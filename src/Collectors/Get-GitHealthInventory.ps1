function Invoke-GitHealthCommand {
    param(
        [Parameter(Mandatory)] [object] $Resolution,
        [Parameter(Mandatory)] [string[]] $Arguments
    )

    if (-not $Resolution.selected) {
        return $null
    }

    try {
        Invoke-ExternalCommand -FilePath $Resolution.selected.path -Arguments $Arguments
    } catch {
        [pscustomobject]@{
            arguments = @($Arguments)
            exitCode = $null
            standardOutput = ''
            standardError = ''
            timedOut = $false
            probeFailed = $true
            probeError = $_.Exception.Message
        }
    }
}

function Get-GitConfigValue {
    param(
        [Parameter(Mandatory)] [object] $Resolution,
        [Parameter(Mandatory)] [string] $Key
    )

    $result = Invoke-GitHealthCommand -Resolution $Resolution -Arguments @('config', '--global', '--get', $Key)
    [pscustomobject]@{
        configured = $null -ne $result -and $result.exitCode -eq 0 -and $result.standardOutput.Trim().Length -gt 0
        value = if ($null -ne $result -and $result.exitCode -eq 0) { $result.standardOutput.Trim() } else { $null }
    }
}

function Get-SafeCredentialHelperEvidence {
    param([Parameter(Mandatory)] [object] $Resolution)

    $result = Invoke-GitHealthCommand -Resolution $Resolution -Arguments @('config', '--global', '--get-all', 'credential.helper')
    $helpers = @()
    if ($null -ne $result -and $result.exitCode -eq 0) {
        $helpers = @($result.standardOutput -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 } | ForEach-Object {
            $helper = $_.Trim().ToLowerInvariant()
            switch ($helper) {
                'manager' { 'manager'; break }
                'manager-core' { 'manager-core'; break }
                'wincred' { 'wincred'; break }
                'store' { 'store'; break }
                'cache' { 'cache'; break }
                default { if ($helper -match '^!') { 'custom' } else { 'unknown' } }
            }
        } | Select-Object -Unique)
    }

    [pscustomobject]@{
        configured = $helpers.Count -gt 0
        types = $helpers
    }
}

function Get-SafeGitProtocolEvidence {
    param([Parameter(Mandatory)] [object] $Resolution)

    $result = Invoke-GitHealthCommand -Resolution $Resolution -Arguments @('config', '--global', '--get-regexp', '^(url\..*\.insteadOf|protocol\..*\.allow)$')
    $keys = @()
    if ($null -ne $result -and $result.exitCode -eq 0) {
        $keys = @($result.standardOutput -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 } | ForEach-Object {
            ($_.Trim() -split '\s+', 2)[0]
        })
    }

    [pscustomobject]@{
        configured = $keys.Count -gt 0
        keys = $keys
    }
}

function Get-GitHealthInventory {
    $gitResolution = Resolve-ToolCommand -CommandName 'git'
    $ghResolution = Resolve-ToolCommand -CommandName 'gh'

    $git = [pscustomobject]@{
        installed = $null -ne $gitResolution.selected
        selectedCommand = $gitResolution.selected
        commandCandidates = @($gitResolution.candidates)
        version = $null
        identity = [pscustomobject]@{
            name = [pscustomobject]@{ configured = $false; value = $null }
            email = [pscustomobject]@{ configured = $false; value = $null }
            inferred = [pscustomobject]@{ available = $false; name = $null; email = $null }
        }
        defaultBranch = [pscustomobject]@{ configured = $false; value = $null }
        autocrlf = [pscustomobject]@{ configured = $false; value = $null }
        credentialHelper = [pscustomobject]@{ configured = $false; types = @() }
        protocol = [pscustomobject]@{ configured = $false; keys = @() }
    }

    if ($git.installed) {
        $versionResult = Invoke-GitHealthCommand -Resolution $gitResolution -Arguments @('--version')
        if ($versionResult -and $versionResult.exitCode -eq 0) {
            $git.version = $versionResult.standardOutput.Trim()
        }

        $git.identity.name = Get-GitConfigValue -Resolution $gitResolution -Key 'user.name'
        $git.identity.email = Get-GitConfigValue -Resolution $gitResolution -Key 'user.email'
        $git.defaultBranch = Get-GitConfigValue -Resolution $gitResolution -Key 'init.defaultBranch'
        $git.autocrlf = Get-GitConfigValue -Resolution $gitResolution -Key 'core.autocrlf'
        $git.credentialHelper = Get-SafeCredentialHelperEvidence -Resolution $gitResolution
        $git.protocol = Get-SafeGitProtocolEvidence -Resolution $gitResolution

        $identityResult = Invoke-GitHealthCommand -Resolution $gitResolution -Arguments @('var', 'GIT_AUTHOR_IDENT')
        if ($identityResult -and $identityResult.exitCode -eq 0) {
            $identity = $identityResult.standardOutput.Trim()
            if ($identity -match '^(.+?) <([^>]+)>') {
                $git.identity.inferred = [pscustomobject]@{
                    available = $true
                    name = $Matches[1]
                    email = $Matches[2]
                }
            }
        }
    }

    $github = [pscustomobject]@{
        installed = $null -ne $ghResolution.selected
        selectedCommand = $ghResolution.selected
        commandCandidates = @($ghResolution.candidates)
        version = $null
        authentication = [pscustomobject]@{
            checked = $false
            authenticated = $false
            available = $false
            hosts = @()
        }
    }

    if ($github.installed) {
        $versionResult = Invoke-GitHealthCommand -Resolution $ghResolution -Arguments @('--version')
        if ($versionResult -and $versionResult.exitCode -eq 0) {
            $github.version = $versionResult.standardOutput.Trim()
        }
        $authResult = Invoke-GitHealthCommand -Resolution $ghResolution -Arguments @('auth', 'status')
        if ($authResult) {
            $authText = ($authResult.standardOutput + "`n" + $authResult.standardError)
            $hosts = @([regex]::Matches($authText, '(?im)logged in to\s+([^\s(]+)') | ForEach-Object { $_.Groups[1].Value.TrimEnd(':') } | Select-Object -Unique)
            $unauthenticatedResponse = $authText -match '(?i)not logged in|not logged into|no authenticated user'
            $github.authentication = [pscustomobject]@{
                checked = $true
                authenticated = $authResult.exitCode -eq 0 -and $hosts.Count -gt 0
                available = $authResult.exitCode -eq 0 -or $unauthenticatedResponse
                hosts = $hosts
            }
        }
    }

    New-CollectorResult -CollectorId 'GitHealth' -Status Available -Data ([pscustomobject]@{
        git = $git
        githubCli = $github
    })
}