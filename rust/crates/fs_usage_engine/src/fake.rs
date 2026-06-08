use crate::{
    events::ScanEvent,
    growing_tree::{GrowingNodeState, GrowingTreeBatch, GrowingTreeEvent, PartialNodeName},
    ports::{EventSink, ScannerBackend},
    read_model::{DraftNode, ScanSnapshotDraft},
    scan::{
        BackendRunId, BackendScanOutput, BackendScanRequest, CancellationToken, ScanFailure,
        ScannerBackendCapabilities,
    },
};
use fs_usage_core::{
    CapabilitySet, ChildCompleteness, EvidenceConfidence, MeasuredQuantity, NodeKind,
    PartialNodeId, ScanIssue, ScanSessionId, SizeBytes, SizeFact, SupportLevel,
};

#[derive(Debug, Clone)]
pub struct FakeScannerBackend {
    capabilities: ScannerBackendCapabilities,
    draft: ScanSnapshotDraft,
    issues: Vec<ScanIssue>,
}

impl FakeScannerBackend {
    pub fn new(draft: ScanSnapshotDraft) -> Self {
        Self {
            capabilities: ScannerBackendCapabilities::new(
                "fake",
                CapabilitySet::new(
                    SupportLevel::Unsupported,
                    SupportLevel::Unsupported,
                    SupportLevel::Supported,
                    SupportLevel::Unsupported,
                    SupportLevel::Supported,
                ),
            ),
            draft,
            issues: Vec::new(),
        }
    }

    pub fn sample() -> Self {
        Self::sample_with_issues(Vec::new())
    }

    pub fn sample_with_issues(issues: Vec<ScanIssue>) -> Self {
        let size = |bytes| {
            SizeFact::new(
                bytes,
                MeasuredQuantity::ApparentBytes,
                Some(SizeBytes::new(bytes)),
                EvidenceConfidence::Exact,
            )
        };
        let draft = ScanSnapshotDraft::new(vec![
            DraftNode::new(
                "root",
                NodeKind::Directory,
                size(100),
                ChildCompleteness::Complete,
            )
            .with_children(vec![
                DraftNode::new(
                    "alpha.log",
                    NodeKind::File,
                    size(40),
                    ChildCompleteness::Complete,
                ),
                DraftNode::new(
                    "beta.cache",
                    NodeKind::File,
                    size(60),
                    ChildCompleteness::Complete,
                ),
            ]),
        ]);

        Self {
            capabilities: ScannerBackendCapabilities::new(
                "fake",
                CapabilitySet::new(
                    SupportLevel::Unsupported,
                    SupportLevel::Unsupported,
                    SupportLevel::Supported,
                    SupportLevel::Unsupported,
                    SupportLevel::Supported,
                ),
            ),
            draft,
            issues,
        }
    }
}

impl ScannerBackend for FakeScannerBackend {
    fn capabilities(&self) -> ScannerBackendCapabilities {
        self.capabilities.clone()
    }

    fn scan(
        &self,
        request: BackendScanRequest,
        events: &mut dyn EventSink,
        cancellation: &CancellationToken,
    ) -> Result<BackendScanOutput, ScanFailure> {
        if cancellation.is_canceled() {
            events.emit(ScanEvent::Canceled {
                session_id: request.session_id(),
            });
            return Err(ScanFailure::Canceled);
        }

        events.emit(ScanEvent::Progress {
            session_id: request.session_id(),
            scanned_items: 3,
        });
        emit_sample_growing_tree_batch(request.session_id(), events);

        Ok(BackendScanOutput::new(
            BackendRunId::new(1).expect("non-zero backend run id"),
            self.draft.clone(),
            self.issues.clone(),
            self.capabilities.clone(),
        ))
    }
}

fn emit_sample_growing_tree_batch(session_id: ScanSessionId, events: &mut dyn EventSink) {
    let root = PartialNodeId::new(1).expect("partial root id");
    let alpha = PartialNodeId::new(2).expect("partial alpha id");
    let beta = PartialNodeId::new(3).expect("partial beta id");
    let size = |bytes| {
        SizeFact::new(
            bytes,
            MeasuredQuantity::ApparentBytes,
            Some(SizeBytes::new(bytes)),
            EvidenceConfidence::Low,
        )
    };
    let batch = GrowingTreeBatch::new(
        session_id,
        3,
        vec![
            GrowingTreeEvent::NodeDiscovered {
                session_id,
                node_id: root,
                parent_id: None,
                name: PartialNodeName::new("root").expect("root name"),
                kind: NodeKind::Directory,
            },
            GrowingTreeEvent::NodeSizeUpdated {
                session_id,
                node_id: root,
                aggregate_size: size(100),
                state: GrowingNodeState::Scanning,
            },
            GrowingTreeEvent::NodeDiscovered {
                session_id,
                node_id: alpha,
                parent_id: Some(root),
                name: PartialNodeName::new("alpha.log").expect("alpha name"),
                kind: NodeKind::File,
            },
            GrowingTreeEvent::NodeCompleted {
                session_id,
                node_id: alpha,
                aggregate_size: size(40),
                child_completeness: ChildCompleteness::Complete,
            },
            GrowingTreeEvent::NodeDiscovered {
                session_id,
                node_id: beta,
                parent_id: Some(root),
                name: PartialNodeName::new("beta.cache").expect("beta name"),
                kind: NodeKind::File,
            },
            GrowingTreeEvent::NodeCompleted {
                session_id,
                node_id: beta,
                aggregate_size: size(60),
                child_completeness: ChildCompleteness::Complete,
            },
        ],
    )
    .expect("valid growing tree batch");

    events.emit(ScanEvent::GrowingTreeBatch { batch });
}
