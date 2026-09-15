$modulePath = Join-Path $PSScriptRoot '..\src\DevRigInspector.psd1'
Import-Module $modulePath -Force

Describe 'Invoke-ExternalCommand' {
    It 'captures output, errors, and exit code' {
        InModuleScope DevRigInspector {
            $result = Invoke-ExternalCommand -FilePath (Get-Command pwsh).Path -Arguments @('-NoProfile', '-Command', '[Console]::Write("ok"); [Console]::Error.Write("warn")')
            $result.exitCode | Should Be 0
            $result.standardOutput | Should Be 'ok'
            $result.standardError | Should Be 'warn'
            $result.timedOut | Should Be $false
        }
    }

    It 'terminates a command that exceeds the timeout' {
        InModuleScope DevRigInspector {
            $result = Invoke-ExternalCommand -FilePath (Get-Command pwsh).Path -Arguments @('-NoProfile', '-Command', 'Start-Sleep -Seconds 5') -TimeoutMilliseconds 100
            $result.timedOut | Should Be $true
            $result.exitCode | Should Be $null
        }
    }
}