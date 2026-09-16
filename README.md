# Dev Rig Inspector

Windows developer-workstation diagnostics utility.

## Goals

- Inventory Windows and hardware
- Inventory installed development tools
- Produce structured JSON
- Produce readable console output
- Handle missing tools cleanly
- Be easy to extend

## Requirements

- Windows
- **PowerShell 7.0 or later** (the `pwsh` executable)

Dev Rig Inspector does **not** run on Windows PowerShell 5.1 (the `powershell.exe` that ships built into Windows). Check which one you're running with:

```powershell
$PSVersionTable.PSVersion
```

If `Major` is `5`, you're in Windows PowerShell 5.1 and need to switch to PowerShell 7. If PowerShell 7 isn't installed yet, install it with:

```powershell
winget install --id Microsoft.PowerShell --source winget
```

Dev Rig Inspector never runs this command for you — install PowerShell 7 yourself, then continue below.

## Quick start (source repository checkout)

If you cloned this repository, from the repository root, in Windows (double-click, or run from any shell):

```
Start-DevRigInspector.cmd
```

This finds PowerShell 7 if it's installed and runs an inspection immediately. If PowerShell 7 isn't found, it prints installation guidance and exits without changing anything on your computer. This launcher is a source-repository convenience — it is not included in the downloaded/installed package described below.

## Usage (source repository checkout)

For direct module access and the full parameter surface, use PowerShell 7 (`pwsh`) from the repository root:

```powershell
Import-Module .\src\DevRigInspector.psd1
Invoke-DevRigInspection -OutputPath .\output\inventory.json -LogPath .\output\inventory.log
```

The default mode writes only the readable console report. Use `-PassThru` when a PowerShell object is needed, `-JsonOnly` when JSON should be written to the pipeline, or `-OutputPath` to write JSON to a file. `-JsonOnly` and `-PassThru` cannot be combined. Tool definitions are maintained in `src\Collectors\ToolDefinitions.psd1`; the selected PATH command and all matching candidates are included in the result.

Run the focused tests with:

```powershell
.\scripts\Invoke-Tests.ps1
```

## Building a distributable package

To produce a versioned, installable copy of the module without the repository's tests/docs/scripts:

```powershell
.\scripts\Build-ModulePackage.ps1
```

This creates `dist\DevRigInspector-<version>\` (a ready-to-install module folder) and `dist\DevRigInspector-<version>.zip`. The build script validates the packaged manifest, imports the packaged copy, and confirms only `Invoke-DevRigInspection` and `Compare-DevRigInspection` are exported before creating the ZIP. The package does **not** include `Start-DevRigInspector.cmd`/`.ps1` — those launchers are source-repository conveniences only.

## Using a downloaded or installed package

If you received a ZIP or an already-installed copy of the module (not a source checkout), use normal PowerShell module behavior — there is no launcher script in the package.

Running directly from an extracted ZIP, without installing it anywhere:

```powershell
Import-Module .\DevRigInspector.psd1
Invoke-DevRigInspection
```

Installed by name, once placed under a module path (see below):

```powershell
Import-Module DevRigInspector
Invoke-DevRigInspection
```

To place the package under a module path first:

```powershell
$moduleRoot = Join-Path (Split-Path $PROFILE.CurrentUserAllHosts) 'Modules\DevRigInspector\0.5.0'
New-Item -ItemType Directory -Path $moduleRoot -Force
Copy-Item .\dist\DevRigInspector-0.5.0\* -Destination $moduleRoot -Recurse
```

## JSON contract

Inventory JSON is currently `schemaVersion = 0.2`. `Compare-DevRigInspection` also accepts historical `schemaVersion = 0.1` inventories (produced by v0.3/v0.4) so older baselines remain usable for comparison.

Raw external-command output (stdout/stderr/exit code from version-probe commands) is **not** part of the public inventory contract. Tool entries report curated fields (`id`, `displayName`, `status`, `version`, `selectedCommand`, `allCommandCandidates`, `diagnostics`, `error`) derived from that probe, not the raw process result itself.

The 0.2 schema removes the previously serialized `tools[].command` and `tools[].rawVersion` fields. Unrecognized tool versions are `null`, and tool probe errors use fixed messages rather than stdout, stderr, or exception text. Comparisons normalize both supported inventory schemas to the same curated fields, ignoring legacy raw fields; no baseline rewrite is required. The comparison schema remains `0.1` because its output contract is unchanged.

## Troubleshooting

**`Import-Module` fails with "requires a minimum Windows PowerShell version of '7.0'"**

You're running Windows PowerShell 5.1. This is expected — Dev Rig Inspector requires PowerShell 7+. Start PowerShell 7 (`pwsh`) and re-run `Import-Module`, or, from a source checkout, use `Start-DevRigInspector.cmd`, which detects this automatically.
