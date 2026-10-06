$repoRoot = Split-Path -Parent $PSScriptRoot
$readme = Get-Content (Join-Path $repoRoot 'README.md') -Raw
$manifest = Import-PowerShellDataFile (Join-Path $repoRoot 'src\DevRigInspector.psd1')

function Get-ReadmeExample {
    param([string] $Name)
    $pattern = '(?s)<!-- example: ' + [regex]::Escape($Name) + ' -->\s*```powershell\s*\r?\n(.*?)```'
    $match = [regex]::Match($readme, $pattern)
    if (-not $match.Success) { throw "Missing executable README example: $Name" }
    $match.Groups[1].Value.Trim()
}

function Assert-DocumentationLinks {
    param([string] $Root)
    $files = @((Get-Item (Join-Path $Root 'README.md'))) + @(Get-ChildItem (Join-Path $Root 'docs') -Filter *.md)
    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw
        foreach ($match in [regex]::Matches($content, '\[[^\]]+\]\(([^)]+)\)')) {
            $target = $match.Groups[1].Value
            if ($target -match '^(https?://|#)') { continue }
            $target = ($target -split '#', 2)[0]
            if (-not (Test-Path -LiteralPath (Join-Path $file.DirectoryName $target))) {
                throw "Broken link in $($file.Name): $target"
            }
        }
    }
}

Describe 'Documentation and operator workflows' {
    BeforeAll {
        $script:docWork = Join-Path $TestDrive 'documentation'
        New-Item -ItemType Directory $script:docWork -Force | Out-Null
        $expectedDist = [IO.Path]::GetFullPath((Join-Path $repoRoot 'dist'))
        if ((Split-Path $expectedDist -Parent) -ne $repoRoot) { throw 'Unexpected build target' }
        & (Join-Path $repoRoot 'scripts\Build-ModulePackage.ps1') | Out-Null
        $script:docPackage = Join-Path $script:docWork 'extracted'
        Expand-Archive -LiteralPath (Join-Path $repoRoot "dist\DevRigInspector-$($manifest.ModuleVersion).zip") -DestinationPath $script:docPackage
    }

    AfterAll {
        # Later files use InModuleScope by name; do not leave the extracted copy
        # loaded alongside their source import in Pester's shared process.
        Get-Module -Name DevRigInspector -All | Remove-Module -Force
    }

    It 'resolves relative documentation links in the source and extracted ZIP' {
        { Assert-DocumentationLinks -Root $repoRoot } | Should Not Throw
        { Assert-DocumentationLinks -Root $script:docPackage } | Should Not Throw
    }

    It 'references existing source launchers, scripts, and module files' {
        foreach ($path in @('Start-DevRigInspector.cmd', 'Start-DevRigInspector.ps1', 'src\DevRigInspector.psd1', 'src\Collectors\ToolDefinitions.psd1', 'scripts\Invoke-Tests.ps1', 'scripts\Build-ModulePackage.ps1')) {
            $readme.Contains($path) | Should Be $true
            Test-Path -LiteralPath (Join-Path $repoRoot $path) | Should Be $true
        }
        Test-Path (Join-Path $script:docPackage 'DevRigInspector.psd1') | Should Be $true
    }

    It 'uses valid public commands and syntactically valid PowerShell examples' {
        $documentedCommands = @([regex]::Matches($readme, '\b(?:Invoke|Compare)-DevRigInspection\b') | ForEach-Object Value | Sort-Object -Unique)
        ($documentedCommands -join ',') | Should Be (($manifest.FunctionsToExport | Sort-Object) -join ',')
        foreach ($block in [regex]::Matches($readme, '(?s)```powershell\s*\r?\n(.*?)```')) {
            $parseErrors = $null; $tokens = $null
            [System.Management.Automation.Language.Parser]::ParseInput($block.Groups[1].Value, [ref]$tokens, [ref]$parseErrors) | Out-Null
            @($parseErrors).Count | Should Be 0
        }
    }

    It 'keeps documented schema and implementation versions aligned with production' {
        Import-Module (Join-Path $repoRoot 'src\DevRigInspector.psd1') -Force
        $inventory = & (Get-Module DevRigInspector) {
            New-InspectionResult -Computer ([pscustomobject]@{}) -Tools @([pscustomobject]@{id='git';displayName='Git';status='Available';version='1.0.0'}) -CollectorResults @((New-CollectorResult -CollectorId System -Status Available -Data ([pscustomobject]@{})))
        }
        $comparison = Compare-DevRigInspection -Reference $inventory -Current $inventory -JsonOnly | ConvertFrom-Json
        $schemaDoc = Get-Content (Join-Path $repoRoot 'docs\inventory-schema.md') -Raw
        $comparisonDoc = Get-Content (Join-Path $repoRoot 'docs\comparison.md') -Raw
        foreach ($entry in @(@{name='schemaVersion';value=$inventory.schemaVersion}, @{name='collectorVersion';value=$inventory.collectorVersion}, @{name='comparisonSchemaVersion';value=$comparison.comparisonSchemaVersion}, @{name='comparisonVersion';value=$comparison.comparisonVersion})) {
            $schemaDoc.Contains("$($entry.name) = $($entry.value)") | Should Be $true
            $readme | Should Match ('(?m)^\|[^\r\n]*`' + $entry.name + '`[^|]*\|\s*`' + [regex]::Escape($entry.value) + '`')
        }
        $comparisonDoc.Contains("comparisonSchemaVersion = $($comparison.comparisonSchemaVersion)") | Should Be $true
        $inventory.schemaVersion = '0.1'
        { Compare-DevRigInspection -Reference $inventory -Current $inventory -JsonOnly } | Should Not Throw
        $schemaDoc | Should Match 'supported historical inventory `schemaVersion = 0\.1`'
    }

    It 'keeps repository-only commands outside the package installation workflow' {
        $packagedReadme = Get-Content (Join-Path $script:docPackage 'README.md') -Raw
        $installation = [regex]::Match($packagedReadme, '(?s)## Installation\s*(.*?)## Basic inspection').Groups[1].Value
        $installation | Should Not Match '\.\\(?:src|dist|scripts)\\|Start-DevRigInspector'
        $installation | Should Match 'Import-Module \.\\DevRigInspector.psd1'
        $installation | Should Match 'Import-Module DevRigInspector'
        $packagedReadme | Should Match 'Source checkout only'
    }

    It 'runs the source checkout direct-import quick start' {
        Remove-Module DevRigInspector -Force -ErrorAction SilentlyContinue
        Push-Location $repoRoot
        try {
            . ([scriptblock]::Create((Get-ReadmeExample 'source-import'))) 6>$null
            (Get-Module DevRigInspector).Path | Should Be (Join-Path $repoRoot 'src\DevRigInspector.psm1')
        } finally { Pop-Location }
    }

    It 'runs the extracted ZIP import example outside the repository' {
        Remove-Module DevRigInspector -Force -ErrorAction SilentlyContinue
        Push-Location $script:docPackage
        try {
            . ([scriptblock]::Create((Get-ReadmeExample 'zip-import'))) 6>$null
            $actualPath = [IO.Path]::GetFullPath((Get-Module DevRigInspector).Path)
            $expectedPath = [IO.Path]::GetFullPath((Join-Path $script:docPackage 'DevRigInspector.psm1'))
            [string]::Equals($actualPath, $expectedPath, [StringComparison]::OrdinalIgnoreCase) | Should Be $true
        } finally { Pop-Location }
    }

    It 'runs installed-by-name import in a fresh process using a temporary module directory' {
        $temporaryModules = Join-Path $script:docWork 'Modules'
        $moduleRoot = Join-Path $temporaryModules "DevRigInspector\$($manifest.ModuleVersion)"
        # Execute the README copy steps with only the destination redirected into TestDrive.
        $copySteps = ((Get-ReadmeExample 'install-copy') -split '\r?\n' | Select-Object -Skip 1) -join [Environment]::NewLine
        Push-Location $script:docPackage
        try { . ([scriptblock]::Create($copySteps)) } finally { Pop-Location }
        $runner = Join-Path $script:docWork 'installed-example.ps1'
        @('$ErrorActionPreference = ''Stop''', (Get-ReadmeExample 'installed-import'), "'MODULEBASE=' + (Get-Module DevRigInspector).ModuleBase") | Set-Content $runner
        $previousModulePath = $env:PSModulePath
        try {
            $env:PSModulePath = $temporaryModules + [IO.Path]::PathSeparator + $previousModulePath
            Push-Location $script:docWork
            try { $result = & pwsh -NoProfile -File $runner 2>&1 | Out-String; $exitCode = $LASTEXITCODE } finally { Pop-Location }
        } finally { $env:PSModulePath = $previousModulePath }
        $exitCode | Should Be 0
        $moduleBaseLine = [regex]::Match($result, '(?m)^MODULEBASE=(.+)$')
        $moduleBaseLine.Success | Should Be $true
        $actualModuleBase = [IO.Path]::GetFullPath($moduleBaseLine.Groups[1].Value.Trim())
        $expectedModuleBase = [IO.Path]::GetFullPath($moduleRoot)
        [string]::Equals($actualModuleBase, $expectedModuleBase, [StringComparison]::OrdinalIgnoreCase) | Should Be $true
    }

    It 'executes basic, report, JSON, baseline, and Markdown comparison examples from the package' {
        Import-Module (Join-Path $script:docPackage 'DevRigInspector.psd1') -Force
        Push-Location $script:docWork
        try {
            . ([scriptblock]::Create((Get-ReadmeExample 'basic'))) 6>$null
            $inventory.schemaVersion | Should Be '0.2'
            . ([scriptblock]::Create((Get-ReadmeExample 'reports'))) 6>$null
            (Get-Content .\inventory.json -Raw | ConvertFrom-Json).schemaVersion | Should Be '0.2'
            Get-Content .\report.md -Raw | Should Match '# Dev Rig Inspector Report'
            . ([scriptblock]::Create((Get-ReadmeExample 'json-only')))
            $json -is [string] | Should Be $true
            $inventory.schemaVersion | Should Be '0.2'
            . ([scriptblock]::Create((Get-ReadmeExample 'baseline'))) 6>$null
            . ([scriptblock]::Create((Get-ReadmeExample 'comparison-report'))) 6>$null
            Get-Content .\comparison.md -Raw | Should Match '# Dev Rig Inspector Comparison'
            $comparisonDoc = Get-Content (Join-Path $repoRoot 'docs\comparison.md') -Raw
            $exportExample = [regex]::Match($comparisonDoc, '(?s)```powershell\s*\r?\n(.*?)```').Groups[1].Value
            . ([scriptblock]::Create($exportExample))
            (Get-Content .\comparison.json -Raw | ConvertFrom-Json).comparisonSchemaVersion | Should Be '0.1'
        } finally { Pop-Location }
    }

    It 'provides packaged Full help with descriptions, examples, outputs, notes, and every public parameter' {
        Import-Module (Join-Path $script:docPackage 'DevRigInspector.psd1') -Force
        foreach ($name in $manifest.FunctionsToExport) {
            $help = Get-Help $name -Full
            $help.Name | Should Be $name
            [string]::IsNullOrWhiteSpace(($help.description.Text -join ' ')) | Should Be $false
            @($help.examples.example).Count -ge 3 | Should Be $true
            [string]::IsNullOrWhiteSpace(($help.returnValues | Out-String)) | Should Be $false
            ($help.alertSet | Out-String) | Should Match '0\.5\.0'
            $command = Get-Command $name
            $common = @('Verbose','Debug','ErrorAction','WarningAction','InformationAction','ProgressAction','ErrorVariable','WarningVariable','InformationVariable','OutVariable','OutBuffer','PipelineVariable')
            foreach ($parameter in $command.Parameters.Keys | Where-Object { $_ -notin $common }) {
                $documented = @($help.parameters.parameter | Where-Object name -eq $parameter)
                $documented.Count | Should Be 1
                [string]::IsNullOrWhiteSpace(($documented[0].description.Text -join ' ')) | Should Be $false
            }
        }
    }
}
