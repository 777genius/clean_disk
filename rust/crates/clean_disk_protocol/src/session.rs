use crate::{DecimalU64Dto, DecimalU128Dto};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum SessionStateDto {
    Created,
    Running,
    Canceled,
    Completed,
    Failed,
    #[serde(other)]
    Unknown,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ScanProgressDto {
    scanned_items: DecimalU64Dto,
    elapsed_ms: Option<DecimalU64Dto>,
    throughput_bytes_per_sec: Option<DecimalU64Dto>,
}

impl ScanProgressDto {
    pub fn new(
        scanned_items: DecimalU64Dto,
        elapsed_ms: Option<DecimalU64Dto>,
        throughput_bytes_per_sec: Option<DecimalU64Dto>,
    ) -> Self {
        Self {
            scanned_items,
            elapsed_ms,
            throughput_bytes_per_sec,
        }
    }

    pub const fn scanned_items(&self) -> &DecimalU64Dto {
        &self.scanned_items
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ScanSessionStatusDto {
    session_id: DecimalU128Dto,
    state: SessionStateDto,
    snapshot_id: Option<DecimalU128Dto>,
    root_node_ids: Vec<DecimalU64Dto>,
    progress: Option<ScanProgressDto>,
}

impl ScanSessionStatusDto {
    pub fn new(
        session_id: DecimalU128Dto,
        state: SessionStateDto,
        snapshot_id: Option<DecimalU128Dto>,
        root_node_ids: Vec<DecimalU64Dto>,
        progress: Option<ScanProgressDto>,
    ) -> Self {
        Self {
            session_id,
            state,
            snapshot_id,
            root_node_ids,
            progress,
        }
    }

    pub const fn session_id(&self) -> &DecimalU128Dto {
        &self.session_id
    }

    pub const fn state(&self) -> SessionStateDto {
        self.state
    }

    pub const fn snapshot_id(&self) -> Option<&DecimalU128Dto> {
        self.snapshot_id.as_ref()
    }

    pub fn root_node_ids(&self) -> &[DecimalU64Dto] {
        &self.root_node_ids
    }

    pub const fn progress(&self) -> Option<&ScanProgressDto> {
        self.progress.as_ref()
    }
}
