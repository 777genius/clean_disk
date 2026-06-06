use crate::{DecimalU64Dto, DecimalU128Dto, ProtocolVersionDto};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum CleanupItemOutcomeStateDto {
    Pending,
    DispatchRecorded,
    MovedToTrash,
    Blocked,
    Failed,
    UnknownRequiresReview,
    #[serde(other)]
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum CleanupReceiptStateDto {
    IntentRecorded,
    ReceiptSkeletonRecorded,
    Running,
    Completed,
    CompletedWithFailures,
    InterruptedRequiresReview,
    CompletedWithUnknowns,
    FailedBeforeDispatch,
    #[serde(other)]
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum RestoreExpectationLevelDto {
    PlatformTrashManual,
    Unknown,
    NotRestorable,
    #[serde(other)]
    Unsupported,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum CleanupPlanStateDto {
    Ready,
    Blocked,
    #[serde(other)]
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum CleanupPlanItemStateDto {
    Ready,
    Blocked,
    #[serde(other)]
    Unknown,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CleanupPlanItemRefDto {
    session_id: DecimalU128Dto,
    snapshot_id: DecimalU128Dto,
    node_id: DecimalU64Dto,
}

impl CleanupPlanItemRefDto {
    pub fn new(
        session_id: DecimalU128Dto,
        snapshot_id: DecimalU128Dto,
        node_id: DecimalU64Dto,
    ) -> Self {
        Self {
            session_id,
            snapshot_id,
            node_id,
        }
    }

    pub const fn session_id(&self) -> &DecimalU128Dto {
        &self.session_id
    }

    pub const fn snapshot_id(&self) -> &DecimalU128Dto {
        &self.snapshot_id
    }

    pub const fn node_id(&self) -> &DecimalU64Dto {
        &self.node_id
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CreateCleanupPlanRequestDto {
    protocol_version: ProtocolVersionDto,
    command_id: DecimalU128Dto,
    items: Vec<CleanupPlanItemRefDto>,
}

impl CreateCleanupPlanRequestDto {
    pub fn new(
        protocol_version: ProtocolVersionDto,
        command_id: DecimalU128Dto,
        items: Vec<CleanupPlanItemRefDto>,
    ) -> Self {
        Self {
            protocol_version,
            command_id,
            items,
        }
    }

    pub const fn protocol_version(&self) -> ProtocolVersionDto {
        self.protocol_version
    }

    pub const fn command_id(&self) -> &DecimalU128Dto {
        &self.command_id
    }

    pub fn items(&self) -> &[CleanupPlanItemRefDto] {
        &self.items
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CleanupPlanItemDto {
    item_ref: CleanupPlanItemRefDto,
    display_name: String,
    state: CleanupPlanItemStateDto,
    reason: Option<String>,
}

impl CleanupPlanItemDto {
    pub fn new(
        item_ref: CleanupPlanItemRefDto,
        display_name: impl Into<String>,
        state: CleanupPlanItemStateDto,
        reason: Option<String>,
    ) -> Self {
        Self {
            item_ref,
            display_name: display_name.into(),
            state,
            reason,
        }
    }

    pub const fn item_ref(&self) -> &CleanupPlanItemRefDto {
        &self.item_ref
    }

    pub fn display_name(&self) -> &str {
        &self.display_name
    }

    pub const fn state(&self) -> CleanupPlanItemStateDto {
        self.state
    }

    pub fn reason(&self) -> Option<&str> {
        self.reason.as_deref()
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CleanupPlanDto {
    protocol_version: ProtocolVersionDto,
    plan_id: DecimalU128Dto,
    command_id: DecimalU128Dto,
    state: CleanupPlanStateDto,
    created_at_unix_ms: DecimalU64Dto,
    items: Vec<CleanupPlanItemDto>,
}

impl CleanupPlanDto {
    pub fn new(
        plan_id: DecimalU128Dto,
        command_id: DecimalU128Dto,
        state: CleanupPlanStateDto,
        created_at_unix_ms: DecimalU64Dto,
        items: Vec<CleanupPlanItemDto>,
    ) -> Self {
        Self {
            protocol_version: crate::PROTOCOL_VERSION,
            plan_id,
            command_id,
            state,
            created_at_unix_ms,
            items,
        }
    }

    pub const fn protocol_version(&self) -> ProtocolVersionDto {
        self.protocol_version
    }

    pub const fn plan_id(&self) -> &DecimalU128Dto {
        &self.plan_id
    }

    pub const fn command_id(&self) -> &DecimalU128Dto {
        &self.command_id
    }

    pub const fn state(&self) -> CleanupPlanStateDto {
        self.state
    }

    pub fn items(&self) -> &[CleanupPlanItemDto] {
        &self.items
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ExecuteCleanupPlanRequestDto {
    protocol_version: ProtocolVersionDto,
    command_id: DecimalU128Dto,
    plan_id: DecimalU128Dto,
}

impl ExecuteCleanupPlanRequestDto {
    pub fn new(
        protocol_version: ProtocolVersionDto,
        command_id: DecimalU128Dto,
        plan_id: DecimalU128Dto,
    ) -> Self {
        Self {
            protocol_version,
            command_id,
            plan_id,
        }
    }

    pub const fn protocol_version(&self) -> ProtocolVersionDto {
        self.protocol_version
    }

    pub const fn command_id(&self) -> &DecimalU128Dto {
        &self.command_id
    }

    pub const fn plan_id(&self) -> &DecimalU128Dto {
        &self.plan_id
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ExecuteCleanupRequestDto {
    protocol_version: ProtocolVersionDto,
    command_id: DecimalU128Dto,
    items: Vec<CleanupPlanItemRefDto>,
}

impl ExecuteCleanupRequestDto {
    pub fn new(
        protocol_version: ProtocolVersionDto,
        command_id: DecimalU128Dto,
        items: Vec<CleanupPlanItemRefDto>,
    ) -> Self {
        Self {
            protocol_version,
            command_id,
            items,
        }
    }

    pub const fn protocol_version(&self) -> ProtocolVersionDto {
        self.protocol_version
    }

    pub const fn command_id(&self) -> &DecimalU128Dto {
        &self.command_id
    }

    pub fn items(&self) -> &[CleanupPlanItemRefDto] {
        &self.items
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CleanupReceiptItemDto {
    node_id: DecimalU64Dto,
    display_name: String,
    state: CleanupItemOutcomeStateDto,
    restore_expectation: RestoreExpectationLevelDto,
    reason: Option<String>,
    resulting_location: Option<String>,
}

impl CleanupReceiptItemDto {
    pub fn new(
        node_id: DecimalU64Dto,
        display_name: impl Into<String>,
        state: CleanupItemOutcomeStateDto,
        restore_expectation: RestoreExpectationLevelDto,
        reason: Option<String>,
        resulting_location: Option<String>,
    ) -> Self {
        Self {
            node_id,
            display_name: display_name.into(),
            state,
            restore_expectation,
            reason,
            resulting_location,
        }
    }

    pub const fn node_id(&self) -> &DecimalU64Dto {
        &self.node_id
    }

    pub fn display_name(&self) -> &str {
        &self.display_name
    }

    pub const fn state(&self) -> CleanupItemOutcomeStateDto {
        self.state
    }

    pub const fn restore_expectation(&self) -> RestoreExpectationLevelDto {
        self.restore_expectation
    }

    pub fn reason(&self) -> Option<&str> {
        self.reason.as_deref()
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CleanupReceiptDto {
    protocol_version: ProtocolVersionDto,
    operation_id: DecimalU128Dto,
    command_id: DecimalU128Dto,
    state: CleanupReceiptStateDto,
    started_at_unix_ms: DecimalU64Dto,
    updated_at_unix_ms: DecimalU64Dto,
    low_disk_reserve_ready: bool,
    items: Vec<CleanupReceiptItemDto>,
}

impl CleanupReceiptDto {
    pub fn new(
        operation_id: DecimalU128Dto,
        command_id: DecimalU128Dto,
        state: CleanupReceiptStateDto,
        started_at_unix_ms: DecimalU64Dto,
        updated_at_unix_ms: DecimalU64Dto,
        low_disk_reserve_ready: bool,
        items: Vec<CleanupReceiptItemDto>,
    ) -> Self {
        Self {
            protocol_version: crate::PROTOCOL_VERSION,
            operation_id,
            command_id,
            state,
            started_at_unix_ms,
            updated_at_unix_ms,
            low_disk_reserve_ready,
            items,
        }
    }

    pub const fn protocol_version(&self) -> ProtocolVersionDto {
        self.protocol_version
    }

    pub const fn operation_id(&self) -> &DecimalU128Dto {
        &self.operation_id
    }

    pub const fn command_id(&self) -> &DecimalU128Dto {
        &self.command_id
    }

    pub const fn state(&self) -> CleanupReceiptStateDto {
        self.state
    }

    pub fn items(&self) -> &[CleanupReceiptItemDto] {
        &self.items
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CleanupRecoveryInboxDto {
    protocol_version: ProtocolVersionDto,
    interrupted_receipts: Vec<CleanupReceiptDto>,
}

impl CleanupRecoveryInboxDto {
    pub fn new(interrupted_receipts: Vec<CleanupReceiptDto>) -> Self {
        Self {
            protocol_version: crate::PROTOCOL_VERSION,
            interrupted_receipts,
        }
    }

    pub fn interrupted_receipts(&self) -> &[CleanupReceiptDto] {
        &self.interrupted_receipts
    }
}
