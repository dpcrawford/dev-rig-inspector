function Get-PowerShellHealthInventory {
    try {
        $executionPolicies = @(
            Get-ExecutionPolicy -List | ForEach-Object {
                [pscustomobject]@{
                    scope = [string] $_.Scope
                    policy = [string] $_.ExecutionPolicy
                }
            }
        )
        $policyPrecedence = @('MachinePolicy', 'UserPolicy', 'Process', 'CurrentUser', 'LocalMachine')
        $effectivePolicy = $null
        foreach ($scope in $policyPrecedence) {
            $policy = $executionPolicies | Where-Object scope -eq $scope | Select-Object -First 1
            if ($policy -and $policy.policy -and $policy.policy -ne 'Undefined') {
                $effectivePolicy = [pscustomobject]@{
                    scope = $scope
                    policy = $policy.policy
                }
                break
            }
        }

        $modulePathEntries = @(
            ($env:PSModulePath -split [IO.Path]::PathSeparator) |
                Where-Object { $_.Trim().Length -gt 0 } |
                ForEach-Object {
                    $entry = ConvertTo-NormalizedPathEntry -RawEntry $_
                    [pscustomobject]@{
                        raw = $entry.raw
                        expanded = $entry.expanded
                        normalized = $entry.normalized
                        exists = [IO.Directory]::Exists($entry.expanded)
                    }
                }
        )

        $profiles = @(
            [pscustomobject]@{ name = 'CurrentUserCurrentHost'; path = $PROFILE.CurrentUserCurrentHost }
            [pscustomobject]@{ name = 'CurrentUserAllHosts'; path = $PROFILE.CurrentUserAllHosts }
            [pscustomobject]@{ name = 'AllUsersCurrentHost'; path = $PROFILE.AllUsersCurrentHost }
            [pscustomobject]@{ name = 'AllUsersAllHosts'; path = $PROFILE.AllUsersAllHosts }
        ) | ForEach-Object {
            [pscustomobject]@{
                name = $_.name
                path = $_.path
                exists = [IO.File]::Exists($_.path)
            }
        }

        $pwshResolution = Resolve-ToolCommand -CommandName 'pwsh'
        $windowsPowerShellResolution = Resolve-ToolCommand -CommandName 'powershell.exe'
        $windowsPowerShell = [pscustomobject]@{
            present = $windowsPowerShellResolution.candidates.Count -gt 0
            version = $null
            commandCandidates = @($windowsPowerShellResolution.candidates)
        }
        if ($windowsPowerShell.present) {
            $windowsPowerShellExecution = Invoke-ExternalCommand `
                -FilePath $windowsPowerShellResolution.selected.path `
                -Arguments @('-NoProfile', '-NonInteractive', '-Command', '$PSVersionTable.PSVersion.ToString()')
            if ($windowsPowerShellExecution.exitCode -eq 0) {
                $windowsPowerShell.version = $windowsPowerShellExecution.standardOutput.Trim()
            }
        }

        $activeExecutable = $null
        $activeProcess = Get-Process -Id $PID -ErrorAction SilentlyContinue
        if ($activeProcess) {
            $activeExecutable = $activeProcess.Path
        }

        $pester = @(Get-Module -Name Pester -ListAvailable -ErrorAction SilentlyContinue | ForEach-Object {
            [pscustomobject]@{
                version = $_.Version.ToString()
                path = $_.ModuleBase
            }
        })

        New-CollectorResult -CollectorId 'PowerShellHealth' -Status Available -Data ([pscustomobject]@{
            active = [pscustomobject]@{
                edition = [string] $PSVersionTable.PSEdition
                version = $PSVersionTable.PSVersion.ToString()
                executable = $activeExecutable
            }
            windowsPowerShell = $windowsPowerShell
            powerShell7 = [pscustomobject]@{
                commandCandidates = @($pwshResolution.candidates)
                selectedCommand = $pwshResolution.selected
            }
            executionPolicies = $executionPolicies
            effectiveExecutionPolicy = $effectivePolicy
            profiles = @($profiles)
            psModulePath = @($modulePathEntries)
            pester = @($pester)
        })
    } catch {
        New-CollectorResult -CollectorId 'PowerShellHealth' -Status Error -ErrorMessage $_.Exception.Message
    }
}