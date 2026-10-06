# Troubleshooting

[Back to README](../README.md)

## Windows PowerShell 5.1 versus PowerShell 7

Check `$PSVersionTable.PSVersion`. If its major version is 5, start `pwsh` and retry the import there. The manifest's minimum-version error is expected in Windows PowerShell 5.1. From a source checkout, `Start-DevRigInspector.cmd` selects `pwsh.exe` on PATH; the `.ps1` launcher prints guidance instead of importing in an older runtime. If PowerShell 7 is installed but not on PATH, open it directly and use the direct module import. No launcher installs PowerShell or changes execution policy.

## Module not found / wrong working directory

| What you have | Working directory for relative import | Command |
|---|---|---|
| Source checkout | Repository root | `Import-Module .\src\DevRigInspector.psd1` |
| Extracted module ZIP | Directory containing the manifest | `Import-Module .\DevRigInspector.psd1` |
| Installed module | Any directory | `Import-Module DevRigInspector` |

For installed-by-name discovery, inspect `$env:PSModulePath -split [IO.Path]::PathSeparator`. The package belongs in `DevRigInspector\0.5.0` under one of those directories. The extracted module ZIP does not contain source launchers or `scripts`; a source archive is not the same layout as a built module ZIP. Direct import by absolute manifest path is also supported. If loading is blocked by local policy, follow your organization's policy; this utility does not change it.

## Optional-feature queries unavailable

Some Windows optional-feature queries need elevation or are unavailable in the current environment. `Unavailable` describes missing evidence, not proof that the feature is disabled. You can leave it unobserved or, if appropriate for your environment, rerun in an elevated PowerShell 7 session for fuller evidence. Inspection never elevates itself or enables a feature. Other observed configuration, such as a WSL 2 distribution with incomplete readiness evidence, may still produce a finding; read that evidence rather than interpreting every unavailable query as failure.

## WSL installed with no distributions

The presence of `wsl.exe` and detected distributions are separate observations. No detected distributions does not by itself imply a broken installation. `distributionParseStatus = NoneOrUnknown` can mean an empty list or output the parser could not interpret; `Unavailable` means list evidence could not be obtained. Localized or changed command output can limit parsing. Do not infer that a distribution was removed merely from unavailable evidence.

## PATH entries point to nonexistent directories

A missing PATH directory is a demonstrated configuration surprise and can produce a Warning. It may be left over from an uninstall or refer to a location that is currently unavailable. Inspect the recorded path and context before deciding whether it is obsolete. The report never edits PATH. Multiple command locations may be intentional; the selected winner and competing candidates explain what the current session will resolve.

## Comparison rejects a schema or file

Use an inventory JSON file, not a Markdown report or comparison JSON. Supported inventory schemas are 0.1 and 0.2; missing or unsupported versions and malformed tools/diagnostics are rejected. Do not change the version string merely to bypass validation. Preserve the original file and use compatible software or collect a new baseline when appropriate.

## Reports, console output, and sharing

`-PassThru` adds an object but still shows the console report. Use `-JsonOnly` for pipeline JSON; it cannot be combined with `-PassThru` or `-ReportPath`. Check the destination and write permissions if a report cannot be created. Report files are overwritten; inspection logs are appended. Review [privacy boundaries](privacy.md) before sending reports to others.
