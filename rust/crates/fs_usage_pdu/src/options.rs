use crate::backend::PduScannerBackend;
use fs_usage_core::{
    BoundaryPolicy, HardlinkPolicy, IssueCode, IssueEvidence, IssueSeverity, MeasuredQuantity,
    ScanIssue,
};
use fs_usage_engine::{BackendScanRequest, ScanFailure};
use parallel_disk_usage::device::DeviceBoundary;
use std::path::{Path, PathBuf};

#[derive(Debug)]
pub(crate) struct PduOptions {
    root: PathBuf,
    device_boundary: DeviceBoundary,
    max_depth: u64,
    limitation_issues: Vec<ScanIssue>,
}

impl PduOptions {
    pub(crate) fn root(&self) -> &Path {
        &self.root
    }

    pub(crate) const fn device_boundary(&self) -> DeviceBoundary {
        self.device_boundary
    }

    pub(crate) const fn max_depth(&self) -> u64 {
        self.max_depth
    }

    pub(crate) fn into_limitation_issues(self) -> Vec<ScanIssue> {
        self.limitation_issues
    }
}

pub(crate) struct PduOptionsMapper;

impl PduOptionsMapper {
    pub(crate) fn map(
        request: &BackendScanRequest,
        max_depth: u64,
    ) -> Result<PduOptions, ScanFailure> {
        if request.targets().len() != 1 {
            return Err(ScanFailure::InvalidRequest(
                "pdu MVP adapter expects exactly one scan target".to_string(),
            ));
        }

        if request.measurement() != MeasuredQuantity::ApparentBytes {
            return Err(ScanFailure::InvalidRequest(
                "pdu MVP adapter currently supports apparent bytes only".to_string(),
            ));
        }

        let target = &request.targets()[0];
        let root = PathBuf::from(target.path().as_str());
        let mut limitation_issues = Vec::new();
        if target.hardlink_policy() != HardlinkPolicy::Ignore {
            limitation_issues.push(ScanIssue::new(
                IssueCode::BackendLimitation,
                IssueSeverity::Info,
                IssueEvidence::new(
                    Some(target.path().as_str().to_string()),
                    Some("hardlink_policy".to_string()),
                    Some(
                        "pdu MVP adapter records hardlink policy as unsupported evidence"
                            .to_string(),
                    ),
                ),
            ));
        }
        if max_depth != PduScannerBackend::DEFAULT_MAX_DEPTH {
            limitation_issues.push(ScanIssue::new(
                IssueCode::BackendLimitation,
                IssueSeverity::Info,
                IssueEvidence::new(
                    Some(target.path().as_str().to_string()),
                    Some("max_depth".to_string()),
                    Some(
                        "pdu final DataTree does not expose exact collapsed node identities"
                            .to_string(),
                    ),
                ),
            ));
        }

        Ok(PduOptions {
            root,
            device_boundary: match target.boundary_policy() {
                BoundaryPolicy::CrossFilesystems => DeviceBoundary::Cross,
                BoundaryPolicy::StayOnInitialFilesystem => DeviceBoundary::Stay,
            },
            max_depth,
            limitation_issues,
        })
    }
}
