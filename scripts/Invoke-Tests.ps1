$ErrorActionPreference = 'Stop'
Import-Module Pester -ErrorAction Stop
Invoke-Pester -Path (Join-Path $PSScriptRoot '..\tests')