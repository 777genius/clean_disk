use fs_usage_core::{
    ChildCompleteness, NodeKind, PartialNodeId, ScanIssue, ScanSessionId, SizeFact,
};

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct PartialNodeName(String);

impl PartialNodeName {
    pub fn new(value: impl Into<String>) -> Result<Self, PartialNodeNameError> {
        let value = value.into();
        if value.trim().is_empty() {
            return Err(PartialNodeNameError::Empty);
        }
        Ok(Self(value))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum PartialNodeNameError {
    Empty,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum GrowingNodeState {
    Discovered,
    Scanning,
    Complete,
    Skipped,
    Stale,
}

impl GrowingNodeState {
    pub const fn is_cleanup_authority(self) -> bool {
        false
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum GrowingTreeEvent {
    NodeDiscovered {
        session_id: ScanSessionId,
        node_id: PartialNodeId,
        parent_id: Option<PartialNodeId>,
        name: PartialNodeName,
        kind: NodeKind,
    },
    NodeSizeUpdated {
        session_id: ScanSessionId,
        node_id: PartialNodeId,
        aggregate_size: SizeFact,
        state: GrowingNodeState,
    },
    NodeCompleted {
        session_id: ScanSessionId,
        node_id: PartialNodeId,
        aggregate_size: SizeFact,
        child_completeness: ChildCompleteness,
    },
    NodeIssueRecorded {
        session_id: ScanSessionId,
        node_id: Option<PartialNodeId>,
        issue: ScanIssue,
    },
}

impl GrowingTreeEvent {
    pub const fn session_id(&self) -> ScanSessionId {
        match self {
            Self::NodeDiscovered { session_id, .. }
            | Self::NodeSizeUpdated { session_id, .. }
            | Self::NodeCompleted { session_id, .. }
            | Self::NodeIssueRecorded { session_id, .. } => *session_id,
        }
    }

    pub const fn node_id(&self) -> Option<PartialNodeId> {
        match self {
            Self::NodeDiscovered { node_id, .. }
            | Self::NodeSizeUpdated { node_id, .. }
            | Self::NodeCompleted { node_id, .. } => Some(*node_id),
            Self::NodeIssueRecorded { node_id, .. } => *node_id,
        }
    }

    pub const fn is_cleanup_authority(&self) -> bool {
        false
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GrowingTreeBatch {
    session_id: ScanSessionId,
    scanned_items: u64,
    events: Vec<GrowingTreeEvent>,
}

impl GrowingTreeBatch {
    pub fn new(
        session_id: ScanSessionId,
        scanned_items: u64,
        events: Vec<GrowingTreeEvent>,
    ) -> Result<Self, GrowingTreeBatchError> {
        if events.is_empty() {
            return Err(GrowingTreeBatchError::Empty);
        }
        if events.iter().any(|event| event.session_id() != session_id) {
            return Err(GrowingTreeBatchError::SessionMismatch);
        }
        Ok(Self {
            session_id,
            scanned_items,
            events,
        })
    }

    pub const fn session_id(&self) -> ScanSessionId {
        self.session_id
    }

    pub const fn scanned_items(&self) -> u64 {
        self.scanned_items
    }

    pub fn events(&self) -> &[GrowingTreeEvent] {
        &self.events
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum GrowingTreeBatchError {
    Empty,
    SessionMismatch,
}
