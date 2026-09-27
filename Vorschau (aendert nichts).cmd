@echo off
chcp 65001 >nul
REM Doppelklick: zeigt nur an, was importiert WUERDE (-WhatIf). Aendert nichts.
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Importiere-Medien.ps1" -WhatIf %*
echo.
pause
