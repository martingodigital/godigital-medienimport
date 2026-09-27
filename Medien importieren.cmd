@echo off
chcp 65001 >nul
REM Doppelklick: importiert alle Dateien aus der Inbox in die Mediathek.
REM Umgeht die PowerShell-Execution-Policy, laeuft daher ohne Vorkonfiguration.
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Importiere-Medien.ps1" %*
echo.
pause
