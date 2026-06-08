use crate::{growing_tree::GrowingTreeBatch, ports::EventSink};
use fs_usage_core::{ScanSessionId, SnapshotId};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ScanEvent {
    Started {
        session_id: ScanSessionId,
    },
    Progress {
        session_id: ScanSessionId,
        scanned_items: u64,
    },
    GrowingTreeBatch {
        batch: GrowingTreeBatch,
    },
    SnapshotPublished {
        session_id: ScanSessionId,
        snapshot_id: SnapshotId,
    },
    Canceled {
        session_id: ScanSessionId,
    },
    Failed {
        session_id: ScanSessionId,
        message: String,
    },
}

#[derive(Debug, Default)]
pub struct VecEventSink {
    events: Vec<ScanEvent>,
}

impl VecEventSink {
    pub fn events(&self) -> &[ScanEvent] {
        &self.events
    }

    pub fn into_events(self) -> Vec<ScanEvent> {
        self.events
    }
}

impl EventSink for VecEventSink {
    fn emit(&mut self, event: ScanEvent) {
        self.events.push(event);
    }
}
