<#
.SYNOPSIS
    GoDigital Medienimport: Fotos und Videos aus der Inbox nach Aufnahmedatum
    umbenennen, in die Mediathek einsortieren und protokollieren.

.DESCRIPTION
    Pro Datei ein Schritt (Move-Item = umbenennen + verschieben). Das Datum wird
    per ExifTool (CreateDate -> DateTimeOriginal -> ModifyDate -> Dateidatum) in
    EINEM Aufruf für die ganze Inbox gelesen.

    Lose Dateien direkt in der Inbox werden nach Datum einsortiert:

        JahrMonat (Standard) : mediathek\2026\2026-09\20260910_101530_IMG_1001.JPG
        Jahr                 : mediathek\2026\20260910_101530_IMG_1001.JPG
        Tag                  : mediathek\2026-09-10\20260910_101530_IMG_1001.JPG
        Keine                : mediathek\20260910_101530_IMG_1001.JPG

    Unterordner der Inbox gelten als Ereignis. Ihr Name wird zum Zielordner:

        inbox\2026-09_Urlaub Italien\IMG_1001.JPG
            -> mediathek\Ereignisse\2026-09_Urlaub Italien\20260910_101530_IMG_1001.JPG

    Bestehende Zieldateien werden nie überschrieben: Ist die Datei identisch,
    bleibt sie als Dublette liegen; ist sie verschieden, bekommt der Zielname
    einen Zähler. Nach jedem echten Lauf entsteht ein Markdown-Protokoll.

    Trägt eine Datei bereits einen Datumsvorsatz aus einem früheren Lauf, gilt
    dieser als Aufnahmedatum und es wird kein zweiter vorangestellt. Nur so
    erkennt der Kollisionsvergleich eine zurückgelegte Datei als Dublette.

    Mit -Reorganisieren werden stattdessen bereits vorhandene Dateien in der
    Mediathek in das aktuelle Gruppierungsschema einsortiert (idempotent).
    Der Ereignis-Zweig bleibt dabei unangetastet.

    Standardwerte kommen aus config\einstellungen.json. Ausdrücklich übergebene
    Parameter haben Vorrang. Fehlt oder fällt die Datei aus, läuft das Skript
    mit den eingebauten Standardwerten weiter.

    Das gilt auch für die Ordner: Inbox, Mediathek und Protokolle dürfen in der
    Einstellungsdatei stehen. Fehlen sie dort, liegen sie wie bisher neben dem
    Skript. Ein relativer Pfad wird gegen den Projektordner aufgelöst.

.PARAMETER Gruppierung        JahrMonat (Standard) | Jahr | Tag | Keine
.PARAMETER Reorganisieren     Vorhandene Mediathek in das Schema einsortieren.
.PARAMETER Inbox              Aus der Einstellungsdatei, sonst <Root>\inbox
.PARAMETER Mediathek          Aus der Einstellungsdatei, sonst <Root>\mediathek
.PARAMETER Protokolle         Aus der Einstellungsdatei, sonst <Root>\protokolle
.PARAMETER ExifToolPath       Standard aus der Einstellungsdatei.
.PARAMETER Praefix            Namensfilter, Standard leer (alle Dateien).
.PARAMETER Erweiterungen      Erlaubte Dateiendungen, Standard aus der Einstellungsdatei.
.PARAMETER AlleDateien        Endungsfilter abschalten.
.PARAMETER Ereignis           Fester Ereignisname, schlägt den Unterordnernamen.
.PARAMETER EreignisOrdnerName Zweig in der Mediathek, Standard "Ereignisse".
.PARAMETER OhneUnterordner    Unterordner der Inbox nicht als Ereignis behandeln.
.PARAMETER EinstellungsDatei  Standard: <Root>\config\einstellungen.json
.PARAMETER DatumsFormat       ExifTool-Datumsformat, Standard "%Y%m%d_%H%M%S".

.EXAMPLE
    .\Importiere-Medien.ps1 -WhatIf
.EXAMPLE
    .\Importiere-Medien.ps1 -Ereignis "2026-09_Urlaub Italien"
.EXAMPLE
    .\Importiere-Medien.ps1 -Praefix "DJI_"
.EXAMPLE
    .\Importiere-Medien.ps1 -Reorganisieren
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('JahrMonat','Jahr','Tag','Keine')]
    [string]$Gruppierung = 'JahrMonat',
    [switch]$Reorganisieren,
    [string]$Inbox,
    [string]$Mediathek,
    [string]$Protokolle,
    [string]$ExifToolPath,
    [string]$Praefix = "",
    [string[]]$Erweiterungen,
    [switch]$AlleDateien,
    [string]$Ereignis = "",
    [string]$EreignisOrdnerName = "Ereignisse",
    [switch]$OhneUnterordner,
    [string]$EinstellungsDatei,
    [string]$DatumsFormat = "%Y%m%d_%H%M%S"
)

# --- Pfade relativ zum Skript ------------------------------------------------
# Nur die Einstellungsdatei steht hier fest. Inbox, Mediathek und Protokolle
# werden erst NACH dem Lesen der Datei gesetzt, weiter unten: sie duerfen auch
# aus der Einstellungsdatei kommen, damit die Weboberflaeche und der
# Doppelklick-Betrieb dieselben Ordner benutzen.
$Root = Split-Path -Parent $PSScriptRoot
if (-not $EinstellungsDatei) { $EinstellungsDatei = Join-Path $Root "config\einstellungen.json" }

$start = Get-Date

# --- Programmversion ---------------------------------------------------------
# Die Nummer steht ausschliesslich in VERSION. Fehlt die Datei - etwa in einem
# unvollstaendig kopierten Ordner -, laeuft der Import weiter und meldet
# "unbekannt"; eine fehlende Versionsdatei ist kein Grund, nichts zu tun.
# Bewusst ueber System.IO: Get-Content meldet unter PowerShell 5.1 bei -WhatIf
# seine Provider-Zugriffe und verrauscht die Vorschau.
function Get-Programmversion {
    param([string]$Pfad)
    if (-not (Test-Path -LiteralPath $Pfad -PathType Leaf)) { return "unbekannt" }
    try {
        $zeile = ([System.IO.File]::ReadAllText($Pfad)).Trim()
        if ($zeile) { return $zeile }
    } catch { }
    return "unbekannt"
}
$Programmversion = Get-Programmversion -Pfad (Join-Path $Root "VERSION")

# --- Eingebaute Standardwerte (greifen ohne Einstellungsdatei) ---------------
$standardErweiterungen = @(
    'jpg','jpeg','heic','heif','png','tif','tiff',
    'dng','raw','cr2','cr3','nef','arw','orf','rw2',
    'mp4','mov','avi','mts','m2ts','m4v','mkv'
)
# Rueckfallkette fuer ExifTool. Parameter und Einstellungsdatei stehen weiter
# davor; hier geht es nur um den Fall, dass beide schweigen.
#   1. exiftool\exiftool.exe neben dem Programm - so liefert das Setup es aus.
#   2. der Suchpfad, falls jemand ExifTool regulaer installiert hat.
#   3. der bisherige feste Pfad, damit der Entwicklungsrechner unveraendert laeuft.
function Get-ExifToolStandard {
    param([string]$ProgrammWurzel)
    $daneben = Join-Path $ProgrammWurzel "exiftool\exiftool.exe"
    if (Test-Path -LiteralPath $daneben -PathType Leaf) { return $daneben }
    $imPfad = Get-Command 'exiftool.exe' -CommandType Application -ErrorAction SilentlyContinue |
              Select-Object -First 1 -ExpandProperty Source
    if ($imPfad) { return $imPfad }
    return "E:\Exiftool\exiftool.exe"
}
$standardExifTool = Get-ExifToolStandard -ProgrammWurzel $Root

# Der Datumsvorsatz, den dieses Skript selbst vergibt: yyyyMMdd_HHmmss_ mit plausiblem
# Monat, Tag und Uhrzeit. Beide Modi pruefen dagegen, deshalb steht das Muster nur hier.
# Die Plausibilitaetspruefung ist Absicht: ein Name wie 12345678_901234_x.jpg soll nicht
# als Datum durchgehen und in einem Ordner 1234\1234-56 landen.
$datumsVorsatzMuster = '^(\d{4}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])_(?:[01]\d|2[0-3])[0-5]\d[0-5]\d)_'

# --- Einstellungsdatei lesen -------------------------------------------------
# Rangfolge: ausdruecklicher Parameter > Einstellungsdatei > eingebauter Standard.
# Eine fehlende oder fehlerhafte Datei darf den Lauf nie stoppen.
function Get-Einstellungen {
    param([string]$Pfad)
    if (-not (Test-Path -LiteralPath $Pfad -PathType Leaf)) { return $null }
    try {
        return (Get-Content -LiteralPath $Pfad -Raw -Encoding UTF8 | ConvertFrom-Json)
    } catch {
        Write-Host "WARNUNG: Einstellungsdatei unlesbar, es gelten die Standardwerte." -ForegroundColor Yellow
        Write-Host "         $Pfad" -ForegroundColor Yellow
        Write-Host "         $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

function Get-Einstellung {
    param($Konfig, [string]$Name, $Standard)
    if ($Konfig -and ($Konfig.PSObject.Properties.Name -contains $Name)) {
        $wert = $Konfig.$Name
        if ($null -ne $wert) { return $wert }
    }
    return $Standard
}

$konfig            = Get-Einstellungen -Pfad $EinstellungsDatei
$konfigVerwendet   = if ($konfig) { $EinstellungsDatei } else { "(keine, Standardwerte)" }

# --- Ordnerpfade: Parameter > Einstellungsdatei > Ordner neben dem Skript -----
# Ein relativer Pfad aus der Datei wird gegen den Projektordner aufgeloest, damit
# "..\Fotos" nicht vom Arbeitsverzeichnis des Aufrufers abhaengt.
function Get-Ordnerpfad {
    param([string]$Name, [string]$Standard)
    $wert = [string](Get-Einstellung $konfig $Name "")
    if (-not $wert) { return (Join-Path $Root $Standard) }
    if ([System.IO.Path]::IsPathRooted($wert)) { return $wert }
    return (Join-Path $Root $wert)
}

if (-not $PSBoundParameters.ContainsKey('Inbox') -or -not $Inbox) {
    $Inbox = Get-Ordnerpfad 'Inbox' 'inbox'
}
if (-not $PSBoundParameters.ContainsKey('Mediathek') -or -not $Mediathek) {
    $Mediathek = Get-Ordnerpfad 'Mediathek' 'mediathek'
}
if (-not $PSBoundParameters.ContainsKey('Protokolle') -or -not $Protokolle) {
    $Protokolle = Get-Ordnerpfad 'Protokolle' 'protokolle'
}

if (-not $PSBoundParameters.ContainsKey('Gruppierung')) {
    # Erst pruefen, dann zuweisen: das ValidateSet der Variablen wirkt auch bei
    # spaeteren Zuweisungen und wuerde sonst eine rohe PowerShell-Fehlermeldung werfen.
    $gruppierungKonfig = [string](Get-Einstellung $konfig 'Gruppierung' $Gruppierung)
    if ($gruppierungKonfig -in @('JahrMonat','Jahr','Tag','Keine')) {
        $Gruppierung = $gruppierungKonfig
    } else {
        Write-Host "WARNUNG: Unbekannte Gruppierung '$gruppierungKonfig' in der Einstellungsdatei, es gilt '$Gruppierung'." -ForegroundColor Yellow
    }
}
if (-not $PSBoundParameters.ContainsKey('Praefix')) {
    $Praefix = [string](Get-Einstellung $konfig 'Praefix' $Praefix)
}
if (-not $PSBoundParameters.ContainsKey('Erweiterungen')) {
    $Erweiterungen = @(Get-Einstellung $konfig 'Erweiterungen' $standardErweiterungen)
}
if (-not $PSBoundParameters.ContainsKey('ExifToolPath')) {
    $ExifToolPath = [string](Get-Einstellung $konfig 'ExifToolPath' $standardExifTool)
    # Ein leerer Wert in der Datei zaehlt wie ein fehlender: die mitgelieferte
    # Vorlage traegt hier nichts ein, und ueber die Seite laesst sich das Feld
    # leeren. Sonst stuende im Fehlertext ein leerer Pfad.
    if (-not $ExifToolPath) { $ExifToolPath = $standardExifTool }
}
if (-not $PSBoundParameters.ContainsKey('EreignisOrdnerName')) {
    $EreignisOrdnerName = [string](Get-Einstellung $konfig 'EreignisOrdnerName' $EreignisOrdnerName)
}
if ($PSBoundParameters.ContainsKey('OhneUnterordner')) {
    $unterordnerAlsEreignisse = -not $OhneUnterordner
} else {
    $unterordnerAlsEreignisse = [bool](Get-Einstellung $konfig 'UnterordnerAlsEreignisse' $true)
}
$videoZeitAlsOrtszeit = [bool](Get-Einstellung $konfig 'VideoZeitAlsOrtszeit' $true)

# --- Sperre: Ereignis und Reorganisieren schliessen sich aus -----------------
# Sonst wuerde ein Lauf die komplette Mediathek in einen einzigen Ordner ziehen.
if ($Reorganisieren -and $Ereignis) {
    Write-Host "FEHLER: -Ereignis ist im Modus -Reorganisieren nicht erlaubt." -ForegroundColor Red
    Write-Host "        -Reorganisieren sortiert die ganze Mediathek um; ein fester" -ForegroundColor Red
    Write-Host "        Ereignisname würde dabei alle Dateien in einen Ordner ziehen." -ForegroundColor Red
    exit 1
}

# --- Hilfsfunktion: Unterordner aus Datums-Praefix (yyyyMMdd_HHmmss) ----------
function Get-Unterordner {
    param([string]$DatumPraefix, [string]$Schema)
    if ($DatumPraefix -notmatch '^(\d{4})(\d{2})(\d{2})') { return "" }
    $jahr = $Matches[1]; $monat = $Matches[2]; $tag = $Matches[3]
    switch ($Schema) {
        'Jahr'      { return $jahr }
        'JahrMonat' { return (Join-Path $jahr "$jahr-$monat") }
        'Tag'       { return "$jahr-$monat-$tag" }
        default     { return "" }   # Keine
    }
}

# --- Hilfsfunktion: Ereignisname aus dem Inbox-Unterordner -------------------
# ExifTool liefert Directory mit Schraegstrichen, daher vorher normalisieren.
# Kein GetRelativePath: das gibt es in PowerShell 5.1 nicht.
function Get-QuellLabel {
    param([string]$DateiOrdner, [string]$InboxWurzel)
    $ordner = ($DateiOrdner -replace '/','\').TrimEnd('\')
    $wurzel = ($InboxWurzel -replace '/','\').TrimEnd('\')
    if ($ordner -ieq $wurzel) { return "" }
    if ($ordner.Length -gt $wurzel.Length -and
        $ordner.Substring(0, $wurzel.Length) -ieq $wurzel) {
        return $ordner.Substring($wurzel.Length).Trim('\')
    }
    return ""
}

# --- Hilfsfunktion: sind zwei Dateien inhaltlich gleich? ---------------------
# Erst die Groesse vergleichen, nur bei Gleichstand hashen - ein SHA256 ueber
# eine grosse Videodatei kostet sonst unnoetig Zeit.
function Test-GleicheDatei {
    param([string]$A, [string]$B)
    # Bewusst ueber .NET statt Get-Item/Get-FileHash: die Cmdlets melden unter
    # Windows PowerShell 5.1 bei -WhatIf ihre Provider-Zugriffe und verrauschen
    # damit die Vorschau. Diese Pruefung liest nur, sie darf nie etwas anzeigen.
    $sha = $null; $stromA = $null; $stromB = $null
    try {
        $fa = New-Object System.IO.FileInfo $A
        $fb = New-Object System.IO.FileInfo $B
        if (-not $fa.Exists -or -not $fb.Exists) { return $false }
        if ($fa.Length -ne $fb.Length) { return $false }

        $sha    = [System.Security.Cryptography.SHA256]::Create()
        $stromA = [System.IO.File]::OpenRead($A)
        $hashA  = $sha.ComputeHash($stromA)
        $stromA.Close(); $stromA = $null
        $stromB = [System.IO.File]::OpenRead($B)
        $hashB  = $sha.ComputeHash($stromB)
        $stromB.Close(); $stromB = $null

        return ([System.BitConverter]::ToString($hashA) -eq [System.BitConverter]::ToString($hashB))
    } catch {
        return $false
    } finally {
        if ($stromA) { $stromA.Dispose() }
        if ($stromB) { $stromB.Dispose() }
        if ($sha)    { $sha.Dispose() }
    }
}

# --- Hilfsfunktion: freien Zielnamen mit Zaehler suchen ----------------------
function Get-FreierZielName {
    param([string]$ZielOrdner, [string]$Name, $Belegt)
    $basis = [System.IO.Path]::GetFileNameWithoutExtension($Name)
    $ext   = [System.IO.Path]::GetExtension($Name)
    for ($i = 1; $i -le 999; $i++) {
        $kandidat = "{0}_{1}{2}" -f $basis, $i, $ext
        $pfad     = Join-Path $ZielOrdner $kandidat
        if (-not (Test-Path -LiteralPath $pfad) -and -not $Belegt.Contains($pfad.ToLowerInvariant())) {
            return $kandidat
        }
    }
    return $null
}

# --- Vorpruefungen -----------------------------------------------------------
if (-not (Test-Path -LiteralPath $Mediathek -PathType Container)) {
    New-Item -ItemType Directory -Path $Mediathek -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $Protokolle -PathType Container)) {
    New-Item -ItemType Directory -Path $Protokolle -Force | Out-Null
}

$ergebnisse    = New-Object System.Collections.Generic.List[object]
$geplanteZiele = New-Object System.Collections.Generic.HashSet[string]
$verschoben    = 0
$uebersprungen = 0

if ($Reorganisieren) {
    # ============ MODUS: bestehende Mediathek einsortieren ===================
    $modusText = "Reorganisieren (Schema: $Gruppierung)"

    # Der Ereignis-Zweig bleibt aussen vor. Er leitet seinen Ort nicht aus dem
    # Dateinamen ab, ein Umsortieren wuerde die Ereignisse stillschweigend aufloesen.
    $ereignisPfad = Join-Path $Mediathek $EreignisOrdnerName
    $dateien = Get-ChildItem -LiteralPath $Mediathek -File -Recurse |
               Where-Object {
                   $_.Name -match $datumsVorsatzMuster -and
                   -not $_.FullName.StartsWith($ereignisPfad, [System.StringComparison]::OrdinalIgnoreCase)
               }

    foreach ($f in $dateien) {
        $unter = Get-Unterordner -DatumPraefix $f.Name -Schema $Gruppierung
        $zielOrdner = if ($unter) { Join-Path $Mediathek $unter } else { $Mediathek }
        $ziel = Join-Path $zielOrdner $f.Name

        if ($f.FullName -ieq $ziel) { continue }  # liegt schon richtig
        if (Test-Path -LiteralPath $ziel) {
            $ergebnisse.Add([pscustomobject]@{Status="SKIP"; Alt=$f.Name; Neu=(Join-Path $unter $f.Name); Grund="Ziel existiert bereits"})
            $uebersprungen++; continue
        }
        if ($PSCmdlet.ShouldProcess($f.FullName, "Einsortieren nach '$ziel'")) {
            try {
                if (-not (Test-Path -LiteralPath $zielOrdner)) { New-Item -ItemType Directory -Path $zielOrdner -Force | Out-Null }
                Move-Item -LiteralPath $f.FullName -Destination $ziel -ErrorAction Stop
                Write-Host "OK '$($f.Name)' -> '$unter'" -ForegroundColor Green
                $ergebnisse.Add([pscustomobject]@{Status="OK"; Alt=$f.Name; Neu=(Join-Path $unter $f.Name); Grund=""})
                $verschoben++
            } catch {
                Write-Host "FEHLER '$($f.Name)': $($_.Exception.Message)" -ForegroundColor Red
                $ergebnisse.Add([pscustomobject]@{Status="FEHLER"; Alt=$f.Name; Neu=(Join-Path $unter $f.Name); Grund=$_.Exception.Message})
                $uebersprungen++
            }
        }
    }

    # leere Unterordner aufraeumen, den Ereignis-Zweig eingeschlossen
    Get-ChildItem -LiteralPath $Mediathek -Directory -Recurse |
        Where-Object { @(Get-ChildItem $_.FullName -Recurse -File).Count -eq 0 } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

} else {
    # ============ MODUS: Inbox verarbeiten ===================================
    $modusText = "Medien importieren (Schema: $Gruppierung)"

    if (-not (Test-Path -LiteralPath $ExifToolPath -PathType Leaf)) {
        Write-Host "ExifTool nicht gefunden: $ExifToolPath" -ForegroundColor Red; exit 1
    }
    if (-not (Test-Path -LiteralPath $Inbox -PathType Container)) {
        Write-Host "Inbox-Ordner existiert nicht: $Inbox" -ForegroundColor Red; exit 1
    }

    $inboxAbs = (Resolve-Path -LiteralPath $Inbox).Path

    # Ein einziger ExifTool-Aufruf fuer die ganze Inbox, auch mit Unterordnern.
    # QuickTimeUTC=1 rechnet Videozeiten von UTC in Ortszeit um, sonst sortieren
    # sich Videos gegenueber Fotos desselben Tages um den Zeitzonenversatz falsch ein.
    $exifArgs = @("-j","-d",$DatumsFormat)
    if ($videoZeitAlsOrtszeit) { $exifArgs += @("-api","QuickTimeUTC=1") }
    $exifArgs += @("-CreateDate","-DateTimeOriginal","-ModifyDate","-FileName","-Directory")
    # -r immer: ExifTool sieht ohne Rekursion nur die losen Dateien der Inbox, Dateien in
    # Unterordnern blieben sonst bei -OhneUnterordner unbemerkt liegen. Ob ein Unterordner
    # zum Ereignis wird, entscheidet allein $label weiter unten.
    $exifArgs += "-r"
    $exifArgs += $inboxAbs

    $rohJson = & $ExifToolPath @exifArgs 2>$null

    if ([string]::IsNullOrWhiteSpace($rohJson)) {
        Write-Host "Keine Dateien in der Inbox." -ForegroundColor Yellow
    } else {
        try { $eintraege = $rohJson | ConvertFrom-Json }
        catch { Write-Host "JSON-Fehler: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
        if ($eintraege -isnot [array]) { $eintraege = @($eintraege) }

        foreach ($e in $eintraege) {
            $dateiName  = $e.FileName
            $quellOrdner = ($e.Directory -replace '/','\').TrimEnd('\')
            $quelle      = Join-Path $quellOrdner $dateiName

            # --- Namensfilter (leerer Praefix = alle Dateien) ----------------
            if ($Praefix -and ($dateiName -notmatch ("^" + [regex]::Escape($Praefix)))) { continue }

            # --- Endungsfilter -----------------------------------------------
            # Nichttreffer werden still uebergangen. Ohne Namensfilter wuerde das
            # Protokoll sonst mit Thumbs.db, desktop.ini und Beidateien volllaufen.
            if (-not $AlleDateien -and $Erweiterungen -and $Erweiterungen.Count -gt 0) {
                $ext = [System.IO.Path]::GetExtension($dateiName).TrimStart('.')
                $treffer = $Erweiterungen | Where-Object { $_.ToString().TrimStart('.') -ieq $ext }
                if (-not $treffer) { continue }
            }

            # --- Ereignisname -------------------------------------------------
            $label = ""
            if ($Ereignis) {
                $label = $Ereignis
            } elseif ($unterordnerAlsEreignisse) {
                $label = Get-QuellLabel -DateiOrdner $quellOrdner -InboxWurzel $inboxAbs
            }

            # --- Aufnahmedatum -------------------------------------------------
            $datumsGrund  = ""
            $schonBenannt = $false

            if ($dateiName -match $datumsVorsatzMuster) {
                # Die Datei war schon einmal hier. Ein zweiter Vorsatz wuerde ihr einen
                # neuen Zielnamen geben, die Kollisionspruefung liefe nie an, und die
                # Mediathek haette dieselbe Aufnahme ein zweites Mal.
                $datum        = $Matches[1]
                $schonBenannt = $true
                $datumsGrund  = "Datum aus Dateiname"
            } else {
                $datum = @($e.CreateDate, $e.DateTimeOriginal, $e.ModifyDate) |
                         Where-Object { $_ -and $_ -ne "-" } | Select-Object -First 1

                if (-not $datum) {
                    # Screenshots, Messenger-Bilder und viele Downloads haben kein EXIF.
                    # Das .NET-Format muss zu -DatumsFormat passen: %Y%m%d_%H%M%S.
                    try {
                        $info = New-Object System.IO.FileInfo $quelle
                        if (-not $info.Exists) { throw "Datei nicht gefunden" }
                        $datum = $info.LastWriteTime.ToString("yyyyMMdd_HHmmss")
                        $datumsGrund = "Datum aus Dateisystem"
                    } catch {
                        $datum = $null
                    }
                }
            }

            if (-not $datum) {
                Write-Host "SKIP '$dateiName' - kein Datum ermittelbar" -ForegroundColor Yellow
                $ergebnisse.Add([pscustomobject]@{Status="SKIP"; Alt=$dateiName; Neu="-"; Grund="kein Datum ermittelbar"})
                $uebersprungen++; continue
            }

            # --- Ziel bestimmen ------------------------------------------------
            $neuerName = if ($schonBenannt) { $dateiName } else { "${datum}_$dateiName" }
            if ($label) {
                $unter = Join-Path $EreignisOrdnerName $label
            } else {
                $unter = Get-Unterordner -DatumPraefix $datum -Schema $Gruppierung
            }
            $zielOrdner = if ($unter) { Join-Path $Mediathek $unter } else { $Mediathek }
            $ziel       = Join-Path $zielOrdner $neuerName
            $grund      = $datumsGrund

            # --- Kollision: Dublette oder Namensgleichheit? ---------------------
            if ((Test-Path -LiteralPath $ziel) -or $geplanteZiele.Contains($ziel.ToLowerInvariant())) {
                if ((Test-Path -LiteralPath $ziel) -and (Test-GleicheDatei -A $quelle -B $ziel)) {
                    Write-Host "SKIP '$dateiName' - Dublette, identische Datei vorhanden" -ForegroundColor Yellow
                    $ergebnisse.Add([pscustomobject]@{Status="SKIP"; Alt=$dateiName; Neu=(Join-Path $unter $neuerName); Grund="Dublette, identische Datei vorhanden"})
                    $uebersprungen++; continue
                }
                $freier = Get-FreierZielName -ZielOrdner $zielOrdner -Name $neuerName -Belegt $geplanteZiele
                if (-not $freier) {
                    Write-Host "FEHLER '$dateiName': kein freier Zielname gefunden" -ForegroundColor Red
                    $ergebnisse.Add([pscustomobject]@{Status="FEHLER"; Alt=$dateiName; Neu=(Join-Path $unter $neuerName); Grund="kein freier Zielname gefunden"})
                    $uebersprungen++; continue
                }
                $neuerName = $freier
                $ziel      = Join-Path $zielOrdner $neuerName
                $hinweis   = "Namenskonflikt, Zähler angehängt"
                $grund     = if ($grund) { "$grund; $hinweis" } else { $hinweis }
            }

            [void]$geplanteZiele.Add($ziel.ToLowerInvariant())

            if ($PSCmdlet.ShouldProcess($quelle, "Verschieben nach '$ziel'")) {
                try {
                    if (-not (Test-Path -LiteralPath $zielOrdner)) { New-Item -ItemType Directory -Path $zielOrdner -Force | Out-Null }
                    Move-Item -LiteralPath $quelle -Destination $ziel -ErrorAction Stop
                    Write-Host "OK '$dateiName' -> '$(Join-Path $unter $neuerName)'" -ForegroundColor Green
                    $ergebnisse.Add([pscustomobject]@{Status="OK"; Alt=$dateiName; Neu=(Join-Path $unter $neuerName); Grund=$grund})
                    $verschoben++
                } catch {
                    Write-Host "FEHLER '$dateiName': $($_.Exception.Message)" -ForegroundColor Red
                    $ergebnisse.Add([pscustomobject]@{Status="FEHLER"; Alt=$dateiName; Neu=(Join-Path $unter $neuerName); Grund=$_.Exception.Message})
                    $uebersprungen++
                }
            }
        }
    }
}

# --- Protokoll schreiben -----------------------------------------------------
# Bei -WhatIf wirkt $WhatIfPreference automatisch auf Set-Content, es entsteht
# also bewusst kein Protokoll.
$ende = Get-Date
$stempel = $start.ToString("yyyyMMdd_HHmmss")
$modusSuffix = if ($WhatIfPreference) { " (VORSCHAU / -WhatIf, nichts geändert)" } else { "" }

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# Protokoll - $modusText$modusSuffix")
[void]$md.AppendLine("")
[void]$md.AppendLine("- **Start:** $($start.ToString('yyyy-MM-dd HH:mm:ss'))")
[void]$md.AppendLine("- **Ende:**  $($ende.ToString('yyyy-MM-dd HH:mm:ss'))")
[void]$md.AppendLine("- **Programmversion:** $Programmversion")
[void]$md.AppendLine("- **ExifTool:** ``$ExifToolPath``")
[void]$md.AppendLine("- **Mediathek:** ``$Mediathek``")
if (-not $Reorganisieren) {
    $textNamensfilter = if ($Praefix) { '`' + $Praefix + '`' } else { 'keiner (alle Dateien)' }
    $textEndungen     = if ($AlleDateien -or -not $Erweiterungen -or $Erweiterungen.Count -eq 0) { 'keiner' } else { ($Erweiterungen -join ', ') }
    $textUnterordner  = if ($unterordnerAlsEreignisse) { 'ja' } else { 'nein' }
    $textVideoZeit    = if ($videoZeitAlsOrtszeit) { 'ja' } else { 'nein' }

    [void]$md.AppendLine("- **Inbox:** ``$Inbox``")
    [void]$md.AppendLine("- **Namensfilter:** $textNamensfilter")
    [void]$md.AppendLine("- **Endungsfilter:** $textEndungen")
    [void]$md.AppendLine("- **Unterordner als Ereignis:** $textUnterordner")
    if ($Ereignis) { [void]$md.AppendLine("- **Fester Ereignisname:** $Ereignis") }
    [void]$md.AppendLine("- **Videozeit in Ortszeit:** $textVideoZeit")
}
[void]$md.AppendLine("- **Gruppierung:** $Gruppierung")
[void]$md.AppendLine("- **Einstellungen:** ``$konfigVerwendet``")
[void]$md.AppendLine("")
[void]$md.AppendLine("## Zusammenfassung")
[void]$md.AppendLine("| Verschoben | Übersprungen | Gesamt |")
[void]$md.AppendLine("|-----------:|-------------:|-------:|")
[void]$md.AppendLine("| $verschoben | $uebersprungen | $($ergebnisse.Count) |")
[void]$md.AppendLine("")
if ($ergebnisse.Count -gt 0) {
    [void]$md.AppendLine("## Details")
    [void]$md.AppendLine("| Status | Datei (alt) | Ziel (relativ zur Mediathek) | Grund |")
    [void]$md.AppendLine("|--------|-------------|------------------------------|-------|")
    foreach ($r in $ergebnisse) {
        [void]$md.AppendLine("| $($r.Status) | $($r.Alt) | $($r.Neu) | $($r.Grund) |")
    }
} else {
    [void]$md.AppendLine("_Keine passenden Dateien verarbeitet._")
}

$protokollDatei = Join-Path $Protokolle "protokoll_$stempel.md"
$md.ToString() | Set-Content -LiteralPath $protokollDatei -Encoding UTF8

# --- Zusammenfassung ---------------------------------------------------------
Write-Host ""
Write-Host "Fertig ($modusText). Verschoben: $verschoben, Übersprungen: $uebersprungen" -ForegroundColor Cyan
Write-Host "Protokoll: $protokollDatei" -ForegroundColor Cyan
