@echo off
setlocal

where pwsh.exe >nul 2>nul
if errorlevel 1 goto :no_pwsh

pwsh.exe -NoLogo -NoProfile -File "%~dp0Start-DevRigInspector.ps1"
exit /b %ERRORLEVEL%

:no_pwsh
echo.
echo Dev Rig Inspector requires PowerShell 7 or later.
echo.
echo PowerShell 7 was not found on this computer.
echo.
echo Install it with:
echo   winget install --id Microsoft.PowerShell --source winget
echo.
echo Official installation guidance:
echo   https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows
echo.
echo Then run Start-DevRigInspector.cmd again.
echo.
echo Dev Rig Inspector does not install or modify PowerShell automatically.
echo.
exit /b 1
