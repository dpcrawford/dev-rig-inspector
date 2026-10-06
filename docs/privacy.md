# Collected data and privacy boundaries

[Back to README](../README.md)

Dev Rig Inspector is privacy-conscious, not anonymous. Its purpose requires workstation evidence. Treat inventories, comparisons, Markdown reports, and logs as potentially identifying material.

## What can appear

| Area | Examples of retained evidence |
|---|---|
| System | Hostname, Windows/build, CPU, memory, volume labels/capacity/free space |
| Resolution | Executable and PATH directory names, usernames embedded in paths, command candidates |
| PowerShell | Runtime versions/paths and execution-policy scopes/values |
| Git / GitHub CLI | Configured and inferred Git name/email, default branch, autocrlf, credential-helper categories, protocol configuration key names, authentication flags/hostnames |
| Python / Node | Runtime and launcher versions/paths, virtual-environment path, pip/uv evidence, npm global prefix/path |
| Virtualization | Feature/query states, processor capability evidence, WSL version/status text and distribution names |
| Reports/logs | Snapshot source paths, output locations, timestamps, diagnostic messages and some query error details |

Credential-helper commands are categorized rather than dumped; GitHub authentication output is reduced to state and hosts rather than a token-bearing auth transcript. Git protocol key names may themselves contain URL information. This is not a general secret scanner or redactor.

## Raw probes and schema 0.2

Schema 0.2 excludes arbitrary raw external-command stdout/stderr from public `tools[]` records and their duplicate collector data. The raw `Invoke-ExternalCommand` result is not serialized there: `command` and `rawVersion` are removed, versions are parsed numeric tokens or null, and tool errors use fixed messages. Raw execution details are noisy, unstable, and may carry credentials unrelated to the intended version probe.

This boundary must not be read as a blanket guarantee that every command-derived string is sanitized. Dedicated health collectors still retain selected successful output, including Git/GitHub version text, WSL version/status text, and configuration values. Python/Node health version fallbacks can retain unrecognized text; some query/probe errors retain exception messages. Review output before sharing, especially with custom command wrappers or unusual configuration. Historical 0.1 snapshots can still contain raw tool output; comparison ignores those legacy fields but does not erase them from the original file. Supplied comparison objects are not scrubbed of all sensitive content.

## Read-only behavior

Inspection and comparison do not alter PATH, change execution policy, modify Git configuration, log into/out of GitHub, install/remove packages, change Python environments, modify npm configuration, enable/disable Windows features, or modify WSL/Hyper-V. They inspect and recommend; they do not remediate.

They execute resolved commands for version/configuration/status queries. Those programs run with the caller's permissions; Dev Rig Inspector does not sandbox third-party executables or guarantee their own side effects. GitHub CLI authentication checks can contact its service, so read-only does not mean guaranteed offline. Dev Rig Inspector contains no report-upload or publishing step.

Explicit `OutputPath`/`ReportPath` writes and `LogPath` appends are expected outputs. The documented manual installation and source package build also write files at the user's direction; they are separate from workstation inspection. Keep outputs in a suitable location and review the actual evidence before sharing externally.
