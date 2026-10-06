$repoRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repoRoot 'src\DevRigInspector.psd1') -Force

Describe 'Optional capabilities on a fresh workstation' {
    It 'does not probe or report unhealthy Git or GitHub CLI when both are absent' {
        InModuleScope DevRigInspector {
            Mock Resolve-ToolCommand { [pscustomobject]@{ selected=$null; candidates=@() } }
            Mock Invoke-ExternalCommand { throw 'Unexpected probe' }
            $health = (Get-GitHealthInventory).data
            $health.git.installed | Should Be $false
            $health.githubCli.installed | Should Be $false
            @(Get-GitHealthDiagnostics $health | Where-Object severity -ne Info).Count | Should Be 0
            Assert-MockCalled Invoke-ExternalCommand -Times 0 -Exactly -Scope It
        }
    }

    It 'does not report absent Python, py, uv and pip as broken selected capabilities' {
        InModuleScope DevRigInspector {
            Mock Resolve-ToolCommand { [pscustomobject]@{ selected=$null; candidates=@() } }
            Mock Invoke-ExternalCommand { throw 'Unexpected probe' }
            $previous = $env:VIRTUAL_ENV
            try {
                $env:VIRTUAL_ENV = ''
                $health = (Get-PythonHealthInventory).data
                $null -eq $health.selected | Should Be $true
                $health.uv.available | Should Be $false
                @(Get-PythonHealthDiagnostics $health | Where-Object severity -ne Info).Count | Should Be 0
            } finally { $env:VIRTUAL_ENV = $previous }
            Assert-MockCalled Invoke-ExternalCommand -Times 0 -Exactly -Scope It
        }
    }

    It 'does not report absent Node and npm as broken selected capabilities' {
        InModuleScope DevRigInspector {
            Mock Resolve-ToolCommand { [pscustomobject]@{ selected=$null; candidates=@() } }
            Mock Get-NpmRawLauncherEvidence { @() }
            Mock Invoke-ExternalCommand { throw 'Unexpected probe' }
            $health = (Get-NodeHealthInventory).data
            $null -eq $health.node.selected | Should Be $true
            $health.npm.runnable | Should Be $false
            @(Get-NodeHealthDiagnostics $health | Where-Object severity -ne Info).Count | Should Be 0
            Assert-MockCalled Invoke-ExternalCommand -Times 0 -Exactly -Scope It
        }
    }

    It 'keeps non-elevated feature evidence unavailable and installed WSL without distributions benign' {
        InModuleScope DevRigInspector {
            Mock Resolve-ToolCommand { [pscustomobject]@{ selected=[pscustomobject]@{path='C:\Windows\System32\wsl.exe'}; candidates=@() } }
            Mock Get-CimInstance { throw 'Access denied' }
            Mock Get-Command { [pscustomobject]@{Name='Get-WindowsOptionalFeature'} } -ParameterFilter { $Name -eq 'Get-WindowsOptionalFeature' }
            Mock Get-WindowsOptionalFeature { throw [UnauthorizedAccessException]::new('Requires elevation') }
            Mock Invoke-ExternalCommand { [pscustomobject]@{ exitCode=0; standardOutput=''; standardError=''; timedOut=$false } }
            $health = (Get-VirtualizationHealthInventory).data
            $health.wsl.installed | Should Be $true
            $health.wsl.distributions.Count | Should Be 0
            $health.wsl.distributionParseStatus | Should Be 'NoneOrUnknown'
            @($health.features | Where-Object state -ne Unavailable).Count | Should Be 0
            @(Get-VirtualizationHealthDiagnostics $health | Where-Object severity -ne Info).Count | Should Be 0
        }
    }
}

Describe 'Release and CI portability gates' {
    It 'has no workstation-specific absolute filesystem literals in production' {
        $hits = @()
        foreach ($file in Get-ChildItem (Join-Path $repoRoot 'src') -Recurse -File -Include *.ps1,*.psm1,*.psd1) {
            $tokens=$null; $errors=$null
            $ast = [Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
            $hits += @($ast.FindAll({ param($node)
                $node -is [Management.Automation.Language.StringConstantExpressionAst] -and $node.Value -match '^[A-Za-z]:[\\/]'
            }, $true))
        }
        $hits.Count | Should Be 0
    }

    It 'fails the shared test runner for failed or empty suites and keeps raw test output private' {
        $runner = Join-Path $repoRoot 'scripts\Invoke-Tests.ps1'
        $fixture = Join-Path $TestDrive 'gate.Tests.ps1'
        "Describe 'Gate fixture' { It 'fails deliberately' { Write-Host 'PRIVATE_PROBE_TEXT'; 'PRIVATE_PROBE_TEXT' | Should Be 'different' } }" | Set-Content $fixture
        $output = & (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File $runner -Path $fixture 2>&1 | Out-String
        $LASTEXITCODE | Should Not Be 0
        $output | Should Not Match 'PRIVATE_PROBE_TEXT'
        "Describe 'Gate fixture' { It 'passes' { 1 | Should Be 1 } }" | Set-Content $fixture
        $output = & (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File $runner -Path $fixture 2>&1 | Out-String
        $LASTEXITCODE | Should Be 0
        $empty = Join-Path $TestDrive 'empty'
        New-Item -ItemType Directory $empty | Out-Null
        $output = & (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File $runner -Path $empty 2>&1 | Out-String
        $LASTEXITCODE | Should Not Be 0
    }

    It 'builds and verifies extracted and installed packages from unrelated cwd without changing parent PSModulePath' {
        $before = $env:PSModulePath
        Push-Location $TestDrive
        try { $result = & (Join-Path $repoRoot 'scripts\Test-Release.ps1') 6>$null } finally { Pop-Location }
        $env:PSModulePath | Should Be $before
        $result.Extracted | Should Be 'Passed'
        $result.Installed | Should Be 'Passed'
        $result.ParserFiles | Should Be 37
        if (Get-Command powershell.exe -ErrorAction SilentlyContinue) { $result.Legacy | Should Be 'Passed' }
        Test-Path $result.PackagePath | Should Be $true
    }
}
