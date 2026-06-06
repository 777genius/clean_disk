#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct TargetPath(String);

impl TargetPath {
    pub fn new(path: impl Into<String>) -> Result<Self, TargetPathError> {
        let path = path.into();
        if path.trim().is_empty() {
            return Err(TargetPathError::Empty);
        }
        Ok(Self(path))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TargetPathError {
    Empty,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum TargetScope {
    LocalPath,
    Volume,
    Custom,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum BoundaryPolicy {
    CrossFilesystems,
    StayOnInitialFilesystem,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum HardlinkPolicy {
    Ignore,
    Detect,
    DeduplicateForDisplay,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct ScanTarget {
    path: TargetPath,
    scope: TargetScope,
    boundary_policy: BoundaryPolicy,
    hardlink_policy: HardlinkPolicy,
}

impl ScanTarget {
    pub const fn new(
        path: TargetPath,
        scope: TargetScope,
        boundary_policy: BoundaryPolicy,
        hardlink_policy: HardlinkPolicy,
    ) -> Self {
        Self {
            path,
            scope,
            boundary_policy,
            hardlink_policy,
        }
    }

    pub const fn path(&self) -> &TargetPath {
        &self.path
    }

    pub const fn scope(&self) -> TargetScope {
        self.scope
    }

    pub const fn boundary_policy(&self) -> BoundaryPolicy {
        self.boundary_policy
    }

    pub const fn hardlink_policy(&self) -> HardlinkPolicy {
        self.hardlink_policy
    }
}
