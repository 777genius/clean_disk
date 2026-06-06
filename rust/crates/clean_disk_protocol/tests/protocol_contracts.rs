use clean_disk_protocol::{
    BoundaryPolicyDto, ChildCompletenessDto, DaemonDiagnosticsDto, DecimalU64Dto, DecimalU128Dto,
    DecimalUsizeDto, HardlinkPolicyDto, MeasuredQuantityDto, MeasuredQuantityResponseDto,
    NodeFlagsDto, NodeKindDto, NodePageItemDto, PROTOCOL_VERSION, PathPrivacyDto, RawPathDto,
    ScanEventDto, ScanModeDto, ScanProgressDto, ScanSessionStatusDto, ScanTargetDto,
    SearchPageRequestDto, SearchTextDto, SensitiveTextError, SessionStateDto, SizeConfidenceDto,
    SizeFactDto, StartScanRequestDto, TargetScopeDto, protocol_schema,
};
use serde_json::{Value, json};

#[test]
fn large_integer_fields_are_decimal_strings_for_flutter_web() {
    let size = SizeFactDto::new(
        DecimalU64Dto::from_u64(9_007_199_254_740_993),
        MeasuredQuantityResponseDto::ApparentBytes,
        Some(DecimalU64Dto::from_u64(9_007_199_254_740_993)),
        SizeConfidenceDto::High,
    );
    let item = NodePageItemDto::new(
        DecimalU64Dto::from_u64(9_007_199_254_740_993),
        None,
        "huge.bin",
        NodeKindDto::File,
        size,
        NodeFlagsDto::new(false, false, false, false),
        ChildCompletenessDto::Complete,
        DecimalUsizeDto::from_usize(0),
        DecimalUsizeDto::from_usize(0),
        DecimalUsizeDto::from_usize(0),
    );

    let value = serde_json::to_value(item).expect("json");

    assert_eq!(value["nodeId"], "9007199254740993");
    assert_eq!(value["size"]["rawValue"], "9007199254740993");
    assert_eq!(value["size"]["byteEquivalent"], "9007199254740993");
}

#[test]
fn large_integer_deserialization_rejects_json_numbers_and_invalid_strings() {
    assert!(serde_json::from_value::<DecimalU64Dto>(json!(42)).is_err());
    assert!(serde_json::from_value::<DecimalU64Dto>(json!("not-a-number")).is_err());
    assert!(serde_json::from_value::<DecimalU128Dto>(json!("")).is_err());
}

#[test]
fn response_unknown_values_degrade_to_unknown_variants() {
    let state =
        serde_json::from_value::<SessionStateDto>(json!("paused_by_future_daemon")).expect("state");
    let kind = serde_json::from_value::<NodeKindDto>(json!("future_node_kind")).expect("kind");
    let event = serde_json::from_value::<ScanEventDto>(json!({
        "type": "future_event",
        "payload": "ignored"
    }))
    .expect("event");

    assert_eq!(state, SessionStateDto::Unknown);
    assert_eq!(kind, NodeKindDto::Unrecognized);
    assert_eq!(event, ScanEventDto::Unknown);
}

#[test]
fn command_unknown_values_fail_closed() {
    let request = json!({
        "protocolVersion": { "major": 0, "minor": 2 },
        "commandId": "1",
        "targets": [{
            "path": "/Users/belief/Downloads",
            "scope": "local_path",
            "boundaryPolicy": "cross_filesystems",
            "hardlinkPolicy": "ignore"
        }],
        "measurement": "exclusive_reclaim_bytes",
        "mode": "balanced"
    });

    assert!(serde_json::from_value::<StartScanRequestDto>(request).is_err());
}

#[test]
fn sensitive_command_values_are_redacted_in_debug_output() {
    let raw_path = RawPathDto::new("/Users/belief/Downloads/private").expect("path");
    let target = ScanTargetDto::new(
        raw_path,
        TargetScopeDto::LocalPath,
        BoundaryPolicyDto::CrossFilesystems,
        HardlinkPolicyDto::Ignore,
    );
    let request = StartScanRequestDto::new(
        PROTOCOL_VERSION,
        DecimalU128Dto::from_u128(1),
        vec![target],
        MeasuredQuantityDto::ApparentBytes,
        ScanModeDto::Balanced,
    );
    let search = SearchPageRequestDto::new(
        DecimalU128Dto::from_u128(1),
        SearchTextDto::new("secret-file-name").expect("search"),
        None,
        DecimalUsizeDto::from_usize(25),
    );

    let request_debug = format!("{request:?}");
    let search_debug = format!("{search:?}");

    assert!(!request_debug.contains("/Users/belief"));
    assert!(request_debug.contains("<redacted>"));
    assert!(!search_debug.contains("secret-file-name"));
    assert!(search_debug.contains("<redacted>"));
}

#[test]
fn sensitive_text_rejects_empty_values() {
    assert_eq!(
        RawPathDto::new("   ").expect_err("empty path"),
        SensitiveTextError::Empty
    );
    assert_eq!(
        SearchTextDto::new("").expect_err("empty search"),
        SensitiveTextError::Empty
    );
}

#[test]
fn schema_generation_covers_protocol_root() {
    let schema = protocol_schema();
    let value = serde_json::to_value(schema).expect("schema json");
    let schema_text = serde_json::to_string(&value).expect("schema text");

    assert!(schema_text.contains("startScanRequest"));
    assert!(schema_text.contains("daemonDiagnostics"));
    assert!(schema_text.contains("scanEventEnvelope"));
    assert!(schema_text.contains("nodePageResponse"));
}

#[test]
fn diagnostics_dto_contains_only_low_cardinality_redacted_fields() {
    let diagnostics = DaemonDiagnosticsDto::new(
        PROTOCOL_VERSION,
        DecimalUsizeDto::from_usize(2),
        DecimalUsizeDto::from_usize(1),
        DecimalUsizeDto::from_usize(1),
        DecimalUsizeDto::from_usize(0),
        DecimalUsizeDto::from_usize(8),
        DecimalUsizeDto::from_usize(3),
        true,
    );
    let value = serde_json::to_value(&diagnostics).expect("diagnostics json");
    let text = serde_json::to_string(&value).expect("diagnostics text");

    assert_eq!(value["activeSessions"], "2");
    assert_eq!(value["storedCursors"], "3");
    assert!(diagnostics.auth_required());
    assert!(!text.contains("token"));
    assert!(!text.contains("/Users/"));
}

#[test]
fn protocol_crate_has_no_domain_engine_pdu_or_server_dependency() {
    let manifest = std::fs::read_to_string("Cargo.toml").expect("manifest");
    for forbidden in [
        "fs_usage_core",
        "fs_usage_engine",
        "fs_usage_pdu",
        "fs_usage_platform",
        "clean-disk-server",
        "parallel-disk-usage",
        "tokio",
        "flutter",
    ] {
        assert!(
            !manifest.contains(forbidden),
            "protocol crate must not depend on {forbidden}"
        );
    }
}

#[test]
fn display_path_debug_redacts_even_when_privacy_is_raw() {
    let path = clean_disk_protocol::DisplayPathDto::new(
        "/Users/belief/Library/Caches",
        PathPrivacyDto::Raw,
    );
    let debug = format!("{path:?}");

    assert!(!debug.contains("/Users/belief"));
    assert!(debug.contains("<redacted>"));
}

#[test]
fn progress_numbers_remain_decimal_strings_in_events() {
    let event = ScanEventDto::Progress {
        session_id: DecimalU128Dto::from_u128(42),
        progress: ScanProgressDto::new(
            DecimalU64Dto::from_u64(9_007_199_254_740_993),
            Some(DecimalU64Dto::from_u64(123)),
            None,
        ),
    };

    let value = serde_json::to_value(event).expect("event json");

    assert_eq!(value["sessionId"], Value::String("42".to_string()));
    assert_eq!(
        value["progress"]["scannedItems"],
        Value::String("9007199254740993".to_string())
    );
}

#[test]
fn session_status_exposes_root_node_ids_as_decimal_strings() {
    let status = ScanSessionStatusDto::new(
        DecimalU128Dto::from_u128(42),
        SessionStateDto::Completed,
        Some(DecimalU128Dto::from_u128(9)),
        vec![
            DecimalU64Dto::from_u64(1),
            DecimalU64Dto::from_u64(u64::MAX),
        ],
        None,
    );

    let value = serde_json::to_value(status).expect("status json");

    assert_eq!(value["rootNodeIds"][0], Value::String("1".to_string()));
    assert_eq!(
        value["rootNodeIds"][1],
        Value::String("18446744073709551615".to_string())
    );
}
