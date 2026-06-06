# Implementation Edge Cases - Remote And Headless Mode

Last updated: 2026-05-12.

This file records remote, headless, server, container, and multi-user deployment edge cases for Clean Disk.

Remote/headless mode is not "desktop mode over the network". It changes authority, identity, filesystem visibility, logging, audit, threat model, packaging, and user expectations. A local cleanup tool can assume one human and one machine. A remote/server tool cannot.

Related documents:

- [Implementation edge cases](implementation-edge-cases.md)
- [Implementation edge cases security privacy](implementation-edge-cases-security-privacy.md)
- [Implementation edge cases operational reliability](implementation-edge-cases-operational-reliability.md)
- [Implementation edge cases product workflows](implementation-edge-cases-product-workflows.md)
- [Implementation edge cases performance scale](implementation-edge-cases-performance-scale.md)
- [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md)
- [Rust architecture](rust-architecture.md)

## Sources Reviewed

- OWASP, [API Security Project](https://owasp.org/www-project-api-security/). Relevant points: broken object-level authorization, broken authentication, broken object-property authorization, unrestricted resource consumption, and unsafe consumption of APIs are core API risks.
- OWASP, [Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal). Relevant point: path parameters can be abused to access files outside the intended scope unless server-side authorization constrains them.
- OWASP, [Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html). Relevant points: audit/transaction logs and security event logs have different purposes; authentication failures, policy violations, and data exports need careful logging without over-collection.
- NIST, [Cybersecurity Framework 2.0 release](https://www.nist.gov/news-events/news/2024/02/nist-releases-version-20-landmark-cybersecurity-framework). Relevant point: govern, identify, protect, detect, respond, and recover form a lifecycle for managing cybersecurity risk.
- NIST, [SP 800-207 Zero Trust Architecture](https://csrc.nist.gov/pubs/sp/800/207/final). Relevant point: network location is not trust; authentication and authorization happen before access to resources.
- NIST, [SP 800-53 Rev. 5](https://csrc.nist.gov/Pubs/sp/800/53/r5/upd1/Final). Relevant point: access control, audit/accountability, identification/authentication, incident response, privacy, and supply-chain controls are separate control families.
- Docker, [Bind mounts](https://docs.docker.com/engine/storage/bind-mounts/). Relevant points: bind mounts are writable by default, affect host files, and remote Docker daemon mounts paths on the daemon host, not the client.
- Docker, [Volumes](https://docs.docker.com/engine/storage/volumes/). Relevant points: volumes persist outside a container lifecycle and can obscure existing directory contents.
- Docker, [Engine security](https://docs.docker.com/engine/security/). Relevant points: Linux capabilities and mounts influence container isolation; removing unnecessary capabilities is safer.
- Kubernetes, [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/). Relevant point: baseline/restricted profiles disallow privileged host access patterns such as host namespaces.
- Kubernetes, [RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/). Relevant point: least privilege should use specific resources and verbs; wildcards can accidentally grant future permissions.
- Kubernetes, [Security Context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/). Relevant points: `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation`, SELinux, AppArmor, seccomp, UID/GID, and supplementary groups affect filesystem access.
- Tailscale, [Access control](https://tailscale.com/docs/features/access-control). Relevant points: least privilege and zero-trust network access are useful, but network grants are not a replacement for app-level authorization.
- systemd, [systemd.exec](https://www.freedesktop.org/software/systemd/man/systemd.exec.html). Relevant points from the current man page/search result: service sandboxing can make filesystems read-only with `ProtectSystem`, then allowlist writes with `ReadWritePaths`; `NoNewPrivileges` and namespace restrictions affect service authority.

## Severity Scale

- `P0` - must be handled before any remote/headless public use.
- `P1` - should be handled before private beta with real remote machines.
- `P2` - useful hardening or enterprise polish after the core remote shape is stable.

## Top 3 Remote Decisions

1. Remote mode is read-only scan/query by default - 🎯 10 🛡️ 10 🧠 4, roughly 150-450 LOC across mode config, capability flags, UI gating, and command rejection tests.
2. Per-user authorization on every session/object/action - 🎯 9 🛡️ 10 🧠 8, roughly 900-2500 LOC across identity, auth middleware, application policies, resource ownership, audit, and tests.
3. Explicit scan target scopes instead of arbitrary remote paths - 🎯 9 🛡️ 9 🧠 6, roughly 500-1300 LOC across target registry, allowed roots, path normalization, display labels, and path traversal tests.

## Core Remote Principle

Remote/headless mode must never inherit local trust assumptions.

Local mode:

- one OS user;
- loopback-only daemon;
- local ephemeral token;
- UI and daemon usually run on the same machine;
- Trash belongs to the current user;
- reveal/open path can use local file manager.

Remote/headless mode:

- one or many API users;
- network-visible endpoint;
- real authentication and authorization;
- server filesystem may not match UI machine;
- Trash may be absent or service-user scoped;
- reveal/open path often makes no sense;
- audit and retention become product obligations.

## Deployment Modes

### Local Desktop Mode - `P0`

This remains the primary MVP mode.

Allowed:

- loopback-only listener;
- random local port;
- local session token;
- current-user daemon;
- move-to-trash with local platform adapter;
- local reveal in Finder/Explorer/file manager.

Not allowed:

- binding to `0.0.0.0` accidentally;
- remote browser connecting through a forwarded port and receiving delete capability;
- using local token model as remote authentication.

### Local Web UI To Local Daemon - `P0`

This is still local mode even though the UI is web.

Implementation rule:

- web UI must display that scan target is local machine;
- local daemon validates token, Origin, Host, and protocol version;
- browser storage cannot be the source of truth for daemon endpoint;
- delete actions still require server-side confirmation and identity validation.

### Remote Read-Only Server Mode - `P0`

This is the first safe remote profile.

Allowed:

- authenticated users can start/query scans within allowed roots;
- users can view own sessions and summaries;
- admin can view capability/status summaries if explicitly allowed;
- no cleanup commands;
- no direct file content download unless separately designed.

Implementation rule:

- `capabilities.cleanup.* = false`;
- UI labels target host/user/context on every scan summary;
- API rejects destructive commands even if client sends hidden requests;
- support bundle is user/session scoped.

### Remote Delete-Capable Mode - `P0`, Deferred

Remote cleanup is a separate product mode, not a config toggle.

Required before enabling:

- real authentication;
- authorization per user, target, path scope, and action;
- audit policy;
- retention policy;
- trash/quarantine strategy;
- operator approval model if shared server;
- recovery plan for interrupted delete;
- visible target host in confirmation and receipt;
- staged rollout behind feature flag.

MVP rule:

- remote delete-capable mode is disabled.

### Headless Single-User CLI/Server Mode - `P1`

This can be useful for personal servers.

Implementation rule:

- still uses explicit config file;
- default listen is loopback unless remote flag is passed;
- cleanup disabled unless explicitly enabled and supported;
- service user is visible in `/capabilities`;
- UI labels "running as user X on host Y".

### Container Mode - `P1`

Containerized Clean Disk sees the container's filesystem namespace, not magically the host.

Implementation rule:

- report container/sandbox context when detectable;
- scan targets are mounted paths, not host paths;
- if a target is a bind mount, label it as host-mounted where detectable;
- cleanup disabled by default for bind-mounted host paths;
- receipts include container id/context if available.

## Authentication And Authorization

### Authentication Is Not Authorization - `P0`

A logged-in user can still be unauthorized for a scan target, delete plan, receipt, or event stream.

Implementation rule:

- identity middleware authenticates the principal;
- application service authorizes every command/query against resource ownership and policy;
- object IDs are untrusted input;
- WebSocket subscription authorization is checked for each session/event stream;
- authorization failure does not reveal whether another user's path/session exists.

### Object-Level Authorization - `P0`

OWASP API Security names broken object-level authorization as the first API risk. Clean Disk has many object IDs.

Objects needing authorization:

- scan session;
- scan target;
- node/page query;
- search result;
- selected node details;
- delete plan;
- receipt;
- event stream;
- support bundle;
- export job;
- server status.

Implementation rule:

- every object carries owner/principal or policy scope;
- handlers do not fetch by ID and then rely on UI hiding;
- repository/query methods should accept authorization context or pre-authorized scope;
- tests attempt cross-user access for every object type.

### Object-Property Authorization - `P1`

Not every authorized user should see every field.

Sensitive fields:

- full path;
- username/home directory;
- raw OS errors;
- permission bits/ACL summaries;
- delete receipt details;
- token id;
- remote host internals;
- support bundle metadata.

Implementation rule:

- DTO projection is policy-aware;
- admin and owner views can differ;
- public/shared dashboard never gets raw private paths by accident;
- adding fields to DTOs requires sensitivity classification.

### Session Tokens Are Not Enterprise Auth - `P0`

Local ephemeral tokens are for browser-to-local-daemon protection. They are not remote identity.

Remote auth options:

1. Reverse proxy/OIDC in front of daemon - 🎯 8 🛡️ 8 🧠 6, roughly 500-1500 LOC including trusted headers and tests.
2. Built-in bearer tokens/users - 🎯 7 🛡️ 6 🧠 6, roughly 600-1800 LOC. Easier self-hosting, more security ownership.
3. Read-only SSH tunnel / Tailscale-only personal mode - 🎯 7 🛡️ 7 🧠 4, roughly 250-800 LOC. Good for personal use, not enough for multi-user product authorization.

Recommendation:

- support reverse-proxy/OIDC-style identity later;
- keep built-in auth minimal until product need is clear;
- treat tunnels/Tailscale as network transport protection, not app authorization.

### Network ACLs Are Helpful But Insufficient - `P1`

Tailscale grants, VPNs, firewalls, and SSH tunnels reduce exposure but do not answer "can this user delete this target".

Implementation rule:

- network allowlist is defense-in-depth;
- daemon still authenticates and authorizes application actions;
- remote UI still shows security mode and target host;
- no "VPN means admin" shortcut.

## Target Scope And Path Authority

### Remote Scan Targets Must Be Registered - `P0`

Arbitrary path input is too risky in remote/server mode.

Implementation rule:

- server exposes configured target roots with IDs and display names;
- user chooses target ID, not raw root path;
- query paths are relative to a target scope where possible;
- raw absolute path scans require admin policy and audit;
- target config says read-only, cleanup-supported, hidden, or admin-only.

Example target model:

```text
target_id: "home-cache"
display_name: "User cache"
root: "/home/alice/.cache"
owner_policy: "user:alice"
cleanup_capability: "read_only"
path_visibility: "owner_only"
```

### Path Traversal Is A Remote API Bug - `P0`

Any endpoint that accepts a path-like value can be abused.

Implementation rule:

- no endpoint accepts `../../etc/passwd`-style authority;
- canonicalization is not the only defense;
- resolved path must remain inside authorized target scope;
- symlink/reparse/mount traversal follows target policy;
- errors are typed and do not leak existence outside allowed scope.

Tests:

- `../`;
- URL-encoded traversal;
- mixed separators;
- absolute path injection;
- symlink out of target;
- mount/bind out of target;
- Unicode lookalikes and control characters.

### Server Filesystem View Must Be Visible - `P1`

The web UI may run on laptop while daemon scans a server/container.

Implementation rule:

- scan summary includes host label and execution context;
- path display includes "remote path";
- local reveal actions hidden;
- delete confirmation repeats remote host/context;
- receipts include host id/context.

### Shared Filesystems Are Not Local Folders - `P1`

NFS, SMB, NAS, EFS, network shares, and distributed filesystems can have server-side snapshots, quotas, stale handles, ACLs, and caching.

Implementation rule:

- detect/network-classify when possible;
- mark reclaim estimate confidence lower;
- cleanup disabled or high-warning by default;
- server-side Trash/snapshot semantics are not assumed;
- "freed space" may not appear immediately or for this user.

## Remote Cleanup And Trash

### Trash May Not Exist - `P0`

Headless Linux or container mode may not have a desktop Trash service.

Implementation rule:

- unsupported Trash disables cleanup capability;
- no silent fallback to permanent delete;
- remote cleanup needs a quarantine/trash design if platform Trash is absent;
- "move to Trash" label is not shown unless true.

### Service User Trash Is Not Human User Trash - `P0`

A daemon running as `clean-disk` or in a container may move files to a Trash location the real human cannot inspect easily.

Implementation rule:

- capability reports effective user and Trash scope;
- confirmation says which account performs cleanup;
- receipt shows platform outcome and location if available;
- UI provides recovery instructions appropriate to service user.

### Remote Permanent Delete Is Deferred - `P0`

Permanent delete over a network is high-risk.

Required before considering:

- policy flag;
- extra confirmation;
- object identity revalidation;
- strong audit;
- backup/snapshot warning;
- per-target allowlist;
- rate limits;
- hostile filesystem tests.

MVP rule:

- no remote permanent delete.

### Quarantine Can Be Safer Than Trash - `P1`

For servers, moving to an app-owned quarantine directory may be more predictable than platform Trash, but it has storage and security tradeoffs.

Implementation options:

1. Read-only remote MVP - 🎯 10 🛡️ 10 🧠 3, 100-300 LOC. Best first release.
2. App-owned quarantine per target - 🎯 7 🛡️ 7 🧠 8, 700-2000 LOC. Useful later, but must handle permissions, disk pressure, retention, restore, and cross-volume moves.
3. Native platform Trash only where supported - 🎯 8 🛡️ 8 🧠 6, 500-1500 LOC. Good for desktop/server-with-user-session, weak for headless/container.

Recommendation:

- start with option 1;
- evaluate option 2 only after audit/retention design exists.

## Containers, Kubernetes, And systemd

### Docker Bind Mounts Are Dangerous Cleanup Targets - `P0`

Docker bind mounts are writable by default and can modify host files.

Implementation rule:

- if running in container, bind-mounted targets are read-only by Clean Disk unless explicitly configured;
- UI labels bind-mounted targets as host-mounted;
- cleanup on bind mounts requires separate target policy;
- volume/bind mount detection should be part of capability reporting where possible.

### Docker Volumes Persist Outside Containers - `P1`

Volumes can survive container removal and are often stateful data stores.

Implementation rule:

- do not recommend deleting Docker volumes as ordinary folders;
- classify Docker volumes as tool-owned persistent data;
- future Docker cleanup should use Docker API/CLI with preview and volume-specific warnings;
- scan can show volume size, but cleanup is high-risk.

### Remote Docker Daemon Path Confusion - `P1`

Docker docs note that bind mounts attach paths from the daemon host, not the client.

Implementation rule:

- if Clean Disk manages or inspects Docker-based targets, label the daemon host;
- never imply a browser/client local path is mounted into a remote Docker daemon;
- remote target setup UI must say which machine owns the path.

### Kubernetes Pod Security Changes Filesystem Truth - `P1`

Kubernetes security contexts affect visible UID/GID, groups, capabilities, root filesystem writability, and volume access.

Implementation rule:

- container image should run as non-root for remote scanner mode where feasible;
- use `readOnlyRootFilesystem` for app root and mount only app data/targets explicitly;
- set `allowPrivilegeEscalation: false` when possible;
- do not use privileged pods, hostPID, hostIPC, hostNetwork, or hostPath for normal mode;
- if hostPath is used, it is a high-risk deployment profile.

### Kubernetes RBAC Is For Cluster API, Not Filesystem Cleanup - `P1`

Kubernetes RBAC governs Kubernetes API access. It does not authorize filesystem deletion inside mounted volumes.

Implementation rule:

- Kubernetes RBAC least privilege still matters for deployment;
- Clean Disk app-level authorization still governs scan/delete sessions;
- no wildcard RBAC verbs/resources unless absolutely required;
- no service account token exposure in support bundles.

### systemd Service Hardening Can Break Scans - `P1`

systemd sandboxing can make filesystems read-only or inaccessible, which is good for service hardening but can make scan/delete behavior confusing.

Implementation rule:

- headless service profile documents required `ReadWritePaths` for app data and scan targets;
- `ProtectSystem=strict` is good for daemon code paths but scan targets need explicit access;
- `NoNewPrivileges` and reduced capabilities are preferred;
- capability endpoint reports hardened/sandboxed mode where detectable;
- permission errors caused by service sandbox are distinct from filesystem ACL denial.

## Multi-User State And Concurrency

### Operation Ownership - `P0`

Every remote operation needs an owner and policy.

Implementation rule:

- scan sessions have owner principal;
- observers are separate from command owners;
- delete plans are bound to owner, target scope, plan hash, and confirmation;
- admin access is explicit and audited;
- ownership is checked on status, events, pages, details, exports, and receipts.

### Shared Scan Results Can Leak Paths - `P0`

Sharing one scan across users sounds efficient but can leak private paths.

Implementation rule:

- default scan result visibility is owner-only;
- shared/team scan requires explicit target policy;
- per-row path visibility is policy-aware;
- support bundles are scoped by user/session;
- remote dashboards show aggregate counts without raw paths unless authorized.

### Multiple Users Can Race Cleanup - `P0`

Two users can queue overlapping paths or one user can delete while another scans.

Implementation rule:

- delete plans acquire operation-level conflict checks;
- target scope has active cleanup lock or conflict policy;
- stale scan data is revalidated before cleanup;
- failed/conflicted items remain explicit outcomes;
- UI shows "changed by another operation" state.

### Quotas And Fairness - `P1`

Remote daemon can be used by many users.

Implementation rule:

- per-user active scan limit;
- per-target active scan limit;
- per-user query/search rate limit;
- max page size;
- max export size;
- max support bundle size;
- admin-visible resource pressure metrics.

## Audit, Privacy, And Retention

### Audit Is Not Debug Logging - `P0`

Remote cleanup needs accountability, but raw path logs can leak sensitive data.

Implementation rule:

- audit record includes actor, operation id, target id, action, outcome, timestamps, and redacted path summary;
- full path appears only in owner-visible receipt or encrypted/local protected store where required;
- audit log and debug log are separate;
- audit records are append-oriented;
- audit export is role-gated.

### Retention Policy Is Required Before Remote Cleanup - `P0`

Remote receipts and audit records can become sensitive datasets.

Implementation rule:

- define retention periods for scan history, receipts, audit, logs, support bundles, and exports;
- owner can delete personal scan history where product policy allows;
- destructive audit may need longer retention than scan cache;
- support bundles expire or are manually removed;
- remote mode documents where data is stored.

### Data Minimization For Remote APIs - `P1`

Remote APIs should not return every property just because local UI needs it.

Implementation rule:

- query DTOs are projection-specific;
- details endpoint returns sensitive metadata only with permission;
- list endpoints return summaries;
- errors avoid path existence leaks;
- search snippets are redacted or scoped.

### Incident Response Path - `P1`

Remote mode can be abused or misconfigured.

Implementation rule:

- admin can revoke sessions/tokens;
- admin can disable cleanup globally;
- server can enter read-only safe mode;
- audit query supports operation id and actor filters;
- support bundle can include security-mode summary without tokens.

## Transport And Exposure

### TLS / Reverse Proxy Decision Must Be Explicit - `P0`

Remote HTTP/WebSocket cannot use local daemon assumptions.

Implementation rule:

- remote mode requires TLS directly or trusted reverse proxy;
- if behind reverse proxy, trusted headers are allowlisted and documented;
- client origin/CORS policy is explicit;
- WebSocket auth is equivalent to HTTP auth;
- no bearer tokens in URLs.

### SSH Tunnel Is A Deployment Pattern, Not Product Auth - `P1`

SSH local port forwarding can be convenient for private use.

Implementation rule:

- tunnel mode can be documented as personal/dev deployment;
- app still sees connection as remote profile if daemon is remote;
- delete capability remains disabled unless explicit server-side policy exists;
- UI labels target host to avoid "my laptop disk" confusion.

### Public Internet Exposure Is Not MVP - `P0`

Clean Disk can read private paths and may later delete files. Public exposure is high risk.

Implementation rule:

- no public listen config in MVP;
- remote read-only private network is the first remote target;
- internet exposure requires threat model, auth, rate limits, TLS, security headers, audit, and update policy;
- admin docs include a clear warning.

## UI Requirements For Remote Mode

### Host/Context Must Be First-Class - `P0`

User must always know which machine is being scanned.

UI must show:

- host display name;
- execution context: local, remote, container, sandbox, service user;
- target root label;
- scan owner;
- cleanup capability;
- read-only/delete-capable mode;
- last handshake time and daemon version.

### Remote Confirmation Copy Is Different - `P0`

If remote cleanup is ever enabled, confirmation needs more context than local.

Required confirmation fields:

- remote host;
- service/effective user;
- target scope;
- operation owner;
- item count;
- risk tier summary;
- trash/quarantine/permanent action type;
- receipt/audit retention note.

### Local Actions Must Disappear - `P1`

Remote mode cannot offer local-only actions.

Implementation rule:

- hide "Reveal in Finder/Explorer";
- replace with "Copy remote path" only if allowed;
- no drag-out local path;
- no browser file picker as scan authority;
- export reports clearly label remote host.

## Testing Matrix

### Authorization Tests

- user cannot query another user's scan session;
- user cannot subscribe to another user's WebSocket stream;
- user cannot query another user's node details;
- user cannot access another user's receipt;
- admin read access is explicit and audited;
- hidden cleanup button cannot bypass server-side policy;
- object-property projection hides raw paths for unauthorized roles.

### Target Scope Tests

- target ID required for remote scans;
- raw absolute path rejected for non-admin;
- traversal outside target rejected;
- symlink outside target follows policy;
- mount/bind outside target follows policy;
- target deleted or changed during scan returns typed state.

### Remote Mode Tests

- remote daemon starts read-only by default;
- cleanup endpoint returns capability error;
- UI displays remote host and read-only mode;
- old UI cannot assume local reveal action;
- WebSocket reconnect restores authorized state only;
- no token/header appears in logs/support bundle.

### Container Tests

- daemon running in Docker reports container context where feasible;
- bind-mounted target labeled;
- cleanup disabled by default on bind mount;
- read-only bind mount scan succeeds and cleanup disabled;
- named volume classified as persistent tool-owned data;
- Docker Desktop VM path confusion documented in target label.

### Kubernetes/systemd Tests

- non-root container can scan allowed volume;
- read-only root filesystem with writable app data works;
- missing `ReadWritePaths` produces sandbox permission state;
- `allowPrivilegeEscalation=false` profile still starts;
- no host namespace/privileged mode in default manifests;
- service account token excluded from support bundle.

### Audit/Retention Tests

- audit record created for auth failure;
- audit record created for remote scan start/cancel;
- cleanup attempt in read-only mode audited as denied if security policy requires;
- full raw path not present in admin audit summary;
- receipt retention and scan cache retention are separate;
- support bundle expires or can be deleted.

## MVP Cut Line

Must be true before remote/headless preview:

- remote profile is explicit;
- remote profile is read-only by default;
- no remote cleanup;
- real authentication strategy selected or reverse proxy identity accepted;
- object-level authorization for sessions/events/receipts;
- target registry instead of arbitrary path input;
- host/context labels in UI;
- capability handshake advertises remote/read-only/container/sandbox;
- support bundle redacts remote auth and service account data;
- rate limits and max page/export sizes;
- path traversal tests;
- cross-user access tests.

Can wait:

- remote cleanup;
- app-owned quarantine;
- multi-tenant admin console;
- OIDC built-in login UI;
- Kubernetes operator/chart;
- systemd hardening templates;
- full enterprise audit retention controls;
- public internet deployment docs.

## Summary

📌 Remote invariant: remote mode starts as authenticated read-only analysis, not cleanup.

The strongest product shape is:

- local desktop remains the first delete-capable product;
- remote/headless mode uses the same command/query/event contract but stricter capability gates;
- every remote object is authorized server-side;
- scan targets are registered scopes, not arbitrary path strings;
- containers and services report their real filesystem context;
- network ACLs and tunnels are helpful but never replace app authorization;
- remote cleanup stays disabled until authorization, audit, retention, and recovery are designed.
