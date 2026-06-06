#[test]
fn engine_manifest_has_no_pdu_protocol_server_or_async_runtime_dependencies() {
    let manifest = std::fs::read_to_string(format!("{}/Cargo.toml", env!("CARGO_MANIFEST_DIR")))
        .expect("read Cargo.toml");

    for forbidden in [
        "parallel-disk-usage",
        "clean_disk_protocol",
        "clean-disk-server",
        "tokio",
        "axum",
        "flutter",
    ] {
        assert!(
            !manifest.contains(forbidden),
            "fs_usage_engine must not depend on {forbidden}"
        );
    }
}
