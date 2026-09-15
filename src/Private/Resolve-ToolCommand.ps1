function Resolve-ToolCommand {
    param([Parameter(Mandatory)] [string] $CommandName)

    $commands = @(Get-Command -Name $CommandName -All -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandType -eq 'Application' -and $_.Path })

    $candidates = @(
        for ($index = 0; $index -lt $commands.Count; $index++) {
            $command = $commands[$index]
            $directory = Split-Path -Parent $command.Path
        [pscustomobject]@{
                name = $command.Name
                commandType = [string] $command.CommandType
                path = $command.Path
                source = $command.Source
                normalizedParentDirectory = (ConvertTo-NormalizedPathEntry -RawEntry $directory).normalized
                order = $index + 1
            }
        }
    )

    [pscustomobject]@{
        selected = if ($candidates.Count -gt 0) { $candidates[0] } else { $null }
        candidates = $candidates
    }
}