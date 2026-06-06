use crate::{
    events::ScanEvent,
    ports::{EventSink, ScannerBackend},
    read_model::{DraftNode, ScanSnapshotDraft},
    scan::{
        BackendRunId, BackendScanOutput, BackendScanRequest, CancellationToken, ScanFailure,
        ScannerBackendCapabilities,
    },
};
use fs_usage_core::{
    CapabilitySet, ChildCompleteness, EvidenceConfidence, MeasuredQuantity, NodeKind, ScanIssue,
    SizeBytes, SizeFact, SupportLevel,
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

        Ok(BackendScanOutput::new(
            BackendRunId::new(1).expect("non-zero backend run id"),
            self.draft.clone(),
            self.issues.clone(),
            self.capabilities.clone(),
        ))
    }
}
