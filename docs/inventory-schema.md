# Inventory schema

[Back to README](../README.md)

Current inventory `schemaVersion = 0.2`; supported historical inventory `schemaVersion = 0.1`. The producing software is identified separately by `collectorVersion = 0.5.0`. A software release does not necessarily require a schema revision.

## Document shape

| Property | Purpose |
|---|---|
| `schemaVersion` | Inventory contract version |
| `collectorVersion` | Producing software version |
| `collectedAt` | UTC collection timestamp |
| `computer` | Hostname, Windows/build, CPU, physical memory, local logical volumes |
| `tools[]` | Configured command inventory |
| `diagnostics.collectorResults[]` | System and DevelopmentTools collection envelopes, including their data/status/errors |
| `diagnostics.findings[]` | Interpreted diagnostic findings |
| `diagnostics.health` | PowerShell, Git, Python, Node, and virtualization evidence |
| `diagnostics.summary` | Finding-derived status, counts, attention items, and affected subsystems |

`collectorResults` is not a list of every health collector: health data is under `diagnostics.health`. Missing observations may appear as nulls, empty sections, or named evidence states. Consumers should check availability before interpreting a value.

## Tool fields

Every current tool entry has `id`, `displayName`, `status`, `selectedCommand`, `allCommandCandidates`, `version`, `diagnostics`, and `error`.

- `id` provides identity; `displayName` is for presentation.
- `selectedCommand` and `allCommandCandidates` explain command resolution, including paths and precedence.
- `version` is a parsed numeric token or null when it cannot be recognized; it is not an unfiltered version banner.
- `status` records probe outcome (`Available`, `Missing`, `Error`, or `TimedOut`). `Available` does not imply a recognized version or a healthy workstation.
- `diagnostics` contains local tool observations. Top-level diagnostic findings are authoritative for the health summary.
- `error` contains a fixed tool-probe failure/timeout message or null.

The old `command` process object and `rawVersion` are removed in 0.2, including from tool collector data. Properties named `command` can still legitimately occur in finding evidence as a command name or executable descriptor. They are not process results.

## Findings and summary

Findings contain `code`, `severity`, `category`, `title`, `message`, `affectedComponent`, `evidence`, and `recommendation`. Severity is `Info`, `Warning`, or `Error`; evidence is retained so interpretation can be assessed.

Summary `Problems` means at least one Error; `Attention` means Warnings but no Errors; `Healthy` means neither. `errorCount`, `warningCount`, and `infoCount` count findings. `attention` includes Errors/Warnings, ordered with Errors first; `affectedSubsystems` lists their distinct categories. There is no numeric health score and no claim of complete observation.

## Reading old baselines

Comparison accepts schemas 0.1 and 0.2 and projects both into the same comparable state. Legacy-only `command` and `rawVersion` do not create drift and are not copied into comparison output. No baseline rewrite is required. Unknown future schemas and missing schema versions are rejected, as are malformed tools/diagnostics structures. Validation is a compatibility check, not a general-purpose JSON Schema validator or a privacy scrubber for user-supplied objects.

Comparison documents have a separate `comparisonSchemaVersion = 0.1` and `comparisonVersion = 0.5.0`; see [comparison](comparison.md). For collected personal/workstation information, see [privacy](privacy.md).
