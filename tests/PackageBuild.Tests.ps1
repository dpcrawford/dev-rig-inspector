$repoRoot = Split-Path -Parent $PSScriptRoot
$buildScript = Join-Path $repoRoot 'scripts\Build-ModulePackage.ps1'
$manifestData = Import-PowerShellDataFile (Join-Path $repoRoot 'src\DevRigInspector.psd1')
$expectedVersion = $manifestData.ModuleVersion
$distRoot = Join-Path $repoRoot 'dist'
$stagingDir = Join-Path $distRoot "DevRigInspector-$expectedVersion"
$zipPath = Join-Path $distRoot "DevRigInspector-$expectedVersion.zip"

Describe 'Build-ModulePackage' {
    BeforeAll {
        # Hash the source tree before the build runs to later prove the build never modifies source files.
        $srcRoot = Join-Path $repoRoot 'src'
        $script:beforeHashes = @(Get-ChildItem -Path $srcRoot -Recurse -File | Sort-Object FullName | ForEach-Object {
            [pscustomobject]@{ Path = $_.FullName; Hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash }
        })

        & $buildScript | Out-Null
    }

    It 'creates the expected versioned staging directory with required runtime files' {
        Test-Path $stagingDir | Should Be $true
        Test-Path (Join-Path $stagingDir 'DevRigInspector.psd1') | Should Be $true
        Test-Path (Join-Path $stagingDir 'DevRigInspector.psm1') | Should Be $true
        Test-Path (Join-Path $stagingDir 'Public') | Should Be $true
        Test-Path (Join-Path $stagingDir 'Private') | Should Be $true
        Test-Path (Join-Path $stagingDir 'Collectors') | Should Be $true
        Test-Path (Join-Path $stagingDir 'docs\privacy.md') | Should Be $true
    }

    It 'creates the versioned ZIP' {
        Test-Path $zipPath | Should Be $true
    }

    It 'excludes development-only files and directories from the package' {
        Test-Path (Join-Path $stagingDir 'tests') | Should Be $false
        Test-Path (Join-Path $stagingDir '.git') | Should Be $false
        Test-Path (Join-Path $stagingDir 'scripts') | Should Be $false
        Test-Path (Join-Path $stagingDir 'output') | Should Be $false
        Test-Path (Join-Path $stagingDir 'Start-DevRigInspector.ps1') | Should Be $false
        Test-Path (Join-Path $stagingDir 'Start-DevRigInspector.cmd') | Should Be $false
    }

    It 'produces a manifest that validates from the packaged location' {
        { Test-ModuleManifest -Path (Join-Path $stagingDir 'DevRigInspector.psd1') } | Should Not Throw
    }

    It 'exports exactly the two intended public commands from the packaged module' {
        try {
            Import-Module (Join-Path $stagingDir 'DevRigInspector.psd1') -Force
            $names = @(Get-Command -Module DevRigInspector | Select-Object -ExpandProperty Name | Sort-Object)
            ($names -join ',') | Should Be 'Compare-DevRigInspection,Invoke-DevRigInspection'
        } finally {
            Remove-Module -Name DevRigInspector -Force -ErrorAction SilentlyContinue
        }
    }

    It 'imports and runs from outside the repository working directory' {
        Push-Location $env:TEMP
        try {
            $output = & pwsh -NoLogo -NoProfile -Command "Import-Module '$stagingDir\DevRigInspector.psd1' -Force; (Invoke-DevRigInspection -PassThru 6>`$null).collectorVersion" 2>&1 | Out-String
        } finally {
            Pop-Location
        }
        $output.Trim() | Should Be $expectedVersion
    }

    It 'emits the current schema version and no raw tool probe fields from the packaged module' {
        Push-Location $env:TEMP
        try {
            $output = & pwsh -NoLogo -NoProfile -Command "Import-Module '$stagingDir\DevRigInspector.psd1' -Force; `$json = Invoke-DevRigInspection -JsonOnly 6>`$null; `$json" 2>&1 | Out-String
        } finally {
            Pop-Location
        }
        $inventory = $output | ConvertFrom-Json
        $inventory.schemaVersion | Should Be '0.2'
        # Scoped to the tools[] array specifically; other objects (e.g. WSL evidence) legitimately have unrelated "command" properties.
        foreach ($tool in @($inventory.tools)) {
            ($tool.PSObject.Properties.Name -contains 'command') | Should Be $false
            ($tool.PSObject.Properties.Name -contains 'rawVersion') | Should Be $false
        }
        $output | Should Not Match '"standardOutput"\s*:'
        $output | Should Not Match '"standardError"\s*:'
    }

    It 'does not modify any source file' {
        $afterHashes = @(Get-ChildItem -Path (Join-Path $repoRoot 'src') -Recurse -File | Sort-Object FullName | ForEach-Object {
            [pscustomobject]@{ Path = $_.FullName; Hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash }
        })
        ($afterHashes | ConvertTo-Json -Depth 5) | Should Be ($script:beforeHashes | ConvertTo-Json -Depth 5)
    }

    It 'produces build output that Git ignores' {
        Push-Location $repoRoot
        try {
            git check-ignore -q 'dist/marker-check.txt'
            $ignoreExit = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        $ignoreExit | Should Be 0
    }
}

Describe 'Package installed-by-name acceptance' {
    It 'imports by module name from a temporary PSModulePath and executes successfully' {
        $tempModuleRoot = Join-Path $env:TEMP ('dri-test-modroot-' + [guid]::NewGuid())
        $versionedTarget = Join-Path $tempModuleRoot "DevRigInspector\$expectedVersion"
        New-Item -ItemType Directory -Path $versionedTarget -Force | Out-Null
        try {
            Copy-Item -Path (Join-Path $stagingDir '*') -Destination $versionedTarget -Recurse -Force
            $scriptBlock = "`$env:PSModulePath = '$tempModuleRoot' + [System.IO.Path]::PathSeparator + `$env:PSModulePath; Import-Module DevRigInspector; (Get-Module DevRigInspector).Version.ToString(); (Invoke-DevRigInspection -PassThru 6>`$null).collectorVersion"
            $output = & pwsh -NoLogo -NoProfile -Command $scriptBlock 2>&1 | Out-String
            $lines = @($output -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 })
            $lines[0].Trim() | Should Be $expectedVersion
            $lines[1].Trim() | Should Be $expectedVersion
        } finally {
            Remove-Item -Path $tempModuleRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Package ZIP acceptance' {
    It 'extracts and imports successfully from an unrelated temporary directory' {
        $zipExtractDir = Join-Path $env:TEMP ('dri-test-zip-' + [guid]::NewGuid())
        try {
            Expand-Archive -Path $zipPath -DestinationPath $zipExtractDir
            $extractedManifest = Join-Path $zipExtractDir 'DevRigInspector.psd1'
            $output = & pwsh -NoLogo -NoProfile -Command "Import-Module '$extractedManifest'; (Invoke-DevRigInspection -PassThru 6>`$null).collectorVersion" 2>&1 | Out-String
            $output.Trim() | Should Be $expectedVersion
        } finally {
            Remove-Item -Path $zipExtractDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
