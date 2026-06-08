use fs_usage_core::{
    BoundaryPolicy, ChildCompleteness, HardlinkPolicy, IssueCode, MeasuredQuantity, NodeKind,
    ScanSessionId, ScanTarget, SupportLevel, TargetPath, TargetScope,
};
use fs_usage_engine::{
    CancellationToken, ChildrenPageQuery, EventSink, ScanEvent, ScanFailure, ScanSession,
    ScanState, SearchQuery, TopItemsKind, TopItemsQuery, VecEventSink, scan::BackendScanRequest,
};
use fs_usage_pdu::PduScannerBackend;
use std::{
    fs,
    path::PathBuf,
    time::{SystemTime, UNIX_EPOCH},
};

#[cfg(unix)]
use std::os::unix::fs::{PermissionsExt, symlink};

#[cfg(unix)]
use std::{ffi::OsString, os::unix::ffi::OsStringExt};

struct TempFixture {
    root: PathBuf,
}

struct CancelOnProgressSink {
    cancellation: CancellationToken,
    events: Vec<ScanEvent>,
}

impl CancelOnProgressSink {
    fn new(cancellation: CancellationToken) -> Self {
        Self {
            cancellation,
            events: Vec::new(),
        }
    }

    fn events(&self) -> &[ScanEvent] {
        &self.events
    }
}

impl EventSink for CancelOnProgressSink {
    fn emit(&mut self, event: ScanEvent) {
        if matches!(event, ScanEvent::Progress { .. }) {
            self.cancellation.cancel();
        }
        self.events.push(event);
    }
}

impl TempFixture {
    fn new(name: &str) -> Self {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("system time")
            .as_nanos();
        let root = std::env::temp_dir().join(format!(
            "clean_disk_{name}_{}_{}",
            std::process::id(),
            nanos
        ));
        fs::create_dir_all(&root).expect("create fixture root");
        Self { root }
    }

    fn path(&self) -> &PathBuf {
        &self.root
    }
}

impl Drop for TempFixture {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.root);
    }
}

fn request(session_id: ScanSessionId, target: PathBuf) -> BackendScanRequest {
    request_with_policy(
        session_id,
        target,
        MeasuredQuantity::ApparentBytes,
        HardlinkPolicy::Ignore,
    )
}

fn request_with_policy(
    session_id: ScanSessionId,
    target: PathBuf,
    measurement: MeasuredQuantity,
    hardlink_policy: HardlinkPolicy,
) -> BackendScanRequest {
    BackendScanRequest::new(
        session_id,
        vec![ScanTarget::new(
            TargetPath::new(target.to_string_lossy().into_owned()).expect("target path"),
            TargetScope::LocalPath,
            BoundaryPolicy::CrossFilesystems,
            hardlink_policy,
        )],
        measurement,
    )
}

#[test]
fn pdu_backend_scans_fixture_into_product_snapshot() {
    let fixture = TempFixture::new("pdu_scan");
    fs::create_dir_all(fixture.path().join("cache")).expect("cache dir");
    fs::create_dir_all(fixture.path().join("logs")).expect("logs dir");
    fs::write(fixture.path().join("cache/a.bin"), [1_u8; 10]).expect("cache file");
    fs::write(fixture.path().join("logs/b.log"), [2_u8; 20]).expect("log file");

    let session_id = ScanSessionId::new(200).expect("session id");
    let backend = PduScannerBackend::default();
    let cancellation = CancellationToken::new();
    let mut events = VecEventSink::default();
    let mut session = ScanSession::new(session_id);

    session
        .start(
            &backend,
            request(session_id, fixture.path().clone()),
            &mut events,
            &cancellation,
        )
        .expect("pdu scan succeeds");

    assert_eq!(session.state(), &ScanState::Completed);
    assert_eq!(
        session
            .backend_capabilities()
            .expect("capabilities")
            .backend_name(),
        "parallel-disk-usage"
    );
    assert_eq!(
        session
            .backend_capabilities()
            .expect("capabilities")
            .capabilities()
            .growing_tree_streaming(),
        SupportLevel::Supported
    );
    let snapshot = session.snapshot().expect("snapshot");
    assert_eq!(snapshot.root_ids().len(), 1);

    let root = snapshot.node(snapshot.root_ids()[0]).expect("root");
    assert_eq!(root.child_ids().len(), 2);
    assert!(root.size().raw_value() >= 30);
    let progress_index = events
        .events()
        .iter()
        .position(|event| {
            matches!(
                event,
                ScanEvent::Progress {
                    scanned_items,
                    ..
                } if *scanned_items > 0
            )
        })
        .expect("positive progress event");
    let snapshot_index = events
        .events()
        .iter()
        .position(|event| matches!(event, ScanEvent::SnapshotPublished { .. }))
        .expect("snapshot event");
    assert!(progress_index < snapshot_index);
    let growing_index = events
        .events()
        .iter()
        .position(|event| matches!(event, ScanEvent::GrowingTreeBatch { .. }))
        .expect("growing tree event");
    assert!(growing_index < snapshot_index);
    assert!(max_root_growing_size(events.events()).is_some_and(|size| size >= 30));

    let search = snapshot
        .search_page(SearchQuery::new(snapshot.snapshot_id(), "cache", None, 10))
        .expect("search page");
    assert_eq!(search.items.len(), 1);

    let top = snapshot
        .top_items_page(TopItemsQuery::new(
            snapshot.snapshot_id(),
            TopItemsKind::Files,
            None,
            2,
        ))
        .expect("top page");
    assert_eq!(top.items.len(), 2);
    assert_eq!(top.items[0].name(), "b.log");
}

#[test]
fn pdu_backend_streams_growing_tree_before_final_snapshot() {
    let fixture = TempFixture::new("pdu_growing");
    fs::create_dir_all(fixture.path().join("cache")).expect("cache dir");
    fs::write(fixture.path().join("cache/a.bin"), [1_u8; 10]).expect("cache file");
    fs::write(fixture.path().join("cache/b.bin"), [2_u8; 20]).expect("cache file");

    let session_id = ScanSessionId::new(209).expect("session id");
    let backend = PduScannerBackend::with_progress_emit_interval(
        PduScannerBackend::DEFAULT_MAX_DEPTH,
        std::time::Duration::from_millis(1),
    );
    let cancellation = CancellationToken::new();
    let mut events = VecEventSink::default();
    let mut session = ScanSession::new(session_id);

    session
        .start(
            &backend,
            request(session_id, fixture.path().clone()),
            &mut events,
            &cancellation,
        )
        .expect("pdu scan succeeds");

    let snapshot_index = events
        .events()
        .iter()
        .position(|event| matches!(event, ScanEvent::SnapshotPublished { .. }))
        .expect("snapshot event");
    let growing_index = events
        .events()
        .iter()
        .position(|event| matches!(event, ScanEvent::GrowingTreeBatch { .. }))
        .expect("growing tree batch");

    assert!(growing_index < snapshot_index);
    assert!(events.events().iter().any(|event| matches!(
        event,
        ScanEvent::GrowingTreeBatch { batch }
            if batch.events().iter().any(|growing| matches!(
                growing,
                fs_usage_engine::GrowingTreeEvent::NodeDiscovered {
                    parent_id: Some(_),
                    ..
                }
            ))
    )));
    assert!(max_root_growing_size(events.events()).is_some_and(|size| size >= 30));
    assert_eq!(discovered_file_count(events.events()), 0);
}

#[test]
fn pdu_backend_growing_tree_does_not_stream_one_row_per_file() {
    let fixture = TempFixture::new("pdu_growing_many_files");
    let cache = fixture.path().join("cache");
    fs::create_dir_all(&cache).expect("cache dir");
    for index in 0..512 {
        fs::write(cache.join(format!("file-{index}.bin")), [1_u8; 32]).expect("cache file");
    }

    let session_id = ScanSessionId::new(210).expect("session id");
    let backend = PduScannerBackend::with_progress_emit_interval(
        PduScannerBackend::DEFAULT_MAX_DEPTH,
        std::time::Duration::from_millis(1),
    );
    let cancellation = CancellationToken::new();
    let mut events = VecEventSink::default();
    let mut session = ScanSession::new(session_id);

    session
        .start(
            &backend,
            request(session_id, fixture.path().clone()),
            &mut events,
            &cancellation,
        )
        .expect("pdu scan succeeds");

    let discovered = discovered_node_count(events.events());
    assert!(
        discovered <= 2,
        "expected root and cache only, got {discovered}"
    );
    assert_eq!(discovered_file_count(events.events()), 0);
    assert!(max_root_growing_size(events.events()).is_some_and(|size| size >= 16_384));
}

#[test]
fn pdu_backend_maps_missing_target_error_into_scan_issue() {
    let fixture = TempFixture::new("pdu_missing");
    let missing = fixture.path().join("missing");
    let session_id = ScanSessionId::new(201).expect("session id");
    let backend = PduScannerBackend::default();
    let cancellation = CancellationToken::new();
    let mut events = VecEventSink::default();
    let mut session = ScanSession::new(session_id);

    session
        .start(
            &backend,
            request(session_id, missing),
            &mut events,
            &cancellation,
        )
        .expect("pdu reports missing target as degraded snapshot");

    let snapshot = session.snapshot().expect("snapshot");
    assert!(!snapshot.issues().is_empty());
}

#[test]
fn pdu_backend_rejects_unsupported_mvp_request_shape() {
    let fixture = TempFixture::new("pdu_invalid");
    let session_id = ScanSessionId::new(202).expect("session id");
    let backend = PduScannerBackend::default();
    let cancellation = CancellationToken::new();
    let mut events = VecEventSink::default();
    let mut session = ScanSession::new(session_id);
    let request = request_with_policy(
        session_id,
        fixture.path().clone(),
        MeasuredQuantity::AllocatedBytes,
        HardlinkPolicy::Ignore,
    );

    let err = session
        .start(&backend, request, &mut events, &cancellation)
        .expect_err("allocated bytes are not supported yet");

    assert!(matches!(
        err,
        fs_usage_engine::ScanFailure::InvalidRequest(_)
    ));
}

#[test]
fn pdu_backend_records_hardlink_policy_as_limitation_evidence() {
    let fixture = TempFixture::new("pdu_hardlinks");
    fs::write(fixture.path().join("a.bin"), [1_u8; 10]).expect("file");
    fs::hard_link(
        fixture.path().join("a.bin"),
        fixture.path().join("a-link.bin"),
    )
    .expect("hardlink");
    let session_id = ScanSessionId::new(203).expect("session id");
    let backend = PduScannerBackend::default();
    let cancellation = CancellationToken::new();
    let mut events = VecEventSink::default();
    let mut session = ScanSession::new(session_id);

    session
        .start(
            &backend,
            request_with_policy(
                session_id,
                fixture.path().clone(),
                MeasuredQuantity::ApparentBytes,
                HardlinkPolicy::Detect,
            ),
            &mut events,
            &cancellation,
        )
        .expect("scan succeeds with limitation evidence");

    let snapshot = session.snapshot().expect("snapshot");
    assert!(
        snapshot
            .issues()
            .iter()
            .any(|issue| issue.code() == IssueCode::BackendLimitation)
    );
}

#[test]
fn pdu_backend_late_output_is_not_published_after_cancellation() {
    let fixture = TempFixture::new("pdu_cancel_late");
    fs::write(fixture.path().join("a.bin"), [1_u8; 10]).expect("file");
    let session_id = ScanSessionId::new(208).expect("session id");
    let backend = PduScannerBackend::default();
    let cancellation = CancellationToken::new();
    let mut events = CancelOnProgressSink::new(cancellation.clone());
    let mut session = ScanSession::new(session_id);

    let err = session
        .start(
            &backend,
            request(session_id, fixture.path().clone()),
            &mut events,
            &cancellation,
        )
        .expect_err("late backend output must be dropped after cancellation");

    assert_eq!(err, ScanFailure::Canceled);
    assert_eq!(session.state(), &ScanState::Canceled);
    assert!(session.snapshot().is_none());
    assert!(
        events
            .events()
            .iter()
            .any(|event| matches!(event, ScanEvent::Progress { .. }))
    );
    assert!(
        events
            .events()
            .iter()
            .any(|event| matches!(event, ScanEvent::Canceled { .. }))
    );
}

#[test]
fn pdu_backend_marks_depth_limited_tree_as_collapsed() {
    let fixture = TempFixture::new("pdu_depth");
    fs::create_dir_all(fixture.path().join("nested")).expect("nested dir");
    fs::write(fixture.path().join("nested/a.bin"), [1_u8; 10]).expect("file");
    let session_id = ScanSessionId::new(204).expect("session id");
    let backend = PduScannerBackend::new(1);
    let cancellation = CancellationToken::new();
    let mut events = VecEventSink::default();
    let mut session = ScanSession::new(session_id);

    session
        .start(
            &backend,
            request(session_id, fixture.path().clone()),
            &mut events,
            &cancellation,
        )
        .expect("scan succeeds with max depth");

    let snapshot = session.snapshot().expect("snapshot");
    let root = snapshot.node(snapshot.root_ids()[0]).expect("root");
    assert_eq!(
        root.child_completeness(),
        ChildCompleteness::CollapsedByDepth
    );
    assert!(
        snapshot
            .issues()
            .iter()
            .any(|issue| issue.code() == IssueCode::BackendLimitation)
    );
    assert!(max_root_growing_size(events.events()).is_some_and(|size| size >= 10));
    assert!(!events.events().iter().any(|event| matches!(
        event,
        ScanEvent::GrowingTreeBatch { batch }
            if batch.events().iter().any(|growing| matches!(
                growing,
                fs_usage_engine::GrowingTreeEvent::NodeDiscovered {
                    parent_id: Some(_),
                    ..
                }
            ))
    )));
}

fn max_root_growing_size(events: &[ScanEvent]) -> Option<u64> {
    let mut root_id = None;
    let mut max_size = None;

    for event in events {
        let ScanEvent::GrowingTreeBatch { batch } = event else {
            continue;
        };
        for growing in batch.events() {
            match growing {
                fs_usage_engine::GrowingTreeEvent::NodeDiscovered {
                    parent_id: None,
                    node_id,
                    ..
                } => root_id = Some(*node_id),
                fs_usage_engine::GrowingTreeEvent::NodeSizeUpdated {
                    node_id,
                    aggregate_size,
                    ..
                }
                | fs_usage_engine::GrowingTreeEvent::NodeCompleted {
                    node_id,
                    aggregate_size,
                    ..
                } if Some(*node_id) == root_id => {
                    max_size = Some(max_size.unwrap_or(0).max(aggregate_size.raw_value()));
                }
                _ => {}
            }
        }
    }

    max_size
}

fn discovered_node_count(events: &[ScanEvent]) -> usize {
    events
        .iter()
        .map(|event| match event {
            ScanEvent::GrowingTreeBatch { batch } => batch
                .events()
                .iter()
                .filter(|event| {
                    matches!(
                        event,
                        fs_usage_engine::GrowingTreeEvent::NodeDiscovered { .. }
                    )
                })
                .count(),
            _ => 0,
        })
        .sum()
}

fn discovered_file_count(events: &[ScanEvent]) -> usize {
    events
        .iter()
        .map(|event| match event {
            ScanEvent::GrowingTreeBatch { batch } => batch
                .events()
                .iter()
                .filter(|event| {
                    matches!(
                        event,
                        fs_usage_engine::GrowingTreeEvent::NodeDiscovered {
                            kind: NodeKind::File,
                            ..
                        }
                    )
                })
                .count(),
            _ => 0,
        })
        .sum()
}

#[cfg(unix)]
#[test]
fn pdu_backend_preserves_symlink_kind_without_following_target() {
    let fixture = TempFixture::new("pdu_symlink");
    fs::write(fixture.path().join("target.bin"), [1_u8; 10]).expect("target");
    symlink(
        fixture.path().join("target.bin"),
        fixture.path().join("target-link"),
    )
    .expect("symlink");
    let session_id = ScanSessionId::new(205).expect("session id");
    let backend = PduScannerBackend::default();
    let cancellation = CancellationToken::new();
    let mut events = VecEventSink::default();
    let mut session = ScanSession::new(session_id);

    session
        .start(
            &backend,
            request(session_id, fixture.path().clone()),
            &mut events,
            &cancellation,
        )
        .expect("scan succeeds");

    let snapshot = session.snapshot().expect("snapshot");
    let root_id = snapshot.root_ids()[0];
    let children = snapshot
        .children_page(ChildrenPageQuery::new(
            snapshot.snapshot_id(),
            root_id,
            None,
            10,
        ))
        .expect("children");
    let link = children
        .items
        .iter()
        .find(|item| item.name() == "target-link")
        .expect("link row");

    assert_eq!(link.kind(), NodeKind::Symlink);
    assert_eq!(link.child_count(), 0);
}

#[cfg(unix)]
#[test]
fn pdu_backend_maps_permission_denied_into_issue() {
    let fixture = TempFixture::new("pdu_permission");
    let protected = fixture.path().join("protected");
    fs::create_dir_all(&protected).expect("protected dir");
    fs::set_permissions(&protected, fs::Permissions::from_mode(0o000)).expect("chmod protected");
    let session_id = ScanSessionId::new(206).expect("session id");
    let backend = PduScannerBackend::default();
    let cancellation = CancellationToken::new();
    let mut events = VecEventSink::default();
    let mut session = ScanSession::new(session_id);

    let result = session.start(
        &backend,
        request(session_id, fixture.path().clone()),
        &mut events,
        &cancellation,
    );
    fs::set_permissions(&protected, fs::Permissions::from_mode(0o755)).expect("restore chmod");
    result.expect("scan succeeds with permission issue");

    let snapshot = session.snapshot().expect("snapshot");
    assert!(
        snapshot
            .issues()
            .iter()
            .any(|issue| issue.code() == IssueCode::PermissionDenied)
    );
}

#[cfg(unix)]
#[test]
fn pdu_backend_records_non_utf8_name_as_lossy_issue() {
    let fixture = TempFixture::new("pdu_non_utf8");
    let file_name = OsString::from_vec(vec![b'b', b'a', b'd', b'-', 0xff]);
    if fs::write(fixture.path().join(file_name), [1_u8; 10]).is_err() {
        return;
    }
    let session_id = ScanSessionId::new(207).expect("session id");
    let backend = PduScannerBackend::default();
    let cancellation = CancellationToken::new();
    let mut events = VecEventSink::default();
    let mut session = ScanSession::new(session_id);

    session
        .start(
            &backend,
            request(session_id, fixture.path().clone()),
            &mut events,
            &cancellation,
        )
        .expect("scan succeeds");

    let snapshot = session.snapshot().expect("snapshot");
    assert!(
        snapshot
            .issues()
            .iter()
            .any(|issue| issue.code() == IssueCode::NonUtf8Path)
    );
}
