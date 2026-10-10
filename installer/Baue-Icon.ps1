<#
.SYNOPSIS
    Baut GoDigital-Medienimport.ico aus GoDigital-Medienimport.svg.

.DESCRIPTION
    Rendert das Bildzeichen mit Chrome in jeder benoetigten Groesse einzeln und
    setzt daraus eine .ico-Datei zusammen. Einzeln rendern statt herunterskalieren:
    nur so bleiben die 16- und 20-Pixel-Fassungen scharf, und genau die sieht man
    in der Taskleiste und in der Liste der installierten Programme.

    Die Eintraege sind PNG-komprimiert. Das versteht Windows seit Vista, und der
    Inno-Setup-Compiler reicht die Datei unveraendert als Ressource weiter.

    Nur fuer die Entwicklung. Das Ergebnis ist eingecheckt; dieses Skript muss nur
    laufen, wenn sich das Bildzeichen aendert.

.PARAMETER Chrome
    Pfad zu chrome.exe. Ohne Angabe wird in den ueblichen Ordnern gesucht.

.PARAMETER Quelle
    Die SVG-Datei. Vorgabe: GoDigital-Medienimport.svg neben diesem Skript.

.PARAMETER Ziel
    Die zu schreibende .ico-Datei. Vorgabe: GoDigital-Medienimport.ico daneben.

.EXAMPLE
    .\installer\Baue-Icon.ps1
#>
[CmdletBinding()]
param(
    [string]$Chrome,
    [string]$Quelle,
    [string]$Ziel
)

$ErrorActionPreference = 'Stop'
$Hier = $PSScriptRoot

if (-not $Quelle) { $Quelle = Join-Path $Hier "GoDigital-Medienimport.svg" }
if (-not $Ziel)   { $Ziel   = Join-Path $Hier "GoDigital-Medienimport.ico" }

if (-not (Test-Path -LiteralPath $Quelle -PathType Leaf)) {
    Write-Host "Quelle nicht gefunden: $Quelle" -ForegroundColor Red; exit 1
}

# Die Groessen, die Windows abfragt. 256 steckt als PNG drin und wird fuer die
# grossen Kacheln im Explorer benutzt.
$Groessen = @(16, 20, 24, 32, 40, 48, 64, 128, 256)

# --- Chrome suchen -----------------------------------------------------------
function Get-Chrome {
    param([string]$Vorgabe)
    if ($Vorgabe) {
        if (Test-Path -LiteralPath $Vorgabe -PathType Leaf) { return $Vorgabe }
        Write-Host "chrome.exe nicht gefunden: $Vorgabe" -ForegroundColor Red; exit 1
    }
    $kandidaten = @(
        (Join-Path $env:ProgramFiles "Google\Chrome\Application\chrome.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Google\Chrome\Application\chrome.exe"),
        (Join-Path $env:LOCALAPPDATA "Google\Chrome\Application\chrome.exe"),
        (Join-Path $env:ProgramFiles "Microsoft\Edge\Application\msedge.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Microsoft\Edge\Application\msedge.exe")
    )
    foreach ($k in $kandidaten) {
        if ($k -and (Test-Path -LiteralPath $k -PathType Leaf)) { return $k }
    }
    Write-Host "Weder Chrome noch Edge gefunden. Gesucht wurde in:" -ForegroundColor Red
    $kandidaten | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    exit 1
}
$Browser = Get-Chrome -Vorgabe $Chrome

# --- Rendern -----------------------------------------------------------------
$Arbeit = Join-Path ([System.IO.Path]::GetTempPath()) ("gdmi-icon-" + [guid]::NewGuid().ToString("N"))
$null = New-Item -ItemType Directory -Path $Arbeit

try {
    $svgText = [System.IO.File]::ReadAllText($Quelle)

    # Liste statt Woerterbuch: Bei [ordered]@{} mit Zahlen als Schluessel greift
    # $bilder[16] auf die 17. Position zu und nicht auf den Schluessel 16.
    $bilder = New-Object System.Collections.Generic.List[object]

    Write-Host "Quelle:  $Quelle"
    Write-Host "Browser: $Browser"
    Write-Host ""

    foreach ($g in $Groessen) {
        # Huelle statt direktem Aufruf der SVG-Datei: die traegt eine feste
        # Pixelgroesse, und ein kleineres Fenster wuerde sie abschneiden statt
        # skalieren. In der Huelle fuellt sie das Fenster genau aus.
        $huelle = @(
            '<!DOCTYPE html><html><head><meta charset="utf-8"><style>'
            "html,body{margin:0;padding:0;background:transparent;width:${g}px;height:${g}px;overflow:hidden}"
            "svg{display:block;width:${g}px;height:${g}px}"
            '</style></head><body>'
            $svgText
            '</body></html>'
        ) -join "`n"

        $huelleDatei = Join-Path $Arbeit "huelle-$g.html"
        $pngDatei    = Join-Path $Arbeit "icon-$g.png"
        [System.IO.File]::WriteAllText($huelleDatei, $huelle, (New-Object System.Text.UTF8Encoding $false))

        # Die Fenstergroesse muss als EIN Zeichenkettenargument uebergeben werden.
        # Ohne Anfuehrungszeichen macht PowerShell aus "16,16" zwei Argumente, und
        # Chrome nimmt dann die Groesse aus seinem Profil.
        #
        # Chrome meldet auch den Erfolg ("... bytes written to file ...") auf dem
        # Fehlerkanal. Unter $ErrorActionPreference = 'Stop' bricht Windows
        # PowerShell 5.1 deswegen ab, obwohl nichts schiefging. Darum hier
        # voruebergehend 'Continue'; geprueft wird danach am Ergebnis.
        $vorher = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        & $Browser --headless=new --disable-gpu --hide-scrollbars `
                   --force-device-scale-factor=1 --default-background-color=00000000 `
                   "--window-size=$g,$g" --virtual-time-budget=4000 `
                   "--user-data-dir=$Arbeit\profil" `
                   "--screenshot=$pngDatei" `
                   ("file:///" + ($huelleDatei -replace '\\','/')) 2>&1 | Out-Null
        $ErrorActionPreference = $vorher

        if (-not (Test-Path -LiteralPath $pngDatei -PathType Leaf)) {
            Write-Host "Der Browser lieferte kein Bild fuer $g Pixel." -ForegroundColor Red; exit 1
        }

        # Gegenpruefen statt vertrauen: eine falsche Fenstergroesse faellt sonst
        # erst auf, wenn das fertige Icon im Explorer verzerrt aussieht.
        Add-Type -AssemblyName System.Drawing
        $bild = [System.Drawing.Image]::FromFile($pngDatei)
        $istBreite = $bild.Width; $istHoehe = $bild.Height
        $bild.Dispose()
        if ($istBreite -ne $g -or $istHoehe -ne $g) {
            Write-Host "Das Bild fuer $g Pixel ist ${istBreite}x${istHoehe} geworden." -ForegroundColor Red; exit 1
        }

        $daten = [System.IO.File]::ReadAllBytes($pngDatei)
        $bilder.Add([pscustomobject]@{ Groesse = $g; Daten = $daten })
        Write-Host ("  {0,3} Pixel  {1,6} Byte" -f $g, $daten.Length)
    }

    # --- ICO zusammensetzen --------------------------------------------------
    # Aufbau: ICONDIR (6 Byte), je Eintrag ein ICONDIRENTRY (16 Byte), danach die
    # Bilddaten. In der Groessenangabe steht 0 fuer 256.
    $strom   = New-Object System.IO.MemoryStream
    $schreib = New-Object System.IO.BinaryWriter($strom)

    $schreib.Write([uint16]0)                  # reserviert
    $schreib.Write([uint16]1)                  # Typ 1 = Icon
    $schreib.Write([uint16]$bilder.Count)

    $versatz = 6 + (16 * $bilder.Count)
    foreach ($eintrag in $bilder) {
        $mass = $(if ($eintrag.Groesse -ge 256) { 0 } else { $eintrag.Groesse })
        $schreib.Write([byte]$mass)            # Breite, 0 bedeutet 256
        $schreib.Write([byte]$mass)            # Hoehe
        $schreib.Write([byte]0)                # Farben in der Palette: keine
        $schreib.Write([byte]0)                # reserviert
        $schreib.Write([uint16]1)              # Ebenen
        $schreib.Write([uint16]32)             # Bit je Bildpunkt
        $schreib.Write([uint32]$eintrag.Daten.Length)
        $schreib.Write([uint32]$versatz)
        $versatz += $eintrag.Daten.Length
    }
    foreach ($eintrag in $bilder) { $schreib.Write($eintrag.Daten) }

    $schreib.Flush()
    [System.IO.File]::WriteAllBytes($Ziel, $strom.ToArray())
    $schreib.Dispose(); $strom.Dispose()

    Write-Host ""
    Write-Host "Fertig: $Ziel ($((Get-Item -LiteralPath $Ziel).Length) Byte, $($bilder.Count) Groessen)" -ForegroundColor Cyan
}
finally {
    Remove-Item -LiteralPath $Arbeit -Recurse -Force -ErrorAction SilentlyContinue
}
