# Architecture

[Back to README](../README.md)

Dev Rig Inspector separates observations from interpretation. Its only public commands are `Invoke-DevRigInspection` and `Compare-DevRigInspection`.

## Inspection

```text
collect → diagnose → summarize → serialize → render
```

Collectors read Windows registry/CIM evidence, resolve commands, and run version/configuration/status probes. The tool inventory and dedicated PowerShell, Git, Python, Node, and virtualization health collectors serve different purposes: discovering a command does not imply complete health analysis for that tool.

Diagnostic functions turn collected evidence into findings with a code, severity, category, affected component, evidence, and recommendation. They preserve uncertainty rather than treating every missing observation as a broken capability. The summary derives counts, status, affected subsystems, and attention items from those findings; it does not probe or diagnose again.

The pipeline above is conceptual: a structured inventory feeds independent serializers and renderers. JSON is produced only when requested for a file or pipeline; Markdown and console rendering consume the inventory object directly, not a JSON round trip. `-JsonOnly` skips console rendering. Requested progress logs are separate from inventory data.

Raw process results are implementation evidence, not a stable public tool contract. stdout/stderr can contain incidental text or secrets and vary independently of tool state. The `tools[]` projection retains resolution metadata, parsed version, status, local diagnostics, and fixed error messages. See [privacy boundaries](privacy.md) for the distinction between that projection and selected health text.

## Comparison

```text
acquire → validate → normalize → compare → structured result → render
```

Acquisition accepts files or objects independently on either side. Validation checks supported schema and required structure. Normalization selects comparable fields and records evidence availability, ignoring historical raw tool fields. Comparison evaluates tools, diagnostic identities, and supported health fields. A structured result includes changes, counts, source metadata, and a heuristic machine-identity assessment; console, JSON, and Markdown are presentations of that result.

No comparison stage collects live workstation state or rewrites a baseline. See [comparison semantics](comparison.md) for what is and is not compared.

## Source and package layout

The source module lives under `src`, with `Collectors`, `Private`, and `Public` directories. Source launchers and build/test scripts live outside the module. The package places the manifest/module at its root alongside those runtime directories, README, and operator docs. Only the two public functions are exported. Building recreates repository `dist`; it does not publish, install, or change workstation configuration.
