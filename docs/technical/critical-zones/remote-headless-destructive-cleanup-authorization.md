# Critical Zone - Remote And Headless Destructive Cleanup Authorization

Last updated: 2026-05-16.

This file is the next focused global critical-zone file after
`tool-command-execution-sandbox.md`. It covers remote/headless destructive
cleanup authority: authentication, object-level authorization, target scopes,
host identity, tenant/user isolation, audit, quotas, WebSocket message
authorization, and operator policy.

## Sources Reviewed

- OWASP API Security Top 10 2023: Broken Object Level Authorization is the first
  listed API risk, and API endpoints that handle object identifiers create a
  broad object-level access-control surface.
  Source: https://owasp.org/www-project-api-security/
- OWASP API4:2023 Unrestricted Resource Consumption: APIs need execution
  timeouts, memory/process/file descriptor limits, pagination limits, operation
  limits, and rate limiting.
  Source:
  https://owasp.org/API-Security/editions/2023/en/0xa4-unrestricted-resource-consumption/
- OWASP WebSocket Security Cheat Sheet: WebSocket connection authentication is
  not enough. Each message/action needs authorization, plus rate limits,
  validation, logging, and security monitoring.
  Source:
  https://cheatsheetseries.owasp.org/cheatsheets/WebSocket_Security_Cheat_Sheet.html
- NIST SP 800-207 Zero Trust Architecture: trust should not be granted by
  network location. Access decisions are resource-oriented and policy-driven.
  Source: https://www.nist.gov/news-events/news/2020/08/zero-trust-architecture-nist-publishes-sp-800-207
- NIST SP 800-204 Security Strategies for Microservices-based Application
  Systems: distributed/API-based systems need authentication, access management,
  secure communication protocols, monitoring, availability/resiliency controls,
  load balancing, and throttling.
  Source: https://csrc.nist.gov/pubs/sp/800/204/final
- Cedar authorization docs: authorization requests are modeled as principal,
  action, resource, and context. Cedar schemas can validate which principal and
  resource types are valid for each action.
  Sources:
  https://docs.cedarpolicy.com/auth/authorization.html and
  https://docs.cedarpolicy.com/policies/validation.html
- Open Policy Agent docs: OPA supports policy-as-code and offloading policy
  decisions from application code through structured inputs.
  Source: https://www.openpolicyagent.org/docs/latest
- Existing Clean Disk docs for remote/headless mode, transport protocol
  streaming, security/privacy, restore/undo, command sandbox, and operation
  journals.

## Why This Is The Next Global Critical Zone

After command sandboxing, the next global risk is remote/headless destructive
cleanup. Local cleanup already needs DeletePlan, identity revalidation, Trash,
receipts, and command sandboxing. Remote cleanup adds a harder question:

```text
Who is allowed to make this host perform this destructive action on this target?
```

Remote/headless cleanup can affect:

- another user's home directory;
- shared package stores;
- Docker volumes and VM state;
- cloud sync roots;
- production server disks;
- CI workspaces;
- mounted network shares;
- containers and Kubernetes volumes;
- backup and restore data;
- files owned by a service account rather than the human operator.

This is P0 before any remote destructive mode. It is not required for local MVP
if remote remains read-only, but it is the next global critical zone because one
authorization bug can turn a useful headless scanner into remote data deletion.

## Current Global Ranking

1. **Remote/headless destructive cleanup authorization** - 🎯 8  🛡️ 10  🧠 10, roughly 2600-7600 LOC/tests/docs.
   Selected now. It wraps every previous destructive boundary in actor, host,
   tenant, target scope, capability, policy, quota, and audit decisions.

2. **Persistent operation journal and receipt durability under low disk** - 🎯 8  🛡️ 9  🧠 8, roughly 1400-3800 LOC/tests/docs.
   Next candidate if cleanup beta starts before remote cleanup. A journal that
   cannot write under storage pressure breaks destructive safety.

3. **Remote deployment and pairing lifecycle** - 🎯 6  🛡️ 8  🧠 9, roughly 1800-5200 LOC/tests/docs.
   Important if hosted web UI, SSH tunnel, LAN remote UI, cloud relay, or server
   agents become first-class products.

## Core Rule

Remote destructive cleanup is disabled unless a complete authority chain is
proved for each operation.

```text
authenticated principal
  -> authorized host/session
  -> authorized target root
  -> authorized object/session/delete-plan ids
  -> authorized action kind
  -> fresh capability lease
  -> explicit destructive policy
  -> audit receipt
  -> quota and rate limit
```

Rules:

- remote mode starts read-only.
- network location grants no trust.
- local loopback token assumptions do not become remote authentication.
- every HTTP command and WebSocket message is authorized server-side.
- object IDs are opaque identifiers, not authorization.
- destructive capability is separate from scan/query capability.
- unsupported or unknown policy fails closed.

## Deployment Profiles

Remote/headless is not one mode.

```text
DeploymentProfile
  local_desktop_loopback
  daemon_served_local_web
  ssh_tunnel_single_user
  lan_remote_single_user
  remote_single_user_server
  remote_multi_user_server
  ci_agent_disposable_workspace
  container_agent_read_only
  enterprise_managed_server
```

Rules:

- each profile publishes capability state.
- destructive cleanup is off by default for all remote profiles.
- changing bind address to LAN/public interface requires profile change and
  security policy change.
- remote single-user is not the same as multi-user.
- CI disposable workspace can have a more aggressive policy only when workspace
  disposability is explicit.
- container/server environments do not inherit desktop Trash semantics.

Kill criteria:

- `--listen 0.0.0.0` enables cleanup with local token auth.
- remote mode inherits desktop Move-to-Trash UI.
- container agent can clean host mounts by default.
- CI cleanup profile runs on developer laptop.

## Authority Scope Model

Remote cleanup needs multi-dimensional scope.

```text
RemoteAuthorityScope
  principal_id
  auth_method
  host_id
  os_user_id
  deployment_profile
  allowed_roots
  denied_roots
  allowed_actions
  destructive_actions
  max_blast_radius
  quota_policy
  session_expiry
  audit_subject
```

Rules:

- principal identity and OS user identity are different.
- host identity and target root identity are explicit.
- service-account authority does not imply human approval.
- root/admin authority does not bypass policy.
- destructive actions require narrower scope than read-only scan.
- scope changes invalidate sessions, cursors, selections, delete plans,
  recommendations, previews, and receipts awaiting execution.

Kill criteria:

- daemon service account can clean every user's home because OS allows it.
- admin role bypasses target root policy.
- token says "admin" but not which host/root/action it applies to.
- stale delete plan remains valid after scope policy changes.

## Protected Objects

Every identifier crossing the protocol is a protected object.

```text
ProtectedObject
  scan_session
  snapshot
  node_ref
  cursor
  search_query
  selection_set
  recommendation
  command_preview
  delete_plan
  cleanup_operation
  cleanup_receipt
  support_bundle
  audit_export
```

Rules:

- every object has owner, host, scope, epoch, and expiry where applicable.
- every command/query checks principal, object, target root, action, and
  capability.
- cursor ownership includes query shape and snapshot epoch.
- receipt/support export has separate authorization because it can leak private
  metadata.
- shared scan sessions are read-only until collaboration semantics exist.

Kill criteria:

- user changes `session_id` and reads another user's scan.
- delete plan id can be reused by another subject.
- support bundle endpoint checks only authentication.
- authorization failure reveals whether another tenant's object exists.

## Authorization Request Model

Use a typed request model even if MVP uses Rust code rather than Cedar/OPA.

```text
AuthorizationRequest
  principal
  action
  resource
  context
```

```text
AuthorizationContext
  host_id
  deployment_profile
  os_user_id
  target_root
  snapshot_epoch
  operation_kind
  risk_tier
  restore_capability
  command_adapter_kind
  remote_addr_class
  quota_state
  confirmation_level
```

Implementation options:

1. **Typed Rust policy structs first** - 🎯 9  🛡️ 10  🧠 7, roughly 1200-3200 LOC/tests.
   Best MVP fit. Keeps policy reviewable, testable, and close to the domain
   model without introducing policy-engine operations risk.

2. **Cedar-style PARC model behind a Rust port** - 🎯 7  🛡️ 9  🧠 8, roughly 2200-5200 LOC/tests.
   Strong future direction for enterprise/remote policy because principal,
   action, resource, and context match our needs well.

3. **OPA/Rego policy decision point** - 🎯 5  🛡️ 8  🧠 9, roughly 3000-7000 LOC/tests.
   Useful for Kubernetes/enterprise policy ecosystems, but heavier for local
   desktop/headless MVP.

Accepted direction: option 1 now, with request shape compatible with option 2
later.

## Remote Destructive Policy Modes

```text
RemoteDestructivePolicy
  disabled
  analyze_only
  local_physical_confirmation_required
  remote_approval_required
  operator_policy_allowlisted
  disposable_workspace_only
  permanent_delete_forbidden
```

Rules:

- default is `disabled` or `analyze_only`.
- permanent delete is forbidden for remote MVP.
- local physical confirmation can be required for local host cleanup initiated
  from hosted web UI.
- remote approval records approver, actor, host, target root, policy version,
  and reason.
- disposable workspace policy requires proof of workspace root and owner.
- emergency kill switch disables remote cleanup immediately.

Kill criteria:

- remote policy toggles from UI without server/operator confirmation.
- remote cleanup uses local desktop confirmation UX unchanged.
- hosted web page can trigger local cleanup after only browser permission.
- policy does not distinguish move-to-trash, tool command, and permanent delete.

## WebSocket Message Authorization

WebSocket connection auth is not enough.

Rules:

- every message includes operation/session/object context.
- every message is authorized against current principal, scope, and epoch.
- subscription only receives events for authorized sessions.
- reconnect revalidates capability and may require snapshot refresh.
- authority changes revoke old subscriptions.
- rate limits apply per principal, operation, and message class.
- unknown message type fails closed.

Kill criteria:

- authenticated WebSocket can subscribe to any session id.
- delete command over WebSocket bypasses HTTP authz path.
- reconnect after role downgrade keeps old event access.
- lagging event replay leaks another tenant's receipt.

## Target Scope And Namespace Resolution

Remote root scope is not a path string.

```text
RemoteTargetScope
  root_ref
  canonical_root_identity
  owner_subject
  allowed_actions
  denied_subpaths
  mount_policy
  symlink_policy
  reparse_policy
  network_mount_policy
  cloud_root_policy
  cleanup_policy
```

Rules:

- remote target roots are configured server-side.
- client-provided absolute paths are not enough.
- symlink/reparse/mount escapes are denied unless explicitly allowed.
- network shares and cloud roots have reduced cleanup capability.
- every DeletePlan stores target scope version.
- scope change invalidates active destructive operations before side effects
  begin.

Kill criteria:

- `../../` or symlink escapes allowed root.
- Docker bind mount exposes host secrets and cleanup follows it.
- cloud root delete uses generic local cleanup policy.
- allowed root is sent by client.

## Audit And Receipts

Remote cleanup needs audit in addition to user-facing receipts.

```text
RemoteAuditEvent
  audit_event_id
  principal_ref
  host_ref
  os_user_ref
  deployment_profile
  auth_method
  action
  resource_ref
  target_scope_ref
  policy_version
  decision
  reason_code
  operation_id
  receipt_ref
  remote_addr_class
  created_at
```

Rules:

- audit records authorization allow/deny, scope deny, quota deny, destructive
  confirmation, execution start, receipt creation, support export, and policy
  changes.
- audit logs use redacted refs by default.
- receipts contain item outcomes and restore capability.
- audit retention and receipt retention are separate.
- remote support bundles include policy fingerprints, not secret values.
- audit is append-oriented and protected from ordinary cleanup.

Kill criteria:

- remote destructive operation has no actor in receipt.
- audit logs raw bearer token or raw path by default.
- support export can include another tenant's audit trail.
- policy change is not audited.

## Quotas And Abuse Resistance

Remote scanner/cleanup is an API service.

```text
RemoteQuota
  max_active_scans_per_principal
  max_active_cleanup_ops
  max_roots_per_scan
  max_delete_plan_items
  max_query_page_size
  max_event_replay_window
  max_support_bundle_size
  max_command_runtime
  max_daily_destructive_bytes
```

Rules:

- per-principal and global quotas both exist.
- cancellation, receipt write, and recovery are reserved even under quota
  pressure.
- expensive queries and exports have limits.
- remote cleanup has smaller blast-radius budgets than local cleanup.
- quota denials are typed errors and audit events.

Kill criteria:

- one remote user launches scans until daemon OOMs.
- one delete plan contains unbounded items.
- support bundle export fills disk.
- quota exhaustion prevents receipt write.

## Remote UX Safety

Remote UI must make host and scope impossible to miss.

Rules:

- destructive confirmation shows host, OS user/service account, target root,
  deployment profile, actor, policy, action kind, and restore capability.
- remote mode has distinct visual state from local desktop mode.
- read-only/analyze-only badges are visible.
- approval steps name the approver and policy version.
- no compact view hides remote host/scope before destructive action.

Kill criteria:

- user confirms cleanup without seeing host name.
- remote server looks identical to local desktop UI.
- admin approval hides target root or OS user.
- restore capability is shown without remote policy context.

## Architecture Placement

```text
crates/
  fs_usage_engine/
    src/
      domain/
        auth/
          authority_scope.rs
          protected_object.rs
          capability.rs
      application/
        ports/
          authorization_policy.rs
          audit_sink.rs
          quota_guard.rs
        services/
          authorize_command.rs
          build_remote_delete_plan.rs

apps/
  clean_disk_server/
    src/
      remote/
        deployment_profile.rs
        target_scope.rs
        remote_policy.rs
        audit_log.rs
        quotas.rs
      transport/
        http/authz.rs
        websocket/authz.rs
```

Layer rules:

- `fs_usage_engine` models authority concepts without owning remote auth.
- `clean_disk_server` owns deployment profile, policy, token/session handling,
  audit, quotas, and transport enforcement.
- Flutter displays capability and policy, but does not decide remote authz.
- reusable library never decides tenant authorization for a host application.

## Required Spikes Before Remote Cleanup

1. **Object-level authorization and scope fixture spike**
   🎯 9  🛡️ 10  🧠 8, roughly 1200-3400 LOC/tests.
   Prove session/node/cursor/selection/delete-plan/receipt/support-bundle object
   auth, cross-tenant denial, symlink/mount escape denial, and stale scope
   invalidation.

2. **WebSocket message auth and reconnect revocation spike**
   🎯 8  🛡️ 10  🧠 8, roughly 1000-2800 LOC/tests.
   Prove per-message auth, subscription filtering, role downgrade, reconnect
   refresh, event replay limits, and no cross-tenant leakage.

3. **Remote destructive policy, audit, and quota spike**
   🎯 8  🛡️ 10  🧠 9, roughly 1600-4200 LOC/tests.
   Prove read-only default, policy allowlist, approval receipt, audit redaction,
   emergency kill switch, and blast-radius quotas.

## Minimal Acceptance Gates

Before any remote destructive cleanup:

- remote profile is explicit and read-only by default;
- object-level auth exists for every protocol object;
- target roots are server-side scoped objects, not client paths;
- destructive capability is separate from scan/query capability;
- WebSocket messages are authorized per action;
- policy changes invalidate stale plans and subscriptions;
- audit records actor, host, target scope, action, policy, and outcome;
- quotas bound scans, queries, previews, delete plans, event replay, and support
  bundles;
- remote UI shows host, OS user, target root, policy, action, and restore
  capability before confirmation;
- emergency kill switch disables remote destructive actions.

## Decision

The next global critical zone is remote/headless destructive cleanup
authorization.

Implementation should keep remote/headless cleanup disabled until authorization,
target scope, object ownership, audit, quotas, WebSocket message auth, and
operator policy are proven with fixtures.

Practical rule:

```text
Remote cleanup is not local cleanup over HTTP.
It is a separate authority model around every destructive side effect.
```

