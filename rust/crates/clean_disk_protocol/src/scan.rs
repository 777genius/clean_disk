use crate::{DecimalU128Dto, ProtocolVersionDto, RawPathDto};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum TargetScopeDto {
    LocalPath,
    Volume,
    Custom,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum BoundaryPolicyDto {
    CrossFilesystems,
    StayOnInitialFilesystem,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum HardlinkPolicyDto {
    Ignore,
    Detect,
    DeduplicateForDisplay,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum MeasuredQuantityDto {
    ApparentBytes,
    AllocatedBytes,
    BlockCount,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum ScanModeDto {
    Background,
    Balanced,
    Fast,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ScanTargetDto {
    path: RawPathDto,
    scope: TargetScopeDto,
    boundary_policy: BoundaryPolicyDto,
    hardlink_policy: HardlinkPolicyDto,
}

impl ScanTargetDto {
    pub const fn new(
        path: RawPathDto,
        scope: TargetScopeDto,
        boundary_policy: BoundaryPolicyDto,
        hardlink_policy: HardlinkPolicyDto,
    ) -> Self {
        Self {
            path,
            scope,
            boundary_policy,
            hardlink_policy,
        }
    }

    pub const fn path(&self) -> &RawPathDto {
        &self.path
    }

    pub const fn scope(&self) -> TargetScopeDto {
        self.scope
    }

    pub const fn boundary_policy(&self) -> BoundaryPolicyDto {
        self.boundary_policy
    }

    pub const fn hardlink_policy(&self) -> HardlinkPolicyDto {
        self.hardlink_policy
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct StartScanRequestDto {
    protocol_version: ProtocolVersionDto,
    command_id: DecimalU128Dto,
    targets: Vec<ScanTargetDto>,
    measurement: MeasuredQuantityDto,
    mode: ScanModeDto,
}

impl StartScanRequestDto {
    pub fn new(
        protocol_version: ProtocolVersionDto,
        command_id: DecimalU128Dto,
        targets: Vec<ScanTargetDto>,
        measurement: MeasuredQuantityDto,
        mode: ScanModeDto,
    ) -> Self {
        Self {
            protocol_version,
            command_id,
            targets,
            measurement,
            mode,
        }
    }

    pub const fn protocol_version(&self) -> ProtocolVersionDto {
        self.protocol_version
    }

    pub const fn command_id(&self) -> &DecimalU128Dto {
        &self.command_id
    }

    pub fn targets(&self) -> &[ScanTargetDto] {
        &self.targets
    }

    pub const fn measurement(&self) -> MeasuredQuantityDto {
        self.measurement
    }

    pub const fn mode(&self) -> ScanModeDto {
        self.mode
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CancelScanRequestDto {
    protocol_version: ProtocolVersionDto,
    command_id: DecimalU128Dto,
    session_id: DecimalU128Dto,
}

impl CancelScanRequestDto {
    pub const fn new(
        protocol_version: ProtocolVersionDto,
        command_id: DecimalU128Dto,
        session_id: DecimalU128Dto,
    ) -> Self {
        Self {
            protocol_version,
            command_id,
            session_id,
        }
    }

    pub const fn session_id(&self) -> &DecimalU128Dto {
        &self.session_id
    }

    pub const fn protocol_version(&self) -> ProtocolVersionDto {
        self.protocol_version
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct DisposeScanSessionRequestDto {
    protocol_version: ProtocolVersionDto,
    command_id: DecimalU128Dto,
    session_id: DecimalU128Dto,
}

impl DisposeScanSessionRequestDto {
    pub const fn new(
        protocol_version: ProtocolVersionDto,
        command_id: DecimalU128Dto,
        session_id: DecimalU128Dto,
    ) -> Self {
        Self {
            protocol_version,
            command_id,
            session_id,
        }
    }

    pub const fn session_id(&self) -> &DecimalU128Dto {
        &self.session_id
    }

    pub const fn protocol_version(&self) -> ProtocolVersionDto {
        self.protocol_version
    }
}
