# Property List Details Inspector Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- MDN `<dl>` element: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/dl
- MDN `table` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/table_role
- MDN `group` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/group_role
- MDN `aria-details`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-details
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 2.4.6 Headings and Labels: https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html
- WCAG 1.4.10 Reflow: https://www.w3.org/WAI/WCAG22/Understanding/reflow.html
- Flutter Semantics: https://api.flutter.dev/flutter/widgets/Semantics-class.html

## Scope

This standard covers details panes, property lists, metadata inspectors,
definition lists, key-value tables, object summaries, file/folder details,
permission facts, warnings, read-only attributes, and compact inspector rows.

It does not cover editing forms. If a property can be edited, use form field
and validation standards.

## Decision Options

1. `PropertyList` primitive with typed property rows and semantic grouping -
   🎯 9   🛡️ 9   🧠 7, roughly 700-1600 LOC.
   Best fit. It gives details panes a real structure instead of ad hoc rows.
2. Render details as custom rows with text widgets -
   🎯 5   🛡️ 5   🧠 3, roughly 200-700 LOC.
   Quick, but relationships between labels, values, warnings, and commands are
   easy to lose.
3. Use data table for every property list -
   🎯 6   🛡️ 6   🧠 5, roughly 500-1200 LOC.
   Useful for dense comparable data, but heavy for simple object metadata.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- object identity for display only;
- property row ids;
- property labels;
- value model;
- value kind;
- group headings;
- stale/unknown/estimated state;
- warning and capability facts;
- copy/reveal/details command descriptors;
- privacy class for label, value, and command payload;
- relation between selected object and details surface.

Renderer owns:

- two-column layout;
- compact stacked layout;
- separators;
- icon visuals;
- value truncation;
- copy/reveal button visuals.

Application owns:

- actual metadata source;
- platform action execution;
- value formatting policy;
- authority validation;
- localized labels.

## Property Value Kinds

String:

- display text;
- may need bidi isolation.

Number:

- unit and precision required.

Boolean/state:

- must not rely on color only.

Path:

- sensitive by default;
- display path separate from authority path.

Date/time:

- absolute value plus locale formatting;
- avoid relative-only values for important metadata.

Capability:

- access, permission, scan quality, delete support;
- unknown fails closed for risky actions.

Warning:

- visible and semantic warning state;
- links to repair/details where available.

## Relationship Rules

Each visible property must keep:

- label associated with value;
- value associated with warning if present;
- command associated with the property it affects;
- group heading associated with contained properties.

Web adapter:

- use `<dl>` for simple key-value metadata;
- use table semantics for comparable dense matrix;
- use headings/regions for major groups;
- use `aria-details` only when adapter support and content shape justify it.

Flutter adapter:

- expose each row as semantic label/value where useful;
- avoid one huge concatenated details label;
- provide explicit copy/reveal actions through command descriptors.

## Reflow And Compact Rules

At compact width:

- two-column layout can become stacked;
- label and value relationship must remain clear;
- commands remain reachable;
- long paths and hashes use truncation plus explicit copy/details command;
- warnings do not move away from affected property.

## Clean Disk Usage

Selected node details:

- path;
- size on disk;
- logical size;
- item counts;
- modified time;
- permissions;
- warnings;
- provider/cloud state;
- cleanup recommendation facts.

Delete queue item details:

- selected display name;
- validated identity facts;
- reclaim confidence;
- restore capability;
- stale state.

## Privacy Rules

Sensitive values:

- full paths;
- usernames;
- cloud provider names where revealing account context;
- project/app names;
- scan queries;
- daemon ids.

Default behavior:

- do not log raw values;
- do not use raw value as widget key;
- do not put raw value into accessible name unless necessary;
- provide explicit copy command controlled by app policy.

## Conformance Scenarios

- screen reader can associate labels and values;
- compact layout preserves label/value relationships;
- path value is redacted in diagnostics;
- copy path command is explicit;
- unknown permission is not shown as allowed;
- warning is not color-only;
- stale details disable dependent actions;
- group headings remain meaningful after responsive reflow.

## Failure Catalog

- Details pane is one text blob.
- Property value appears without label after compact reflow.
- Full path becomes semantics label for entire pane.
- Copy action copies stale or display-only path.
- Warning appears in icon only.
- Unknown capability rendered as success.
