# Rust Architecture

Last updated: 2026-05-19.

This document records the accepted Rust architecture after the decision to build a reusable filesystem usage library first, and make Clean Disk the first production consumer of that library.

## Accepted Direction

Clean Disk uses three layers:

```text
1. Universal Rust library
   fs_usage_* crates for scan, indexing, metadata, accounting, and optional cleanup.

2. Clean Disk Rust host
   clean-disk-server process, config, auth, protocol, HTTP/WebSocket, and composition.

3. Flutter app
   apps/clean_disk and feature packages as UI/API clients, with no disk traversal logic.
```

The reusable Rust library must not know about Clean Disk, Flutter, HTTP, WebSocket, or the app visual model. Clean Disk depends on the library; the library does not depend on Clean Disk.

## Core Principles

- `pdu` is a scanner adapter, not the domain model.
- Production macOS scans must use a signed Clean Disk app component or bundled helper, not an external `pdu` binary.
- The reusable library owns scan sessions, node identity, query indexes, pagination, metadata enrichment, and capability reporting.
- Clean Disk server owns process lifecycle, auth, transport, protocol mapping, and concrete adapter wiring.
- Flutter owns UI state, user workflows, and presentation only.
- Rust owns the full scan tree and large indexes. Flutter receives pages, details, and event batches.
- Cleanup never trusts stale scan data. It must revalidate current path and identity before Trash/delete actions.
- Size, allocated size, and reclaim estimate are separate concepts.
- The Rust library can be reusable before it is public-stable. Do not promise semver stability externally until Clean Disk validates the API through real product flows.
- Clean Disk runs as one Rust daemon in local mode. Parallelism is implemented with an internal bounded worker pool, not local microservices.
- HTTP commands/queries plus plain WebSocket events are the first accepted transport. JSON-RPC, Socket.IO, gRPC, and gRPC-Web remain future adapter candidates only.
- On macOS, capability probing, scan traversal, metadata enrichment, and delete preflight must run under the same scanner process identity so TCC/Full Disk Access results match the real scanner.

## pdu Integration Coding Gate

Before writing the first production pdu adapter, read and follow:

- `docs/technical/pdu-clean-architecture-contract.md`
- `docs/technical/pre-coding-pdu-architecture-research.md`

Accepted first Rust slice:

1. `fs_usage_core` value objects and invariants - 🎯 9 🛡️ 10 🧠 5, roughly
   600-1200 LOC.
2. `fs_usage_engine` ports, session state, fake backend, and read-model
   contracts - 🎯 9 🛡️ 9 🧠 6, roughly 1200-2600 LOC.
3. `fs_usage_pdu` adapter behind `ScannerBackend` - 🎯 8 🛡️ 8 🧠 7, roughly
   1200-2500 LOC.

Hard boundary:

```text
pdu types stay in fs_usage_pdu.
fs_usage_core names product truth.
fs_usage_engine owns use cases and read models.
fs_usage_platform owns current OS authority.
clean-disk-server wires concrete adapters and transports.
```

Do not start with `parallel_disk_usage::DataTree` as the engine model. The pdu
tree is adapter evidence. The engine model is `ScanSnapshot`, `NodeArena`,
capabilities, issues, indexes, and paginated queries.

## Layer 1 - Universal Rust Library

The library family is provisionally named `fs_usage_*`. Final crate names can change before publishing, but the boundaries are accepted.

Target workspace shape:

```text
rust/
  crates/
    fs_usage_core/
    fs_usage_engine/
    fs_usage_pdu/
    fs_usage_platform/
    fs_usage_accounting/
    fs_usage_cleanup/
```

Do not create every crate and file upfront. Create crates when there is real implementation pressure. The boundaries below are the target architecture.

### `fs_usage_core`

Purpose: reusable domain language and validated value objects.

```text
rust/crates/fs_usage_core/
  Cargo.toml
  src/
    lib.rs
    id/
      mod.rs
      scan_session_id.rs
      node_id.rs
      operation_id.rs
    value/
      mod.rs
      byte_size.rs
      measured_quantity.rs
      numeric_evidence.rs
      measurement_policy.rs
      measured_fact.rs
      measurement_source.rs
      aggregate_size_evidence.rs
      own_size_evidence.rs
      visible_child_sum.rs
      size_fact_selector.rs
      size_display_policy.rs
      size_display_value.rs
      size_unit_semantics.rs
      item_count.rs
      percent.rs
      scan_path.rs
      path_segment_evidence.rs
      display_path.rs
      path_sort_key.rs
      path_encoding_state.rs
      display_safety.rs
      path_redaction_class.rs
      path_export_policy.rs
      path_authority_kind.rs
      timestamp.rs
      page_size.rs
      sort_policy.rs
      tie_breaker_policy.rs
      query_fingerprint.rs
      page_cursor.rs
      converter_depth_evidence.rs
      progress_confidence.rs
    model/
      mod.rs
      scan_target.rs
      target_overlap_policy.rs
      target_preflight_issue.rs
      target_identity_evidence.rs
      target_drift_state.rs
      synthetic_root_kind.rs
      target_authority_scope.rs
      scan_options.rs
      scan_status.rs
      scan_progress.rs
      scan_phase_progress.rs
      final_scan_summary.rs
      usage_node.rs
      usage_node_kind.rs
      link_kind.rs
      link_evidence.rs
      link_traversal_policy.rs
      boundary_policy.rs
      boundary_evidence.rs
      boundary_capability.rs
      boundary_decision.rs
      volume_scope.rs
      volume_identity.rs
      mount_class.rs
      node_identity.rs
      node_metadata.rs
      scan_capabilities.rs
      hardlink_capability.rs
      hardlink_identity_kind.rs
      diagnostic_snapshot_authority.rs
      diagnostic_provenance.rs
    accounting/
      mod.rs
      size_kind.rs
      reclaim_estimate.rs
      confidence.rs
      measured_size.rs
      child_completeness.rs
      hardlink_group_evidence.rs
      hardlink_summary_evidence.rs
      hardlink_scope.rs
      hardlink_confidence.rs
      hardlink_reclaim_policy.rs
    projection/
      mod.rs
      tree_projection_kind.rs
      child_materialization_state.rs
      projection_evidence.rs
    issue/
      mod.rs
      scan_issue_reason.rs
      scan_issue_severity.rs
      scan_quality.rs
      issue_path_scope.rs
      issue_attachment.rs
      issue_repair_class.rs
      issue_evidence_ref.rs
    warning/
      mod.rs
      warning_code.rs
      warning_severity.rs
    error/
      mod.rs
      fs_usage_error.rs
```

Rules:

- No `pdu`, no `tokio`, no HTTP/WebSocket, no Flutter, no Clean Disk protocol.
- Prefer Rust newtypes over raw strings and integers.
- Policies are pure rules only. No filesystem IO.
- Path value objects can normalize/compare display-safe values, encoding state,
  and authority class, but must not inspect the OS.
- Display paths are never cleanup authority. Destructive workflows use `NodeRef`
  plus current identity revalidation through platform ports.
- Display safety, redaction class, and export policy are explicit value objects.
  pdu `OsStringDisplay`/terminal output never proves UI/export safety.
- `PathSortKey` is product vocabulary. It is derived by engine policy and never
  by pdu `OsStringDisplay` ordering.
- `NodeIdentity` stores scan-time identity evidence needed for later revalidation.
- Link/reparse vocabulary such as `LinkKind`, `LinkEvidence`, and
  `LinkTraversalPolicy` is pure domain vocabulary. Actual OS classification
  belongs to platform adapters.
- Size value objects must distinguish aggregate measured size, own measured
  size, visible child sum, and reclaim/accounting estimates.
- Aggregate size, own size, and visible-child sum are separate evidence values.
  pdu `DataTree::dir` constructor semantics never become domain behavior.
- Numeric value objects must carry exactness/confidence so pdu `u64` values,
  progress counters, and formatted sizes never become product truth directly.
- Size display values are separate projections. pdu `BytesFormat`, visualizer
  strings, and rounded unit strings never become exact facts.
- Converter depth evidence is domain vocabulary. It records traversal/conversion
  safety without exposing pdu recursion or `DataTree` internals.
- Hardlink capability is domain vocabulary. It is not derived from pdu type
  names, Rust `cfg` flags, or platform guesses leaking into protocol.

### `fs_usage_engine`

Purpose: application/use-case layer, session lifecycle, read models, query indexes, and ports.

```text
rust/crates/fs_usage_engine/
  Cargo.toml
  src/
    lib.rs
    application/
      mod.rs
      target/
        mod.rs
        normalize_scan_targets.rs
        build_synthetic_root.rs
        target_preflight.rs
        target_overlap_detector.rs
        target_execution_plan.rs
        target_scan_outcome.rs
        target_outcome_aggregator.rs
        target_projection_policy.rs
        product_default_target_policy.rs
        target_canonicalization_evidence.rs
        target_authority_evidence.rs
        target_identity_envelope.rs
        target_drift_detector.rs
      command/
        mod.rs
        create_scan_session.rs
        start_scan.rs
        cancel_scan.rs
        dispose_scan_session.rs
      query/
        mod.rs
        get_scan_summary.rs
        get_children.rs
        get_top_items.rs
        get_node_details.rs
        search_nodes.rs
      dto/
        mod.rs
        page.rs
        sort.rs
        filters.rs
        scan_summary.rs
        tree_row.rs
        node_details.rs
        scan_issue.rs
        scan_quality.rs
      event/
        mod.rs
        scan_event.rs
        scan_event_batch.rs
        event_sequence.rs
      port/
        mod.rs
        scanner_backend.rs
        metadata_provider.rs
        identity_provider.rs
        accounting_provider.rs
        event_publisher.rs
        clock.rs
    read_model/
      mod.rs
      tree/
        mod.rs
        node_store.rs
        children_index.rs
      index/
        mod.rs
        top_index.rs
        search_index.rs
        sort_index.rs
        snapshot_order_index.rs
        stable_order_builder.rs
      pagination/
        mod.rs
        cursor.rs
        cursor_validator.rs
        page_builder.rs
    session/
      mod.rs
      scan_session.rs
      session_registry.rs
      session_lifecycle.rs
      cancellation_token.rs
      scan_phase.rs
      scan_phase_event.rs
      scan_phase_metrics.rs
    job/
      mod.rs
      scan_job.rs
      scan_scheduler.rs
      worker_pool.rs
      resource_profile.rs
      resource_budget.rs
      volume_budget.rs
      resource_decision_evidence.rs
      storage_hint_confidence.rs
      resource_downgrade_reason.rs
      storage_qos_policy.rs
      execution_budget.rs
      io_pressure_mode.rs
      progress_throttle.rs
    engine/
      mod.rs
      builder.rs
      fs_usage_engine.rs
```

Rules:

- Depends on `fs_usage_core`.
- Declares ports for scanners, metadata, identity, accounting, events, and clocks.
- Does not import `parallel_disk_usage`, platform Trash crates, HTTP/WebSocket libraries, or Clean Disk protocol.
- Commands mutate session lifecycle.
- Queries read Rust-owned indexes and return pages/projections.
- Event streams are throttled and batched. Never emit one UI event per filesystem entry.
- Search, sort, filter, top lists, and pagination happen in Rust.
- Query ordering is deterministic inside a snapshot and independent from pdu
  child order, pdu callback order, and pdu helper sorting.
- Parallel work is bounded and owned by `fs_usage_engine`, with explicit scan scheduling, cancellation, per-volume budget policy, and backend capability checks.
- Do not create worker processes or network services inside `fs_usage_engine`. If future distributed workers are needed, they are host-level adapters over the same engine contracts.
- Target normalization, duplicate handling, overlap policy, synthetic root
  creation, and target preflight diagnostics are application responsibilities,
  not pdu adapter behavior.
- Target identity is an envelope, not a pdu root path. Preflight identity,
  pdu traversal evidence, post-scan probe, and delete-time revalidation stay
  separate.

### `fs_usage_pdu`

Purpose: adapter from `parallel-disk-usage` into `fs_usage_engine` ports.

```text
rust/crates/fs_usage_pdu/
  Cargo.toml
  src/
    lib.rs
    adapter/
      mod.rs
      pdu_scanner_backend.rs
      pdu_execution_lane.rs
      pdu_rayon_pool_guard.rs
      pdu_lane_policy.rs
      pdu_nested_parallelism_guard.rs
      pdu_scan_runner.rs
      pdu_target_runner.rs
      pdu_options_mapper.rs
      pdu_cli_args_guard.rs
      pdu_raw_flag_rejection_guard.rs
      pdu_target_input_mapper.rs
      pdu_target_identity_boundary_guard.rs
      pdu_backend_capabilities.rs
      pdu_contract_fingerprint.rs
      pdu_sdk_boundary_matrix.rs
      pdu_toolchain_compatibility_guard.rs
      pdu_build_surface_guard.rs
      pdu_crate_root_guard.rs
      pdu_warning_policy_guard.rs
      pdu_target_api_surface_guard.rs
      pdu_target_cfg_probe.rs
      pdu_non_exhaustive_api_guard.rs
      pdu_api_evolution_mapper.rs
      pdu_feature_graph_guard.rs
      pdu_effective_dependency_graph.rs
      pdu_auxiliary_feature_guard.rs
      pdu_dependency_graph_fingerprint.rs
      pdu_import_allowlist.rs
      pdu_callback_policy.rs
      pdu_callback_state_guard.rs
      pdu_callback_evidence_sink.rs
      pdu_get_size_policy.rs
      pdu_measurement_profile_guard.rs
      pdu_aggregate_size_guard.rs
      pdu_raw_result.rs
      pdu_evidence_joiner.rs
      pdu_resultless_traversal_guard.rs
      pdu_raw_scan_metrics.rs
      pdu_memory_pressure_policy.rs
      pdu_wide_directory_evidence.rs
      pdu_wide_directory_observability_gap.rs
      pdu_memory_evidence_confidence_mapper.rs
      pdu_memory_budget_gate.rs
      pdu_lane_metrics.rs
      pdu_thread_budget_mapper.rs
      pdu_storage_hint_policy.rs
      pdu_mount_point_heuristic_guard.rs
      pdu_depth_risk.rs
      pdu_stored_depth_mapper.rs
      pdu_stored_depth_evidence.rs
      pdu_cancel_epoch.rs
      pdu_panic_boundary.rs
      pdu_projection_guard.rs
      pdu_datatree_helper_guard.rs
      pdu_datatree_helper_mutation_guard.rs
      pdu_reflection_validation_guard.rs
      pdu_cli_pipeline_guard.rs
      pdu_terminal_display_guard.rs
      pdu_status_side_effect_guard.rs
      pdu_multi_root_guard.rs
      pdu_treebuilder_boundary_guard.rs
      pdu_name_semantics_guard.rs
    evidence/
      mod.rs
      pdu_metadata_tap_recorder.rs
      pdu_metadata_tap_record.rs
      pdu_metadata_tap_summary.rs
      pdu_boundary_evidence_store.rs
      pdu_boundary_decision_evidence.rs
      pdu_same_device_observation.rs
      pdu_boundary_observability_summary.rs
      pdu_issue_evidence.rs
      pdu_io_error_evidence.rs
      pdu_issue_sample_policy.rs
      pdu_target_probe_evidence.rs
      pdu_tree_shape_anomaly_summary.rs
    mapper/
      mod.rs
      pdu_datatree_readonly_view.rs
      pdu_tree_converter.rs
      pdu_iterative_tree_converter.rs
      pdu_tree_converter_stack_guard.rs
      pdu_issue_mapper.rs
      pdu_issue_path_scope_mapper.rs
      pdu_issue_completeness_mapper.rs
      pdu_issue_attachment_mapper.rs
      pdu_traversal_outcome_mapper.rs
      pdu_io_error_kind_mapper.rs
      pdu_platform_error_facet_mapper.rs
      pdu_hardlink_mapper.rs
      pdu_size_facts_mapper.rs
      pdu_aggregate_size_mapper.rs
      pdu_measurement_policy_mapper.rs
      pdu_option_semantics_mapper.rs
      pdu_fraction_min_ratio_guard.rs
      pdu_get_size_mapper.rs
      pdu_get_size_purity_guard.rs
      pdu_measurement_evidence_mapper.rs
      pdu_unix_blocks_unit_mapper.rs
      pdu_unit_semantics_mapper.rs
      pdu_size_trait_boundary_mapper.rs
      pdu_size_display_guard.rs
      pdu_progress_snapshot_mapper.rs
      pdu_progress_counter_mapper.rs
      pdu_terminal_output_rejection_mapper.rs
      pdu_device_boundary_mapper.rs
      pdu_boundary_capability_mapper.rs
      pdu_boundary_skip_mapper.rs
      pdu_boundary_observability_guard.rs
      pdu_same_device_evidence_mapper.rs
      pdu_root_shape_mapper.rs
      pdu_metrics_mapper.rs
      pdu_child_materialization_mapper.rs
      pdu_metadata_tap_mapper.rs
      pdu_resource_mapper.rs
      pdu_storage_hint_mapper.rs
      pdu_path_evidence_mapper.rs
      pdu_name_kind_mapper.rs
      pdu_path_display_boundary_mapper.rs
    reporter/
      mod.rs
      pdu_reporter.rs
      pdu_reporter_lifecycle_guard.rs
      pdu_parallel_reporter_boundary_guard.rs
      pdu_reporter_snapshot.rs
      pdu_progress_snapshotter.rs
      pdu_progress_evidence_store.rs
      pdu_callback_overflow_counter.rs
      pdu_issue_sampler.rs
      pdu_event_buffer.rs
      pdu_reporter_backpressure_guard.rs
      pdu_event_sequence_bridge.rs
      pdu_reporter_panic_guard.rs
    hardlink/
      mod.rs
      clean_disk_hardlink_recorder.rs
      pdu_hardlink_evidence_store.rs
      pdu_hardlink_conflict_store.rs
      pdu_hardlink_observation_state.rs
      pdu_hardlink_identity_mapper.rs
      pdu_hardlink_group_mapper.rs
      pdu_hardlink_conflict_mapper.rs
      pdu_hardlink_summary_mapper.rs
      pdu_hardlink_scope_mapper.rs
      pdu_hardlink_dedup_projection_mapper.rs
      pdu_hardlink_dedup_guard.rs
      pdu_hardlink_dedup_arithmetic_guard.rs
      pdu_hardlink_prefix_projection_guard.rs
      pdu_platform_hardlink_capability.rs
      pdu_hardlink_capability_mapper.rs
    diagnostics/
      mod.rs
      pdu_json_fixture_codec.rs
      pdu_reflection_fixture_codec.rs
      pdu_json_import_guard.rs
      pdu_runtime_error_guard.rs
      pdu_cli_host_evidence.rs
      pdu_diagnostic_snapshot_mapper.rs
      pdu_diagnostic_authority.rs
    tests/
      contract_hardlinks.rs
      contract_symlinks.rs
      contract_missing_target.rs
      contract_max_depth.rs
      contract_pdu_max_depth_zero_one_equivalent.rs
      contract_stored_depth_mapping.rs
      contract_depth_projection_not_cleanup_authority.rs
      contract_non_utf8.rs
      contract_cli_host_semantics.rs
      contract_reporter_progress.rs
      contract_error_report_owned_evidence.rs
      contract_error_report_redaction.rs
      contract_no_pdu_text_error_report.rs
      contract_access_entry_parent_scope.rs
      contract_event_order.rs
      contract_datatree_projection.rs
      contract_no_pdu_treebuilder_as_engine_port.rs
      contract_treebuilder_callback_not_domain_port.rs
      contract_treebuilder_no_result_cancel_stream.rs
      contract_metadata_tap.rs
      contract_boundary_scope.rs
      contract_resource_profile.rs
      contract_no_global_rayon.rs
      contract_target_overlap.rs
      contract_target_canonicalization_authority.rs
      contract_no_pdu_overlap_removal.rs
      contract_symlink_target_policy.rs
      contract_synthetic_root.rs
      contract_path_display_safety.rs
      contract_non_utf8_path_authority.rs
      contract_size_display_boundary.rs
      contract_size_policy_mapping.rs
      contract_hardlink_reflection_boundary.rs
      contract_hardlink_reclaim_boundary.rs
      contract_hardlink_ordering.rs
      contract_hardlink_recorder_side_store.rs
      contract_hardlink_event_not_group_count.rs
      contract_hardlink_conflict_path_preserved.rs
      contract_hardlink_dedup_not_primary_size.rs
      contract_hardlink_projection_not_reclaim.rs
      contract_hardlink_duplicate_observation_preserved.rs
      contract_hardlink_summary_not_reclaim_authority.rs
      contract_hardlink_summary_outside_links.rs
      contract_pdu_hardlink_unix_only_capability.rs
      contract_metadata_tap_not_hardlink_support.rs
      contract_future_ntfs_hardlink_same_domain_contract.rs
      contract_pdu_runtime_error_not_backend_failure.rs
      contract_pdu_json_import_read_only.rs
      contract_pdu_schema_not_protocol_version.rs
      contract_pdu_sdk_layer_matrix.rs
      contract_pdu_sdk_import_firewall.rs
      contract_pdu_toolchain_compatibility.rs
      contract_pdu_build_surface_guard.rs
      contract_no_pdu_library_main_in_daemon.rs
      contract_pdu_deny_warnings_is_release_gate.rs
      contract_pdu_target_api_surface.rs
      contract_docs_rs_not_capability_authority.rs
      contract_windows_pdu_unix_paths_disabled.rs
      contract_pdu_non_exhaustive_fallback.rs
      contract_no_pdu_variant_names_in_product_contracts.rs
      contract_pdu_name_order_not_product_sort.rs
      contract_pdu_display_not_path_authority.rs
      contract_no_pdu_terminal_display_imports.rs
      contract_no_pdu_status_board_side_effects.rs
      contract_pdu_status_board_not_session_event_bus.rs
      contract_no_pdu_formatted_sizes_in_protocol.rs
      contract_no_pdu_bytes_format_aliases_in_protocol.rs
      contract_size_display_policy_not_pdu_bytes_format.rs
      contract_pdu_block_count_ignores_byte_format.rs
      contract_get_size_not_measurement_port.rs
      contract_pdu_bytes_semantics_explicit.rs
      contract_measurement_fallback_visible.rs
      contract_pdu_aggregate_not_own_size.rs
      contract_no_pdu_datatree_constructor_in_engine.rs
      contract_pdu_reporter_not_product_event_bus.rs
      contract_pdu_reporter_non_blocking.rs
      contract_no_builtin_progress_reporter_in_production.rs
      contract_builtin_progress_reporter_destroyed_in_diagnostics.rs
      contract_progress_thread_panic_maps_to_diagnostic_failure.rs
      contract_production_pdu_reporter_not_parallel_reporter.rs
      contract_parallel_reporter_destroy_diagnostic_only.rs
      contract_pdu_callbacks_side_store_only.rs
      contract_pdu_callback_overflow_evidence.rs
      contract_pdu_recorder_err_not_cancellation.rs
      contract_event_sequence_owned_by_engine.rs
      contract_stable_order_independent_from_pdu_child_order.rs
      contract_cursor_invalidates_on_index_version.rs
      contract_pdu_tree_converter_iterative.rs
      contract_converter_depth_budget_failure.rs
      contract_wide_directory_budget_gate.rs
      contract_pdu_mount_point_not_volume_authority.rs
      contract_storage_hint_not_scan_boundary.rs
      contract_defer_secondary_indexes_on_pressure.rs
      contract_no_half_built_read_model.rs
      contract_no_pdu_helper_mutation.rs
      contract_pdu_reflection_validation_not_trust.rs
      contract_engine_index_order_not_pdu_sort.rs
      contract_issue_path_scope.rs
      contract_zero_size_error_node.rs
      contract_access_entry_parent_scope.rs
      contract_measurement_policy_mapping.rs
      contract_pdu_get_size_no_side_effect_port.rs
      contract_pdu_get_size_not_metadata_provider.rs
      contract_pdu_bytes_unit_ambiguity.rs
      contract_pdu_unix_blocks_512_unit_evidence.rs
      contract_pdu_block_count_not_bytes.rs
      contract_no_domain_type_implements_pdu_size.rs
      contract_pdu_size_display_not_product_semantics.rs
      contract_no_pdu_fake_root_pipeline.rs
      contract_product_default_target.rs
      contract_multi_target_projection.rs
      contract_device_boundary_capability.rs
      contract_boundary_skipped_children.rs
      contract_non_unix_boundary_unsupported.rs
      contract_boundary_skip_not_empty_dir.rs
      contract_same_device_evidence_required.rs
      contract_non_unix_same_device_not_claimed.rs
      contract_pdu_json_diagnostic_only.rs
      contract_pdu_reflection_reduced_authority.rs
      contract_pdu_schema_not_protocol.rs
      contract_pdu_json_output_error_precedence_diagnostic_only.rs
      contract_no_pdu_json_stdout_flow_in_export_api.rs
      contract_clean_disk_export_receipt_not_pdu_runtime_error.rs
      contract_no_pdu_threads_api.rs
      contract_no_pdu_args_in_backend_request.rs
      contract_no_raw_pdu_cli_tokens_in_protocol.rs
      contract_pdu_min_ratio_not_query_policy.rs
      contract_pdu_fraction_nan_not_product_filter.rs
      contract_pdu_cull_output_reduced_authority.rs
      contract_resource_budget_before_pdu.rs
      contract_no_global_rayon_pool.rs
      contract_pdu_local_thread_pool.rs
      contract_pdu_resource_profile_mapping.rs
      contract_pdu_helper_lane_containment.rs
      contract_pdu_feature_graph.rs
      contract_pdu_effective_dependency_graph.rs
      contract_no_pdu_auxiliary_features_in_production.rs
      contract_no_pdu_cli_or_json_in_production_graph.rs
      contract_pdu_dependency_names_not_domain_capabilities.rs
      contract_pdu_import_allowlist.rs
      contract_no_pdu_presentation_imports.rs
      contract_pdu_datatree_readonly_conversion.rs
      contract_no_pdu_datatree_helper_mutations.rs
      contract_pdu_children_vec_not_pagination.rs
      contract_pdu_resultless_traversal_join.rs
      contract_pdu_empty_children_not_complete_without_evidence.rs
      contract_pdu_callback_events_adapter_private.rs
      contract_product_phase_not_pdu_walk.rs
      contract_snapshot_ready_after_indexing.rs
      contract_progress_snapshot_not_final_summary.rs
      contract_pdu_hardlink_progress_not_group_count.rs
      contract_pdu_hardlink_dedup_not_primary_size.rs
      contract_pdu_hardlink_projection_checked_arithmetic.rs
      contract_pdu_hardlink_reflection_not_evidence_authority.rs
      contract_pdu_wide_directory_memory_estimated_not_exact.rs
      contract_pdu_max_depth_not_memory_safety.rs
      contract_pdu_budget_blocks_half_built_snapshot.rs
      contract_scan_not_ready_after_pdu_traversal.rs
      contract_target_outcome_from_pdu_root_error.rs
      contract_target_outcome_cleanup_block.rs
      contract_target_identity_envelope.rs
      contract_pdu_root_probe_drift.rs
```

Rules:

- Read [pdu Clean Architecture contract](pdu-clean-architecture-contract.md)
  before implementing this crate.
- This is the only crate that may import `parallel_disk_usage`.
- It maps pdu types to `fs_usage_core` and `fs_usage_engine` types immediately.
- It must not expose pdu types in its public API unless a type is explicitly adapter-only.
- It receives normalized targets from `fs_usage_engine`; it must not copy pdu
  CLI overlap removal, default target, or fake root behavior.
- Forking pdu is not the default. Start with adapter integration, then upstream-first PRs for missing hooks, then a small controlled fork only if required by proven product constraints.
- Use `parallel-disk-usage` with `default-features = false`; enable `json`
  only for fixtures or diagnostics if needed.
- Treat `default-features = false` as necessary but not sufficient. Release
  checks also prove the effective normal dependency graph has no pdu `cli`, no
  accidental production `json`, and no pdu imports outside `fs_usage_pdu`.
- Production release checks also deny pdu auxiliary features:
  `ai-instructions`, `cli-completions`, `man-page`, and `usage-md`.
- pdu crate root has `#![deny(warnings)]` and a library-level `main()` behind
  `cli`. Treat both as release/CLI host concerns. `clean-disk-server` must use
  scanner adapters, not `parallel_disk_usage::main()`.
- pdu feature names and dependency names are build evidence only. They never
  become domain capability names, protocol fields, or Flutter view-state terms.
- pdu Unix allocated bytes from `GetBlockSize` map to explicit
  `MeasurementUnitEvidence` with source API `MetadataExt::blocks` and unit
  `unix_512_byte_blocks`. They are measured allocated bytes, not exact reclaim
  authority.
- pdu `GetSize` is a pure pdu measurement hook. It is not a metadata provider,
  accounting provider, event emitter, cancellation hook, or path-aware extension
  point. Rich metadata and delete authority come from platform providers.
- pdu `Size`, `Bytes`, `Blocks`, and `DisplayFormat` stay inside `fs_usage_pdu`.
  Domain `SizeFacts`, reclaim estimates, accounting evidence, protocol DTOs,
  and Flutter models must not implement or expose pdu size traits or newtype
  names.
- pdu target-specific APIs are build evidence only. Unix-only pdu APIs such as
  hardlink-aware detection, block-size getters, device ids, and inode ids map to
  target capability DTOs. They never appear as domain `cfg` assumptions.
- docs.rs pages and crate metadata are source references, not release-target
  authority. Every supported artifact target needs compile evidence for the pdu
  APIs used by the adapter.
- Keep pdu JSON and `Reflection` in `diagnostics/` or tests only. They must not
  become server protocol DTOs, persistence schemas, Flutter DTOs, or engine read
  model types.
- pdu JSON output is also CLI control flow. Its stdout serialization and
  `.or(deduplication_result)` hardlink-report precedence stay diagnostic-only.
  Product exports use Clean Disk export receipts and issue models.
- pdu `StatusBoard` and `GLOBAL_STATUS_BOARD` stay out of production daemon
  paths. Product progress is session-scoped events, not process-global stderr
  repaint state.
- pdu byte-format CLI names and aliases stay out of product protocol and
  preferences. `1`, `1000`, and `1024` are diagnostic compatibility tokens,
  while product code uses `SizeDisplayPolicy` and exact `SizeFact` values.
- Run pdu scans through `PduExecutionLane`, not through Rayon global pool.
  The lane owns a bounded Rayon pool and calls `ThreadPool::install` so pdu's
  internal parallel iterators execute under our resource budget.
- Keep pdu Rayon scheduling private to `fs_usage_pdu`. Domain, application,
  protocol, and Flutter contracts use `ResourceProfile`, `ScanPriority`, and
  `PduLaneMetrics`, not Rayon thread-pool types or pdu CLI `Threads`.
- pdu helper diagnostics such as reflection conversion, helper sort/retain, or
  hardlink projections must also run inside a bounded lane.
- Model pdu cancellation as request/epoch invalidation until a real cooperative
  cancellation hook exists. Do not claim instant stop in API or UI.
- Contain recoverable pdu panics at the adapter boundary where the Rust panic
  strategy allows it. If the product uses aborting panic semantics or needs
  stronger isolation, move pdu execution behind a helper-process adapter without
  changing engine contracts.
- Product daemon code must not call `rayon::ThreadPoolBuilder::build_global`.
- Do not use pdu CLI presentation behavior as product behavior. Multi-root
  synthetic roots, sorting, filtering, progress throttling, and scan quality
  belong to `fs_usage_engine`.
- pdu CLI host modules are reference material only. Production adapter code
  must not import pdu `app`, `args`, or `runtime_error`.
- Record pdu raw scan metrics separately from arena and index metrics. pdu does
  not stream nodes, so memory budgets must account for temporary pdu tree plus
  conversion overlap.
- Treat wide-directory memory evidence as confidence-tagged. pdu does not expose
  exact temporary child-name vector peaks, and final `DataTree` shape cannot
  prove peak memory use, especially when stored depth hides descendants.
- Resource policy is engine-owned. `PduExecutionLane` maps product
  `ResourceProfile` into local Rayon pool settings and records
  `PduLaneMetrics`.
- Use a custom `PduReporter` as bounded evidence collection. Do not expose or
  depend on pdu's built-in `ProgressAndErrorReporter` as product progress
  state.
- Production `PduReporter` implements pdu `Reporter` only. It does not implement
  pdu `ParallelReporter`, does not own a progress thread, and does not use
  `destroy()` as scan completion.
- Do not use pdu `ProgressAndErrorReporter` in production paths. It spawns its
  own progress thread and must be explicitly destroyed if diagnostics ever use
  it.
- pdu callbacks are extension hooks inside traversal workers, not product event
  buses. They may only copy tiny owned evidence into bounded adapter-side stores
  and return quickly.
- pdu traversal returns a `DataTree` even when errors were reported. Join pdu
  tree shape with reporter evidence, metadata tap evidence, hardlink evidence,
  and target preflight in `PduEvidenceJoiner` before creating
  `BackendScanOutput`.
- Empty pdu children are not completeness evidence by themselves. They can mean
  real empty directory, read failure, device boundary, stored-depth projection,
  symlink/non-directory, metadata failure, or a race.
- Do not treat `RecordHardlinks::Err` as cancellation, backpressure, or product
  failure because `FsTreeBuilder` discards recorder errors.
- Map pdu progress counters to `PduProgressEvidence` only. Product
  `ScanPhaseProgress` is engine-owned and final `ScanSummary` comes from
  `BackendScanOutput`, `NodeArena`, read-model indexes, and issue aggregation.
- Treat pdu `linked` and `shared` progress fields as hardlink telemetry only,
  not as unique hardlink groups, exclusive shared size, or reclaim estimate.
- Publish scan readiness only after pdu traversal, tree conversion, primary
  indexes, and scan-quality aggregation complete. A final pdu progress tick is
  not required for final summary publication.
- Assign product event sequence numbers outside pdu callbacks. pdu callback
  order is traversal evidence only and is not UI/protocol order.
- Do not use pdu `DataTree` helper mutations as product query semantics. Sorting,
  culling, child projection, and hardlink-adjusted views belong to engine
  indexes and explicit projection evidence.
- pdu `Fraction`, CLI `min_ratio`, and `par_cull_insignificant_data` are
  diagnostic/CLI projection helpers. Product query filters use exact typed
  descriptors, reject non-finite thresholds, and never depend on pdu `f32`
  culling semantics.
- Production conversion reads pdu `DataTree` through immutable getters only via
  `PduDataTreeReadOnlyView`. `name_mut`, `par_retain`, `into_par_retained`,
  `par_sort_by`, `into_par_sorted`, `par_cull_insignificant_data`, and
  `fixed_size_dir_constructor` are diagnostic/fixture-only and reduced-authority.
- Do not use pdu `DataTree::dir` or pdu aggregate recomputation outside
  `fs_usage_pdu`. Engine projections use `AggregateSizeEvidence`,
  `OwnSizeEvidence`, `VisibleChildSum`, and `ChildCompleteness`.
- Do not use pdu `OsStringDisplay` ordering, `Display`, `Deref`, `DerefMut`, or
  text error output as product sort, path identity, export, cache, protocol, or
  cleanup authority.
- Map pdu root and child names through `PduNameKindMapper` before creating
  engine path evidence. Root is full-path-like; descendants are file-name
  segments.
- Treat pdu root shape as traversal evidence only. pdu does not prove target
  identity stability across preflight, scan, query, and cleanup review.
- Treat pdu child position as diagnostic evidence only. Engine
  `SnapshotOrderIndex` and opaque cursors define product pagination.
- Convert pdu `DataTree` with an iterative converter or explicit stack-depth
  guard. Do not publish a partially converted `NodeArena`.
- A custom pdu `RecordHardlinks` implementation may be used as a private
  metadata tap, but its output is scan-time adapter evidence only. Current
  metadata and delete authority still come from platform providers.
- Keep pdu `HardlinkList`, `HardlinkListReflection`, `LinkPathList`,
  `LinkPathListReflection`, and `SharedLinkSummary` inside `fs_usage_pdu`.
  Map them to owned `HardlinkGroupEvidence`, `HardlinkScope`,
  `HardlinkSummaryEvidence`, `HardlinkConfidence`, and
  `HardlinkReclaimPolicy` before any engine, protocol, cache, or Flutter
  boundary.
- Hardlink order, duplicate path handling, and summary exclusivity are adapter
  evidence. Product row ordering, reclaim confidence, and delete authority are
  engine/application decisions.
- pdu hardlink summary fields such as `exclusive_shared_size` are evidence only.
  Exact reclaim estimates require accounting/platform revalidation.
- pdu hardlink dedupe prefix/suffix subtraction is a projection algorithm, not
  primary measured size and not reclaim authority. Product hardlink-adjusted
  views are recomputed from `HardlinkGroupEvidence` with checked arithmetic.
- Keep pdu `LinkPathListReflection` diagnostic-only because its `HashSet`
  conversion can erase duplicate-observation evidence.
- pdu built-in `HardlinkAware` detection is Unix-only adapter capability.
  Non-Unix pdu reports hardlink detection as unsupported or degraded explicitly.
- A custom `RecordHardlinks` metadata tap is not the same as hardlink group
  support. It can collect adapter evidence while `HardlinkCapability` remains
  unsupported.
- Future Windows NTFS/MFT hardlink evidence uses the same
  `HardlinkCapability` and `HardlinkIdentityKind` domain contracts through a
  separate adapter, not pdu Unix identity names.
- Record deep-tree/path-depth risk separately. pdu `max_depth` is not a true
  traversal cutoff and pdu has no stack-depth guard.
- pdu's `DataTree` is converted into the engine read model and dropped as soon
  as practical.

### `fs_usage_platform`

Purpose: platform metadata and identity providers.

```text
rust/crates/fs_usage_platform/
  Cargo.toml
  src/
    lib.rs
    metadata/
      mod.rs
      basic_metadata_provider.rs
      link_metadata_provider.rs
    identity/
      mod.rs
      file_identity_provider.rs
      revalidator.rs
    links/
      mod.rs
      link_classifier.rs
    volume/
      mod.rs
      volume_info_provider.rs
      device_identity_provider.rs
      mount_scope_provider.rs
      storage_medium_provider.rs
      storage_medium_hint.rs
      storage_medium_confidence.rs
      disk_kind_provider.rs
    permissions/
      mod.rs
      permission_reader.rs
    platform/
      mod.rs
      macos.rs
      windows.rs
      linux.rs
      unsupported.rs
```

Rules:

- Platform-specific `cfg` stays here.
- Implements metadata, identity, volume, and permission ports from `fs_usage_engine`.
- Must degrade through explicit capabilities when a platform cannot provide a detail.
- Classifies symlink, broken symlink, Windows reparse point, junction, mount
  point, provider placeholder, and unknown link-like objects. pdu `DataTree`
  must never be treated as final link kind.

### `fs_usage_accounting`

Purpose: advanced storage accounting and reclaim estimates.

```text
rust/crates/fs_usage_accounting/
  Cargo.toml
  src/
    lib.rs
    estimate/
      mod.rs
      reclaim_estimator.rs
      confidence_model.rs
    hardlink/
      mod.rs
      hardlink_accounting.rs
    shared_extents/
      mod.rs
      shared_extent_detector.rs
    snapshots/
      mod.rs
      snapshot_detector.rs
    compression/
      mod.rs
      compression_detector.rs
```

Rules:

- Keeps `logical_size`, `allocated_size`, `exclusive_reclaim_estimate`, `confidence`, `quota_effect`, and observed free-space delta separate.
- Must report unknown/partial confidence instead of making exact claims.
- Does not make cleanup decisions by itself.

### `fs_usage_cleanup`

Purpose: optional reusable cleanup preflight, Trash, revalidation, and receipts.

```text
rust/crates/fs_usage_cleanup/
  Cargo.toml
  src/
    lib.rs
    domain/
      mod.rs
      delete_candidate.rs
      delete_plan.rs
      delete_plan_status.rs
      cleanup_capabilities.rs
      cleanup_receipt.rs
    application/
      mod.rs
      command/
        mod.rs
        create_delete_plan.rs
        validate_delete_plan.rs
        move_to_trash.rs
      query/
        mod.rs
        get_delete_plan.rs
      port/
        mod.rs
        trash_provider.rs
        identity_revalidator.rs
        delete_plan_repository.rs
    infrastructure/
      mod.rs
      memory/
        mod.rs
        delete_plan_registry.rs
      trash/
        mod.rs
        platform_trash.rs
```

Rules:

- Delete is plan-based, never path-string based.
- Uses scan-time identity plus current filesystem revalidation.
- Platform Trash support is capability-based.
- Returns structured partial outcomes and receipts.

## Layer 2 - Clean Disk Rust Host

Clean Disk has its own Rust host and protocol. This layer is app-specific and should not be published as the reusable filesystem library.

```text
rust/
  apps/
    clean_disk_server/
    clean_disk_cli/
  crates/
    clean_disk_protocol/
    clean_disk_http_ws/
```

### `clean_disk_protocol`

Purpose: versioned wire DTOs and mapping for Clean Disk clients.

```text
rust/crates/clean_disk_protocol/
  Cargo.toml
  src/
    lib.rs
    version.rs
    v1/
      mod.rs
      paging.rs
      commands/
        mod.rs
        scan_commands.rs
        cleanup_commands.rs
      queries/
        mod.rs
        scan_queries.rs
        cleanup_queries.rs
      responses/
        mod.rs
        scan_responses.rs
        cleanup_responses.rs
      events/
        mod.rs
        scan_events.rs
        cleanup_events.rs
        event_batch.rs
      errors/
        mod.rs
        error_code.rs
        error_response.rs
      mapping/
        mod.rs
        fs_usage_mapping.rs
        cleanup_mapping.rs
```

Rules:

- Owns JSON/OpenAPI/AsyncAPI compatibility.
- Uses string-encoded exact integers for byte counts, large counters, IDs, cursors, and event sequences where web precision matters.
- Wire DTOs are not Rust domain models and not Flutter view state.
- Protocol maps to and from `fs_usage_*` types at the boundary.

### `clean_disk_http_ws`

Purpose: first socket transport adapter.

```text
rust/crates/clean_disk_http_ws/
  Cargo.toml
  src/
    lib.rs
    server.rs
    state.rs
    routes/
      mod.rs
      health.rs
      scan_sessions.rs
      scan_tree.rs
      cleanup.rs
      events_ws.rs
    middleware/
      mod.rs
      auth.rs
      cors.rs
      tracing.rs
      request_id.rs
    websocket/
      mod.rs
      connection.rs
      heartbeat.rs
      event_sender.rs
      reconnect.rs
```

Rules:

- HTTP and WebSocket only.
- HTTP owns commands and queries. WebSocket owns progress/session events.
- WebSocket events are notifications, not the only source of truth. Clients recover state through HTTP queries after reconnect.
- Route handlers are thin: parse, authorize, call engine/application services, map response.
- Does not call `pdu`, platform Trash, or filesystem adapters directly.

### `apps/clean_disk_server`

Purpose: process composition root. Binary name: `clean-disk-server`.

```text
rust/apps/clean_disk_server/
  Cargo.toml
  src/
    main.rs
    config/
      mod.rs
      local.rs
      remote.rs
      auth.rs
    composition/
      mod.rs
      fs_usage.rs
      cleanup.rs
      transport.rs
      dependencies.rs
    observability/
      mod.rs
      logging.rs
      tracing.rs
      metrics.rs
    shutdown.rs
```

Rules:

- Wires `fs_usage_engine`, `fs_usage_pdu`, platform/accounting/cleanup adapters, protocol, and HTTP/WebSocket transport.
- Owns local token generation, random local port selection, allowed origins, config, logging, shutdown, and remote mode settings.
- Contains no scan, indexing, accounting, or cleanup business rules.
- Owns the local process lifecycle for one daemon process. Do not split the local runtime into microservices for MVP.
- Owns runtime resource mode selection such as Balanced, Fast, and Background, but delegates actual scheduling policy to `fs_usage_engine`.

### Desktop And Web Runtime

Desktop:

```text
Flutter desktop launches clean-disk-server
  -> random loopback port
  -> random session token
  -> health check
  -> HTTP commands/queries
  -> WebSocket event batches
  -> graceful shutdown on app exit
```

Web:

```text
Flutter web connects to a local or remote clean-disk-server
  -> user-approved endpoint
  -> token/auth
  -> origin allowlist
  -> same command/query/event protocol
```

Full disk scanning never happens through browser filesystem APIs.

## Layer 3 - Flutter App

Flutter is a client of the Clean Disk API.

Feature package target:

```text
features/scan/
  lib/
    scan.dart
    src/
      domain/
        scan_session.dart
        scan_node.dart
        byte_count.dart
      application/
        ports/
          scan_repository.dart
          scan_event_stream.dart
        use_cases/
          start_scan.dart
          cancel_scan.dart
          get_children.dart
          get_node_details.dart
          search_nodes.dart
        state/
      data/
        dto/
        sources/
          clean_disk_scan_api.dart
          clean_disk_scan_ws.dart
        protocol/
          clean_disk_api_client.dart
          scan_event_client.dart
          dto/
          mappers/
        repositories/
      presentation/
        pages/
        stores/
        widgets/
      di/
```

Rules:

- Flutter domain/application does not import Rust, pdu, HTTP libraries directly, generated bridge code, or filesystem APIs.
- Flutter data layer owns protocol DTO parsing and repository adapters.
- `CleanDiskApiClient` uses the existing `abstract_http_client` for HTTP commands and queries. It is a product protocol adapter, not a generic network wrapper.
- `ScanEventClient` owns WebSocket connection, event decoding, reconnect inputs, and `after_seq` subscription parameters.
- Flutter presentation owns UI state, selection, expanded rows, visible pages, details panel, and delete queue interaction state.
- Exact byte values should use value objects, not raw `double`.
- Flutter never receives or stores the full scan tree.

## Dependency Direction

Allowed direction:

```text
fs_usage_core

fs_usage_engine
  -> fs_usage_core

fs_usage_pdu
  -> fs_usage_engine
  -> fs_usage_core
  -> parallel-disk-usage

fs_usage_platform
  -> fs_usage_engine
  -> fs_usage_core
  -> platform APIs

fs_usage_accounting
  -> fs_usage_engine
  -> fs_usage_core
  -> optional platform/shared-extent probes

fs_usage_cleanup
  -> fs_usage_core
  -> optional fs_usage_engine ports/types
  -> platform Trash adapters

clean_disk_protocol
  -> fs_usage_core
  -> fs_usage_engine application DTOs
  -> fs_usage_cleanup DTOs

clean_disk_http_ws
  -> clean_disk_protocol
  -> fs_usage_engine
  -> fs_usage_cleanup

apps/clean_disk_server
  -> concrete fs_usage adapters
  -> clean_disk_protocol
  -> clean_disk_http_ws

apps/clean_disk Flutter
  -> feature application ports
  -> feature data adapters
  -> protocol DTOs through data layer only
```

Forbidden:

- `fs_usage_core` importing any adapter or transport crate.
- `fs_usage_engine` importing `parallel_disk_usage`, HTTP/WebSocket, Flutter bridge, or Clean Disk protocol.
- `clean_disk_http_ws` calling `pdu` or Trash directly.
- Flutter domain/application importing HTTP/WebSocket implementation details or Rust internals.
- Any adapter depending on another adapter unless explicitly documented as composition-only.

## Session API Shape

Reusable Rust API:

```text
create_session(options) -> ScanSessionId
start_scan(session_id)
cancel_scan(session_id)
dispose_session(session_id)

get_summary(session_id)
get_children(session_id, node_id, page_request)
get_top_items(session_id, top_items_request)
get_node_details(session_id, node_id, detail_level)
search_nodes(session_id, query, page_request)

subscribe_events(session_id, after_seq) -> EventBatch stream
```

Clean Disk HTTP shape:

```text
GET  /api/v1/health
POST /api/v1/sessions
POST /api/v1/sessions/{session_id}/start
POST /api/v1/sessions/{session_id}/cancel
DELETE /api/v1/sessions/{session_id}

GET  /api/v1/sessions/{session_id}/summary
GET  /api/v1/sessions/{session_id}/nodes/{node_id}/children
GET  /api/v1/sessions/{session_id}/top
GET  /api/v1/sessions/{session_id}/nodes/{node_id}
GET  /api/v1/sessions/{session_id}/search

POST /api/v1/sessions/{session_id}/delete-plan/validate
POST /api/v1/delete-plans/{delete_plan_id}/move-to-trash
```

Clean Disk WebSocket shape:

```text
GET /api/v1/sessions/{session_id}/events?after_seq=...
```

Event batches include ordered sequence values so clients can reconnect without assuming delivery of every progress snapshot.

Transport abstraction shape:

```text
Flutter application ports:
  ScanRepository
  ScanEventStream

Flutter data/protocol adapters:
  CleanDiskApiClient
  ScanEventClient

Clean Disk server adapters:
  clean_disk_http_ws routes
  clean_disk_http_ws event socket

Reusable Rust library:
  no transport dependency
```

The abstraction is intentionally small. Do not build a generic RPC framework, transport factory hierarchy, Socket.IO adapter, JSON-RPC adapter, or gRPC adapter before there is a measured need.

## Data Transfer Rules

- Do not send the full scan tree to clients.
- Send progress and scan events as throttled batches.
- Send tree rows only as pages.
- Keep large indexes in Rust.
- Sort and filter in Rust.
- Keep stable `NodeId` values per scan session.
- Long paths and names may be truncated in UI, but protocol values must remain exact.
- JSON exact integer values crossing Flutter web must use decimal strings or value-object DTOs.

## Capability Model

Every scanner/accounting/cleanup backend must report capabilities explicitly.

Examples:

```text
supports_progress
supports_cancel
hardlink_detection = supported | unsupported | degraded
hardlink_identity_kind = unix_dev_inode | ntfs_file_reference | unknown
supports_allocated_size
supports_reclaim_estimate
supports_realtime_events
supports_platform_trash
supports_remote_mode
```

UI and protocol must not infer capabilities from crate names. Unknown support is a valid state.

## Known Architecture Risks

Detailed future risks are tracked in [Architecture future risks](architecture-future-risks.md). This section is the short checklist that must stay visible in the main architecture document.

### Public API Stability Too Early - `P0`

Risk: freezing the reusable library API before real Clean Disk workflows validate it.

Mitigation:

- Keep `fs_usage_*` reusable but internal/unstable first.
- Publish externally only after scan, pagination, search, details, cleanup queue, and preflight flows are exercised.
- Add compatibility fixtures before promising semver stability.

### pdu Leakage - `P0`

Risk: `pdu::DataTree`, pdu events, pdu hardlink semantics, or pdu size modes become the public API.

Mitigation:

- `parallel_disk_usage` import is allowed only in `fs_usage_pdu`.
- Add boundary tests based on `cargo metadata` or import scans.
- Map pdu types immediately to `fs_usage_*` types.

### Size Versus Reclaim Confusion - `P0`

Risk: showing folder size as if it were exact free space after deletion.

Mitigation:

- Separate logical size, allocated size, exclusive reclaim estimate, confidence, quota effect, and observed free-space delta.
- Show unknown/estimated states when APFS clones, snapshots, reflinks, VSS, sparse files, compression, cloud placeholders, hardlinks, or open files are involved.

### Crate Explosion - `P1`

Risk: too many crates before implementation proves the pressure.

Mitigation:

- Start with `fs_usage_core`, `fs_usage_engine`, `fs_usage_pdu`, `clean_disk_protocol`, and `clean_disk_server`.
- Split `platform`, `accounting`, and `cleanup` when the implementation needs those boundaries.

### Feature Flag Complexity - `P1`

Risk: one crate with many optional flags becomes harder to reason about than separate adapters.

Mitigation:

- Prefer optional adapter crates over a single giant crate with many flags.
- Keep the core dependency graph small.
- Document enabled dependency features for pdu and platform crates.

### Async Contamination - `P1`

Risk: `tokio`, channels, locks, or transport concepts leak into domain/value objects.

Mitigation:

- Keep `fs_usage_core` sync and pure.
- Keep async orchestration in `fs_usage_engine` sessions/jobs and Clean Disk server.
- Use ports to isolate async IO.

### Protocol DTO Leakage - `P1`

Risk: wire DTOs become Rust domain models or Flutter view models.

Mitigation:

- Keep `clean_disk_protocol` as a mapping boundary.
- Add DTO fixtures and mapping tests.
- Flutter data layer maps protocol DTOs to feature models.

### Backpressure And Huge Trees - `P0`

Risk: event floods or huge JSON responses freeze UI or exhaust memory.

Mitigation:

- Bound all channels and buffers.
- Coalesce progress events.
- Preserve terminal events and errors.
- Serve rows, top lists, and search results only by pages.
- Drop or slow-path clients that cannot keep up, with observable lag state.

### Cancellation Semantics - `P1`

Risk: UI says canceled while scanner keeps doing expensive work.

Mitigation:

- Model cancellation state explicitly.
- Require scanner backend capability for cooperative cancellation.
- If a backend cannot cancel immediately, expose `cancel_requested` and terminal `canceled` separately.

### Stale Scan Data Before Cleanup - `P0`

Risk: deleting the wrong target after files move/change between scan and delete.

Mitigation:

- Delete by validated candidate, not raw path string.
- Re-read metadata and identity before Trash/delete.
- Return structured stale/mismatch reasons.

### Local Daemon Security - `P0`

Risk: a browser or local process controls the daemon without permission.

Mitigation:

- Bind local mode to loopback only.
- Use random local port and random session token.
- Enforce origin allowlist.
- Disable destructive commands without valid auth/session.
- Treat remote/headless mode as a separate security profile with explicit auth.

## SOLID And DDD Rules

- Domain/value objects have one reason to change: filesystem usage language and invariants.
- Ports are small and role-specific. Do not create a single large `FilesystemService`.
- New scanner backends are added by implementing `ScannerBackend`, not by changing `fs_usage_engine`.
- New transports are added in Clean Disk host/interface crates, not in the reusable library.
- Use anti-corruption mapping at real boundaries: pdu adapter, platform metadata, protocol, cleanup revalidation, and Flutter data adapters.
- Do not model the full scanned filesystem as one giant domain aggregate.
- Treat tree rows, details, search results, and top-item lists as query projections backed by indexes.
- Use enums/custom policy types instead of raw `bool` flags for scan, accounting, and cleanup behavior.
- Parse at boundaries. HTTP, WebSocket, CLI, and Flutter adapters convert raw strings/JSON into typed commands before calling application services.
- Keep events separate by layer: scanner events, application events, protocol event batches, and Flutter UI events are not the same type.

## Rust Tactical Layer Layout

The Rust side uses crate boundaries first, then module boundaries inside each
crate. The goal is not to copy Java-style folders. The goal is to make illegal
dependencies hard to write.

Top 3 module layout options:

1. Crate-level layers with focused modules inside each crate - 🎯 10 🛡️ 9 🧠 7,
   roughly 1800-3800 LOC for the first slice. Accepted. This fits Rust because
   Cargo dependencies enforce the most important boundaries.
2. One large crate with `domain/application/infrastructure` modules - 🎯 5
   🛡️ 5 🧠 4, roughly 1200-2800 LOC. Rejected as default. It is convenient, but
   imports can leak and architecture checks become more important than the
   compiler boundary.
3. Many micro-crates per use case - 🎯 4 🛡️ 7 🧠 9, roughly 2500-6000 LOC.
   Rejected for MVP. It over-optimizes modularity before contracts are stable.

Accepted crate responsibilities:

```text
crates/
  fs_usage_core/
    src/
      lib.rs
      ids/
      value_objects/
      domain/
        scan_session.rs
        delete_plan.rs
        policies/
      errors/
      capabilities/
      issues/

  fs_usage_engine/
    src/
      lib.rs
      application/
        use_cases/
        ports/
        services/
      read_model/
        arena/
        indexes/
        queries/
        projections/
      events/
      contracts/

  fs_usage_pdu/
    src/
      lib.rs
      adapter/
        options_mapper.rs
        scan_runner.rs
        reporter_recorder.rs
        tree_converter.rs
        issue_mapper.rs
        hardlink_mapper.rs
        capability_mapper.rs
        backend_fingerprint.rs
      tests/

  fs_usage_platform/
    src/
      lib.rs
      metadata/
      identity/
      accounting/
      trash/
      permissions/
      topology/

apps/
  clean_disk_server/
    src/
      main.rs
      bootstrap/
      config/
      transport/
        http/
        websocket/
      protocol/
      auth/
      observability/
      lifecycle/
```

DDD mapping:

- `fs_usage_core/domain` owns aggregate roots and pure rules.
- `fs_usage_core/value_objects` owns typed facts and identities.
- `fs_usage_engine/application` owns use cases and ports.
- `fs_usage_engine/read_model` owns large scan projections and indexes.
- `fs_usage_pdu/adapter` owns all `parallel_disk_usage` imports.
- `fs_usage_platform` owns real OS facts and destructive platform actions.
- `clean_disk_server` owns runtime composition and transport.

Rules:

- `NodeArena` is a read model, not a domain aggregate.
- `ScanSession` references current snapshot by id, not by holding a full tree.
- `DeletePlan` is the destructive-intent aggregate and must require current
  revalidation.
- Repositories and backend ports live in application/engine, not in domain.
- Protocol DTOs are host/product boundary objects, not reusable library types.

## Architecture Verification

When Rust crates exist, add automated boundary checks:

- no `parallel_disk_usage` imports outside `fs_usage_pdu`;
- no `axum`, WebSocket, or protocol DTO imports in `fs_usage_core` or `fs_usage_engine`;
- no platform Trash implementation imports in scan crates;
- no Clean Disk protocol imports in reusable `fs_usage_*` crates;
- no Flutter bridge-generated code in reusable Rust domain/application crates;
- no full-tree protocol response types;
- no raw JSON `u64` exact byte/count values in web-facing DTOs;
- no cleanup command that accepts only a path string as authority.

Use Cargo crate boundaries first. Add a small `xtask` or CI script based on `cargo metadata` if Cargo boundaries alone are not enough.
