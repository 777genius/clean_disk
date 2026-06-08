use fs_usage_core::{
    ChildCompleteness, EvidenceConfidence, MeasuredQuantity, NodeKind, PartialNodeId,
    ScanSessionId, SizeBytes, SizeFact,
};
use fs_usage_engine::{
    GrowingNodeState, GrowingTreeBatch, GrowingTreeEvent, PartialNodeName, ScanEvent,
};
use std::{
    collections::{HashMap, HashSet, VecDeque},
    path::{Path, PathBuf},
    sync::Mutex,
};

const MAX_MATERIALIZED_PARTIAL_NODES: usize = 512;
pub(crate) const MAX_GROWING_EVENTS_PER_BATCH: usize = 32;

#[derive(Debug)]
pub(crate) struct PduGrowingTreeRecorder {
    session_id: ScanSessionId,
    root: PathBuf,
    max_depth: u64,
    inner: Mutex<PduGrowingTreeState>,
}

#[derive(Debug, Default)]
struct PduGrowingTreeState {
    next_node_id: u64,
    nodes: HashMap<PathBuf, PduPartialNodeRecord>,
    pending_discoveries: VecDeque<GrowingTreeEvent>,
    dirty_paths: VecDeque<PathBuf>,
    dirty_path_set: HashSet<PathBuf>,
}

#[derive(Debug, Clone, Copy)]
struct PduPartialNodeRecord {
    node_id: PartialNodeId,
    aggregate_size: u64,
}

impl PduGrowingTreeRecorder {
    pub(crate) fn new(session_id: ScanSessionId, root: PathBuf, max_depth: u64) -> Self {
        Self {
            session_id,
            root,
            max_depth,
            inner: Mutex::new(PduGrowingTreeState::default()),
        }
    }

    pub(crate) fn record_node(&self, path: &Path, kind: NodeKind, raw_size: u64) {
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
        );
    }

    pub(crate) fn drain_scan_event(&self, scanned_items: u64) -> Option<ScanEvent> {
        let mut inner = self
            .inner
            .lock()
            .expect("pdu growing tree recorder poisoned");
        batch_to_scan_event(
            self.session_id,
            scanned_items,
            inner.drain_regular_batch(self.session_id),
        )
    }

    pub(crate) fn complete_root_node(
        &self,
        path: &Path,
        aggregate_size: u64,
        scanned_items: u64,
    ) -> Option<ScanEvent> {
        let mut inner = self
            .inner
            .lock()
            .expect("pdu growing tree recorder poisoned");
        batch_to_scan_event(
            self.session_id,
            scanned_items,
            inner.complete_node(self.session_id, path, aggregate_size),
        )
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
    ) {
        let should_materialize = should_materialize_partial_node(root, max_depth, path, kind);

        if should_materialize
            && !self.nodes.contains_key(path)
            && self.nodes.len() < MAX_MATERIALIZED_PARTIAL_NODES
        {
            let node_id = self.next_node_id();
            let parent_id = parent_id_for(root, path, &self.nodes);
            self.nodes.insert(
                path.to_path_buf(),
                PduPartialNodeRecord {
                    node_id,
                    aggregate_size: 0,
                },
            );
            self.pending_discoveries
                .push_back(GrowingTreeEvent::NodeDiscovered {
                    session_id,
                    node_id,
                    parent_id,
                    name: partial_name_for(root, path),
                    kind,
                });
        }

        if raw_size == 0 {
            return;
        }

        for ancestor in materialized_ancestor_paths(root, path) {
            let Some(record) = self.nodes.get_mut(&ancestor) else {
                continue;
            };
            record.aggregate_size = record.aggregate_size.saturating_add(raw_size);
            if self.dirty_path_set.insert(ancestor.clone()) {
                self.dirty_paths.push_back(ancestor);
            }
        }
    }

    fn drain_regular_batch(&mut self, session_id: ScanSessionId) -> Vec<GrowingTreeEvent> {
        let mut events = Vec::with_capacity(MAX_GROWING_EVENTS_PER_BATCH);

        while events.len() < MAX_GROWING_EVENTS_PER_BATCH {
            let Some(event) = self.pending_discoveries.pop_front() else {
                break;
            };
            events.push(event);
        }

        while events.len() < MAX_GROWING_EVENTS_PER_BATCH {
            let Some(path) = self.dirty_paths.pop_front() else {
                break;
            };
            self.dirty_path_set.remove(&path);
            let Some(record) = self.nodes.get(&path) else {
                continue;
            };
            events.push(GrowingTreeEvent::NodeSizeUpdated {
                session_id,
                node_id: record.node_id,
                aggregate_size: size_fact(record.aggregate_size),
                state: GrowingNodeState::Scanning,
            });
        }

        events
    }

    fn complete_node(
        &mut self,
        session_id: ScanSessionId,
        path: &Path,
        aggregate_size: u64,
    ) -> Vec<GrowingTreeEvent> {
        let Some(record) = self.nodes.get_mut(path) else {
            return Vec::new();
        };
        record.aggregate_size = record.aggregate_size.max(aggregate_size);
        self.dirty_path_set.remove(path);
        self.dirty_paths.retain(|dirty| dirty != path);
        vec![
            GrowingTreeEvent::NodeSizeUpdated {
                session_id,
                node_id: record.node_id,
                aggregate_size: size_fact(record.aggregate_size),
                state: GrowingNodeState::Scanning,
            },
            GrowingTreeEvent::NodeCompleted {
                session_id,
                node_id: record.node_id,
                aggregate_size: size_fact(record.aggregate_size),
                child_completeness: ChildCompleteness::Complete,
            },
        ]
    }

    fn next_node_id(&mut self) -> PartialNodeId {
        self.next_node_id = self.next_node_id.saturating_add(1);
        PartialNodeId::new(self.next_node_id).expect("partial node id is non-zero")
    }
}

fn batch_to_scan_event(
    session_id: ScanSessionId,
    scanned_items: u64,
    events: Vec<GrowingTreeEvent>,
) -> Option<ScanEvent> {
    if events.is_empty() {
        return None;
    }
    let growing_batch = GrowingTreeBatch::new(session_id, scanned_items, events)
        .expect("pdu growing tree events are session-scoped and non-empty");
    Some(ScanEvent::GrowingTreeBatch {
        batch: growing_batch,
    })
}

fn should_materialize_partial_node(
    root: &Path,
    max_depth: u64,
    path: &Path,
    kind: NodeKind,
) -> bool {
    if path != root && kind != NodeKind::Directory {
        return false;
    }
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
