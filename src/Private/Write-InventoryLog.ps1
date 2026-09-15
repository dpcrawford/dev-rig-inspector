function Write-InventoryLog {
    param(
        [Parameter(Mandatory)] [string] $Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')] [string] $Level = 'INFO',
        [string] $Path
    )

    $line = '{0} [{1}] {2}' -f [DateTime]::UtcNow.ToString('o'), $Level, $Message
    if ($Path) {
        Add-Content -LiteralPath $Path -Value $line -Encoding utf8
    }
    Write-Verbose $line
}