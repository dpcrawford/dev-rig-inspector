# Dev Rig Inspector

Windows developer-workstation diagnostics utility.

## Goals

- Inventory Windows and hardware
- Inventory installed development tools
- Produce structured JSON
- Produce readable console output
- Handle missing tools cleanly
- Be easy to extend

## Usage

The utility requires PowerShell 7 and Windows built-in facilities. From the repository root:

```powershell
Import-Module .\src\DevRigInspector.psd1
Invoke-DevRigInspection -OutputPath .\output\inventory.json -LogPath .\output\inventory.log
```

The default mode writes only the readable console report. Use `-PassThru` when a PowerShell object is needed, `-JsonOnly` when JSON should be written to the pipeline, or `-OutputPath` to write JSON to a file. `-JsonOnly` and `-PassThru` cannot be combined. Tool definitions are maintained in `src\Collectors\ToolDefinitions.psd1`; the selected PATH command and all matching candidates are included in the result.

Run the focused tests with:

```powershell
.\scripts\Invoke-Tests.ps1
```
