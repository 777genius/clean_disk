use crate::{
    events::ScanEvent,
    scan::{
        BackendScanOutput, BackendScanRequest, CancellationToken, ScanFailure,
        ScannerBackendCapabilities,
    },
};

pub trait EventSink {
    fn emit(&mut self, event: ScanEvent);
}

pub trait ScannerBackend: Send + Sync {
    fn capabilities(&self) -> ScannerBackendCapabilities;

    fn scan(
        &self,
        request: BackendScanRequest,
        events: &mut dyn EventSink,
        cancellation: &CancellationToken,
    ) -> Result<BackendScanOutput, ScanFailure>;
}
