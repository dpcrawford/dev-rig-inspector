function Get-GitHealthDiagnostics {
    param([Parameter(Mandatory)] [object] $GitHealth)

    $findings = @()
    $git = $GitHealth.git
    $github = $GitHealth.githubCli

    if ($git.installed) {
        $missingIdentity = @(
            if (-not $git.identity.name.configured) { 'user.name' }
            if (-not $git.identity.email.configured) { 'user.email' }
        )
        if ($missingIdentity.Count -gt 0) {
            $inferredMessage = if ($git.identity.inferred.available) {
                ' Git can still create commits using an inferred identity, but that is not equivalent to explicit configuration.'
            } else { '' }
            $findings += New-DiagnosticFinding `
                -Code 'GitIdentityMissing' `
                -Severity Warning `
                -Category 'Git' `
                -Title 'Git identity is not explicitly configured' `
                -Message ('Git is missing explicit configuration for: {0}.{1}' -f ($missingIdentity -join ', '), $inferredMessage) `
                -AffectedComponent 'Git.Identity' `
                -Evidence @([pscustomobject]@{
                    missingFields = $missingIdentity
                    nameConfigured = $git.identity.name.configured
                    emailConfigured = $git.identity.email.configured
                    inferredIdentityAvailable = $git.identity.inferred.available
                }) `
                -Recommendation 'Configure the intended global Git user.name and user.email explicitly before creating commits.'
        } else {
            $findings += New-DiagnosticFinding `
                -Code 'GitIdentityConfigured' `
                -Severity Info `
                -Category 'Git' `
                -Title 'Git identity is explicitly configured' `
                -Message 'Both global Git identity fields are explicitly configured.' `
                -AffectedComponent 'Git.Identity' `
                -Evidence @([pscustomobject]@{ nameConfigured = $true; emailConfigured = $true }) `
                -Recommendation 'No action is required.'
        }

        if ($git.defaultBranch.configured) {
            $findings += New-DiagnosticFinding `
                -Code 'GitDefaultBranchConfigured' `
                -Severity Info `
                -Category 'Git' `
                -Title 'Git default branch is configured' `
                -Message ('New repositories default to the explicitly configured branch: {0}' -f $git.defaultBranch.value) `
                -AffectedComponent 'Git.init.defaultBranch' `
                -Evidence @($git.defaultBranch) `
                -Recommendation 'No action is required unless this default differs from your workflow.'
        }

        if ($git.autocrlf.configured) {
            $findings += New-DiagnosticFinding `
                -Code 'GitLineEndingPolicyDetected' `
                -Severity Info `
                -Category 'Git' `
                -Title 'Git line-ending policy is configured' `
                -Message ('Git core.autocrlf is configured as: {0}' -f $git.autocrlf.value) `
                -AffectedComponent 'Git.core.autocrlf' `
                -Evidence @($git.autocrlf) `
                -Recommendation 'No action is required unless this policy conflicts with a repository workflow.'
        }

        if ($git.credentialHelper.configured) {
            $findings += New-DiagnosticFinding `
                -Code 'GitCredentialHelperConfigured' `
                -Severity Info `
                -Category 'Git' `
                -Title 'Git credential helper is configured' `
                -Message 'Git has a credential helper configured without exposing credential contents.' `
                -AffectedComponent 'Git.credentialHelper' `
                -Evidence @($git.credentialHelper) `
                -Recommendation 'No action is required unless authentication behavior is unexpected.'
        }
    }

    if ($github.installed) {
        $auth = $github.authentication
        if (-not $auth.checked -or -not $auth.available) {
            $findings += New-DiagnosticFinding `
                -Code 'GitHubCliAuthenticationUnavailable' `
                -Severity Info `
                -Category 'GitHub' `
                -Title 'GitHub CLI authentication status is unavailable' `
                -Message 'GitHub CLI is installed, but authentication status could not be established safely.' `
                -AffectedComponent 'GitHubCli.Authentication' `
                -Evidence @($auth) `
                -Recommendation 'Run gh auth status interactively when you need to inspect or configure GitHub CLI authentication.'
        } elseif ($auth.authenticated) {
            $findings += New-DiagnosticFinding `
                -Code 'GitHubCliAuthenticated' `
                -Severity Info `
                -Category 'GitHub' `
                -Title 'GitHub CLI is authenticated' `
                -Message 'GitHub CLI reports an authenticated session for the detected host.' `
                -AffectedComponent 'GitHubCli.Authentication' `
                -Evidence @([pscustomobject]@{ hosts = $auth.hosts }) `
                -Recommendation 'No action is required.'
        } else {
            $findings += New-DiagnosticFinding `
                -Code 'GitHubCliNotAuthenticated' `
                -Severity Info `
                -Category 'GitHub' `
                -Title 'GitHub CLI is not authenticated' `
                -Message 'GitHub CLI is installed but does not report an authenticated session.' `
                -AffectedComponent 'GitHubCli.Authentication' `
                -Evidence @([pscustomobject]@{ checked = $true; authenticated = $false; hosts = @() }) `
                -Recommendation 'Authenticate with gh only when GitHub CLI operations require it.'
        }
    }

    @($findings)
}