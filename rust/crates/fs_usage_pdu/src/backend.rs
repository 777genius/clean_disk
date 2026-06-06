use crate::{
    converter::{PduNodeName, PduTreeConverter},
    options::PduOptionsMapper,
    reporter::PduReporterRecorder,
};
use fs_usage_core::{CapabilitySet, NodeKind, SupportLevel};
use fs_usage_engine::{
    BackendRunId, BackendScanOutput, BackendScanRequest, CancellationToken, EventSink, ScanEvent,
    ScanFailure, ScanSnapshotDraft, ScannerBackend, ScannerBackendCapabilities,
};
use parallel_disk_usage::{
    data_tree::DataTree,
    device::DeviceBoundary,
    get_size::{GetApparentSize, GetSize},
    os_string_display::OsStringDisplay,
    reporter::{Event, Reporter, error_report::Operation::*},
    size::Bytes,
    tree_builder::{Info, TreeBuilder},
};
use std::{
    fs::{FileType, Metadata, read_dir, symlink_metadata},
    path::{Path, PathBuf},
    sync::atomic::{AtomicU64, Ordering},
    thread,
    time::Duration,
};

const PROGRESS_EMIT_INTERVAL: Duration = Duration::from_millis(100);

#[derive(Debug)]
pub struct PduScannerBackend {
    max_depth: u64,
    next_run_id: AtomicU64,
}

impl PduScannerBackend {
    pub const DEFAULT_MAX_DEPTH: u64 = u64::MAX;

    pub fn new(max_depth: u64) -> Self {
        Self {
            max_depth,
            next_run_id: AtomicU64::new(1),
        }
    }

    fn next_run_id(&self) -> BackendRunId {
        let value = self.next_run_id.fetch_add(1, Ordering::Relaxed);
        BackendRunId::new(value.max(1)).expect("backend run id is non-zero")
    }
}

impl Default for PduScannerBackend {
    fn default() -> Self {
        Self::new(Self::DEFAULT_MAX_DEPTH)
    }
}

impl ScannerBackend for PduScannerBackend {
    fn capabilities(&self) -> ScannerBackendCapabilities {
        pdu_capabilities()
    }

    fn scan(
        &self,
        request: BackendScanRequest,
        events: &mut dyn EventSink,
        cancellation: &CancellationToken,
    ) -> Result<BackendScanOutput, ScanFailure> {
        if cancellation.is_canceled() {
            return Err(ScanFailure::Canceled);
        }

        let options = PduOptionsMapper::map(&request, self.max_depth)?;
        let reporter = PduReporterRecorder::default();
        let root_path = options.root().to_path_buf();
        let device_boundary = options.device_boundary();
        let max_depth = options.max_depth();
        let mut last_progress = 0;
        let tree: DataTree<PduNodeName, Bytes> = thread::scope(|scope| {
            let handle =
                scope.spawn(|| build_pdu_tree(&root_path, device_boundary, max_depth, &reporter));
            while !handle.is_finished() {
                thread::sleep(PROGRESS_EMIT_INTERVAL);
                if !cancellation.is_canceled() {
                    emit_progress_if_changed(
                        events,
                        request.session_id(),
                        &reporter,
                        &mut last_progress,
                    );
                }
            }
            handle
                .join()
                .map_err(|_| ScanFailure::Backend("pdu scan worker panicked".to_string()))
        })?;

        if cancellation.is_canceled() {
            return Err(ScanFailure::Canceled);
        }

        emit_progress_if_changed(events, request.session_id(), &reporter, &mut last_progress);

        let mut issues = reporter.take_issues();
        let root = PduTreeConverter::new(request.measurement(), self.max_depth).convert_root(
            &tree,
            &root_path,
            &mut issues,
        );
        issues.extend(options.into_limitation_issues());
        let draft = ScanSnapshotDraft::new(vec![root]);

        Ok(BackendScanOutput::new(
            self.next_run_id(),
            draft,
            issues,
            self.capabilities(),
        ))
    }
}

fn emit_progress_if_changed(
    events: &mut dyn EventSink,
    session_id: fs_usage_core::ScanSessionId,
    reporter: &PduReporterRecorder,
    last_progress: &mut u64,
) {
    let scanned_items = reporter.received_data_count();
    if scanned_items <= *last_progress {
        return;
    }
    *last_progress = scanned_items;
    events.emit(ScanEvent::Progress {
        session_id,
        scanned_items,
    });
}

fn build_pdu_tree(
    root: &Path,
    device_boundary: DeviceBoundary,
    max_depth: u64,
    reporter: &PduReporterRecorder,
) -> DataTree<PduNodeName, Bytes> {
    let root_metadata = symlink_metadata(root);
    let root_device = match (device_boundary, root_metadata.as_ref()) {
        (DeviceBoundary::Stay, Ok(metadata)) => Some(device_id(metadata)),
        (DeviceBoundary::Stay, Err(error)) => {
            reporter.report_error(SymlinkMetadata, root, clone_io_error(error));
            None
        }
        (DeviceBoundary::Cross, _) => None,
    };
    let root_kind = root_metadata
        .as_ref()
        .map(classify_metadata)
        .unwrap_or(NodeKind::Unknown);

    TreeBuilder::<PathBuf, PduNodeName, Bytes, _, _> {
        name: PduNodeName::new(
            OsStringDisplay::os_string_from(root.as_os_str().to_os_string()),
            root_kind,
        ),
        path: root.to_path_buf(),
        get_info: |path| {
            let (kind, size, same_device) = match symlink_metadata(path) {
                Err(error) => {
                    reporter.report_error(SymlinkMetadata, path, error);
                    return Info {
                        size: Bytes::default(),
                        children: Vec::new(),
                    };
                }
                Ok(metadata) => {
                    let kind = classify_metadata(&metadata);
                    let same_device =
                        root_device.is_none_or(|root_device| device_id(&metadata) == root_device);
                    let size = GetApparentSize.get_size(&metadata);
                    reporter.report(Event::ReceiveData(size));
                    (kind, size, same_device)
                }
            };

            let children = if kind == NodeKind::Directory && same_device {
                match read_dir(path) {
                    Err(error) => {
                        reporter.report_error(ReadDirectory, path, error);
                        return Info {
                            size,
                            children: Vec::new(),
                        };
                    }
                    Ok(entries) => entries,
                }
                .filter_map(|entry| match entry {
                    Err(error) => {
                        reporter.report_error(AccessEntry, path, error);
                        None
                    }
                    Ok(entry) => {
                        let kind = match entry.file_type() {
                            Ok(file_type) => classify_file_type(&file_type),
                            Err(error) => {
                                let child_path = entry.path();
                                reporter.report_error(AccessEntry, &child_path, error);
                                NodeKind::Unknown
                            }
                        };
                        Some(PduNodeName::new(
                            OsStringDisplay::from(entry.file_name()),
                            kind,
                        ))
                    }
                })
                .collect()
            } else {
                Vec::new()
            };

            Info { size, children }
        },
        join_path: |prefix, name| prefix.join(name.as_os_str()),
        max_depth,
    }
    .into()
}

fn classify_metadata(metadata: &Metadata) -> NodeKind {
    classify_file_type(&metadata.file_type())
}

fn classify_file_type(file_type: &FileType) -> NodeKind {
    if file_type.is_symlink() {
        NodeKind::Symlink
    } else if file_type.is_dir() {
        NodeKind::Directory
    } else if file_type.is_file() {
        NodeKind::File
    } else {
        NodeKind::Other
    }
}

#[cfg(unix)]
type DeviceId = u64;

#[cfg(not(unix))]
type DeviceId = ();

#[cfg(unix)]
fn device_id(metadata: &Metadata) -> DeviceId {
    use std::os::unix::fs::MetadataExt;
    metadata.dev()
}

#[cfg(not(unix))]
fn device_id(_metadata: &Metadata) -> DeviceId {}

fn clone_io_error(error: &std::io::Error) -> std::io::Error {
    std::io::Error::new(error.kind(), error.to_string())
}

fn pdu_capabilities() -> ScannerBackendCapabilities {
    ScannerBackendCapabilities::new(
        "parallel-disk-usage",
        CapabilitySet::new(
            SupportLevel::Unsupported,
            SupportLevel::Supported,
            SupportLevel::Unsupported,
            SupportLevel::Unsupported,
        ),
    )
}
