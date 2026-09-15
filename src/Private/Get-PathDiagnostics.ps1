function ConvertTo-NormalizedPathEntry {
    param([Parameter(Mandatory)] [string] $RawEntry)

    $expanded = [Environment]::ExpandEnvironmentVariables($RawEntry.Trim().Trim('"').Trim("'").Trim())
    $normalized = $expanded -replace '/', '\'

    if ($normalized -notmatch '^[A-Za-z]:\\$' -and $normalized -notmatch '^\\\\[^\\]+\\[^\\]+\\$') {
        $normalized = $normalized.TrimEnd('\')
    }

    [pscustomobject]@{
        raw = $RawEntry
        expanded = $expanded
        normalized = $normalized
    }
}

function Get-PathDiagnostics {
    param([string] $PathValue = $env:PATH)

    $entries = @(
        ($PathValue -split ';') |
            Where-Object { $_.Trim().Length -gt 0 } |
            ForEach-Object { ConvertTo-NormalizedPathEntry -RawEntry $_ }
    )

    foreach ($entry in $entries) {
        if (-not [IO.Directory]::Exists($entry.expanded)) {
            New-DiagnosticFinding `
                -Code 'PathEntryMissing' `
                -Severity Warning `
                -Category 'Path' `
                -Title 'PATH entry does not exist' `
                -Message ('The PATH entry does not point to an existing directory: {0}' -f $entry.raw.Trim()) `
                -AffectedComponent 'PATH' `
                -Evidence @([pscustomobject]@{
                    raw = $entry.raw
                    expanded = $entry.expanded
                    normalized = $entry.normalized
                }) `
                -Recommendation 'Remove or correct the stale entry after confirming it is no longer required.'
        }
    }

    $duplicateGroups = $entries | Group-Object -Property normalized | Where-Object { $_.Count -gt 1 }
    foreach ($group in $duplicateGroups) {
        New-DiagnosticFinding `
            -Code 'PathEntryDuplicate' `
            -Severity Warning `
            -Category 'Path' `
            -Title 'Duplicate PATH entry' `
            -Message ('The PATH contains the same directory more than once: {0}' -f $group.Name) `
            -AffectedComponent 'PATH' `
            -Evidence @($group.Group | ForEach-Object {
                [pscustomobject]@{
                    raw = $_.raw
                    expanded = $_.expanded
                    normalized = $_.normalized
                }
            }) `
            -Recommendation 'Remove duplicate entries while preserving the intended PATH order.'
    }
}