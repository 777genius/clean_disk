use fs_usage_core::{
    BoundaryPolicy, ChildCompleteness, HardlinkPolicy, IssueCode, MeasuredQuantity, NodeKind,
    ScanSessionId, ScanTarget, SupportLevel, TargetPath, TargetScope,
};
use fs_usage_engine::{
    CancellationToken, EventSink, ScanEvent, ScanFailure, ScanSession, ScanState, SearchQuery,
    TopItemsKind, TopItemsQuery, VecEventSink, scan::BackendScanRequest,
};
use fs_usage_pdu::PduScannerBackend;
use std::{
    fs,
    path::PathBuf,
    time::{SystemTime, UNIX_EPOCH},
};

#[cfg(any(unix, windows))]
use fs_usage_engine::{ChildSort, ChildrenPageQuery, NodeDetailsQuery};

#[cfg(windows)]
use fs_usage_engine::QueryFailure;

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

#[cfg(windows)]
fn completed_windows_session(
    session_id_value: u128,
    backend: &PduScannerBackend,
    target: PathBuf,
) -> ScanSession {
    let session_id = ScanSessionId::new(session_id_value).expect("session id");
    let cancellation = CancellationToken::new();
    let mut events = VecEventSink::default();
    let mut session = ScanSession::new(session_id);

    session
        .start(
            backend,
            request(session_id, target),
            &mut events,
            &cancellation,
        )
        .expect("pdu windows scan succeeds");

    assert_eq!(session.state(), &ScanState::Completed);
    session
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

#[cfg(windows)]
#[test]
fn pdu_backend_scans_windows_paths_with_spaces_and_backslashes() {
    let fixture = TempFixture::new("pdu_windows_spaces");
    let program_dir = fixture.path().join("Program Files");
    let cache_dir = program_dir.join("Cache Data");
    fs::create_dir_all(&cache_dir).expect("cache dir");
    fs::write(cache_dir.join("asset.bin"), [3_u8; 17]).expect("asset file");
    fs::write(fixture.path().join("root.log"), [4_u8; 5]).expect("root file");

    let session_id = ScanSessionId::new(209).expect("session id");
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
        .expect("windows path scan succeeds");

    let snapshot = session.snapshot().expect("snapshot");
    let root_id = snapshot.root_ids()[0];
    let children = snapshot
        .children_page(ChildrenPageQuery::new_sorted(
            snapshot.snapshot_id(),
            root_id,
            None,
            10,
            ChildSort::NameAsc,
        ))
        .expect("root children");
    let program = children
        .items
        .iter()
        .find(|item| item.name() == "Program Files")
        .expect("program files node");
    let details = snapshot
        .node_details(NodeDetailsQuery::new(snapshot.snapshot_id(), program.id()))
        .expect("program details");
    let source_path = details
        .source_path()
        .expect("source path")
        .to_string_lossy();

    assert!(source_path.contains("Program Files"));
    assert!(source_path.contains('\\'));
    assert_eq!(details.child_ids().len(), 1);
}

#[cfg(windows)]
#[test]
fn pdu_backend_windows_search_is_case_insensitive_for_file_names() {
    let fixture = TempFixture::new("pdu_windows_search");
    fs::write(fixture.path().join("MixedCASE.Cache"), [5_u8; 11]).expect("mixed case file");

    let session_id = ScanSessionId::new(210).expect("session id");
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
        .expect("windows search scan succeeds");

    let snapshot = session.snapshot().expect("snapshot");
    let lower = snapshot
        .search_page(SearchQuery::new(
            snapshot.snapshot_id(),
            "mixedcase.cache",
            None,
            10,
        ))
        .expect("lowercase search");
    let upper = snapshot
        .search_page(SearchQuery::new(snapshot.snapshot_id(), "CACHE", None, 10))
        .expect("uppercase search");

    assert_eq!(lower.items.len(), 1);
    assert_eq!(lower.items[0].name(), "MixedCASE.Cache");
    assert_eq!(upper.items.len(), 1);
    assert_eq!(upper.items[0].name(), "MixedCASE.Cache");
}

#[cfg(windows)]
#[test]
fn pdu_backend_windows_sorts_and_paginates_root_children() {
    let fixture = TempFixture::new("pdu_windows_sort_page");
    fs::write(fixture.path().join("Zeta.tmp"), [1_u8; 4]).expect("zeta file");
    fs::write(fixture.path().join("alpha.tmp"), [2_u8; 1]).expect("alpha file");
    fs::write(fixture.path().join("Beta.tmp"), [3_u8; 2]).expect("beta file");
    fs::write(fixture.path().join("delta.tmp"), [4_u8; 8]).expect("delta file");

    let backend = PduScannerBackend::default();
    let session = completed_windows_session(211, &backend, fixture.path().clone());
    let snapshot = session.snapshot().expect("snapshot");
    let root_id = snapshot.root_ids()[0];

    let first_name_page = snapshot
        .children_page(ChildrenPageQuery::new_sorted(
            snapshot.snapshot_id(),
            root_id,
            None,
            2,
            ChildSort::NameAsc,
        ))
        .expect("first name page");
    assert_eq!(
        first_name_page
            .items
            .iter()
            .map(|item| item.name())
            .collect::<Vec<_>>(),
        ["alpha.tmp", "Beta.tmp"]
    );

    let second_name_page = snapshot
        .children_page(ChildrenPageQuery::new_sorted(
            snapshot.snapshot_id(),
            root_id,
            first_name_page.next_cursor,
            2,
            ChildSort::NameAsc,
        ))
        .expect("second name page");
    assert_eq!(
        second_name_page
            .items
            .iter()
            .map(|item| item.name())
            .collect::<Vec<_>>(),
        ["delta.tmp", "Zeta.tmp"]
    );
    assert!(second_name_page.next_cursor.is_none());

    let size_desc = snapshot
        .children_page(ChildrenPageQuery::new_sorted(
            snapshot.snapshot_id(),
            root_id,
            None,
            4,
            ChildSort::SizeDesc,
        ))
        .expect("size desc page");
    assert_eq!(
        size_desc
            .items
            .iter()
            .map(|item| item.name())
            .collect::<Vec<_>>(),
        ["delta.tmp", "Zeta.tmp", "Beta.tmp", "alpha.tmp"]
    );

    let cursor_mismatch = snapshot
        .children_page(ChildrenPageQuery::new_sorted(
            snapshot.snapshot_id(),
            root_id,
            first_name_page.next_cursor,
            2,
            ChildSort::SizeDesc,
        ))
        .expect_err("cursor from another sort must be rejected");
    assert_eq!(cursor_mismatch, QueryFailure::CursorQueryMismatch);
}

#[cfg(windows)]
#[test]
fn pdu_backend_windows_preserves_unicode_file_details_and_top_items() {
    let fixture = TempFixture::new("pdu_windows_unicode");
    let cache_dir = fixture.path().join("Cache Data #1");
    fs::create_dir_all(&cache_dir).expect("cache dir");
    let unicode_file_name = format!(
        "unicode-{}.bin",
        "\u{0434}\u{0430}\u{043d}\u{043d}\u{044b}\u{0435}"
    );
    fs::write(cache_dir.join(&unicode_file_name), [9_u8; 31]).expect("unicode file");
    fs::write(fixture.path().join("small.bin"), [1_u8; 3]).expect("small file");

    let backend = PduScannerBackend::default();
    let session = completed_windows_session(212, &backend, fixture.path().clone());
    let snapshot = session.snapshot().expect("snapshot");

    let top_files = snapshot
        .top_items_page(TopItemsQuery::new(
            snapshot.snapshot_id(),
            TopItemsKind::Files,
            None,
            5,
        ))
        .expect("top files");
    let top_file = top_files.items.first().expect("top file");
    assert_eq!(top_file.name(), unicode_file_name);
    assert_eq!(top_file.kind(), NodeKind::File);
    assert_eq!(top_file.size().raw_value(), 31);

    let unicode_search = snapshot
        .search_page(SearchQuery::new(
            snapshot.snapshot_id(),
            "\u{0434}\u{0430}\u{043d}",
            None,
            10,
        ))
        .expect("unicode search");
    assert_eq!(unicode_search.items.len(), 1);
    assert_eq!(unicode_search.items[0].name(), unicode_file_name);

    let details = snapshot
        .node_details(NodeDetailsQuery::new(
            snapshot.snapshot_id(),
            unicode_search.items[0].id(),
        ))
        .expect("unicode file details");
    let source_path = details
        .source_path()
        .expect("source path")
        .to_string_lossy();
    assert!(source_path.contains("Cache Data #1"));
    assert!(source_path.contains(&unicode_file_name));
    assert!(source_path.contains('\\'));
    assert_eq!(details.summary().kind(), NodeKind::File);
    assert_eq!(details.summary().child_count(), 0);
    assert!(details.child_ids().is_empty());
}

#[cfg(windows)]
#[test]
fn pdu_backend_windows_depth_limit_collapses_nested_branch() {
    let fixture = TempFixture::new("pdu_windows_depth");
    let level_one = fixture.path().join("Level One");
    let level_two = level_one.join("Level Two");
    fs::create_dir_all(&level_two).expect("nested dir");
    fs::write(level_two.join("leaf.bin"), [7_u8; 6]).expect("leaf file");

    let backend = PduScannerBackend::new(2);
    let session = completed_windows_session(213, &backend, fixture.path().clone());
    let snapshot = session.snapshot().expect("snapshot");
    let root_id = snapshot.root_ids()[0];
    let children = snapshot
        .children_page(ChildrenPageQuery::new_sorted(
            snapshot.snapshot_id(),
            root_id,
            None,
            10,
            ChildSort::NameAsc,
        ))
        .expect("root children");
    let collapsed = children
        .items
        .iter()
        .find(|item| item.name() == "Level One")
        .expect("level one node");

    assert_eq!(collapsed.kind(), NodeKind::Directory);
    assert_eq!(
        collapsed.child_completeness(),
        ChildCompleteness::CollapsedByDepth
    );
    assert!(
        snapshot
            .issues()
            .iter()
            .any(|issue| issue.code() == IssueCode::BackendLimitation)
    );

    let details = snapshot
        .node_details(NodeDetailsQuery::new(
            snapshot.snapshot_id(),
            collapsed.id(),
        ))
        .expect("collapsed details");
    let source_path = details
        .source_path()
        .expect("source path")
        .to_string_lossy();
    assert!(source_path.ends_with("Level One"));
    assert!(source_path.contains('\\'));
    assert!(details.child_ids().is_empty());
}

#[cfg(windows)]
#[test]
fn pdu_backend_windows_missing_target_records_metadata_evidence() {
    let fixture = TempFixture::new("pdu_windows_missing");
    let missing = fixture.path().join("Missing Folder").join("child");
    let session_id = ScanSessionId::new(214).expect("session id");
    let backend = PduScannerBackend::default();
    let cancellation = CancellationToken::new();
    let mut events = VecEventSink::default();
    let mut session = ScanSession::new(session_id);

    session
        .start(
            &backend,
            request(session_id, missing.clone()),
            &mut events,
            &cancellation,
        )
        .expect("missing windows target degrades into snapshot");

    let snapshot = session.snapshot().expect("snapshot");
    let issue = snapshot
        .issues()
        .iter()
        .find(|issue| issue.code() == IssueCode::MetadataUnavailable)
        .expect("metadata issue");
    let evidence = issue.evidence();
    let evidence_path = evidence.path().expect("issue path");
    assert!(evidence_path.contains("Missing Folder"));
    assert!(evidence_path.contains('\\'));
    assert!(evidence.operation().is_some());
    assert!(evidence.message().is_some());
    assert_eq!(session.state(), &ScanState::Completed);
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
