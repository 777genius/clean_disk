#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum IssueCode {
    PermissionDenied,
    MetadataUnavailable,
    ReadDirectoryFailed,
    AccessEntryFailed,
    BoundarySkipped,
    NonUtf8Path,
    BackendLimitation,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum IssueSeverity {
    Info,
    Warning,
    Error,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Default)]
pub struct IssueEvidence {
    path: Option<String>,
    operation: Option<String>,
    message: Option<String>,
}

impl IssueEvidence {
    pub fn new(path: Option<String>, operation: Option<String>, message: Option<String>) -> Self {
        Self {
            path,
            operation,
            message,
        }
    }

    pub fn path(&self) -> Option<&str> {
        self.path.as_deref()
    }

    pub fn operation(&self) -> Option<&str> {
        self.operation.as_deref()
    }

    pub fn message(&self) -> Option<&str> {
        self.message.as_deref()
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct ScanIssue {
    code: IssueCode,
    severity: IssueSeverity,
    evidence: IssueEvidence,
}

impl ScanIssue {
    pub const fn new(code: IssueCode, severity: IssueSeverity, evidence: IssueEvidence) -> Self {
        Self {
            code,
            severity,
            evidence,
        }
    }

    pub const fn code(&self) -> IssueCode {
        self.code
    }

    pub const fn severity(&self) -> IssueSeverity {
        self.severity
    }

    pub const fn evidence(&self) -> &IssueEvidence {
        &self.evidence
    }
}
