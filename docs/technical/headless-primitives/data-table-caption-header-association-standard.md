# Data Table Caption Header Association Standard

## Status

Accepted direction for Headless. Extends TreeGrid and grid foundation work. Not
implemented yet.

## Source Standards

- W3C WAI Tables Tutorial: https://www.w3.org/WAI/tutorials/tables/
- MDN HTML table accessibility: https://developer.mozilla.org/en-US/docs/Learn_web_development/Core/Structuring_content/Table_accessibility
- MDN `th`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/th
- MDN `caption`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/caption
- MDN `table`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/table
- WAI-ARIA APG Grid Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- WAI-ARIA APG Treegrid Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html

## Problem

Dense products often render table-looking layouts with rows, columns, sticky
headers, virtualization, resizable columns, and custom cells, but lose the
semantic relationships that make data understandable. Visual proximity is not
enough. A user must know which header applies to a cell, what the table is
about, which cells are row headers, whether headers are grouped, and whether
visible sorting changes the logical model.

Clean Disk relies on this for folder tree rows, details tables, delete queue
tables, scan history, compare views, support exports, and visual map legends.

## Decision Options

1. Treat table semantics as renderer responsibility - 🎯 4   🛡️ 4   🧠 2,
   about 80-200 LOC. Flexible but inconsistent and easy to break.
2. Add semantic table metadata to Headless grid contracts - 🎯 9   🛡️ 9
   🧠 6, about 500-1200 LOC. Best fit.
3. Require native HTML tables only - 🎯 5   🛡️ 8   🧠 7, about 300-900 LOC
   plus layout compromises. Too restrictive for Flutter and virtualization.

Accepted: option 2.

## Accepted Contract

Headless grids and table-like primitives expose structural metadata:

```dart
final class RDataTableSemantics {
  final String tableId;
  final String? caption;
  final String? summary;
  final List<RColumnHeaderSemantics> columnHeaders;
  final List<RRowHeaderSemantics> rowHeaders;
  final List<RHeaderAssociation> associations;
  final RTableComplexity complexity;
  final bool virtualized;
}
```

The renderer maps this to native semantics where available. When native table
semantics are unavailable, the adapter still exposes equivalent row, column,
caption, and header relationships through platform semantics.

## Table Complexity

```text
simpleOneHeader:
  one header row or one header column

simpleTwoHeader:
  row and column headers

groupedHeaders:
  header groups or spanning headers

multiLevelHeaders:
  multiple headers associated with one cell

virtualizedGrid:
  row and column metadata exist beyond mounted widgets

treeGrid:
  hierarchical row header plus columns
```

## Rules

- Every data table or grid has a caption or external accessible name.
- Row headers and column headers are explicit.
- Sort state belongs to the relevant header, not the whole table.
- Header associations are part of the semantic model, not visual layout.
- Virtualized cells must still know global row and column context.
- Sticky headers cannot become duplicate accessible headers.
- Hidden columns do not remain active headers unless their data is still
  included in accessible cell summaries.
- Cell text must not be the only way to infer data meaning.
- Layout tables are not represented as data tables.

## TreeGrid Rules

TreeGrid has a special row header:

- the hierarchy column is the primary row header;
- disclosure state belongs to the row header cell or row, depending on adapter;
- level, expanded/collapsed state, position, and selected state are separate
  from column header association;
- size, percent, items, modified, and warnings remain column data.

Clean Disk must not let the size bar alone convey percent or risk.

## Caption And Summary

Caption answers: what data is this?

Summary answers: how should a user navigate or interpret this complex table?

Examples:

```text
Caption:
  Folder sizes in the current scan

Summary:
  Rows are hierarchical folders. Use expand controls to reveal children. Size
  column is sorted descending. Values are scan snapshot estimates.
```

Summary is especially useful for virtualized, tree, comparison, or grouped
tables.

## Web Mapping

For web adapters:

- native `table`, `caption`, `th`, `scope`, `headers`, and `td` are preferred
  when layout allows;
- ARIA grid or treegrid mapping is used when interaction or virtualization
  requires composite behavior;
- `aria-rowcount`, `aria-colcount`, `aria-rowindex`, and `aria-colindex` are
  required for virtualized grids where supported;
- sort state maps to column header state.

## Flutter Mapping

Flutter adapters need semantic facts even when the render tree is not an HTML
table:

- row index;
- column index;
- column header label;
- row header label;
- selected and expanded states;
- sorted column;
- table caption or region label;
- virtualized total counts.

## Clean Disk Requirements

Clean Disk central table must expose:

- caption for current scan result;
- hierarchy row header;
- size, percent, items, modified, warnings, and actions columns;
- selected row state;
- sort state;
- row level and expansion;
- stale snapshot status when relevant;
- no raw path in semantic id.

Details and queue tables use the same contract at smaller scale.

## Testing Requirements

- Screen-reader row movement includes row header and relevant column header.
- Sort state is associated with the sorted column.
- Virtualized row 10,000 reports correct logical row position.
- Sticky header does not duplicate announcements.
- Hidden columns do not create misleading semantics.
- Caption and summary are discoverable.
- Tree row level and expansion remain correct after filtering.

## Failure Catalog

- Size cell announces `38.7` without header context.
- Sticky header is read twice.
- Row index resets to 1 after virtualization window changes.
- Sort icon is visual only.
- Hidden path column remains in copy or accessibility output.
- Caption says current scan while table shows stale cached snapshot.
- Row header is plain text with no hierarchy state.

## Release Gates

- `RDataTableSemantics` is available before public TreeGrid release.
- Clean Disk TreeTable facade maps all columns through table semantics.
- Web adapter has table or ARIA grid conformance tests.
- Flutter adapter has semantics tests for row, header, sort, and virtualization.
- Export adapters preserve header associations.

## Summary

Table meaning is structural, not visual. Headless must carry caption, summary,
row headers, column headers, and associations through every renderer, including
virtualized and treegrid layouts.
