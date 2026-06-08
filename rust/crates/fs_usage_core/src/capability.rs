#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum SupportLevel {
    Supported,
    Unsupported,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct CapabilitySet {
    hardlinks: SupportLevel,
    filesystem_boundary: SupportLevel,
    cooperative_cancellation: SupportLevel,
    metadata_enrichment: SupportLevel,
    growing_tree_streaming: SupportLevel,
}

impl CapabilitySet {
    pub const fn new(
        hardlinks: SupportLevel,
        filesystem_boundary: SupportLevel,
        cooperative_cancellation: SupportLevel,
        metadata_enrichment: SupportLevel,
        growing_tree_streaming: SupportLevel,
    ) -> Self {
        Self {
            hardlinks,
            filesystem_boundary,
            cooperative_cancellation,
            metadata_enrichment,
            growing_tree_streaming,
        }
    }

    pub const fn unknown() -> Self {
        Self::new(
            SupportLevel::Unknown,
            SupportLevel::Unknown,
            SupportLevel::Unknown,
            SupportLevel::Unknown,
            SupportLevel::Unknown,
        )
    }

    pub const fn hardlinks(self) -> SupportLevel {
        self.hardlinks
    }

    pub const fn filesystem_boundary(self) -> SupportLevel {
        self.filesystem_boundary
    }

    pub const fn cooperative_cancellation(self) -> SupportLevel {
        self.cooperative_cancellation
    }

    pub const fn metadata_enrichment(self) -> SupportLevel {
        self.metadata_enrichment
    }

    pub const fn growing_tree_streaming(self) -> SupportLevel {
        self.growing_tree_streaming
    }
}
