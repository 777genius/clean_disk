# Implementation Edge Cases - Search, Query, And Indexing

Last updated: 2026-05-13.

This file records edge cases for search, sorting, filtering, top lists, pagination, query language, read-model indexes, privacy, stale search results, and query performance.

Clean Disk's central workflow is not only scanning. The user needs to find large folders, caches, old downloads, build artifacts, duplicates in view, and risky cleanup candidates across a huge tree. Search and filters must be fast, but they must not become a second unsafe source of truth.

Related documents:

- [Implementation edge cases product workflows](implementation-edge-cases-product-workflows.md)
- [Implementation edge cases performance scale](implementation-edge-cases-performance-scale.md)
- [Implementation edge cases transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md)
- [Implementation edge cases recommendation rule engine](implementation-edge-cases-recommendation-rule-engine.md)
- [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md)
- [Implementation edge cases UI accessibility and i18n](implementation-edge-cases-ui-accessibility-i18n.md)
- [Rust best practices research](rust-best-practices.md)

## Sources Reviewed

- SQLite, [FTS5 Extension](https://www.sqlite.org/fts5.html). Relevant points: FTS5 tokenizes text into query terms, has prefix queries, query syntax details can be surprising, tokenizers control behavior, and index structures are separate from ordinary table rows.
- Rust `regex`, [crate documentation](https://docs.rs/regex/latest/regex/). Relevant points: Rust regex avoids unbounded backtracking and is designed to search untrusted haystacks, but search cost is still bounded by both pattern size and haystack size, so user regex needs limits.
- OWASP, [Regular expression Denial of Service](https://owasp.org/www-community/attacks/Regular_expression_Denial_of_Service_-_ReDoS). Relevant point: regex engines with problematic patterns can cause denial of service, so arbitrary regex/filter syntax is security-sensitive.
- Unicode Consortium, [UAX #15 Unicode Normalization Forms](https://unicode.org/reports/tr15/). Relevant points: Unicode has canonical and compatibility normalization forms; search/display normalization must be separate from filesystem identity.
- Microsoft Learn, [Windows case sensitivity](https://learn.microsoft.com/en-us/windows/wsl/case-sensitivity). Relevant points: Windows defaults to case-insensitive paths, but per-directory case sensitivity exists; tools can behave incorrectly in case-sensitive directories.
- Apple Developer Documentation, [Files and directories](https://developer.apple.com/documentation/technologyoverviews/files-and-directories). Relevant point from accessible summary/search result: code should handle case-sensitive names safely and use display names for UI where appropriate.
- W3C WAI-ARIA APG, [Treegrid pattern](https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/). Relevant points: treegrid focus, selection, expansion, sorting, and filter controls need explicit keyboard and screen-reader semantics.
- Tantivy, [crate documentation](https://docs.rs/tantivy/latest/tantivy/). Relevant points: Tantivy is a Rust search engine library with explicit index, segment, schema, index writer, searcher, and query concepts. It is a future candidate, not an accepted dependency.

## Severity Scale

- `P0` - search/filter results can select or queue the wrong node, leak private paths, bypass authorization, drive cleanup from stale results, or allow expensive queries to stall the daemon.
- `P1` - search/filter can be slow, nondeterministic, confusing after sorting/rescan, memory-heavy, inaccessible, or misleading about size/risk.
- `P2` - improves ranking, discoverability, saved searches, advanced operators, or future search engine integration.

## Top 3 Query Architecture Decisions

1. Rust-owned snapshot query service with simple indexed predicates in MVP - 🎯 10 🛡️ 10 🧠 5, roughly 700-1800 LOC across read-model indexes, query DTOs, pagination, tests, and Flutter stores.
2. Add a dedicated full-text/fuzzy search adapter later, still behind query ports - 🎯 7 🛡️ 8 🧠 7, roughly 1600-4500 LOC across index lifecycle, memory/disk storage, schema migrations, ranking, and stale handling.
3. Push search/filter to Flutter over a full tree copy - 🎯 2 🛡️ 2 🧠 4, roughly 300-900 LOC but wrong for this product. It violates the fixed rule that Rust owns full trees and large indexes.

My recommendation: MVP uses Rust query/read-model indexes for name/path substring, type, size, risk, modified-time, skipped/error state, and top-K views. Fuzzy/full-text search is a later adapter if measured need appears.

## Core Principle

Search is navigation, not authority.

Minimum search result model:

```text
SearchResult
  result_id
  scan_id
  snapshot_id
  index_version
  node_id
  display_name
  display_path
  node_kind
  size
  risk_summary
  freshness
  match_reason_codes[]
  matched_ranges[]
  parent_context[]
```

Rules:

- search results reference node identity, never only path text;
- search ranking never defines delete order;
- add-to-queue from search always creates a DeletePlan candidate that revalidates identity;
- result pages include snapshot/index version;
- query parsing is bounded, typed, and server-side;
- UI never filters the full tree client-side by holding all nodes.

## Bounded Context

### Query/Indexing Is A Read Model - `P0`

Search, sort, filter, and top lists are optimized projections over scan facts. They are not domain aggregates.

Required behavior:

- scan domain stores facts and identities;
- query/read-model infrastructure builds indexes/projections;
- application query services enforce snapshot, authorization, and stale rules;
- protocol DTOs return pages and summaries;
- cleanup consumes validated DeletePlan candidates, not raw search rows.

Avoid:

- putting fuzzy ranking inside domain rules;
- letting a search engine schema become the domain model;
- allowing query projection types to enter cleanup application logic.

### Query Features Are Product Contracts - `P1`

If users can sort by "Size" or filter "Cleanup candidates", behavior must be stable and explainable.

Required behavior:

- every filter has a named semantic definition;
- every sort has stable tie-breakers;
- search result pages state total count confidence: exact, capped, approximate, or unknown;
- result rows expose why they matched;
- UI labels distinguish "matches current snapshot" from "current filesystem".

Avoid:

- changing ranking/sort behavior silently between releases;
- reporting exact result counts when the query was capped;
- merging "largest", "recommended", and "safe" into one vague result list.

## Query Types And MVP Scope

### Start With Typed Filters, Not A Free-Form Query Language - `P0`

A powerful query language is attractive but becomes API compatibility and DoS surface.

MVP query types:

- `name_contains`;
- `path_contains`;
- `extension_in`;
- `kind_in`: file, folder, package, bundle, symlink, reparse point, unknown;
- `size_range`;
- `modified_range`;
- `risk_tier_in`;
- `recommendation_action_in`;
- `skipped_or_error`;
- `under_node`;
- `top_files`;
- `top_folders`;
- `children_page`.

Deferred:

- arbitrary regex;
- glob language;
- fuzzy search;
- boolean expression grammar;
- saved searches;
- cross-snapshot history search;
- content search.

Avoid:

- exposing raw SQL/FTS syntax to the UI;
- accepting unbounded free-form grammar in localhost/remote API;
- supporting regex before rate limits, pattern limits, and timeout/cancellation exist.

### Regex/Glob Filters Need A Separate Safety Decision - `P1`

Rust `regex` is safer than many backtracking engines, but user-supplied patterns can still be expensive and confusing. Other engines can have ReDoS risk.

Required behavior if regex is added:

- regex is opt-in advanced mode;
- use a bounded, non-backtracking engine where possible;
- cap pattern length, compiled size, result count, and search time;
- reject unsupported syntax with typed errors;
- never interpolate user text into another regex;
- query budget applies per session/user.

Avoid:

- enabling regex through an ordinary search box without clear mode;
- using platform/browser regex engines for server-side search semantics;
- letting a regex search block scanner or delete workers.

## Text Normalization Edge Cases

### Search Normalization Is Not Filesystem Identity - `P0`

Case-insensitive and Unicode-normalized search is useful, but the original filesystem path remains authoritative.

Required behavior:

- store original name/path bytes or platform representation for identity/display;
- build separate normalized search keys;
- search normalization policy is tagged in index metadata;
- search result maps back to node ID and identity snapshot;
- delete/preflight uses current filesystem identity, not normalized search text.

Avoid:

- lowercasing paths before identity comparison;
- assuming Windows case-insensitive behavior everywhere;
- assuming macOS APFS names are always normalization-insensitive;
- deduplicating search results by normalized path alone.

### Case Sensitivity Can Vary Within A Machine - `P1`

Windows can have per-directory case sensitivity. macOS can be case-sensitive or case-insensitive depending on volume. Linux is usually case-sensitive.

Required behavior:

- search can default to user-friendly case-insensitive matching;
- exact path operations stay platform-aware;
- display duplicate case-different names distinctly;
- query result tie-breakers include original name/path or node ID;
- tests include same-name-different-case fixtures where platform supports them.

Avoid:

- merging `Build` and `build` in UI selection;
- assuming a case-insensitive search match means one unique filesystem object;
- changing delete candidate identity after a case-only rename without revalidation.

### Path Display And Path Search Are Different - `P1`

Paths may contain separators, control characters, bidi text, localized display names, package/bundle display names, or platform-specific prefixes.

Required behavior:

- path search operates on a normalized search representation;
- path display escapes or visually isolates dangerous characters;
- matched ranges are based on display string version used by UI;
- raw path is not logged with query text;
- search supports long paths without layout overflow.

Avoid:

- highlighting based on byte offsets in a Unicode display string;
- showing raw control characters in search result rows;
- using localized display name as deletion target.

## Sorting And Pagination Edge Cases

### Stable Sort Is Required For Paging - `P0`

If sort order is unstable, page 2 can duplicate or skip rows.

Required behavior:

- every sortable view defines full tie-breakers;
- cursor includes snapshot ID, index version, parent/result scope, sort key, filter hash, and page boundary;
- server rejects stale cursor or returns an explicit resync result;
- equal-size/equal-name rows sort deterministically;
- internal `HashMap` iteration order never reaches protocol output.

Recommended tie-breakers:

```text
size desc, kind rank, display_name asc, path asc, node_id asc
modified desc, size desc, path asc, node_id asc
name asc, path asc, node_id asc
risk tier desc, size desc, path asc, node_id asc
```

Avoid:

- sorting by formatted size text;
- relying on filesystem traversal order;
- cursoring by row number only;
- exposing internal Vec index as a stable public ID.

### Filtered Tree Views Need Ancestor Context - `P1`

If a filter hides ancestors, users lose orientation and may queue the wrong item.

Required behavior:

- search/filter result includes parent context;
- tree mode can show matched descendants with ancestor chain;
- collapsed ancestors indicate hidden matches;
- add-to-queue shows full path and source context;
- details panel references node ID and snapshot.

Avoid:

- presenting search results as if they are siblings;
- queuing a folder without showing whether children are filtered;
- hiding parent/child conflicts in bulk search selection.

### Result Count Can Be Expensive Or Misleading - `P1`

Counting every match may require scanning a large index.

Required behavior:

- page responses can use `total_count_mode`: exact, capped, approximate, unknown;
- UI copy reflects capped results;
- top-K endpoints return explicit limit and cutoff;
- user can refine query rather than forcing exact count;
- metrics track query latency and scanned index entries.

Avoid:

- blocking UI for exact counts by default;
- saying "all results" when only first N are returned;
- using approximate count for cleanup totals.

## Index Lifecycle Edge Cases

### Indexing Is A Session Phase - `P1`

Post-scan indexing can dominate perceived latency after traversal.

Required behavior:

- scan status distinguishes traversal, aggregation, index building, ready, partial ready;
- children pages can become available before full search index is ready if safe;
- top-K indexes can stream early but must mark incomplete;
- cancellation stops indexing jobs too;
- resource exhaustion maps to typed degraded query capability.

Avoid:

- showing scan complete while search/top views are still missing;
- building every possible index before first useful UI;
- hiding index build time inside "scan" throughput claims.

### Lazy Indexing Needs Deterministic Behavior - `P1`

Lazy indexes reduce upfront cost but can surprise users.

Required behavior:

- first query can trigger an index build job with progress/capability state;
- query timeout returns `index_not_ready`, not a stuck spinner;
- multiple clients share one index build;
- stale snapshot invalidates lazy index;
- persisted indexes include schema/version and normalization policy.

Avoid:

- rebuilding the same index per client;
- making search latency randomly huge without status;
- using a stale persisted index with a newer scan snapshot.

### Top-K Views Should Avoid Global Sorts - `P1`

Largest files/folders are core views, but global sorting millions of nodes for every request is wasteful.

Required behavior:

- maintain bounded top-K indexes during aggregation where practical;
- keep top files, top folders, top recommendations, and skipped/error top lists separate;
- final top-K display has deterministic tie-breakers;
- changing accounting policy rebuilds affected top indexes;
- top-K pages state cutoff and snapshot identity.

Avoid:

- sorting all nodes every time user opens "Largest files";
- mixing folders and files without clear semantics;
- claiming top-K by reclaimable size when index is by apparent size.

## Search Engine Dependency Edge Cases

### SQLite FTS/Tantivy Are Adapter Choices, Not Architecture - `P1`

FTS5 and Tantivy are viable future implementation choices, but adopting either should not shape domain/application APIs.

Required behavior before adopting a search engine:

- define query contract first;
- measure index build time, memory, and disk size on realistic scans;
- verify Unicode/case behavior;
- verify prefix/substr behavior matches UX;
- verify snapshot/version isolation;
- keep engine schemas in infrastructure;
- provide fallback simple search for small scans or engine failure.

Avoid:

- exposing FTS query syntax directly through public API;
- adopting a full-text engine before simple path/name search is measured;
- storing private path indexes durably without retention/privacy policy.

### Substring, Prefix, Token, And Fuzzy Search Are Different Features - `P1`

Users expect search for `cache` to find `Cache`, `com.apple.CacheDelete`, `/Library/Caches`, and maybe `cachedData`. Different indexes handle those differently.

Required behavior:

- define matching modes explicitly;
- default mode favors predictable contains/prefix matching for names and paths;
- tokenized full-text search is a separate mode if added;
- fuzzy search is capped and visually marked;
- result reason says name match, path match, extension match, rule match, or fuzzy match.

Avoid:

- using a token index when UX promises substring matching;
- fuzzy matching hidden in normal search;
- ranking a fuzzy small file above exact huge folder without explanation.

## Privacy And Security Edge Cases

### Search Queries And Results Are Sensitive - `P0`

Search terms can reveal projects, clients, medical/legal topics, private apps, or secrets. Results reveal path structure.

Required behavior:

- query text is not logged by default;
- support bundles redact query text and result paths;
- remote mode authorizes every search against target scope;
- search snippets are scoped/redacted;
- saved searches are local/private and disabled by default until retention policy exists.

Avoid:

- sending query telemetry by default;
- storing search history forever;
- including raw query and full results in crash reports;
- letting remote user search outside allowed roots.

### Query Endpoints Need Budgets - `P0`

A search endpoint can be used for local or remote denial of service.

Required behavior:

- cap query length;
- cap page size;
- cap result count;
- cap regex/fuzzy complexity if supported;
- per-session and per-client query concurrency limits;
- cancellation for abandoned queries;
- slow query metrics without raw private paths.

Avoid:

- one query scanning every string on the daemon control thread;
- unbounded `contains` over every path on every keystroke;
- allowing many browser tabs to build duplicate indexes.

## UI And Accessibility Edge Cases

### Search Results Must Preserve Tree Meaning - `P1`

Clean Disk is a tree/table tool, not a flat search-only finder.

Required behavior:

- result rows show name, full path context, size, risk/recommendation summary, and stale state;
- result can reveal/open in tree without losing selection;
- selected result and focused row remain separate;
- after sort/filter/search, selection resolves by node ID;
- bulk actions show parent/child conflict normalization.

Avoid:

- hiding path context to save space;
- using row index as selection;
- losing keyboard focus when results update;
- making search result selection visually identical to queued-for-delete state.

### Sort/Filter Controls Need Explicit Semantics - `P1`

Treegrid sort/filter must be understandable for keyboard and assistive technology users.

Required behavior:

- sortable headers expose sort state;
- filter chips show active constraints;
- result count/capped count is announced or visible;
- no color-only indication for filters or stale results;
- compact layout keeps search/filter reachable without a permanent sidebar.

Avoid:

- hidden filter state that changes delete queue results;
- hover-only explanations for active filters;
- inaccessible custom dropdowns for sort/filter.

## Testing Edge Cases

### Query Invariants Need Property Tests - `P1`

Search/query bugs often show up only with equal names, equal sizes, renamed paths, empty pages, and stale cursors.

Required tests:

- stable sort with equal size/name/modified values;
- cursor rejects wrong snapshot/index/filter/sort;
- page boundaries do not duplicate or skip rows;
- search result add-to-queue revalidates identity;
- normalized search matches but does not merge identity;
- case-different names remain distinct where supported;
- result count modes are honest;
- query cancellation leaves no partial selection state;
- filter hiding parent still shows context;
- regex/fuzzy unsupported modes return typed errors.

### Fixture Matrix

Recommended fixture groups:

- million-node synthetic tree;
- many equal-size files;
- deeply nested long paths;
- Unicode composed/decomposed names;
- same-name-different-case names;
- names with control characters and bidi text;
- package/bundle directories;
- hidden/system folders;
- cloud placeholder names;
- symlink/reparse point names;
- stale snapshot after rescan;
- parent and child both matching search;
- huge single directory with many children.

## MVP Cut Line

Before first large tree UI:

- children pages are server-side sorted and paginated;
- cursors include snapshot/index/sort/filter identity;
- selection is by node ID, not row number;
- top files/folders are Rust-side queries;
- search can be disabled until index is ready.

Before first cleanup-capable beta:

- search result add-to-queue revalidates identity;
- filtered bulk queue normalizes parent/child conflicts;
- stale search results cannot execute old confirmation tokens;
- search query text is not logged by default;
- result pages include freshness and snapshot identity.

Before advanced search:

- query grammar is versioned;
- regex/fuzzy modes have complexity budgets;
- search index storage has retention/privacy policy;
- accessibility for search/filter/treegrid is tested;
- performance benchmarks include search/index build time.

## Summary

The safe stance:

```text
Search is navigation.
Index is projection.
Snapshot is context.
Node identity is authority.
Sort order must be deterministic.
Query text is private.
Advanced query syntax is an attack surface.
Search result never deletes anything directly.
```

The invariant:

```text
Clean Disk must never let search, sort, filter, ranking, or result pagination become the authority for filesystem identity or cleanup safety.
```
