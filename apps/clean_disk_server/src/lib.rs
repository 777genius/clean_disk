#![forbid(unsafe_code)]

use axum::{
    Json, Router,
    extract::{Path as AxumPath, State, WebSocketUpgrade, ws::Message},
    http::{HeaderMap, HeaderValue, StatusCode},
    response::{IntoResponse, Response},
    routing::{get, post},
};
use clean_disk_protocol::{
    BoundaryPolicyDto, CancelScanRequestDto, CapabilityResponseDto, CapabilitySetDto,
    ChildCompletenessDto, ChildSortDto, ChildrenPageRequestDto, CleanupItemOutcomeStateDto,
    CleanupPlanDto, CleanupPlanItemDto, CleanupPlanItemRefDto, CleanupPlanItemStateDto,
    CleanupPlanStateDto, CleanupReceiptDto, CleanupReceiptItemDto, CleanupReceiptStateDto,
    CleanupRecoveryInboxDto, CreateCleanupPlanRequestDto, DaemonDiagnosticsDto, DecimalU64Dto,
    DecimalU128Dto, DecimalUsizeDto, DisplayPathDto, DisposeScanSessionRequestDto,
    DistributionChannelDto, ExecuteCleanupPlanRequestDto, ExecuteCleanupRequestDto,
    HardlinkPolicyDto, IssueCodeDto, IssueEvidenceDto, IssueSeverityDto, MeasuredQuantityDto,
    MeasuredQuantityResponseDto, NodeDetailsRequestDto, NodeDetailsResponseDto, NodeFlagsDto,
    NodeKindDto, NodePageItemDto, NodePageResponseDto, NodeTimestampsDto, OpaqueCursorDto,
    PROTOCOL_VERSION, PackageModeDto, PackagingProofDto, PathPrivacyDto, PermissionProbeDto,
    PermissionProbeRequestDto, PermissionProbeStatusDto, PermissionRequiredActionDto,
    ProtocolLimitDto, RawPathDto, RestoreExpectationLevelDto, RuntimePlatformDto, RuntimeProofDto,
    ScanEventDto, ScanEventEnvelopeDto, ScanIssueDto, ScanProgressDto, ScanSessionStatusDto,
    ScanTargetDto, ScannerCapabilityDto, ScannerIdentityProofDto, ScannerIdentityVerificationDto,
    ScannerProcessKindDto, SearchPageRequestDto, SessionStateDto, SizeConfidenceDto, SizeFactDto,
    StartScanRequestDto, SupportLevelDto, TargetScopeDto, TopItemsKindDto, TopItemsRequestDto,
    UpdateSafetyDto,
};
use fs_usage_core::{
    BoundaryPolicy, ChildCompleteness, EvidenceConfidence, HardlinkPolicy, IssueCode,
    IssueSeverity, MeasuredQuantity, NodeFlags, NodeId, NodeIdentityEvidence, NodeKind, ScanIssue,
    ScanSessionId, ScanTarget, SizeFact, SnapshotId, SupportLevel, TargetPath, TargetScope,
};
use fs_usage_engine::{
    BackendScanRequest, BoundedEventBuffer, CancellationToken, ChildSort, ChildrenPageQuery,
    EventSink, NodeDetails, NodeDetailsQuery, NodePageItem, Page, PageCursor, QueryFailure,
    RuntimeAdmissionController, RuntimeAdmissionError, ScanEvent, ScanPermit, ScanResourceProfile,
    ScanSession, ScanState, ScannerBackend, ScannerBackendCapabilities, SearchQuery, TopItemsKind,
    TopItemsQuery, WorkerBudget,
};
use fs_usage_pdu::PduScannerBackend;
use fs_usage_platform::{
    OsTrashAdapter, RestoreExpectationLevel, TrashAdapter, TrashFailure, metadata_identity_evidence,
};
use serde::{Deserialize, Serialize};
use std::{
    collections::{HashMap, HashSet, VecDeque},
    env, fmt, fs,
    fs::{File, OpenOptions},
    io::{self, Write},
    net::{IpAddr, Ipv4Addr, SocketAddr},
    path::{Path, PathBuf},
    process::Command,
    sync::{
        Arc, Mutex,
        atomic::{AtomicU64, Ordering},
    },
    time::{SystemTime, UNIX_EPOCH},
};
use tokio::sync::broadcast;

pub const LOCAL_AUTH_TOKEN_ENV: &str = "CLEAN_DISK_LOCAL_AUTH_TOKEN";
const EVENTS_WEBSOCKET_SUBPROTOCOL: &str = "clean-disk-events-v1";
const EVENTS_WEBSOCKET_TOKEN_PREFIX: &str = "clean-disk-token.";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ServerConfigError {
    MissingLocalAuthToken,
    EmptyLocalAuthToken,
}

impl fmt::Display for ServerConfigError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingLocalAuthToken => {
                write!(formatter, "{LOCAL_AUTH_TOKEN_ENV} is required")
            }
            Self::EmptyLocalAuthToken => {
                write!(formatter, "{LOCAL_AUTH_TOKEN_ENV} must not be empty")
            }
        }
    }
}

impl std::error::Error for ServerConfigError {}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ScanOnlyPackagingSmokeFailure {
    DevelopmentDistribution,
    UnknownDistributionChannel,
    DevelopmentShell,
    UnknownPackageMode,
    UnsignedBuild,
    DebugBuild,
    SandboxedBuild,
    ExternalScannerProcess,
    UnknownScannerProcess,
    MissingAppBundleIdentity,
    MissingBundledHelperIdentity,
    MissingUpdateQuiesceGate,
    MissingReceiptPreservation,
}

impl ScanOnlyPackagingSmokeFailure {
    pub const fn code(self) -> &'static str {
        match self {
            Self::DevelopmentDistribution => "development_distribution",
            Self::UnknownDistributionChannel => "unknown_distribution_channel",
            Self::DevelopmentShell => "development_shell",
            Self::UnknownPackageMode => "unknown_package_mode",
            Self::UnsignedBuild => "unsigned_build",
            Self::DebugBuild => "debug_build",
            Self::SandboxedBuild => "sandboxed_build",
            Self::ExternalScannerProcess => "external_scanner_process",
            Self::UnknownScannerProcess => "unknown_scanner_process",
            Self::MissingAppBundleIdentity => "missing_app_bundle_identity",
            Self::MissingBundledHelperIdentity => "missing_bundled_helper_identity",
            Self::MissingUpdateQuiesceGate => "missing_update_quiesce_gate",
            Self::MissingReceiptPreservation => "missing_receipt_preservation",
        }
    }
}

impl fmt::Display for ScanOnlyPackagingSmokeFailure {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(self.code())
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ScanOnlyPackagingSmokeReport {
    failures: Vec<ScanOnlyPackagingSmokeFailure>,
}

impl ScanOnlyPackagingSmokeReport {
    fn new(failures: Vec<ScanOnlyPackagingSmokeFailure>) -> Self {
        Self { failures }
    }

    pub fn passed(&self) -> bool {
        self.failures.is_empty()
    }

    pub fn failures(&self) -> &[ScanOnlyPackagingSmokeFailure] {
        &self.failures
    }
}

#[derive(Clone)]
pub struct ServerConfig {
    bind_addr: SocketAddr,
    local_auth_token: Option<String>,
    event_buffer_limit: usize,
    allowed_origins: Vec<String>,
}

impl fmt::Debug for ServerConfig {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("ServerConfig")
            .field("bind_addr", &self.bind_addr)
            .field(
                "local_auth_token",
                &self.local_auth_token.as_ref().map(|_| "<redacted>"),
            )
            .field("event_buffer_limit", &self.event_buffer_limit)
            .field("allowed_origins", &self.allowed_origins)
            .finish()
    }
}

impl ServerConfig {
    pub fn local_default() -> Self {
        Self {
            bind_addr: SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 17631),
            local_auth_token: None,
            event_buffer_limit: 1_024,
            allowed_origins: vec![
                "http://localhost".to_string(),
                "http://127.0.0.1".to_string(),
                "https://localhost".to_string(),
                "https://127.0.0.1".to_string(),
            ],
        }
    }

    pub fn local_from_env() -> Result<Self, ServerConfigError> {
        let token =
            env::var(LOCAL_AUTH_TOKEN_ENV).map_err(|_| ServerConfigError::MissingLocalAuthToken)?;
        Self::local_with_required_token(Some(token))
    }

    fn local_with_required_token(token: Option<String>) -> Result<Self, ServerConfigError> {
        let token = token.ok_or(ServerConfigError::MissingLocalAuthToken)?;
        if token.trim().is_empty() {
            return Err(ServerConfigError::EmptyLocalAuthToken);
        }
        Ok(Self::local_default().with_auth_token(token))
    }

    pub fn with_auth_token(mut self, token: impl Into<String>) -> Self {
        self.local_auth_token = Some(token.into());
        self
    }

    pub const fn bind_addr(&self) -> SocketAddr {
        self.bind_addr
    }

    pub const fn auth_required(&self) -> bool {
        self.local_auth_token.is_some()
    }
}

#[derive(Clone)]
pub struct AppState {
    inner: Arc<AppStateInner>,
}

struct AppStateInner {
    config: ServerConfig,
    backend: Arc<dyn ScannerBackend>,
    cleanup_journal: Arc<FileCleanupJournal>,
    trash_adapter: Arc<dyn TrashAdapter>,
    cleanup_locks: Arc<CleanupExecutionLocks>,
    cleanup_plans: Arc<CleanupPlanStore>,
    registry: Arc<SessionRegistry>,
    budget: WorkerBudget,
}

impl AppState {
    pub fn production() -> Result<Self, ServerConfigError> {
        Ok(Self::new_with_cleanup(
            ServerConfig::local_from_env()?,
            Arc::new(PduScannerBackend::default()),
            Arc::new(FileCleanupJournal::default_for_process()),
            Arc::new(OsTrashAdapter),
            WorkerBudget::for_profile(ScanResourceProfile::Balanced),
        ))
    }

    pub fn new(
        config: ServerConfig,
        backend: Arc<dyn ScannerBackend>,
        budget: WorkerBudget,
    ) -> Self {
        Self::new_with_cleanup(
            config,
            backend,
            Arc::new(FileCleanupJournal::default_for_process()),
            Arc::new(OsTrashAdapter),
            budget,
        )
    }

    pub fn new_with_cleanup(
        config: ServerConfig,
        backend: Arc<dyn ScannerBackend>,
        cleanup_journal: Arc<FileCleanupJournal>,
        trash_adapter: Arc<dyn TrashAdapter>,
        budget: WorkerBudget,
    ) -> Self {
        let event_buffer_limit = config.event_buffer_limit;
        Self {
            inner: Arc::new(AppStateInner {
                config,
                backend,
                cleanup_journal,
                trash_adapter,
                cleanup_locks: Arc::new(CleanupExecutionLocks::default()),
                cleanup_plans: Arc::new(CleanupPlanStore::new(256)),
                registry: Arc::new(SessionRegistry::new(budget, event_buffer_limit, 1)),
                budget,
            }),
        }
    }

    pub fn config(&self) -> &ServerConfig {
        &self.inner.config
    }

    fn backend(&self) -> Arc<dyn ScannerBackend> {
        Arc::clone(&self.inner.backend)
    }

    fn registry(&self) -> Arc<SessionRegistry> {
        Arc::clone(&self.inner.registry)
    }

    fn cleanup_journal(&self) -> Arc<FileCleanupJournal> {
        Arc::clone(&self.inner.cleanup_journal)
    }

    fn trash_adapter(&self) -> Arc<dyn TrashAdapter> {
        Arc::clone(&self.inner.trash_adapter)
    }

    fn cleanup_locks(&self) -> Arc<CleanupExecutionLocks> {
        Arc::clone(&self.inner.cleanup_locks)
    }

    fn cleanup_plans(&self) -> Arc<CleanupPlanStore> {
        Arc::clone(&self.inner.cleanup_plans)
    }

    fn budget(&self) -> WorkerBudget {
        self.inner.budget
    }
}

pub fn build_router(state: AppState) -> Router {
    Router::new()
        .route("/v1/capabilities", get(get_capabilities))
        .route("/v1/permission-probe", post(probe_permission))
        .route("/v1/scans", post(start_scan))
        .route("/v1/scans/{session_id}", get(get_scan_status))
        .route("/v1/scans/{session_id}/cancel", post(cancel_scan))
        .route("/v1/scans/{session_id}/dispose", post(dispose_scan))
        .route("/v1/scans/{session_id}/children", post(get_children_page))
        .route("/v1/scans/{session_id}/search", post(search_nodes))
        .route("/v1/scans/{session_id}/top", post(get_top_items))
        .route("/v1/scans/{session_id}/details", post(get_node_details))
        .route("/v1/cleanup/plans", post(create_cleanup_plan))
        .route(
            "/v1/cleanup/plans/{plan_id}/execute",
            post(execute_cleanup_plan),
        )
        .route("/v1/cleanup/execute", post(execute_cleanup))
        .route(
            "/v1/cleanup/recovery-inbox",
            get(get_cleanup_recovery_inbox),
        )
        .route("/v1/diagnostics", get(get_diagnostics))
        .route("/v1/events", get(open_events_socket))
        .with_state(state)
}

pub async fn run_server(state: AppState) -> Result<(), std::io::Error> {
    let listener = tokio::net::TcpListener::bind(state.config().bind_addr()).await?;
    let registry = state.registry();
    axum::serve(listener, build_router(state))
        .with_graceful_shutdown(shutdown_signal(registry))
        .await
}

#[derive(Debug)]
pub struct SessionRegistry {
    next_session_id: AtomicU64,
    event_sequence: AtomicU64,
    cursor_sequence: AtomicU64,
    admission: RuntimeAdmissionController,
    event_buffer_limit: usize,
    sessions: Mutex<HashMap<u128, SessionRecord>>,
    event_log: Mutex<VecDeque<ScanEventEnvelopeDto>>,
    event_tx: broadcast::Sender<ScanEventEnvelopeDto>,
    cursors: Mutex<CursorRegistry>,
}

impl SessionRegistry {
    pub fn new(budget: WorkerBudget, event_buffer_limit: usize, first_session_id: u64) -> Self {
        let event_buffer_limit = event_buffer_limit
            .max(1)
            .min(budget.max_event_queue_items().get());
        let (event_tx, _) = broadcast::channel(event_buffer_limit);
        Self {
            next_session_id: AtomicU64::new(first_session_id),
            event_sequence: AtomicU64::new(1),
            cursor_sequence: AtomicU64::new(1),
            admission: RuntimeAdmissionController::new(budget),
            event_buffer_limit,
            sessions: Mutex::new(HashMap::new()),
            event_log: Mutex::new(VecDeque::new()),
            event_tx,
            cursors: Mutex::new(CursorRegistry::new(event_buffer_limit)),
        }
    }

    fn allocate_session_id(&self) -> ScanSessionId {
        let id = self.next_session_id.fetch_add(1, Ordering::SeqCst);
        ScanSessionId::new(u128::from(id.max(1))).expect("allocated id is non-zero")
    }

    fn try_acquire_scan(&self) -> Result<ScanPermit, RuntimeAdmissionError> {
        self.admission.try_acquire_scan()
    }

    fn insert_running(&self, session_id: ScanSessionId, cancellation: CancellationToken) {
        let mut sessions = self.sessions.lock().expect("session registry poisoned");
        sessions.insert(
            session_id.get(),
            SessionRecord {
                session_id,
                session: None,
                cancellation,
                cancel_requested: false,
                events: BoundedEventBuffer::new(
                    std::num::NonZeroUsize::new(self.event_buffer_limit)
                        .expect("event buffer limit is non-zero"),
                ),
            },
        );
    }

    fn complete(&self, session_id: ScanSessionId, session: ScanSession) {
        let mut sessions = self.sessions.lock().expect("session registry poisoned");
        if let Some(record) = sessions.get_mut(&session_id.get()) {
            record.session = Some(session);
        }
    }

    fn cancel(&self, session_id: ScanSessionId) -> Option<ScanSessionStatusDto> {
        let mut sessions = self.sessions.lock().expect("session registry poisoned");
        let record = sessions.get_mut(&session_id.get())?;
        record.cancellation.cancel();
        if !record.is_terminal() {
            record.cancel_requested = true;
        }
        Some(status_from_record(record))
    }

    fn dispose(&self, session_id: ScanSessionId) -> bool {
        let record = self
            .sessions
            .lock()
            .expect("session registry poisoned")
            .remove(&session_id.get());
        let Some(record) = record else {
            return false;
        };
        record.cancellation.cancel();
        self.cursors
            .lock()
            .expect("cursor registry poisoned")
            .remove_for_session(session_id);
        true
    }

    fn cancel_all_running(&self) -> usize {
        let mut canceled = 0;
        let mut sessions = self.sessions.lock().expect("session registry poisoned");
        for record in sessions.values_mut() {
            if record.is_terminal() {
                continue;
            }
            record.cancellation.cancel();
            record.cancel_requested = true;
            canceled += 1;
        }
        canceled
    }

    fn status(&self, session_id: ScanSessionId) -> Option<ScanSessionStatusDto> {
        let sessions = self.sessions.lock().expect("session registry poisoned");
        sessions.get(&session_id.get()).map(status_from_record)
    }

    fn push_event(&self, session_id: ScanSessionId, event: ScanEvent) {
        let mut event_was_recorded = false;
        {
            let mut sessions = self.sessions.lock().expect("session registry poisoned");
            if let Some(record) = sessions.get_mut(&session_id.get()) {
                record.events.emit(event.clone());
                event_was_recorded = true;
            }
        }

        if event_was_recorded {
            let envelope = self.next_event_envelope(event);
            let mut event_log = self.event_log.lock().expect("event log poisoned");
            if event_log.len() >= self.event_buffer_limit {
                event_log.pop_front();
            }
            event_log.push_back(envelope.clone());
            let _ = self.event_tx.send(envelope);
        }
    }

    fn event_envelopes(&self) -> Vec<ScanEventEnvelopeDto> {
        self.event_log
            .lock()
            .expect("event log poisoned")
            .iter()
            .cloned()
            .collect()
    }

    fn next_event_envelope(&self, event: ScanEvent) -> ScanEventEnvelopeDto {
        let sequence = self.event_sequence.fetch_add(1, Ordering::SeqCst);
        ScanEventEnvelopeDto::new(
            PROTOCOL_VERSION,
            DecimalU64Dto::from_u64(sequence),
            DecimalU64Dto::from_u64(now_unix_ms()),
            map_event(event),
        )
    }

    fn subscribe_events(&self) -> broadcast::Receiver<ScanEventEnvelopeDto> {
        self.event_tx.subscribe()
    }

    fn resolve_cursor(
        &self,
        session_id: ScanSessionId,
        snapshot_id: SnapshotId,
        cursor: Option<&OpaqueCursorDto>,
    ) -> Result<Option<PageCursor>, SessionQueryFailure> {
        let Some(cursor) = cursor else {
            return Ok(None);
        };
        self.cursors
            .lock()
            .expect("cursor registry poisoned")
            .get(cursor.as_str(), session_id, snapshot_id)
            .ok_or(SessionQueryFailure::InvalidCursor)
            .map(Some)
    }

    fn store_cursor(
        &self,
        session_id: ScanSessionId,
        snapshot_id: SnapshotId,
        cursor: Option<PageCursor>,
    ) -> Option<OpaqueCursorDto> {
        cursor.map(|cursor| {
            let sequence = self.cursor_sequence.fetch_add(1, Ordering::SeqCst);
            let token = format!("cursor-{sequence}");
            self.cursors
                .lock()
                .expect("cursor registry poisoned")
                .insert(token.clone(), session_id, snapshot_id, cursor);
            OpaqueCursorDto::new(token).expect("generated cursor token is non-empty")
        })
    }

    fn children_page(
        &self,
        session_id: ScanSessionId,
        query: ChildrenPageQuery,
    ) -> Result<Page<NodePageItem>, SessionQueryFailure> {
        self.with_snapshot(session_id, |snapshot| {
            snapshot.children_page(query).map_err(Into::into)
        })
    }

    fn search_page(
        &self,
        session_id: ScanSessionId,
        query: SearchQuery,
    ) -> Result<Page<NodePageItem>, SessionQueryFailure> {
        self.with_snapshot(session_id, |snapshot| {
            snapshot.search_page(query).map_err(Into::into)
        })
    }

    fn top_items_page(
        &self,
        session_id: ScanSessionId,
        query: TopItemsQuery,
    ) -> Result<Page<NodePageItem>, SessionQueryFailure> {
        self.with_snapshot(session_id, |snapshot| {
            snapshot.top_items_page(query).map_err(Into::into)
        })
    }

    fn node_details(
        &self,
        session_id: ScanSessionId,
        query: NodeDetailsQuery,
    ) -> Result<NodeDetails, SessionQueryFailure> {
        self.with_snapshot(session_id, |snapshot| {
            snapshot.node_details(query).map_err(Into::into)
        })
    }

    fn node_record(
        &self,
        session_id: ScanSessionId,
        snapshot_id: SnapshotId,
        node_id: NodeId,
    ) -> Result<fs_usage_engine::NodeRecord, SessionQueryFailure> {
        self.with_snapshot(session_id, |snapshot| {
            if snapshot.snapshot_id() != snapshot_id {
                return Err(SessionQueryFailure::Query(QueryFailure::SnapshotMismatch));
            }
            snapshot
                .node(node_id)
                .cloned()
                .ok_or(SessionQueryFailure::Query(QueryFailure::UnknownNode(
                    node_id,
                )))
        })
    }

    fn with_snapshot<T>(
        &self,
        session_id: ScanSessionId,
        query: impl FnOnce(&fs_usage_engine::ScanSnapshot) -> Result<T, SessionQueryFailure>,
    ) -> Result<T, SessionQueryFailure> {
        let snapshot = {
            let sessions = self.sessions.lock().expect("session registry poisoned");
            let record = sessions
                .get(&session_id.get())
                .ok_or(SessionQueryFailure::SessionNotFound)?;
            let session = record
                .session
                .as_ref()
                .ok_or(SessionQueryFailure::SnapshotNotReady)?;
            session
                .snapshot_arc()
                .ok_or(SessionQueryFailure::SnapshotNotReady)?
        };
        query(snapshot.as_ref())
    }

    fn diagnostics(&self) -> RegistryDiagnostics {
        let sessions = self.sessions.lock().expect("session registry poisoned");
        let active_sessions = sessions.len();
        let running_sessions = sessions
            .values()
            .filter(|record| !record.is_terminal())
            .count();
        let completed_sessions = sessions
            .values()
            .filter(|record| {
                record
                    .session
                    .as_ref()
                    .is_some_and(|session| matches!(session.state(), ScanState::Completed))
            })
            .count();
        let cancel_requested_sessions = sessions
            .values()
            .filter(|record| record.cancel_requested)
            .count();
        drop(sessions);

        RegistryDiagnostics {
            active_sessions,
            running_sessions,
            completed_sessions,
            cancel_requested_sessions,
            buffered_events: self.event_envelopes().len(),
            stored_cursors: self.cursors.lock().expect("cursor registry poisoned").len(),
        }
    }
}

#[derive(Debug)]
struct SessionRecord {
    session_id: ScanSessionId,
    session: Option<ScanSession>,
    cancellation: CancellationToken,
    cancel_requested: bool,
    events: BoundedEventBuffer,
}

impl SessionRecord {
    fn is_terminal(&self) -> bool {
        self.session.as_ref().is_some_and(|session| {
            matches!(
                session.state(),
                ScanState::Canceled | ScanState::Completed | ScanState::Failed(_)
            )
        })
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct RegistryDiagnostics {
    active_sessions: usize,
    running_sessions: usize,
    completed_sessions: usize,
    cancel_requested_sessions: usize,
    buffered_events: usize,
    stored_cursors: usize,
}

#[derive(Debug, Clone)]
struct CleanupCandidate {
    item_ref: CleanupPlanItemRefDto,
    display_name: String,
    source_path: Option<PathBuf>,
    scan_identity: Option<NodeIdentityEvidence>,
    kind: NodeKind,
    size: fs_usage_core::SizeFact,
    flags: NodeFlags,
    child_completeness: ChildCompleteness,
    issue_count: usize,
    subtree_issue_count: usize,
}

#[derive(Debug, Clone)]
struct CleanupPreflight {
    source_path: PathBuf,
    lock_path: PathBuf,
    identity: NodeIdentityEvidence,
}

#[derive(Debug, Default)]
struct CleanupExecutionLocks {
    active_paths: Mutex<Vec<PathBuf>>,
}

impl CleanupExecutionLocks {
    fn try_acquire(self: &Arc<Self>, paths: Vec<PathBuf>) -> Result<CleanupExecutionGuard, ()> {
        let mut active_paths = self.active_paths.lock().expect("cleanup locks poisoned");
        if paths.iter().any(|path| {
            active_paths
                .iter()
                .any(|active| cleanup_paths_overlap(active, path))
        }) {
            return Err(());
        }
        active_paths.extend(paths.iter().cloned());
        Ok(CleanupExecutionGuard {
            locks: Arc::clone(self),
            paths,
        })
    }
}

#[derive(Debug)]
struct CleanupExecutionGuard {
    locks: Arc<CleanupExecutionLocks>,
    paths: Vec<PathBuf>,
}

impl Drop for CleanupExecutionGuard {
    fn drop(&mut self) {
        let mut active_paths = self
            .locks
            .active_paths
            .lock()
            .expect("cleanup locks poisoned");
        active_paths.retain(|active| !self.paths.iter().any(|path| path == active));
    }
}

#[derive(Debug)]
struct CleanupPlanStore {
    next_plan_id: AtomicU64,
    max_len: usize,
    order: Mutex<VecDeque<u128>>,
    plans: Mutex<HashMap<u128, CleanupPlanRecord>>,
}

impl CleanupPlanStore {
    fn new(max_len: usize) -> Self {
        Self {
            next_plan_id: AtomicU64::new(1),
            max_len: max_len.max(1),
            order: Mutex::new(VecDeque::new()),
            plans: Mutex::new(HashMap::new()),
        }
    }

    fn allocate_plan_id(&self) -> u128 {
        u128::from(self.next_plan_id.fetch_add(1, Ordering::SeqCst).max(1))
    }

    fn insert(&self, plan: CleanupPlanRecord) {
        let mut order = self.order.lock().expect("cleanup plan order poisoned");
        let mut plans = self.plans.lock().expect("cleanup plans poisoned");
        if !plans.contains_key(&plan.plan_id) {
            order.push_back(plan.plan_id);
        }
        plans.insert(plan.plan_id, plan);
        while plans.len() > self.max_len {
            let Some(oldest) = order.pop_front() else {
                break;
            };
            plans.remove(&oldest);
        }
    }

    fn get(&self, plan_id: u128) -> Option<CleanupPlanRecord> {
        self.plans
            .lock()
            .expect("cleanup plans poisoned")
            .get(&plan_id)
            .cloned()
    }
}

#[derive(Debug, Clone)]
struct CleanupPlanRecord {
    plan_id: u128,
    command_id: u128,
    created_at_unix_ms: u64,
    candidates: Vec<CleanupCandidate>,
    preflights: HashMap<u64, Result<CleanupPreflight, String>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum CleanupJournalRecord {
    IntentRecorded {
        operation_id: String,
        command_id: String,
        items: Vec<PersistedCleanupItemRef>,
        at_unix_ms: u64,
    },
    ReceiptSkeletonRecorded {
        operation_id: String,
        command_id: String,
        items: Vec<PersistedCleanupReceiptItem>,
        at_unix_ms: u64,
        low_disk_reserve_ready: bool,
    },
    ItemDispatchRecorded {
        operation_id: String,
        node_id: u64,
        at_unix_ms: u64,
    },
    ItemOutcomeRecorded {
        operation_id: String,
        item: PersistedCleanupReceiptItem,
        at_unix_ms: u64,
    },
    ReceiptFinalized {
        operation_id: String,
        state: CleanupReceiptStateDto,
        at_unix_ms: u64,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct PersistedCleanupItemRef {
    session_id: String,
    snapshot_id: String,
    node_id: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct PersistedCleanupReceiptItem {
    node_id: u64,
    display_name: String,
    state: CleanupItemOutcomeStateDto,
    restore_expectation: RestoreExpectationLevelDto,
    reason: Option<String>,
    resulting_location: Option<String>,
}

#[derive(Debug, Clone)]
pub struct FileCleanupJournal {
    path: PathBuf,
    reserve_path: PathBuf,
    lock: Arc<Mutex<()>>,
}

impl FileCleanupJournal {
    fn default_for_process() -> Self {
        let path = env::var("CLEAN_DISK_CLEANUP_JOURNAL")
            .map(PathBuf::from)
            .unwrap_or_else(|_| env::temp_dir().join("clean-disk-cleanup-journal.jsonl"));
        Self::new(path)
    }

    fn new(path: PathBuf) -> Self {
        let reserve_path = path.with_extension("reserve");
        Self {
            path,
            reserve_path,
            lock: Arc::new(Mutex::new(())),
        }
    }

    fn ensure_ready(&self) -> io::Result<()> {
        if let Some(parent) = self.path.parent() {
            fs::create_dir_all(parent)?;
        }
        if !self.reserve_path.exists() {
            let reserve = File::create(&self.reserve_path)?;
            reserve.set_len(64 * 1024)?;
            reserve.sync_all()?;
        }
        Ok(())
    }

    fn append(&self, record: &CleanupJournalRecord) -> io::Result<()> {
        let _guard = self.lock.lock().expect("cleanup journal lock poisoned");
        self.ensure_ready()?;
        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.path)?;
        serde_json::to_writer(&mut file, record)?;
        file.write_all(b"\n")?;
        file.flush()?;
        file.sync_data()
    }

    fn records(&self) -> io::Result<Vec<CleanupJournalRecord>> {
        let _guard = self.lock.lock().expect("cleanup journal lock poisoned");
        if !self.path.exists() {
            return Ok(Vec::new());
        }
        let contents = fs::read_to_string(&self.path)?;
        contents
            .lines()
            .filter(|line| !line.trim().is_empty())
            .map(|line| {
                serde_json::from_str::<CleanupJournalRecord>(line)
                    .map_err(|error| io::Error::new(io::ErrorKind::InvalidData, error))
            })
            .collect()
    }

    fn receipt_for_command(&self, command_id: u128) -> io::Result<Option<CleanupReceiptDto>> {
        let command_id = command_id.to_string();
        Ok(build_cleanup_receipts(self.records()?)
            .into_iter()
            .find(|receipt| receipt.command_id().as_str() == command_id))
    }

    fn recovery_inbox(&self) -> io::Result<CleanupRecoveryInboxDto> {
        let receipts = build_cleanup_receipts(self.records()?)
            .into_iter()
            .filter(|receipt| {
                matches!(
                    receipt.state(),
                    CleanupReceiptStateDto::InterruptedRequiresReview
                        | CleanupReceiptStateDto::CompletedWithUnknowns
                )
            })
            .collect();
        Ok(CleanupRecoveryInboxDto::new(receipts))
    }
}

#[derive(Debug)]
struct ReceiptAccumulator {
    operation_id: String,
    command_id: String,
    state: CleanupReceiptStateDto,
    started_at_unix_ms: u64,
    updated_at_unix_ms: u64,
    low_disk_reserve_ready: bool,
    items: Vec<PersistedCleanupReceiptItem>,
}

fn build_cleanup_receipts(records: Vec<CleanupJournalRecord>) -> Vec<CleanupReceiptDto> {
    let mut order = Vec::new();
    let mut receipts = HashMap::<String, ReceiptAccumulator>::new();

    for record in records {
        match record {
            CleanupJournalRecord::IntentRecorded {
                operation_id,
                command_id,
                items,
                at_unix_ms,
            } => {
                if !receipts.contains_key(&operation_id) {
                    order.push(operation_id.clone());
                }
                receipts
                    .entry(operation_id.clone())
                    .or_insert_with(|| ReceiptAccumulator {
                        operation_id,
                        command_id,
                        state: CleanupReceiptStateDto::IntentRecorded,
                        started_at_unix_ms: at_unix_ms,
                        updated_at_unix_ms: at_unix_ms,
                        low_disk_reserve_ready: false,
                        items: items
                            .iter()
                            .map(|item| PersistedCleanupReceiptItem {
                                node_id: item.node_id,
                                display_name: format!("node {}", item.node_id),
                                state: CleanupItemOutcomeStateDto::Pending,
                                restore_expectation: RestoreExpectationLevelDto::Unknown,
                                reason: None,
                                resulting_location: None,
                            })
                            .collect(),
                    });
            }
            CleanupJournalRecord::ReceiptSkeletonRecorded {
                operation_id,
                command_id,
                items,
                at_unix_ms,
                low_disk_reserve_ready,
            } => {
                if !receipts.contains_key(&operation_id) {
                    order.push(operation_id.clone());
                }
                receipts.insert(
                    operation_id.clone(),
                    ReceiptAccumulator {
                        operation_id,
                        command_id,
                        state: CleanupReceiptStateDto::ReceiptSkeletonRecorded,
                        started_at_unix_ms: at_unix_ms,
                        updated_at_unix_ms: at_unix_ms,
                        low_disk_reserve_ready,
                        items,
                    },
                );
            }
            CleanupJournalRecord::ItemDispatchRecorded {
                operation_id,
                node_id,
                at_unix_ms,
            } => {
                if let Some(receipt) = receipts.get_mut(&operation_id) {
                    receipt.state = CleanupReceiptStateDto::Running;
                    receipt.updated_at_unix_ms = at_unix_ms;
                    if let Some(item) = receipt
                        .items
                        .iter_mut()
                        .find(|item| item.node_id == node_id)
                    {
                        item.state = CleanupItemOutcomeStateDto::DispatchRecorded;
                    }
                }
            }
            CleanupJournalRecord::ItemOutcomeRecorded {
                operation_id,
                item,
                at_unix_ms,
            } => {
                if let Some(receipt) = receipts.get_mut(&operation_id) {
                    receipt.updated_at_unix_ms = at_unix_ms;
                    if let Some(existing) = receipt
                        .items
                        .iter_mut()
                        .find(|existing| existing.node_id == item.node_id)
                    {
                        *existing = item;
                    }
                }
            }
            CleanupJournalRecord::ReceiptFinalized {
                operation_id,
                state,
                at_unix_ms,
            } => {
                if let Some(receipt) = receipts.get_mut(&operation_id) {
                    receipt.state = state;
                    receipt.updated_at_unix_ms = at_unix_ms;
                }
            }
        }
    }

    order
        .into_iter()
        .filter_map(|operation_id| receipts.remove(&operation_id))
        .map(|mut receipt| {
            if matches!(
                receipt.state,
                CleanupReceiptStateDto::IntentRecorded
                    | CleanupReceiptStateDto::ReceiptSkeletonRecorded
                    | CleanupReceiptStateDto::Running
            ) {
                for item in &mut receipt.items {
                    if item.state == CleanupItemOutcomeStateDto::DispatchRecorded {
                        item.state = CleanupItemOutcomeStateDto::UnknownRequiresReview;
                        item.restore_expectation = RestoreExpectationLevelDto::Unknown;
                        item.reason = Some("dispatch_recorded_without_terminal_outcome".into());
                    }
                }
                receipt.state = if receipt
                    .items
                    .iter()
                    .any(|item| item.state == CleanupItemOutcomeStateDto::UnknownRequiresReview)
                {
                    CleanupReceiptStateDto::CompletedWithUnknowns
                } else {
                    CleanupReceiptStateDto::InterruptedRequiresReview
                };
            }
            cleanup_receipt_to_dto(receipt)
        })
        .collect()
}

fn cleanup_receipt_to_dto(receipt: ReceiptAccumulator) -> CleanupReceiptDto {
    CleanupReceiptDto::new(
        DecimalU128Dto::from_u128(
            receipt
                .operation_id
                .parse()
                .expect("persisted operation id is decimal"),
        ),
        DecimalU128Dto::from_u128(
            receipt
                .command_id
                .parse()
                .expect("persisted command id is decimal"),
        ),
        receipt.state,
        DecimalU64Dto::from_u64(receipt.started_at_unix_ms),
        DecimalU64Dto::from_u64(receipt.updated_at_unix_ms),
        receipt.low_disk_reserve_ready,
        receipt
            .items
            .into_iter()
            .map(|item| {
                CleanupReceiptItemDto::new(
                    DecimalU64Dto::from_u64(item.node_id),
                    item.display_name,
                    item.state,
                    item.restore_expectation,
                    item.reason,
                    item.resulting_location,
                )
            })
            .collect(),
    )
}

#[derive(Debug)]
struct CursorRegistry {
    max_len: usize,
    order: VecDeque<String>,
    values: HashMap<String, StoredCursor>,
}

#[derive(Debug, Clone, Copy)]
struct StoredCursor {
    session_id: ScanSessionId,
    snapshot_id: SnapshotId,
    cursor: PageCursor,
}

impl CursorRegistry {
    fn new(max_len: usize) -> Self {
        Self {
            max_len: max_len.max(1),
            order: VecDeque::new(),
            values: HashMap::new(),
        }
    }

    fn get(
        &self,
        token: &str,
        session_id: ScanSessionId,
        snapshot_id: SnapshotId,
    ) -> Option<PageCursor> {
        self.values
            .get(token)
            .filter(|stored| stored.session_id == session_id && stored.snapshot_id == snapshot_id)
            .map(|stored| stored.cursor)
    }

    fn insert(
        &mut self,
        token: String,
        session_id: ScanSessionId,
        snapshot_id: SnapshotId,
        cursor: PageCursor,
    ) {
        if self.values.len() >= self.max_len
            && let Some(oldest) = self.order.pop_front()
        {
            self.values.remove(&oldest);
        }
        self.order.push_back(token.clone());
        self.values.insert(
            token,
            StoredCursor {
                session_id,
                snapshot_id,
                cursor,
            },
        );
    }

    fn remove_for_session(&mut self, session_id: ScanSessionId) {
        self.values
            .retain(|_, stored| stored.session_id != session_id);
        self.order.retain(|token| self.values.contains_key(token));
    }

    fn len(&self) -> usize {
        self.values.len()
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SessionQueryFailure {
    SessionNotFound,
    SnapshotNotReady,
    InvalidCursor,
    Query(QueryFailure),
}

impl From<QueryFailure> for SessionQueryFailure {
    fn from(value: QueryFailure) -> Self {
        Self::Query(value)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum QueryLimitFailure {
    Zero,
    ExceedsMaximum,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ApiErrorDto {
    code: &'static str,
    message: &'static str,
}

async fn get_capabilities(State(state): State<AppState>, headers: HeaderMap) -> Response {
    if let Err(status) = authorize(&state, &headers) {
        return status.into_response();
    }

    Json(capability_response(&state)).into_response()
}

async fn probe_permission(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(request): Json<PermissionProbeRequestDto>,
) -> Response {
    if let Err(status) = authorize(&state, &headers) {
        return status.into_response();
    }
    if !PROTOCOL_VERSION.is_compatible_with(request.protocol_version()) {
        return error_response(
            StatusCode::BAD_REQUEST,
            "incompatible_protocol",
            "protocol version is not compatible",
        );
    }

    match map_target(request.target()) {
        Ok(target) => Json(probe_target_permission(&target)).into_response(),
        Err(error) => error_response(StatusCode::BAD_REQUEST, "invalid_target", error),
    }
}

async fn start_scan(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(request): Json<StartScanRequestDto>,
) -> Response {
    if let Err(status) = authorize(&state, &headers) {
        return status.into_response();
    }

    let session_id = state.registry().allocate_session_id();
    let scan_request = match map_scan_request(session_id, &request) {
        Ok(request) => request,
        Err(error) => return error_response(StatusCode::BAD_REQUEST, "invalid_request", error),
    };
    let permit = match state.registry().try_acquire_scan() {
        Ok(permit) => permit,
        Err(RuntimeAdmissionError::ResourceExhausted { .. }) => {
            return error_response(
                StatusCode::TOO_MANY_REQUESTS,
                "resource_exhausted",
                "scanner worker pool is full",
            );
        }
    };
    let cancellation = CancellationToken::new();
    let registry = state.registry();
    registry.insert_running(session_id, cancellation.clone());
    let backend = state.backend();

    tokio::task::spawn_blocking(move || {
        let _permit = permit;
        let mut sink = RegistryEventSink {
            registry: Arc::clone(&registry),
            session_id,
        };
        let mut session = ScanSession::new(session_id);
        let _ = session.start(backend.as_ref(), scan_request, &mut sink, &cancellation);
        registry.complete(session_id, session);
    });

    let status = state
        .registry()
        .status(session_id)
        .expect("session was inserted before task spawn");
    (StatusCode::ACCEPTED, Json(status)).into_response()
}

async fn get_scan_status(
    State(state): State<AppState>,
    headers: HeaderMap,
    AxumPath(session_id): AxumPath<u128>,
) -> Response {
    if let Err(status) = authorize(&state, &headers) {
        return status.into_response();
    }

    let Some(session_id) = ScanSessionId::new(session_id) else {
        return error_response(
            StatusCode::BAD_REQUEST,
            "invalid_session_id",
            "session id is zero",
        );
    };
    match state.registry().status(session_id) {
        Some(status) => Json(status).into_response(),
        None => error_response(
            StatusCode::NOT_FOUND,
            "not_found",
            "scan session was not found",
        ),
    }
}

async fn cancel_scan(
    State(state): State<AppState>,
    headers: HeaderMap,
    AxumPath(session_id): AxumPath<u128>,
    Json(request): Json<CancelScanRequestDto>,
) -> Response {
    if let Err(status) = authorize(&state, &headers) {
        return status.into_response();
    }

    let Some(path_session_id) = ScanSessionId::new(session_id) else {
        return error_response(
            StatusCode::BAD_REQUEST,
            "invalid_session_id",
            "session id is zero",
        );
    };
    let Some(body_session_id) = ScanSessionId::new(request.session_id().to_u128()) else {
        return error_response(
            StatusCode::BAD_REQUEST,
            "invalid_session_id",
            "session id is zero",
        );
    };
    if path_session_id != body_session_id {
        return error_response(
            StatusCode::BAD_REQUEST,
            "session_mismatch",
            "path and body session ids differ",
        );
    }
    if !PROTOCOL_VERSION.is_compatible_with(request.protocol_version()) {
        return error_response(
            StatusCode::BAD_REQUEST,
            "invalid_request",
            "protocol version is not compatible",
        );
    }

    match state.registry().cancel(path_session_id) {
        Some(status) => Json(status).into_response(),
        None => error_response(
            StatusCode::NOT_FOUND,
            "not_found",
            "scan session was not found",
        ),
    }
}

async fn dispose_scan(
    State(state): State<AppState>,
    headers: HeaderMap,
    AxumPath(session_id): AxumPath<u128>,
    Json(request): Json<DisposeScanSessionRequestDto>,
) -> Response {
    if let Err(status) = authorize(&state, &headers) {
        return status.into_response();
    }

    let Some(path_session_id) = ScanSessionId::new(session_id) else {
        return invalid_session_response();
    };
    let Some(body_session_id) = ScanSessionId::new(request.session_id().to_u128()) else {
        return invalid_session_response();
    };
    if path_session_id != body_session_id {
        return error_response(
            StatusCode::BAD_REQUEST,
            "session_mismatch",
            "path and body session ids differ",
        );
    }
    if !PROTOCOL_VERSION.is_compatible_with(request.protocol_version()) {
        return error_response(
            StatusCode::BAD_REQUEST,
            "invalid_request",
            "protocol version is not compatible",
        );
    }

    if state.registry().dispose(path_session_id) {
        StatusCode::NO_CONTENT.into_response()
    } else {
        error_response(
            StatusCode::NOT_FOUND,
            "not_found",
            "scan session was not found",
        )
    }
}

async fn get_children_page(
    State(state): State<AppState>,
    headers: HeaderMap,
    AxumPath(session_id): AxumPath<u128>,
    Json(request): Json<ChildrenPageRequestDto>,
) -> Response {
    if let Err(status) = authorize(&state, &headers) {
        return status.into_response();
    }

    let Some(session_id) = parse_session_id(session_id) else {
        return invalid_session_response();
    };
    let Some(snapshot_id) = parse_snapshot_id(request.snapshot_id().to_u128()) else {
        return invalid_snapshot_response();
    };
    let Some(parent_id) = parse_node_id(request.parent_id().to_u64()) else {
        return invalid_node_response();
    };
    let limit = match validate_query_limit(request.limit().to_usize(), state.budget()) {
        Ok(limit) => limit,
        Err(error) => return query_limit_error_response(error),
    };
    let cursor = match state
        .registry()
        .resolve_cursor(session_id, snapshot_id, request.cursor())
    {
        Ok(cursor) => cursor,
        Err(error) => return query_error_response(error),
    };
    let query = ChildrenPageQuery::new_sorted(
        snapshot_id,
        parent_id,
        cursor,
        limit,
        map_child_sort(request.sort()),
    );

    match state.registry().children_page(session_id, query) {
        Ok(page) => Json(map_node_page_response(
            session_id,
            snapshot_id,
            page,
            &state.registry(),
        ))
        .into_response(),
        Err(error) => query_error_response(error),
    }
}

async fn search_nodes(
    State(state): State<AppState>,
    headers: HeaderMap,
    AxumPath(session_id): AxumPath<u128>,
    Json(request): Json<SearchPageRequestDto>,
) -> Response {
    if let Err(status) = authorize(&state, &headers) {
        return status.into_response();
    }

    let Some(session_id) = parse_session_id(session_id) else {
        return invalid_session_response();
    };
    let Some(snapshot_id) = parse_snapshot_id(request.snapshot_id().to_u128()) else {
        return invalid_snapshot_response();
    };
    let limit = match validate_query_limit(request.limit().to_usize(), state.budget()) {
        Ok(limit) => limit,
        Err(error) => return query_limit_error_response(error),
    };
    let cursor = match state
        .registry()
        .resolve_cursor(session_id, snapshot_id, request.cursor())
    {
        Ok(cursor) => cursor,
        Err(error) => return query_error_response(error),
    };
    let query = SearchQuery::new(snapshot_id, request.search_text().as_str(), cursor, limit);

    match state.registry().search_page(session_id, query) {
        Ok(page) => Json(map_node_page_response(
            session_id,
            snapshot_id,
            page,
            &state.registry(),
        ))
        .into_response(),
        Err(error) => query_error_response(error),
    }
}

async fn get_top_items(
    State(state): State<AppState>,
    headers: HeaderMap,
    AxumPath(session_id): AxumPath<u128>,
    Json(request): Json<TopItemsRequestDto>,
) -> Response {
    if let Err(status) = authorize(&state, &headers) {
        return status.into_response();
    }

    let Some(session_id) = parse_session_id(session_id) else {
        return invalid_session_response();
    };
    let Some(snapshot_id) = parse_snapshot_id(request.snapshot_id().to_u128()) else {
        return invalid_snapshot_response();
    };
    let limit = match validate_query_limit(request.limit().to_usize(), state.budget()) {
        Ok(limit) => limit,
        Err(error) => return query_limit_error_response(error),
    };
    let cursor = match state
        .registry()
        .resolve_cursor(session_id, snapshot_id, request.cursor())
    {
        Ok(cursor) => cursor,
        Err(error) => return query_error_response(error),
    };
    let query = TopItemsQuery::new(
        snapshot_id,
        map_top_items_kind(request.kind()),
        cursor,
        limit,
    );

    match state.registry().top_items_page(session_id, query) {
        Ok(page) => Json(map_node_page_response(
            session_id,
            snapshot_id,
            page,
            &state.registry(),
        ))
        .into_response(),
        Err(error) => query_error_response(error),
    }
}

async fn get_node_details(
    State(state): State<AppState>,
    headers: HeaderMap,
    AxumPath(session_id): AxumPath<u128>,
    Json(request): Json<NodeDetailsRequestDto>,
) -> Response {
    if let Err(status) = authorize(&state, &headers) {
        return status.into_response();
    }

    let Some(session_id) = parse_session_id(session_id) else {
        return invalid_session_response();
    };
    let Some(snapshot_id) = parse_snapshot_id(request.snapshot_id().to_u128()) else {
        return invalid_snapshot_response();
    };
    let Some(node_id) = parse_node_id(request.node_id().to_u64()) else {
        return invalid_node_response();
    };
    let query = NodeDetailsQuery::new(snapshot_id, node_id);

    match state.registry().node_details(session_id, query) {
        Ok(details) => Json(map_node_details_response(snapshot_id, details)).into_response(),
        Err(error) => query_error_response(error),
    }
}

async fn create_cleanup_plan(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(request): Json<CreateCleanupPlanRequestDto>,
) -> Response {
    if let Err(status) = authorize(&state, &headers) {
        return status.into_response();
    }

    let command_id = match validate_cleanup_plan_request(
        request.protocol_version(),
        request.command_id(),
        request.items(),
    ) {
        Ok(command_id) => command_id,
        Err(response) => return response,
    };
    let plan_id = state.cleanup_plans().allocate_plan_id();
    let plan = match build_cleanup_plan_record(&state, plan_id, command_id, request.items()) {
        Ok(plan) => plan,
        Err(response) => return response,
    };
    state.cleanup_plans().insert(plan.clone());

    Json(map_cleanup_plan_record(&plan)).into_response()
}

async fn execute_cleanup_plan(
    State(state): State<AppState>,
    headers: HeaderMap,
    AxumPath(plan_id): AxumPath<u128>,
    Json(request): Json<ExecuteCleanupPlanRequestDto>,
) -> Response {
    if let Err(status) = authorize(&state, &headers) {
        return status.into_response();
    }

    let command_id = match validate_cleanup_protocol_and_command(
        request.protocol_version(),
        request.command_id(),
    ) {
        Ok(command_id) => command_id,
        Err(response) => return response,
    };
    if plan_id == 0 {
        return error_response(
            StatusCode::BAD_REQUEST,
            "invalid_cleanup_plan_id",
            "cleanup plan id is zero",
        );
    }
    let body_plan_id = request.plan_id().to_u128();
    if body_plan_id == 0 {
        return error_response(
            StatusCode::BAD_REQUEST,
            "invalid_cleanup_plan_id",
            "cleanup plan id is zero",
        );
    }
    if plan_id != body_plan_id {
        return error_response(
            StatusCode::BAD_REQUEST,
            "cleanup_plan_mismatch",
            "path and body cleanup plan ids differ",
        );
    }

    let Some(plan) = state.cleanup_plans().get(plan_id) else {
        return error_response(
            StatusCode::NOT_FOUND,
            "cleanup_plan_not_found",
            "cleanup plan was not found",
        );
    };

    execute_cleanup_record(&state, command_id, &plan)
}

async fn execute_cleanup(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(request): Json<ExecuteCleanupRequestDto>,
) -> Response {
    if let Err(status) = authorize(&state, &headers) {
        return status.into_response();
    }

    let command_id = match validate_cleanup_plan_request(
        request.protocol_version(),
        request.command_id(),
        request.items(),
    ) {
        Ok(command_id) => command_id,
        Err(response) => return response,
    };
    let plan = match build_cleanup_plan_record(&state, 0, command_id, request.items()) {
        Ok(plan) => plan,
        Err(response) => return response,
    };

    execute_cleanup_record(&state, command_id, &plan)
}

fn execute_cleanup_record(
    state: &AppState,
    command_id: u128,
    plan: &CleanupPlanRecord,
) -> Response {
    let operation_id = command_id.to_string();
    let command_id_wire = command_id.to_string();
    let journal = state.cleanup_journal();
    match journal.receipt_for_command(command_id) {
        Ok(Some(receipt)) => return Json(receipt).into_response(),
        Ok(None) => {}
        Err(_) => {
            return error_response(
                StatusCode::INSUFFICIENT_STORAGE,
                "cleanup_journal_unavailable",
                "cleanup journal cannot be read",
            );
        }
    }

    let lock_paths = plan
        .preflights
        .values()
        .filter_map(|preflight| {
            preflight
                .as_ref()
                .ok()
                .map(|preflight| preflight.lock_path.clone())
        })
        .collect::<Vec<_>>();
    let _cleanup_guard = if lock_paths.is_empty() {
        None
    } else {
        match state.cleanup_locks().try_acquire(lock_paths) {
            Ok(guard) => Some(guard),
            Err(()) => {
                return error_response(
                    StatusCode::CONFLICT,
                    "active_cleanup_conflict",
                    "another cleanup operation is already handling an overlapping path",
                );
            }
        }
    };
    if let Err(error) = journal.ensure_ready() {
        return cleanup_journal_error_response(error);
    }

    let now = now_unix_ms();
    let refs = plan
        .candidates
        .iter()
        .map(|candidate| PersistedCleanupItemRef {
            session_id: candidate.item_ref.session_id().as_str().to_string(),
            snapshot_id: candidate.item_ref.snapshot_id().as_str().to_string(),
            node_id: candidate.item_ref.node_id().to_u64(),
        })
        .collect::<Vec<_>>();
    if let Err(error) = journal.append(&CleanupJournalRecord::IntentRecorded {
        operation_id: operation_id.clone(),
        command_id: command_id_wire.clone(),
        items: refs,
        at_unix_ms: now,
    }) {
        return cleanup_journal_error_response(error);
    }

    let skeleton_items = plan
        .candidates
        .iter()
        .map(|candidate| PersistedCleanupReceiptItem {
            node_id: candidate.item_ref.node_id().to_u64(),
            display_name: candidate.display_name.clone(),
            state: CleanupItemOutcomeStateDto::Pending,
            restore_expectation: RestoreExpectationLevelDto::Unknown,
            reason: None,
            resulting_location: None,
        })
        .collect::<Vec<_>>();
    if let Err(error) = journal.append(&CleanupJournalRecord::ReceiptSkeletonRecorded {
        operation_id: operation_id.clone(),
        command_id: command_id_wire.clone(),
        items: skeleton_items,
        at_unix_ms: now_unix_ms(),
        low_disk_reserve_ready: true,
    }) {
        return cleanup_journal_error_response(error);
    }

    let trash_adapter = state.trash_adapter();
    for candidate in plan.candidates.iter().cloned() {
        let node_id = candidate.item_ref.node_id().to_u64();
        let initial_preflight = match plan
            .preflights
            .get(&node_id)
            .expect("preflight exists for every candidate")
        {
            Ok(preflight) => preflight,
            Err(reason) => {
                let item = cleanup_outcome_item(
                    &candidate,
                    CleanupItemOutcomeStateDto::Blocked,
                    RestoreExpectationLevelDto::NotRestorable,
                    Some(reason.clone()),
                    None,
                );
                if let Err(error) = journal.append(&CleanupJournalRecord::ItemOutcomeRecorded {
                    operation_id: operation_id.clone(),
                    item,
                    at_unix_ms: now_unix_ms(),
                }) {
                    return cleanup_journal_error_response(error);
                }
                continue;
            }
        };
        let current_preflight = match preflight_cleanup_candidate(&candidate) {
            Ok(preflight) => preflight,
            Err(reason) => {
                let item = cleanup_outcome_item(
                    &candidate,
                    CleanupItemOutcomeStateDto::Blocked,
                    RestoreExpectationLevelDto::NotRestorable,
                    Some(reason),
                    None,
                );
                if let Err(error) = journal.append(&CleanupJournalRecord::ItemOutcomeRecorded {
                    operation_id: operation_id.clone(),
                    item,
                    at_unix_ms: now_unix_ms(),
                }) {
                    return cleanup_journal_error_response(error);
                }
                continue;
            }
        };
        if current_preflight.identity != initial_preflight.identity
            || current_preflight.lock_path != initial_preflight.lock_path
        {
            let item = cleanup_outcome_item(
                &candidate,
                CleanupItemOutcomeStateDto::Blocked,
                RestoreExpectationLevelDto::NotRestorable,
                Some("stale_identity_changed".to_string()),
                None,
            );
            if let Err(error) = journal.append(&CleanupJournalRecord::ItemOutcomeRecorded {
                operation_id: operation_id.clone(),
                item,
                at_unix_ms: now_unix_ms(),
            }) {
                return cleanup_journal_error_response(error);
            }
            continue;
        }

        if let Err(error) = journal.append(&CleanupJournalRecord::ItemDispatchRecorded {
            operation_id: operation_id.clone(),
            node_id,
            at_unix_ms: now_unix_ms(),
        }) {
            return cleanup_journal_error_response(error);
        }

        let item = match trash_adapter.move_to_trash(&current_preflight.source_path) {
            Ok(outcome) => cleanup_outcome_item(
                &candidate,
                CleanupItemOutcomeStateDto::MovedToTrash,
                map_restore_expectation(outcome.restore_expectation()),
                None,
                outcome.resulting_location().map(ToOwned::to_owned),
            ),
            Err(error) => cleanup_outcome_item(
                &candidate,
                CleanupItemOutcomeStateDto::Failed,
                RestoreExpectationLevelDto::Unknown,
                Some(match error {
                    TrashFailure::Unsupported => "trash_unsupported".to_string(),
                    TrashFailure::AdapterFailed { message } => message,
                }),
                None,
            ),
        };
        if let Err(error) = journal.append(&CleanupJournalRecord::ItemOutcomeRecorded {
            operation_id: operation_id.clone(),
            item,
            at_unix_ms: now_unix_ms(),
        }) {
            return cleanup_journal_error_response(error);
        }
    }

    let receipt = match journal.receipt_for_command(command_id) {
        Ok(Some(receipt)) => receipt,
        Ok(None) => {
            return error_response(
                StatusCode::INTERNAL_SERVER_ERROR,
                "cleanup_receipt_missing",
                "cleanup receipt was not found after execution",
            );
        }
        Err(error) => return cleanup_journal_error_response(error),
    };
    let final_state = cleanup_final_state(&receipt);
    if let Err(error) = journal.append(&CleanupJournalRecord::ReceiptFinalized {
        operation_id: operation_id.clone(),
        state: final_state,
        at_unix_ms: now_unix_ms(),
    }) {
        return cleanup_journal_error_response(error);
    }

    match journal.receipt_for_command(command_id) {
        Ok(Some(receipt)) => Json(receipt).into_response(),
        Ok(None) => error_response(
            StatusCode::INTERNAL_SERVER_ERROR,
            "cleanup_receipt_missing",
            "cleanup receipt was not found after finalization",
        ),
        Err(error) => cleanup_journal_error_response(error),
    }
}

fn validate_cleanup_protocol_and_command(
    protocol_version: clean_disk_protocol::ProtocolVersionDto,
    command_id: &DecimalU128Dto,
) -> Result<u128, Response> {
    if !PROTOCOL_VERSION.is_compatible_with(protocol_version) {
        return Err(error_response(
            StatusCode::BAD_REQUEST,
            "incompatible_protocol",
            "protocol version is not compatible",
        ));
    }

    let command_id = command_id.to_u128();
    if command_id == 0 {
        return Err(error_response(
            StatusCode::BAD_REQUEST,
            "invalid_command_id",
            "command id is zero",
        ));
    }
    Ok(command_id)
}

fn validate_cleanup_plan_request(
    protocol_version: clean_disk_protocol::ProtocolVersionDto,
    command_id: &DecimalU128Dto,
    items: &[CleanupPlanItemRefDto],
) -> Result<u128, Response> {
    let command_id = validate_cleanup_protocol_and_command(protocol_version, command_id)?;
    if items.is_empty() {
        return Err(error_response(
            StatusCode::BAD_REQUEST,
            "empty_cleanup_plan",
            "cleanup plan must contain at least one item",
        ));
    }
    if has_duplicate_cleanup_item_refs(items) {
        return Err(error_response(
            StatusCode::BAD_REQUEST,
            "duplicate_cleanup_item",
            "cleanup plan contains duplicate item references",
        ));
    }
    if has_mixed_cleanup_snapshot_refs(items) {
        return Err(error_response(
            StatusCode::BAD_REQUEST,
            "mixed_cleanup_snapshot",
            "cleanup plan items must belong to one session snapshot",
        ));
    }
    Ok(command_id)
}

fn build_cleanup_plan_record(
    state: &AppState,
    plan_id: u128,
    command_id: u128,
    items: &[CleanupPlanItemRefDto],
) -> Result<CleanupPlanRecord, Response> {
    let candidates = resolve_cleanup_candidates(state, items)?;
    let preflights = candidates
        .iter()
        .map(|candidate| {
            (
                candidate.item_ref.node_id().to_u64(),
                preflight_cleanup_candidate(candidate),
            )
        })
        .collect::<HashMap<_, _>>();
    let lock_paths = preflights
        .values()
        .filter_map(|preflight| {
            preflight
                .as_ref()
                .ok()
                .map(|preflight| preflight.lock_path.clone())
        })
        .collect::<Vec<_>>();
    if cleanup_paths_have_overlap(&lock_paths) {
        return Err(error_response(
            StatusCode::BAD_REQUEST,
            "overlapping_cleanup_items",
            "cleanup plan contains overlapping paths",
        ));
    }

    Ok(CleanupPlanRecord {
        plan_id,
        command_id,
        created_at_unix_ms: now_unix_ms(),
        candidates,
        preflights,
    })
}

fn map_cleanup_plan_record(plan: &CleanupPlanRecord) -> CleanupPlanDto {
    let items = plan
        .candidates
        .iter()
        .map(|candidate| {
            let node_id = candidate.item_ref.node_id().to_u64();
            let (state, reason) = match plan
                .preflights
                .get(&node_id)
                .expect("preflight exists for every candidate")
            {
                Ok(_) => (CleanupPlanItemStateDto::Ready, None),
                Err(reason) => (CleanupPlanItemStateDto::Blocked, Some(reason.clone())),
            };
            CleanupPlanItemDto::new(
                candidate.item_ref.clone(),
                candidate.display_name.clone(),
                state,
                reason,
            )
        })
        .collect::<Vec<_>>();
    let state = if items
        .iter()
        .all(|item| item.state() == CleanupPlanItemStateDto::Ready)
    {
        CleanupPlanStateDto::Ready
    } else {
        CleanupPlanStateDto::Blocked
    };

    CleanupPlanDto::new(
        DecimalU128Dto::from_u128(plan.plan_id),
        DecimalU128Dto::from_u128(plan.command_id),
        state,
        DecimalU64Dto::from_u64(plan.created_at_unix_ms),
        items,
    )
}

async fn get_cleanup_recovery_inbox(State(state): State<AppState>, headers: HeaderMap) -> Response {
    if let Err(status) = authorize(&state, &headers) {
        return status.into_response();
    }

    match state.cleanup_journal().recovery_inbox() {
        Ok(inbox) => Json(inbox).into_response(),
        Err(error) => cleanup_journal_error_response(error),
    }
}

fn resolve_cleanup_candidates(
    state: &AppState,
    items: &[CleanupPlanItemRefDto],
) -> Result<Vec<CleanupCandidate>, Response> {
    items
        .iter()
        .map(|item| {
            let session_id = parse_session_id(item.session_id().to_u128())
                .ok_or_else(invalid_session_response)?;
            let snapshot_id = parse_snapshot_id(item.snapshot_id().to_u128())
                .ok_or_else(invalid_snapshot_response)?;
            let node_id =
                parse_node_id(item.node_id().to_u64()).ok_or_else(invalid_node_response)?;
            let record = state
                .registry()
                .node_record(session_id, snapshot_id, node_id)
                .map_err(query_error_response)?;
            Ok(CleanupCandidate {
                item_ref: item.clone(),
                display_name: record.name().to_string(),
                source_path: record.source_path().map(Path::to_path_buf),
                scan_identity: record.identity_evidence().cloned(),
                kind: record.kind(),
                size: record.size(),
                flags: record.flags(),
                child_completeness: record.child_completeness(),
                issue_count: record.issues().len(),
                subtree_issue_count: record.subtree_issue_count(),
            })
        })
        .collect()
}

fn has_duplicate_cleanup_item_refs(items: &[CleanupPlanItemRefDto]) -> bool {
    let mut seen = HashSet::with_capacity(items.len());
    items.iter().any(|item| {
        !seen.insert((
            item.session_id().as_str().to_string(),
            item.snapshot_id().as_str().to_string(),
            item.node_id().to_u64(),
        ))
    })
}

fn has_mixed_cleanup_snapshot_refs(items: &[CleanupPlanItemRefDto]) -> bool {
    let Some(first) = items.first() else {
        return false;
    };
    items.iter().skip(1).any(|item| {
        item.session_id().as_str() != first.session_id().as_str()
            || item.snapshot_id().as_str() != first.snapshot_id().as_str()
    })
}

fn preflight_cleanup_candidate(candidate: &CleanupCandidate) -> Result<CleanupPreflight, String> {
    let Some(path) = candidate.source_path.as_deref() else {
        return Err("missing_path_evidence".to_string());
    };
    if !matches!(
        candidate.kind,
        NodeKind::File | NodeKind::Directory | NodeKind::Unknown
    ) {
        return Err("unsupported_cleanup_kind".to_string());
    }
    if candidate.flags.system || candidate.flags.package || candidate.flags.symlink {
        return Err("policy_conflict".to_string());
    }
    if candidate.child_completeness != ChildCompleteness::Complete
        || candidate.issue_count > 0
        || candidate.subtree_issue_count > 0
    {
        return Err("scan_issue_or_incomplete_subtree".to_string());
    }

    let metadata = match fs::symlink_metadata(path) {
        Ok(metadata) => metadata,
        Err(error) if error.kind() == io::ErrorKind::NotFound => {
            return Err("stale_missing_path".to_string());
        }
        Err(error) if error.kind() == io::ErrorKind::PermissionDenied => {
            return Err("permission_denied".to_string());
        }
        Err(error) => return Err(format!("metadata_revalidation_failed:{error}")),
    };
    if metadata.file_type().is_symlink() {
        return Err("stale_changed_kind".to_string());
    }
    if !metadata.is_file() && !metadata.is_dir() {
        return Err("unsupported_cleanup_kind".to_string());
    }
    match candidate.kind {
        NodeKind::File if !metadata.is_file() => {
            return Err("stale_changed_kind".to_string());
        }
        NodeKind::Directory if !metadata.is_dir() => {
            return Err("stale_changed_kind".to_string());
        }
        _ => {}
    }
    if candidate.kind == NodeKind::File
        && let Some(bytes) = candidate.size.byte_equivalent()
        && metadata.len() != bytes.get()
    {
        return Err("stale_changed_size".to_string());
    }
    let identity = metadata_identity_evidence(&metadata);
    if let Some(reason) = identity_mismatch_reason(candidate.scan_identity.as_ref(), &identity) {
        return Err(reason);
    }
    let lock_path =
        fs::canonicalize(path).map_err(|error| format!("canonicalize_failed:{error}"))?;
    Ok(CleanupPreflight {
        source_path: path.to_path_buf(),
        lock_path,
        identity,
    })
}

fn identity_mismatch_reason(
    scan_identity: Option<&NodeIdentityEvidence>,
    current_identity: &NodeIdentityEvidence,
) -> Option<String> {
    let scan_identity = scan_identity?;
    if let (Some(scan), Some(current)) = (
        scan_identity.platform_file_id(),
        current_identity.platform_file_id(),
    ) && scan != current
    {
        return Some("stale_identity_changed".to_string());
    }
    if let (Some(scan), Some(current)) = (
        scan_identity.modified_unix_nanos(),
        current_identity.modified_unix_nanos(),
    ) && scan != current
    {
        return Some("stale_modified".to_string());
    }
    if let (Some(scan), Some(current)) = (scan_identity.size_bytes(), current_identity.size_bytes())
        && scan != current
    {
        return Some("stale_changed_size".to_string());
    }
    None
}

fn cleanup_paths_have_overlap(paths: &[PathBuf]) -> bool {
    for (index, path) in paths.iter().enumerate() {
        if paths
            .iter()
            .skip(index + 1)
            .any(|other| cleanup_paths_overlap(path, other))
        {
            return true;
        }
    }
    false
}

fn cleanup_paths_overlap(left: &Path, right: &Path) -> bool {
    left == right || left.starts_with(right) || right.starts_with(left)
}

fn cleanup_outcome_item(
    candidate: &CleanupCandidate,
    state: CleanupItemOutcomeStateDto,
    restore_expectation: RestoreExpectationLevelDto,
    reason: Option<String>,
    resulting_location: Option<String>,
) -> PersistedCleanupReceiptItem {
    PersistedCleanupReceiptItem {
        node_id: candidate.item_ref.node_id().to_u64(),
        display_name: candidate.display_name.clone(),
        state,
        restore_expectation,
        reason,
        resulting_location,
    }
}

fn map_restore_expectation(level: RestoreExpectationLevel) -> RestoreExpectationLevelDto {
    match level {
        RestoreExpectationLevel::PlatformTrashManual => {
            RestoreExpectationLevelDto::PlatformTrashManual
        }
        RestoreExpectationLevel::Unknown => RestoreExpectationLevelDto::Unknown,
    }
}

fn cleanup_final_state(receipt: &CleanupReceiptDto) -> CleanupReceiptStateDto {
    if receipt
        .items()
        .iter()
        .any(|item| item.state() == CleanupItemOutcomeStateDto::UnknownRequiresReview)
    {
        return CleanupReceiptStateDto::CompletedWithUnknowns;
    }
    if receipt.items().iter().any(|item| {
        matches!(
            item.state(),
            CleanupItemOutcomeStateDto::Blocked | CleanupItemOutcomeStateDto::Failed
        )
    }) {
        return CleanupReceiptStateDto::CompletedWithFailures;
    }
    CleanupReceiptStateDto::Completed
}

async fn get_diagnostics(State(state): State<AppState>, headers: HeaderMap) -> Response {
    if let Err(status) = authorize(&state, &headers) {
        return status.into_response();
    }

    Json(map_diagnostics(
        state.registry().diagnostics(),
        state.config().auth_required(),
    ))
    .into_response()
}

async fn open_events_socket(
    State(state): State<AppState>,
    headers: HeaderMap,
    websocket: WebSocketUpgrade,
) -> Response {
    if let Err(status) = authorize_events_socket(&state, &headers) {
        return status.into_response();
    }

    let registry = state.registry();
    websocket
        .protocols([EVENTS_WEBSOCKET_SUBPROTOCOL])
        .on_upgrade(move |mut socket| async move {
            let mut events = registry.subscribe_events();
            let replay = registry.event_envelopes();
            let replay_high_watermark = replay.last().map_or(0, |event| event.sequence().to_u64());

            for envelope in replay {
                let Ok(text) = serde_json::to_string(&envelope) else {
                    continue;
                };
                if socket.send(Message::Text(text.into())).await.is_err() {
                    return;
                }
            }

            loop {
                match events.recv().await {
                    Ok(envelope) => {
                        if envelope.sequence().to_u64() <= replay_high_watermark {
                            continue;
                        }
                        let Ok(text) = serde_json::to_string(&envelope) else {
                            continue;
                        };
                        if socket.send(Message::Text(text.into())).await.is_err() {
                            return;
                        }
                    }
                    Err(broadcast::error::RecvError::Lagged(_)) => continue,
                    Err(broadcast::error::RecvError::Closed) => return,
                }
            }
        })
        .into_response()
}

fn authorize(state: &AppState, headers: &HeaderMap) -> Result<(), StatusCode> {
    if !origin_is_allowed(state.config(), headers.get("origin")) {
        return Err(StatusCode::FORBIDDEN);
    }

    let Some(expected) = &state.config().local_auth_token else {
        return Ok(());
    };
    match headers
        .get("authorization")
        .and_then(|value| value.to_str().ok())
    {
        _ if expected.trim().is_empty() => Err(StatusCode::UNAUTHORIZED),
        Some(actual) if bearer_token_matches(actual, expected) => Ok(()),
        _ => Err(StatusCode::UNAUTHORIZED),
    }
}

fn authorize_events_socket(state: &AppState, headers: &HeaderMap) -> Result<(), StatusCode> {
    if !origin_is_allowed(state.config(), headers.get("origin")) {
        return Err(StatusCode::FORBIDDEN);
    }

    let Some(expected) = &state.config().local_auth_token else {
        return Ok(());
    };
    if expected.trim().is_empty() {
        return Err(StatusCode::UNAUTHORIZED);
    }
    if headers
        .get("authorization")
        .and_then(|value| value.to_str().ok())
        .is_some_and(|actual| bearer_token_matches(actual, expected))
    {
        return Ok(());
    }
    if websocket_protocol_token_matches(headers, expected) {
        return Ok(());
    }
    Err(StatusCode::UNAUTHORIZED)
}

fn origin_is_allowed(config: &ServerConfig, origin: Option<&HeaderValue>) -> bool {
    let Some(origin) = origin.and_then(|value| value.to_str().ok()) else {
        return true;
    };
    config
        .allowed_origins
        .iter()
        .any(|allowed| origin_matches_allowed(origin, allowed))
}

fn origin_matches_allowed(origin: &str, allowed: &str) -> bool {
    if origin == allowed {
        return true;
    }
    origin
        .strip_prefix(allowed)
        .and_then(|suffix| suffix.strip_prefix(':'))
        .is_some_and(|port| !port.is_empty() && port.parse::<u16>().is_ok())
}

fn bearer_token_matches(actual: &str, expected_token: &str) -> bool {
    let expected = format!("Bearer {expected_token}");
    constant_time_eq(actual.as_bytes(), expected.as_bytes())
}

fn websocket_protocol_token_matches(headers: &HeaderMap, expected_token: &str) -> bool {
    headers
        .get_all("sec-websocket-protocol")
        .iter()
        .filter_map(|value| value.to_str().ok())
        .flat_map(|value| value.split(','))
        .map(str::trim)
        .filter_map(|protocol| protocol.strip_prefix(EVENTS_WEBSOCKET_TOKEN_PREFIX))
        .any(|actual| constant_time_eq(actual.as_bytes(), expected_token.as_bytes()))
}

fn constant_time_eq(left: &[u8], right: &[u8]) -> bool {
    let max_len = left.len().max(right.len());
    let mut diff = left.len() ^ right.len();
    for index in 0..max_len {
        let left_byte = *left.get(index).unwrap_or(&0);
        let right_byte = *right.get(index).unwrap_or(&0);
        diff |= usize::from(left_byte ^ right_byte);
    }
    diff == 0
}

fn capability_response(state: &AppState) -> CapabilityResponseDto {
    let capabilities = state.backend().capabilities();
    let budget = state.budget();
    CapabilityResponseDto::new(
        PROTOCOL_VERSION,
        ScannerCapabilityDto::new(
            capabilities.backend_name().to_string(),
            map_capabilities(capabilities),
        ),
        ProtocolLimitDto::new(
            DecimalUsizeDto::from_usize(budget.max_query_page_size().get()),
            DecimalUsizeDto::from_usize(budget.max_event_queue_items().get()),
        ),
        runtime_proof(),
    )
}

fn runtime_proof() -> RuntimeProofDto {
    runtime_proof_from_packaging(packaging_proof())
}

fn runtime_proof_from_packaging(packaging: PackagingProofDto) -> RuntimeProofDto {
    let process_kind = packaging.scanner_process();
    let verification =
        if packaging.signed_build() && process_kind != ScannerProcessKindDto::ExternalProcess {
            ScannerIdentityVerificationDto::Verified
        } else {
            ScannerIdentityVerificationDto::Unverified
        };
    RuntimeProofDto::new(
        ScannerIdentityProofDto::new(
            runtime_platform(),
            process_kind,
            verification,
            current_executable_path(),
            env::var("CLEAN_DISK_BUNDLE_IDENTIFIER").ok(),
        ),
        PermissionProbeDto::new(
            PermissionProbeStatusDto::NotProbed,
            None,
            PermissionRequiredActionDto::None,
        ),
        packaging,
    )
}

fn probe_target_permission(target: &ScanTarget) -> PermissionProbeDto {
    let path = target.path().as_str();
    let status = match fs::metadata(path) {
        Ok(metadata) if metadata.is_dir() => match fs::read_dir(path) {
            Ok(_) => PermissionProbeStatusDto::Verified,
            Err(error) => permission_status_from_io_error(error),
        },
        Ok(_) => PermissionProbeStatusDto::Verified,
        Err(error) => permission_status_from_io_error(error),
    };
    PermissionProbeDto::new(
        status,
        Some(DecimalU128Dto::from_u128(u128::from(now_unix_ms()))),
        required_action_for_probe(status),
    )
}

fn permission_status_from_io_error(error: io::Error) -> PermissionProbeStatusDto {
    match error.kind() {
        io::ErrorKind::PermissionDenied => PermissionProbeStatusDto::Denied,
        io::ErrorKind::NotFound => PermissionProbeStatusDto::Degraded,
        _ => PermissionProbeStatusDto::Degraded,
    }
}

const fn required_action_for_probe(
    status: PermissionProbeStatusDto,
) -> PermissionRequiredActionDto {
    required_action_for_probe_on_platform(status, runtime_platform())
}

const fn required_action_for_probe_on_platform(
    status: PermissionProbeStatusDto,
    platform: RuntimePlatformDto,
) -> PermissionRequiredActionDto {
    match status {
        PermissionProbeStatusDto::Denied => match platform {
            RuntimePlatformDto::Macos => PermissionRequiredActionDto::OpenMacosFullDiskAccess,
            RuntimePlatformDto::Windows => PermissionRequiredActionDto::RunAsAdministrator,
            RuntimePlatformDto::Linux => PermissionRequiredActionDto::ReviewLinuxPermissions,
            _ => PermissionRequiredActionDto::Unknown,
        },
        PermissionProbeStatusDto::Degraded => match platform {
            RuntimePlatformDto::Linux => PermissionRequiredActionDto::ReviewLinuxPermissions,
            _ => PermissionRequiredActionDto::None,
        },
        _ => PermissionRequiredActionDto::None,
    }
}

fn packaging_proof() -> PackagingProofDto {
    let distribution_channel = distribution_channel();
    let package_mode = package_mode();
    let scanner_process = scanner_process_kind();
    let signed_build = signed_build();
    let debug_build = cfg!(debug_assertions);
    let sandboxed =
        env_bool("CLEAN_DISK_SANDBOXED") || env::var_os("APP_SANDBOX_CONTAINER_ID").is_some();

    let mut limitations = Vec::new();
    if debug_build {
        limitations.push("debug_build".to_string());
    }
    if !signed_build {
        limitations.push("unsigned_build".to_string());
    }
    if package_mode == PackageModeDto::DevelopmentShell {
        limitations.push("development_shell".to_string());
    }
    if sandboxed {
        limitations.push("sandboxed_build".to_string());
    }
    if scanner_process == ScannerProcessKindDto::ExternalProcess {
        limitations.push("external_scanner_process".to_string());
    }

    packaging_proof_from(
        distribution_channel,
        package_mode,
        scanner_process,
        signed_build,
        debug_build,
        sandboxed,
        limitations,
    )
}

fn packaging_proof_from(
    distribution_channel: DistributionChannelDto,
    package_mode: PackageModeDto,
    scanner_process: ScannerProcessKindDto,
    signed_build: bool,
    debug_build: bool,
    sandboxed: bool,
    limitations: Vec<String>,
) -> PackagingProofDto {
    PackagingProofDto::new(
        distribution_channel,
        package_mode,
        sandboxed,
        signed_build,
        debug_build,
        scanner_process,
        limitations,
        UpdateSafetyDto::new(true, SupportLevelDto::Unknown, SupportLevelDto::Supported),
    )
}

pub fn scan_only_packaging_smoke_report() -> ScanOnlyPackagingSmokeReport {
    let current_exe = env::current_exe().ok();
    scan_only_packaging_smoke_report_from_packaging(&packaging_proof(), current_exe.as_deref())
}

fn scan_only_packaging_smoke_report_from_packaging(
    packaging: &PackagingProofDto,
    executable_path: Option<&Path>,
) -> ScanOnlyPackagingSmokeReport {
    let mut failures = Vec::new();

    match packaging.distribution_channel() {
        DistributionChannelDto::Development => {
            failures.push(ScanOnlyPackagingSmokeFailure::DevelopmentDistribution);
        }
        DistributionChannelDto::Unknown | DistributionChannelDto::Unrecognized => {
            failures.push(ScanOnlyPackagingSmokeFailure::UnknownDistributionChannel);
        }
        DistributionChannelDto::Direct
        | DistributionChannelDto::MacAppStore
        | DistributionChannelDto::WindowsStore
        | DistributionChannelDto::PackageManager => {}
    }

    match packaging.package_mode() {
        PackageModeDto::DevelopmentShell => {
            failures.push(ScanOnlyPackagingSmokeFailure::DevelopmentShell);
        }
        PackageModeDto::Unknown | PackageModeDto::Unrecognized => {
            failures.push(ScanOnlyPackagingSmokeFailure::UnknownPackageMode);
        }
        PackageModeDto::AppBundle
        | PackageModeDto::BundledDaemon
        | PackageModeDto::SystemService
        | PackageModeDto::Portable => {}
    }

    if !packaging.signed_build() {
        failures.push(ScanOnlyPackagingSmokeFailure::UnsignedBuild);
    }
    if packaging.debug_build() {
        failures.push(ScanOnlyPackagingSmokeFailure::DebugBuild);
    }
    if packaging.sandboxed() {
        failures.push(ScanOnlyPackagingSmokeFailure::SandboxedBuild);
    }

    match packaging.scanner_process() {
        ScannerProcessKindDto::ExternalProcess => {
            failures.push(ScanOnlyPackagingSmokeFailure::ExternalScannerProcess);
        }
        ScannerProcessKindDto::Unknown | ScannerProcessKindDto::Unrecognized => {
            failures.push(ScanOnlyPackagingSmokeFailure::UnknownScannerProcess);
        }
        ScannerProcessKindDto::AppBundle
        | ScannerProcessKindDto::BundledHelper
        | ScannerProcessKindDto::CurrentProcess => {}
    }
    if cfg!(target_os = "macos") {
        let is_app_executable = executable_path.is_some_and(is_macos_app_executable_path);
        let is_app_helper = executable_path.is_some_and(is_macos_app_helper_path);

        match packaging.scanner_process() {
            ScannerProcessKindDto::BundledHelper if !is_app_helper => {
                failures.push(ScanOnlyPackagingSmokeFailure::MissingBundledHelperIdentity);
            }
            ScannerProcessKindDto::AppBundle | ScannerProcessKindDto::CurrentProcess
                if packaging.package_mode() == PackageModeDto::AppBundle
                    && !is_app_executable
                    && !is_app_helper =>
            {
                failures.push(ScanOnlyPackagingSmokeFailure::MissingAppBundleIdentity);
            }
            _ => {}
        }
    }

    let update_safety = packaging.update_safety();
    if !update_safety.quiesce_required_before_update() {
        failures.push(ScanOnlyPackagingSmokeFailure::MissingUpdateQuiesceGate);
    }
    if update_safety.receipt_preservation() != SupportLevelDto::Supported {
        failures.push(ScanOnlyPackagingSmokeFailure::MissingReceiptPreservation);
    }

    ScanOnlyPackagingSmokeReport::new(failures)
}

fn distribution_channel() -> DistributionChannelDto {
    match env::var("CLEAN_DISK_DISTRIBUTION_CHANNEL")
        .unwrap_or_else(|_| default_distribution_channel_name(cfg!(debug_assertions)).to_string())
        .as_str()
    {
        "development" => DistributionChannelDto::Development,
        "direct" => DistributionChannelDto::Direct,
        "mac_app_store" => DistributionChannelDto::MacAppStore,
        "windows_store" => DistributionChannelDto::WindowsStore,
        "package_manager" => DistributionChannelDto::PackageManager,
        _ => DistributionChannelDto::Unknown,
    }
}

const fn default_distribution_channel_name(debug_build: bool) -> &'static str {
    if debug_build { "development" } else { "direct" }
}

fn package_mode() -> PackageModeDto {
    match env::var("CLEAN_DISK_PACKAGE_MODE")
        .unwrap_or_else(|_| default_package_mode_name())
        .as_str()
    {
        "development_shell" => PackageModeDto::DevelopmentShell,
        "app_bundle" => PackageModeDto::AppBundle,
        "bundled_daemon" => PackageModeDto::BundledDaemon,
        "system_service" => PackageModeDto::SystemService,
        "portable" => PackageModeDto::Portable,
        _ => PackageModeDto::Unknown,
    }
}

fn default_package_mode_name() -> String {
    let current_exe = env::current_exe().ok();
    if current_exe
        .as_deref()
        .is_some_and(|path| is_macos_app_executable_path(path) || is_macos_app_helper_path(path))
    {
        "app_bundle".to_string()
    } else if cfg!(debug_assertions) {
        "development_shell".to_string()
    } else {
        "portable".to_string()
    }
}

fn scanner_process_kind() -> ScannerProcessKindDto {
    match env::var("CLEAN_DISK_SCANNER_PROCESS") {
        Ok(value) => match value.as_str() {
            "app_bundle" => ScannerProcessKindDto::AppBundle,
            "bundled_helper" => ScannerProcessKindDto::BundledHelper,
            "current_process" => ScannerProcessKindDto::CurrentProcess,
            "external_process" => ScannerProcessKindDto::ExternalProcess,
            _ => ScannerProcessKindDto::Unknown,
        },
        Err(_) => env::current_exe()
            .ok()
            .as_deref()
            .and_then(scanner_process_kind_from_path)
            .unwrap_or(ScannerProcessKindDto::CurrentProcess),
    }
}

fn scanner_process_kind_from_path(path: &Path) -> Option<ScannerProcessKindDto> {
    if is_macos_app_helper_path(path) {
        return Some(ScannerProcessKindDto::BundledHelper);
    }
    if is_macos_app_executable_path(path) {
        return Some(ScannerProcessKindDto::AppBundle);
    }
    None
}

fn is_macos_app_executable_path(path: &Path) -> bool {
    path_contains_app_contents_folder(path, "MacOS")
}

fn is_macos_app_helper_path(path: &Path) -> bool {
    path_contains_app_contents_folder(path, "Helpers")
}

fn path_contains_app_contents_folder(path: &Path, folder: &str) -> bool {
    let components = path
        .components()
        .filter_map(|component| component.as_os_str().to_str())
        .collect::<Vec<_>>();
    components
        .windows(3)
        .any(|window| window[0].ends_with(".app") && window[1] == "Contents" && window[2] == folder)
}

fn signed_build() -> bool {
    if cfg!(target_os = "macos") {
        return env::current_exe()
            .ok()
            .as_deref()
            .is_some_and(has_macos_distribution_signature);
    }
    env_bool("CLEAN_DISK_SIGNED_BUILD")
}

fn has_macos_distribution_signature(path: &Path) -> bool {
    let Ok(output) = Command::new("/usr/bin/codesign")
        .arg("-dv")
        .arg("--verbose=4")
        .arg(path)
        .output()
    else {
        return false;
    };
    if !output.status.success() {
        return false;
    }

    let mut details = String::from_utf8_lossy(&output.stderr).into_owned();
    details.push_str(&String::from_utf8_lossy(&output.stdout));
    details.contains("TeamIdentifier=")
        && !details.contains("TeamIdentifier=not set")
        && !details.contains("Signature=adhoc")
}

fn env_bool(name: &str) -> bool {
    matches!(
        env::var(name).as_deref(),
        Ok("1") | Ok("true") | Ok("TRUE") | Ok("yes") | Ok("YES")
    )
}

fn current_executable_path() -> Option<RawPathDto> {
    let path = env::current_exe().ok()?;
    RawPathDto::new(path.to_string_lossy().into_owned()).ok()
}

const fn runtime_platform() -> RuntimePlatformDto {
    if cfg!(target_os = "macos") {
        RuntimePlatformDto::Macos
    } else if cfg!(target_os = "windows") {
        RuntimePlatformDto::Windows
    } else if cfg!(target_os = "linux") {
        RuntimePlatformDto::Linux
    } else {
        RuntimePlatformDto::Unknown
    }
}

fn map_capabilities(capabilities: ScannerBackendCapabilities) -> CapabilitySetDto {
    let capabilities = capabilities.capabilities();
    CapabilitySetDto::new(
        map_support(capabilities.hardlinks()),
        map_support(capabilities.filesystem_boundary()),
        map_support(capabilities.cooperative_cancellation()),
        map_support(capabilities.metadata_enrichment()),
    )
}

fn map_diagnostics(diagnostics: RegistryDiagnostics, auth_required: bool) -> DaemonDiagnosticsDto {
    DaemonDiagnosticsDto::new(
        PROTOCOL_VERSION,
        DecimalUsizeDto::from_usize(diagnostics.active_sessions),
        DecimalUsizeDto::from_usize(diagnostics.running_sessions),
        DecimalUsizeDto::from_usize(diagnostics.completed_sessions),
        DecimalUsizeDto::from_usize(diagnostics.cancel_requested_sessions),
        DecimalUsizeDto::from_usize(diagnostics.buffered_events),
        DecimalUsizeDto::from_usize(diagnostics.stored_cursors),
        auth_required,
    )
}

const fn map_support(level: SupportLevel) -> SupportLevelDto {
    match level {
        SupportLevel::Supported => SupportLevelDto::Supported,
        SupportLevel::Unsupported => SupportLevelDto::Unsupported,
        SupportLevel::Unknown => SupportLevelDto::Unknown,
    }
}

fn map_scan_request(
    session_id: ScanSessionId,
    request: &StartScanRequestDto,
) -> Result<BackendScanRequest, &'static str> {
    if !PROTOCOL_VERSION.is_compatible_with(request.protocol_version()) {
        return Err("protocol version is not compatible");
    }
    if request.command_id().to_u128() == 0 {
        return Err("command id is zero");
    }
    if request.targets().is_empty() {
        return Err("scan target list must not be empty");
    }
    let targets = request
        .targets()
        .iter()
        .map(map_target)
        .collect::<Result<Vec<_>, _>>()?;
    Ok(BackendScanRequest::new(
        session_id,
        targets,
        map_measurement(request.measurement()),
    ))
}

fn map_target(target: &ScanTargetDto) -> Result<ScanTarget, &'static str> {
    let path = TargetPath::new(target.path().as_str().to_string()).map_err(|_| "empty path")?;
    Ok(ScanTarget::new(
        path,
        match target.scope() {
            TargetScopeDto::LocalPath => TargetScope::LocalPath,
            TargetScopeDto::Volume => TargetScope::Volume,
            TargetScopeDto::Custom => TargetScope::Custom,
        },
        match target.boundary_policy() {
            BoundaryPolicyDto::CrossFilesystems => BoundaryPolicy::CrossFilesystems,
            BoundaryPolicyDto::StayOnInitialFilesystem => BoundaryPolicy::StayOnInitialFilesystem,
        },
        match target.hardlink_policy() {
            HardlinkPolicyDto::Ignore => HardlinkPolicy::Ignore,
            HardlinkPolicyDto::Detect => HardlinkPolicy::Detect,
            HardlinkPolicyDto::DeduplicateForDisplay => HardlinkPolicy::DeduplicateForDisplay,
        },
    ))
}

const fn map_measurement(measurement: MeasuredQuantityDto) -> MeasuredQuantity {
    match measurement {
        MeasuredQuantityDto::ApparentBytes => MeasuredQuantity::ApparentBytes,
        MeasuredQuantityDto::AllocatedBytes => MeasuredQuantity::AllocatedBytes,
        MeasuredQuantityDto::BlockCount => MeasuredQuantity::BlockCount,
    }
}

fn parse_session_id(value: u128) -> Option<ScanSessionId> {
    ScanSessionId::new(value)
}

fn parse_snapshot_id(value: u128) -> Option<SnapshotId> {
    SnapshotId::new(value)
}

fn parse_node_id(value: u64) -> Option<NodeId> {
    NodeId::new(value)
}

fn validate_query_limit(limit: usize, budget: WorkerBudget) -> Result<usize, QueryLimitFailure> {
    if limit == 0 {
        return Err(QueryLimitFailure::Zero);
    }
    if limit > budget.max_query_page_size().get() {
        return Err(QueryLimitFailure::ExceedsMaximum);
    }
    Ok(limit)
}

const fn map_child_sort(sort: ChildSortDto) -> ChildSort {
    match sort {
        ChildSortDto::Insertion => ChildSort::Insertion,
        ChildSortDto::NameAsc => ChildSort::NameAsc,
        ChildSortDto::NameDesc => ChildSort::NameDesc,
        ChildSortDto::SizeAsc => ChildSort::SizeAsc,
        ChildSortDto::SizeDesc => ChildSort::SizeDesc,
    }
}

const fn map_top_items_kind(kind: TopItemsKindDto) -> TopItemsKind {
    match kind {
        TopItemsKindDto::Files => TopItemsKind::Files,
        TopItemsKindDto::Directories => TopItemsKind::Directories,
        TopItemsKindDto::FilesAndDirectories => TopItemsKind::FilesAndDirectories,
    }
}

fn map_node_page_response(
    session_id: ScanSessionId,
    snapshot_id: SnapshotId,
    page: Page<NodePageItem>,
    registry: &SessionRegistry,
) -> NodePageResponseDto {
    let next_cursor = registry.store_cursor(session_id, snapshot_id, page.next_cursor);
    NodePageResponseDto::new(
        DecimalU128Dto::from_u128(snapshot_id.get()),
        page.items.into_iter().map(map_node_page_item).collect(),
        next_cursor,
    )
}

fn map_node_details_response(
    snapshot_id: SnapshotId,
    details: NodeDetails,
) -> NodeDetailsResponseDto {
    NodeDetailsResponseDto::new(
        DecimalU128Dto::from_u128(snapshot_id.get()),
        map_node_page_item(details.summary().clone()),
        map_node_timestamps(details.source_path()),
        details
            .child_ids()
            .iter()
            .map(|id| DecimalU64Dto::from_u64(id.get()))
            .collect(),
        details.issues().iter().map(map_scan_issue).collect(),
    )
}

fn map_node_timestamps(path: Option<&Path>) -> Option<NodeTimestampsDto> {
    let metadata = path.and_then(|path| fs::symlink_metadata(path).ok())?;
    let created_at_unix_ms = metadata
        .created()
        .ok()
        .and_then(system_time_unix_ms)
        .map(DecimalU128Dto::from_u128);
    let modified_at_unix_ms = metadata
        .modified()
        .ok()
        .and_then(system_time_unix_ms)
        .map(DecimalU128Dto::from_u128);

    if created_at_unix_ms.is_none() && modified_at_unix_ms.is_none() {
        return None;
    }

    Some(NodeTimestampsDto::new(
        created_at_unix_ms,
        modified_at_unix_ms,
    ))
}

fn system_time_unix_ms(time: SystemTime) -> Option<u128> {
    time.duration_since(UNIX_EPOCH)
        .ok()
        .map(|duration| duration.as_millis())
}

fn map_node_page_item(item: NodePageItem) -> NodePageItemDto {
    NodePageItemDto::new(
        DecimalU64Dto::from_u64(item.id().get()),
        item.parent_id().map(|id| DecimalU64Dto::from_u64(id.get())),
        item.name(),
        map_node_kind(item.kind()),
        map_size_fact(item.size()),
        map_node_flags(item.flags()),
        map_child_completeness(item.child_completeness()),
        DecimalUsizeDto::from_usize(item.child_count()),
        DecimalUsizeDto::from_usize(item.issue_count()),
        DecimalUsizeDto::from_usize(item.subtree_issue_count()),
    )
}

const fn map_node_kind(kind: NodeKind) -> NodeKindDto {
    match kind {
        NodeKind::File => NodeKindDto::File,
        NodeKind::Directory => NodeKindDto::Directory,
        NodeKind::Symlink => NodeKindDto::Symlink,
        NodeKind::Other => NodeKindDto::Other,
        NodeKind::Unknown => NodeKindDto::Unknown,
    }
}

const fn map_node_flags(flags: NodeFlags) -> NodeFlagsDto {
    NodeFlagsDto::new(flags.hidden, flags.system, flags.package, flags.symlink)
}

const fn map_child_completeness(completeness: ChildCompleteness) -> ChildCompletenessDto {
    match completeness {
        ChildCompleteness::Complete => ChildCompletenessDto::Complete,
        ChildCompleteness::CollapsedByDepth => ChildCompletenessDto::CollapsedByDepth,
        ChildCompleteness::CollapsedByProjection => ChildCompletenessDto::CollapsedByProjection,
        ChildCompleteness::SkippedByBoundary => ChildCompletenessDto::SkippedByBoundary,
        ChildCompleteness::IncompleteDueToIssue => ChildCompletenessDto::IncompleteDueToIssue,
        ChildCompleteness::Unknown => ChildCompletenessDto::Unknown,
    }
}

fn map_size_fact(size: SizeFact) -> SizeFactDto {
    SizeFactDto::new(
        DecimalU64Dto::from_u64(size.raw_value()),
        match size.quantity() {
            MeasuredQuantity::ApparentBytes => MeasuredQuantityResponseDto::ApparentBytes,
            MeasuredQuantity::AllocatedBytes => MeasuredQuantityResponseDto::AllocatedBytes,
            MeasuredQuantity::BlockCount => MeasuredQuantityResponseDto::BlockCount,
        },
        size.byte_equivalent()
            .map(|bytes| DecimalU64Dto::from_u64(bytes.get())),
        map_size_confidence(size.confidence()),
    )
}

const fn map_size_confidence(confidence: EvidenceConfidence) -> SizeConfidenceDto {
    match confidence {
        EvidenceConfidence::Exact => SizeConfidenceDto::Exact,
        EvidenceConfidence::High => SizeConfidenceDto::High,
        EvidenceConfidence::Medium => SizeConfidenceDto::Medium,
        EvidenceConfidence::Low => SizeConfidenceDto::Low,
        EvidenceConfidence::Unknown => SizeConfidenceDto::Unknown,
    }
}

fn map_scan_issue(issue: &ScanIssue) -> ScanIssueDto {
    let evidence = issue.evidence();
    ScanIssueDto::new(
        map_issue_code(issue.code()),
        map_issue_severity(issue.severity()),
        IssueEvidenceDto::new(
            evidence
                .path()
                .map(|path| DisplayPathDto::new(path, PathPrivacyDto::Raw)),
            evidence.operation().map(str::to_string),
            evidence.message().map(str::to_string),
        ),
    )
}

const fn map_issue_code(code: IssueCode) -> IssueCodeDto {
    match code {
        IssueCode::PermissionDenied => IssueCodeDto::PermissionDenied,
        IssueCode::MetadataUnavailable => IssueCodeDto::MetadataUnavailable,
        IssueCode::ReadDirectoryFailed => IssueCodeDto::ReadDirectoryFailed,
        IssueCode::AccessEntryFailed => IssueCodeDto::AccessEntryFailed,
        IssueCode::BoundarySkipped => IssueCodeDto::BoundarySkipped,
        IssueCode::NonUtf8Path => IssueCodeDto::NonUtf8Path,
        IssueCode::BackendLimitation => IssueCodeDto::BackendLimitation,
        IssueCode::Unknown => IssueCodeDto::Unknown,
    }
}

const fn map_issue_severity(severity: IssueSeverity) -> IssueSeverityDto {
    match severity {
        IssueSeverity::Info => IssueSeverityDto::Info,
        IssueSeverity::Warning => IssueSeverityDto::Warning,
        IssueSeverity::Error => IssueSeverityDto::Error,
    }
}

fn status_from_record(record: &SessionRecord) -> ScanSessionStatusDto {
    match &record.session {
        Some(session) => status_from_session(session),
        None => ScanSessionStatusDto::new(
            DecimalU128Dto::from_u128(record.session_id.get()),
            SessionStateDto::Running,
            None,
            Vec::new(),
            latest_progress(record),
        ),
    }
}

fn status_from_session(session: &ScanSession) -> ScanSessionStatusDto {
    let root_node_ids = session
        .snapshot()
        .map(|snapshot| {
            snapshot
                .root_ids()
                .iter()
                .map(|id| DecimalU64Dto::from_u64(id.get()))
                .collect()
        })
        .unwrap_or_default();

    ScanSessionStatusDto::new(
        DecimalU128Dto::from_u128(session.id().get()),
        match session.state() {
            ScanState::Created => SessionStateDto::Created,
            ScanState::Running => SessionStateDto::Running,
            ScanState::Canceled => SessionStateDto::Canceled,
            ScanState::Completed => SessionStateDto::Completed,
            ScanState::Failed(_) => SessionStateDto::Failed,
        },
        session
            .snapshot()
            .map(|snapshot| DecimalU128Dto::from_u128(snapshot.snapshot_id().get())),
        root_node_ids,
        None,
    )
}

fn latest_progress(record: &SessionRecord) -> Option<ScanProgressDto> {
    record
        .events
        .events()
        .iter()
        .rev()
        .find_map(|event| match event {
            ScanEvent::Progress { scanned_items, .. } => Some(ScanProgressDto::new(
                DecimalU64Dto::from_u64(*scanned_items),
                None,
                None,
            )),
            _ => None,
        })
}

fn map_event(event: ScanEvent) -> ScanEventDto {
    match event {
        ScanEvent::Started { session_id } => ScanEventDto::Started {
            session_id: DecimalU128Dto::from_u128(session_id.get()),
        },
        ScanEvent::Progress {
            session_id,
            scanned_items,
        } => ScanEventDto::Progress {
            session_id: DecimalU128Dto::from_u128(session_id.get()),
            progress: ScanProgressDto::new(DecimalU64Dto::from_u64(scanned_items), None, None),
        },
        ScanEvent::SnapshotPublished {
            session_id,
            snapshot_id,
        } => ScanEventDto::SnapshotPublished {
            session_id: DecimalU128Dto::from_u128(session_id.get()),
            snapshot_id: DecimalU128Dto::from_u128(snapshot_id.get()),
        },
        ScanEvent::Canceled { session_id } => ScanEventDto::Canceled {
            session_id: DecimalU128Dto::from_u128(session_id.get()),
        },
        ScanEvent::Failed {
            session_id,
            message,
        } => ScanEventDto::Failed {
            session_id: DecimalU128Dto::from_u128(session_id.get()),
            message,
        },
    }
}

fn error_response(status: StatusCode, code: &'static str, message: &'static str) -> Response {
    (status, Json(ApiErrorDto { code, message })).into_response()
}

fn invalid_session_response() -> Response {
    error_response(
        StatusCode::BAD_REQUEST,
        "invalid_session_id",
        "session id is zero",
    )
}

fn invalid_snapshot_response() -> Response {
    error_response(
        StatusCode::BAD_REQUEST,
        "invalid_snapshot_id",
        "snapshot id is zero",
    )
}

fn invalid_node_response() -> Response {
    error_response(
        StatusCode::BAD_REQUEST,
        "invalid_node_id",
        "node id is zero",
    )
}

fn query_error_response(error: SessionQueryFailure) -> Response {
    match error {
        SessionQueryFailure::SessionNotFound => error_response(
            StatusCode::NOT_FOUND,
            "not_found",
            "scan session was not found",
        ),
        SessionQueryFailure::SnapshotNotReady => error_response(
            StatusCode::CONFLICT,
            "snapshot_not_ready",
            "scan snapshot is not available yet",
        ),
        SessionQueryFailure::InvalidCursor => error_response(
            StatusCode::BAD_REQUEST,
            "invalid_cursor",
            "query cursor is unknown or expired",
        ),
        SessionQueryFailure::Query(QueryFailure::SnapshotMismatch) => error_response(
            StatusCode::BAD_REQUEST,
            "snapshot_mismatch",
            "request snapshot does not belong to the current scan snapshot",
        ),
        SessionQueryFailure::Query(QueryFailure::CursorSnapshotMismatch) => error_response(
            StatusCode::BAD_REQUEST,
            "invalid_cursor",
            "query cursor belongs to another snapshot",
        ),
        SessionQueryFailure::Query(QueryFailure::CursorQueryMismatch) => error_response(
            StatusCode::BAD_REQUEST,
            "invalid_cursor",
            "query cursor belongs to another query",
        ),
        SessionQueryFailure::Query(QueryFailure::InvalidLimit) => error_response(
            StatusCode::BAD_REQUEST,
            "invalid_limit",
            "query limit must be greater than zero",
        ),
        SessionQueryFailure::Query(QueryFailure::InvalidSearchText) => error_response(
            StatusCode::BAD_REQUEST,
            "invalid_search_text",
            "search text must not be empty",
        ),
        SessionQueryFailure::Query(QueryFailure::UnknownNode(_)) => {
            error_response(StatusCode::NOT_FOUND, "not_found", "node was not found")
        }
    }
}

fn cleanup_journal_error_response(error: io::Error) -> Response {
    let message = match error.kind() {
        io::ErrorKind::OutOfMemory | io::ErrorKind::StorageFull => {
            "cleanup journal could not be written because storage is full"
        }
        _ => "cleanup journal could not be written",
    };
    error_response(
        StatusCode::INSUFFICIENT_STORAGE,
        "cleanup_journal_unavailable",
        message,
    )
}

fn query_limit_error_response(error: QueryLimitFailure) -> Response {
    match error {
        QueryLimitFailure::Zero => error_response(
            StatusCode::BAD_REQUEST,
            "invalid_limit",
            "query limit must be greater than zero",
        ),
        QueryLimitFailure::ExceedsMaximum => error_response(
            StatusCode::BAD_REQUEST,
            "invalid_limit",
            "query limit exceeds daemon protocol limit",
        ),
    }
}

fn now_unix_ms() -> u64 {
    let millis = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis();
    u64::try_from(millis).unwrap_or(u64::MAX)
}

async fn shutdown_signal(registry: Arc<SessionRegistry>) {
    let _ = tokio::signal::ctrl_c().await;
    registry.cancel_all_running();
}

struct RegistryEventSink {
    registry: Arc<SessionRegistry>,
    session_id: ScanSessionId,
}

impl EventSink for RegistryEventSink {
    fn emit(&mut self, event: ScanEvent) {
        self.registry.push_event(self.session_id, event);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{
        body::{Body, to_bytes},
        http::Request,
    };
    use fs_usage_core::{EvidenceConfidence, MeasuredQuantity, SizeBytes, SizeFact};
    use fs_usage_engine::{DraftNode, FakeScannerBackend, ScanSnapshotDraft};
    use fs_usage_platform::{TrashOutcome, path_identity_evidence};
    use std::time::Duration;
    use tower::ServiceExt;

    #[derive(Debug, Default)]
    struct RecordingTrashAdapter {
        paths: Mutex<Vec<PathBuf>>,
    }

    impl TrashAdapter for RecordingTrashAdapter {
        fn move_to_trash(&self, path: &Path) -> Result<TrashOutcome, TrashFailure> {
            self.paths
                .lock()
                .expect("recording trash adapter lock")
                .push(path.to_path_buf());
            Ok(TrashOutcome::platform_trash_manual(Some(
                "trash://clean-disk-test".to_string(),
            )))
        }
    }

    #[derive(Debug)]
    struct SlowRecordingTrashAdapter {
        paths: Mutex<Vec<PathBuf>>,
        delay: Duration,
    }

    impl SlowRecordingTrashAdapter {
        fn new(delay: Duration) -> Self {
            Self {
                paths: Mutex::new(Vec::new()),
                delay,
            }
        }
    }

    impl TrashAdapter for SlowRecordingTrashAdapter {
        fn move_to_trash(&self, path: &Path) -> Result<TrashOutcome, TrashFailure> {
            std::thread::sleep(self.delay);
            self.paths
                .lock()
                .expect("slow recording trash adapter lock")
                .push(path.to_path_buf());
            Ok(TrashOutcome::platform_trash_manual(Some(
                "trash://clean-disk-test".to_string(),
            )))
        }
    }

    async fn response_json<T: serde::de::DeserializeOwned>(response: Response) -> T {
        let bytes = to_bytes(response.into_body(), usize::MAX)
            .await
            .expect("response body");
        serde_json::from_slice(&bytes).expect("json response")
    }

    fn post_json(path: &str, body: impl Serialize) -> Request<Body> {
        Request::builder()
            .method("POST")
            .uri(path)
            .header("authorization", "Bearer test-token")
            .header("content-type", "application/json")
            .body(Body::from(serde_json::to_vec(&body).expect("json body")))
            .expect("request")
    }

    fn get(path: &str) -> Request<Body> {
        Request::builder()
            .method("GET")
            .uri(path)
            .header("authorization", "Bearer test-token")
            .body(Body::empty())
            .expect("request")
    }

    async fn wait_for_completed_scan(app: &Router, session_id: u128) -> ScanSessionStatusDto {
        let path = format!("/v1/scans/{session_id}");
        let mut last_status = None;
        for _ in 0..100 {
            let response = app
                .clone()
                .oneshot(get(&path))
                .await
                .expect("status response");
            let status: ScanSessionStatusDto = response_json(response).await;
            if status.state() == SessionStateDto::Completed {
                return status;
            }
            last_status = Some(status);
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
        last_status.expect("status response before timeout")
    }

    fn test_path(name: &str) -> PathBuf {
        env::temp_dir().join(format!("clean-disk-{name}-{}", now_unix_ms()))
    }

    fn size(bytes: u64) -> SizeFact {
        SizeFact::new(
            bytes,
            MeasuredQuantity::ApparentBytes,
            Some(SizeBytes::new(bytes)),
            EvidenceConfidence::Exact,
        )
    }

    #[test]
    fn event_replay_keeps_stable_sequences_across_reconnects() {
        let budget = WorkerBudget::for_profile_with_parallelism(
            ScanResourceProfile::Balanced,
            std::num::NonZeroUsize::new(4).expect("cores"),
        );
        let registry = SessionRegistry::new(budget, 8, 1);
        let session_id = ScanSessionId::new(1).expect("session id");
        registry.insert_running(session_id, CancellationToken::new());
        registry.push_event(session_id, ScanEvent::Started { session_id });
        registry.push_event(
            session_id,
            ScanEvent::Progress {
                session_id,
                scanned_items: 10,
            },
        );

        let first = registry.event_envelopes();
        let second = registry.event_envelopes();

        assert_eq!(first, second);
        assert_eq!(first.len(), 2);
        assert_eq!(first[0].sequence().to_u64(), 1);
        assert_eq!(first[1].sequence().to_u64(), 2);
    }

    #[test]
    fn event_subscribers_receive_live_events_after_subscription() {
        let budget = WorkerBudget::for_profile_with_parallelism(
            ScanResourceProfile::Balanced,
            std::num::NonZeroUsize::new(4).expect("cores"),
        );
        let registry = SessionRegistry::new(budget, 8, 1);
        let session_id = ScanSessionId::new(1).expect("session id");
        let mut live_events = registry.subscribe_events();
        registry.insert_running(session_id, CancellationToken::new());

        registry.push_event(session_id, ScanEvent::Started { session_id });

        let live_event = live_events.try_recv().expect("live event");
        assert_eq!(live_event.sequence().to_u64(), 1);
        assert_eq!(registry.event_envelopes(), vec![live_event]);
    }

    #[tokio::test]
    async fn cleanup_execution_writes_skeleton_before_dispatch_and_receipt_before_adapter() {
        let fixture_dir = test_path("cleanup-fixture");
        fs::create_dir_all(&fixture_dir).expect("fixture dir");
        let nested_dir_path = fixture_dir.join("cache-dir");
        fs::create_dir_all(&nested_dir_path).expect("nested fixture dir");
        let file_path = fixture_dir.join("alpha.log");
        fs::write(&file_path, b"test").expect("fixture file");
        let journal_path = test_path("cleanup-journal").join("journal.jsonl");
        let trash_adapter = Arc::new(RecordingTrashAdapter::default());
        let draft = ScanSnapshotDraft::new(vec![
            DraftNode::new(
                "root",
                NodeKind::Directory,
                size(4),
                ChildCompleteness::Complete,
            )
            .with_source_path(&fixture_dir)
            .with_children(vec![
                DraftNode::new(
                    "cache-dir",
                    NodeKind::Directory,
                    size(0),
                    ChildCompleteness::Complete,
                )
                .with_source_path(&nested_dir_path),
                DraftNode::new(
                    "alpha.log",
                    NodeKind::File,
                    size(4),
                    ChildCompleteness::Complete,
                )
                .with_source_path(&file_path),
            ]),
        ]);
        let budget = WorkerBudget::for_profile_with_parallelism(
            ScanResourceProfile::Balanced,
            std::num::NonZeroUsize::new(4).expect("cores"),
        );
        let state = AppState::new_with_cleanup(
            ServerConfig::local_default().with_auth_token("test-token"),
            Arc::new(FakeScannerBackend::new(draft)),
            Arc::new(FileCleanupJournal::new(journal_path)),
            trash_adapter.clone(),
            budget,
        );
        let app = build_router(state);

        let start = StartScanRequestDto::new(
            PROTOCOL_VERSION,
            DecimalU128Dto::from_u128(1),
            vec![ScanTargetDto::new(
                RawPathDto::new(fixture_dir.to_string_lossy().to_string()).expect("target path"),
                TargetScopeDto::LocalPath,
                BoundaryPolicyDto::StayOnInitialFilesystem,
                HardlinkPolicyDto::Ignore,
            )],
            MeasuredQuantityDto::ApparentBytes,
            clean_disk_protocol::ScanModeDto::Balanced,
        );
        let response = app
            .clone()
            .oneshot(post_json("/v1/scans", start))
            .await
            .expect("start response");
        assert_eq!(response.status(), StatusCode::ACCEPTED);

        let status = wait_for_completed_scan(&app, 1).await;
        assert_eq!(status.state(), SessionStateDto::Completed);

        let cleanup = ExecuteCleanupRequestDto::new(
            PROTOCOL_VERSION,
            DecimalU128Dto::from_u128(2),
            vec![
                CleanupPlanItemRefDto::new(
                    DecimalU128Dto::from_u128(1),
                    DecimalU128Dto::from_u128(1),
                    DecimalU64Dto::from_u64(2),
                ),
                CleanupPlanItemRefDto::new(
                    DecimalU128Dto::from_u128(1),
                    DecimalU128Dto::from_u128(1),
                    DecimalU64Dto::from_u64(3),
                ),
            ],
        );
        let response = app
            .oneshot(post_json("/v1/cleanup/execute", cleanup))
            .await
            .expect("cleanup response");
        assert_eq!(response.status(), StatusCode::OK);
        let receipt: CleanupReceiptDto = response_json(response).await;

        assert_eq!(receipt.state(), CleanupReceiptStateDto::Completed);
        assert_eq!(
            receipt.items()[0].state(),
            CleanupItemOutcomeStateDto::MovedToTrash
        );
        assert_eq!(
            trash_adapter.paths.lock().expect("paths").as_slice(),
            &[nested_dir_path, file_path]
        );
    }

    #[tokio::test]
    async fn cleanup_plan_route_creates_plan_and_executes_by_plan_id() {
        let fixture_dir = test_path("cleanup-plan-fixture");
        fs::create_dir_all(&fixture_dir).expect("fixture dir");
        let file_path = fixture_dir.join("alpha.log");
        fs::write(&file_path, b"test").expect("fixture file");
        let journal_path = test_path("cleanup-plan-journal").join("journal.jsonl");
        let trash_adapter = Arc::new(RecordingTrashAdapter::default());
        let draft = ScanSnapshotDraft::new(vec![
            DraftNode::new(
                "root",
                NodeKind::Directory,
                size(4),
                ChildCompleteness::Complete,
            )
            .with_source_path(&fixture_dir)
            .with_children(vec![
                DraftNode::new(
                    "alpha.log",
                    NodeKind::File,
                    size(4),
                    ChildCompleteness::Complete,
                )
                .with_source_path(&file_path),
            ]),
        ]);
        let state = AppState::new_with_cleanup(
            ServerConfig::local_default().with_auth_token("test-token"),
            Arc::new(FakeScannerBackend::new(draft)),
            Arc::new(FileCleanupJournal::new(journal_path)),
            trash_adapter.clone(),
            WorkerBudget::for_profile_with_parallelism(
                ScanResourceProfile::Balanced,
                std::num::NonZeroUsize::new(4).expect("cores"),
            ),
        );
        let app = build_router(state);
        let start = StartScanRequestDto::new(
            PROTOCOL_VERSION,
            DecimalU128Dto::from_u128(1),
            vec![ScanTargetDto::new(
                RawPathDto::new(fixture_dir.to_string_lossy().to_string()).expect("target path"),
                TargetScopeDto::LocalPath,
                BoundaryPolicyDto::StayOnInitialFilesystem,
                HardlinkPolicyDto::Ignore,
            )],
            MeasuredQuantityDto::ApparentBytes,
            clean_disk_protocol::ScanModeDto::Balanced,
        );
        let response = app
            .clone()
            .oneshot(post_json("/v1/scans", start))
            .await
            .expect("start response");
        assert_eq!(response.status(), StatusCode::ACCEPTED);
        let status = wait_for_completed_scan(&app, 1).await;
        assert_eq!(status.state(), SessionStateDto::Completed);

        let create_plan = CreateCleanupPlanRequestDto::new(
            PROTOCOL_VERSION,
            DecimalU128Dto::from_u128(2),
            vec![CleanupPlanItemRefDto::new(
                DecimalU128Dto::from_u128(1),
                DecimalU128Dto::from_u128(1),
                DecimalU64Dto::from_u64(2),
            )],
        );
        let response = app
            .clone()
            .oneshot(post_json("/v1/cleanup/plans", create_plan))
            .await
            .expect("create plan response");
        assert_eq!(response.status(), StatusCode::OK);
        let plan: CleanupPlanDto = response_json(response).await;

        assert_eq!(plan.plan_id().to_u128(), 1);
        assert_eq!(plan.command_id().to_u128(), 2);
        assert_eq!(plan.state(), CleanupPlanStateDto::Ready);
        assert_eq!(plan.items()[0].state(), CleanupPlanItemStateDto::Ready);

        let execute_plan = ExecuteCleanupPlanRequestDto::new(
            PROTOCOL_VERSION,
            DecimalU128Dto::from_u128(3),
            plan.plan_id().clone(),
        );
        let response = app
            .oneshot(post_json("/v1/cleanup/plans/1/execute", execute_plan))
            .await
            .expect("execute plan response");
        assert_eq!(response.status(), StatusCode::OK);
        let receipt: CleanupReceiptDto = response_json(response).await;

        assert_eq!(receipt.command_id().to_u128(), 3);
        assert_eq!(receipt.state(), CleanupReceiptStateDto::Completed);
        assert_eq!(
            trash_adapter.paths.lock().expect("paths").as_slice(),
            &[file_path]
        );
    }

    #[tokio::test]
    async fn cleanup_plan_execute_revalidates_file_changed_after_plan_creation() {
        let fixture_dir = test_path("cleanup-plan-stale");
        fs::create_dir_all(&fixture_dir).expect("fixture dir");
        let file_path = fixture_dir.join("alpha.log");
        fs::write(&file_path, b"test").expect("fixture file");
        let file_identity = path_identity_evidence(&file_path).expect("file identity");
        let journal_path = test_path("cleanup-plan-stale-journal").join("journal.jsonl");
        let trash_adapter = Arc::new(RecordingTrashAdapter::default());
        let draft = ScanSnapshotDraft::new(vec![
            DraftNode::new(
                "root",
                NodeKind::Directory,
                size(4),
                ChildCompleteness::Complete,
            )
            .with_source_path(&fixture_dir)
            .with_children(vec![
                DraftNode::new(
                    "alpha.log",
                    NodeKind::File,
                    size(4),
                    ChildCompleteness::Complete,
                )
                .with_source_path(&file_path)
                .with_identity_evidence(file_identity),
            ]),
        ]);
        let state = AppState::new_with_cleanup(
            ServerConfig::local_default().with_auth_token("test-token"),
            Arc::new(FakeScannerBackend::new(draft)),
            Arc::new(FileCleanupJournal::new(journal_path)),
            trash_adapter.clone(),
            WorkerBudget::for_profile_with_parallelism(
                ScanResourceProfile::Balanced,
                std::num::NonZeroUsize::new(4).expect("cores"),
            ),
        );
        let app = build_router(state);
        let start = StartScanRequestDto::new(
            PROTOCOL_VERSION,
            DecimalU128Dto::from_u128(1),
            vec![ScanTargetDto::new(
                RawPathDto::new(fixture_dir.to_string_lossy().to_string()).expect("target path"),
                TargetScopeDto::LocalPath,
                BoundaryPolicyDto::StayOnInitialFilesystem,
                HardlinkPolicyDto::Ignore,
            )],
            MeasuredQuantityDto::ApparentBytes,
            clean_disk_protocol::ScanModeDto::Balanced,
        );
        let response = app
            .clone()
            .oneshot(post_json("/v1/scans", start))
            .await
            .expect("start response");
        assert_eq!(response.status(), StatusCode::ACCEPTED);
        let status = wait_for_completed_scan(&app, 1).await;
        assert_eq!(status.state(), SessionStateDto::Completed);

        let create_plan = CreateCleanupPlanRequestDto::new(
            PROTOCOL_VERSION,
            DecimalU128Dto::from_u128(2),
            vec![CleanupPlanItemRefDto::new(
                DecimalU128Dto::from_u128(1),
                DecimalU128Dto::from_u128(1),
                DecimalU64Dto::from_u64(2),
            )],
        );
        let response = app
            .clone()
            .oneshot(post_json("/v1/cleanup/plans", create_plan))
            .await
            .expect("create plan response");
        assert_eq!(response.status(), StatusCode::OK);
        let plan: CleanupPlanDto = response_json(response).await;
        assert_eq!(plan.state(), CleanupPlanStateDto::Ready);

        std::thread::sleep(Duration::from_millis(20));
        fs::write(&file_path, b"TEST").expect("mutate fixture file");

        let execute_plan = ExecuteCleanupPlanRequestDto::new(
            PROTOCOL_VERSION,
            DecimalU128Dto::from_u128(3),
            plan.plan_id().clone(),
        );
        let response = app
            .oneshot(post_json("/v1/cleanup/plans/1/execute", execute_plan))
            .await
            .expect("execute plan response");
        assert_eq!(response.status(), StatusCode::OK);
        let receipt: CleanupReceiptDto = response_json(response).await;

        assert_eq!(
            receipt.state(),
            CleanupReceiptStateDto::CompletedWithFailures
        );
        assert_eq!(
            receipt.items()[0].state(),
            CleanupItemOutcomeStateDto::Blocked
        );
        assert_eq!(receipt.items()[0].reason(), Some("stale_modified"));
        assert!(trash_adapter.paths.lock().expect("paths").is_empty());
    }

    #[tokio::test]
    async fn cleanup_plan_execute_rejects_unknown_plan_id() {
        let app = build_router(AppState::new_with_cleanup(
            ServerConfig::local_default().with_auth_token("test-token"),
            Arc::new(FakeScannerBackend::sample()),
            Arc::new(FileCleanupJournal::new(
                test_path("cleanup-unknown-plan-journal").join("journal.jsonl"),
            )),
            Arc::new(RecordingTrashAdapter::default()),
            WorkerBudget::for_profile_with_parallelism(
                ScanResourceProfile::Balanced,
                std::num::NonZeroUsize::new(4).expect("cores"),
            ),
        ));
        let execute_plan = ExecuteCleanupPlanRequestDto::new(
            PROTOCOL_VERSION,
            DecimalU128Dto::from_u128(3),
            DecimalU128Dto::from_u128(404),
        );

        let response = app
            .oneshot(post_json("/v1/cleanup/plans/404/execute", execute_plan))
            .await
            .expect("execute plan response");

        assert_eq!(response.status(), StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn cleanup_execute_blocks_file_changed_since_scan_identity() {
        let fixture_dir = test_path("cleanup-stale-identity");
        fs::create_dir_all(&fixture_dir).expect("fixture dir");
        let file_path = fixture_dir.join("alpha.log");
        fs::write(&file_path, b"test").expect("fixture file");
        let file_identity = path_identity_evidence(&file_path).expect("file identity");
        let journal_path = test_path("cleanup-stale-identity-journal").join("journal.jsonl");
        let trash_adapter = Arc::new(RecordingTrashAdapter::default());
        let draft = ScanSnapshotDraft::new(vec![
            DraftNode::new(
                "root",
                NodeKind::Directory,
                size(4),
                ChildCompleteness::Complete,
            )
            .with_source_path(&fixture_dir)
            .with_children(vec![
                DraftNode::new(
                    "alpha.log",
                    NodeKind::File,
                    size(4),
                    ChildCompleteness::Complete,
                )
                .with_source_path(&file_path)
                .with_identity_evidence(file_identity),
            ]),
        ]);
        let state = AppState::new_with_cleanup(
            ServerConfig::local_default().with_auth_token("test-token"),
            Arc::new(FakeScannerBackend::new(draft)),
            Arc::new(FileCleanupJournal::new(journal_path)),
            trash_adapter.clone(),
            WorkerBudget::for_profile_with_parallelism(
                ScanResourceProfile::Balanced,
                std::num::NonZeroUsize::new(4).expect("cores"),
            ),
        );
        let app = build_router(state);
        let start = StartScanRequestDto::new(
            PROTOCOL_VERSION,
            DecimalU128Dto::from_u128(1),
            vec![ScanTargetDto::new(
                RawPathDto::new(fixture_dir.to_string_lossy().to_string()).expect("target path"),
                TargetScopeDto::LocalPath,
                BoundaryPolicyDto::StayOnInitialFilesystem,
                HardlinkPolicyDto::Ignore,
            )],
            MeasuredQuantityDto::ApparentBytes,
            clean_disk_protocol::ScanModeDto::Balanced,
        );
        let response = app
            .clone()
            .oneshot(post_json("/v1/scans", start))
            .await
            .expect("start response");
        assert_eq!(response.status(), StatusCode::ACCEPTED);
        let status = wait_for_completed_scan(&app, 1).await;
        assert_eq!(status.state(), SessionStateDto::Completed);

        std::thread::sleep(Duration::from_millis(20));
        fs::write(&file_path, b"TEST").expect("mutate fixture file");

        let cleanup = ExecuteCleanupRequestDto::new(
            PROTOCOL_VERSION,
            DecimalU128Dto::from_u128(2),
            vec![CleanupPlanItemRefDto::new(
                DecimalU128Dto::from_u128(1),
                DecimalU128Dto::from_u128(1),
                DecimalU64Dto::from_u64(2),
            )],
        );
        let response = app
            .oneshot(post_json("/v1/cleanup/execute", cleanup))
            .await
            .expect("cleanup response");
        assert_eq!(response.status(), StatusCode::OK);
        let receipt: CleanupReceiptDto = response_json(response).await;

        assert_eq!(
            receipt.state(),
            CleanupReceiptStateDto::CompletedWithFailures
        );
        assert_eq!(
            receipt.items()[0].state(),
            CleanupItemOutcomeStateDto::Blocked
        );
        assert_eq!(receipt.items()[0].reason(), Some("stale_modified"));
        assert!(trash_adapter.paths.lock().expect("paths").is_empty());
    }

    #[tokio::test]
    async fn cleanup_execute_rejects_nested_plan_items_before_journal_or_trash() {
        let fixture_dir = test_path("cleanup-overlap");
        fs::create_dir_all(&fixture_dir).expect("fixture dir");
        let file_path = fixture_dir.join("alpha.log");
        fs::write(&file_path, b"test").expect("fixture file");
        let journal_path = test_path("cleanup-overlap-journal").join("journal.jsonl");
        let trash_adapter = Arc::new(RecordingTrashAdapter::default());
        let draft = ScanSnapshotDraft::new(vec![
            DraftNode::new(
                "root",
                NodeKind::Directory,
                size(4),
                ChildCompleteness::Complete,
            )
            .with_source_path(&fixture_dir)
            .with_children(vec![
                DraftNode::new(
                    "alpha.log",
                    NodeKind::File,
                    size(4),
                    ChildCompleteness::Complete,
                )
                .with_source_path(&file_path),
            ]),
        ]);
        let state = AppState::new_with_cleanup(
            ServerConfig::local_default().with_auth_token("test-token"),
            Arc::new(FakeScannerBackend::new(draft)),
            Arc::new(FileCleanupJournal::new(journal_path.clone())),
            trash_adapter.clone(),
            WorkerBudget::for_profile_with_parallelism(
                ScanResourceProfile::Balanced,
                std::num::NonZeroUsize::new(4).expect("cores"),
            ),
        );
        let app = build_router(state);
        let start = StartScanRequestDto::new(
            PROTOCOL_VERSION,
            DecimalU128Dto::from_u128(1),
            vec![ScanTargetDto::new(
                RawPathDto::new(fixture_dir.to_string_lossy().to_string()).expect("target path"),
                TargetScopeDto::LocalPath,
                BoundaryPolicyDto::StayOnInitialFilesystem,
                HardlinkPolicyDto::Ignore,
            )],
            MeasuredQuantityDto::ApparentBytes,
            clean_disk_protocol::ScanModeDto::Balanced,
        );
        let response = app
            .clone()
            .oneshot(post_json("/v1/scans", start))
            .await
            .expect("start response");
        assert_eq!(response.status(), StatusCode::ACCEPTED);
        let status = wait_for_completed_scan(&app, 1).await;
        assert_eq!(status.state(), SessionStateDto::Completed);

        let cleanup = ExecuteCleanupRequestDto::new(
            PROTOCOL_VERSION,
            DecimalU128Dto::from_u128(2),
            vec![
                CleanupPlanItemRefDto::new(
                    DecimalU128Dto::from_u128(1),
                    DecimalU128Dto::from_u128(1),
                    DecimalU64Dto::from_u64(1),
                ),
                CleanupPlanItemRefDto::new(
                    DecimalU128Dto::from_u128(1),
                    DecimalU128Dto::from_u128(1),
                    DecimalU64Dto::from_u64(2),
                ),
            ],
        );
        let response = app
            .oneshot(post_json("/v1/cleanup/execute", cleanup))
            .await
            .expect("cleanup response");

        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
        assert!(!journal_path.exists());
        assert!(trash_adapter.paths.lock().expect("paths").is_empty());
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn cleanup_execute_rejects_active_overlapping_operation() {
        let fixture_dir = test_path("cleanup-active-overlap");
        fs::create_dir_all(&fixture_dir).expect("fixture dir");
        let file_path = fixture_dir.join("alpha.log");
        fs::write(&file_path, b"test").expect("fixture file");
        let journal_path = test_path("cleanup-active-overlap-journal").join("journal.jsonl");
        let trash_adapter = Arc::new(SlowRecordingTrashAdapter::new(Duration::from_millis(200)));
        let draft = ScanSnapshotDraft::new(vec![
            DraftNode::new(
                "root",
                NodeKind::Directory,
                size(4),
                ChildCompleteness::Complete,
            )
            .with_source_path(&fixture_dir)
            .with_children(vec![
                DraftNode::new(
                    "alpha.log",
                    NodeKind::File,
                    size(4),
                    ChildCompleteness::Complete,
                )
                .with_source_path(&file_path),
            ]),
        ]);
        let state = AppState::new_with_cleanup(
            ServerConfig::local_default().with_auth_token("test-token"),
            Arc::new(FakeScannerBackend::new(draft)),
            Arc::new(FileCleanupJournal::new(journal_path)),
            trash_adapter.clone(),
            WorkerBudget::for_profile_with_parallelism(
                ScanResourceProfile::Balanced,
                std::num::NonZeroUsize::new(4).expect("cores"),
            ),
        );
        let app = build_router(state);
        let start = StartScanRequestDto::new(
            PROTOCOL_VERSION,
            DecimalU128Dto::from_u128(1),
            vec![ScanTargetDto::new(
                RawPathDto::new(fixture_dir.to_string_lossy().to_string()).expect("target path"),
                TargetScopeDto::LocalPath,
                BoundaryPolicyDto::StayOnInitialFilesystem,
                HardlinkPolicyDto::Ignore,
            )],
            MeasuredQuantityDto::ApparentBytes,
            clean_disk_protocol::ScanModeDto::Balanced,
        );
        let response = app
            .clone()
            .oneshot(post_json("/v1/scans", start))
            .await
            .expect("start response");
        assert_eq!(response.status(), StatusCode::ACCEPTED);
        let status = wait_for_completed_scan(&app, 1).await;
        assert_eq!(status.state(), SessionStateDto::Completed);

        let first_cleanup = ExecuteCleanupRequestDto::new(
            PROTOCOL_VERSION,
            DecimalU128Dto::from_u128(2),
            vec![CleanupPlanItemRefDto::new(
                DecimalU128Dto::from_u128(1),
                DecimalU128Dto::from_u128(1),
                DecimalU64Dto::from_u64(2),
            )],
        );
        let second_cleanup = ExecuteCleanupRequestDto::new(
            PROTOCOL_VERSION,
            DecimalU128Dto::from_u128(3),
            vec![CleanupPlanItemRefDto::new(
                DecimalU128Dto::from_u128(1),
                DecimalU128Dto::from_u128(1),
                DecimalU64Dto::from_u64(2),
            )],
        );
        let first_app = app.clone();
        let first = tokio::spawn(async move {
            first_app
                .oneshot(post_json("/v1/cleanup/execute", first_cleanup))
                .await
                .expect("first cleanup response")
        });
        tokio::time::sleep(Duration::from_millis(40)).await;
        let second_response = app
            .oneshot(post_json("/v1/cleanup/execute", second_cleanup))
            .await
            .expect("second cleanup response");
        let first_response = first.await.expect("first task");

        assert_eq!(second_response.status(), StatusCode::CONFLICT);
        assert_eq!(first_response.status(), StatusCode::OK);
        assert_eq!(trash_adapter.paths.lock().expect("paths").len(), 1);
    }

    #[tokio::test]
    async fn cleanup_execute_rejects_zero_command_id_before_journal_or_trash() {
        let journal_path = test_path("cleanup-zero-command").join("journal.jsonl");
        let trash_adapter = Arc::new(RecordingTrashAdapter::default());
        let state = AppState::new_with_cleanup(
            ServerConfig::local_default().with_auth_token("test-token"),
            Arc::new(FakeScannerBackend::sample()),
            Arc::new(FileCleanupJournal::new(journal_path.clone())),
            trash_adapter.clone(),
            WorkerBudget::for_profile_with_parallelism(
                ScanResourceProfile::Balanced,
                std::num::NonZeroUsize::new(4).expect("cores"),
            ),
        );
        let app = build_router(state);
        let cleanup = ExecuteCleanupRequestDto::new(
            PROTOCOL_VERSION,
            DecimalU128Dto::from_u128(0),
            vec![CleanupPlanItemRefDto::new(
                DecimalU128Dto::from_u128(1),
                DecimalU128Dto::from_u128(1),
                DecimalU64Dto::from_u64(1),
            )],
        );

        let response = app
            .oneshot(post_json("/v1/cleanup/execute", cleanup))
            .await
            .expect("cleanup response");

        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
        assert!(!journal_path.exists());
        assert!(trash_adapter.paths.lock().expect("paths").is_empty());
    }

    #[tokio::test]
    async fn cleanup_execute_rejects_duplicate_items_before_journal_or_trash() {
        let journal_path = test_path("cleanup-duplicates").join("journal.jsonl");
        let trash_adapter = Arc::new(RecordingTrashAdapter::default());
        let item = CleanupPlanItemRefDto::new(
            DecimalU128Dto::from_u128(1),
            DecimalU128Dto::from_u128(1),
            DecimalU64Dto::from_u64(1),
        );
        let state = AppState::new_with_cleanup(
            ServerConfig::local_default().with_auth_token("test-token"),
            Arc::new(FakeScannerBackend::sample()),
            Arc::new(FileCleanupJournal::new(journal_path.clone())),
            trash_adapter.clone(),
            WorkerBudget::for_profile_with_parallelism(
                ScanResourceProfile::Balanced,
                std::num::NonZeroUsize::new(4).expect("cores"),
            ),
        );
        let app = build_router(state);
        let cleanup = ExecuteCleanupRequestDto::new(
            PROTOCOL_VERSION,
            DecimalU128Dto::from_u128(8),
            vec![item.clone(), item],
        );

        let response = app
            .oneshot(post_json("/v1/cleanup/execute", cleanup))
            .await
            .expect("cleanup response");

        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
        assert!(!journal_path.exists());
        assert!(trash_adapter.paths.lock().expect("paths").is_empty());
    }

    #[test]
    fn cleanup_recovery_marks_dispatched_item_unknown_without_auto_retry() {
        let journal = FileCleanupJournal::new(test_path("cleanup-recovery").join("journal.jsonl"));
        journal
            .append(&CleanupJournalRecord::IntentRecorded {
                operation_id: "7".to_string(),
                command_id: "7".to_string(),
                items: vec![PersistedCleanupItemRef {
                    session_id: "1".to_string(),
                    snapshot_id: "1".to_string(),
                    node_id: 2,
                }],
                at_unix_ms: 10,
            })
            .expect("intent");
        journal
            .append(&CleanupJournalRecord::ReceiptSkeletonRecorded {
                operation_id: "7".to_string(),
                command_id: "7".to_string(),
                items: vec![PersistedCleanupReceiptItem {
                    node_id: 2,
                    display_name: "alpha.log".to_string(),
                    state: CleanupItemOutcomeStateDto::Pending,
                    restore_expectation: RestoreExpectationLevelDto::Unknown,
                    reason: None,
                    resulting_location: None,
                }],
                at_unix_ms: 11,
                low_disk_reserve_ready: true,
            })
            .expect("skeleton");
        journal
            .append(&CleanupJournalRecord::ItemDispatchRecorded {
                operation_id: "7".to_string(),
                node_id: 2,
                at_unix_ms: 12,
            })
            .expect("dispatch");

        let inbox = journal.recovery_inbox().expect("recovery inbox");

        assert_eq!(inbox.interrupted_receipts().len(), 1);
        let receipt = &inbox.interrupted_receipts()[0];
        assert_eq!(
            receipt.state(),
            CleanupReceiptStateDto::CompletedWithUnknowns
        );
        assert_eq!(
            receipt.items()[0].state(),
            CleanupItemOutcomeStateDto::UnknownRequiresReview
        );
    }

    #[test]
    fn shutdown_cancels_running_sessions_without_touching_terminal_snapshots() {
        let budget = WorkerBudget::for_profile_with_parallelism(
            ScanResourceProfile::Balanced,
            std::num::NonZeroUsize::new(4).expect("cores"),
        );
        let registry = SessionRegistry::new(budget, 8, 1);
        let running_id = ScanSessionId::new(1).expect("running id");
        let running_cancellation = CancellationToken::new();
        registry.insert_running(running_id, running_cancellation.clone());

        let canceled = registry.cancel_all_running();

        assert_eq!(canceled, 1);
        assert!(running_cancellation.is_canceled());
        assert_eq!(registry.diagnostics().cancel_requested_sessions, 1);
    }

    #[test]
    fn origin_match_allows_localhost_ports_but_rejects_prefixed_hosts() {
        assert!(origin_matches_allowed(
            "http://localhost:5173",
            "http://localhost"
        ));
        assert!(!origin_matches_allowed(
            "http://localhost:not-a-port",
            "http://localhost"
        ));
        assert!(!origin_matches_allowed(
            "http://localhost:99999",
            "http://localhost"
        ));
        assert!(!origin_matches_allowed(
            "http://localhost.evil.example",
            "http://localhost"
        ));
    }

    #[test]
    fn websocket_auth_accepts_browser_subprotocol_token() {
        let budget = WorkerBudget::for_profile_with_parallelism(
            ScanResourceProfile::Balanced,
            std::num::NonZeroUsize::new(4).expect("cores"),
        );
        let state = AppState::new(
            ServerConfig::local_default().with_auth_token("test-token"),
            Arc::new(FakeScannerBackend::sample()),
            budget,
        );
        let mut headers = HeaderMap::new();
        headers.insert(
            "sec-websocket-protocol",
            format!("{EVENTS_WEBSOCKET_SUBPROTOCOL}, {EVENTS_WEBSOCKET_TOKEN_PREFIX}test-token")
                .parse()
                .expect("protocol header"),
        );

        assert!(authorize_events_socket(&state, &headers).is_ok());
    }

    #[test]
    fn websocket_auth_rejects_empty_configured_token() {
        let budget = WorkerBudget::for_profile_with_parallelism(
            ScanResourceProfile::Balanced,
            std::num::NonZeroUsize::new(4).expect("cores"),
        );
        let state = AppState::new(
            ServerConfig::local_default().with_auth_token(" "),
            Arc::new(FakeScannerBackend::sample()),
            budget,
        );
        let mut headers = HeaderMap::new();
        headers.insert("authorization", "Bearer ".parse().expect("auth header"));

        assert_eq!(
            authorize_events_socket(&state, &headers).expect_err("empty token"),
            StatusCode::UNAUTHORIZED
        );
    }

    #[test]
    fn permission_probe_actions_are_platform_specific_and_fail_closed() {
        assert_eq!(
            required_action_for_probe_on_platform(
                PermissionProbeStatusDto::Denied,
                RuntimePlatformDto::Macos
            ),
            PermissionRequiredActionDto::OpenMacosFullDiskAccess
        );
        assert_eq!(
            required_action_for_probe_on_platform(
                PermissionProbeStatusDto::Denied,
                RuntimePlatformDto::Windows
            ),
            PermissionRequiredActionDto::RunAsAdministrator
        );
        assert_eq!(
            required_action_for_probe_on_platform(
                PermissionProbeStatusDto::Denied,
                RuntimePlatformDto::Linux
            ),
            PermissionRequiredActionDto::ReviewLinuxPermissions
        );
        assert_eq!(
            required_action_for_probe_on_platform(
                PermissionProbeStatusDto::Denied,
                RuntimePlatformDto::Unknown
            ),
            PermissionRequiredActionDto::Unknown
        );
        assert_eq!(
            required_action_for_probe_on_platform(
                PermissionProbeStatusDto::Degraded,
                RuntimePlatformDto::Linux
            ),
            PermissionRequiredActionDto::ReviewLinuxPermissions
        );
        assert_eq!(
            required_action_for_probe_on_platform(
                PermissionProbeStatusDto::Degraded,
                RuntimePlatformDto::Macos
            ),
            PermissionRequiredActionDto::None
        );
    }

    #[test]
    fn signed_direct_packaging_proves_predictable_scanner_identity() {
        let packaging = packaging_proof_from(
            DistributionChannelDto::Direct,
            PackageModeDto::AppBundle,
            ScannerProcessKindDto::BundledHelper,
            true,
            false,
            false,
            Vec::new(),
        );
        let proof = runtime_proof_from_packaging(packaging);

        assert_eq!(
            proof.scanner_identity().verification(),
            ScannerIdentityVerificationDto::Verified
        );
        assert_eq!(
            proof.scanner_identity().process_kind(),
            ScannerProcessKindDto::BundledHelper
        );
        assert_eq!(
            proof.packaging().distribution_channel(),
            DistributionChannelDto::Direct
        );
        assert_eq!(proof.packaging().package_mode(), PackageModeDto::AppBundle);
        assert!(proof.packaging().signed_build());
        assert!(proof.packaging().limitations().is_empty());
        assert!(
            proof
                .packaging()
                .update_safety()
                .quiesce_required_before_update()
        );
    }

    #[test]
    fn external_scanner_process_never_verifies_even_when_signed() {
        let packaging = packaging_proof_from(
            DistributionChannelDto::Direct,
            PackageModeDto::Portable,
            ScannerProcessKindDto::ExternalProcess,
            true,
            false,
            false,
            vec!["external_scanner_process".to_string()],
        );
        let proof = runtime_proof_from_packaging(packaging);

        assert_eq!(
            proof.scanner_identity().verification(),
            ScannerIdentityVerificationDto::Unverified
        );
        assert!(
            proof
                .packaging()
                .limitations()
                .iter()
                .any(|limitation| limitation == "external_scanner_process")
        );
    }

    #[test]
    fn scan_only_packaging_smoke_accepts_signed_release_app_helper() {
        let packaging = packaging_proof_from(
            DistributionChannelDto::Direct,
            PackageModeDto::AppBundle,
            ScannerProcessKindDto::BundledHelper,
            true,
            false,
            false,
            Vec::new(),
        );
        let helper_path =
            Path::new("/Applications/Clean Disk.app/Contents/Helpers/clean-disk-server");

        let report = scan_only_packaging_smoke_report_from_packaging(&packaging, Some(helper_path));

        assert!(report.passed());
        assert!(report.failures().is_empty());
    }

    #[test]
    fn scan_only_packaging_smoke_rejects_reduced_dev_identity() {
        let packaging = packaging_proof_from(
            DistributionChannelDto::Development,
            PackageModeDto::DevelopmentShell,
            ScannerProcessKindDto::ExternalProcess,
            false,
            true,
            true,
            vec![
                "debug_build".to_string(),
                "unsigned_build".to_string(),
                "development_shell".to_string(),
                "external_scanner_process".to_string(),
            ],
        );

        let report = scan_only_packaging_smoke_report_from_packaging(&packaging, None);

        assert!(!report.passed());
        assert_eq!(
            report.failures(),
            &[
                ScanOnlyPackagingSmokeFailure::DevelopmentDistribution,
                ScanOnlyPackagingSmokeFailure::DevelopmentShell,
                ScanOnlyPackagingSmokeFailure::UnsignedBuild,
                ScanOnlyPackagingSmokeFailure::DebugBuild,
                ScanOnlyPackagingSmokeFailure::SandboxedBuild,
                ScanOnlyPackagingSmokeFailure::ExternalScannerProcess,
            ]
        );
    }

    #[test]
    fn release_build_defaults_to_direct_distribution() {
        assert_eq!(default_distribution_channel_name(true), "development");
        assert_eq!(default_distribution_channel_name(false), "direct");
    }

    #[test]
    fn scan_only_packaging_smoke_rejects_development_distribution_for_release_shape() {
        let packaging = packaging_proof_from(
            DistributionChannelDto::Development,
            PackageModeDto::AppBundle,
            ScannerProcessKindDto::BundledHelper,
            true,
            false,
            false,
            Vec::new(),
        );
        let helper_path =
            Path::new("/Applications/Clean Disk.app/Contents/Helpers/clean-disk-server");

        let report = scan_only_packaging_smoke_report_from_packaging(&packaging, Some(helper_path));

        assert!(!report.passed());
        assert_eq!(
            report.failures(),
            &[ScanOnlyPackagingSmokeFailure::DevelopmentDistribution]
        );
    }

    #[test]
    fn scan_only_packaging_smoke_rejects_helper_claim_outside_app_bundle() {
        let packaging = packaging_proof_from(
            DistributionChannelDto::Direct,
            PackageModeDto::AppBundle,
            ScannerProcessKindDto::BundledHelper,
            true,
            false,
            false,
            Vec::new(),
        );
        let external_path = Path::new("/tmp/clean-disk-server");

        let report =
            scan_only_packaging_smoke_report_from_packaging(&packaging, Some(external_path));

        if cfg!(target_os = "macos") {
            assert_eq!(
                report.failures(),
                &[ScanOnlyPackagingSmokeFailure::MissingBundledHelperIdentity]
            );
        } else {
            assert!(report.passed());
        }
    }

    #[test]
    fn scanner_process_kind_detects_macos_app_helper_paths() {
        let helper_path =
            Path::new("/Applications/Clean Disk.app/Contents/Helpers/clean-disk-server");
        let app_path = Path::new("/Applications/Clean Disk.app/Contents/MacOS/Clean Disk");
        let external_path = Path::new("/usr/local/bin/clean-disk-server");

        assert_eq!(
            scanner_process_kind_from_path(helper_path),
            Some(ScannerProcessKindDto::BundledHelper)
        );
        assert_eq!(
            scanner_process_kind_from_path(app_path),
            Some(ScannerProcessKindDto::AppBundle)
        );
        assert_eq!(scanner_process_kind_from_path(external_path), None);
    }

    #[test]
    fn scan_only_packaging_smoke_requires_update_quiesce_and_receipt_preservation() {
        let packaging = PackagingProofDto::new(
            DistributionChannelDto::Direct,
            PackageModeDto::AppBundle,
            false,
            true,
            false,
            ScannerProcessKindDto::BundledHelper,
            Vec::new(),
            UpdateSafetyDto::new(false, SupportLevelDto::Unknown, SupportLevelDto::Unknown),
        );

        let helper_path =
            Path::new("/Applications/Clean Disk.app/Contents/Helpers/clean-disk-server");
        let report = scan_only_packaging_smoke_report_from_packaging(&packaging, Some(helper_path));

        assert_eq!(
            report.failures(),
            &[
                ScanOnlyPackagingSmokeFailure::MissingUpdateQuiesceGate,
                ScanOnlyPackagingSmokeFailure::MissingReceiptPreservation,
            ]
        );
    }

    #[test]
    fn production_config_fails_closed_without_required_local_token() {
        assert_eq!(
            ServerConfig::local_with_required_token(None).expect_err("missing token"),
            ServerConfigError::MissingLocalAuthToken
        );
        assert_eq!(
            ServerConfig::local_with_required_token(Some("  ".to_string()))
                .expect_err("empty token"),
            ServerConfigError::EmptyLocalAuthToken
        );
    }
}
