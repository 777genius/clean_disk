#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum NodeKind {
    File,
    Directory,
    Symlink,
    Other,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default)]
pub struct NodeFlags {
    pub hidden: bool,
    pub system: bool,
    pub package: bool,
    pub symlink: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct NodeIdentityEvidence {
    platform_file_id: Option<String>,
    size_bytes: Option<u64>,
    modified_unix_nanos: Option<u128>,
    created_unix_nanos: Option<u128>,
}

impl NodeIdentityEvidence {
    pub fn new(
        platform_file_id: Option<String>,
        size_bytes: Option<u64>,
        modified_unix_nanos: Option<u128>,
        created_unix_nanos: Option<u128>,
    ) -> Self {
        Self {
            platform_file_id,
            size_bytes,
            modified_unix_nanos,
            created_unix_nanos,
        }
    }

    pub fn platform_file_id(&self) -> Option<&str> {
        self.platform_file_id.as_deref()
    }

    pub const fn size_bytes(&self) -> Option<u64> {
        self.size_bytes
    }

    pub const fn modified_unix_nanos(&self) -> Option<u128> {
        self.modified_unix_nanos
    }

    pub const fn created_unix_nanos(&self) -> Option<u128> {
        self.created_unix_nanos
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ChildCompleteness {
    Complete,
    CollapsedByDepth,
    CollapsedByProjection,
    SkippedByBoundary,
    IncompleteDueToIssue,
    Unknown,
}
