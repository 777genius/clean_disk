use fs_usage_core::{
    ChildCompleteness, EvidenceConfidence, IssueCode, IssueEvidence, IssueSeverity,
    MeasuredQuantity, NodeKind, ScanIssue, SizeBytes, SizeFact, SnapshotId,
};
use fs_usage_engine::{
    ChildSort, ChildrenPageQuery, DraftNode, NodeDetailsQuery, QueryFailure, ScanSnapshotDraft,
    SearchQuery, SnapshotPublicationGate, TopItemsKind, TopItemsQuery,
};

fn size(bytes: u64) -> SizeFact {
    SizeFact::new(
        bytes,
        MeasuredQuantity::ApparentBytes,
        Some(SizeBytes::new(bytes)),
        EvidenceConfidence::Exact,
    )
}

fn snapshot_id() -> SnapshotId {
    SnapshotId::new(100).expect("snapshot id")
}

fn issue(path: &str) -> ScanIssue {
    ScanIssue::new(
        IssueCode::PermissionDenied,
        IssueSeverity::Warning,
        IssueEvidence::new(Some(path.to_string()), Some("read_dir".to_string()), None),
    )
}

fn publish(roots: Vec<DraftNode>) -> fs_usage_engine::ScanSnapshot {
    SnapshotPublicationGate::publish(snapshot_id(), ScanSnapshotDraft::new(roots), Vec::new())
}

#[test]
fn arena_uses_stable_ids_and_direct_node_lookup() {
    let snapshot = publish(vec![
        DraftNode::new(
            "root",
            NodeKind::Directory,
            size(300),
            ChildCompleteness::Complete,
        )
        .with_children(vec![
            DraftNode::new(
                "alpha",
                NodeKind::File,
                size(100),
                ChildCompleteness::Complete,
            ),
            DraftNode::new(
                "beta",
                NodeKind::File,
                size(200),
                ChildCompleteness::Complete,
            ),
        ]),
    ]);

    assert_eq!(snapshot.node_count(), 3);
    let root_id = snapshot.root_ids()[0];
    let root = snapshot.node(root_id).expect("root");
    assert_eq!(root.name(), "root");

    let first_child = root.child_ids()[0];
    let child = snapshot.node(first_child).expect("child");
    assert_eq!(child.parent_id(), Some(root_id));
    assert_eq!(child.name(), "alpha");
}

#[test]
fn children_query_returns_bounded_projection_not_records() {
    let snapshot = publish(vec![
        DraftNode::new(
            "root",
            NodeKind::Directory,
            size(300),
            ChildCompleteness::Complete,
        )
        .with_children(vec![
            DraftNode::new(
                "small",
                NodeKind::File,
                size(10),
                ChildCompleteness::Complete,
            ),
            DraftNode::new(
                "large",
                NodeKind::File,
                size(200),
                ChildCompleteness::Complete,
            ),
            DraftNode::new(
                "medium",
                NodeKind::File,
                size(90),
                ChildCompleteness::Complete,
            ),
        ]),
    ]);
    let root_id = snapshot.root_ids()[0];

    let page = snapshot
        .children_page(ChildrenPageQuery::new_sorted(
            snapshot.snapshot_id(),
            root_id,
            None,
            2,
            ChildSort::SizeDesc,
        ))
        .expect("children page");

    assert_eq!(page.items.len(), 2);
    assert_eq!(page.items[0].name(), "large");
    assert_eq!(page.items[0].child_count(), 0);
    assert!(page.next_cursor.is_some());
}

#[test]
fn cursor_invalidates_when_query_identity_changes() {
    let snapshot = publish(vec![
        DraftNode::new(
            "root",
            NodeKind::Directory,
            size(300),
            ChildCompleteness::Complete,
        )
        .with_children(vec![
            DraftNode::new("a", NodeKind::File, size(10), ChildCompleteness::Complete),
            DraftNode::new("b", NodeKind::File, size(20), ChildCompleteness::Complete),
        ]),
    ]);
    let root_id = snapshot.root_ids()[0];
    let first_page = snapshot
        .children_page(ChildrenPageQuery::new_sorted(
            snapshot.snapshot_id(),
            root_id,
            None,
            1,
            ChildSort::NameAsc,
        ))
        .expect("first page");

    let err = snapshot
        .children_page(ChildrenPageQuery::new_sorted(
            snapshot.snapshot_id(),
            root_id,
            first_page.next_cursor,
            1,
            ChildSort::SizeDesc,
        ))
        .expect_err("cursor belongs to a different query");

    assert_eq!(err, QueryFailure::CursorQueryMismatch);
}

#[test]
fn search_top_items_and_details_are_paged_read_model_queries() {
    let snapshot = publish(vec![
        DraftNode::new(
            "root",
            NodeKind::Directory,
            size(360),
            ChildCompleteness::Complete,
        )
        .with_children(vec![
            DraftNode::new(
                "alpha-cache",
                NodeKind::File,
                size(100),
                ChildCompleteness::Complete,
            ),
            DraftNode::new(
                "beta-cache",
                NodeKind::File,
                size(200),
                ChildCompleteness::Complete,
            ),
            DraftNode::new(
                "logs",
                NodeKind::Directory,
                size(60),
                ChildCompleteness::Complete,
            )
            .with_issues(vec![issue("/tmp/logs")]),
        ]),
    ]);

    let search = snapshot
        .search_page(SearchQuery::new(snapshot.snapshot_id(), "CACHE", None, 10))
        .expect("search page");
    assert_eq!(search.items.len(), 2);

    let top = snapshot
        .top_items_page(TopItemsQuery::new(
            snapshot.snapshot_id(),
            TopItemsKind::Files,
            None,
            1,
        ))
        .expect("top files");
    assert_eq!(top.items[0].name(), "beta-cache");

    let root_id = snapshot.root_ids()[0];
    let root_page = snapshot
        .children_page(ChildrenPageQuery::new(
            snapshot.snapshot_id(),
            root_id,
            None,
            10,
        ))
        .expect("root children");
    let logs_id = root_page
        .items
        .iter()
        .find(|item| item.name() == "logs")
        .expect("logs row")
        .id();
    let details = snapshot
        .node_details(NodeDetailsQuery::new(snapshot.snapshot_id(), logs_id))
        .expect("details");

    assert_eq!(details.summary().name(), "logs");
    assert_eq!(details.issues().len(), 1);
}

#[test]
fn subtree_issue_count_and_child_completeness_propagate_upward() {
    let snapshot = publish(vec![
        DraftNode::new(
            "root",
            NodeKind::Directory,
            size(100),
            ChildCompleteness::Complete,
        )
        .with_children(vec![
            DraftNode::new(
                "protected",
                NodeKind::Directory,
                size(100),
                ChildCompleteness::IncompleteDueToIssue,
            )
            .with_issues(vec![issue("/tmp/protected")]),
        ]),
    ]);

    let root = snapshot.node(snapshot.root_ids()[0]).expect("root");
    assert_eq!(root.subtree_issue_count(), 1);
    assert_eq!(
        root.child_completeness(),
        ChildCompleteness::IncompleteDueToIssue
    );
}

#[test]
fn synthetic_large_tree_queries_do_not_require_full_tree_export() {
    let child_count = 50_000;
    let children = (0..child_count)
        .map(|index| {
            let name = if index == 42 {
                "needle-file".to_string()
            } else {
                format!("file-{index:05}")
            };
            DraftNode::new(
                name,
                NodeKind::File,
                size(index as u64 + 1),
                ChildCompleteness::Complete,
            )
        })
        .collect::<Vec<_>>();
    let snapshot = publish(vec![
        DraftNode::new(
            "root",
            NodeKind::Directory,
            size(child_count as u64),
            ChildCompleteness::Complete,
        )
        .with_children(children),
    ]);
    let root_id = snapshot.root_ids()[0];

    let page = snapshot
        .children_page(ChildrenPageQuery::new(
            snapshot.snapshot_id(),
            root_id,
            None,
            32,
        ))
        .expect("children page");
    assert_eq!(snapshot.node_count(), child_count + 1);
    assert_eq!(page.items.len(), 32);
    assert_eq!(page.items[0].child_count(), 0);

    let search = snapshot
        .search_page(SearchQuery::new(snapshot.snapshot_id(), "needle", None, 10))
        .expect("search page");
    assert_eq!(search.items.len(), 1);
    assert_eq!(search.items[0].name(), "needle-file");

    let top = snapshot
        .top_items_page(TopItemsQuery::new(
            snapshot.snapshot_id(),
            TopItemsKind::Files,
            None,
            5,
        ))
        .expect("top files");
    assert_eq!(top.items.len(), 5);
    assert_eq!(top.items[0].name(), "file-49999");
}
