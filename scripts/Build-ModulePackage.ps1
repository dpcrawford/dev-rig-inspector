#Requires -Version 7.0
<#
    Builds a versioned, installable copy of the DevRigInspector module from the repository's
    src/ tree and packages it into a ZIP. Never touches installed modules or publishes anything.
#>
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$srcRoot = Join-Path -Path $repoRoot -ChildPath 'src'
$manifestSourcePath = Join-Path -Path $srcRoot -ChildPath 'DevRigInspector.psd1'

$manifestData = Import-PowerShellDataFile -Path $manifestSourcePath
$version = $manifestData.ModuleVersion
$expectedCommands = @($manifestData.FunctionsToExport | Sort-Object)

$distRoot = Join-Path -Path $repoRoot -ChildPath 'dist'
$packageName = "DevRigInspector-$version"
$stagingDir = Join-Path -Path $distRoot -ChildPath $packageName
$zipPath = Join-Path -Path $distRoot -ChildPath "$packageName.zip"

Write-Host "Building DevRigInspector package version $version"

# Only ever clean/recreate our own build output directory.
if (Test-Path -LiteralPath $distRoot) {
    Remove-Item -LiteralPath $distRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

# Copy only the files required at runtime; tests/docs/scripts/output/.git are never touched.
Copy-Item -LiteralPath (Join-Path $srcRoot 'DevRigInspector.psd1') -Destination $stagingDir
Copy-Item -LiteralPath (Join-Path $srcRoot 'DevRigInspector.psm1') -Destination $stagingDir
Copy-Item -LiteralPath (Join-Path $srcRoot 'Public') -Destination $stagingDir -Recurse
Copy-Item -LiteralPath (Join-Path $srcRoot 'Private') -Destination $stagingDir -Recurse
Copy-Item -LiteralPath (Join-Path $srcRoot 'Collectors') -Destination $stagingDir -Recurse

$readmePath = Join-Path -Path $repoRoot -ChildPath 'README.md'
if (Test-Path -LiteralPath $readmePath) {
    Copy-Item -LiteralPath $readmePath -Destination $stagingDir
}
$licensePath = Join-Path -Path $repoRoot -ChildPath 'LICENSE'
if (Test-Path -LiteralPath $licensePath) {
    Copy-Item -LiteralPath $licensePath -Destination $stagingDir
}

$packagedManifestPath = Join-Path -Path $stagingDir -ChildPath 'DevRigInspector.psd1'

Write-Host 'Validating packaged manifest...'
Test-ModuleManifest -Path $packagedManifestPath | Out-Null

Write-Host 'Importing packaged module from staging directory...'
Import-Module $packagedManifestPath -Force

$actualCommands = @(Get-Command -Module DevRigInspector | Select-Object -ExpandProperty Name | Sort-Object)
if (Compare-Object -ReferenceObject $expectedCommands -DifferenceObject $actualCommands) {
    Remove-Module -Name DevRigInspector -Force -ErrorAction SilentlyContinue
    throw "Packaged module exports do not match the manifest. Expected: $($expectedCommands -join ', '). Actual: $($actualCommands -join ', ')."
}
Write-Host "Confirmed exported commands: $($actualCommands -join ', ')"

Remove-Module -Name DevRigInspector -Force -ErrorAction SilentlyContinue

Write-Host "Creating ZIP: $zipPath"
Compress-Archive -Path (Join-Path $stagingDir '*') -DestinationPath $zipPath -Force

Write-Host ''
Write-Host 'Package build complete.'

[pscustomobject]@{
    Version = $version
    StagingPath = $stagingDir
    ZipPath = $zipPath
    ExportedCommands = $actualCommands
}
