use crate::{
    events::ScanEvent,
    ports::{EventSink, ScannerBackend},
    read_model::{ScanSnapshot, ScanSnapshotDraft, SnapshotPublicationGate},
};
use fs_usage_core::{CapabilitySet, MeasuredQuantity, ScanIssue, ScanSessionId, ScanTarget};
use std::sync::{
    Arc,
    atomic::{AtomicBool, Ordering},
};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct BackendRunId(u64);

impl BackendRunId {
    pub fn new(value: u64) -> Option<Self> {
        if value == 0 {
            return None;
        }
        Some(Self(value))
    }

    pub const fn get(self) -> u64 {
        self.0
    }
}

#[derive(Debug, Clone)]
pub struct BackendScanRequest {
    session_id: ScanSessionId,
    targets: Vec<ScanTarget>,
    measurement: MeasuredQuantity,
}

impl BackendScanRequest {
    pub fn new(
        session_id: ScanSessionId,
        targets: Vec<ScanTarget>,
        measurement: MeasuredQuantity,
    ) -> Self {
        Self {
            session_id,
            targets,
            measurement,
        }
    }

    pub const fn session_id(&self) -> ScanSessionId {
        self.session_id
    }

    pub fn targets(&self) -> &[ScanTarget] {
        &self.targets
    }

    pub const fn measurement(&self) -> MeasuredQuantity {
        self.measurement
    }
}

#[derive(Debug, Clone)]
pub struct ScannerBackendCapabilities {
    backend_name: String,
    capabilities: CapabilitySet,
}

impl ScannerBackendCapabilities {
    pub fn new(backend_name: impl Into<String>, capabilities: CapabilitySet) -> Self {
        Self {
            backend_name: backend_name.into(),
            capabilities,
        }
    }

    pub fn backend_name(&self) -> &str {
        &self.backend_name
    }

    pub const fn capabilities(&self) -> CapabilitySet {
        self.capabilities
    }
}

#[derive(Debug, Clone)]
pub struct BackendScanOutput {
    backend_run_id: BackendRunId,
    draft: ScanSnapshotDraft,
    issues: Vec<ScanIssue>,
    capabilities: ScannerBackendCapabilities,
}

impl BackendScanOutput {
    pub fn new(
        backend_run_id: BackendRunId,
        draft: ScanSnapshotDraft,
        issues: Vec<ScanIssue>,
        capabilities: ScannerBackendCapabilities,
    ) -> Self {
        Self {
            backend_run_id,
            draft,
            issues,
            capabilities,
        }
    }

    pub const fn backend_run_id(&self) -> BackendRunId {
        self.backend_run_id
    }

    pub const fn draft(&self) -> &ScanSnapshotDraft {
        &self.draft
    }

    pub fn into_parts(
        self,
    ) -> (
        BackendRunId,
        ScanSnapshotDraft,
        Vec<ScanIssue>,
        ScannerBackendCapabilities,
    ) {
        (
            self.backend_run_id,
            self.draft,
            self.issues,
            self.capabilities,
        )
    }

    pub fn issues(&self) -> &[ScanIssue] {
        &self.issues
    }

    pub const fn capabilities(&self) -> &ScannerBackendCapabilities {
        &self.capabilities
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ScanFailure {
    Canceled,
    Backend(String),
    InvalidRequest(String),
}

#[derive(Debug, Clone, Default)]
pub struct CancellationToken {
    canceled: Arc<AtomicBool>,
}

impl CancellationToken {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn cancel(&self) {
        self.canceled.store(true, Ordering::SeqCst);
    }

    pub fn is_canceled(&self) -> bool {
        self.canceled.load(Ordering::SeqCst)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ScanState {
    Created,
    Running,
    Canceled,
    Completed,
    Failed(String),
}

#[derive(Debug)]
pub struct ScanSession {
    id: ScanSessionId,
    state: ScanState,
    snapshot: Option<Arc<ScanSnapshot>>,
    backend_run_id: Option<BackendRunId>,
    backend_capabilities: Option<ScannerBackendCapabilities>,
}

impl ScanSession {
    pub const fn new(id: ScanSessionId) -> Self {
        Self {
            id,
            state: ScanState::Created,
            snapshot: None,
            backend_run_id: None,
            backend_capabilities: None,
        }
    }

    pub const fn id(&self) -> ScanSessionId {
        self.id
    }

    pub const fn state(&self) -> &ScanState {
        &self.state
    }

    pub fn snapshot(&self) -> Option<&ScanSnapshot> {
        self.snapshot.as_deref()
    }

    pub fn snapshot_arc(&self) -> Option<Arc<ScanSnapshot>> {
        self.snapshot.clone()
    }

    pub const fn backend_run_id(&self) -> Option<BackendRunId> {
        self.backend_run_id
    }

    pub const fn backend_capabilities(&self) -> Option<&ScannerBackendCapabilities> {
        self.backend_capabilities.as_ref()
    }

    pub fn start(
        &mut self,
        backend: &dyn ScannerBackend,
        request: BackendScanRequest,
        events: &mut dyn EventSink,
        cancellation: &CancellationToken,
    ) -> Result<(), ScanFailure> {
        if request.session_id() != self.id {
            let failure = ScanFailure::InvalidRequest("request session id mismatch".to_string());
            self.state = ScanState::Failed("request session id mismatch".to_string());
            events.emit(ScanEvent::Failed {
                session_id: self.id,
                message: "request session id mismatch".to_string(),
            });
            return Err(failure);
        }

        if cancellation.is_canceled() {
            self.state = ScanState::Canceled;
            events.emit(ScanEvent::Canceled {
                session_id: self.id,
            });
            return Err(ScanFailure::Canceled);
        }

        self.state = ScanState::Running;
        events.emit(ScanEvent::Started {
            session_id: self.id,
        });

        let output = match backend.scan(request, events, cancellation) {
            Ok(output) => output,
            Err(ScanFailure::Canceled) => {
                self.state = ScanState::Canceled;
                events.emit(ScanEvent::Canceled {
                    session_id: self.id,
                });
                return Err(ScanFailure::Canceled);
            }
            Err(error) => {
                self.state = ScanState::Failed(format!("{error:?}"));
                events.emit(ScanEvent::Failed {
                    session_id: self.id,
                    message: format!("{error:?}"),
                });
                return Err(error);
            }
        };

        if cancellation.is_canceled() {
            self.state = ScanState::Canceled;
            events.emit(ScanEvent::Canceled {
                session_id: self.id,
            });
            return Err(ScanFailure::Canceled);
        }

        let (backend_run_id, draft, issues, capabilities) = output.into_parts();
        let snapshot = SnapshotPublicationGate::publish_for_session(self.id, draft, issues);
        events.emit(ScanEvent::SnapshotPublished {
            session_id: self.id,
            snapshot_id: snapshot.snapshot_id(),
        });
        self.snapshot = Some(Arc::new(snapshot));
        self.backend_run_id = Some(backend_run_id);
        self.backend_capabilities = Some(capabilities);
        self.state = ScanState::Completed;
        Ok(())
    }
}
