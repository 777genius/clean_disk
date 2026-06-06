use fs_usage_core::{
    ChildCompleteness, NodeFlags, NodeId, NodeIdentityEvidence, NodeKind, ScanIssue, ScanSessionId,
    SizeFact, SnapshotId,
};
use std::path::{Path, PathBuf};

#[derive(Debug, Clone)]
pub struct DraftNode {
    name: String,
    source_path: Option<PathBuf>,
    identity_evidence: Option<NodeIdentityEvidence>,
    kind: NodeKind,
    size: SizeFact,
    flags: NodeFlags,
    child_completeness: ChildCompleteness,
    children: Vec<DraftNode>,
    issues: Vec<ScanIssue>,
}

impl DraftNode {
    pub fn new(
        name: impl Into<String>,
        kind: NodeKind,
        size: SizeFact,
        child_completeness: ChildCompleteness,
    ) -> Self {
        Self {
            name: name.into(),
            source_path: None,
            identity_evidence: None,
            kind,
            size,
            flags: NodeFlags::default(),
            child_completeness,
            children: Vec::new(),
            issues: Vec::new(),
        }
    }

    pub fn with_children(mut self, children: Vec<DraftNode>) -> Self {
        self.children = children;
        self
    }

    pub fn with_source_path(mut self, path: impl Into<PathBuf>) -> Self {
        self.source_path = Some(path.into());
        self
    }

    pub fn with_identity_evidence(mut self, identity_evidence: NodeIdentityEvidence) -> Self {
        self.identity_evidence = Some(identity_evidence);
        self
    }

    pub fn with_flags(mut self, flags: NodeFlags) -> Self {
        self.flags = flags;
        self
    }

    pub fn with_issues(mut self, issues: Vec<ScanIssue>) -> Self {
        self.issues = issues;
        self
    }
}

#[derive(Debug, Clone)]
pub struct ScanSnapshotDraft {
    roots: Vec<DraftNode>,
}

impl ScanSnapshotDraft {
    pub fn new(roots: Vec<DraftNode>) -> Self {
        Self { roots }
    }

    pub fn roots(&self) -> &[DraftNode] {
        &self.roots
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NodeRecord {
    id: NodeId,
    parent_id: Option<NodeId>,
    name: String,
    source_path: Option<PathBuf>,
    identity_evidence: Option<NodeIdentityEvidence>,
    kind: NodeKind,
    size: SizeFact,
    flags: NodeFlags,
    child_completeness: ChildCompleteness,
    child_ids: Vec<NodeId>,
    issues: Vec<ScanIssue>,
    subtree_issue_count: usize,
}

impl NodeRecord {
    pub const fn id(&self) -> NodeId {
        self.id
    }

    pub const fn parent_id(&self) -> Option<NodeId> {
        self.parent_id
    }

    pub fn name(&self) -> &str {
        &self.name
    }

    pub fn source_path(&self) -> Option<&Path> {
        self.source_path.as_deref()
    }

    pub fn identity_evidence(&self) -> Option<&NodeIdentityEvidence> {
        self.identity_evidence.as_ref()
    }

    pub const fn kind(&self) -> NodeKind {
        self.kind
    }

    pub const fn size(&self) -> SizeFact {
        self.size
    }

    pub const fn child_completeness(&self) -> ChildCompleteness {
        self.child_completeness
    }

    pub const fn flags(&self) -> NodeFlags {
        self.flags
    }

    pub fn child_ids(&self) -> &[NodeId] {
        &self.child_ids
    }

    pub fn issues(&self) -> &[ScanIssue] {
        &self.issues
    }

    pub const fn subtree_issue_count(&self) -> usize {
        self.subtree_issue_count
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NodePageItem {
    id: NodeId,
    parent_id: Option<NodeId>,
    name: String,
    kind: NodeKind,
    size: SizeFact,
    flags: NodeFlags,
    child_completeness: ChildCompleteness,
    child_count: usize,
    issue_count: usize,
    subtree_issue_count: usize,
}

impl NodePageItem {
    pub const fn id(&self) -> NodeId {
        self.id
    }

    pub const fn parent_id(&self) -> Option<NodeId> {
        self.parent_id
    }

    pub fn name(&self) -> &str {
        &self.name
    }

    pub const fn kind(&self) -> NodeKind {
        self.kind
    }

    pub const fn size(&self) -> SizeFact {
        self.size
    }

    pub const fn flags(&self) -> NodeFlags {
        self.flags
    }

    pub const fn child_completeness(&self) -> ChildCompleteness {
        self.child_completeness
    }

    pub const fn child_count(&self) -> usize {
        self.child_count
    }

    pub const fn issue_count(&self) -> usize {
        self.issue_count
    }

    pub const fn subtree_issue_count(&self) -> usize {
        self.subtree_issue_count
    }
}

impl From<&NodeRecord> for NodePageItem {
    fn from(record: &NodeRecord) -> Self {
        Self {
            id: record.id,
            parent_id: record.parent_id,
            name: record.name.clone(),
            kind: record.kind,
            size: record.size,
            flags: record.flags,
            child_completeness: record.child_completeness,
            child_count: record.child_ids.len(),
            issue_count: record.issues.len(),
            subtree_issue_count: record.subtree_issue_count,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NodeDetails {
    summary: NodePageItem,
    source_path: Option<PathBuf>,
    child_ids: Vec<NodeId>,
    issues: Vec<ScanIssue>,
}

impl NodeDetails {
    pub fn summary(&self) -> &NodePageItem {
        &self.summary
    }

    pub fn source_path(&self) -> Option<&Path> {
        self.source_path.as_deref()
    }

    pub fn child_ids(&self) -> &[NodeId] {
        &self.child_ids
    }

    pub fn issues(&self) -> &[ScanIssue] {
        &self.issues
    }
}

#[derive(Debug, Clone)]
pub struct NodeArena {
    nodes: Vec<NodeRecord>,
    root_ids: Vec<NodeId>,
}

impl NodeArena {
    pub fn len(&self) -> usize {
        self.nodes.len()
    }

    pub fn is_empty(&self) -> bool {
        self.nodes.is_empty()
    }

    pub fn root_ids(&self) -> &[NodeId] {
        &self.root_ids
    }

    pub fn node(&self, node_id: NodeId) -> Option<&NodeRecord> {
        let index = usize::try_from(node_id.get().checked_sub(1)?).ok()?;
        self.nodes.get(index).filter(|node| node.id == node_id)
    }
}

#[derive(Debug, Clone)]
pub struct ScanSnapshot {
    snapshot_id: SnapshotId,
    arena: NodeArena,
    issues: Vec<ScanIssue>,
}

impl ScanSnapshot {
    pub const fn snapshot_id(&self) -> SnapshotId {
        self.snapshot_id
    }

    pub fn node_count(&self) -> usize {
        self.arena.len()
    }

    pub fn root_ids(&self) -> &[NodeId] {
        self.arena.root_ids()
    }

    pub fn issues(&self) -> &[ScanIssue] {
        &self.issues
    }

    pub fn node(&self, node_id: NodeId) -> Option<&NodeRecord> {
        self.arena.node(node_id)
    }

    pub fn node_details(&self, query: NodeDetailsQuery) -> Result<NodeDetails, QueryFailure> {
        self.ensure_snapshot(query.snapshot_id)?;
        let record = self
            .node(query.node_id)
            .ok_or(QueryFailure::UnknownNode(query.node_id))?;

        Ok(NodeDetails {
            summary: NodePageItem::from(record),
            source_path: record.source_path.clone(),
            child_ids: record.child_ids.clone(),
            issues: record.issues.clone(),
        })
    }

    pub fn children_page(
        &self,
        query: ChildrenPageQuery,
    ) -> Result<Page<NodePageItem>, QueryFailure> {
        self.ensure_snapshot(query.snapshot_id)?;
        query.ensure_valid_limit()?;

        let parent = self
            .node(query.parent_id)
            .ok_or(QueryFailure::UnknownNode(query.parent_id))?;
        let query_key = QueryFingerprint::children(query.parent_id, query.sort);
        let offset = query.offset_for(self.snapshot_id, query_key)?;
        let mut child_ids = parent.child_ids.clone();
        self.sort_node_ids(&mut child_ids, query.sort);
        self.page_node_ids(child_ids, offset, query.limit, query_key)
    }

    pub fn search_page(&self, query: SearchQuery) -> Result<Page<NodePageItem>, QueryFailure> {
        self.ensure_snapshot(query.snapshot_id)?;
        query.ensure_valid_limit()?;
        if query.text.trim().is_empty() {
            return Err(QueryFailure::InvalidSearchText);
        }

        let normalized = query.text.to_lowercase();
        let query_key = QueryFingerprint::search(&normalized);
        let offset = query.offset_for(self.snapshot_id, query_key)?;
        let matching_ids = self
            .arena
            .nodes
            .iter()
            .filter(|node| node.name.to_lowercase().contains(&normalized))
            .map(|node| node.id)
            .collect::<Vec<_>>();

        self.page_node_ids(matching_ids, offset, query.limit, query_key)
    }

    pub fn top_items_page(&self, query: TopItemsQuery) -> Result<Page<NodePageItem>, QueryFailure> {
        self.ensure_snapshot(query.snapshot_id)?;
        query.ensure_valid_limit()?;

        let query_key = QueryFingerprint::top_items(query.kind);
        let offset = query.offset_for(self.snapshot_id, query_key)?;
        let mut ids = self
            .arena
            .nodes
            .iter()
            .filter(|node| query.kind.matches(node.kind))
            .map(|node| node.id)
            .collect::<Vec<_>>();
        self.sort_node_ids(&mut ids, ChildSort::SizeDesc);

        self.page_node_ids(ids, offset, query.limit, query_key)
    }

    fn ensure_snapshot(&self, snapshot_id: SnapshotId) -> Result<(), QueryFailure> {
        if snapshot_id != self.snapshot_id {
            return Err(QueryFailure::SnapshotMismatch);
        }
        Ok(())
    }

    fn sort_node_ids(&self, ids: &mut [NodeId], sort: ChildSort) {
        ids.sort_by(|left, right| {
            let left = self.node(*left).expect("id came from arena");
            let right = self.node(*right).expect("id came from arena");
            match sort {
                ChildSort::Insertion => left.id.cmp(&right.id),
                ChildSort::NameAsc => left
                    .name
                    .to_lowercase()
                    .cmp(&right.name.to_lowercase())
                    .then_with(|| left.id.cmp(&right.id)),
                ChildSort::NameDesc => right
                    .name
                    .to_lowercase()
                    .cmp(&left.name.to_lowercase())
                    .then_with(|| left.id.cmp(&right.id)),
                ChildSort::SizeAsc => left
                    .size
                    .raw_value()
                    .cmp(&right.size.raw_value())
                    .then_with(|| left.id.cmp(&right.id)),
                ChildSort::SizeDesc => right
                    .size
                    .raw_value()
                    .cmp(&left.size.raw_value())
                    .then_with(|| left.id.cmp(&right.id)),
            }
        });
    }

    fn page_node_ids(
        &self,
        ids: Vec<NodeId>,
        offset: usize,
        limit: usize,
        query_fingerprint: QueryFingerprint,
    ) -> Result<Page<NodePageItem>, QueryFailure> {
        if offset >= ids.len() {
            return Ok(Page {
                items: Vec::new(),
                next_cursor: None,
            });
        }

        let end = offset.saturating_add(limit).min(ids.len());
        let items = ids[offset..end]
            .iter()
            .filter_map(|id| self.node(*id).map(NodePageItem::from))
            .collect::<Vec<_>>();
        let next_cursor = (end < ids.len()).then_some(PageCursor {
            snapshot_id: self.snapshot_id,
            query_fingerprint,
            offset: end,
        });

        Ok(Page { items, next_cursor })
    }
}

pub struct SnapshotPublicationGate;

impl SnapshotPublicationGate {
    pub fn publish_for_session(
        session_id: ScanSessionId,
        draft: ScanSnapshotDraft,
        issues: Vec<ScanIssue>,
    ) -> ScanSnapshot {
        let snapshot_id = SnapshotId::new(session_id.get()).expect("session id is non-zero");
        Self::publish(snapshot_id, draft, issues)
    }

    pub fn publish(
        snapshot_id: SnapshotId,
        draft: ScanSnapshotDraft,
        issues: Vec<ScanIssue>,
    ) -> ScanSnapshot {
        let mut nodes = Vec::new();
        let mut root_ids = Vec::new();

        for root in draft.roots {
            let root_id = flatten_node(root, None, &mut nodes).0;
            root_ids.push(root_id);
        }

        ScanSnapshot {
            snapshot_id,
            arena: NodeArena { nodes, root_ids },
            issues,
        }
    }
}

fn flatten_node(
    draft: DraftNode,
    parent_id: Option<NodeId>,
    nodes: &mut Vec<NodeRecord>,
) -> (NodeId, usize, ChildCompleteness) {
    let id = NodeId::new(nodes.len() as u64 + 1).expect("node id starts at one");
    let node_index = nodes.len();
    nodes.push(NodeRecord {
        id,
        parent_id,
        name: draft.name,
        source_path: draft.source_path,
        identity_evidence: draft.identity_evidence,
        kind: draft.kind,
        size: draft.size,
        flags: draft.flags,
        child_completeness: draft.child_completeness,
        child_ids: Vec::new(),
        subtree_issue_count: draft.issues.len(),
        issues: draft.issues,
    });

    let mut child_ids = Vec::new();
    let mut child_issue_count = 0;
    let mut propagated_child_completeness = ChildCompleteness::Complete;

    for child in draft.children {
        let (child_id, subtree_issues, child_completeness) = flatten_node(child, Some(id), nodes);
        child_ids.push(child_id);
        child_issue_count += subtree_issues;
        propagated_child_completeness =
            merge_child_completeness(propagated_child_completeness, child_completeness);
    }

    let node = &mut nodes[node_index];
    node.child_ids = child_ids;
    node.subtree_issue_count += child_issue_count;
    if node.child_completeness == ChildCompleteness::Complete {
        node.child_completeness = propagated_child_completeness;
    }

    (id, node.subtree_issue_count, node.child_completeness)
}

fn merge_child_completeness(
    current: ChildCompleteness,
    child: ChildCompleteness,
) -> ChildCompleteness {
    match (current_rank(current), current_rank(child)) {
        (left, right) if left >= right => current,
        _ => child,
    }
}

fn current_rank(completeness: ChildCompleteness) -> u8 {
    match completeness {
        ChildCompleteness::Complete => 0,
        ChildCompleteness::Unknown => 0,
        ChildCompleteness::CollapsedByProjection => 1,
        ChildCompleteness::CollapsedByDepth => 2,
        ChildCompleteness::SkippedByBoundary => 3,
        ChildCompleteness::IncompleteDueToIssue => 4,
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
struct QueryFingerprint(u64);

impl QueryFingerprint {
    fn children(parent_id: NodeId, sort: ChildSort) -> Self {
        Self(hash_parts(&[1, parent_id.get(), sort as u64]))
    }

    fn search(text: &str) -> Self {
        Self(hash_text(2, text))
    }

    fn top_items(kind: TopItemsKind) -> Self {
        Self(hash_parts(&[3, kind as u64]))
    }
}

fn hash_parts(parts: &[u64]) -> u64 {
    let mut hash = 0xcbf29ce484222325;
    for part in parts {
        hash ^= *part;
        hash = hash.wrapping_mul(0x100000001b3);
    }
    hash
}

fn hash_text(seed: u64, text: &str) -> u64 {
    let mut hash = hash_parts(&[seed]);
    for byte in text.as_bytes() {
        hash ^= u64::from(*byte);
        hash = hash.wrapping_mul(0x100000001b3);
    }
    hash
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PageCursor {
    snapshot_id: SnapshotId,
    query_fingerprint: QueryFingerprint,
    offset: usize,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ChildSort {
    Insertion,
    NameAsc,
    NameDesc,
    SizeAsc,
    SizeDesc,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ChildrenPageQuery {
    snapshot_id: SnapshotId,
    parent_id: NodeId,
    cursor: Option<PageCursor>,
    limit: usize,
    sort: ChildSort,
}

impl ChildrenPageQuery {
    pub const fn new(
        snapshot_id: SnapshotId,
        parent_id: NodeId,
        cursor: Option<PageCursor>,
        limit: usize,
    ) -> Self {
        Self {
            snapshot_id,
            parent_id,
            cursor,
            limit,
            sort: ChildSort::Insertion,
        }
    }

    pub const fn new_sorted(
        snapshot_id: SnapshotId,
        parent_id: NodeId,
        cursor: Option<PageCursor>,
        limit: usize,
        sort: ChildSort,
    ) -> Self {
        Self {
            snapshot_id,
            parent_id,
            cursor,
            limit,
            sort,
        }
    }

    fn ensure_valid_limit(self) -> Result<(), QueryFailure> {
        if self.limit == 0 {
            return Err(QueryFailure::InvalidLimit);
        }
        Ok(())
    }

    fn offset_for(
        self,
        snapshot_id: SnapshotId,
        query_fingerprint: QueryFingerprint,
    ) -> Result<usize, QueryFailure> {
        cursor_offset(self.cursor, snapshot_id, query_fingerprint)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SearchQuery {
    snapshot_id: SnapshotId,
    text: String,
    cursor: Option<PageCursor>,
    limit: usize,
}

impl SearchQuery {
    pub fn new(
        snapshot_id: SnapshotId,
        text: impl Into<String>,
        cursor: Option<PageCursor>,
        limit: usize,
    ) -> Self {
        Self {
            snapshot_id,
            text: text.into(),
            cursor,
            limit,
        }
    }

    fn ensure_valid_limit(&self) -> Result<(), QueryFailure> {
        if self.limit == 0 {
            return Err(QueryFailure::InvalidLimit);
        }
        Ok(())
    }

    fn offset_for(
        &self,
        snapshot_id: SnapshotId,
        query_fingerprint: QueryFingerprint,
    ) -> Result<usize, QueryFailure> {
        cursor_offset(self.cursor, snapshot_id, query_fingerprint)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum TopItemsKind {
    Files,
    Directories,
    FilesAndDirectories,
}

impl TopItemsKind {
    fn matches(self, node_kind: NodeKind) -> bool {
        match self {
            Self::Files => node_kind == NodeKind::File,
            Self::Directories => node_kind == NodeKind::Directory,
            Self::FilesAndDirectories => {
                matches!(node_kind, NodeKind::File | NodeKind::Directory)
            }
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct TopItemsQuery {
    snapshot_id: SnapshotId,
    kind: TopItemsKind,
    cursor: Option<PageCursor>,
    limit: usize,
}

impl TopItemsQuery {
    pub const fn new(
        snapshot_id: SnapshotId,
        kind: TopItemsKind,
        cursor: Option<PageCursor>,
        limit: usize,
    ) -> Self {
        Self {
            snapshot_id,
            kind,
            cursor,
            limit,
        }
    }

    fn ensure_valid_limit(self) -> Result<(), QueryFailure> {
        if self.limit == 0 {
            return Err(QueryFailure::InvalidLimit);
        }
        Ok(())
    }

    fn offset_for(
        self,
        snapshot_id: SnapshotId,
        query_fingerprint: QueryFingerprint,
    ) -> Result<usize, QueryFailure> {
        cursor_offset(self.cursor, snapshot_id, query_fingerprint)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct NodeDetailsQuery {
    snapshot_id: SnapshotId,
    node_id: NodeId,
}

impl NodeDetailsQuery {
    pub const fn new(snapshot_id: SnapshotId, node_id: NodeId) -> Self {
        Self {
            snapshot_id,
            node_id,
        }
    }
}

fn cursor_offset(
    cursor: Option<PageCursor>,
    snapshot_id: SnapshotId,
    query_fingerprint: QueryFingerprint,
) -> Result<usize, QueryFailure> {
    match cursor {
        Some(cursor) if cursor.snapshot_id != snapshot_id => {
            Err(QueryFailure::CursorSnapshotMismatch)
        }
        Some(cursor) if cursor.query_fingerprint != query_fingerprint => {
            Err(QueryFailure::CursorQueryMismatch)
        }
        Some(cursor) => Ok(cursor.offset),
        None => Ok(0),
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Page<T> {
    pub items: Vec<T>,
    pub next_cursor: Option<PageCursor>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum QueryFailure {
    SnapshotMismatch,
    CursorSnapshotMismatch,
    CursorQueryMismatch,
    InvalidLimit,
    InvalidSearchText,
    UnknownNode(NodeId),
}
