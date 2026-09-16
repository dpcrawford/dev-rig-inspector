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

## Quick start

From the repository root, in Windows (double-click, or run from any shell):

```
Start-DevRigInspector.cmd
```

This finds PowerShell 7 if it's installed and runs an inspection immediately. If PowerShell 7 isn't found, it prints installation guidance and exits without changing anything on your computer.

## Usage

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

## Troubleshooting

**`Import-Module` fails with "requires a minimum Windows PowerShell version of '7.0'"**

You're running Windows PowerShell 5.1. This is expected — Dev Rig Inspector requires PowerShell 7+. Start PowerShell 7 (`pwsh`) and re-run `Import-Module`, or use `Start-DevRigInspector.cmd`, which detects this automatically.
