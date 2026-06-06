use crate::DisplayPathDto;
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum IssueCodeDto {
    PermissionDenied,
    MetadataUnavailable,
    ReadDirectoryFailed,
    AccessEntryFailed,
    BoundarySkipped,
    NonUtf8Path,
    BackendLimitation,
    Unknown,
    #[serde(other)]
    Unrecognized,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum IssueSeverityDto {
    Info,
    Warning,
    Error,
    Unknown,
    #[serde(other)]
    Unrecognized,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct IssueEvidenceDto {
    path: Option<DisplayPathDto>,
    operation: Option<String>,
    message: Option<String>,
}

impl IssueEvidenceDto {
    pub fn new(
        path: Option<DisplayPathDto>,
        operation: Option<String>,
        message: Option<String>,
    ) -> Self {
        Self {
            path,
            operation,
            message,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ScanIssueDto {
    code: IssueCodeDto,
    severity: IssueSeverityDto,
    evidence: IssueEvidenceDto,
}

impl ScanIssueDto {
    pub const fn new(
        code: IssueCodeDto,
        severity: IssueSeverityDto,
        evidence: IssueEvidenceDto,
    ) -> Self {
        Self {
            code,
            severity,
            evidence,
        }
    }
}
