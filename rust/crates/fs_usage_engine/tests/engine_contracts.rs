use fs_usage_core::{
    BoundaryPolicy, HardlinkPolicy, IssueCode, IssueEvidence, IssueSeverity, MeasuredQuantity,
    ScanIssue, ScanSessionId, ScanTarget, TargetPath, TargetScope,
};
use fs_usage_engine::{
    CancellationToken, ChildrenPageQuery, FakeScannerBackend, QueryFailure, ScanEvent, ScanSession,
    ScanState, VecEventSink, scan::BackendScanRequest,
};

fn request(session_id: ScanSessionId) -> BackendScanRequest {
    BackendScanRequest::new(
        session_id,
        vec![ScanTarget::new(
            TargetPath::new("/tmp").expect("target path"),
            TargetScope::LocalPath,
            BoundaryPolicy::StayOnInitialFilesystem,
            HardlinkPolicy::Detect,
        )],
        MeasuredQuantity::ApparentBytes,
    )
}

#[test]
fn fake_scan_creates_snapshot() {
    let session_id = ScanSessionId::new(10).expect("session id");
    let backend = FakeScannerBackend::sample();
    let cancellation = CancellationToken::new();
    let mut events = VecEventSink::default();
    let mut session = ScanSession::new(session_id);

    session
        .start(&backend, request(session_id), &mut events, &cancellation)
        .expect("fake scan succeeds");

    assert_eq!(session.state(), &ScanState::Completed);
    assert_eq!(session.backend_run_id().expect("backend run id").get(), 1);
    assert_eq!(
        session
            .backend_capabilities()
            .expect("backend capabilities")
            .backend_name(),
        "fake"
    );
    let snapshot = session.snapshot().expect("snapshot");
    assert_eq!(snapshot.snapshot_id().get(), 10);
    assert_eq!(snapshot.root_ids().len(), 1);
    assert!(matches!(events.events()[0], ScanEvent::Started { .. }));
    assert!(events.events().iter().any(|event| matches!(
        event,
        ScanEvent::Progress {
            scanned_items: 3,
            ..
        }
    )));
    let growing_batch = events
        .events()
        .iter()
        .find_map(|event| match event {
            ScanEvent::GrowingTreeBatch { batch } => Some(batch),
            _ => None,
        })
        .expect("growing tree batch");
    assert_eq!(growing_batch.scanned_items(), 3);
    assert_eq!(growing_batch.events().len(), 6);
    assert!(
        events
            .events()
            .iter()
            .any(|event| matches!(event, ScanEvent::SnapshotPublished { .. }))
    );
}

#[test]
fn fake_scan_preserves_snapshot_issues() {
    let session_id = ScanSessionId::new(14).expect("session id");
    let issue = ScanIssue::new(
        IssueCode::PermissionDenied,
        IssueSeverity::Warning,
        IssueEvidence::new(
            Some("/tmp/protected".to_string()),
            Some("read_dir".to_string()),
            Some("permission denied".to_string()),
        ),
    );
    let backend = FakeScannerBackend::sample_with_issues(vec![issue.clone()]);
    let cancellation = CancellationToken::new();
    let mut events = VecEventSink::default();
    let mut session = ScanSession::new(session_id);

    session
        .start(&backend, request(session_id), &mut events, &cancellation)
        .expect("fake scan succeeds");

    let snapshot = session.snapshot().expect("snapshot");
    assert_eq!(snapshot.issues(), &[issue]);
}

#[test]
fn children_query_returns_pages() {
    let session_id = ScanSessionId::new(11).expect("session id");
    let backend = FakeScannerBackend::sample();
    let cancellation = CancellationToken::new();
    let mut events = VecEventSink::default();
    let mut session = ScanSession::new(session_id);
    session
        .start(&backend, request(session_id), &mut events, &cancellation)
        .expect("fake scan succeeds");
    let snapshot = session.snapshot().expect("snapshot");
    let root_id = snapshot.root_ids()[0];

    let first_page = snapshot
        .children_page(ChildrenPageQuery::new(
            snapshot.snapshot_id(),
            root_id,
            None,
            1,
        ))
        .expect("first page");
    assert_eq!(first_page.items.len(), 1);
    assert!(first_page.next_cursor.is_some());

    let second_page = snapshot
        .children_page(ChildrenPageQuery::new(
            snapshot.snapshot_id(),
            root_id,
            first_page.next_cursor,
            1,
        ))
        .expect("second page");
    assert_eq!(second_page.items.len(), 1);
    assert!(second_page.next_cursor.is_none());
}

#[test]
fn cursor_invalidates_on_wrong_snapshot() {
    let session_id = ScanSessionId::new(12).expect("session id");
    let backend = FakeScannerBackend::sample();
    let cancellation = CancellationToken::new();
    let mut events = VecEventSink::default();
    let mut session = ScanSession::new(session_id);
    session
        .start(&backend, request(session_id), &mut events, &cancellation)
        .expect("fake scan succeeds");
    let snapshot = session.snapshot().expect("snapshot");
    let root_id = snapshot.root_ids()[0];
    let foreign_cursor = snapshot
        .children_page(ChildrenPageQuery::new(
            snapshot.snapshot_id(),
            root_id,
            None,
            1,
        ))
        .expect("first page")
        .next_cursor
        .expect("cursor");
    let other_snapshot_id = ScanSessionId::new(99).expect("session id");
    let other_snapshot = fs_usage_engine::SnapshotPublicationGate::publish_for_session(
        other_snapshot_id,
        fs_usage_engine::ScanSnapshotDraft::new(vec![
            fs_usage_engine::DraftNode::new(
                "other-root",
                fs_usage_core::NodeKind::Directory,
                fs_usage_core::SizeFact::new(
                    0,
                    MeasuredQuantity::ApparentBytes,
                    Some(fs_usage_core::SizeBytes::ZERO),
                    fs_usage_core::EvidenceConfidence::Exact,
                ),
                fs_usage_core::ChildCompleteness::Complete,
            )
            .with_children(vec![
                fs_usage_engine::DraftNode::new(
                    "other-a",
                    fs_usage_core::NodeKind::File,
                    fs_usage_core::SizeFact::new(
                        1,
                        MeasuredQuantity::ApparentBytes,
                        Some(fs_usage_core::SizeBytes::new(1)),
                        fs_usage_core::EvidenceConfidence::Exact,
                    ),
                    fs_usage_core::ChildCompleteness::Complete,
                ),
                fs_usage_engine::DraftNode::new(
                    "other-b",
                    fs_usage_core::NodeKind::File,
                    fs_usage_core::SizeFact::new(
                        2,
                        MeasuredQuantity::ApparentBytes,
                        Some(fs_usage_core::SizeBytes::new(2)),
                        fs_usage_core::EvidenceConfidence::Exact,
                    ),
                    fs_usage_core::ChildCompleteness::Complete,
                ),
            ]),
        ]),
        Vec::new(),
    );
    let other_root_id = other_snapshot.root_ids()[0];

    let err = other_snapshot
        .children_page(ChildrenPageQuery::new(
            other_snapshot.snapshot_id(),
            other_root_id,
            Some(foreign_cursor),
            1,
        ))
        .expect_err("cursor should be rejected");

    assert_eq!(err, QueryFailure::CursorSnapshotMismatch);
}

#[test]
fn cancellation_changes_session_state() {
    let session_id = ScanSessionId::new(13).expect("session id");
    let backend = FakeScannerBackend::sample();
    let cancellation = CancellationToken::new();
    cancellation.cancel();
    let mut events = VecEventSink::default();
    let mut session = ScanSession::new(session_id);

    let err = session
        .start(&backend, request(session_id), &mut events, &cancellation)
        .expect_err("canceled before scan");

    assert_eq!(err, fs_usage_engine::ScanFailure::Canceled);
    assert_eq!(session.state(), &ScanState::Canceled);
    assert!(
        events
            .events()
            .iter()
            .any(|event| matches!(event, ScanEvent::Canceled { .. }))
    );
}
