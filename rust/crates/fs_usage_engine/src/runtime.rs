use crate::{EventSink, ScanEvent};
use std::{
    num::NonZeroUsize,
    sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    },
};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum RuntimeLane {
    AsyncTransport,
    CommandValidation,
    ScannerWorkerPool,
    MetadataEnrichmentPool,
    IndexBuildPool,
    JournalWriter,
    PlatformTrashThread,
    EventFanout,
    SupportBundleWorker,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ScanResourceProfile {
    Background,
    Balanced,
    Fast,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum IoPriorityHint {
    Low,
    Normal,
    High,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum CpuPriorityHint {
    Low,
    Normal,
    High,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum PanicPolicy {
    FailSession,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ShutdownPolicy {
    cancel_on_shutdown: bool,
    grace_ms: u64,
    panic_policy: PanicPolicy,
}

impl ShutdownPolicy {
    pub const fn new(cancel_on_shutdown: bool, grace_ms: u64, panic_policy: PanicPolicy) -> Self {
        Self {
            cancel_on_shutdown,
            grace_ms,
            panic_policy,
        }
    }

    pub const fn cancel_on_shutdown(self) -> bool {
        self.cancel_on_shutdown
    }

    pub const fn grace_ms(self) -> u64 {
        self.grace_ms
    }

    pub const fn panic_policy(self) -> PanicPolicy {
        self.panic_policy
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct WorkerBudget {
    profile: ScanResourceProfile,
    scanner_threads: NonZeroUsize,
    metadata_threads: NonZeroUsize,
    index_threads: NonZeroUsize,
    max_active_scans: NonZeroUsize,
    max_pending_jobs: NonZeroUsize,
    max_event_queue_items: NonZeroUsize,
    max_query_page_size: NonZeroUsize,
    progress_coalescing_ms: u64,
    io_priority_hint: IoPriorityHint,
    cpu_priority_hint: CpuPriorityHint,
    shutdown_policy: ShutdownPolicy,
}

impl WorkerBudget {
    pub fn for_profile(profile: ScanResourceProfile) -> Self {
        let parallelism = std::thread::available_parallelism()
            .unwrap_or_else(|_| NonZeroUsize::new(1).expect("one is non-zero"));
        Self::for_profile_with_parallelism(profile, parallelism)
    }

    pub fn for_profile_with_parallelism(
        profile: ScanResourceProfile,
        parallelism: NonZeroUsize,
    ) -> Self {
        let cores = parallelism.get();
        match profile {
            ScanResourceProfile::Background => Self {
                profile,
                scanner_threads: non_zero(cores / 4),
                metadata_threads: non_zero(1),
                index_threads: non_zero(1),
                max_active_scans: non_zero(1),
                max_pending_jobs: non_zero(8),
                max_event_queue_items: non_zero(256),
                max_query_page_size: non_zero(200),
                progress_coalescing_ms: 500,
                io_priority_hint: IoPriorityHint::Low,
                cpu_priority_hint: CpuPriorityHint::Low,
                shutdown_policy: ShutdownPolicy::new(true, 5_000, PanicPolicy::FailSession),
            },
            ScanResourceProfile::Balanced => Self {
                profile,
                scanner_threads: non_zero(cores / 2),
                metadata_threads: non_zero(cores / 4),
                index_threads: non_zero(cores / 4),
                max_active_scans: non_zero(1),
                max_pending_jobs: non_zero(16),
                max_event_queue_items: non_zero(1_024),
                max_query_page_size: non_zero(500),
                progress_coalescing_ms: 250,
                io_priority_hint: IoPriorityHint::Normal,
                cpu_priority_hint: CpuPriorityHint::Normal,
                shutdown_policy: ShutdownPolicy::new(true, 10_000, PanicPolicy::FailSession),
            },
            ScanResourceProfile::Fast => Self {
                profile,
                scanner_threads: non_zero(cores),
                metadata_threads: non_zero(cores / 2),
                index_threads: non_zero(cores / 2),
                max_active_scans: non_zero(1),
                max_pending_jobs: non_zero(32),
                max_event_queue_items: non_zero(2_048),
                max_query_page_size: non_zero(1_000),
                progress_coalescing_ms: 100,
                io_priority_hint: IoPriorityHint::High,
                cpu_priority_hint: CpuPriorityHint::High,
                shutdown_policy: ShutdownPolicy::new(true, 15_000, PanicPolicy::FailSession),
            },
        }
    }

    pub const fn profile(self) -> ScanResourceProfile {
        self.profile
    }

    pub const fn scanner_threads(self) -> NonZeroUsize {
        self.scanner_threads
    }

    pub const fn metadata_threads(self) -> NonZeroUsize {
        self.metadata_threads
    }

    pub const fn index_threads(self) -> NonZeroUsize {
        self.index_threads
    }

    pub const fn max_active_scans(self) -> NonZeroUsize {
        self.max_active_scans
    }

    pub const fn max_pending_jobs(self) -> NonZeroUsize {
        self.max_pending_jobs
    }

    pub const fn max_event_queue_items(self) -> NonZeroUsize {
        self.max_event_queue_items
    }

    pub const fn max_query_page_size(self) -> NonZeroUsize {
        self.max_query_page_size
    }

    pub const fn progress_coalescing_ms(self) -> u64 {
        self.progress_coalescing_ms
    }

    pub const fn io_priority_hint(self) -> IoPriorityHint {
        self.io_priority_hint
    }

    pub const fn cpu_priority_hint(self) -> CpuPriorityHint {
        self.cpu_priority_hint
    }

    pub const fn shutdown_policy(self) -> ShutdownPolicy {
        self.shutdown_policy
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RuntimeAdmissionError {
    ResourceExhausted { lane: RuntimeLane, limit: usize },
}

#[derive(Debug, Clone)]
pub struct RuntimeAdmissionController {
    max_active_scans: usize,
    active_scans: Arc<AtomicUsize>,
}

impl RuntimeAdmissionController {
    pub fn new(budget: WorkerBudget) -> Self {
        Self {
            max_active_scans: budget.max_active_scans().get(),
            active_scans: Arc::new(AtomicUsize::new(0)),
        }
    }

    pub fn try_acquire_scan(&self) -> Result<ScanPermit, RuntimeAdmissionError> {
        loop {
            let active = self.active_scans.load(Ordering::SeqCst);
            if active >= self.max_active_scans {
                return Err(RuntimeAdmissionError::ResourceExhausted {
                    lane: RuntimeLane::ScannerWorkerPool,
                    limit: self.max_active_scans,
                });
            }
            if self
                .active_scans
                .compare_exchange(active, active + 1, Ordering::SeqCst, Ordering::SeqCst)
                .is_ok()
            {
                return Ok(ScanPermit {
                    active_scans: Arc::clone(&self.active_scans),
                });
            }
        }
    }

    pub fn active_scans(&self) -> usize {
        self.active_scans.load(Ordering::SeqCst)
    }
}

#[derive(Debug)]
pub struct ScanPermit {
    active_scans: Arc<AtomicUsize>,
}

impl Drop for ScanPermit {
    fn drop(&mut self) {
        self.active_scans.fetch_sub(1, Ordering::SeqCst);
    }
}

#[derive(Debug)]
pub struct BoundedEventBuffer {
    max_items: usize,
    events: Vec<ScanEvent>,
    coalesced_progress_count: u64,
    evicted_event_count: u64,
}

impl BoundedEventBuffer {
    pub fn new(max_items: NonZeroUsize) -> Self {
        Self {
            max_items: max_items.get(),
            events: Vec::new(),
            coalesced_progress_count: 0,
            evicted_event_count: 0,
        }
    }

    pub fn events(&self) -> &[ScanEvent] {
        &self.events
    }

    pub const fn coalesced_progress_count(&self) -> u64 {
        self.coalesced_progress_count
    }

    pub const fn evicted_event_count(&self) -> u64 {
        self.evicted_event_count
    }

    fn push_lifecycle(&mut self, event: ScanEvent) {
        if self.events.len() >= self.max_items {
            if let Some(position) = self
                .events
                .iter()
                .position(|event| matches!(event, ScanEvent::Progress { .. }))
            {
                self.events.remove(position);
            } else {
                self.events.remove(0);
            }
            self.evicted_event_count += 1;
        }
        self.events.push(event);
    }

    fn push_progress(&mut self, event: ScanEvent) {
        if let Some(position) = self
            .events
            .iter()
            .rposition(|event| matches!(event, ScanEvent::Progress { .. }))
        {
            self.events[position] = event;
            self.coalesced_progress_count += 1;
            return;
        }

        if self.events.len() >= self.max_items {
            self.evicted_event_count += 1;
            return;
        }

        self.events.push(event);
    }
}

impl EventSink for BoundedEventBuffer {
    fn emit(&mut self, event: ScanEvent) {
        match event {
            ScanEvent::Progress { .. } => self.push_progress(event),
            _ => self.push_lifecycle(event),
        }
    }
}

fn non_zero(value: usize) -> NonZeroUsize {
    NonZeroUsize::new(value.max(1)).expect("value is clamped to non-zero")
}
