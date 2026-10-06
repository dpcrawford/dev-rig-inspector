# Dev Rig Inspector

Dev Rig Inspector inventories, analyzes, compares, and reports the health of a Windows development workstation without changing its configuration. It provides console reports, JSON snapshots, and Markdown reports for developers and IT professionals.

## What it does

**Inventory** records observed machine and tool information. **Health analysis** gathers subsystem evidence. **Diagnostics** interpret that evidence into findings and recommendations.

| Area | v0.5 coverage |
|---|---|
| Windows / system | OS/build, CPU, memory, local volume capacity and free space |
| PATH / command resolution | Missing directories, duplicate entries, selected commands and competing candidates |
| PowerShell | Active runtime, Windows PowerShell coexistence, execution-policy evidence |
| Git / GitHub CLI | Versions, Git identity/configuration, credential-helper types, authentication state |
| Python / uv / pip | Resolved runtimes, launcher, pip, uv, active virtual-environment evidence |
| Node.js / npm | Versions, launcher selection, global prefix/path evidence |
| .NET / VS Code | Resolved command and version inventory; no dedicated health subsystem |
| WSL / virtualization | Feature/query states, hypervisor/firmware evidence, distributions and readiness |

Discovery follows configured commands and Windows evidence; it is not an exhaustive software inventory. Saved snapshots can be compared without collecting the machine again.

## What it does not do

It does not repair configuration, optimize performance, install tools, or assign a numeric health score. It is not a security scanner or an endpoint-management platform. Recommendations are for you to assess and act on separately.

## Requirements

- **Windows**
- **PowerShell 7.0+** (`pwsh.exe`)

Windows PowerShell 5.1 (`powershell.exe`, included with Windows) and PowerShell 7+ are different runtimes. This module declares and targets PowerShell 7.0+; its process runner uses modern .NET APIs, including `ProcessStartInfo.ArgumentList`, that the Windows PowerShell 5.1 runtime does not provide. Merely having PowerShell 7 installed does not upgrade a running 5.1 session.

Check your current session:

```powershell
$PSVersionTable.PSVersion
```

If needed, install PowerShell 7 yourself, then open `pwsh`:

```powershell
winget install --id Microsoft.PowerShell --source winget
```

Dev Rig Inspector never runs installation commands for you. Normal inspection does not require elevation; some Windows feature evidence may be unavailable without it.

## Quick start

**Source checkout only:** from the repository root, run `Start-DevRigInspector.cmd` (or double-click it). In PowerShell:

```powershell
.\Start-DevRigInspector.cmd
```

The launcher finds `pwsh.exe` on PATH and immediately runs an inspection. If it cannot find PowerShell 7, it prints installation guidance and exits. The companion `Start-DevRigInspector.ps1` also guards against an older runtime. Neither launcher is included in the module ZIP.

For direct development use, open PowerShell 7 at the **source repository root**:

<!-- example: source-import -->
```powershell
Import-Module .\src\DevRigInspector.psd1
Invoke-DevRigInspection
```

## Installation

The module has not been published to PowerShell Gallery. Use a built ZIP or build one from source as described under Development.

**Extracted ZIP:** open PowerShell 7 in the extracted directory containing `DevRigInspector.psd1`. No installation is necessary:

<!-- example: zip-import -->
```powershell
Import-Module .\DevRigInspector.psd1
Invoke-DevRigInspection
```

**Optional current-user installation:** from that same extracted directory, copy the package into PowerShell's current-user module directory:

<!-- example: install-copy -->
```powershell
$moduleRoot = Join-Path (Split-Path $PROFILE.CurrentUserAllHosts) 'Modules\DevRigInspector\0.5.0'
New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null
Copy-Item .\* -Destination $moduleRoot -Recurse
```

This is an explicit installation you perform, not an inspection action. The parent `Modules` directory must be on `$env:PSModulePath`. In a new PowerShell 7 session you can then import by name from any directory:

<!-- example: installed-import -->
```powershell
Import-Module DevRigInspector
Invoke-DevRigInspection
```

The package contains the manifest/module, `Public`, `Private`, `Collectors`, this README, and `docs`. It does not contain the source launchers, tests, or build scripts.

## Basic inspection

After importing the module using the appropriate workflow above:

<!-- example: basic -->
```powershell
Invoke-DevRigInspection

$inventory = Invoke-DevRigInspection -PassThru
```

The default renders a console report. `-PassThru` also returns the structured inventory object; it does not suppress the console report. Only two public commands are exported: `Invoke-DevRigInspection` and `Compare-DevRigInspection`.

## JSON and Markdown reports

<!-- example: reports -->
```powershell
Invoke-DevRigInspection -OutputPath .\inventory.json

Invoke-DevRigInspection -ReportPath .\report.md

Invoke-DevRigInspection `
    -OutputPath .\inventory.json `
    -ReportPath .\report.md
```

These modes still show the console report. Parent output directories are created when needed; existing report files are overwritten. Use `-LogPath .\inspection.log` to append timestamped inspection progress and output-file locations to a log.

`-JsonOnly` returns a JSON **string** to the success pipeline and skips the console report. It can be combined with `-OutputPath` and `-LogPath`, but not `-PassThru` or `-ReportPath`:

<!-- example: json-only -->
```powershell
$json = Invoke-DevRigInspection -JsonOnly
$inventory = $json | ConvertFrom-Json
```

## Baseline comparison

Save a baseline before a planned change. Later, collect a current snapshot and compare it:

<!-- example: baseline -->
```powershell
Invoke-DevRigInspection -OutputPath .\baseline.json

$current = Invoke-DevRigInspection -PassThru

Compare-DevRigInspection `
    -ReferencePath .\baseline.json `
    -Current $current
```

Export that comparison as Markdown:

<!-- example: comparison-report -->
```powershell
Compare-DevRigInspection `
    -ReferencePath .\baseline.json `
    -Current $current `
    -ReportPath .\comparison.md
```

Each side independently accepts a file (`-ReferencePath` / `-CurrentPath`) or an inventory object (`-Reference` / `-Current`): file/file, file/object, object/file, and object/object are supported. Comparison does not recollect or update either snapshot. `-PassThru` returns a comparison object alongside the console report; `-JsonOnly` returns comparison JSON without the console report and cannot be combined with `-PassThru` or `-ReportPath`.

Comparison reports tool additions/removals and version/status changes, finding changes, and selected health-state changes. It is not a comparison of every JSON property. See [comparison behavior and JSON export](docs/comparison.md).

## Diagnostic severity

| Severity | Meaning |
|---|---|
| `Info` | Noteworthy, benign, or contextual evidence |
| `Warning` | Demonstrated misconfiguration or meaningful surprise/risk |
| `Error` | An installed, selected, or expected capability is materially broken |

Absence of an optional tool is not automatically a Warning. Read the finding's evidence and recommendation before deciding what to change. `Unknown` means the evidence does not support a conclusion; `Unavailable` means evidence could not be obtained; `ConflictingEvidence` means observations disagree. These are valid evidence outcomes, not automatic failures.

## Health summary

The summary is derived only from diagnostic findings:

| Status | Derivation |
|---|---|
| `Problems` | One or more Error findings |
| `Attention` | No Errors, one or more Warnings |
| `Healthy` | No Errors or Warnings |

Counts distinguish Errors, Warnings, and Info findings; attention items include Errors and Warnings. `Healthy` does not prove every possible capability was observable. **No numeric health score is used.**

## Privacy and read-only behavior

Inspection does not alter PATH, change execution policy, modify Git configuration, log into/out of GitHub, install/remove packages, change Python environments, modify npm configuration, enable/disable Windows features, or modify WSL/Hyper-V. Requested report/log files are expected output, not workstation remediation.

Schema 0.2 removes arbitrary raw external-command stdout/stderr from the public `tools[]` probe contract, including its copy in collector data. It excludes the old `command` and `rawVersion` fields. This is **privacy-conscious, not anonymous**: output can include hostname, executable paths, usernames in paths, configured Git name/email, runtime versions, and other workstation evidence. Some health fields retain selected command-derived text; there is no universal secret-redaction guarantee. Review reports before sharing. See [collected data and privacy boundaries](docs/privacy.md).

## Compatibility

| Field / support | Current value | Meaning |
|---|---|---|
| `collectorVersion` | `0.5.0` | Software producing the inventory |
| Inventory `schemaVersion` | `0.2` | Inventory document contract |
| Supported historical inventory schema | `0.1` | Older baselines accepted for comparison |
| `comparisonVersion` | `0.5.0` | Comparison implementation |
| `comparisonSchemaVersion` | `0.1` | Comparison document contract |

Equivalent inventories compare across 0.1 and 0.2 without drift from legacy raw tool fields. Unsupported or missing schema versions are rejected. See the [inventory schema](docs/inventory-schema.md) for field meanings and compatibility boundaries.

## Troubleshooting

An import error mentioning a minimum PowerShell version of `7.0` usually means you are in Windows PowerShell 5.1: open `pwsh`, then import again. A module-not-found error usually means the import path does not match your source/package layout or the installed module is outside `PSModulePath`.

Unavailable optional-feature queries, WSL with no detected distributions, and missing PATH directories need different interpretations. See [troubleshooting](docs/troubleshooting.md) for these cases and rejected comparison schemas.

## Development

**Source checkout only**, from the repository root in PowerShell 7 with Pester available:

```powershell
.\scripts\Invoke-Tests.ps1
.\scripts\Build-ModulePackage.ps1
```

The first command runs the full test suite with Pester 3.4.0 and fails on failed or empty suites. The second recreates `dist` and produces `dist\DevRigInspector-0.5.0\` and `dist\DevRigInspector-0.5.0.zip`, validating the manifest and the two public exports. It does not publish or install the module. Tool definitions live in `src\Collectors\ToolDefinitions.psd1`. See [architecture](docs/architecture.md) for the inspection and comparison pipelines, and the [release checklist](docs/release-checklist.md) for test dependency setup, CI, and `scripts/Test-Release.ps1` package acceptance.

Help is available after any supported import, including from the package:

<!-- example: help -->
```powershell
Get-Help Invoke-DevRigInspection -Full
Get-Help Compare-DevRigInspection -Full
```

## License

This project is licensed under the [MIT License](LICENSE).
