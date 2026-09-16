function Get-FindingIdentity {
    param([Parameter(Mandatory)] [object] $Finding)

    $discriminator = $null
    switch ($Finding.code) {
        { $_ -in @('PathEntryMissing', 'PathEntryDuplicate', 'PSModulePathEntryMissing', 'PSModulePathEntryDuplicate') } {
            $firstEvidence = @($Finding.evidence) | Select-Object -First 1
            if ($firstEvidence -and $firstEvidence.normalized) {
                $discriminator = $firstEvidence.normalized.ToLowerInvariant()
            }
        }
    }

    $parts = @([string] $Finding.code, [string] $Finding.affectedComponent)
    if ($discriminator) {
        $parts += $discriminator
    }

    ($parts -join '|').ToLowerInvariant()
}
