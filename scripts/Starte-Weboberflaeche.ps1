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

# Liegt Unten innerhalb von Oben? Dieselbe Regel wie im Installationsassistenten
# (installer\Ordnerpruefung.iss). Der Backslash am Ende ist wichtig: ohne ihn
# gaelte C:\Bilder2 als Unterordner von C:\Bilder.
function Test-LiegtInnerhalb {
    param([string]$Unten, [string]$Oben)
    $u = ($Unten.Trim().TrimEnd('\') + '\').ToLowerInvariant()
    $o = ($Oben.Trim().TrimEnd('\') + '\').ToLowerInvariant()
    return ($u.Length -gt $o.Length -and $u.StartsWith($o))
}

$Token = [guid]::NewGuid().ToString('N')

# --- Antworten ---------------------------------------------------------------
function Write-JsonAntwort {
    param($Antwort, $Objekt, [int]$Status = 200, [int]$Tiefe = 4)
    $json  = $Objekt | ConvertTo-Json -Depth $Tiefe -Compress
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

# --- Vorschaubilder aus der Windows-Shell ------------------------------------
# Dieselbe Quelle wie der Explorer: liefert Bilder fuer alles, wofuer Windows
# einen Codec hat - JPG, PNG und Videos immer, HEIC und RAW je nach Rechner.
# Gemessen unter 5.1: nach dem ersten Aufruf 15 bis 30 ms je Datei. Scheitert das
# Uebersetzen (unter PowerShell 7 fehlt System.Drawing in dieser Form), gibt es
# keine Vorschaubilder; die Seite zeigt dann Symbole, alles andere laeuft weiter.
$VorschaubildBereit = $false
try {
    Add-Type -ReferencedAssemblies System.Drawing -ErrorAction Stop -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class GoDigitalShellBild {
    [ComImport, Guid("bcc18b79-ba16-442f-80c4-8a59c30c463b"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IShellItemImageFactory {
        [PreserveSig] int GetImage(SIZE size, int flags, out IntPtr phbm);
    }
    [StructLayout(LayoutKind.Sequential)] struct SIZE { public int cx; public int cy; }

    [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
    static extern void SHCreateItemFromParsingName(string path, IntPtr pbc, [MarshalAs(UnmanagedType.LPStruct)] Guid riid, [MarshalAs(UnmanagedType.Interface)] out IShellItemImageFactory ppv);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr h);

    public static byte[] Jpeg(string pfad, int kante) {
        IShellItemImageFactory f;
        SHCreateItemFromParsingName(pfad, IntPtr.Zero, typeof(IShellItemImageFactory).GUID, out f);
        IntPtr h;
        SIZE s; s.cx = kante; s.cy = kante;
        // 0x08 = nur ein echtes Vorschaubild, nie das Symbol des Dateityps
        int hr = f.GetImage(s, 0x08, out h);
        Marshal.ReleaseComObject(f);
        if (hr != 0) return null;
        try {
            using (Bitmap b = Image.FromHbitmap(h))
            using (MemoryStream m = new MemoryStream()) {
                b.Save(m, ImageFormat.Jpeg);
                return m.ToArray();
            }
        } finally { DeleteObject(h); }
    }
}
'@
    $VorschaubildBereit = $true
} catch {
    Write-Host "Hinweis: Vorschaubilder stehen nicht zur Verfügung ($($_.Exception.Message.Split("`n")[0]))." -ForegroundColor Yellow
}

# --- Importskript als eigener Prozess, im Hintergrund ------------------------
# Der Dienst bedient eine Anfrage nach der anderen. Wuerde er auf das Ende des
# Laufs warten, koennte die Seite waehrenddessen nicht einmal nach dem Stand
# fragen - genau das war bis 1.3.0 so ("Import laeuft ...", sonst nichts). Der
# Lauf wird deshalb nur gestartet; sein Stand kommt aus der Statusdatei des
# Motors, sein Ergebnis holt Get-Laufstand ab, sobald der Prozess beendet ist.
$script:Lauf = $null

function Test-LaufAktiv {
    return ($null -ne $script:Lauf -and $null -eq $script:Lauf.Ergebnis)
}

function Start-Importlauf {
    param([object[]]$Argumente, [string]$Art, $Pfade)

    $statusDatei = Join-Path ([System.IO.Path]::GetTempPath()) "godigital-medienimport-status-$Token.json"
    try { [System.IO.File]::Delete($statusDatei) } catch { }
    $Argumente = @($Argumente) + (New-Arg "-StatusDatei" $statusDatei)

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
    # Beide Stroeme MUESSEN nebenher gelesen werden. Bleibt einer ungelesen,
    # blockiert der Kindprozess, sobald dessen Puffer voll ist.
    $script:Lauf = [pscustomobject]@{
        Prozess     = $p
        Aus         = $p.StandardOutput.ReadToEndAsync()
        Err         = $p.StandardError.ReadToEndAsync()
        Art         = $Art
        Pfade       = $Pfade
        StatusDatei = $statusDatei
        Beginn      = Get-Date
        Fortschritt = $null
        Ergebnis    = $null
    }
}

function Get-Laufstand {
    $l = $script:Lauf
    if (-not $l) {
        return [pscustomobject]@{ laeuft = $false; art = ""; sekunden = 0; fortschritt = $null; ergebnis = $null }
    }
    if (-not $l.Ergebnis) {
        # Der Motor schreibt die Datei, waehrend hier gelesen wird. Ein halber
        # Stand ist kein Fehler: Dann gilt der letzte lesbare weiter.
        try {
            if ([System.IO.File]::Exists($l.StatusDatei)) {
                $l.Fortschritt = ([System.IO.File]::ReadAllText($l.StatusDatei) | ConvertFrom-Json)
            }
        } catch { }

        if ($l.Prozess.HasExited) {
            $l.Prozess.WaitForExit()
            $ausgabe = $l.Aus.Result
            [void]$l.Err.Result
            $code = $l.Prozess.ExitCode
            $l.Prozess.Dispose()
            try { [System.IO.File]::Delete($l.StatusDatei) } catch { }

            $aus = Read-SkriptAusgabe -Ausgabe $ausgabe -MediathekPfad $l.Pfade.Mediathek -InboxPfad $l.Pfade.Inbox
            if ($l.Art -eq 'vorschau') {
                $l.Ergebnis = [pscustomobject]@{
                    ok        = ($code -eq 0)
                    exitCode  = $code
                    aktionen  = $aus.aktionen
                    meldungen = $aus.meldungen
                }
            } else {
                $name = ""
                if ($aus.protokoll) { $name = [System.IO.Path]::GetFileName($aus.protokoll) }
                $l.Ergebnis = [pscustomobject]@{
                    ok            = ($code -eq 0)
                    exitCode      = $code
                    meldungen     = $aus.meldungen
                    verschoben    = $aus.verschoben
                    uebersprungen = $aus.uebersprungen
                    protokollName = $name
                }
            }
        }
    }
    return [pscustomobject]@{
        laeuft      = ($null -eq $l.Ergebnis)
        art         = $l.Art
        sekunden    = [int]((Get-Date) - $l.Beginn).TotalSeconds
        fortschritt = $l.Fortschritt
        ergebnis    = $l.Ergebnis
    }
}

# Der Pfad einer Datei relativ zu Inbox oder Mediathek. Die Seite fordert damit
# das Vorschaubild an; einen vollen Pfad gibt sie nie zurueck.
function Get-RelativZurWurzel {
    param([string]$Pfad, [string]$InboxPfad, [string]$MediathekPfad)
    foreach ($paar in @(@('inbox', $InboxPfad), @('mediathek', $MediathekPfad))) {
        if (-not $paar[1]) { continue }
        $w = $paar[1].TrimEnd('\') + '\'
        if ($Pfad.StartsWith($w, [System.StringComparison]::OrdinalIgnoreCase)) {
            return [pscustomobject]@{ wurzel = $paar[0]; pfad = $Pfad.Substring($w.Length) }
        }
    }
    return [pscustomobject]@{ wurzel = ""; pfad = "" }
}

# Dieselbe Regel wie im Importskript (Test-OrdnernameErlaubt). Bewusst kopiert,
# die beiden Skripte bleiben voneinander unabhaengig.
function Test-OrdnernameErlaubt {
    param([string]$Name)
    if ($Name -match '[\\/:*?"<>|]') { return $false }
    if ($Name -match '[. ]$')        { return $false }
    if ($Name -match '^(CON|PRN|AUX|NUL|COM\d|LPT\d)$') { return $false }
    return $true
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
    param([string]$Ausgabe, [string]$MediathekPfad, [string]$InboxPfad)

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
                $herkunft = Get-RelativZurWurzel -Pfad $quelle -InboxPfad $InboxPfad -MediathekPfad $MediathekPfad
                $aktionen.Add([pscustomobject]@{
                    quelleName = [System.IO.Path]::GetFileName($quelle)
                    # Fuer das Vorschaubild: wo die Datei JETZT liegt.
                    wurzel     = $herkunft.wurzel
                    quelle     = $herkunft.pfad
                    zielOrdner = [System.IO.Path]::GetDirectoryName($relativ)
                    zielName   = [System.IO.Path]::GetFileName($ziel)
                    # Der Motor haengt diesen Zusatz an den ShouldProcess-Text,
                    # wenn das Datum aus dem Dateisystem stammt. Bewusst gegen
                    # den festen Wortlaut geprueft und nicht gegen eine
                    # beliebige Klammer: Pfade duerfen Klammern enthalten.
                    geschaetzt = ($z -match '\(Datum aus Dateisystem\)')
                })
            }
            continue
        }

        # Die drei Zeilen tragen jeweils ein eigenes Feld "ziel": Frueher stand
        # bei OK der Zielpfad in der Spalte "Grund", und ein geschaetztes Datum
        # war auf der Seite von einem echten nicht zu unterscheiden.
        if ($z -match '^SKIP\s+''(.+?)''\s*-\s*(.+)$') {
            $meldungen.Add([pscustomobject]@{ status = "SKIP"; datei = $Matches[1]; ziel = ""; grund = $Matches[2] })
            continue
        }
        if ($z -match '^FEHLER\s+''(.+?)''\s*:\s*(.+)$') {
            $meldungen.Add([pscustomobject]@{ status = "FEHLER"; datei = $Matches[1]; ziel = ""; grund = $Matches[2] })
            continue
        }
        # Der Grund in Klammern ist freiwillig: Der Reorganisieren-Modus schreibt
        # keinen, und eine Datei mit echtem Aufnahmedatum hat keinen.
        if ($z -match '^OK\s+''(.+?)''\s*->\s*''(.+?)''(?:\s+\((.+)\))?\s*$') {
            $meldungen.Add([pscustomobject]@{ status = "OK"; datei = $Matches[1]; ziel = $Matches[2]; grund = $Matches[3] })
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
    # Verschachtelung ist genauso schaedlich wie Gleichheit, nur unauffaelliger:
    # Der Import liest den inneren Ordner bei jedem Lauf mit. Der Assistent des
    # Installationsprogramms lehnt das ab, die Seite darf es nicht wieder erlauben.
    if (Test-LiegtInnerhalb -Unten $inbox -Oben $mediathek) {
        throw "Die Inbox darf nicht innerhalb der Mediathek liegen: Der Import würde die Mediathek sonst bei jedem Lauf noch einmal mitlesen."
    }
    if (Test-LiegtInnerhalb -Unten $mediathek -Oben $inbox) {
        throw "Die Mediathek darf nicht innerhalb der Inbox liegen: Der Import würde die bereits einsortierten Dateien sonst immer wieder einlesen."
    }
    # Auch der Programmordner selbst darf nicht darin liegen: Der Import zaehlte
    # und verarbeitete sonst seine eigene Installation mit, samt der rund 500
    # Dateien von ExifTool.
    if ($Root -ieq $inbox -or (Test-LiegtInnerhalb -Unten $Root -Oben $inbox)) {
        throw "Das Programm selbst liegt in diesem Ordner ($Root). Als Inbox taugt er deshalb nicht: Der Import würde die eigene Installation mitlesen. Bitte einen Unterordner darunter wählen."
    }
    if ($Root -ieq $mediathek -or (Test-LiegtInnerhalb -Unten $Root -Oben $mediathek)) {
        throw "Das Programm selbst liegt in diesem Ordner ($Root). Als Mediathek taugt er deshalb nicht: Beim Umsortieren würden die eigenen Ordner mitbehandelt."
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
    if (-not (Test-OrdnernameErlaubt $neu.EreignisOrdnerName)) {
        throw "Der Name des Ereignis-Zweigs taugt nicht als Ordnername. Nicht erlaubt sind die Zeichen \ / : * ? `" < > | sowie ein Punkt oder Leerzeichen am Ende."
    }

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

    # Liegt der Programmordner in der Inbox, gehoeren seine Dateien nicht dazu -
    # sonst stehen in der Lage die rund 500 Dateien von ExifTool als "warten in
    # der Inbox". Der Motor uebergeht sie beim Import aus demselben Grund. Die
    # Zahl wird also richtig, aber die Einstellung bleibt falsch: dafuer die
    # Meldung programmInDerInbox, die die Seite als Warnung anzeigt.
    $programmInDerInbox = (Test-LiegtInnerhalb -Unten $Root -Oben $pfade.Inbox)
    $programmOrdner     = $Root.TrimEnd('\') + '\'

    # Namens- und Endungsfilter wie beim Motor, damit die zweite Zahl unten
    # stimmt. Der Motor zieht dieselben Werte aus derselben Datei.
    $praefix = ""
    if ($roh.Konfig -and ($roh.Konfig.PSObject.Properties.Name -contains 'Praefix') -and $roh.Konfig.Praefix) {
        $praefix = [string]$roh.Konfig.Praefix
    }
    $typen = $standardErweiterungen
    if ($roh.Konfig -and ($roh.Konfig.PSObject.Properties.Name -contains 'Erweiterungen') -and $null -ne $roh.Konfig.Erweiterungen) {
        $typen = @($roh.Konfig.Erweiterungen)
    }
    $typen = @($typen | ForEach-Object { ([string]$_).TrimStart('.').ToLowerInvariant() } | Where-Object { $_ })

    $inboxDateien      = 0
    $inboxZuImportieren = 0
    $inboxOrdner       = @()
    $inboxDa = Test-Path -LiteralPath $pfade.Inbox -PathType Container
    if ($inboxDa) {
        $dateien = @(Get-ChildItem -LiteralPath $pfade.Inbox -File -Recurse -ErrorAction SilentlyContinue)
        $ordner  = @(Get-ChildItem -LiteralPath $pfade.Inbox -Directory -ErrorAction SilentlyContinue)
        if ($programmInDerInbox) {
            $dateien = @($dateien | Where-Object { -not $_.FullName.StartsWith($programmOrdner, [System.StringComparison]::OrdinalIgnoreCase) })
            $ordner  = @($ordner  | Where-Object { -not ($_.FullName.TrimEnd('\') + '\').StartsWith($programmOrdner, [System.StringComparison]::OrdinalIgnoreCase) })
        }
        $inboxDateien = $dateien.Count
        $inboxOrdner  = @($ordner | Select-Object -ExpandProperty Name)

        # Die Gesamtzahl allein liest sich nach unerledigter Arbeit: Nach einem
        # vollstaendigen Import bleiben Textdateien, XMP-Beidateien und
        # Thumbs.db liegen, die nie importiert werden. Eine leere Typenliste
        # schaltet den Filter ab, genau wie im Motor.
        $kandidaten = $dateien
        if ($praefix) {
            $kandidaten = @($kandidaten | Where-Object { $_.Name.StartsWith($praefix, [System.StringComparison]::OrdinalIgnoreCase) })
        }
        if ($typen.Count -gt 0) {
            $kandidaten = @($kandidaten | Where-Object { $typen -contains $_.Extension.TrimStart('.').ToLowerInvariant() })
        }
        $inboxZuImportieren = $kandidaten.Count
    }
    $mediathekDateien = 0
    $mediathekDa = Test-Path -LiteralPath $pfade.Mediathek -PathType Container
    if ($mediathekDa) {
        $mediathekDateien = @(Get-ChildItem -LiteralPath $pfade.Mediathek -File -Recurse -ErrorAction SilentlyContinue).Count
    }

    # Liegen Inbox und Mediathek auf verschiedenen Laufwerken, kopiert der Motor
    # jede Datei und loescht danach die Quelle, statt sie nur umzubenennen. Bei
    # grossen Bildmengen ist das der Unterschied zwischen Sekunden und Minuten,
    # deshalb sagt die Seite es vor dem Lauf und nicht erst danach.
    $verschiedeneLaufwerke = $false
    try {
        $wInbox     = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($pfade.Inbox))
        $wMediathek = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($pfade.Mediathek))
        $verschiedeneLaufwerke = -not ($wInbox -ieq $wMediathek)
    } catch { }

    return [pscustomobject]@{
        inbox              = $pfade.Inbox
        inboxVorhanden     = $inboxDa
        inboxDateien       = $inboxDateien
        inboxZuImportieren = $inboxZuImportieren
        inboxOrdner        = $inboxOrdner
        mediathek          = $pfade.Mediathek
        mediathekVorhanden = $mediathekDa
        mediathekDateien   = $mediathekDateien
        protokolle         = $pfade.Protokolle
        exifTool           = $exif
        exifToolVorhanden  = (Test-Path -LiteralPath $exif -PathType Leaf)
        programmInDerInbox = $programmInDerInbox
        programmOrdner     = $Root
        verschiedeneLaufwerke = $verschiedeneLaufwerke
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

                { $_ -in "/api/vorschau", "/api/import" } {
                    # Beide starten nur. Stand und Ergebnis holt die Seite ueber
                    # /api/laufstatus ab.
                    if ($anfrage.HttpMethod -ne "POST") {
                        Write-JsonAntwort $antwort ([pscustomobject]@{ ok = $false; fehler = "Dieser Aufruf braucht POST." }) 405
                    } elseif (Test-LaufAktiv) {
                        Write-JsonAntwort $antwort ([pscustomobject]@{ ok = $false; fehler = "Es läuft bereits ein Lauf. Bitte warten, bis er fertig ist." }) 409
                    } else {
                        $pfade = Get-AktuellePfade -Konfig (Get-KonfigRoh).Konfig
                        if ($pfad -eq "/api/vorschau") {
                            Start-Importlauf -Art 'vorschau' -Pfade $pfade -Argumente (Get-LaufArgumente -Anfrage $koerper -Pfade $pfade -Vorschau)
                        } else {
                            Start-Importlauf -Art 'import' -Pfade $pfade -Argumente (Get-LaufArgumente -Anfrage $koerper -Pfade $pfade)
                        }
                        Write-JsonAntwort $antwort ([pscustomobject]@{ ok = $true; gestartet = $true })
                    }
                }

                "/api/laufstatus" {
                    Write-JsonAntwort $antwort ([pscustomobject]@{ ok = $true; lauf = (Get-Laufstand) }) 200 7
                }

                "/api/vorschaubild" {
                    # Nur Dateien innerhalb von Inbox oder Mediathek, und nur als
                    # verkleinertes Bild: Der Aufruf gibt nie eine Datei im
                    # Original heraus.
                    $pfade  = Get-AktuellePfade -Konfig (Get-KonfigRoh).Konfig
                    $wurzel = switch ($anfrage.QueryString["wurzel"]) {
                        "inbox"     { $pfade.Inbox }
                        "mediathek" { $pfade.Mediathek }
                        default     { "" }
                    }
                    $rel = $anfrage.QueryString["pfad"]
                    $voll = ""
                    if ($wurzel -and $rel) {
                        try { $voll = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($wurzel, $rel)) } catch { $voll = "" }
                    }
                    if (-not $voll -or -not (Test-LiegtInnerhalb -Unten $voll -Oben ([System.IO.Path]::GetFullPath($wurzel)))) {
                        Write-JsonAntwort $antwort ([pscustomobject]@{ ok = $false; fehler = "Ungültiger Pfad." }) 400
                    } else {
                        $bild = $null
                        if ($VorschaubildBereit -and [System.IO.File]::Exists($voll)) {
                            try { $bild = [GoDigitalShellBild]::Jpeg($voll, 320) } catch { $bild = $null }
                        }
                        if ($bild) {
                            $antwort.StatusCode      = 200
                            $antwort.ContentType     = "image/jpeg"
                            $antwort.Headers["Cache-Control"] = "private, max-age=300"
                            $antwort.ContentLength64 = $bild.Length
                            $antwort.OutputStream.Write($bild, 0, $bild.Length)
                        } else {
                            Write-JsonAntwort $antwort ([pscustomobject]@{ ok = $false; fehler = "Kein Vorschaubild." }) 404
                        }
                    }
                }

                "/api/oeffne" {
                    # Nur die drei bekannten Ordner, nie ein Pfad aus der Anfrage.
                    $pfade = Get-AktuellePfade -Konfig (Get-KonfigRoh).Konfig
                    $ziel = ""
                    if ($koerper) {
                        $ziel = switch ([string]$koerper.ordner) {
                            "inbox"      { $pfade.Inbox }
                            "mediathek"  { $pfade.Mediathek }
                            "protokolle" { $pfade.Protokolle }
                            default      { "" }
                        }
                    }
                    if ($anfrage.HttpMethod -ne "POST" -or -not $ziel) {
                        Write-JsonAntwort $antwort ([pscustomobject]@{ ok = $false; fehler = "Unbekannter Ordner." }) 400
                    } elseif (-not (Test-Path -LiteralPath $ziel -PathType Container)) {
                        Write-JsonAntwort $antwort ([pscustomobject]@{ ok = $false; fehler = "Den Ordner gibt es noch nicht: $ziel" }) 404
                    } else {
                        Start-Process explorer.exe -ArgumentList ('"' + $ziel + '"')
                        Write-JsonAntwort $antwort ([pscustomobject]@{ ok = $true })
                    }
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
