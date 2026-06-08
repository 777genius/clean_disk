use std::num::{NonZeroU64, NonZeroU128};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct ScanSessionId(NonZeroU128);

impl ScanSessionId {
    pub fn new(value: u128) -> Option<Self> {
        NonZeroU128::new(value).map(Self)
    }

    pub const fn get(self) -> u128 {
        self.0.get()
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct SnapshotId(NonZeroU128);

impl SnapshotId {
    pub fn new(value: u128) -> Option<Self> {
        NonZeroU128::new(value).map(Self)
    }

    pub const fn get(self) -> u128 {
        self.0.get()
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct OperationId(NonZeroU128);

impl OperationId {
    pub fn new(value: u128) -> Option<Self> {
        NonZeroU128::new(value).map(Self)
    }

    pub const fn get(self) -> u128 {
        self.0.get()
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct NodeId(NonZeroU64);

impl NodeId {
    pub fn new(value: u64) -> Option<Self> {
        NonZeroU64::new(value).map(Self)
    }

    pub const fn get(self) -> u64 {
        self.0.get()
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct PartialNodeId(NonZeroU64);

impl PartialNodeId {
    pub fn new(value: u64) -> Option<Self> {
        NonZeroU64::new(value).map(Self)
    }

    pub const fn get(self) -> u64 {
        self.0.get()
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct NodeRef {
    snapshot_id: SnapshotId,
    node_id: NodeId,
}

impl NodeRef {
    pub const fn new(snapshot_id: SnapshotId, node_id: NodeId) -> Self {
        Self {
            snapshot_id,
            node_id,
        }
    }

    pub const fn snapshot_id(self) -> SnapshotId {
        self.snapshot_id
    }

    pub const fn node_id(self) -> NodeId {
        self.node_id
    }
}
