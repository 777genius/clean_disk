#![forbid(unsafe_code)]

use fs_usage_core::{CapabilitySet, NodeIdentityEvidence};
use std::{
    fmt, fs, io,
    path::Path,
    time::{SystemTime, UNIX_EPOCH},
};

#[cfg(unix)]
use std::os::unix::fs::MetadataExt;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PlatformAdapterBoundary {
    capabilities: CapabilitySet,
}

impl PlatformAdapterBoundary {
    pub const fn new(capabilities: CapabilitySet) -> Self {
        Self { capabilities }
    }

    pub const fn capabilities(self) -> CapabilitySet {
        self.capabilities
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RestoreExpectationLevel {
    PlatformTrashManual,
    Unknown,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrashOutcome {
    restore_expectation: RestoreExpectationLevel,
    resulting_location: Option<String>,
}

impl TrashOutcome {
    pub fn platform_trash_manual(resulting_location: Option<String>) -> Self {
        Self {
            restore_expectation: RestoreExpectationLevel::PlatformTrashManual,
            resulting_location,
        }
    }

    pub const fn restore_expectation(&self) -> RestoreExpectationLevel {
        self.restore_expectation
    }

    pub fn resulting_location(&self) -> Option<&str> {
        self.resulting_location.as_deref()
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TrashFailure {
    Unsupported,
    AdapterFailed { message: String },
}

impl fmt::Display for TrashFailure {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Unsupported => formatter.write_str("platform trash is unsupported"),
            Self::AdapterFailed { message } => formatter.write_str(message),
        }
    }
}

impl std::error::Error for TrashFailure {}

pub trait TrashAdapter: Send + Sync {
    fn move_to_trash(&self, path: &Path) -> Result<TrashOutcome, TrashFailure>;
}

pub fn path_identity_evidence(path: &Path) -> io::Result<NodeIdentityEvidence> {
    fs::symlink_metadata(path).map(|metadata| metadata_identity_evidence(&metadata))
}

pub fn metadata_identity_evidence(metadata: &fs::Metadata) -> NodeIdentityEvidence {
    NodeIdentityEvidence::new(
        metadata_platform_file_id(metadata),
        Some(metadata.len()),
        metadata.modified().ok().and_then(system_time_unix_nanos),
        metadata.created().ok().and_then(system_time_unix_nanos),
    )
}

#[cfg(unix)]
fn metadata_platform_file_id(metadata: &fs::Metadata) -> Option<String> {
    Some(format!("unix:{}:{}", metadata.dev(), metadata.ino()))
}

#[cfg(not(unix))]
fn metadata_platform_file_id(_metadata: &fs::Metadata) -> Option<String> {
    None
}

fn system_time_unix_nanos(time: SystemTime) -> Option<u128> {
    time.duration_since(UNIX_EPOCH).ok().map(|duration| {
        u128::from(duration.as_secs())
            .saturating_mul(1_000_000_000)
            .saturating_add(u128::from(duration.subsec_nanos()))
    })
}

#[derive(Debug, Default)]
pub struct OsTrashAdapter;

impl TrashAdapter for OsTrashAdapter {
    fn move_to_trash(&self, path: &Path) -> Result<TrashOutcome, TrashFailure> {
        trash::delete(path).map_err(|error| TrashFailure::AdapterFailed {
            message: error.to_string(),
        })?;
        Ok(TrashOutcome::platform_trash_manual(None))
    }
}
