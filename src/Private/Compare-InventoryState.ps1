function Compare-InventoryState {
    param(
        [Parameter(Mandatory)] [object] $Reference,
        [Parameter(Mandatory)] [object] $Current
    )

    $toolChanges = @()
    $referenceToolsById = @{}
    foreach ($tool in $Reference.tools) { $referenceToolsById[$tool.id] = $tool }
    $currentToolsById = @{}
    foreach ($tool in $Current.tools) { $currentToolsById[$tool.id] = $tool }

    foreach ($id in $currentToolsById.Keys) {
        if (-not $referenceToolsById.ContainsKey($id)) {
            $tool = $currentToolsById[$id]
            $toolChanges += [pscustomobject]@{ kind = 'Added'; id = $id; displayName = $tool.displayName; fields = @() }
        }
    }
    foreach ($id in $referenceToolsById.Keys) {
        if (-not $currentToolsById.ContainsKey($id)) {
            $tool = $referenceToolsById[$id]
            $toolChanges += [pscustomobject]@{ kind = 'Removed'; id = $id; displayName = $tool.displayName; fields = @() }
        }
    }
    foreach ($id in $referenceToolsById.Keys) {
        if (-not $currentToolsById.ContainsKey($id)) { continue }
        $before = $referenceToolsById[$id]
        $after = $currentToolsById[$id]
        $fields = @()
        if ($before.status -ne $after.status) {
            $fields += [pscustomobject]@{ field = 'status'; before = $before.status; after = $after.status }
        }
        if ($before.version -ne $after.version) {
            $fields += [pscustomobject]@{ field = 'version'; before = $before.version; after = $after.version }
        }
        if ($fields.Count -gt 0) {
            $toolChanges += [pscustomobject]@{ kind = 'Changed'; id = $id; displayName = $after.displayName; fields = $fields }
        }
    }

    $findingChanges = @()
    $referenceFindingsByIdentity = @{}
    foreach ($finding in $Reference.findings) { $referenceFindingsByIdentity[$finding.identity] = $finding }
    $currentFindingsByIdentity = @{}
    foreach ($finding in $Current.findings) { $currentFindingsByIdentity[$finding.identity] = $finding }

    foreach ($identity in $currentFindingsByIdentity.Keys) {
        if (-not $referenceFindingsByIdentity.ContainsKey($identity)) {
            $finding = $currentFindingsByIdentity[$identity]
            $findingChanges += [pscustomobject]@{
                kind = 'NewFinding'
                identity = $identity
                code = $finding.code
                affectedComponent = $finding.affectedComponent
                severity = $finding.severity
                title = $finding.title
                message = $finding.message
            }
        }
    }
    foreach ($identity in $referenceFindingsByIdentity.Keys) {
        if (-not $currentFindingsByIdentity.ContainsKey($identity)) {
            $finding = $referenceFindingsByIdentity[$identity]
            $findingChanges += [pscustomobject]@{
                kind = 'ResolvedFinding'
                identity = $identity
                code = $finding.code
                affectedComponent = $finding.affectedComponent
                severity = $finding.severity
                title = $finding.title
                message = $finding.message
            }
        }
    }
    foreach ($identity in $referenceFindingsByIdentity.Keys) {
        if (-not $currentFindingsByIdentity.ContainsKey($identity)) { continue }
        $before = $referenceFindingsByIdentity[$identity]
        $after = $currentFindingsByIdentity[$identity]
        if ($before.severity -ne $after.severity) {
            $findingChanges += [pscustomobject]@{
                kind = 'SeverityChanged'
                identity = $identity
                code = $after.code
                affectedComponent = $after.affectedComponent
                severityBefore = $before.severity
                severityAfter = $after.severity
                title = $after.title
                message = $after.message
            }
        }
    }

    [pscustomobject]@{
        tools = $toolChanges
        findings = $findingChanges
    }
}
