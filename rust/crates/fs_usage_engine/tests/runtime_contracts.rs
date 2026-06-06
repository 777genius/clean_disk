use fs_usage_core::{ScanSessionId, SnapshotId};
use fs_usage_engine::{
    BoundedEventBuffer, CpuPriorityHint, EventSink, IoPriorityHint, PanicPolicy,
    RuntimeAdmissionController, RuntimeAdmissionError, RuntimeLane, ScanEvent, ScanResourceProfile,
    WorkerBudget,
};
use std::num::NonZeroUsize;

fn cores(value: usize) -> NonZeroUsize {
    NonZeroUsize::new(value).expect("test core count")
}

#[test]
fn resource_profiles_are_bounded_and_ordered() {
    let background =
        WorkerBudget::for_profile_with_parallelism(ScanResourceProfile::Background, cores(8));
    let balanced =
        WorkerBudget::for_profile_with_parallelism(ScanResourceProfile::Balanced, cores(8));
    let fast = WorkerBudget::for_profile_with_parallelism(ScanResourceProfile::Fast, cores(8));

    assert_eq!(background.profile(), ScanResourceProfile::Background);
    assert_eq!(balanced.profile(), ScanResourceProfile::Balanced);
    assert_eq!(fast.profile(), ScanResourceProfile::Fast);
    assert!(background.scanner_threads() <= balanced.scanner_threads());
    assert!(balanced.scanner_threads() <= fast.scanner_threads());
    assert!(background.max_event_queue_items() < balanced.max_event_queue_items());
    assert!(balanced.max_event_queue_items() < fast.max_event_queue_items());
    assert!(background.progress_coalescing_ms() > balanced.progress_coalescing_ms());
    assert!(balanced.progress_coalescing_ms() > fast.progress_coalescing_ms());
    assert_eq!(background.io_priority_hint(), IoPriorityHint::Low);
    assert_eq!(balanced.cpu_priority_hint(), CpuPriorityHint::Normal);
    assert_eq!(fast.io_priority_hint(), IoPriorityHint::High);
    assert_eq!(
        fast.shutdown_policy().panic_policy(),
        PanicPolicy::FailSession
    );
}

#[test]
fn admission_controller_rejects_excess_active_scans_and_releases_on_drop() {
    let budget =
        WorkerBudget::for_profile_with_parallelism(ScanResourceProfile::Balanced, cores(8));
    let controller = RuntimeAdmissionController::new(budget);

    let first = controller.try_acquire_scan().expect("first scan permit");
    assert_eq!(controller.active_scans(), 1);

    let err = controller
        .try_acquire_scan()
        .expect_err("second scan should be rejected by MVP budget");
    assert_eq!(
        err,
        RuntimeAdmissionError::ResourceExhausted {
            lane: RuntimeLane::ScannerWorkerPool,
            limit: 1
        }
    );

    drop(first);
    assert_eq!(controller.active_scans(), 0);
    let _second = controller.try_acquire_scan().expect("permit is released");
}

#[test]
fn bounded_event_buffer_coalesces_progress_and_keeps_terminal_events() {
    let session_id = ScanSessionId::new(42).expect("session id");
    let snapshot_id = SnapshotId::new(42).expect("snapshot id");
    let mut buffer = BoundedEventBuffer::new(cores(2));

    buffer.emit(ScanEvent::Started { session_id });
    buffer.emit(ScanEvent::Progress {
        session_id,
        scanned_items: 10,
    });
    buffer.emit(ScanEvent::Progress {
        session_id,
        scanned_items: 20,
    });
    buffer.emit(ScanEvent::SnapshotPublished {
        session_id,
        snapshot_id,
    });

    assert_eq!(buffer.events().len(), 2);
    assert!(matches!(buffer.events()[0], ScanEvent::Started { .. }));
    assert!(matches!(
        buffer.events()[1],
        ScanEvent::SnapshotPublished { .. }
    ));
    assert_eq!(buffer.coalesced_progress_count(), 1);
    assert_eq!(buffer.evicted_event_count(), 1);
}
