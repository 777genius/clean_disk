use axum::{
    Router,
    body::{Body, to_bytes},
    http::{Request, StatusCode},
};
use clean_disk_protocol::{
    BoundaryPolicyDto, CancelScanRequestDto, CapabilityResponseDto, ChildSortDto,
    ChildrenPageRequestDto, DaemonDiagnosticsDto, DecimalU64Dto, DecimalU128Dto, DecimalUsizeDto,
    DisposeScanSessionRequestDto, DistributionChannelDto, HardlinkPolicyDto, MeasuredQuantityDto,
    NodeDetailsRequestDto, NodeDetailsResponseDto, NodePageResponseDto, OpaqueCursorDto,
    PROTOCOL_VERSION, PackageModeDto, PermissionProbeDto, PermissionProbeRequestDto,
    PermissionProbeStatusDto, PermissionRequiredActionDto, ProtocolVersionDto, RawPathDto,
    ScanModeDto, ScanSessionStatusDto, ScanTargetDto, ScannerIdentityVerificationDto,
    SearchPageRequestDto, SearchTextDto, SessionStateDto, StartScanRequestDto, TargetScopeDto,
    TopItemsKindDto, TopItemsRequestDto,
};
use clean_disk_server::{AppState, ServerConfig, build_router};
use fs_usage_engine::{FakeScannerBackend, ScanResourceProfile, WorkerBudget};
use serde::de::DeserializeOwned;
use std::{env, num::NonZeroUsize, sync::Arc};
use tokio::time::{Duration, sleep};
use tower::ServiceExt;

const SAMPLE_SCAN_COMPLETION_POLLS: usize = 100;
const SAMPLE_SCAN_COMPLETION_DELAY: Duration = Duration::from_millis(10);

fn test_state() -> AppState {
    AppState::new(
        ServerConfig::local_default().with_auth_token("test-token"),
        Arc::new(FakeScannerBackend::sample()),
        WorkerBudget::for_profile_with_parallelism(
            ScanResourceProfile::Balanced,
            NonZeroUsize::new(4).expect("cores"),
        ),
    )
}

fn authorized_request(method: &str, uri: &str, body: Body) -> Request<Body> {
    Request::builder()
        .method(method)
        .uri(uri)
        .header("authorization", "Bearer test-token")
        .header("content-type", "application/json")
        .body(body)
        .expect("request")
}

async fn decode_json<T: DeserializeOwned>(response: axum::response::Response) -> T {
    let bytes = to_bytes(response.into_body(), usize::MAX)
        .await
        .expect("body");
    serde_json::from_slice(&bytes).expect("json body")
}

async fn start_sample_scan(app: &Router) -> ScanSessionStatusDto {
    start_sample_scan_with_expected_session(app, 1).await
}

async fn start_sample_scan_with_expected_session(
    app: &Router,
    expected_session_id: u128,
) -> ScanSessionStatusDto {
    let request = StartScanRequestDto::new(
        PROTOCOL_VERSION,
        DecimalU128Dto::from_u128(1),
        vec![ScanTargetDto::new(
            RawPathDto::new("/tmp").expect("path"),
            TargetScopeDto::LocalPath,
            BoundaryPolicyDto::CrossFilesystems,
            HardlinkPolicyDto::Ignore,
        )],
        MeasuredQuantityDto::ApparentBytes,
        ScanModeDto::Balanced,
    );
    let body = Body::from(serde_json::to_vec(&request).expect("json"));

    let response = app
        .clone()
        .oneshot(authorized_request("POST", "/v1/scans", body))
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::ACCEPTED);
    let mut final_status: ScanSessionStatusDto = decode_json(response).await;
    assert_eq!(final_status.session_id().to_u128(), expected_session_id);

    for _ in 0..SAMPLE_SCAN_COMPLETION_POLLS {
        sleep(SAMPLE_SCAN_COMPLETION_DELAY).await;
        let response = app
            .clone()
            .oneshot(authorized_request(
                "GET",
                &format!("/v1/scans/{expected_session_id}"),
                Body::empty(),
            ))
            .await
            .expect("response");
        assert_eq!(response.status(), StatusCode::OK);
        final_status = decode_json(response).await;
        if final_status.state() == SessionStateDto::Completed {
            break;
        }
    }

    assert_eq!(final_status.state(), SessionStateDto::Completed);
    final_status
}

#[tokio::test]
async fn capability_endpoint_requires_local_bearer_token() {
    let app = build_router(test_state());

    let response = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/v1/capabilities")
                .body(Body::empty())
                .expect("request"),
        )
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);

    let response = app
        .oneshot(authorized_request("GET", "/v1/capabilities", Body::empty()))
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::OK);
}

#[tokio::test]
async fn capability_endpoint_reports_unverified_runtime_proof_until_probe_runs() {
    let app = build_router(test_state());

    let response = app
        .oneshot(authorized_request("GET", "/v1/capabilities", Body::empty()))
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::OK);
    let capabilities: CapabilityResponseDto = decode_json(response).await;

    assert_eq!(
        capabilities
            .runtime_proof()
            .scanner_identity()
            .verification(),
        ScannerIdentityVerificationDto::Unverified
    );
    assert_eq!(
        capabilities.runtime_proof().permission_probe().status(),
        PermissionProbeStatusDto::NotProbed
    );
    assert_eq!(
        capabilities
            .runtime_proof()
            .packaging()
            .distribution_channel(),
        DistributionChannelDto::Development
    );
    assert_eq!(
        capabilities.runtime_proof().packaging().package_mode(),
        PackageModeDto::DevelopmentShell
    );
    assert!(!capabilities.runtime_proof().packaging().signed_build());
    assert!(
        capabilities
            .runtime_proof()
            .packaging()
            .limitations()
            .iter()
            .any(|limitation| limitation == "unsigned_build")
    );
    assert!(
        capabilities
            .runtime_proof()
            .packaging()
            .update_safety()
            .quiesce_required_before_update()
    );
}

#[tokio::test]
async fn permission_probe_runs_under_authorized_scanner_process() {
    let app = build_router(test_state());
    let temp_dir = env::temp_dir().to_string_lossy().into_owned();
    let request = PermissionProbeRequestDto::new(
        PROTOCOL_VERSION,
        ScanTargetDto::new(
            RawPathDto::new(temp_dir).expect("path"),
            TargetScopeDto::LocalPath,
            BoundaryPolicyDto::StayOnInitialFilesystem,
            HardlinkPolicyDto::Ignore,
        ),
    );
    let body = Body::from(serde_json::to_vec(&request).expect("json"));

    let response = app
        .oneshot(authorized_request("POST", "/v1/permission-probe", body))
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::OK);
    let probe: PermissionProbeDto = decode_json(response).await;

    assert_eq!(probe.status(), PermissionProbeStatusDto::Verified);
    assert_eq!(probe.required_action(), PermissionRequiredActionDto::None);
    assert!(probe.checked_at_unix_ms().is_some());
}

#[tokio::test]
async fn start_scan_returns_session_and_status_query_recovers_authoritative_state() {
    let app = build_router(test_state());
    let status = start_sample_scan(&app).await;
    assert_eq!(status.session_id().to_u128(), 1);
    assert_eq!(status.snapshot_id().expect("snapshot id").to_u128(), 1);
}

#[tokio::test]
async fn start_scan_rejects_empty_targets_before_session_execution() {
    let app = build_router(test_state());
    let request = StartScanRequestDto::new(
        PROTOCOL_VERSION,
        DecimalU128Dto::from_u128(1),
        Vec::new(),
        MeasuredQuantityDto::ApparentBytes,
        ScanModeDto::Balanced,
    );

    let response = app
        .clone()
        .oneshot(authorized_request(
            "POST",
            "/v1/scans",
            Body::from(serde_json::to_vec(&request).expect("json")),
        ))
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);

    let response = app
        .oneshot(authorized_request("GET", "/v1/diagnostics", Body::empty()))
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::OK);
    let diagnostics: DaemonDiagnosticsDto = decode_json(response).await;
    assert_eq!(diagnostics.active_sessions().to_usize(), 0);
}

#[tokio::test]
async fn read_query_routes_page_search_top_and_detail_completed_snapshots() {
    let app = build_router(test_state());
    let status = start_sample_scan(&app).await;
    let snapshot_id = status.snapshot_id().expect("snapshot id").clone();

    let first_children = ChildrenPageRequestDto::new(
        snapshot_id.clone(),
        DecimalU64Dto::from_u64(1),
        None,
        DecimalUsizeDto::from_usize(1),
        ChildSortDto::NameAsc,
    );
    let response = app
        .clone()
        .oneshot(authorized_request(
            "POST",
            "/v1/scans/1/children",
            Body::from(serde_json::to_vec(&first_children).expect("json")),
        ))
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::OK);
    let first_page: NodePageResponseDto = decode_json(response).await;
    assert_eq!(first_page.snapshot_id().to_u128(), 1);
    assert_eq!(first_page.items().len(), 1);
    assert_eq!(first_page.items()[0].name(), "alpha.log");
    let next_cursor = first_page.next_cursor().expect("next cursor").clone();

    let second_children = ChildrenPageRequestDto::new(
        snapshot_id.clone(),
        DecimalU64Dto::from_u64(1),
        Some(next_cursor),
        DecimalUsizeDto::from_usize(1),
        ChildSortDto::NameAsc,
    );
    let response = app
        .clone()
        .oneshot(authorized_request(
            "POST",
            "/v1/scans/1/children",
            Body::from(serde_json::to_vec(&second_children).expect("json")),
        ))
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::OK);
    let second_page: NodePageResponseDto = decode_json(response).await;
    assert_eq!(second_page.items().len(), 1);
    assert_eq!(second_page.items()[0].name(), "beta.cache");
    assert!(second_page.next_cursor().is_none());

    let search = SearchPageRequestDto::new(
        snapshot_id.clone(),
        SearchTextDto::new("beta").expect("search text"),
        None,
        DecimalUsizeDto::from_usize(10),
    );
    let response = app
        .clone()
        .oneshot(authorized_request(
            "POST",
            "/v1/scans/1/search",
            Body::from(serde_json::to_vec(&search).expect("json")),
        ))
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::OK);
    let search_page: NodePageResponseDto = decode_json(response).await;
    assert_eq!(search_page.items().len(), 1);
    assert_eq!(search_page.items()[0].name(), "beta.cache");

    let top = TopItemsRequestDto::new(
        snapshot_id.clone(),
        TopItemsKindDto::Files,
        None,
        DecimalUsizeDto::from_usize(2),
    );
    let response = app
        .clone()
        .oneshot(authorized_request(
            "POST",
            "/v1/scans/1/top",
            Body::from(serde_json::to_vec(&top).expect("json")),
        ))
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::OK);
    let top_page: NodePageResponseDto = decode_json(response).await;
    assert_eq!(top_page.items().len(), 2);
    assert_eq!(top_page.items()[0].name(), "beta.cache");
    assert_eq!(top_page.items()[1].name(), "alpha.log");

    let details = NodeDetailsRequestDto::new(snapshot_id, DecimalU64Dto::from_u64(1));
    let response = app
        .oneshot(authorized_request(
            "POST",
            "/v1/scans/1/details",
            Body::from(serde_json::to_vec(&details).expect("json")),
        ))
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::OK);
    let details: NodeDetailsResponseDto = decode_json(response).await;
    assert_eq!(details.summary().name(), "root");
    assert_eq!(details.child_ids().len(), 2);
}

#[tokio::test]
async fn read_query_routes_reject_unknown_opaque_cursor() {
    let app = build_router(test_state());
    let status = start_sample_scan(&app).await;
    let snapshot_id = status.snapshot_id().expect("snapshot id").clone();
    let request = ChildrenPageRequestDto::new(
        snapshot_id,
        DecimalU64Dto::from_u64(1),
        Some(OpaqueCursorDto::new("missing-cursor").expect("cursor")),
        DecimalUsizeDto::from_usize(1),
        ChildSortDto::Insertion,
    );

    let response = app
        .oneshot(authorized_request(
            "POST",
            "/v1/scans/1/children",
            Body::from(serde_json::to_vec(&request).expect("json")),
        ))
        .await
        .expect("response");

    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn read_query_routes_reject_cursor_from_another_session() {
    let app = build_router(test_state());
    let first_status = start_sample_scan_with_expected_session(&app, 1).await;
    let first_snapshot_id = first_status.snapshot_id().expect("snapshot id").clone();

    let first_children = ChildrenPageRequestDto::new(
        first_snapshot_id,
        DecimalU64Dto::from_u64(1),
        None,
        DecimalUsizeDto::from_usize(1),
        ChildSortDto::NameAsc,
    );
    let response = app
        .clone()
        .oneshot(authorized_request(
            "POST",
            "/v1/scans/1/children",
            Body::from(serde_json::to_vec(&first_children).expect("json")),
        ))
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::OK);
    let first_page: NodePageResponseDto = decode_json(response).await;
    let foreign_cursor = first_page.next_cursor().expect("next cursor").clone();

    let second_status = start_sample_scan_with_expected_session(&app, 2).await;
    let second_snapshot_id = second_status.snapshot_id().expect("snapshot id").clone();
    let second_children = ChildrenPageRequestDto::new(
        second_snapshot_id,
        DecimalU64Dto::from_u64(1),
        Some(foreign_cursor),
        DecimalUsizeDto::from_usize(1),
        ChildSortDto::NameAsc,
    );

    let response = app
        .oneshot(authorized_request(
            "POST",
            "/v1/scans/2/children",
            Body::from(serde_json::to_vec(&second_children).expect("json")),
        ))
        .await
        .expect("response");

    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn dispose_scan_releases_session_and_its_cursors() {
    let app = build_router(test_state());
    let status = start_sample_scan(&app).await;
    let snapshot_id = status.snapshot_id().expect("snapshot id").clone();
    let children = ChildrenPageRequestDto::new(
        snapshot_id,
        DecimalU64Dto::from_u64(1),
        None,
        DecimalUsizeDto::from_usize(1),
        ChildSortDto::NameAsc,
    );
    let response = app
        .clone()
        .oneshot(authorized_request(
            "POST",
            "/v1/scans/1/children",
            Body::from(serde_json::to_vec(&children).expect("json")),
        ))
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::OK);
    let page: NodePageResponseDto = decode_json(response).await;
    assert!(page.next_cursor().is_some());

    let dispose = DisposeScanSessionRequestDto::new(
        PROTOCOL_VERSION,
        DecimalU128Dto::from_u128(3),
        DecimalU128Dto::from_u128(1),
    );
    let response = app
        .clone()
        .oneshot(authorized_request(
            "POST",
            "/v1/scans/1/dispose",
            Body::from(serde_json::to_vec(&dispose).expect("json")),
        ))
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::NO_CONTENT);

    let response = app
        .clone()
        .oneshot(authorized_request("GET", "/v1/scans/1", Body::empty()))
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::NOT_FOUND);

    let response = app
        .oneshot(authorized_request("GET", "/v1/diagnostics", Body::empty()))
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::OK);
    let diagnostics: DaemonDiagnosticsDto = decode_json(response).await;
    assert_eq!(diagnostics.active_sessions().to_usize(), 0);
    assert_eq!(diagnostics.stored_cursors().to_usize(), 0);
}

#[tokio::test]
async fn diagnostics_endpoint_is_authorized_and_redacted() {
    let app = build_router(test_state());
    let response = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/v1/diagnostics")
                .body(Body::empty())
                .expect("request"),
        )
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);

    let status = start_sample_scan(&app).await;
    let snapshot_id = status.snapshot_id().expect("snapshot id").clone();
    let children = ChildrenPageRequestDto::new(
        snapshot_id,
        DecimalU64Dto::from_u64(1),
        None,
        DecimalUsizeDto::from_usize(1),
        ChildSortDto::NameAsc,
    );
    let response = app
        .clone()
        .oneshot(authorized_request(
            "POST",
            "/v1/scans/1/children",
            Body::from(serde_json::to_vec(&children).expect("json")),
        ))
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::OK);

    let response = app
        .oneshot(authorized_request("GET", "/v1/diagnostics", Body::empty()))
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::OK);
    let diagnostics: DaemonDiagnosticsDto = decode_json(response).await;
    assert_eq!(diagnostics.active_sessions().to_usize(), 1);
    assert_eq!(diagnostics.completed_sessions().to_usize(), 1);
    assert_eq!(diagnostics.stored_cursors().to_usize(), 1);
    assert!(diagnostics.auth_required());

    let debug = format!("{diagnostics:?}");
    assert!(!debug.contains("test-token"));
    assert!(!debug.contains("/tmp"));
}

#[tokio::test]
async fn origin_policy_rejects_non_local_browser_origins() {
    let app = build_router(test_state());

    let response = app
        .oneshot(
            Request::builder()
                .uri("/v1/capabilities")
                .header("authorization", "Bearer test-token")
                .header("origin", "https://evil.example")
                .body(Body::empty())
                .expect("request"),
        )
        .await
        .expect("response");

    assert_eq!(response.status(), StatusCode::FORBIDDEN);

    let app = build_router(test_state());
    let response = app
        .oneshot(
            Request::builder()
                .uri("/v1/capabilities")
                .header("authorization", "Bearer test-token")
                .header("origin", "http://localhost.evil.example")
                .body(Body::empty())
                .expect("request"),
        )
        .await
        .expect("response");

    assert_eq!(response.status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn cancel_scan_rejects_incompatible_protocol_version() {
    let app = build_router(test_state());
    let request = CancelScanRequestDto::new(
        ProtocolVersionDto::new(99, 0),
        DecimalU128Dto::from_u128(2),
        DecimalU128Dto::from_u128(1),
    );
    let body = Body::from(serde_json::to_vec(&request).expect("json"));

    let response = app
        .oneshot(authorized_request("POST", "/v1/scans/1/cancel", body))
        .await
        .expect("response");

    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn cancel_completed_scan_does_not_mark_cancel_requested() {
    let app = build_router(test_state());
    start_sample_scan(&app).await;
    let request = CancelScanRequestDto::new(
        PROTOCOL_VERSION,
        DecimalU128Dto::from_u128(4),
        DecimalU128Dto::from_u128(1),
    );
    let response = app
        .clone()
        .oneshot(authorized_request(
            "POST",
            "/v1/scans/1/cancel",
            Body::from(serde_json::to_vec(&request).expect("json")),
        ))
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::OK);

    let response = app
        .oneshot(authorized_request("GET", "/v1/diagnostics", Body::empty()))
        .await
        .expect("response");
    assert_eq!(response.status(), StatusCode::OK);
    let diagnostics: DaemonDiagnosticsDto = decode_json(response).await;
    assert_eq!(diagnostics.cancel_requested_sessions().to_usize(), 0);
}

#[test]
fn server_config_debug_redacts_local_auth_token() {
    let config = ServerConfig::local_default().with_auth_token("super-secret-token");
    let debug = format!("{config:?}");

    assert!(!debug.contains("super-secret-token"));
    assert!(debug.contains("<redacted>"));
}
