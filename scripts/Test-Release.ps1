#Requires -Version 7.0
<# Runs the local/CI release gate without publishing or changing installed modules. #>
param()
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Write-Host "PowerShell $($PSVersionTable.PSVersion)"

$files = @(Get-ChildItem (Join-Path $repoRoot 'src') -Recurse -File -Include *.ps1,*.psm1,*.psd1)
foreach ($file in $files) {
    $tokens = $null; $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count) { throw "Production parser failed: $($file.Name)" }
}
Write-Host "Parser: $($files.Count) production files; 0 errors"
$manifestPath = Join-Path $repoRoot 'src\DevRigInspector.psd1'
$manifest = Test-ModuleManifest -Path $manifestPath
if ($manifest.Version.ToString() -ne '0.5.0' -or $manifest.PowerShellVersion.ToString() -ne '7.0') { throw 'Unexpected release manifest versions' }
Write-Host 'Manifest: valid; ModuleVersion 0.5.0; PowerShellVersion 7.0'

$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$work = Join-Path $tempRoot ("dev rig's acceptance-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $work | Out-Null
try {
    Push-Location $work
    try { $package = & (Join-Path $PSScriptRoot 'Build-ModulePackage.ps1') } finally { Pop-Location }
    $extracted = Join-Path $work 'extracted'
    Expand-Archive -LiteralPath $package.ZipPath -DestinationPath $extracted
    $moduleRoot = Join-Path $work 'Modules'
    $installed = Join-Path $moduleRoot 'DevRigInspector\0.5.0'
    New-Item -ItemType Directory -Path $installed -Force | Out-Null
    Get-ChildItem -LiteralPath $extracted | Copy-Item -Destination $installed -Recurse
    $probe = Join-Path $work 'probe.ps1'
    @'
param([string] $Mode, [string] $ExpectedModuleBase)
$ErrorActionPreference = 'Stop'
if ($Mode -eq 'Legacy') {
    if ($PSVersionTable.PSVersion.Major -ne 5) { throw 'Expected Windows PowerShell 5.1' }
    try { Import-Module .\DevRigInspector.psd1 -ErrorAction Stop }
    catch {
        if ($_.FullyQualifiedErrorId -notlike '*Modules_InsufficientPowerShellVersion*') { throw 'Unexpected legacy import failure' }
        'Windows PowerShell 5.1: manifest runtime requirement enforced'
        exit 0
    }
    throw 'Legacy import unexpectedly succeeded'
}
if ($Mode -eq 'Installed') { Import-Module DevRigInspector } else { Import-Module .\DevRigInspector.psd1 }
$module = Get-Module DevRigInspector
if ($module.ModuleBase -ne $ExpectedModuleBase -or $module.Version.ToString() -ne '0.5.0') { throw 'Wrong module loaded' }
$names = @(Get-Command -Module DevRigInspector | Sort-Object Name | Select-Object -ExpandProperty Name)
if (($names -join ',') -ne 'Compare-DevRigInspection,Invoke-DevRigInspection') { throw 'Unexpected public exports' }
Get-Command Invoke-DevRigInspection,Compare-DevRigInspection -ErrorAction Stop | Out-Null
$inventory = Invoke-DevRigInspection -PassThru 6>$null
if ($inventory.schemaVersion -ne '0.2' -or $inventory.collectorVersion -ne '0.5.0') { throw 'Wrong inventory versions' }
$comparison = Compare-DevRigInspection -Reference $inventory -Current $inventory -JsonOnly | ConvertFrom-Json
if ($comparison.comparisonVersion -ne '0.5.0' -or $comparison.comparisonSchemaVersion -ne '0.1' -or $comparison.summary.totalChanges -ne 0) { throw 'Wrong comparison contract' }
$json = $inventory | ConvertTo-Json -Depth 20
if ($json -match '"(?:standardOutput|standardError|exitCode)"\s*:') { throw 'Raw process property serialized' }
foreach ($tool in $inventory.tools) {
    if ($tool.PSObject.Properties.Name -contains 'command' -or $tool.PSObject.Properties.Name -contains 'rawVersion') { throw 'Raw tool evidence serialized' }
}
if ($json -match 'ghp_FAKE_SECRET_SHOULD_NOT_SERIALIZE|npm_FAKE_SECRET_SHOULD_NOT_SERIALIZE|Authorization:\s*Bearer\s+\S+|password=FAKE|stderr-secret-value') { throw 'Privacy scan failed' }
"$Mode package: imported 0.5.0; inventory 0.2/0.5.0; comparison 0.1/0.5.0; privacy property scan passed"
"Exports: $($names -join ', ')"
'@
    | Set-Content -LiteralPath $probe -Encoding utf8

    function Invoke-AcceptanceChild {
        param([string] $Executable, [string] $Mode, [string] $Directory, [string] $ExpectedBase)
        $start = [Diagnostics.ProcessStartInfo]::new()
        $start.FileName = $Executable
        $start.WorkingDirectory = $Directory
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        $arguments = @('-NoProfile', '-NonInteractive')
        if ($Mode -eq 'Legacy') {
            # Permit only this temporary acceptance script under restrictive machine policy.
            $arguments += @('-ExecutionPolicy', 'Bypass')
        }
        $arguments += @('-File', $probe, '-Mode', $Mode, '-ExpectedModuleBase', $ExpectedBase)
        foreach ($arg in $arguments) { $start.ArgumentList.Add($arg) }
        if ($Mode -eq 'Installed') {
            # Child-only: never mutate the calling process or persistent PSModulePath.
            $start.Environment['PSModulePath'] = $moduleRoot + [IO.Path]::PathSeparator + $start.Environment['PSModulePath']
        }
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $start
        try {
            [void]$process.Start()
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit(180000)) { $process.Kill($true); throw "$Mode acceptance timed out" }
            $safeOutput = $stdout.GetAwaiter().GetResult()
            $null = $stderr.GetAwaiter().GetResult()
            if ($process.ExitCode -ne 0) { throw "$Mode acceptance failed; reproduce locally to inspect detailed probe errors" }
            Write-Host $safeOutput.Trim()
        } finally { $process.Dispose() }
    }

    $pwsh = Join-Path $PSHOME 'pwsh.exe'
    Invoke-AcceptanceChild -Executable $pwsh -Mode Extracted -Directory $extracted -ExpectedBase $extracted
    Invoke-AcceptanceChild -Executable $pwsh -Mode Installed -Directory $work -ExpectedBase $installed
    $legacy = Get-Command powershell.exe -ErrorAction SilentlyContinue
    if ($legacy) { Invoke-AcceptanceChild -Executable $legacy.Source -Mode Legacy -Directory $extracted -ExpectedBase $extracted }
    else { Write-Host 'Windows PowerShell 5.1: unavailable; runtime rejection check skipped' }
    Write-Host "Package: $($package.ZipPath)"
    [pscustomobject]@{ PackagePath = $package.ZipPath; ParserFiles = $files.Count; Extracted = 'Passed'; Installed = 'Passed'; Legacy = $(if ($legacy) { 'Passed' } else { 'Unavailable' }) }
} finally {
    $resolvedWork = [IO.Path]::GetFullPath($work)
    if ((Split-Path $resolvedWork -Parent).TrimEnd('\') -ne $tempRoot.TrimEnd('\')) { throw 'Unexpected cleanup target' }
    Remove-Item -LiteralPath $resolvedWork -Recurse -Force
}
