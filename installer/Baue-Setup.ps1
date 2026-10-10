<#
.SYNOPSIS
    Baut das Installationsprogramm fuer GoDigital Medienimport.

.DESCRIPTION
    Liest die Versionsnummer aus VERSION, legt die ExifTool-Fassung samt
    Pruefsumme fest, sucht den Inno-Setup-Compiler und ruft ihn auf. Ergebnis
    ist installer\ausgabe\GoDigital-Medienimport-Setup-<version>.exe.

.PARAMETER ISCC
    Pfad zu ISCC.exe. Ohne Angabe wird in den ueblichen Ordnern gesucht.

.PARAMETER ArchivDatei
    Bereits heruntergeladenes ExifTool-Archiv, falls der Download scheitert.

.PARAMETER OhneExifTool
    Fassung nicht neu ermitteln, sondern exiftool-fassung.txt wiederverwenden.

.EXAMPLE
    .\installer\Baue-Setup.ps1
.EXAMPLE
    .\installer\Baue-Setup.ps1 -OhneExifTool
#>
[CmdletBinding()]
param(
    [string]$ISCC,
    [string]$ArchivDatei,
    [switch]$OhneExifTool
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

# --- ExifTool-Fassung festlegen ----------------------------------------------
# Version und Pruefsumme werden beim Bauen bestimmt. Nur so steht fest, welche
# Datei beim Nutzer ankommt, und nur so merkt der Installer, wenn auf dem
# Spiegelserver etwas anderes liegt.
$FassungsDatei = Join-Path $Hier "exiftool-fassung.txt"
$BauAgent      = "GoDigital-Medienimport-Build/1.0"

if (-not $OhneExifTool) {
    Write-Host "Ermittle die aktuelle ExifTool-Fassung ..."
    $exifVersion = (Invoke-WebRequest -Uri "https://exiftool.org/ver.txt" -UseBasicParsing).Content.Trim()
    if ($exifVersion -notmatch '^\d+(\.\d+)+$') {
        Write-Host "ver.txt lieferte keine Versionsnummer, sondern '$exifVersion'." -ForegroundColor Red; exit 1
    }
    $exifName = "exiftool-${exifVersion}_64.zip"
    # exiftool.org liefert fuer die ZIP-Datei 404; einzige Bezugsquelle ist SourceForge.
    $exifUrl  = "https://sourceforge.net/projects/exiftool/files/$exifName/download"

    if ($ArchivDatei) {
        $temp = $ArchivDatei
        if (-not (Test-Path -LiteralPath $temp -PathType Leaf)) {
            Write-Host "Archiv nicht gefunden: $temp" -ForegroundColor Red; exit 1
        }
        Write-Host "Nutze das uebergebene Archiv: $temp"
    } else {
        $temp = Join-Path $env:TEMP $exifName
        Write-Host "Lade $exifUrl ..."
        # Eigener User-Agent, und zwar bewusst keiner, der nach Browser aussieht:
        # SourceForge schickt browserartigen Clients eine HTML-Zwischenseite mit
        # einem ablaufenden Mirror-Token statt der Datei. Der Standardwert von
        # Invoke-WebRequest faellt darunter. Inno Setup meldet sich von sich aus
        # nicht als Browser und bekommt die Datei deshalb direkt.
        Invoke-WebRequest -Uri $exifUrl -OutFile $temp -UseBasicParsing -UserAgent $BauAgent
    }

    # SourceForge antwortet bei Stoerungen mit einer HTML-Seite und Status 200.
    # Ein ZIP beginnt mit "PK"; ohne diese Pruefung landete die Pruefsumme einer
    # Fehlerseite im Release.
    $kopf = [System.IO.File]::ReadAllBytes($temp)[0..1]
    if ($kopf[0] -ne 0x50 -or $kopf[1] -ne 0x4B) {
        Write-Host "Die geladene Datei ist kein ZIP-Archiv: $temp" -ForegroundColor Red
        Write-Host "Die Adresse von Hand im Browser oeffnen und die Datei mit -ArchivDatei uebergeben." -ForegroundColor Red
        exit 1
    }

    $exifHash = (Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash.ToUpperInvariant()
    if (-not $ArchivDatei) { Remove-Item -LiteralPath $temp -Force }

    @(
        "# Vom Bauskript geschrieben. Welche ExifTool-Fassung in diesem Stand steckt."
        "Version=$exifVersion"
        "Datei=$exifName"
        "URL=$exifUrl"
        "SHA256=$exifHash"
    ) | Set-Content -LiteralPath $FassungsDatei -Encoding UTF8
}

if (-not (Test-Path -LiteralPath $FassungsDatei -PathType Leaf)) {
    Write-Host "exiftool-fassung.txt fehlt. Einmal ohne -OhneExifTool bauen." -ForegroundColor Red; exit 1
}
$fassung = @{}
foreach ($zeile in [System.IO.File]::ReadAllLines($FassungsDatei)) {
    if ($zeile -match '^(\w+)=(.+)$') { $fassung[$Matches[1]] = $Matches[2] }
}
foreach ($schluessel in @('Version','Datei','URL','SHA256')) {
    if (-not $fassung.ContainsKey($schluessel)) {
        Write-Host "In exiftool-fassung.txt fehlt der Eintrag $schluessel." -ForegroundColor Red; exit 1
    }
}

# --- Bauen -------------------------------------------------------------------
$Quelle = Join-Path $Hier "GoDigital-Medienimport.iss"
Write-Host "Version:  $Version"
Write-Host "ExifTool: $($fassung['Version'])  SHA256 $($fassung['SHA256'])"
Write-Host "Compiler: $Compiler"
Write-Host ""

& $Compiler "/DAppVersion=$Version" `
            "/DExifToolVersion=$($fassung['Version'])" `
            "/DExifToolDatei=$($fassung['Datei'])" `
            "/DExifToolUrl=$($fassung['URL'])" `
            "/DExifToolHash=$($fassung['SHA256'])" `
            $Quelle
if ($LASTEXITCODE -ne 0) {
    Write-Host "Der Compiler brach mit Code $LASTEXITCODE ab." -ForegroundColor Red; exit 1
}

$Ergebnis = Join-Path $Hier "ausgabe\GoDigital-Medienimport-Setup-$Version.exe"
if (-not (Test-Path -LiteralPath $Ergebnis -PathType Leaf)) {
    Write-Host "Der Compiler meldete Erfolg, die Datei fehlt aber: $Ergebnis" -ForegroundColor Red; exit 1
}
Write-Host ""
Write-Host "Fertig: $Ergebnis" -ForegroundColor Cyan
