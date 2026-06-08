use fs_usage_core::{
    ChildCompleteness, EvidenceConfidence, MeasuredQuantity, NodeKind, PartialNodeId,
    ScanSessionId, SizeBytes, SizeFact,
};
use fs_usage_engine::{
    GrowingNodeState, GrowingTreeBatch, GrowingTreeEvent, PartialNodeName, ScanEvent,
};
use std::{
    collections::HashMap,
    path::{Path, PathBuf},
    sync::{
        Mutex,
        mpsc::{Receiver, SyncSender, sync_channel},
    },
};

const GROWING_EVENT_CHANNEL_BOUND: usize = 8_192;
pub(crate) const MAX_GROWING_EVENTS_PER_BATCH: usize = 256;

#[derive(Debug)]
pub(crate) struct PduGrowingTreeRecorder {
    session_id: ScanSessionId,
    root: PathBuf,
    max_depth: u64,
    inner: Mutex<PduGrowingTreeState>,
    sender: SyncSender<GrowingTreeEvent>,
}

#[derive(Debug, Default)]
struct PduGrowingTreeState {
    next_node_id: u64,
    nodes: HashMap<PathBuf, PduPartialNodeRecord>,
}

#[derive(Debug, Clone, Copy)]
struct PduPartialNodeRecord {
    node_id: PartialNodeId,
    aggregate_size: u64,
}

impl PduGrowingTreeRecorder {
    pub(crate) fn new(
        session_id: ScanSessionId,
        root: PathBuf,
        max_depth: u64,
    ) -> (Self, Receiver<GrowingTreeEvent>) {
        let (sender, receiver) = sync_channel(GROWING_EVENT_CHANNEL_BOUND);
        (
            Self {
                session_id,
                root,
                max_depth,
                inner: Mutex::new(PduGrowingTreeState::default()),
                sender,
            },
            receiver,
        )
    }

    pub(crate) fn record_node(&self, path: &Path, kind: NodeKind, raw_size: u64) {
        let events = {
            let mut inner = self
                .inner
                .lock()
                .expect("pdu growing tree recorder poisoned");
            inner.record_node(
                self.session_id,
                &self.root,
                self.max_depth,
                path,
                kind,
                raw_size,
            )
        };
        for event in events {
            let _ = self.sender.send(event);
        }
    }

    pub(crate) fn complete_node(&self, path: &Path, aggregate_size: u64) {
        let event = {
            let inner = self
                .inner
                .lock()
                .expect("pdu growing tree recorder poisoned");
            inner.complete_node(self.session_id, path, aggregate_size)
        };
        if let Some(event) = event {
            let _ = self.sender.send(event);
        }
    }
}

impl PduGrowingTreeState {
    fn record_node(
        &mut self,
        session_id: ScanSessionId,
        root: &Path,
        max_depth: u64,
        path: &Path,
        kind: NodeKind,
        raw_size: u64,
    ) -> Vec<GrowingTreeEvent> {
        let should_materialize = should_materialize_partial_node(root, max_depth, path);
        let mut events = Vec::new();

        if should_materialize && !self.nodes.contains_key(path) {
            let node_id = self.next_node_id();
            let parent_id = parent_id_for(root, path, &self.nodes);
            self.nodes.insert(
                path.to_path_buf(),
                PduPartialNodeRecord {
                    node_id,
                    aggregate_size: 0,
                },
            );
            events.push(GrowingTreeEvent::NodeDiscovered {
                session_id,
                node_id,
                parent_id,
                name: partial_name_for(root, path),
                kind,
            });
        }

        if raw_size > 0 {
            for ancestor in materialized_ancestor_paths(root, path) {
                let Some(record) = self.nodes.get_mut(&ancestor) else {
                    continue;
                };
                record.aggregate_size = record.aggregate_size.saturating_add(raw_size);
                events.push(GrowingTreeEvent::NodeSizeUpdated {
                    session_id,
                    node_id: record.node_id,
                    aggregate_size: size_fact(record.aggregate_size),
                    state: GrowingNodeState::Scanning,
                });
            }
        }

        if should_materialize
            && kind != NodeKind::Directory
            && let Some(record) = self.nodes.get(path)
        {
            events.push(GrowingTreeEvent::NodeCompleted {
                session_id,
                node_id: record.node_id,
                aggregate_size: size_fact(record.aggregate_size),
                child_completeness: ChildCompleteness::Complete,
            });
        }

        events
    }

    fn complete_node(
        &self,
        session_id: ScanSessionId,
        path: &Path,
        aggregate_size: u64,
    ) -> Option<GrowingTreeEvent> {
        let record = self.nodes.get(path)?;
        Some(GrowingTreeEvent::NodeCompleted {
            session_id,
            node_id: record.node_id,
            aggregate_size: size_fact(aggregate_size),
            child_completeness: ChildCompleteness::Complete,
        })
    }

    fn next_node_id(&mut self) -> PartialNodeId {
        self.next_node_id = self.next_node_id.saturating_add(1);
        PartialNodeId::new(self.next_node_id).expect("partial node id is non-zero")
    }
}

pub(crate) fn drain_growing_tree_events(
    receiver: &Receiver<GrowingTreeEvent>,
    session_id: ScanSessionId,
    scanned_items: u64,
) -> Vec<ScanEvent> {
    let mut scan_events = Vec::new();
    let mut batch = Vec::with_capacity(MAX_GROWING_EVENTS_PER_BATCH);

    while let Ok(event) = receiver.try_recv() {
        batch.push(event);
        if batch.len() >= MAX_GROWING_EVENTS_PER_BATCH {
            push_batch(&mut scan_events, session_id, scanned_items, &mut batch);
        }
    }

    push_batch(&mut scan_events, session_id, scanned_items, &mut batch);
    scan_events
}

fn push_batch(
    scan_events: &mut Vec<ScanEvent>,
    session_id: ScanSessionId,
    scanned_items: u64,
    batch: &mut Vec<GrowingTreeEvent>,
) {
    if batch.is_empty() {
        return;
    }
    let growing_batch = GrowingTreeBatch::new(session_id, scanned_items, std::mem::take(batch))
        .expect("pdu growing tree events are session-scoped and non-empty");
    scan_events.push(ScanEvent::GrowingTreeBatch {
        batch: growing_batch,
    });
}

fn should_materialize_partial_node(root: &Path, max_depth: u64, path: &Path) -> bool {
    if max_depth == u64::MAX {
        return true;
    }
    relative_depth(root, path).is_some_and(|depth| depth < max_depth)
}

fn relative_depth(root: &Path, path: &Path) -> Option<u64> {
    let relative = path.strip_prefix(root).ok()?;
    Some(relative.components().count() as u64)
}

fn parent_id_for(
    root: &Path,
    path: &Path,
    nodes: &HashMap<PathBuf, PduPartialNodeRecord>,
) -> Option<PartialNodeId> {
    if path == root {
        return None;
    }
    path.parent()
        .and_then(|parent| nodes.get(parent))
        .map(|record| record.node_id)
}

fn materialized_ancestor_paths(root: &Path, path: &Path) -> Vec<PathBuf> {
    let mut ancestors = Vec::new();
    let mut current = Some(path);
    while let Some(candidate) = current {
        if candidate.starts_with(root) {
            ancestors.push(candidate.to_path_buf());
        }
        if candidate == root {
            break;
        }
        current = candidate.parent();
    }
    ancestors.reverse();
    ancestors
}

fn partial_name_for(root: &Path, path: &Path) -> PartialNodeName {
    let value = if path == root {
        path.file_name()
            .map(|name| name.to_string_lossy().into_owned())
            .filter(|name| !name.trim().is_empty())
            .unwrap_or_else(|| path.to_string_lossy().into_owned())
    } else {
        path.file_name()
            .map(|name| name.to_string_lossy().into_owned())
            .unwrap_or_else(|| path.to_string_lossy().into_owned())
    };

    PartialNodeName::new(value).unwrap_or_else(|_| PartialNodeName::new("root").expect("fallback"))
}

const fn size_fact(raw_size: u64) -> SizeFact {
    SizeFact::new(
        raw_size,
        MeasuredQuantity::ApparentBytes,
        Some(SizeBytes::new(raw_size)),
        EvidenceConfidence::High,
    )
}
