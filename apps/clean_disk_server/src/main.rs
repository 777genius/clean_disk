#![forbid(unsafe_code)]

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut args = std::env::args().skip(1);
    match args.next().as_deref() {
        Some("--scan-only-packaging-smoke") => {
            let report = clean_disk_server::scan_only_packaging_smoke_report();
            if report.passed() {
                println!("scan-only packaging smoke: passed");
                return Ok(());
            }

            eprintln!("scan-only packaging smoke: failed");
            for failure in report.failures() {
                eprintln!("- {}", failure.code());
            }
            std::process::exit(1);
        }
        Some("--help") | Some("-h") => {
            println!("clean-disk-server");
            println!("  --scan-only-packaging-smoke  Validate scan-only packaging proof and exit");
            return Ok(());
        }
        Some(argument) => {
            return Err(format!("unknown argument: {argument}").into());
        }
        None => {}
    }

    let state = clean_disk_server::AppState::production()?;
    println!(
        "clean-disk-server listening on {} with protocol {}.{}",
        state.config().bind_addr(),
        clean_disk_protocol::PROTOCOL_VERSION.major(),
        clean_disk_protocol::PROTOCOL_VERSION.minor()
    );
    clean_disk_server::run_server(state).await?;
    Ok(())
}
