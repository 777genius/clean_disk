# Scope Context Banner Authority Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Landmarks Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/landmarks/
- WAI-ARIA APG Breadcrumb Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/breadcrumb/
- MDN `status` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role
- MDN `aria-current`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-current
- MDN `aria-busy`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-busy
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 2.4.6 Headings and Labels: https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html

## Scope

This standard covers scope banners, context bars, authority banners, stale
snapshot banners, remote/headless mode banners, permission-quality banners,
read-only mode banners, and current target context surfaces.

It extends breadcrumb, capability, degraded/offline, and destructive safety
standards. It focuses on making the current authority scope visible and
semantic.

## Problem

Clean Disk can show current scan target, snapshot, daemon state, permission
quality, local/remote mode, stale cache state, and cleanup authority. If this
context is hidden in tiny nav text, users may act on the wrong target or stale
data. Headless needs a generic context banner contract because many products
have similar authority scopes.

## Decision Options

1. `ScopeContextBanner` with authority, freshness, and mode facts -
   🎯 9   🛡️ 10   🧠 7, roughly 800-1700 LOC.
   Best fit. It makes risky context explicit without making Headless know
   product policy.
2. Use breadcrumb only -
   🎯 6   🛡️ 6   🧠 3, roughly 200-600 LOC.
   Breadcrumb shows location, not permission quality, stale state, or mode.
3. Use notification banner only when something is wrong -
   🎯 5   🛡️ 5   🧠 3, roughly 200-600 LOC.
   Users still need normal current context, not only failures.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- scope id;
- scope kind;
- current target facts;
- freshness facts;
- authority facts;
- capability summary;
- mode flags;
- action descriptors;
- visibility policy;
- announcement policy;
- privacy class.

Renderer owns:

- compact banner visuals;
- icon treatment;
- breadcrumb/path placement;
- warning styling;
- collapse/expand visuals;
- responsive layout.

Application owns:

- actual authority decision;
- capability probing;
- target labels;
- repair actions;
- destructive-action gating;
- localization;
- logging policy.

## Scope Kinds

Kinds:

- local;
- remote;
- readOnly;
- destructiveAllowed;
- destructiveBlocked;
- staleSnapshot;
- degradedPermission;
- offline;
- reconnecting;
- historicalView;
- compareView;
- appDefined.

Unknown scope kind fails closed for risky actions in Clean Disk.

## Authority Facts

Authority fact includes:

- canRead;
- canQuery;
- canQueue;
- canPlanDelete;
- canMoveToTrash;
- canRestore;
- canExport;
- requiresRepair;
- reason codes;
- evidence version.

Headless displays facts. Application enforces policy.

## Freshness Rules

Freshness states:

- current;
- refreshing;
- stale;
- historical;
- incompatible;
- unknown.

Rules:

- stale context must be visible when risky actions exist;
- historical context cannot present current cleanup commands;
- refreshing context can show read-only data by policy;
- incompatible daemon/protocol blocks risky commands;
- freshness text is not hidden in tooltip only.

## Clean Disk Usage

Context banner can show:

- target volume or folder;
- scan snapshot;
- local daemon status;
- permission quality;
- read-only remote mode;
- stale cache;
- current path segment;
- cleanup capability.

Rules:

- banner never stores raw daemon token;
- raw path display follows path semantic standard;
- repair command routes through application;
- hidden banner state still blocks risky commands;
- banner collapse cannot hide critical destructive warnings.

## Community API Sketch

```dart
final class RScopeContextBannerModel {
  const RScopeContextBannerModel({
    required this.scope,
    required this.freshness,
    required this.authority,
    required this.commands,
  });

  final RScopeFact scope;
  final RFreshnessFact freshness;
  final RAuthorityFact authority;
  final List<RCommandDescriptor> commands;
}
```

## Conformance Scenarios

- stale snapshot banner is visible and semantic;
- read-only mode disables destructive commands;
- repair action is keyboard reachable;
- historical view cannot queue delete target;
- collapsed banner preserves critical warning;
- context update announces only important changes;
- private path is redacted by policy;
- unknown authority fails closed.

## Failure Catalog

- Current target appears only as tiny nav text.
- Stale snapshot looks current.
- Remote read-only mode still shows delete button.
- Banner collapse hides permission warning.
- Authority fact is enforced by renderer.
- Repair command bypasses application adapter.
- Raw daemon token appears in context UI.

