function Resolve-ToolCommand {
    param([Parameter(Mandatory)] [string] $CommandName)

    $commands = @(Get-Command -Name $CommandName -All -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandType -eq 'Application' -and $_.Path })

    $candidates = @($commands | ForEach-Object {
        [pscustomobject]@{
            path = $_.Path
            source = 'Path'
        }
    })

    [pscustomobject]@{
        selected = if ($candidates.Count -gt 0) { $candidates[0] } else { $null }
        candidates = $candidates
    }
}