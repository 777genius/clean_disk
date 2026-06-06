use crate::backend::PduScannerBackend;
use fs_usage_core::{
    ChildCompleteness, EvidenceConfidence, IssueCode, IssueEvidence, IssueSeverity,
    MeasuredQuantity, NodeKind, ScanIssue, SizeBytes, SizeFact,
};
use fs_usage_engine::DraftNode;
use parallel_disk_usage::{data_tree::DataTree, os_string_display::OsStringDisplay, size::Size};
use std::{
    ffi::OsStr,
    path::{Path, PathBuf},
};

#[derive(Debug, PartialEq, Eq)]
pub(crate) struct PduNodeName {
    display: OsStringDisplay,
    kind: NodeKind,
}

impl PduNodeName {
    pub(crate) fn new(display: OsStringDisplay, kind: NodeKind) -> Self {
        Self { display, kind }
    }

    pub(crate) fn as_os_str(&self) -> &OsStr {
        self.display.as_os_str()
    }

    const fn kind(&self) -> NodeKind {
        self.kind
    }
}

#[derive(Debug, Clone, Copy)]
pub(crate) struct PduTreeConverter {
    measurement: MeasuredQuantity,
    max_depth: u64,
}

impl PduTreeConverter {
    pub(crate) const fn new(measurement: MeasuredQuantity, max_depth: u64) -> Self {
        Self {
            measurement,
            max_depth,
        }
    }

    pub(crate) fn convert_root<RawSize: Size + Into<u64>>(
        self,
        tree: &DataTree<PduNodeName, RawSize>,
        root_path: &Path,
        issues: &mut Vec<ScanIssue>,
    ) -> DraftNode {
        self.convert_tree(tree, 0, root_path, issues)
    }

    fn convert_tree<RawSize: Size + Into<u64>>(
        self,
        tree: &DataTree<PduNodeName, RawSize>,
        depth: u64,
        current_path: &Path,
        issues: &mut Vec<ScanIssue>,
    ) -> DraftNode {
        let name = os_name_to_string(tree.name(), issues);
        let children = tree
            .children()
            .iter()
            .map(|child| {
                let child_path = join_child_path(current_path, child.name());
                self.convert_tree(child, depth.saturating_add(1), &child_path, issues)
            })
            .collect::<Vec<_>>();
        let raw_size = tree.size().into();
        let kind = tree.name().kind();
        let (kind, child_completeness) = if children.is_empty() {
            let completeness = if self.max_depth != PduScannerBackend::DEFAULT_MAX_DEPTH
                && depth.saturating_add(1) >= self.max_depth
            {
                ChildCompleteness::CollapsedByDepth
            } else {
                ChildCompleteness::Complete
            };
            (kind, completeness)
        } else {
            (NodeKind::Directory, ChildCompleteness::Complete)
        };
        let size = SizeFact::new(
            raw_size,
            self.measurement,
            Some(SizeBytes::new(raw_size)),
            EvidenceConfidence::High,
        );

        DraftNode::new(name, kind, size, child_completeness)
            .with_source_path(current_path.to_path_buf())
            .with_children(children)
    }
}

fn join_child_path(parent: &Path, child_name: &PduNodeName) -> PathBuf {
    parent.join(child_name.as_os_str())
}

fn os_name_to_string(name: &PduNodeName, issues: &mut Vec<ScanIssue>) -> String {
    match name.as_os_str().to_str() {
        Some(value) => value.to_string(),
        None => {
            let value = name.as_os_str().to_string_lossy().into_owned();
            issues.push(ScanIssue::new(
                IssueCode::NonUtf8Path,
                IssueSeverity::Warning,
                IssueEvidence::new(
                    Some(value.clone()),
                    Some("pdu_name_decode".to_string()),
                    Some("path segment was converted with lossy UTF-8 replacement".to_string()),
                ),
            ));
            value
        }
    }
}
