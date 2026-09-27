@echo off
chcp 65001 >nul
REM Doppelklick: startet die Weboberflaeche auf 127.0.0.1 und oeffnet sie im Browser.
REM Dieses Fenster muss offen bleiben, solange die Oberflaeche benutzt wird.
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Starte-Weboberflaeche.ps1" %*
echo.
pause
