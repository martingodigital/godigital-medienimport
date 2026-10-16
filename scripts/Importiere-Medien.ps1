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

# --- Zaehler fuer Phasenzeiten und Durchsatz ---------------------------------
# Aus dem Betatest: 480 Bilder zu je 8 MB sahen aus, als haenge das Programm. Bis
# zur ersten Zeile vergehen die Sekunden des ExifTool-Durchlaufs, und danach sagt
# nichts, wie weit der Lauf ist. Gemessen (480 Dateien, 3,6 GB): Metadaten 12 s,
# Einsortieren auf demselben Laufwerk unter 1 s, auf ein anderes 11 s.
# [long] ist Pflicht: 3,6 GB sprengen Int32.
[long]$summeBytes      = 0
[long]$erledigtBytes   = 0
$uhrMetadaten          = New-Object System.Diagnostics.Stopwatch
$uhrEinsortieren       = New-Object System.Diagnostics.Stopwatch
$gleichesLaufwerk      = $true

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

# --- Hilfsfunktionen: Zahlen lesbar machen -----------------------------------
function Format-Datenmenge {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return ("{0:N2} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N1} MB" -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ("{0:N0} KB" -f ($Bytes / 1KB)) }
    return ("{0:N0} Bytes" -f $Bytes)
}

function Format-Dauer {
    param([double]$Sekunden)
    if ($Sekunden -ge 60) {
        $m = [math]::Floor($Sekunden / 60)
        return ("{0} min {1:N0} s" -f $m, ($Sekunden - $m * 60))
    }
    return ("{0:N1} s" -f $Sekunden)
}

# --- Hilfsfunktion: liegen zwei Pfade auf demselben Laufwerk? ----------------
# Auf demselben Laufwerk ist Move-Item ein Umbenennen und kostet nichts. Ueber
# eine Laufwerksgrenze kopiert Windows jede Datei und loescht danach die Quelle;
# dann bestimmt die langsamere Platte die Dauer des ganzen Laufs. Im Zweifel
# (nicht aufloesbarer Pfad) wird kein Hinweis ausgegeben.
function Test-GleichesLaufwerk {
    param([string]$A, [string]$B)
    try {
        $wa = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($A))
        $wb = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($B))
        return ($wa -ieq $wb)
    } catch { return $true }
}

# --- Hilfsfunktion: Fortschritt anzeigen -------------------------------------
# Write-Progress geht in den Progress-Stream, nicht nach stdout. Die Vorschau und
# das Auswerten der Ausgabe in der Weboberflaeche bleiben davon unberuehrt - eine
# zusaetzliche Zeile auf stdout wuerde dort als Dateibewegung oder Meldung landen.
# Unter Windows PowerShell 5.1 kostet jeder Aufruf Zeit, deshalb hoechstens alle
# 200 ms zeichnen; die letzte Datei immer.
$script:letzteAnzeige = [System.Diagnostics.Stopwatch]::StartNew()
function Write-Fortschritt {
    param(
        [int]$Nummer,
        [int]$Gesamt,
        [string]$Datei,
        [long]$Bytes = 0,
        [long]$GesamtBytes = 0,
        [switch]$Erzwingen
    )
    if (-not $Erzwingen -and $script:letzteAnzeige.ElapsedMilliseconds -lt 200) { return }
    $script:letzteAnzeige.Restart()
    $anteil = if ($Gesamt -gt 0) { [int](100 * $Nummer / $Gesamt) } else { 0 }
    $menge  = if ($GesamtBytes -gt 0) { " - $(Format-Datenmenge $Bytes) von $(Format-Datenmenge $GesamtBytes)" } else { "" }
    Write-Progress -Activity "Einsortieren" `
                   -Status ("Datei {0} von {1}{2}" -f $Nummer, $Gesamt, $menge) `
                   -CurrentOperation $Datei `
                   -PercentComplete ([math]::Min($anteil, 100))
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
# Zu jedem belegten Zielnamen die Quelldatei, die ihn belegt hat. Ohne diese
# Zuordnung kuendigt die Vorschau fuer zwei gleiche Dateien im selben Lauf einen
# Zaehler an, waehrend der echte Lauf die zweite als Dublette ueberspringt: Beim
# echten Lauf liegt die erste Datei dann schon am Ziel und laesst sich
# vergleichen, in der Vorschau nicht.
$geplanteQuelle    = New-Object 'System.Collections.Generic.Dictionary[string,string]'
$verschoben        = 0
$uebersprungen     = 0
# Nur fuer die Vorschau: Was verschoben wuerde. Im echten Lauf zaehlt
# $verschoben, der erst innerhalb von ShouldProcess hochgeht.
$geplant           = 0
# Dateien, deren Datum aus dem Dateisystem stammt. Wer eine Speicherkarte erst
# auf die Platte kopiert und dann importiert, sortiert sonst einen ganzen
# Schwung unter dem heutigen Datum ein, ohne es zu bemerken.
$ohneAufnahmedatum = 0

if ($Reorganisieren) {
    # ============ MODUS: bestehende Mediathek einsortieren ===================
    $modusText = "Reorganisieren (Schema: $Gruppierung)"

    # Der Ereignis-Zweig bleibt aussen vor. Er leitet seinen Ort nicht aus dem
    # Dateinamen ab, ein Umsortieren wuerde die Ereignisse stillschweigend aufloesen.
    $ereignisPfad = Join-Path $Mediathek $EreignisOrdnerName
    Write-Host "Schritt 1 von 2: Mediathek durchsehen. Bei vielen Dateien dauert das." -ForegroundColor Gray
    $uhrMetadaten.Start()
    $dateien = @(Get-ChildItem -LiteralPath $Mediathek -File -Recurse |
               Where-Object {
                   $_.Name -match $datumsVorsatzMuster -and
                   -not $_.FullName.StartsWith($ereignisPfad, [System.StringComparison]::OrdinalIgnoreCase)
               })
    $uhrMetadaten.Stop()
    foreach ($f in $dateien) { $summeBytes += [long]$f.Length }

    $gesamtZuTun = $dateien.Count
    Write-Host ("Schritt 1 von 2 fertig: {0} {1}, {2}, gelesen in {3}." -f `
                $gesamtZuTun, $(if ($gesamtZuTun -eq 1) { "Datei" } else { "Dateien" }), (Format-Datenmenge $summeBytes), (Format-Dauer $uhrMetadaten.Elapsed.TotalSeconds)) -ForegroundColor Gray
    if ($gesamtZuTun -gt 0) {
        if ($WhatIfPreference) { Write-Host "Schritt 2 von 2: Vorschau erstellen." -ForegroundColor Gray }
        else                   { Write-Host "Schritt 2 von 2: umsortieren." -ForegroundColor Gray }
    }

    $uhrEinsortieren.Start()
    $nummer = 0
    foreach ($f in $dateien) {
        $nummer++
        # Innerhalb der Mediathek bleibt alles auf demselben Laufwerk; hier zaehlt
        # die Anzahl, nicht die Datenmenge.
        if (-not $WhatIfPreference) {
            Write-Fortschritt -Nummer $nummer -Gesamt $gesamtZuTun -Datei $f.Name
        }
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
                $erledigtBytes += [long]$f.Length
            } catch {
                Write-Host "FEHLER '$($f.Name)': $($_.Exception.Message)" -ForegroundColor Red
                $ergebnisse.Add([pscustomobject]@{Status="FEHLER"; Alt=$f.Name; Neu=(Join-Path $unter $f.Name); Grund=$_.Exception.Message})
                $uebersprungen++
            }
        } else {
            $geplant++   # nur die Vorschau, siehe Schlusszeile
        }
    }

    $uhrEinsortieren.Stop()
    if (-not $WhatIfPreference) {
        Write-Fortschritt -Nummer $gesamtZuTun -Gesamt $gesamtZuTun -Datei "" -Erzwingen
        Write-Progress -Activity "Einsortieren" -Completed
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

    # Liegt der Programmordner selbst in der Inbox, gehoeren seine Dateien nicht
    # dazu. Sonst zaehlt und verschiebt der Import die eigene Installation mit -
    # bei abgeschaltetem Endungsfilter samt ExifTool und den eigenen Skripten.
    # Nur diese eine Richtung wird ausgeschlossen: Im Projektordner liegt die
    # Inbox umgekehrt UNTER $Root, dort darf nichts uebergangen werden.
    $programmOrdner = ""
    $wurzel = $Root.TrimEnd('\')
    $inboxOhne = $inboxAbs.TrimEnd('\')
    if ($wurzel -ne $inboxOhne -and
        $wurzel.StartsWith($inboxOhne + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        $programmOrdner = $wurzel + '\'
        Write-Host "Hinweis: Der Programmordner liegt in der Inbox und wird uebergangen." -ForegroundColor Yellow
        Write-Host "         $wurzel" -ForegroundColor Yellow
    }

    # Ein einziger ExifTool-Aufruf fuer die ganze Inbox, auch mit Unterordnern.
    # QuickTimeUTC=1 rechnet Videozeiten von UTC in Ortszeit um, sonst sortieren
    # sich Videos gegenueber Fotos desselben Tages um den Zeitzonenversatz falsch ein.
    $exifArgs = @("-j","-d",$DatumsFormat)
    if ($videoZeitAlsOrtszeit) { $exifArgs += @("-api","QuickTimeUTC=1") }
    # -FileSize# liefert die rohe Bytezahl als JSON-Zahl (ohne das # kaeme "7.7 MB"
    # als Text). Damit steht die Datenmenge des Laufs fest, ohne eine einzige
    # zusaetzliche Dateiabfrage - der eine ExifTool-Aufruf bleibt der einzige.
    $exifArgs += @("-CreateDate","-DateTimeOriginal","-ModifyDate","-FileName","-Directory","-FileSize#")
    # -r immer: ExifTool sieht ohne Rekursion nur die losen Dateien der Inbox, Dateien in
    # Unterordnern blieben sonst bei -OhneUnterordner unbemerkt liegen. Ob ein Unterordner
    # zum Ereignis wird, entscheidet allein $label weiter unten.
    $exifArgs += "-r"
    $exifArgs += $inboxAbs

    # Diese Phase ist der stumme Teil des Laufs: Bei vielen Dateien vergehen hier
    # Sekunden bis Minuten, ohne dass etwas auf dem Bildschirm passiert.
    Write-Host "Schritt 1 von 2: Metadaten lesen. ExifTool geht den Inbox-Ordner durch, das kann dauern." -ForegroundColor Gray
    $uhrMetadaten.Start()
    $rohJson = & $ExifToolPath @exifArgs 2>$null
    $uhrMetadaten.Stop()

    if ([string]::IsNullOrWhiteSpace($rohJson)) {
        Write-Host "Keine Dateien in der Inbox." -ForegroundColor Yellow
    } else {
        try { $eintraege = $rohJson | ConvertFrom-Json }
        catch { Write-Host "JSON-Fehler: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
        if ($eintraege -isnot [array]) { $eintraege = @($eintraege) }

        # --- Vorlauf: was ist ueberhaupt zu tun? ------------------------------
        # Die drei Filter stehen hier und nicht mehr in der Hauptschleife, damit
        # der Fortschritt "Datei 12 von 480" sagen kann statt "12 von 3200":
        # ExifTool meldet auch .txt, .xmp und alles, was die Filter gleich wieder
        # aussortieren. Bedingungen und Reihenfolge sind unveraendert uebernommen -
        # wer hier etwas umstellt, laesst den Lauf andere Dateien verarbeiten.
        $zuTun = New-Object System.Collections.Generic.List[object]
        foreach ($e in $eintraege) {
            $dateiName   = $e.FileName
            $quellOrdner = ($e.Directory -replace '/','\').TrimEnd('\')
            $quelle      = Join-Path $quellOrdner $dateiName

            # --- Eigener Programmordner ---------------------------------------
            # Still uebergehen wie ein Nichttreffer des Endungsfilters: Ein
            # Protokoll mit 500 Zeilen ExifTool nuetzt niemandem.
            if ($programmOrdner -and $quelle.StartsWith($programmOrdner, [System.StringComparison]::OrdinalIgnoreCase)) { continue }

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

            if ($null -ne $e.FileSize) { $summeBytes += [long]$e.FileSize }
            $zuTun.Add($e)
        }

        $gesamtZuTun = $zuTun.Count
        Write-Host ("Schritt 1 von 2 fertig: {0} {1}, {2}, gelesen in {3}." -f `
                    $gesamtZuTun, $(if ($gesamtZuTun -eq 1) { "Datei" } else { "Dateien" }), (Format-Datenmenge $summeBytes), (Format-Dauer $uhrMetadaten.Elapsed.TotalSeconds)) -ForegroundColor Gray

        $gleichesLaufwerk = Test-GleichesLaufwerk -A $Inbox -B $Mediathek
        if ($gesamtZuTun -gt 0 -and -not $gleichesLaufwerk) {
            Write-Host "Hinweis: Inbox und Mediathek liegen auf verschiedenen Laufwerken." -ForegroundColor Yellow
            Write-Host "         Jede Datei wird deshalb kopiert und danach gelöscht. Das dauert so" -ForegroundColor Yellow
            Write-Host "         lange wie dasselbe Kopieren im Explorer. Lägen beide Ordner auf einem" -ForegroundColor Yellow
            Write-Host "         Laufwerk, wäre es nur ein Umbenennen und in Sekunden vorbei." -ForegroundColor Yellow
        }

        if ($gesamtZuTun -gt 0) {
            if ($WhatIfPreference) { Write-Host "Schritt 2 von 2: Vorschau erstellen." -ForegroundColor Gray }
            else                   { Write-Host "Schritt 2 von 2: einsortieren." -ForegroundColor Gray }
        }

        $uhrEinsortieren.Start()
        $nummer = 0
        foreach ($e in $zuTun) {
            $nummer++
            $dateiName   = $e.FileName
            $quellOrdner = ($e.Directory -replace '/','\').TrimEnd('\')
            $quelle      = Join-Path $quellOrdner $dateiName

            # Nur im echten Lauf: Die Vorschau verschiebt nichts, ihre Zeit steckt
            # in Schritt 1 und nicht hier.
            if (-not $WhatIfPreference) {
                Write-Fortschritt -Nummer $nummer -Gesamt $gesamtZuTun -Datei $dateiName -Bytes $erledigtBytes -GesamtBytes $summeBytes
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
                # Womit wird verglichen? Mit der Datei am Ziel, wenn es sie schon
                # gibt - sonst mit der Quelldatei, die diesen Zielnamen in
                # diesem Lauf belegt hat. Der zweite Fall tritt nur in der
                # Vorschau auf, wo noch nichts verschoben wurde; ohne ihn
                # kuendigt die Vorschau einen Zaehler an und der echte Lauf
                # ueberspringt dieselbe Datei als Dublette.
                $vergleichsDatei = $null
                if (Test-Path -LiteralPath $ziel) {
                    $vergleichsDatei = $ziel
                } elseif ($geplanteQuelle.ContainsKey($ziel.ToLowerInvariant())) {
                    $vergleichsDatei = $geplanteQuelle[$ziel.ToLowerInvariant()]
                }
                if ($vergleichsDatei -and (Test-GleicheDatei -A $quelle -B $vergleichsDatei)) {
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
            $geplanteQuelle[$ziel.ToLowerInvariant()] = $quelle
            if ($datumsGrund -eq "Datum aus Dateisystem") { $ohneAufnahmedatum++ }

            # Der Zusatz steht im Text von ShouldProcess und damit auch in der
            # WhatIf-Zeile: Nur so kann die Vorschau - die keine OK-Zeilen
            # kennt - ein geschaetztes Datum von einem echten unterscheiden.
            $vorgang = "Verschieben nach '$ziel'"
            if ($datumsGrund -eq "Datum aus Dateisystem") { $vorgang += " (Datum aus Dateisystem)" }

            if ($PSCmdlet.ShouldProcess($quelle, $vorgang)) {
                try {
                    if (-not (Test-Path -LiteralPath $zielOrdner)) { New-Item -ItemType Directory -Path $zielOrdner -Force | Out-Null }
                    Move-Item -LiteralPath $quelle -Destination $ziel -ErrorAction Stop
                    # Der Grund steht in Klammern dahinter, damit die Weboberflaeche
                    # ihn anzeigen kann: Bisher stand "Datum aus Dateisystem" nur im
                    # Protokoll, und ein geschaetztes Datum sah auf der Seite aus wie
                    # ein echtes. Der Parser im Dienst kennt die Klammer.
                    $okZeile = "OK '$dateiName' -> '$(Join-Path $unter $neuerName)'"
                    if ($grund) { $okZeile += " ($grund)" }
                    Write-Host $okZeile -ForegroundColor Green
                    $ergebnisse.Add([pscustomobject]@{Status="OK"; Alt=$dateiName; Neu=(Join-Path $unter $neuerName); Grund=$grund})
                    $verschoben++
                    if ($null -ne $e.FileSize) { $erledigtBytes += [long]$e.FileSize }
                } catch {
                    Write-Host "FEHLER '$dateiName': $($_.Exception.Message)" -ForegroundColor Red
                    $ergebnisse.Add([pscustomobject]@{Status="FEHLER"; Alt=$dateiName; Neu=(Join-Path $unter $neuerName); Grund=$_.Exception.Message})
                    $uebersprungen++
                }
            } else {
                # Nur die Vorschau kommt hier an: ShouldProcess gibt dann false
                # zurueck. Ohne diesen Zaehler wuesste die Schlusszeile nicht,
                # wie viele Dateien verschoben wuerden.
                $geplant++
            }
        }
        $uhrEinsortieren.Stop()
        if (-not $WhatIfPreference) {
            # Ohne -Completed bleibt das Fortschrittsband nach dem Lauf stehen.
            Write-Fortschritt -Nummer $gesamtZuTun -Gesamt $gesamtZuTun -Datei "" -Bytes $erledigtBytes -GesamtBytes $summeBytes -Erzwingen
            Write-Progress -Activity "Einsortieren" -Completed
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

# Phasenzeiten und Durchsatz. Ohne sie laesst sich eine Rueckmeldung wie "dauert
# ewig" nicht nachrechnen: Es bleibt offen, ob die Zeit im Metadatenlesen steckt
# oder im Kopieren ueber eine Laufwerksgrenze.
$dauerSekunden = ($ende - $start).TotalSeconds
[void]$md.AppendLine("- **Dauer:** $(Format-Dauer $dauerSekunden) (Metadaten $(Format-Dauer $uhrMetadaten.Elapsed.TotalSeconds), Einsortieren $(Format-Dauer $uhrEinsortieren.Elapsed.TotalSeconds))")
if ($erledigtBytes -ge 10MB -and $uhrEinsortieren.Elapsed.TotalSeconds -gt 0) {
    $mbProSekunde = ($erledigtBytes / 1MB) / $uhrEinsortieren.Elapsed.TotalSeconds
    [void]$md.AppendLine("- **Datenmenge:** $(Format-Datenmenge $erledigtBytes), Durchsatz $('{0:N0}' -f $mbProSekunde) MB/s")
}
if (-not $Reorganisieren) {
    if ($gleichesLaufwerk) {
        [void]$md.AppendLine("- **Laufwerke:** Inbox und Mediathek auf demselben Laufwerk, jede Datei wurde umbenannt")
    } else {
        [void]$md.AppendLine("- **Laufwerke:** Inbox und Mediathek auf verschiedenen Laufwerken, jede Datei wurde kopiert")
    }
}
[void]$md.AppendLine("- **Einstellungen:** ``$konfigVerwendet``")
[void]$md.AppendLine("")
[void]$md.AppendLine("## Zusammenfassung")
[void]$md.AppendLine("| Verschoben | Übersprungen | Gesamt |")
[void]$md.AppendLine("|-----------:|-------------:|-------:|")
[void]$md.AppendLine("| $verschoben | $uebersprungen | $($ergebnisse.Count) |")
[void]$md.AppendLine("")
if ($ohneAufnahmedatum -gt 0) {
    $satzDatum = if ($ohneAufnahmedatum -eq 1) { "Eine Datei hatte" } else { "$ohneAufnahmedatum Dateien hatten" }
    [void]$md.AppendLine("$satzDatum kein Aufnahmedatum; verwendet wurde das Änderungsdatum der Datei.")
    [void]$md.AppendLine("")
}
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
if ($WhatIfPreference) {
    # Die Vorschau hat nichts verschoben und kein Protokoll geschrieben. Die
    # frueheren Zeilen "Verschoben: 0" und "Protokoll: ..." stimmten beide
    # nicht - gelesen hat sie trotzdem jeder, der die Vorschau per Doppelklick
    # startet. Die Weboberflaeche wertet die WhatIf-Zeilen aus und ist davon
    # nicht betroffen.
    $wortGeplant = switch ($geplant) {
        0       { "Keine Datei würde verschoben" }
        1       { "1 Datei würde verschoben" }
        default { "$geplant Dateien würden verschoben" }
    }
    $wortRest = switch ($uebersprungen) {
        0       { "keine bliebe liegen" }
        1       { "1 bliebe liegen" }
        default { "$uebersprungen blieben liegen" }
    }
    Write-Host "Vorschau beendet ($modusText). $wortGeplant, $wortRest." -ForegroundColor Cyan
    Write-Host "Es wurde nichts verändert und kein Protokoll geschrieben." -ForegroundColor Cyan
} else {
    Write-Host "Fertig ($modusText). Verschoben: $verschoben, Übersprungen: $uebersprungen" -ForegroundColor Cyan
    Write-Host "Protokoll: $protokollDatei" -ForegroundColor Cyan
}
# Ein Dateidatum ist kein Aufnahmedatum. Wer eine Speicherkarte erst auf die
# Platte kopiert und dann importiert, sortiert sonst einen ganzen Schwung unter
# dem heutigen Tag ein, ohne es zu bemerken.
if ($ohneAufnahmedatum -gt 0) {
    $wortDatum = if ($ohneAufnahmedatum -eq 1) { "Eine Datei hatte" } else { "$ohneAufnahmedatum Dateien hatten" }
    Write-Host "$wortDatum kein Aufnahmedatum; verwendet wurde das Änderungsdatum der Datei." -ForegroundColor Yellow
}
# Diese beiden Zeilen stehen bewusst NACH "Protokoll:": Die Weboberflaeche liest
# die Ausgabe zeilenweise gegen feste Muster, und die bisherige Reihenfolge der
# erkannten Zeilen bleibt damit unangetastet.
Write-Host ("Zeiten: Metadaten {0}, Einsortieren {1}, gesamt {2}" -f `
            (Format-Dauer $uhrMetadaten.Elapsed.TotalSeconds),
            (Format-Dauer $uhrEinsortieren.Elapsed.TotalSeconds),
            (Format-Dauer ($ende - $start).TotalSeconds)) -ForegroundColor Cyan
# Erst ab einer Datenmenge, bei der die Zahl etwas aussagt: Bei drei kleinen
# Dateien misst man die Startzeit von PowerShell, nicht den Durchsatz.
if ($erledigtBytes -ge 10MB -and $uhrEinsortieren.Elapsed.TotalSeconds -gt 0) {
    Write-Host ("Durchsatz: {0} in {1} = {2:N0} MB/s" -f `
                (Format-Datenmenge $erledigtBytes),
                (Format-Dauer $uhrEinsortieren.Elapsed.TotalSeconds),
                (($erledigtBytes / 1MB) / $uhrEinsortieren.Elapsed.TotalSeconds)) -ForegroundColor Cyan
}
