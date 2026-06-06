use crate::{
    DecimalU64Dto, DecimalU128Dto, DecimalUsizeDto, OpaqueCursorDto, ScanIssueDto, SearchTextDto,
};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum NodeKindDto {
    File,
    Directory,
    Symlink,
    Other,
    Unknown,
    #[serde(other)]
    Unrecognized,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum ChildCompletenessDto {
    Complete,
    CollapsedByDepth,
    CollapsedByProjection,
    SkippedByBoundary,
    IncompleteDueToIssue,
    Unknown,
    #[serde(other)]
    Unrecognized,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum ChildSortDto {
    Insertion,
    NameAsc,
    NameDesc,
    SizeAsc,
    SizeDesc,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum TopItemsKindDto {
    Files,
    Directories,
    FilesAndDirectories,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct NodeFlagsDto {
    hidden: bool,
    system: bool,
    package: bool,
    symlink: bool,
}

impl NodeFlagsDto {
    pub const fn new(hidden: bool, system: bool, package: bool, symlink: bool) -> Self {
        Self {
            hidden,
            system,
            package,
            symlink,
        }
    }

    pub const fn hidden(&self) -> bool {
        self.hidden
    }

    pub const fn system(&self) -> bool {
        self.system
    }

    pub const fn package(&self) -> bool {
        self.package
    }

    pub const fn symlink(&self) -> bool {
        self.symlink
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum SizeConfidenceDto {
    Exact,
    High,
    Medium,
    Low,
    Unknown,
    #[serde(other)]
    Unrecognized,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum MeasuredQuantityResponseDto {
    ApparentBytes,
    AllocatedBytes,
    BlockCount,
    Unknown,
    #[serde(other)]
    Unrecognized,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct SizeFactDto {
    raw_value: DecimalU64Dto,
    quantity: MeasuredQuantityResponseDto,
    byte_equivalent: Option<DecimalU64Dto>,
    confidence: SizeConfidenceDto,
}

impl SizeFactDto {
    pub fn new(
        raw_value: DecimalU64Dto,
        quantity: MeasuredQuantityResponseDto,
        byte_equivalent: Option<DecimalU64Dto>,
        confidence: SizeConfidenceDto,
    ) -> Self {
        Self {
            raw_value,
            quantity,
            byte_equivalent,
            confidence,
        }
    }

    pub fn raw_value(&self) -> &DecimalU64Dto {
        &self.raw_value
    }

    pub const fn quantity(&self) -> &MeasuredQuantityResponseDto {
        &self.quantity
    }

    pub const fn byte_equivalent(&self) -> Option<&DecimalU64Dto> {
        self.byte_equivalent.as_ref()
    }

    pub const fn confidence(&self) -> &SizeConfidenceDto {
        &self.confidence
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct NodePageItemDto {
    node_id: DecimalU64Dto,
    parent_id: Option<DecimalU64Dto>,
    name: String,
    kind: NodeKindDto,
    size: SizeFactDto,
    flags: NodeFlagsDto,
    child_completeness: ChildCompletenessDto,
    child_count: DecimalUsizeDto,
    issue_count: DecimalUsizeDto,
    subtree_issue_count: DecimalUsizeDto,
}

impl NodePageItemDto {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        node_id: DecimalU64Dto,
        parent_id: Option<DecimalU64Dto>,
        name: impl Into<String>,
        kind: NodeKindDto,
        size: SizeFactDto,
        flags: NodeFlagsDto,
        child_completeness: ChildCompletenessDto,
        child_count: DecimalUsizeDto,
        issue_count: DecimalUsizeDto,
        subtree_issue_count: DecimalUsizeDto,
    ) -> Self {
        Self {
            node_id,
            parent_id,
            name: name.into(),
            kind,
            size,
            flags,
            child_completeness,
            child_count,
            issue_count,
            subtree_issue_count,
        }
    }

    pub fn node_id(&self) -> &DecimalU64Dto {
        &self.node_id
    }

    pub const fn parent_id(&self) -> Option<&DecimalU64Dto> {
        self.parent_id.as_ref()
    }

    pub fn name(&self) -> &str {
        &self.name
    }

    pub const fn kind(&self) -> NodeKindDto {
        self.kind
    }

    pub const fn size(&self) -> &SizeFactDto {
        &self.size
    }

    pub const fn flags(&self) -> &NodeFlagsDto {
        &self.flags
    }

    pub const fn child_completeness(&self) -> ChildCompletenessDto {
        self.child_completeness
    }

    pub fn child_count(&self) -> &DecimalUsizeDto {
        &self.child_count
    }

    pub fn issue_count(&self) -> &DecimalUsizeDto {
        &self.issue_count
    }

    pub fn subtree_issue_count(&self) -> &DecimalUsizeDto {
        &self.subtree_issue_count
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct NodePageResponseDto {
    snapshot_id: DecimalU128Dto,
    items: Vec<NodePageItemDto>,
    next_cursor: Option<OpaqueCursorDto>,
}

impl NodePageResponseDto {
    pub fn new(
        snapshot_id: DecimalU128Dto,
        items: Vec<NodePageItemDto>,
        next_cursor: Option<OpaqueCursorDto>,
    ) -> Self {
        Self {
            snapshot_id,
            items,
            next_cursor,
        }
    }

    pub fn snapshot_id(&self) -> &DecimalU128Dto {
        &self.snapshot_id
    }

    pub fn items(&self) -> &[NodePageItemDto] {
        &self.items
    }

    pub const fn next_cursor(&self) -> Option<&OpaqueCursorDto> {
        self.next_cursor.as_ref()
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct NodeDetailsResponseDto {
    snapshot_id: DecimalU128Dto,
    summary: NodePageItemDto,
    #[serde(default)]
    timestamps: Option<NodeTimestampsDto>,
    child_ids: Vec<DecimalU64Dto>,
    issues: Vec<ScanIssueDto>,
}

impl NodeDetailsResponseDto {
    pub fn new(
        snapshot_id: DecimalU128Dto,
        summary: NodePageItemDto,
        timestamps: Option<NodeTimestampsDto>,
        child_ids: Vec<DecimalU64Dto>,
        issues: Vec<ScanIssueDto>,
    ) -> Self {
        Self {
            snapshot_id,
            summary,
            timestamps,
            child_ids,
            issues,
        }
    }

    pub fn snapshot_id(&self) -> &DecimalU128Dto {
        &self.snapshot_id
    }

    pub const fn summary(&self) -> &NodePageItemDto {
        &self.summary
    }

    pub const fn timestamps(&self) -> Option<&NodeTimestampsDto> {
        self.timestamps.as_ref()
    }

    pub fn child_ids(&self) -> &[DecimalU64Dto] {
        &self.child_ids
    }

    pub fn issues(&self) -> &[ScanIssueDto] {
        &self.issues
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct NodeTimestampsDto {
    created_at_unix_ms: Option<DecimalU128Dto>,
    modified_at_unix_ms: Option<DecimalU128Dto>,
}

impl NodeTimestampsDto {
    pub const fn new(
        created_at_unix_ms: Option<DecimalU128Dto>,
        modified_at_unix_ms: Option<DecimalU128Dto>,
    ) -> Self {
        Self {
            created_at_unix_ms,
            modified_at_unix_ms,
        }
    }

    pub const fn created_at_unix_ms(&self) -> Option<&DecimalU128Dto> {
        self.created_at_unix_ms.as_ref()
    }

    pub const fn modified_at_unix_ms(&self) -> Option<&DecimalU128Dto> {
        self.modified_at_unix_ms.as_ref()
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ChildrenPageRequestDto {
    snapshot_id: DecimalU128Dto,
    parent_id: DecimalU64Dto,
    cursor: Option<OpaqueCursorDto>,
    limit: DecimalUsizeDto,
    sort: ChildSortDto,
}

impl ChildrenPageRequestDto {
    pub fn new(
        snapshot_id: DecimalU128Dto,
        parent_id: DecimalU64Dto,
        cursor: Option<OpaqueCursorDto>,
        limit: DecimalUsizeDto,
        sort: ChildSortDto,
    ) -> Self {
        Self {
            snapshot_id,
            parent_id,
            cursor,
            limit,
            sort,
        }
    }

    pub fn snapshot_id(&self) -> &DecimalU128Dto {
        &self.snapshot_id
    }

    pub fn parent_id(&self) -> &DecimalU64Dto {
        &self.parent_id
    }

    pub const fn cursor(&self) -> Option<&OpaqueCursorDto> {
        self.cursor.as_ref()
    }

    pub fn limit(&self) -> &DecimalUsizeDto {
        &self.limit
    }

    pub const fn sort(&self) -> ChildSortDto {
        self.sort
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct SearchPageRequestDto {
    snapshot_id: DecimalU128Dto,
    search_text: SearchTextDto,
    cursor: Option<OpaqueCursorDto>,
    limit: DecimalUsizeDto,
}

impl SearchPageRequestDto {
    pub fn new(
        snapshot_id: DecimalU128Dto,
        search_text: SearchTextDto,
        cursor: Option<OpaqueCursorDto>,
        limit: DecimalUsizeDto,
    ) -> Self {
        Self {
            snapshot_id,
            search_text,
            cursor,
            limit,
        }
    }

    pub fn snapshot_id(&self) -> &DecimalU128Dto {
        &self.snapshot_id
    }

    pub fn search_text(&self) -> &SearchTextDto {
        &self.search_text
    }

    pub const fn cursor(&self) -> Option<&OpaqueCursorDto> {
        self.cursor.as_ref()
    }

    pub fn limit(&self) -> &DecimalUsizeDto {
        &self.limit
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct TopItemsRequestDto {
    snapshot_id: DecimalU128Dto,
    kind: TopItemsKindDto,
    cursor: Option<OpaqueCursorDto>,
    limit: DecimalUsizeDto,
}

impl TopItemsRequestDto {
    pub fn new(
        snapshot_id: DecimalU128Dto,
        kind: TopItemsKindDto,
        cursor: Option<OpaqueCursorDto>,
        limit: DecimalUsizeDto,
    ) -> Self {
        Self {
            snapshot_id,
            kind,
            cursor,
            limit,
        }
    }

    pub fn snapshot_id(&self) -> &DecimalU128Dto {
        &self.snapshot_id
    }

    pub const fn kind(&self) -> TopItemsKindDto {
        self.kind
    }

    pub const fn cursor(&self) -> Option<&OpaqueCursorDto> {
        self.cursor.as_ref()
    }

    pub fn limit(&self) -> &DecimalUsizeDto {
        &self.limit
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct NodeDetailsRequestDto {
    snapshot_id: DecimalU128Dto,
    node_id: DecimalU64Dto,
}

impl NodeDetailsRequestDto {
    pub fn new(snapshot_id: DecimalU128Dto, node_id: DecimalU64Dto) -> Self {
        Self {
            snapshot_id,
            node_id,
        }
    }

    pub fn snapshot_id(&self) -> &DecimalU128Dto {
        &self.snapshot_id
    }

    pub fn node_id(&self) -> &DecimalU64Dto {
        &self.node_id
    }
}
