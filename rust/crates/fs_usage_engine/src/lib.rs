#![forbid(unsafe_code)]

pub mod events;
pub mod fake;
pub mod ports;
pub mod read_model;
pub mod runtime;
pub mod scan;

pub use events::{ScanEvent, VecEventSink};
pub use fake::FakeScannerBackend;
pub use ports::{EventSink, ScannerBackend};
pub use read_model::{
    ChildSort, ChildrenPageQuery, DraftNode, NodeArena, NodeDetails, NodeDetailsQuery,
    NodePageItem, NodeRecord, Page, PageCursor, QueryFailure, ScanSnapshot, ScanSnapshotDraft,
    SearchQuery, SnapshotPublicationGate, TopItemsKind, TopItemsQuery,
};
pub use runtime::{
    BoundedEventBuffer, CpuPriorityHint, IoPriorityHint, PanicPolicy, RuntimeAdmissionController,
    RuntimeAdmissionError, RuntimeLane, ScanPermit, ScanResourceProfile, ShutdownPolicy,
    WorkerBudget,
};
pub use scan::{
    BackendRunId, BackendScanOutput, BackendScanRequest, CancellationToken, ScanFailure,
    ScanSession, ScanState, ScannerBackendCapabilities,
};
