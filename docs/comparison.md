# Baselines and comparison

[Back to README](../README.md)

Use a JSON inventory saved by `Invoke-DevRigInspection -OutputPath` as a baseline. A Markdown report is for reading, not comparison input. Preserve the baseline and collect the current inventory under the intended user/runtime/environment: command resolution and active virtual environments can legitimately differ between sessions.

## Input and output choices

| Pairing | Reference argument | Current argument |
|---|---|---|
| file/file | `-ReferencePath .\baseline.json` | `-CurrentPath .\inventory.json` |
| file/object | `-ReferencePath .\baseline.json` | `-Current $current` |
| object/file | `-Reference $baseline` | `-CurrentPath .\inventory.json` |
| object/object | `-Reference $baseline` | `-Current $current` |

Objects come from `Invoke-DevRigInspection -PassThru` or JSON parsed with `ConvertFrom-Json`. Comparison only reads supplied snapshots; it does not inspect the machine again. Either input may use inventory schema 0.1 or 0.2.

Console output is the default. `-PassThru` also returns the structured comparison. `-ReportPath .\comparison.md` writes Markdown and still renders the console report; parent directories are created and existing reports overwritten. There is no comparison `-OutputPath` or `-LogPath` parameter. For JSON:

```powershell
Compare-DevRigInspection `
    -ReferencePath .\baseline.json `
    -CurrentPath .\inventory.json `
    -JsonOnly | Set-Content -LiteralPath .\comparison.json -Encoding utf8
```

`-JsonOnly` emits a string without the console report; it cannot be combined with `-PassThru` or `-ReportPath`.

## What changes mean

- **Tools:** matched by `id`; reports Added, Removed, or Changed. Changed fields are version and status, not arbitrary properties or tool-array order.
- **Findings:** matched by a stable identity based on code, component, and relevant evidence. Reports NewFinding, ResolvedFinding, or SeverityChanged. Wording-only changes do not constitute new findings.
- **Health:** compares selected runtime/resolution/configuration/state fields for PowerShell, Git/GitHub CLI, Python, Node/npm, and virtualization. Credential-helper types and authenticated hosts are set comparisons; Python runtime membership is keyed by path; WSL distributions by name with distribution-version changes also reported.

Health comparisons require the corresponding evidence group on both sides. Missing historical sections are not automatically removals or regressions. Not every collected field participates: for example, Git identity configured/not-configured flags are compared rather than the actual name/email; WSL running/stopped state and default-distribution flags are not compared. Timestamp changes, legacy tool probe objects, and unrelated metadata do not create drift. An unchanged comparison means no changes in supported comparable evidence, not byte-identical snapshots or proof of health.

## Result contract

Current `comparisonSchemaVersion = 0.1` identifies the document contract; `comparisonVersion = 0.5.0` identifies the implementation. `reference` and `current` retain source type/path (null for object input), collection metadata, hostname, and inventory versions. `changes` groups tools, findings, and health. `summary` counts each change kind, health records and affected health subsystems; `totalChanges` counts records, not necessarily distinct real-world causes. One runtime upgrade can affect both tool and health records.

`machineIdentity` uses hostname, CPU, and memory evidence to report `LikelySame`, `PossiblySame`, `Different`, or `Insufficient`, with reasons. It is a heuristic, not a hardware identity guarantee, and never suppresses detected changes.

See [schema compatibility](inventory-schema.md) and [troubleshooting](troubleshooting.md) for rejected inputs.
