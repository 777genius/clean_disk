use crate::{
    CancelScanRequestDto, CapabilityResponseDto, ChildrenPageRequestDto, CleanupPlanDto,
    CleanupReceiptDto, CleanupRecoveryInboxDto, CreateCleanupPlanRequestDto, DaemonDiagnosticsDto,
    DisposeScanSessionRequestDto, ExecuteCleanupPlanRequestDto, NodeDetailsRequestDto,
    NodeDetailsResponseDto, NodePageResponseDto, ScanEventEnvelopeDto, ScanSessionStatusDto,
    SearchPageRequestDto, StartScanRequestDto, TopItemsRequestDto,
};
use schemars::{JsonSchema, Schema, schema_for};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ProtocolSchemaRootDto {
    capability_response: CapabilityResponseDto,
    daemon_diagnostics: DaemonDiagnosticsDto,
    start_scan_request: StartScanRequestDto,
    cancel_scan_request: CancelScanRequestDto,
    dispose_scan_session_request: DisposeScanSessionRequestDto,
    scan_session_status: ScanSessionStatusDto,
    scan_event_envelope: ScanEventEnvelopeDto,
    children_page_request: ChildrenPageRequestDto,
    search_page_request: SearchPageRequestDto,
    top_items_request: TopItemsRequestDto,
    node_page_response: NodePageResponseDto,
    node_details_request: NodeDetailsRequestDto,
    node_details_response: NodeDetailsResponseDto,
    create_cleanup_plan_request: CreateCleanupPlanRequestDto,
    execute_cleanup_plan_request: ExecuteCleanupPlanRequestDto,
    cleanup_plan: CleanupPlanDto,
    cleanup_receipt: CleanupReceiptDto,
    cleanup_recovery_inbox: CleanupRecoveryInboxDto,
}

pub fn protocol_schema() -> Schema {
    schema_for!(ProtocolSchemaRootDto)
}
