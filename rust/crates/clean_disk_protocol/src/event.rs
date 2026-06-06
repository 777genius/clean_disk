use crate::{DecimalU64Dto, DecimalU128Dto, ProtocolVersionDto, ScanProgressDto};
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
