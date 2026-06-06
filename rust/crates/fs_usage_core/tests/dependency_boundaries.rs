#[test]
fn core_manifest_has_no_adapter_or_runtime_dependencies() {
    let manifest = std::fs::read_to_string(format!("{}/Cargo.toml", env!("CARGO_MANIFEST_DIR")))
        .expect("read Cargo.toml");

    for forbidden in [
        "parallel-disk-usage",
        "tokio",
        "clean_disk_protocol",
        "clean-disk-server",
        "fs_usage_engine",
        "fs_usage_platform",
        "fs_usage_pdu",
    ] {
        assert!(
            !manifest.contains(forbidden),
            "fs_usage_core must not depend on {forbidden}"
        );
    }
}
