use crate::{
    ChildCompletenessDto, DecimalU64Dto, DecimalU128Dto, NodeKindDto, ProtocolVersionDto,
    ScanIssueDto, ScanProgressDto, SizeFactDto,
};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

pub type EventSequenceDto = DecimalU64Dto;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ScanEventEnvelopeDto {
    protocol_version: ProtocolVersionDto,
    sequence: EventSequenceDto,
    emitted_at_unix_ms: DecimalU64Dto,
    event: ScanEventDto,
}

impl ScanEventEnvelopeDto {
    pub fn new(
        protocol_version: ProtocolVersionDto,
        sequence: EventSequenceDto,
        emitted_at_unix_ms: DecimalU64Dto,
        event: ScanEventDto,
    ) -> Self {
        Self {
            protocol_version,
            sequence,
            emitted_at_unix_ms,
            event,
        }
    }

    pub const fn sequence(&self) -> &EventSequenceDto {
        &self.sequence
    }

    pub const fn emitted_at_unix_ms(&self) -> &DecimalU64Dto {
        &self.emitted_at_unix_ms
    }

    pub const fn event(&self) -> &ScanEventDto {
        &self.event
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(
    tag = "type",
    rename_all = "snake_case",
    rename_all_fields = "camelCase"
)]
pub enum ScanEventDto {
    Started {
        session_id: DecimalU128Dto,
    },
    Progress {
        session_id: DecimalU128Dto,
        progress: ScanProgressDto,
    },
    GrowingTreeBatch {
        session_id: DecimalU128Dto,
        scanned_items: DecimalU64Dto,
        events: Vec<GrowingTreeEventDto>,
    },
    SnapshotPublished {
        session_id: DecimalU128Dto,
        snapshot_id: DecimalU128Dto,
    },
    Canceled {
        session_id: DecimalU128Dto,
    },
    Failed {
        session_id: DecimalU128Dto,
        message: String,
    },
    #[serde(other)]
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum GrowingNodeStateDto {
    Discovered,
    Scanning,
    Complete,
    Skipped,
    Stale,
    Unknown,
    #[serde(other)]
    Unrecognized,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(
    tag = "type",
    rename_all = "snake_case",
    rename_all_fields = "camelCase"
)]
pub enum GrowingTreeEventDto {
    NodeDiscovered {
        node_id: DecimalU64Dto,
        parent_id: Option<DecimalU64Dto>,
        name: String,
        kind: NodeKindDto,
    },
    NodeSizeUpdated {
        node_id: DecimalU64Dto,
        aggregate_size: SizeFactDto,
        state: GrowingNodeStateDto,
    },
    NodeCompleted {
        node_id: DecimalU64Dto,
        aggregate_size: SizeFactDto,
        child_completeness: ChildCompletenessDto,
    },
    NodeIssueRecorded {
        node_id: Option<DecimalU64Dto>,
        issue: ScanIssueDto,
    },
    #[serde(other)]
    Unknown,
}
