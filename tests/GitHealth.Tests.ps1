$modulePath = Join-Path $PSScriptRoot '..\src\DevRigInspector.psd1'
Import-Module $modulePath -Force

function global:New-TestGitHealth {
    param(
        [bool] $NameConfigured = $true,
        [bool] $EmailConfigured = $true,
        [bool] $Inferred = $false,
        [bool] $DefaultBranchConfigured = $true,
        [bool] $AutocrlfConfigured = $true,
        [bool] $CredentialHelperConfigured = $true,
        [bool] $GithubInstalled = $true,
        [bool] $GithubAuthChecked = $true,
        [bool] $GithubAuthenticated = $true,
        [bool] $GithubAuthAvailable = $true
    )

    [pscustomobject]@{
        git = [pscustomobject]@{
            installed = $true
            version = 'git version 2.55.0'
            selectedCommand = [pscustomobject]@{ path = 'C:\Git\cmd\git.exe' }
            commandCandidates = @([pscustomobject]@{ path = 'C:\Git\cmd\git.exe'; order = 1 })
            identity = [pscustomobject]@{
                name = [pscustomobject]@{ configured = $NameConfigured; value = if ($NameConfigured) { 'Developer' } else { $null } }
                email = [pscustomobject]@{ configured = $EmailConfigured; value = if ($EmailConfigured) { 'developer@example.test' } else { $null } }
                inferred = [pscustomobject]@{ available = $Inferred; name = if ($Inferred) { 'Inferred User' } else { $null }; email = if ($Inferred) { 'inferred@example.test' } else { $null } }
            }
            defaultBranch = [pscustomobject]@{ configured = $DefaultBranchConfigured; value = if ($DefaultBranchConfigured) { 'main' } else { $null } }
            autocrlf = [pscustomobject]@{ configured = $AutocrlfConfigured; value = if ($AutocrlfConfigured) { 'true' } else { $null } }
            credentialHelper = [pscustomobject]@{ configured = $CredentialHelperConfigured; types = if ($CredentialHelperConfigured) { @('manager-core') } else { @() } }
            protocol = [pscustomobject]@{ configured = $false; keys = @() }
        }
        githubCli = [pscustomobject]@{
            installed = $GithubInstalled
            version = if ($GithubInstalled) { 'gh version 2.101.0' } else { $null }
            selectedCommand = $null
            commandCandidates = @()
            authentication = [pscustomobject]@{ checked = $GithubAuthChecked; authenticated = $GithubAuthenticated; available = $GithubAuthAvailable; hosts = if ($GithubAuthenticated) { @('github.com') } else { @() } }
        }
    }
}

Describe 'Git and GitHub health' {
    It 'reports explicit Git identity as informational without exposing values in the finding' {
        InModuleScope DevRigInspector {
            $findings = @(Get-GitHealthDiagnostics -GitHealth (New-TestGitHealth))
            $finding = $findings | Where-Object code -eq 'GitIdentityConfigured'
            $finding.severity | Should Be 'Info'
            $finding.evidence.nameConfigured | Should Be $true
            ($finding | ConvertTo-Json -Depth 8) | Should Not Match 'Developer'
            ($finding | ConvertTo-Json -Depth 8) | Should Not Match 'developer@example.test'
        }
    }

    It 'warns for missing name, email, or both while preserving inferred identity distinction' {
        InModuleScope DevRigInspector {
            $missingName = @(Get-GitHealthDiagnostics -GitHealth (New-TestGitHealth -NameConfigured $false -Inferred $true)) |
                Where-Object code -eq 'GitIdentityMissing'
            $missingName.evidence.missingFields | Should Be 'user.name'
            $missingName.message | Should Match 'inferred identity'

            $missingEmail = @(Get-GitHealthDiagnostics -GitHealth (New-TestGitHealth -EmailConfigured $false)) |
                Where-Object code -eq 'GitIdentityMissing'
            $missingEmail.evidence.missingFields | Should Be 'user.email'

            $missingBoth = @(Get-GitHealthDiagnostics -GitHealth (New-TestGitHealth -NameConfigured $false -EmailConfigured $false)) |
                Where-Object code -eq 'GitIdentityMissing'
            $missingBoth.evidence.missingFields | Should Be @('user.name', 'user.email')
        }
    }

    It 'reports deliberate default branch, valid line-ending policy, and credential helper as informational' {
        InModuleScope DevRigInspector {
            $findings = @(Get-GitHealthDiagnostics -GitHealth (New-TestGitHealth))
            ($findings | Where-Object code -eq 'GitDefaultBranchConfigured').severity | Should Be 'Info'
            ($findings | Where-Object code -eq 'GitLineEndingPolicyDetected').severity | Should Be 'Info'
            ($findings | Where-Object code -eq 'GitCredentialHelperConfigured').severity | Should Be 'Info'
        }
    }

    It 'does not invent a default branch finding when none is configured' {
        InModuleScope DevRigInspector {
            @(Get-GitHealthDiagnostics -GitHealth (New-TestGitHealth -DefaultBranchConfigured $false)) |
                Where-Object code -eq 'GitDefaultBranchConfigured' | Should BeNullOrEmpty
        }
    }

    It 'classifies GitHub CLI authentication outcomes conservatively' {
        InModuleScope DevRigInspector {
            $authenticated = @(Get-GitHealthDiagnostics -GitHealth (New-TestGitHealth)) |
                Where-Object code -eq 'GitHubCliAuthenticated'
            $authenticated.severity | Should Be 'Info'
            $authenticated.evidence.hosts | Should Be 'github.com'

            $notAuthenticated = @(Get-GitHealthDiagnostics -GitHealth (New-TestGitHealth -GithubAuthenticated $false)) |
                Where-Object code -eq 'GitHubCliNotAuthenticated'
            $notAuthenticated.severity | Should Be 'Info'

            $unavailable = @(Get-GitHealthDiagnostics -GitHealth (New-TestGitHealth -GithubAuthChecked $false -GithubAuthAvailable $false)) |
                Where-Object code -eq 'GitHubCliAuthenticationUnavailable'
            $unavailable.severity | Should Be 'Info'
        }
    }

    It 'does not serialize token-like or raw authentication output' {
        InModuleScope DevRigInspector {
            $health = New-TestGitHealth
            $json = $health | ConvertTo-Json -Depth 12
            $json | Should Not Match 'token'
            $json | Should Not Match 'gho_'
            $json | Should Not Match 'Authorization'
        }
    }

    It 'sanitizes custom and secret-looking credential helpers' {
        InModuleScope DevRigInspector {
            Mock Invoke-ExternalCommand {
                param([string] $FilePath, [string[]] $Arguments)
                [pscustomobject]@{
                    exitCode = 0
                    standardOutput = "manager-core`n!f(){ echo SUPER_SECRET_TOKEN; }`nC:\\Tools\\helper.exe --token=LEAK_ME"
                    standardError = ''
                }
            }
            $evidence = Get-SafeCredentialHelperEvidence -Resolution ([pscustomobject]@{ selected = [pscustomobject]@{ path = 'C:\Git\git.exe' } })
            $evidence.configured | Should Be $true
            $evidence.types | Should Be @('manager-core', 'custom', 'unknown')
            ($evidence | ConvertTo-Json -Depth 8) | Should Not Match 'SUPER_SECRET_TOKEN|LEAK_ME|helper.exe'
        }
    }

    It 'does not terminate collection when Git and GitHub probes throw' {
        InModuleScope DevRigInspector {
            Mock Resolve-ToolCommand {
                param([string] $CommandName)
                [pscustomobject]@{
                    selected = [pscustomobject]@{ path = "C:\$CommandName.exe" }
                    candidates = @([pscustomobject]@{ path = "C:\$CommandName.exe"; name = "$CommandName.exe"; order = 1 })
                }
            }
            Mock Invoke-ExternalCommand { throw 'process start failed' }
            $result = Get-GitHealthInventory
            $result.status | Should Be 'Available'
            $result.data.git.version | Should Be $null
            $result.data.githubCli.authentication.authenticated | Should Be $false
            $result.data.githubCli.authentication.available | Should Be $false
        }
    }

    It 'handles gh authentication command failure without throwing' {
        InModuleScope DevRigInspector {
            Mock Resolve-ToolCommand {
                param([string] $CommandName)
                [pscustomobject]@{
                    selected = [pscustomobject]@{ path = "C:\$CommandName.exe" }
                    candidates = @([pscustomobject]@{ path = "C:\$CommandName.exe"; name = "$CommandName.exe"; order = 1 })
                }
            }
            Mock Invoke-GitHealthCommand {
                param([object] $Resolution, [string[]] $Arguments)
                if ($Arguments -contains 'auth') {
                    [pscustomobject]@{ exitCode = 1; standardOutput = ''; standardError = 'not logged in'; timedOut = $false; durationMilliseconds = 1 }
                } elseif ($Arguments -contains '--version') {
                    [pscustomobject]@{ exitCode = 0; standardOutput = 'gh version 2.101.0'; standardError = ''; timedOut = $false; durationMilliseconds = 1 }
                } else {
                    [pscustomobject]@{ exitCode = 1; standardOutput = ''; standardError = ''; timedOut = $false; durationMilliseconds = 1 }
                }
            }

            $result = Get-GitHealthInventory
            $result.status | Should Be 'Available'
            $result.data.githubCli.authentication.checked | Should Be $true
            $result.data.githubCli.authentication.authenticated | Should Be $false
            $result.data.githubCli.authentication.available | Should Be $true
            $finding = @(Get-GitHealthDiagnostics -GitHealth $result.data) | Where-Object code -eq 'GitHubCliNotAuthenticated'
            $finding.severity | Should Be 'Info'
        }
    }
}