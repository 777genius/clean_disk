use fs_usage_core::{IssueCode, IssueEvidence, IssueSeverity, ScanIssue};
use parallel_disk_usage::{
    reporter::{ErrorReport, Event, Reporter, error_report::Operation},
    size::Size,
};
use std::{
    io,
    path::Path,
    sync::{
        Mutex,
        atomic::{AtomicU64, Ordering},
    },
};

const MAX_RECORDED_ISSUES: usize = 4096;

#[derive(Debug, Default)]
pub(crate) struct PduReporterRecorder {
    issues: Mutex<Vec<ScanIssue>>,
    received_data_count: AtomicU64,
    dropped_issue_count: AtomicU64,
}

impl PduReporterRecorder {
    pub(crate) fn take_issues(&self) -> Vec<ScanIssue> {
        let mut issues = self
            .issues
            .lock()
            .expect("pdu issue recorder poisoned")
            .clone();
        let dropped = self.dropped_issue_count.load(Ordering::Relaxed);
        if dropped > 0 {
            issues.push(ScanIssue::new(
                IssueCode::BackendLimitation,
                IssueSeverity::Warning,
                IssueEvidence::new(
                    None,
                    Some("pdu_reporter_recorder".to_string()),
                    Some(format!(
                        "pdu issue recorder dropped {dropped} excess issues"
                    )),
                ),
            ));
        }
        issues
    }

    pub(crate) fn received_data_count(&self) -> u64 {
        self.received_data_count.load(Ordering::Relaxed)
    }

    pub(crate) fn report_error(&self, operation: Operation, path: &Path, error: io::Error) {
        self.record_issue(map_error_report(ErrorReport {
            operation,
            path,
            error,
        }));
    }

    fn record_issue(&self, issue: ScanIssue) {
        let mut issues = self.issues.lock().expect("pdu issue recorder poisoned");
        if issues.len() < MAX_RECORDED_ISSUES {
            issues.push(issue);
        } else {
            self.dropped_issue_count.fetch_add(1, Ordering::Relaxed);
        }
    }
}

impl<RawSize: Size> Reporter<RawSize> for PduReporterRecorder {
    fn report(&self, event: Event<RawSize>) {
        match event {
            Event::ReceiveData(_) => {
                self.received_data_count.fetch_add(1, Ordering::Relaxed);
            }
            Event::EncounterError(report) => {
                self.record_issue(map_error_report(report));
            }
            Event::DetectHardlink(_) => {}
            _ => {}
        }
    }
}

fn map_error_report(report: ErrorReport<'_>) -> ScanIssue {
    let code = if report.error.kind() == std::io::ErrorKind::PermissionDenied {
        IssueCode::PermissionDenied
    } else {
        match report.operation {
            Operation::SymlinkMetadata => IssueCode::MetadataUnavailable,
            Operation::ReadDirectory => IssueCode::ReadDirectoryFailed,
            Operation::AccessEntry => IssueCode::AccessEntryFailed,
        }
    };

    ScanIssue::new(
        code,
        IssueSeverity::Warning,
        IssueEvidence::new(
            Some(report.path.to_string_lossy().into_owned()),
            Some(report.operation.name().to_string()),
            Some(report.error.to_string()),
        ),
    )
}
