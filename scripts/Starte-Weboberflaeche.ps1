<#
.SYNOPSIS
    GoDigital Medienimport: lokale Weboberflaeche zur Bedienung von
    Importiere-Medien.ps1.

.DESCRIPTION
    Startet einen kleinen HTTP-Dienst auf 127.0.0.1 und oeffnet die Seite im
    Browser. Die Seite liest und schreibt config\einstellungen.json und ruft
    das Importskript auf: mit -WhatIf fuer die Vorschau, ohne fuer den echten
    Lauf.

    Das Importskript wird nicht veraendert und bleibt eigenstaendig per
    Doppelklick lauffaehig. Der Dienst ruft es als EIGENEN Prozess auf. Das ist
    Pflicht: das Skript beendet sich bei fehlendem ExifTool mit "exit 1", und im
    selben Prozess wuerde das den Dienst mit beenden.

    Die Ordner (Inbox, Mediathek, Protokolle) stehen in der Einstellungsdatei
    und lassen sich ueber die Seite aendern. Wer diesem Skript beim Start
    -Inbox, -Mediathek oder -Protokolle mitgibt, uebersteuert die Datei fuer
    diese Sitzung; die Seite zeigt das an und sperrt das jeweilige Feld.

    Zugriffsschutz: Der Dienst bindet ausschliesslich an 127.0.0.1 und verlangt
    ein bei jedem Start neu erzeugtes Token. Ohne diese Pruefung koennte eine
    beliebige Webseite im Browser einen Import ausloesen, denn ein Formular-POST
    an localhost ist ihr nicht verboten.

.PARAMETER Port
    Startport, Standard 8787. Ist er belegt, sucht der Dienst aufwaerts weiter.
.PARAMETER Inbox
    Uebersteuert die Einstellungsdatei fuer diese Sitzung.
.PARAMETER Mediathek
    Uebersteuert die Einstellungsdatei fuer diese Sitzung.
.PARAMETER Protokolle
    Uebersteuert die Einstellungsdatei fuer diese Sitzung.
.PARAMETER EinstellungsDatei
    Standard: <Root>\config\einstellungen.json
.PARAMETER OhneBrowser
    Seite nicht automatisch oeffnen, nur die Adresse ausgeben.

.EXAMPLE
    .\Starte-Weboberflaeche.ps1
.EXAMPLE
    .\Starte-Weboberflaeche.ps1 -Port 9000 -OhneBrowser
#>
[CmdletBinding()]
param(
    [int]$Port = 8787,
    [string]$Inbox,
    [string]$Mediathek,
    [string]$Protokolle,
    [string]$EinstellungsDatei,
    [switch]$OhneBrowser
)

$ErrorActionPreference = 'Stop'

# --- Pfade -------------------------------------------------------------------
# Nur die Einstellungsdatei steht fest. Die drei Ordner kommen bei jeder Anfrage
# frisch aus der Datei, damit eine Aenderung ueber die Seite sofort greift.
$Root = Split-Path -Parent $PSScriptRoot
if (-not $EinstellungsDatei) { $EinstellungsDatei = Join-Path $Root "config\einstellungen.json" }

$ImportSkript = Join-Path $PSScriptRoot "Importiere-Medien.ps1"
$SeitenDatei  = Join-Path $Root "web\index.html"

if (-not (Test-Path -LiteralPath $ImportSkript -PathType Leaf)) {
    Write-Host "Importskript nicht gefunden: $ImportSkript" -ForegroundColor Red; exit 1
}
if (-not (Test-Path -LiteralPath $SeitenDatei -PathType Leaf)) {
    Write-Host "Seite nicht gefunden: $SeitenDatei" -ForegroundColor Red; exit 1
}

# Beim Start ausdruecklich gesetzte Ordner gelten nur fuer diese Sitzung. So
# laesst sich der Dienst gegen Testordner starten, ohne die Datei anzufassen.
$PfadUeberschreibung = @{}
foreach ($n in @('Inbox','Mediathek','Protokolle')) {
    if ($PSBoundParameters.ContainsKey($n) -and $PSBoundParameters[$n]) {
        $PfadUeberschreibung[$n] = [string]$PSBoundParameters[$n]
    }
}

# Dieselbe eingebaute Liste wie im Importskript. Sie dient hier nur dazu, der
# Oberflaeche die abwaehlbaren Typen anzubieten.
$standardErweiterungen = @(
    'jpg','jpeg','heic','heif','png','tif','tiff',
    'dng','raw','cr2','cr3','nef','arw','orf','rw2',
    'mp4','mov','avi','mts','m2ts','m4v','mkv'
)

# Rueckfallkette fuer ExifTool, wortgleich mit dem Importskript. Bewusst kopiert:
# die beiden Skripte bleiben voneinander unabhaengig, so wie $standardErweiterungen
# ebenfalls zweimal steht. Wer sie aendert, aendert beide.
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

$Token = [guid]::NewGuid().ToString('N')

# --- Antworten ---------------------------------------------------------------
function Write-JsonAntwort {
    param($Antwort, $Objekt, [int]$Status = 200)
    $json  = $Objekt | ConvertTo-Json -Depth 4 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $Antwort.StatusCode      = $Status
    $Antwort.ContentType     = "application/json; charset=utf-8"
    $Antwort.ContentLength64 = $bytes.Length
    $Antwort.OutputStream.Write($bytes, 0, $bytes.Length)
}

function Write-TextAntwort {
    param($Antwort, [string]$Text, [string]$Typ = "text/html; charset=utf-8", [int]$Status = 200)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $Antwort.StatusCode      = $Status
    $Antwort.ContentType     = $Typ
    $Antwort.ContentLength64 = $bytes.Length
    $Antwort.OutputStream.Write($bytes, 0, $bytes.Length)
}

# --- Einstellungsdatei lesen -------------------------------------------------
function Get-KonfigRoh {
    if (-not (Test-Path -LiteralPath $EinstellungsDatei -PathType Leaf)) {
        return [pscustomobject]@{ Konfig = $null; Warnung = "Keine Einstellungsdatei vorhanden, es gelten die eingebauten Standardwerte." }
    }
    try {
        # System.IO statt Get-Content: das Cmdlet haengt jedem String seine
        # Provider-Eigenschaften an, und ConvertTo-Json verlaeuft sich darin.
        return [pscustomobject]@{ Konfig = ([System.IO.File]::ReadAllText($EinstellungsDatei) | ConvertFrom-Json); Warnung = "" }
    } catch {
        return [pscustomobject]@{ Konfig = $null; Warnung = "Einstellungsdatei unlesbar, es gelten die Standardwerte: $($_.Exception.Message)" }
    }
}

# --- Ordner: Sitzungsvorgabe > Einstellungsdatei > neben dem Skript ----------
function Get-Ordner {
    param([string]$Name, [string]$Standard, $Konfig)
    if ($PfadUeberschreibung.ContainsKey($Name)) { return $PfadUeberschreibung[$Name] }
    $wert = ""
    if ($Konfig -and ($Konfig.PSObject.Properties.Name -contains $Name)) {
        $w = $Konfig.$Name
        if ($null -ne $w) { $wert = ([string]$w).Trim() }
    }
    if (-not $wert) { return (Join-Path $Root $Standard) }
    if ([System.IO.Path]::IsPathRooted($wert)) { return $wert }
    return (Join-Path $Root $wert)
}

function Get-AktuellePfade {
    param($Konfig)
    return [pscustomobject]@{
        Inbox      = Get-Ordner 'Inbox'      'inbox'      $Konfig
        Mediathek  = Get-Ordner 'Mediathek'  'mediathek'  $Konfig
        Protokolle = Get-Ordner 'Protokolle' 'protokolle' $Konfig
    }
}

# --- Importskript als eigener Prozess ----------------------------------------
function Invoke-Importskript {
    param([object[]]$Argumente)

    # Parametername und Wert MUESSEN getrennt behandelt werden: ein Name in
    # Anfuehrungszeichen ist fuer PowerShell kein Parameter, sondern ein Wert.
    # '-Inbox' landete so als Wert im ersten Positionsparameter -Gruppierung und
    # das Skript brach am ValidateSet ab (geprueft).
    $teile = @()
    foreach ($a in $Argumente) {
        $teile += $a.Name
        if (-not $a.IstSchalter) {
            $teile += "'" + ([string]$a.Wert -replace "'", "''") + "'"
        }
    }
    $argText = if ($teile.Count -gt 0) { " " + ($teile -join " ") } else { "" }
    $skriptEsc = $ImportSkript -replace "'", "''"
    $inner = "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; & '$skriptEsc'$argText"

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName               = "powershell.exe"
    $psi.Arguments              = "-NoProfile -ExecutionPolicy Bypass -Command `"$inner`""
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    $psi.WorkingDirectory       = $Root

    $p = [System.Diagnostics.Process]::Start($psi)
    # stderr MUSS nebenher gelesen werden. Liest man erst stdout zu Ende und
    # danach stderr, blockiert der Kindprozess, sobald sein stderr-Puffer voll
    # ist, und ReadToEnd kehrt nie zurueck.
    $errAufgabe = $p.StandardError.ReadToEndAsync()
    $aus = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    $err  = $errAufgabe.Result
    $code = $p.ExitCode
    $p.Dispose()

    return [pscustomobject]@{ Code = $code; Ausgabe = $aus; Fehler = $err }
}

# --- Ausgabe des Importskripts auswerten -------------------------------------
# Die WhatIf-Zeilen sind lokalisiert und lauten unter PowerShell 5.1 anders als
# unter 7 (Wortstellung und Anfuehrungszeichen). Deshalb wird NICHT der Satzbau
# geparst, sondern:
#   - die Zeile muss den Text aus unserem eigenen ShouldProcess-Aufruf tragen
#     ("Verschieben nach" bzw. "Einsortieren nach"),
#   - aus ihr werden die Windows-Pfade gezogen: erster = Ziel, zweiter = Quelle.
# Die WhatIf-Zeile des unterdrueckten Set-Content faellt damit von selbst weg.
function Read-SkriptAusgabe {
    param([string]$Ausgabe, [string]$MediathekPfad)

    $aktionen  = New-Object System.Collections.Generic.List[object]
    $meldungen = New-Object System.Collections.Generic.List[object]
    $protokoll = ""
    $verschoben = $null
    $uebersprungen = $null

    $pfadMuster = '[A-Za-z]:\\[^''"\u201E\u201C\u201D]+'

    foreach ($zeile in ($Ausgabe -split "`r?`n")) {
        $z = $zeile.Trim()
        if (-not $z) { continue }

        if ($z -match 'Verschieben nach|Einsortieren nach') {
            $treffer = [regex]::Matches($z, $pfadMuster)
            if ($treffer.Count -ge 2) {
                $ziel   = $treffer[0].Value.TrimEnd('.', ' ')
                $quelle = $treffer[1].Value.TrimEnd('.', ' ')
                $relativ = $ziel
                if ($MediathekPfad -and $ziel.StartsWith($MediathekPfad, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $relativ = $ziel.Substring($MediathekPfad.Length).TrimStart('\')
                }
                $aktionen.Add([pscustomobject]@{
                    quelleName = [System.IO.Path]::GetFileName($quelle)
                    zielOrdner = [System.IO.Path]::GetDirectoryName($relativ)
                    zielName   = [System.IO.Path]::GetFileName($ziel)
                })
            }
            continue
        }

        if ($z -match '^SKIP\s+''(.+?)''\s*-\s*(.+)$') {
            $meldungen.Add([pscustomobject]@{ status = "SKIP"; datei = $Matches[1]; grund = $Matches[2] })
            continue
        }
        if ($z -match '^FEHLER\s+''(.+?)''\s*:\s*(.+)$') {
            $meldungen.Add([pscustomobject]@{ status = "FEHLER"; datei = $Matches[1]; grund = $Matches[2] })
            continue
        }
        if ($z -match '^OK\s+''(.+?)''\s*->\s*''(.+?)''\s*$') {
            $meldungen.Add([pscustomobject]@{ status = "OK"; datei = $Matches[1]; grund = $Matches[2] })
            continue
        }
        if ($z -match '^Protokoll:\s*(.+)$') { $protokoll = $Matches[1].Trim(); continue }
        if ($z -match 'Verschoben:\s*(\d+),\s*\S+:\s*(\d+)') {
            $verschoben    = [int]$Matches[1]
            $uebersprungen = [int]$Matches[2]
            continue
        }
        if ($z -match '^(ExifTool nicht gefunden|Inbox-Ordner existiert nicht|JSON-Fehler|FEHLER:)') {
            $meldungen.Add([pscustomobject]@{ status = "ABBRUCH"; datei = ""; grund = $z })
            continue
        }
        if ($z -match '^(WARNUNG|Keine Dateien)') {
            $meldungen.Add([pscustomobject]@{ status = "HINWEIS"; datei = ""; grund = $z })
            continue
        }
    }

    return [pscustomobject]@{
        aktionen      = $aktionen
        meldungen     = $meldungen
        protokoll     = $protokoll
        verschoben    = $verschoben
        uebersprungen = $uebersprungen
    }
}

# --- Einstellungen fuer die Seite --------------------------------------------
function Get-EinstellungenObjekt {
    $roh   = Get-KonfigRoh
    $k     = $roh.Konfig
    $pfade = Get-AktuellePfade -Konfig $k

    $werte = [ordered]@{
        Inbox                    = $pfade.Inbox
        Mediathek                = $pfade.Mediathek
        Protokolle               = $pfade.Protokolle
        Gruppierung              = "JahrMonat"
        Praefix                  = ""
        Erweiterungen            = $standardErweiterungen
        UnterordnerAlsEreignisse = $true
        EreignisOrdnerName       = "Ereignisse"
        ExifToolPath             = $standardExifTool
        VideoZeitAlsOrtszeit     = $true
    }
    if ($k) {
        foreach ($name in @('Gruppierung','Praefix','Erweiterungen','UnterordnerAlsEreignisse','EreignisOrdnerName','ExifToolPath','VideoZeitAlsOrtszeit')) {
            if ($k.PSObject.Properties.Name -contains $name) {
                $wert = $k.$name
                if ($null -ne $wert) { $werte[$name] = $wert }
            }
        }
    }
    # Ein leerer ExifTool-Pfad steht so in der mitgelieferten Vorlage. Er darf den
    # Standard nicht verdraengen, sonst zeigt die Seite ein leeres Feld an und der
    # Nutzer muesste einen Pfad eintragen, den das Setup laengst eingerichtet hat.
    if (-not [string]$werte['ExifToolPath']) { $werte['ExifToolPath'] = $standardExifTool }
    return [pscustomobject]@{
        werte       = $werte
        warnung     = $roh.Warnung
        datei       = $EinstellungsDatei
        alleTypen   = $standardErweiterungen
        festeOrdner = @($PfadUeberschreibung.Keys)
    }
}

function Set-EinstellungenObjekt {
    param($Eingang)

    $erlaubteGruppierung = @('JahrMonat','Jahr','Tag','Keine')
    $gruppierung = [string]$Eingang.Gruppierung
    if ($erlaubteGruppierung -notcontains $gruppierung) {
        throw "Unbekannte Gruppierung '$gruppierung'."
    }

    $typen = @()
    if ($Eingang.Erweiterungen) {
        $typen = @($Eingang.Erweiterungen | ForEach-Object { ([string]$_).TrimStart('.').Trim() } | Where-Object { $_ })
    }
    if ($typen.Count -eq 0) {
        # Ein leeres Array schaltet den Endungsfilter im Importskript AB, statt
        # gar nichts zu importieren. Wer alle Haken entfernt, meint das Gegenteil.
        throw "Es muss mindestens ein Dateityp ausgewählt sein. Eine leere Liste würde den Endungsfilter abschalten und auch Textdateien in die Mediathek ziehen."
    }

    $exif = ([string]$Eingang.ExifToolPath).Trim()
    if (-not $exif) { throw "Der Pfad zu ExifTool darf nicht leer sein." }

    # Ordner pruefen. Die Inbox muss es geben; Mediathek und Protokolle legt das
    # Importskript bei Bedarf selbst an, ihr Elternordner muss aber existieren.
    $inbox      = ([string]$Eingang.Inbox).Trim()
    $mediathek  = ([string]$Eingang.Mediathek).Trim()
    $protokolle = ([string]$Eingang.Protokolle).Trim()
    if (-not $inbox -or -not $mediathek -or -not $protokolle) {
        throw "Inbox, Mediathek und Protokolle müssen angegeben sein."
    }
    if (-not (Test-Path -LiteralPath $inbox -PathType Container)) {
        throw "Den Inbox-Ordner gibt es nicht: $inbox"
    }
    foreach ($paar in @(@('die Mediathek',$mediathek), @('die Protokolle',$protokolle))) {
        if (-not (Test-Path -LiteralPath $paar[1] -PathType Container)) {
            $eltern = Split-Path -Parent $paar[1]
            if (-not $eltern -or -not (Test-Path -LiteralPath $eltern -PathType Container)) {
                throw "Für $($paar[0]) gibt es den übergeordneten Ordner nicht: $($paar[1])"
            }
        }
    }
    if ($inbox -ieq $mediathek) {
        throw "Inbox und Mediathek dürfen nicht derselbe Ordner sein."
    }

    $neu = [ordered]@{
        Inbox                    = $inbox
        Mediathek                = $mediathek
        Protokolle               = $protokolle
        Gruppierung              = $gruppierung
        Praefix                  = [string]$Eingang.Praefix
        Erweiterungen            = $typen
        UnterordnerAlsEreignisse = [bool]$Eingang.UnterordnerAlsEreignisse
        EreignisOrdnerName       = ([string]$Eingang.EreignisOrdnerName).Trim()
        ExifToolPath             = $exif
        VideoZeitAlsOrtszeit     = [bool]$Eingang.VideoZeitAlsOrtszeit
    }
    if (-not $neu.EreignisOrdnerName) { $neu.EreignisOrdnerName = "Ereignisse" }

    # ConvertTo-Json maskiert unter PowerShell 5.1 Umlaute als \uXXXX. Gueltiges
    # JSON, aber die Datei soll von Hand lesbar bleiben, deshalb zurueckwandeln.
    $json = $neu | ConvertTo-Json -Depth 5
    $json = [regex]::Replace($json, '\\u([0-9a-fA-F]{4})', {
        param($m) [char][int]("0x" + $m.Groups[1].Value)
    })

    $ordner = Split-Path -Parent $EinstellungsDatei
    if (-not (Test-Path -LiteralPath $ordner -PathType Container)) {
        New-Item -ItemType Directory -Path $ordner -Force | Out-Null
    }
    # Kein Git im Ordner: vor dem Ueberschreiben eine Sicherung ablegen.
    if (Test-Path -LiteralPath $EinstellungsDatei -PathType Leaf) {
        Copy-Item -LiteralPath $EinstellungsDatei -Destination "$EinstellungsDatei.bak" -Force
    }
    [System.IO.File]::WriteAllText($EinstellungsDatei, $json, (New-Object System.Text.UTF8Encoding $false))
    return $neu
}

# --- Lage in Inbox und Mediathek ---------------------------------------------
function Get-Lage {
    $roh   = Get-KonfigRoh
    $pfade = Get-AktuellePfade -Konfig $roh.Konfig
    $exif  = $standardExifTool
    if ($roh.Konfig -and ($roh.Konfig.PSObject.Properties.Name -contains 'ExifToolPath') -and $roh.Konfig.ExifToolPath) {
        $exif = [string]$roh.Konfig.ExifToolPath
    }

    $inboxDateien = 0
    $inboxOrdner  = @()
    $inboxDa = Test-Path -LiteralPath $pfade.Inbox -PathType Container
    if ($inboxDa) {
        $inboxDateien = @(Get-ChildItem -LiteralPath $pfade.Inbox -File -Recurse -ErrorAction SilentlyContinue).Count
        $inboxOrdner  = @(Get-ChildItem -LiteralPath $pfade.Inbox -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
    }
    $mediathekDateien = 0
    $mediathekDa = Test-Path -LiteralPath $pfade.Mediathek -PathType Container
    if ($mediathekDa) {
        $mediathekDateien = @(Get-ChildItem -LiteralPath $pfade.Mediathek -File -Recurse -ErrorAction SilentlyContinue).Count
    }

    return [pscustomobject]@{
        inbox              = $pfade.Inbox
        inboxVorhanden     = $inboxDa
        inboxDateien       = $inboxDateien
        inboxOrdner        = $inboxOrdner
        mediathek          = $pfade.Mediathek
        mediathekVorhanden = $mediathekDa
        mediathekDateien   = $mediathekDateien
        protokolle         = $pfade.Protokolle
        exifTool           = $exif
        exifToolVorhanden  = (Test-Path -LiteralPath $exif -PathType Leaf)
        festeOrdner        = @($PfadUeberschreibung.Keys)
    }
}

# --- Argumente fuer einen Lauf -----------------------------------------------
function New-Arg {
    param([string]$Name, $Wert)
    return [pscustomobject]@{
        Name        = $Name
        Wert        = $Wert
        IstSchalter = ($PSBoundParameters.Count -lt 2)
    }
}

function Get-LaufArgumente {
    param($Anfrage, $Pfade, [switch]$Vorschau)

    # Die drei Ordner und die Einstellungsdatei gehen IMMER mit, mit genau den
    # Werten, die die Seite auch anzeigt. Fehlt einer, faellt das Importskript
    # still auf seine eigenen Standardordner zurueck - und das waeren dann
    # womoeglich andere als die hier gemeinten.
    $a = @(
        (New-Arg "-Inbox"             $Pfade.Inbox),
        (New-Arg "-Mediathek"         $Pfade.Mediathek),
        (New-Arg "-Protokolle"        $Pfade.Protokolle),
        (New-Arg "-EinstellungsDatei" $EinstellungsDatei)
    )

    if ($Anfrage.reorganisieren) {
        $a += (New-Arg "-Reorganisieren")
    } else {
        if ($Anfrage.ereignis)        { $a += (New-Arg "-Ereignis" ([string]$Anfrage.ereignis)) }
        if ($Anfrage.praefix)         { $a += (New-Arg "-Praefix"  ([string]$Anfrage.praefix)) }
        if ($Anfrage.alleDateien)     { $a += (New-Arg "-AlleDateien") }
        if ($Anfrage.ohneUnterordner) { $a += (New-Arg "-OhneUnterordner") }
    }
    if ($Anfrage.gruppierung) { $a += (New-Arg "-Gruppierung" ([string]$Anfrage.gruppierung)) }
    if ($Vorschau)            { $a += (New-Arg "-WhatIf") }
    return $a
}

# --- Freien Port suchen und Dienst starten -----------------------------------
$listener = $null
$gewaehlterPort = 0
for ($p = $Port; $p -lt ($Port + 20); $p++) {
    try {
        $l = New-Object System.Net.HttpListener
        $l.Prefixes.Add("http://127.0.0.1:$p/")
        $l.Start()
        $listener = $l
        $gewaehlterPort = $p
        break
    } catch {
        if ($l) { try { $l.Close() } catch { } }
    }
}
if (-not $listener) {
    Write-Host "Kein freier Port zwischen $Port und $($Port + 19) gefunden." -ForegroundColor Red
    exit 1
}

$adresse    = "http://127.0.0.1:$gewaehlterPort/?t=$Token"
$startPfade = Get-AktuellePfade -Konfig (Get-KonfigRoh).Konfig

Write-Host ""
Write-Host "GoDigital Medienimport - Weboberfläche läuft." -ForegroundColor Cyan
Write-Host "Adresse: $adresse" -ForegroundColor Cyan
Write-Host "Inbox:      $($startPfade.Inbox)"
Write-Host "Mediathek:  $($startPfade.Mediathek)"
Write-Host "Protokolle: $($startPfade.Protokolle)"
if ($PfadUeberschreibung.Count) {
    Write-Host "Für diese Sitzung fest vorgegeben: $(($PfadUeberschreibung.Keys | Sort-Object) -join ', ')" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Zum Beenden dieses Fenster schließen oder Strg+C drücken." -ForegroundColor Yellow
Write-Host ""

if (-not $OhneBrowser) {
    try { Start-Process $adresse | Out-Null } catch {
        Write-Host "Browser ließ sich nicht öffnen, Adresse bitte von Hand aufrufen." -ForegroundColor Yellow
    }
}

# --- Schleife ----------------------------------------------------------------
try {
    while ($listener.IsListening) {
        $kontext  = $listener.GetContext()
        $anfrage  = $kontext.Request
        $antwort  = $kontext.Response
        $pfad     = $anfrage.Url.AbsolutePath.TrimEnd('/')
        if (-not $pfad) { $pfad = "/" }

        try {
            # Schutz gegen DNS-Rebinding: nur die Schleifenadresse ist erlaubt.
            $hostKopf = $anfrage.UserHostName
            if ($hostKopf -and ($hostKopf -notmatch '^(127\.0\.0\.1|localhost)(:\d+)?$')) {
                Write-TextAntwort $antwort "Nur über 127.0.0.1 erreichbar." "text/plain; charset=utf-8" 403
                $antwort.Close(); continue
            }

            if ($pfad -eq "/") {
                Write-TextAntwort $antwort ([System.IO.File]::ReadAllText($SeitenDatei))
                $antwort.Close(); continue
            }

            # Ab hier ist alles API und tokenpflichtig.
            $gesendet = $anfrage.Headers["X-Token"]
            if (-not $gesendet) { $gesendet = $anfrage.QueryString["t"] }
            if ($gesendet -ne $Token) {
                Write-JsonAntwort $antwort ([pscustomobject]@{ ok = $false; fehler = "Token fehlt oder stimmt nicht. Seite neu über die Startadresse öffnen." }) 403
                $antwort.Close(); continue
            }

            $koerper = $null
            if ($anfrage.HasEntityBody) {
                $leser = New-Object System.IO.StreamReader($anfrage.InputStream, [System.Text.Encoding]::UTF8)
                $rohKoerper = $leser.ReadToEnd()
                $leser.Close()
                if ($rohKoerper) { $koerper = $rohKoerper | ConvertFrom-Json }
            }

            switch ($pfad) {

                "/api/lage" {
                    Write-JsonAntwort $antwort ([pscustomobject]@{ ok = $true; lage = (Get-Lage) })
                }

                "/api/einstellungen" {
                    if ($anfrage.HttpMethod -eq "POST") {
                        try {
                            $neu = Set-EinstellungenObjekt -Eingang $koerper
                            Write-JsonAntwort $antwort ([pscustomobject]@{ ok = $true; werte = $neu; hinweis = "Gespeichert. Die vorige Fassung liegt als einstellungen.json.bak daneben." })
                        } catch {
                            Write-JsonAntwort $antwort ([pscustomobject]@{ ok = $false; fehler = $_.Exception.Message }) 400
                        }
                    } else {
                        Write-JsonAntwort $antwort ([pscustomobject]@{ ok = $true; einstellungen = (Get-EinstellungenObjekt) })
                    }
                }

                "/api/vorschau" {
                    $pfade = Get-AktuellePfade -Konfig (Get-KonfigRoh).Konfig
                    $lauf  = Invoke-Importskript -Argumente (Get-LaufArgumente -Anfrage $koerper -Pfade $pfade -Vorschau)
                    $aus   = Read-SkriptAusgabe -Ausgabe $lauf.Ausgabe -MediathekPfad $pfade.Mediathek
                    Write-JsonAntwort $antwort ([pscustomobject]@{
                        ok        = ($lauf.Code -eq 0)
                        exitCode  = $lauf.Code
                        aktionen  = $aus.aktionen
                        meldungen = $aus.meldungen
                    })
                }

                "/api/import" {
                    $pfade = Get-AktuellePfade -Konfig (Get-KonfigRoh).Konfig
                    $lauf  = Invoke-Importskript -Argumente (Get-LaufArgumente -Anfrage $koerper -Pfade $pfade)
                    $aus   = Read-SkriptAusgabe -Ausgabe $lauf.Ausgabe -MediathekPfad $pfade.Mediathek
                    $name  = ""
                    if ($aus.protokoll) { $name = [System.IO.Path]::GetFileName($aus.protokoll) }
                    Write-JsonAntwort $antwort ([pscustomobject]@{
                        ok            = ($lauf.Code -eq 0)
                        exitCode      = $lauf.Code
                        meldungen     = $aus.meldungen
                        verschoben    = $aus.verschoben
                        uebersprungen = $aus.uebersprungen
                        protokollName = $name
                    })
                }

                "/api/protokolle" {
                    $pfade = Get-AktuellePfade -Konfig (Get-KonfigRoh).Konfig
                    $liste = @()
                    if (Test-Path -LiteralPath $pfade.Protokolle -PathType Container) {
                        $liste = @(Get-ChildItem -LiteralPath $pfade.Protokolle -Filter "protokoll_*.md" -File |
                                   Sort-Object LastWriteTime -Descending |
                                   Select-Object -First 50 |
                                   ForEach-Object {
                                       [pscustomobject]@{
                                           name  = $_.Name
                                           datum = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
                                       }
                                   })
                    }
                    Write-JsonAntwort $antwort ([pscustomobject]@{ ok = $true; protokolle = $liste })
                }

                "/api/protokoll" {
                    $name = $anfrage.QueryString["name"]
                    # Nur ein reiner Dateiname, kein Pfad: sonst liesse sich hier
                    # jede Datei des Rechners auslesen.
                    if (-not $name -or $name -notmatch '^protokoll_[0-9_]+\.md$') {
                        Write-JsonAntwort $antwort ([pscustomobject]@{ ok = $false; fehler = "Ungültiger Protokollname." }) 400
                    } else {
                        $pfade = Get-AktuellePfade -Konfig (Get-KonfigRoh).Konfig
                        $datei = Join-Path $pfade.Protokolle $name
                        if (Test-Path -LiteralPath $datei -PathType Leaf) {
                            Write-JsonAntwort $antwort ([pscustomobject]@{ ok = $true; name = $name; inhalt = ([System.IO.File]::ReadAllText($datei)) })
                        } else {
                            Write-JsonAntwort $antwort ([pscustomobject]@{ ok = $false; fehler = "Protokoll nicht gefunden." }) 404
                        }
                    }
                }

                default {
                    Write-JsonAntwort $antwort ([pscustomobject]@{ ok = $false; fehler = "Unbekannter Aufruf: $pfad" }) 404
                }
            }
        } catch {
            try {
                Write-JsonAntwort $antwort ([pscustomobject]@{ ok = $false; fehler = $_.Exception.Message }) 500
            } catch { }
            Write-Host "Fehler bei '$pfad': $($_.Exception.Message)" -ForegroundColor Red
        } finally {
            try { $antwort.Close() } catch { }
        }
    }
} finally {
    if ($listener) {
        try { $listener.Stop(); $listener.Close() } catch { }
    }
    Write-Host "Weboberfläche beendet." -ForegroundColor Cyan
}
