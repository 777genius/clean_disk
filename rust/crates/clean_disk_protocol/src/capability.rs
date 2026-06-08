use crate::{DecimalU128Dto, DecimalUsizeDto, ProtocolVersionDto, RawPathDto, scan::ScanTargetDto};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum SupportLevelDto {
    Supported,
    Unsupported,
    Unknown,
    #[serde(other)]
    Unrecognized,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum RuntimePlatformDto {
    Macos,
    Windows,
    Linux,
    Unknown,
    #[serde(other)]
    Unrecognized,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum ScannerProcessKindDto {
    AppBundle,
    BundledHelper,
    CurrentProcess,
    ExternalProcess,
    Unknown,
    #[serde(other)]
    Unrecognized,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum ScannerIdentityVerificationDto {
    Verified,
    Unverified,
    Unknown,
    #[serde(other)]
    Unrecognized,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum PermissionProbeStatusDto {
    Verified,
    Denied,
    NotDetermined,
    NotProbed,
    Degraded,
    Unsupported,
    Unknown,
    #[serde(other)]
    Unrecognized,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum PermissionRequiredActionDto {
    None,
    OpenMacosFullDiskAccess,
    RunAsAdministrator,
    ReviewLinuxPermissions,
    Unknown,
    #[serde(other)]
    Unrecognized,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum DistributionChannelDto {
    Development,
    Direct,
    MacAppStore,
    WindowsStore,
    PackageManager,
    Unknown,
    #[serde(other)]
    Unrecognized,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum PackageModeDto {
    DevelopmentShell,
    AppBundle,
    BundledDaemon,
    SystemService,
    Portable,
    Unknown,
    #[serde(other)]
    Unrecognized,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CapabilitySetDto {
    hardlinks: SupportLevelDto,
    filesystem_boundary: SupportLevelDto,
    cooperative_cancellation: SupportLevelDto,
    metadata_enrichment: SupportLevelDto,
    #[serde(default = "unknown_support_level")]
    growing_tree_streaming: SupportLevelDto,
}

impl CapabilitySetDto {
    pub const fn new(
        hardlinks: SupportLevelDto,
        filesystem_boundary: SupportLevelDto,
        cooperative_cancellation: SupportLevelDto,
        metadata_enrichment: SupportLevelDto,
        growing_tree_streaming: SupportLevelDto,
    ) -> Self {
        Self {
            hardlinks,
            filesystem_boundary,
            cooperative_cancellation,
            metadata_enrichment,
            growing_tree_streaming,
        }
    }

    pub const fn hardlinks(&self) -> SupportLevelDto {
        self.hardlinks
    }

    pub const fn filesystem_boundary(&self) -> SupportLevelDto {
        self.filesystem_boundary
    }

    pub const fn cooperative_cancellation(&self) -> SupportLevelDto {
        self.cooperative_cancellation
    }

    pub const fn metadata_enrichment(&self) -> SupportLevelDto {
        self.metadata_enrichment
    }

    pub const fn growing_tree_streaming(&self) -> SupportLevelDto {
        self.growing_tree_streaming
    }
}

const fn unknown_support_level() -> SupportLevelDto {
    SupportLevelDto::Unknown
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct UpdateSafetyDto {
    quiesce_required_before_update: bool,
    rollback_supported: SupportLevelDto,
    receipt_preservation: SupportLevelDto,
}

impl UpdateSafetyDto {
    pub const fn new(
        quiesce_required_before_update: bool,
        rollback_supported: SupportLevelDto,
        receipt_preservation: SupportLevelDto,
    ) -> Self {
        Self {
            quiesce_required_before_update,
            rollback_supported,
            receipt_preservation,
        }
    }

    pub const fn quiesce_required_before_update(&self) -> bool {
        self.quiesce_required_before_update
    }

    pub const fn rollback_supported(&self) -> SupportLevelDto {
        self.rollback_supported
    }

    pub const fn receipt_preservation(&self) -> SupportLevelDto {
        self.receipt_preservation
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct PackagingProofDto {
    distribution_channel: DistributionChannelDto,
    package_mode: PackageModeDto,
    sandboxed: bool,
    signed_build: bool,
    debug_build: bool,
    scanner_process: ScannerProcessKindDto,
    limitations: Vec<String>,
    update_safety: UpdateSafetyDto,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PackagingProofDtoParts {
    pub distribution_channel: DistributionChannelDto,
    pub package_mode: PackageModeDto,
    pub sandboxed: bool,
    pub signed_build: bool,
    pub debug_build: bool,
    pub scanner_process: ScannerProcessKindDto,
    pub limitations: Vec<String>,
    pub update_safety: UpdateSafetyDto,
}

impl PackagingProofDto {
    pub fn new(parts: PackagingProofDtoParts) -> Self {
        Self {
            distribution_channel: parts.distribution_channel,
            package_mode: parts.package_mode,
            sandboxed: parts.sandboxed,
            signed_build: parts.signed_build,
            debug_build: parts.debug_build,
            scanner_process: parts.scanner_process,
            limitations: parts.limitations,
            update_safety: parts.update_safety,
        }
    }

    pub const fn distribution_channel(&self) -> DistributionChannelDto {
        self.distribution_channel
    }

    pub const fn package_mode(&self) -> PackageModeDto {
        self.package_mode
    }

    pub const fn signed_build(&self) -> bool {
        self.signed_build
    }

    pub const fn debug_build(&self) -> bool {
        self.debug_build
    }

    pub const fn sandboxed(&self) -> bool {
        self.sandboxed
    }

    pub const fn scanner_process(&self) -> ScannerProcessKindDto {
        self.scanner_process
    }

    pub fn limitations(&self) -> &[String] {
        &self.limitations
    }

    pub const fn update_safety(&self) -> &UpdateSafetyDto {
        &self.update_safety
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct PermissionProbeRequestDto {
    protocol_version: ProtocolVersionDto,
    target: ScanTargetDto,
}

impl PermissionProbeRequestDto {
    pub const fn new(protocol_version: ProtocolVersionDto, target: ScanTargetDto) -> Self {
        Self {
            protocol_version,
            target,
        }
    }

    pub const fn protocol_version(&self) -> ProtocolVersionDto {
        self.protocol_version
    }

    pub const fn target(&self) -> &ScanTargetDto {
        &self.target
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ScannerCapabilityDto {
    backend_name: String,
    capabilities: CapabilitySetDto,
}

impl ScannerCapabilityDto {
    pub fn new(backend_name: impl Into<String>, capabilities: CapabilitySetDto) -> Self {
        Self {
            backend_name: backend_name.into(),
            capabilities,
        }
    }

    pub fn backend_name(&self) -> &str {
        &self.backend_name
    }

    pub const fn capabilities(&self) -> &CapabilitySetDto {
        &self.capabilities
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ScannerIdentityProofDto {
    platform: RuntimePlatformDto,
    process_kind: ScannerProcessKindDto,
    verification: ScannerIdentityVerificationDto,
    executable_path: Option<RawPathDto>,
    bundle_identifier: Option<String>,
}

impl ScannerIdentityProofDto {
    pub fn new(
        platform: RuntimePlatformDto,
        process_kind: ScannerProcessKindDto,
        verification: ScannerIdentityVerificationDto,
        executable_path: Option<RawPathDto>,
        bundle_identifier: Option<String>,
    ) -> Self {
        Self {
            platform,
            process_kind,
            verification,
            executable_path,
            bundle_identifier,
        }
    }

    pub const fn platform(&self) -> RuntimePlatformDto {
        self.platform
    }

    pub const fn process_kind(&self) -> ScannerProcessKindDto {
        self.process_kind
    }

    pub const fn verification(&self) -> ScannerIdentityVerificationDto {
        self.verification
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct PermissionProbeDto {
    status: PermissionProbeStatusDto,
    checked_at_unix_ms: Option<DecimalU128Dto>,
    required_action: PermissionRequiredActionDto,
}

impl PermissionProbeDto {
    pub const fn new(
        status: PermissionProbeStatusDto,
        checked_at_unix_ms: Option<DecimalU128Dto>,
        required_action: PermissionRequiredActionDto,
    ) -> Self {
        Self {
            status,
            checked_at_unix_ms,
            required_action,
        }
    }

    pub const fn status(&self) -> PermissionProbeStatusDto {
        self.status
    }

    pub const fn checked_at_unix_ms(&self) -> Option<&DecimalU128Dto> {
        self.checked_at_unix_ms.as_ref()
    }

    pub const fn required_action(&self) -> PermissionRequiredActionDto {
        self.required_action
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct RuntimeProofDto {
    scanner_identity: ScannerIdentityProofDto,
    permission_probe: PermissionProbeDto,
    packaging: PackagingProofDto,
}

impl RuntimeProofDto {
    pub fn new(
        scanner_identity: ScannerIdentityProofDto,
        permission_probe: PermissionProbeDto,
        packaging: PackagingProofDto,
    ) -> Self {
        Self {
            scanner_identity,
            permission_probe,
            packaging,
        }
    }

    pub const fn scanner_identity(&self) -> &ScannerIdentityProofDto {
        &self.scanner_identity
    }

    pub const fn permission_probe(&self) -> &PermissionProbeDto {
        &self.permission_probe
    }

    pub const fn packaging(&self) -> &PackagingProofDto {
        &self.packaging
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ProtocolLimitDto {
    max_page_size: DecimalUsizeDto,
    max_event_queue_items: DecimalUsizeDto,
}

impl ProtocolLimitDto {
    pub fn new(max_page_size: DecimalUsizeDto, max_event_queue_items: DecimalUsizeDto) -> Self {
        Self {
            max_page_size,
            max_event_queue_items,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CapabilityResponseDto {
    protocol_version: ProtocolVersionDto,
    scanner: ScannerCapabilityDto,
    limits: ProtocolLimitDto,
    runtime_proof: RuntimeProofDto,
}

impl CapabilityResponseDto {
    pub const fn new(
        protocol_version: ProtocolVersionDto,
        scanner: ScannerCapabilityDto,
        limits: ProtocolLimitDto,
        runtime_proof: RuntimeProofDto,
    ) -> Self {
        Self {
            protocol_version,
            scanner,
            limits,
            runtime_proof,
        }
    }

    pub const fn runtime_proof(&self) -> &RuntimeProofDto {
        &self.runtime_proof
    }
}
