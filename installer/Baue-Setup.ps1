<#
.SYNOPSIS
    Baut das Installationsprogramm fuer GoDigital Medienimport.

.DESCRIPTION
    Liest die Versionsnummer aus VERSION, sucht den Inno-Setup-Compiler und
    ruft ihn auf. Ergebnis ist installer\ausgabe\GoDigital-Medienimport-Setup-
    <version>.exe.

.PARAMETER ISCC
    Pfad zu ISCC.exe. Ohne Angabe wird in den ueblichen Ordnern gesucht.

.EXAMPLE
    .\installer\Baue-Setup.ps1
#>
[CmdletBinding()]
param(
    [string]$ISCC
)

$ErrorActionPreference = 'Stop'
$Hier = $PSScriptRoot
$Root = Split-Path -Parent $Hier

# --- Version: einzige Quelle ist VERSION -------------------------------------
$VersionsDatei = Join-Path $Root "VERSION"
if (-not (Test-Path -LiteralPath $VersionsDatei -PathType Leaf)) {
    Write-Host "VERSION nicht gefunden: $VersionsDatei" -ForegroundColor Red; exit 1
}
$Version = ([System.IO.File]::ReadAllText($VersionsDatei)).Trim()
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    Write-Host "VERSION enthaelt keine Nummer der Form 1.0.0, sondern '$Version'." -ForegroundColor Red; exit 1
}

# --- Compiler suchen ---------------------------------------------------------
# Nicht fest verdrahten: Inno Setup laesst sich ins Benutzerprofil oder in beide
# Programmordner installieren.
function Get-Compiler {
    param([string]$Vorgabe)
    if ($Vorgabe) {
        if (Test-Path -LiteralPath $Vorgabe -PathType Leaf) { return $Vorgabe }
        Write-Host "ISCC.exe nicht gefunden: $Vorgabe" -ForegroundColor Red; exit 1
    }
    $kandidaten = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
        (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
    )
    foreach ($k in $kandidaten) {
        if ($k -and (Test-Path -LiteralPath $k -PathType Leaf)) { return $k }
    }
    Write-Host "Inno Setup 6 nicht gefunden. Gesucht wurde in:" -ForegroundColor Red
    $kandidaten | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host "Download: https://jrsoftware.org/isdl.php" -ForegroundColor Red
    exit 1
}
$Compiler = Get-Compiler -Vorgabe $ISCC

# --- Bauen -------------------------------------------------------------------
$Quelle = Join-Path $Hier "GoDigital-Medienimport.iss"
Write-Host "Version:  $Version"
Write-Host "Compiler: $Compiler"
Write-Host ""

& $Compiler "/DAppVersion=$Version" $Quelle
if ($LASTEXITCODE -ne 0) {
    Write-Host "Der Compiler brach mit Code $LASTEXITCODE ab." -ForegroundColor Red; exit 1
}

$Ergebnis = Join-Path $Hier "ausgabe\GoDigital-Medienimport-Setup-$Version.exe"
if (-not (Test-Path -LiteralPath $Ergebnis -PathType Leaf)) {
    Write-Host "Der Compiler meldete Erfolg, die Datei fehlt aber: $Ergebnis" -ForegroundColor Red; exit 1
}
Write-Host ""
Write-Host "Fertig: $Ergebnis" -ForegroundColor Cyan
