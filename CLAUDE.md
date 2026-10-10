# CLAUDE.md

**Repository:** `godigital-medienimport`
**Beschreibung:** Fotos und Videos nach Aufnahmedatum einsortieren

Guidance für Claude Code (claude.ai/code) in diesem Ordner.

# GoDigital Medienimport

Ein von Claude betreuter Prozess-Ordner für Fotos und Videos beliebiger Herkunft
(Handy, Kamera, Drohne, Downloads). Neue Dateien werden nach ihrem Aufnahmedatum
umbenannt und in eine chronologisch sortierbare Mediathek einsortiert. Keine Tests,
keine Build-Kette – das gesamte Programm ist ein einziges PowerShell-Skript.

Der Ordner liegt als Git-Repository `godigital-medienimport` vor. Versioniert werden
Skripte, Seite, Konfiguration und Dokumentation; Inbox, Mediathek, Laufprotokolle und
`.bak`-Kopien hält die `.gitignore` draußen. `inbox\.gitkeep` hält den sonst leeren
Eingangsordner im Repository – ohne ihn bricht das Skript nach einem Klonen mit
`exit 1` ab. Der Import fasst diese Datei auch mit `-AlleDateien` nicht an (geprüft).

**Verhältnis zu `E:\Drohne-Foto-Workflow`:** Dieses Projekt ist aus dessen Skript
hervorgegangen, läuft aber vollständig getrennt und hat eine eigene Mediathek. Das
Altprojekt ist eingefroren und wird von hier aus **nicht** verändert – weder Skript
noch Mediathek, auch nicht sein `archiv\`.

## Ordnerstruktur

| Ordner / Datei | Zweck |
|---|---|
| `inbox\` | **Eingang.** Lose Dateien werden nach Datum einsortiert, Unterordner gelten als Ereignis. |
| `mediathek\` | **Ergebnis.** Datumsbaum `<Jahr>\<Jahr-Monat>\` plus Zweig `Ereignisse\`. Nicht manuell umbenennen. |
| `mediathek\Ereignisse\` | Benannte Ereignisordner, aus Inbox-Unterordnern oder `-Ereignis`. |
| `config\einstellungen.json` | Standardwerte. Optional; fehlt sie, greifen die eingebauten Werte. |
| `config\einstellungen.vorlage.json` | Versionierte Vorlage mit leeren Ordnerangaben. Der Installer macht daraus die echte Datei. |
| `scripts\Importiere-Medien.ps1` | Der Motor. Läuft eigenständig, kennt die Oberfläche nicht. |
| `scripts\Starte-Weboberflaeche.ps1` | HTTP-Dienst auf 127.0.0.1, ruft den Motor als eigenen Prozess auf. |
| `installer\` | **Installationsprogramm.** Inno-Setup-Quelle, Bauskript und zwei Hilfsskripte, die das Setup zur Laufzeit ruft. |
| `docs\superpowers\` | Specs und Umsetzungspläne. Versioniert, kommt nicht ins Setup. |
| `web\index.html` | Die Oberfläche. Wird vom Dienst ausgeliefert, lädt nichts von außen. |
| `protokolle\` | Ein Markdown-Protokoll pro echtem Lauf (`protokoll_<zeitstempel>.md`). |
| `protokolle\…_Anleitung-bebildert.pdf` | Bebilderte Anwenderanleitung. Versioniert, anders als die Laufprotokolle daneben. |
| `protokolle\…_Anleitung-bebildert.html` | Die Quelle dazu. Alle Zeichnungen stecken als SVG darin, nichts wird nachgeladen. |
| `DOKU-STIL.md` | Kopie der Skill `anwenderdoku-pdf` (Stand 2026-09-25). Bauweise und Layout der bebilderten Anleitung. Maßgeblich bleibt die Skill-Datei. |
| `.gitignore` | Hält Medien, Laufprotokolle und `.bak`-Kopien aus dem Repository. Ignoriert wird nur `protokolle\protokoll_*.md`, nicht der ganze Ordner: Anleitung und HTML-Quelle darin sind versioniert. |
| `Medien importieren.cmd` | **Doppelklick-Start** (ohne Claude). |
| `Vorschau (aendert nichts).cmd` | Doppelklick-Vorschau (`-WhatIf`). |
| `Weboberflaeche starten.cmd` | Doppelklick-Start der Oberfläche. Fenster muss offen bleiben. |
| `ANLEITUNG.md` | Nutzerdokumentation (nicht-technisch). Muss zu diesem Skript passen. |
| `VERSION` | Eine Zeile, die Versionsnummer. Einzige Quelle; Protokollkopf und Setup lesen sie von hier. |
| `LICENSE` | MIT, Inhaber Martin Goßner. |
| `README.md` | Einstieg auf GitHub: Downloadlink, Voraussetzungen, SmartScreen-Hinweis. |

## Befehle

```powershell
# Vorschau, ändert nichts und schreibt kein Protokoll:
.\scripts\Importiere-Medien.ps1 -WhatIf

# Echter Lauf:
.\scripts\Importiere-Medien.ps1

# Fester Ereignisordner für den ganzen Lauf:
.\scripts\Importiere-Medien.ps1 -Ereignis "2026-09_Urlaub Italien"

# Nur Dateien mit bestimmtem Namensanfang / bestimmten Endungen:
.\scripts\Importiere-Medien.ps1 -Praefix "DJI_"
.\scripts\Importiere-Medien.ps1 -Erweiterungen jpg,heic,mp4
.\scripts\Importiere-Medien.ps1 -AlleDateien

# Unterordner nicht als Ereignis werten, Dateien daraus nach Datum einsortieren:
.\scripts\Importiere-Medien.ps1 -OhneUnterordner

# Anderes Ordnerschema:
.\scripts\Importiere-Medien.ps1 -Gruppierung Jahr        # JahrMonat | Jahr | Tag | Keine

# Bestehende Mediathek umsortieren (idempotent, Ereignis-Zweig bleibt aussen vor):
.\scripts\Importiere-Medien.ps1 -Reorganisieren -WhatIf

# Isoliert testen, ohne die echte Mediathek anzufassen:
.\scripts\Importiere-Medien.ps1 -Inbox <testInbox> -Mediathek <testZiel> -Protokolle <testLog> -WhatIf

# Weboberfläche starten (öffnet den Browser, Fenster muss offen bleiben):
.\scripts\Starte-Weboberflaeche.ps1
.\scripts\Starte-Weboberflaeche.ps1 -Port 9000 -OhneBrowser
```

Scheitert der `.ps1`-Aufruf an der Execution-Policy, hilft die `.cmd` (startet mit
`-ExecutionPolicy Bypass`) oder einmalig `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

Rauchtest gegen eine Wegwerf-Mediathek, ohne echte Bilder. Testdateien brauchen kein
EXIF: ExifTool listet auch eine 1-Byte-Datei mit Endung `.JPG`, das Skript greift dann
auf das Dateisystemdatum zurück.

```powershell
$t = "$env:TEMP\mt"; Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue
mkdir "$t\inbox\2026-09_Test", "$t\ziel", "$t\log" | Out-Null
"x" > "$t\inbox\IMG_0001.JPG"; "y" > "$t\inbox\2026-09_Test\IMG_0002.JPG"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Importiere-Medien.ps1 `
  -Inbox "$t\inbox" -Mediathek "$t\ziel" -Protokolle "$t\log" -WhatIf
```

`powershell.exe` statt `pwsh` ist Absicht: die `.cmd`-Starter rufen 5.1 auf.

Ohne `-EinstellungsDatei` zieht auch ein Rauchtest die echte `config\einstellungen.json`.
Wer am Einstellungs-Code arbeitet, gibt den Pfad mit an und legt sich eine Testdatei an,
sonst prüft er gegen die Produktivwerte.

## Architektur

Das Skript hat zwei Modi, die sich denselben Protokoll- und Zusammenfassungs-Code teilen.
Die Verzweigung liegt bei `if ($Reorganisieren)`.

**Einstellungen.** `Get-Einstellungen` liest `config\einstellungen.json` per
`ConvertFrom-Json`, `Get-Einstellung` holt einzelne Werte mit Rückfall auf den eingebauten
Standard. Die Rangfolge ist: ausdrücklich übergebener Parameter, dann Datei, dann
eingebauter Standard. Ob ein Parameter ausdrücklich kam, entscheidet
`$PSBoundParameters.ContainsKey(...)` – ohne diese Prüfung ließe sich ein Parameter-Default
nicht von einer bewussten Angabe unterscheiden. Eine fehlende oder kaputte Datei erzeugt
nur eine Warnung; der Doppelklick-Betrieb darf daran nie scheitern.

Das Skript liest genau diese zehn Schlüssel:

| Schlüssel | Typ | Eingebauter Standard | Parameter |
|---|---|---|---|
| `Inbox` | string | `<Root>\inbox` | `-Inbox` |
| `Mediathek` | string | `<Root>\mediathek` | `-Mediathek` |
| `Protokolle` | string | `<Root>\protokolle` | `-Protokolle` |
| `Gruppierung` | string | `JahrMonat` | `-Gruppierung` |
| `Praefix` | string | `""` | `-Praefix` |
| `Erweiterungen` | string[] | 22 Endungen, siehe `$standardErweiterungen` | `-Erweiterungen` |
| `UnterordnerAlsEreignisse` | bool | `true` | `-OhneUnterordner` (invertiert) |
| `EreignisOrdnerName` | string | `Ereignisse` | `-EreignisOrdnerName` |
| `ExifToolPath` | string | `E:\Exiftool\exiftool.exe` | `-ExifToolPath` |
| `VideoZeitAlsOrtszeit` | bool | `true` | keiner, nur über die Datei |

Die drei Ordner sind ein Sonderfall: Sie werden **nach** dem Lesen der Datei gesetzt, nicht
oben bei den übrigen Pfaden, weil sie aus der Datei kommen dürfen. `Get-Ordnerpfad` setzt die
Rangfolge Parameter > Datei > Ordner neben dem Skript um und löst einen relativen Pfad gegen
`$Root` auf, damit `..\Fotos` nicht vom Arbeitsverzeichnis des Aufrufers abhängt. Ein leerer
Wert in der Datei zählt wie ein fehlender. `-EinstellungsDatei` bleibt der einzige Pfad, der
nur über die Kommandozeile geht – er muss feststehen, bevor die Datei gelesen werden kann.

`config\einstellungen.json` liegt **nicht** im Repository: Sie trägt absolute Pfade dieses
Rechners und greift vor den eingebauten Standardwerten, ein Klon zeigte sonst ins Leere.
Versioniert ist `config\einstellungen.vorlage.json` mit leeren Ordnerangaben – ein leerer Wert
zählt wie ein fehlender, ein Klon landet damit bei den Ordnern neben dem Skript. Der Installer
macht aus der Vorlage die echte Datei und trägt die Ordner aus dem Assistenten ein; eine
vorhandene Datei fasst er nicht an.

Der leere `ExifToolPath` der Vorlage ist der Grund für je eine zusätzliche Zeile in beiden
Skripten: `Get-Einstellung` prüft auf `$null`, ein leerer String kommt also durch. Ohne diese
Zeile bräche ein Lauf mit „ExifTool nicht gefunden: " ohne Pfad ab.

Wer einen Schlüssel ergänzt, braucht dafür eine eigene `Get-Einstellung`-Zeile – die Datei
wird nicht automatisch auf Parameter abgebildet.

`"Erweiterungen": []` schaltet den Endungsfilter **ab** und wirkt damit wie `-AlleDateien`.
`Get-Einstellung` prüft auf `$null -ne $wert`, und ein leeres Array ist nicht `$null`, kommt
also durch. Danach ist die Filterbedingung `-not $AlleDateien -and $Erweiterungen -and
$Erweiterungen.Count -gt 0` falsch, und der Filter entfällt; das Protokoll vermerkt
„Endungsfilter: keiner". Geprüft mit einer `liesmich.txt` in der Inbox: sie wird dann zum
Verschieben eingeplant. Wer die eingebaute Liste will, lässt den Schlüssel ganz weg statt
ihn auf `[]` zu setzen. Der Vergleich trimmt auf beiden Seiten führende Punkte, `".jpg"`
funktioniert in der Datei also genauso wie `"jpg"`.

Vorsicht bei `$Gruppierung`: Das `[ValidateSet]` der Variablen wirkt auch bei *späteren*
Zuweisungen. Ein ungültiger Wert aus der JSON-Datei würde beim Zuweisen eine rohe
PowerShell-Fehlermeldung werfen, deshalb wird der Wert vorher geprüft und nur bei Treffer
zugewiesen. Neue Parameter mit `ValidateSet` brauchen dieselbe Behandlung.

**Modus Inbox (Standard).** ExifTool wird **einmal für den ganzen Inbox-Ordner**
aufgerufen, immer mit `-r`. Ein Prozessstart statt einer pro Datei ist die zentrale
Optimierung; sie darf nicht aufgeweicht werden.
Abgefragt werden `-CreateDate -DateTimeOriginal -ModifyDate -FileName -Directory`,
das Datum formatiert ExifTool selbst über `-d` – das Skript parst keine Datumsstrings,
es gibt bewusst kein `ParseExact`. Der Aufruf verwirft stderr mit `2>$null`; Warnungen von
ExifTool zu einzelnen Dateien sieht niemand. Wer einem Verdacht nachgeht, ruft ExifTool von
Hand ohne diese Umleitung auf.

`-api QuickTimeUTC=1` rechnet Videozeiten von UTC in Ortszeit um. Ohne diese Option
sortieren sich Videos gegenüber Fotos desselben Tages um den Zeitzonenversatz verschoben
ein (im Sommer zwei Stunden). Genau dieser Fehler steckt im Altbestand des Vorgängerprojekts.
Abschaltbar über `"VideoZeitAlsOrtszeit": false`.

`$e.Directory` kommt aus ExifTool **mit Schrägstrichen** (`E:/.../inbox/Handy`). Jeder
Pfadvergleich muss vorher `-replace '/','\'` anwenden, sonst schlägt er fehl. Aus demselben
Grund wird die Quelldatei aus `$e.Directory` zusammengesetzt und nicht aus `$Inbox`.

Fallback-Reihenfolge des Datums ist `CreateDate` → `DateTimeOriginal` → `ModifyDate`
→ Änderungsdatum der Datei. Der letzte Schritt ist neu gegenüber dem Vorgängerprojekt
und nötig, weil Screenshots und Messenger-Bilder oft gar kein EXIF haben; er wird im
Protokoll als „Datum aus Dateisystem" vermerkt.

**Bereits benannte Dateien.** Trägt der Dateiname schon einen Datumsvorsatz, gilt dieser
als Aufnahmedatum und das Skript stellt keinen zweiten voran. Ohne diese Regel bekäme eine
zurückgelegte Datei einen neuen Zielnamen, die Kollisionsprüfung liefe nie an, und
dieselbe Aufnahme läge zweimal in der Mediathek. Im Protokoll steht dann „Datum aus
Dateiname". Geprüft wird gegen `$datumsVorsatzMuster` – dieselbe Variable, gegen die auch
`-Reorganisieren` filtert, damit die beiden Modi nicht auseinanderlaufen. Das Muster prüft
Monat, Tag und Uhrzeit auf Plausibilität, ein Name wie `12345678_901234_x.jpg` fällt
deshalb auf das EXIF zurück und bekommt einen normalen Vorsatz.

Umbenennen und Verschieben passieren in **einem** `Move-Item`.

**Modus `-Reorganisieren`.** Liest **keine** Metadaten. Er nimmt Dateien in der Mediathek,
deren Name auf `$datumsVorsatzMuster` passt, und leitet den Zielordner aus dem Namenspräfix ab.
Der Dateiname ist hier die einzige Wahrheit. Der `Ereignisse`-Zweig ist ausgenommen: seine
Ablage folgt nicht dem Dateinamen, ein Umsortieren würde die Ereignisse stillschweigend
auflösen. `-Reorganisieren` zusammen mit `-Ereignis` bricht deshalb mit `exit 1` ab.
Am Ende räumt der Modus leere Unterordner unterhalb von `mediathek\` per
`Remove-Item -Recurse -Force` weg; das ist die einzige löschende Operation im Skript.
Dieses Aufräumen umfasst auch den `Ereignisse`-Zweig: die Ausnahme oben gilt nur für das
Verschieben. Ein leerer, von Hand angelegter Ereignisordner verschwindet also (geprüft).
Bei `-WhatIf` bleibt er stehen, weil `Remove-Item` selbst ShouldProcess unterstützt.

**`-OhneUnterordner` schaltet nur die Ereignis-Zuordnung ab, nicht die Rekursion.**
`$label` bleibt dann leer und die Dateien aus den Unterordnern landen im Datumsbaum
(geprüft). Das `-r` im ExifTool-Aufruf hing früher an dieser Einstellung; ohne Rekursion
sah ExifTool die Unterordner gar nicht und ihre Dateien blieben unbemerkt in der Inbox
liegen. Wer an den ExifTool-Argumenten arbeitet, darf `-r` deshalb nicht wieder an eine
Bedingung hängen. Leere Inbox-Unterordner bleiben in beiden Fällen stehen: in der Inbox
löscht das Skript nichts.

**`Get-Unterordner`** bekommt einen Datumspräfix (`yyyyMMdd_HHmmss`) und das Schema und
liefert den relativen Unterordner. Beide Modi rufen sie auf, deswegen ergibt sich dasselbe
Layout, egal ob eine Datei frisch aus der Inbox kommt oder nachträglich umsortiert wird.
Eine Schema-Änderung gehört ausschließlich in diese Funktion. Der Ereignis-Zweig entsteht
**daneben**, nicht darin.

**`-DatumsFormat`** ist an drei weitere Stellen gekoppelt und deshalb praktisch
unveränderlich: an den Fallback `LastWriteTime.ToString("yyyyMMdd_HHmmss")`, an die Regex
`^(\d{4})(\d{2})(\d{2})` in `Get-Unterordner` und an `$datumsVorsatzMuster`, das beide Modi
auswerten. Ein anderes Format läuft ohne Fehlermeldung durch, sortiert die
Dateien aber falsch ein und macht sie für `-Reorganisieren` unsichtbar. Wer es ändert,
ändert alle vier Stellen.

**`Get-QuellLabel`** leitet den Ereignisnamen aus dem Inbox-Unterordner ab, indem sie den
Inbox-Pfad vorne abschneidet. Sie normalisiert dafür die Schrägstriche aus ExifTool und
vergleicht die Präfixe von Hand: `[System.IO.Path]::GetRelativePath` gibt es in
PowerShell 5.1 nicht.

**`Test-GleicheDatei`** vergleicht erst die Länge, dann SHA256 – ein Hash über eine große
Videodatei kostet sonst unnötig Zeit. Die Funktion nutzt bewusst `System.IO` und
`System.Security.Cryptography` statt `Get-Item`/`Get-FileHash`: die Cmdlets melden unter
Windows PowerShell 5.1 bei `-WhatIf` ihre Provider-Zugriffe und verrauschen die Vorschau.
Neue rein lesende Prüfungen bitte genauso bauen.

**Kollisionen** führen nie zum Überschreiben. Der Inhalt wird allerdings erst verglichen,
wenn der **Zielname** belegt ist; eine Dublette unter anderem Namen erkennt das Skript
nicht. Deshalb ist die Regel zu den bereits benannten Dateien oben kein Schönheitsfix,
sondern Voraussetzung dafür, dass ein zweiter Import überhaupt als Dublette auffällt.
Identische Datei: `SKIP` mit Grund „Dublette, identische Datei vorhanden". Verschiedene Datei: `Get-FreierZielName` hängt
einen Zähler an, bis `_999`; danach gibt sie auf, und die Datei wird als `FEHLER` mit
Grund „kein freier Zielname gefunden" protokolliert. Ein `HashSet` `$geplanteZiele`
verhindert, dass zwei Quelldateien in derselben Vorschau auf denselben Zielnamen zeigen.

**Pfade** werden aus `Split-Path -Parent $PSScriptRoot` abgeleitet. Das Skript muss also
in `scripts\` liegen. `-Inbox`, `-Mediathek`, `-Protokolle` und `-EinstellungsDatei`
überschreiben das jeweils einzeln.

**`-WhatIf`** kommt aus `[CmdletBinding(SupportsShouldProcess)]`. `$WhatIfPreference`
wirkt automatisch auch auf das abschließende `Set-Content`, deshalb entsteht bei einer
Vorschau kein Protokoll – das ist gewollt, nicht vergessen. Neue schreibende Aktionen
müssen entweder in einen `ShouldProcess`-Block oder ein Cmdlet nutzen, das ShouldProcess
selbst unterstützt.

Was eine Vorschau **nicht** zeigt: `OK`-Einträge entstehen erst innerhalb von
`ShouldProcess`, also nur im echten Lauf. Eine Vorschau meldet deshalb immer
„Verschoben: 0" und sammelt in `$ergebnisse` nur `SKIP` und `FEHLER` (geprüft). Was
verschoben würde, steht ausschließlich in den `WhatIf:`-Zeilen von PowerShell. Die
geplante Weboberfläche muss die Vorschau aus diesen Zeilen lesen, nicht aus der
Zusammenfassung.

Dabei zwei Fallen, beide geprüft. Die Schlusszeile nennt auch bei `-WhatIf` einen
Protokollpfad, obwohl an dieser Stelle keine Datei entsteht. Und das unterdrückte
`Set-Content` erzeugt seinerseits eine `WhatIf:`-Zeile („Inhalt festlegen"), die keine
Dateibewegung ist und beim Auswerten herausfallen muss.

**Ergebnisse** sammelt eine `List[object]` mit den Feldern `Status` / `Alt` / `Neu` / `Grund`.
Aus ihr entstehen sowohl die Konsolenausgabe als auch die Detailtabelle im Protokoll.
Statuswerte sind `OK`, `SKIP` und `FEHLER`. `Grund` trägt auch bei `OK` Text, etwa
„Datum aus Dateisystem". Wer eine neue Abbruchbedingung einbaut, fügt dort einen Eintrag
hinzu, sonst fehlt der Fall im Protokoll.

`$uebersprungen` zählt auch die `FEHLER`-Fälle mit. Die Spalte „Übersprungen" in
Zusammenfassung und Protokoll ist also SKIP plus FEHLER; die Gesamtzahl kommt aus
`$ergebnisse.Count`.

**Fehlerbehandlung:** Fehlt ExifTool oder der Inbox-Ordner, bricht das Skript mit `exit 1`
ab. Ein Fehler an einer einzelnen Datei wird gefangen, als `FEHLER` protokolliert und der
Lauf geht weiter – ein defektes Bild darf den Rest nicht stoppen.

## Weboberfläche

`scripts\Starte-Weboberflaeche.ps1` ist ein HTTP-Dienst, `web\index.html` die Seite. Der
Motor bleibt unangetastet und weiß nichts von der Oberfläche. Wer beide Dateien löscht,
verliert nichts am Import; der Doppelklick-Betrieb hängt nicht an ihnen.

**Der Motor läuft als eigener Prozess**, nicht dot-sourced und nicht im selben Runspace.
Das Importskript beendet sich bei fehlendem ExifTool mit `exit 1`, und das würde den Dienst
mitreißen. `Invoke-Importskript` startet deshalb `powershell.exe` und liest dessen Ausgabe.
Der Exit-Code kommt sauber zurück, der Dienst überlebt (geprüft).

**Parametername und Wert müssen getrennt übergeben werden.** Ein Name in Anführungszeichen
ist für PowerShell kein Parameter, sondern ein Wert: `& skript.ps1 '-Inbox' 'C:\x'` bindet
`-Inbox` an den ersten Positionsparameter `-Gruppierung` und scheitert am `ValidateSet`.
Deshalb liefert `Get-LaufArgumente` Objekte mit `Name`/`Wert`/`IstSchalter`, und nur der Wert
wird gequotet. **Diese Falle ist gefährlicher, als sie aussieht:** kommen `-Inbox`,
`-Mediathek` und `-Protokolle` nicht an, fällt das Importskript still auf seine
Standardpfade zurück – also auf die echte Inbox und die echte Mediathek. Genau so entstand
am 2026-09-23 ein ungewollter echter Lauf gegen den Produktivordner. Wer an der
Argumentübergabe arbeitet, prüft zuerst im Protokoll, welche Pfade tatsächlich benutzt
wurden.

**stderr nebenher lesen.** Erst `StandardOutput.ReadToEnd()` und danach stderr blockiert den
Kindprozess, sobald dessen stderr-Puffer voll läuft. Der Dienst startet deshalb
`StandardError.ReadToEndAsync()`, bevor er stdout liest.

**Keine `Get-Content`-Ergebnisse in eine JSON-Antwort.** `Get-Content` hängt an jeden String
die Provider-Eigenschaften `PSPath`, `PSParentPath`, `PSChildName`, `PSDrive`, `PSProvider`
und `ReadCount`. `ConvertTo-Json` steigt in diesen Objektgraph ab und blieb im Dienst-Runspace
stehen, ohne Fehler und ohne Rückkehr – die Anfrage lief einfach in den Timeout. Dateien
werden deshalb mit `[System.IO.File]::ReadAllText()` gelesen, und die Antwort nutzt
`-Depth 4` statt 8. Das ist dieselbe Linie wie bei `Test-GleicheDatei`: rein lesende Zugriffe
über `System.IO`, nicht über die Provider-Cmdlets.

**Die Vorschau entsteht aus den `WhatIf:`-Zeilen**, wie im Abschnitt zu `-WhatIf` gefordert.
Geparst wird aber nicht der Satzbau: PowerShell 5.1 schreibt `WhatIf: Ausführen des Vorgangs
"…" für das Ziel "…"`, PowerShell 7 dagegen `What If: Der Vorgang „…" wird … ausgeführt` –
andere Wortstellung, andere Anführungszeichen. `Read-SkriptAusgabe` filtert stattdessen auf
`Verschieben nach` bzw. `Einsortieren nach` (Text aus unserem eigenen `ShouldProcess`-Aufruf)
und zieht die Windows-Pfade aus der Zeile: erster Treffer Ziel, zweiter Quelle. Die
`Set-Content`-Zeile des unterdrückten Protokolls fällt damit von selbst weg.

**Der Port steht nicht fest.** Der Dienst probiert ab `-Port` (Standard 8787) bis zu zwanzig
Ports aufwärts und nimmt den ersten freien; erst danach bricht er mit `exit 1` ab. Die
tatsächliche Adresse steht beim Start auf der Konsole. Wer den Dienst von außen anspricht,
darf 8787 deshalb nicht fest verdrahten – ein zweiter laufender Dienst sitzt auf 8788.

**Zugriffsschutz.** Der Dienst bindet nur an `http://127.0.0.1:<port>/` – das geht ohne
Adminrechte, eine URL-ACL ist nicht nötig (geprüft). Jeder API-Aufruf verlangt ein beim Start
erzeugtes Token, das in der Startadresse steht; ohne Token antwortet der Dienst mit 403.
Das ist kein Zierrat: Ein Formular-POST von einer beliebigen fremden Webseite an localhost
ist dem Browser nicht verboten, und `/api/import` verschiebt Dateien. Zusätzlich wird der
`Host`-Kopf gegen `127.0.0.1`/`localhost` geprüft (DNS-Rebinding), und `/api/protokoll`
akzeptiert nur Namen nach dem Muster `protokoll_<ziffern>.md`, damit darüber keine
beliebigen Dateien lesbar werden.

**Die Ordner kommen bei jeder Anfrage frisch aus der Datei.** Der Dienst friert sie nicht
beim Start ein, sonst würde eine Änderung über die Seite erst nach einem Neustart greifen.
`Get-AktuellePfade` liefert die Rangfolge Sitzungsvorgabe > Datei > Ordner neben dem Skript;
die Sitzungsvorgabe entsteht nur, wenn dem Dienst beim Start `-Inbox`, `-Mediathek` oder
`-Protokolle` mitgegeben wurde – dafür ist `$PfadUeberschreibung` da, und die Seite sperrt
die betroffenen Felder samt Begründung. Genau diese Pfade gibt `Get-LaufArgumente` auch an
den Motor weiter, damit Anzeige und Lauf nie auseinanderlaufen können.

Beim Speichern prüft `Set-EinstellungenObjekt` die Ordner: die Inbox muss existieren, bei
Mediathek und Protokolle reicht ein vorhandener Elternordner (den Rest legt der Motor an),
und Inbox und Mediathek dürfen weder derselbe Ordner sein noch ineinanderliegen. Schlägt eine Prüfung fehl, wird
gar nichts geschrieben; die Datei bleibt auf ihrem letzten gültigen Stand (geprüft).

**Die Oberfläche weigert sich, eine leere Dateityp-Liste zu speichern.** Nach dem oben
beschriebenen Verhalten von `"Erweiterungen": []` würde sie den Endungsfilter abschalten
statt nichts zu importieren – wer alle Haken entfernt, meint aber das Gegenteil. Die Prüfung
sitzt in `Set-EinstellungenObjekt` und zusätzlich in der Seite, damit der Knopf gar nicht
erst aktiv ist.

**Der Aufbau der Seite.** Oben ein Lageband: ein Satz zur Lage, darunter die drei
Kennzahlen, rechts die beiden Lauf-Knöpfe. Sie sitzen bewusst dort und nicht mehr im
Import-Reiter — der Riegel bleibt derselbe, `knopfImport` wird erst nach einer Vorschau
scharf (`vorschauGesehen`). Alle Element-Kennungen haben die Umgestaltung unverändert
überlebt; wer am Skriptteil arbeitet, kann sich weiter auf `lage`, `lagehinweis`,
`knopfVorschau`, `knopfImport`, `laufstatus` und `ortMediathek` verlassen. Symbole stecken
als Inline-SVG in der Seite, weil sie nichts von außen nachlädt. Der Hell/Dunkel-Knopf
stempelt `data-theme` auf `<html>` und merkt sich die Wahl in `localStorage`; ohne
gespeicherte Wahl gilt weiter die Systemeinstellung, und jede Farbe steht als Marke in
`:root`, damit beide Fassungen dieselben Regeln benutzen.

Vor jedem Überschreiben legt der Dienst `einstellungen.json.bak` an. Die Sicherung steht
nicht unter Versionskontrolle und ist damit die Rücknahme zwischen zwei Commits.
`ConvertTo-Json` maskiert unter PowerShell 5.1 Umlaute als `\uXXXX`; das wird
zurückgewandelt, damit die Datei von Hand lesbar bleibt.

Die API, alles tokenpflichtig außer `/`:

| Aufruf | Zweck |
|---|---|
| `GET /` | die Seite |
| `GET /api/lage` | Zählungen für Inbox und Mediathek, ExifTool vorhanden |
| `GET/POST /api/einstellungen` | `config\einstellungen.json` lesen und schreiben |
| `POST /api/vorschau` | Motor mit `-WhatIf`, liefert die geplanten Bewegungen |
| `POST /api/import` | echter Lauf, liefert Zusammenfassung und Protokollinhalt |
| `GET /api/protokolle` | die letzten 50 Protokolle |
| `GET /api/protokoll?name=` | ein Protokoll im Volltext |

Der Dienst bedient eine Anfrage nach der anderen. Das reicht für eine Oberfläche mit einem
Benutzer und hält den Code klein; ein Import blockiert währenddessen die Seite, was richtig
ist, weil zwei gleichzeitige Läufe auf derselben Inbox nichts Gutes ergäben.

## Installationsprogramm

`installer\` baut aus dem Projektordner eine einzelne `Setup.exe` (Inno Setup 6). Sie installiert
ins Benutzerprofil nach `%LOCALAPPDATA%\Programs\GoDigital Medienimport`, ohne Administratorrechte:
Das Programm schreibt Protokolle und Einstellungen in den eigenen Ordner, unter `C:\Programme`
dürfte es das nicht.

```powershell
.\installer\Baue-Setup.ps1                      # Version aus VERSION, ExifTool-Fassung frisch
.\installer\Baue-Setup.ps1 -OhneExifTool        # schneller, nutzt exiftool-fassung.txt weiter
.\installer\Baue-Setup.ps1 -ArchivDatei <zip>   # falls der SourceForge-Download klemmt
```

**ExifTool wird beim Installieren geladen, nicht mitgeliefert.** Das hält das Setup bei rund
einem Megabyte. Das Bauskript holt die Versionsnummer von `https://exiftool.org/ver.txt`, lädt
das Archiv von SourceForge – die einzige Quelle, `exiftool.org` liefert für die ZIP-Datei 404 –,
bildet die SHA256-Summe und schreibt alles nach `installer\exiftool-fassung.txt`. Diese Datei ist
versioniert: Aus ihr geht hervor, welche ExifTool-Fassung in einem Release steckt.

**Das Bauskript meldet sich mit einem eigenen User-Agent.** SourceForge schickt browserartigen
Clients eine HTML-Zwischenseite mit ablaufendem Mirror-Token statt der Datei; der Standardwert
von `Invoke-WebRequest` fällt darunter, mit einem echten Browser-Kennzeichen kommt sogar 403.
Nicht-browserartige Clients bekommen die Datei direkt – Inno Setup gehört dazu, der Installer
selbst war nie betroffen. Die Prüfung auf die ZIP-Kennung `PK` fängt den Fall trotzdem ab,
damit nie die Prüfsumme einer Fehlerseite in ein Release wandert.

**Geladen wird in `PrepareToInstall`, nicht auf einer eigenen Seite an `wpReady`.** Eine stille
Installation (`/VERYSILENT`) durchläuft keine Assistentenseiten; dort entstünde sonst eine
Installation ganz ohne ExifTool. Ein nicht leerer Rückgabewert dieser Funktion bricht sauber ab
– geprüft mit einer falschen Prüfsumme: Exitcode 7, kein Zielordner. Die Prüfsumme prüft
`DownloadTemporaryFile` selbst.

**Die Arbeit steckt in PowerShell, nicht in Pascal.** `Entpacke-ExifTool.ps1` und
`Schreibe-Einstellungen.ps1` laufen aus `{tmp}` (`Flags: dontcopy`) und sind einzeln auf der
Kommandozeile prüfbar. Im Pascal-Teil bleiben Seiten und Prüfungen. Jeder Pfad geht dabei in
Anführungszeichen an PowerShell: Zielordner und Medienordner dürfen Leerzeichen und Umlaute
tragen (geprüft mit einer Installation nach `…\Programs\Prüfordner`).

**Das Archiv wird durchsucht, nicht vorausgesetzt.** Die ausführbare Datei heißt
`exiftool(-k).exe`; das `-k` ließe sie nach jedem Aufruf auf einen Tastendruck warten, der
Import bliebe hängen. `Entpacke-ExifTool.ps1` sucht sie samt `exiftool_files` im entpackten
Baum, statt einen Ordnernamen anzunehmen, und benennt beim Kopieren um. Fehlt `exiftool_files`,
bricht es mit Code 1 und einer Begründung ab.

**Die `AppId` `{{89A23525-B7D0-45C9-BA38-83D6BF357836}` bleibt für immer gleich.** Ändert sie
sich, hält Windows ein Update für ein zweites Programm, und der Nutzer hat beides.

**Eine vorhandene `einstellungen.json` bleibt unangetastet** (Rückgabe 2 des Schreibskripts).
Die Schlussseite sagt es, sonst wunderte sich ein Nutzer, warum seine im Assistenten gewählten
Ordner nicht greifen.

**Die Ordnerprüfungen stehen in `installer\Ordnerpruefung.iss`** und werden per `#include` in den
`[Code]`-Abschnitt gezogen. Der Grund ist die Prüfbarkeit: Ein Assistent lässt sich nur von Hand
bedienen, dieselben Funktionen laufen so aber aus einem Wegwerf-Setup heraus gegen eine
Fallliste. Die Datei ist ASCII ohne BOM und kommentiert mit `//` – innerhalb von `[Code]` gilt
Pascal, ein `;`-Kommentar bricht den Compiler mit „BEGIN expected" ab.

Die Ordnerseite lehnt ab, dass Inbox und Mediathek derselbe Ordner sind **oder einer im
anderen liegt** – sonst läse der Import die Mediathek bei jedem Lauf noch einmal mit –, und sie
legt beide Ordner probeweise an, damit ein fehlendes Laufwerk hier auffällt und nicht erst beim
ersten Import. Dieselbe Verschachtelungsregel steckt in `Set-EinstellungenObjekt` der
Weboberfläche (`Test-LiegtInnerhalb`): Was der Assistent verbietet, darf die Seite nicht
hinterher wieder erlauben. Wer eine der beiden Stellen ändert, ändert beide.

**Vorbelegt wird `{%USERPROFILE}\Pictures`, nicht der Bilderordner der Shell.** Den biegt OneDrive
auf einen Synchronisationsordner um (auf dem Entwicklungsrechner `…\OneDrive\Bilder 1`), und eine
Mediathek mit mehreren Gigabyte gehört nicht ungefragt in die Cloud. Eine Konstante `{userpics}`
kennt Inno Setup ohnehin nicht – sie führt zu einem Laufzeitfehler, der die Installation
vollständig abbricht.

Die `.iss` ist **UTF-8 mit BOM**, wie die Skripte: Ohne BOM zeigt der Assistent zerlegte Umlaute.

## Code-Konventionen

- Das Skript ist **UTF-8 mit BOM**. Das BOM ist Pflicht, sonst liest Windows PowerShell 5.1
  die Umlaute als ANSI. Beim Bearbeiten unbedingt beibehalten.
- Ausgaben und Hilfetext dürfen echte Umlaute enthalten. Beide `.cmd`-Starter setzen
  `chcp 65001`, die Anzeige stimmt damit unter Windows PowerShell 5.1 (geprüft). Ein Aufruf
  ohne `chcp`, etwa über das Bash-Werkzeug, zeigt die Umlaute zerlegt. Das ist die Konsole,
  nicht das Skript, und kein Grund, an der Ausgabe zu ändern.
- Das Protokoll entsteht mit `Set-Content -Encoding UTF8`. Unter Windows PowerShell 5.1
  ergibt das UTF-8 **mit** BOM, unter PowerShell 7 ohne (geprüft). Wer die Protokolle
  maschinell liest, muss beides vertragen.
- **Bezeichner, Parameter und Dateinamen bleiben ASCII** (`$uebersprungen`, `-Praefix`,
  `-Gruppierung`). Nur Text, den jemand liest, bekommt Umlaute. Ein Parametername mit
  Umlaut wäre auf der Kommandozeile umständlich.
- Bezeichner, Parameter und Ausgaben sind deutsch. Neue Parameter genauso benennen.

## Der Prozess (Regeln)

1. Neue Dateien kommen ausschließlich in `inbox\`.
2. Verarbeitet wird per Doppelklick auf `Medien importieren.cmd` oder über die
   PowerShell-Aufrufe oben.
3. Jede Datei wird in einem Schritt umbenannt und nach `mediathek\` verschoben.
4. **Niemals überschreiben:** Bei belegtem Zielnamen entscheidet der Inhaltsvergleich
   zwischen Dublette (`SKIP`) und Zähler-Suffix (`OK`). Dateien, die bereits einen
   Datumsvorsatz tragen, behalten ihn, damit eine zurückgelegte Datei denselben
   Zielnamen ergibt und als Dublette erkannt wird.
5. Unterordner der Inbox werden zu `mediathek\Ereignisse\<Name>\`. `-Ereignis` schlägt
   den Unterordnernamen.
6. Nur Dateitypen aus `-Erweiterungen` werden angefasst; `-AlleDateien` schaltet den
   Filter ab. Zusätzlich übergeht ExifTool beim Ordnerdurchlauf `Thumbs.db` und
   `desktop.ini` von sich aus; sie erreichen das Skript also gar nicht, auch mit
   `-AlleDateien` nicht (geprüft). Nicht übergangen werden Typen, die ExifTool kennt,
   ohne dass sie Medien sind: `.txt`, `.xmp`, `.pdf` und ähnliche tauchen in der Ausgabe
   auf. Der Endungsfilter ist der einzige Schutz davor, dass `-AlleDateien` Textdateien
   und XMP-Beidateien in die Mediathek zieht.
7. Dateien ohne jedes ermittelbare Datum werden übersprungen und protokolliert.
8. Nach jedem echten Lauf entsteht automatisch ein Protokoll in `protokolle\`.

## Namenskonvention

`<AufnahmeDatum>_<Originalname>` im Format `yyyyMMdd_HHmmss_<Name>.ext`.

| Ablage | Beispiel |
|---|---|
| Datumsbaum (`JahrMonat`) | `mediathek\2026\2026-09\20260910_101530_IMG_1001.JPG` |
| `Jahr` | `mediathek\2026\20260910_101530_IMG_1001.JPG` |
| `Tag` | `mediathek\2026-09-10\20260910_101530_IMG_1001.JPG` |
| `Keine` | `mediathek\20260910_101530_IMG_1001.JPG` |
| Ereignis | `mediathek\Ereignisse\2026-09_Urlaub Italien\20260910_101530_IMG_1001.JPG` |
| Namenskonflikt | `…\20260910_101530_IMG_1001_1.JPG` |

## Regeln für Claude in diesem Ordner

- Vor einem echten Lauf bei Unsicherheit erst `-WhatIf` zeigen.
- Die Mediathek ist die Wahrheit: Dateien dort nicht umbenennen oder löschen ohne
  ausdrückliche Aufforderung. Das gilt besonders für `-Reorganisieren`, das leere Ordner
  wirklich löscht.
- Destruktive Aktionen immer vorher bestätigen lassen.
- Nach jedem Verarbeitungslauf die Protokoll-Zusammenfassung nennen und auf die
  Protokolldatei verlinken.
- Änderungen am Skript zuerst mit eigenen `-Inbox`/`-Mediathek`-Pfaden im Scratchpad
  prüfen, nicht an der echten Mediathek. Es gibt keine automatisierten Tests.
- Git trägt die Historie, aber nur so weit sie eingecheckt ist: vor einem größeren Eingriff
  `git status` ansehen und einen ungesicherten Stand erst committen. Geht das nicht, eine
  Kopie als `Importiere-Medien.ps1.bak-<zeitstempel>` ablegen – solche Kopien ignoriert Git.
- Beim Testen mit eigenen Pfaden **immer alle drei** angeben (`-Inbox`, `-Mediathek`,
  `-Protokolle`) und danach im Protokollkopf nachsehen, ob sie auch angekommen sind. Ein
  falsch gebauter Aufruf fällt ohne Fehlermeldung auf die echten Ordner zurück – so ist
  schon ein ungewollter Lauf gegen die Produktivmediathek entstanden.
- **Immer auch unter Windows PowerShell 5.1 testen** (`powershell.exe`, nicht nur `pwsh`).
  Die `.cmd`-Starter rufen 5.1 auf, und es verhält sich bei `-WhatIf`, Encoding und
  .NET-Methoden anders als PowerShell 7.
- Ändert sich das Verhalten, `ANLEITUNG.md` mitziehen. Sie ist die Nutzerdoku und
  beschreibt dieselben Abläufe in nicht-technischer Sprache; sie darf nicht auseinanderlaufen.
- Dasselbe gilt für die bebilderte Anleitung in `protokolle\`. Geändert wird die
  HTML-Quelle, daraus entsteht das PDF neu; das PDF selbst lässt sich nicht bearbeiten.
  Stil und Aufbau stehen in `DOKU-STIL.md`:

  ```bash
  chrome.exe --headless=new --disable-gpu --no-pdf-header-footer \
    --print-to-pdf="GoDigital-Medienimport_Anleitung-bebildert.pdf" \
    "file:///E:/GoDigital Medienimport/protokolle/GoDigital-Medienimport_Anleitung-bebildert.html"
  ```

  Danach das PDF seitenweise rendern und ansehen (`pypdfium2`), sonst fallen abgeschnittene
  SVG-Beschriftungen und halb leere Seiten erst beim Leser auf. Der Umbruch ist eingestellt,
  nicht zufällig: Jede Zeichnung steht mit ihrer Bildunterschrift zusammen, und der
  Spickzettel bekommt als einziger Abschnitt einen erzwungenen Seitenumbruch.
- `E:\Drohne-Foto-Workflow` nicht anfassen. Getrenntes, eingefrorenes Projekt.

## Voraussetzungen

- **ExifTool.** Gesucht wird in dieser Reihenfolge: `-ExifToolPath`, Einstellungsdatei,
  `exiftool\exiftool.exe` neben dem Programm (so liefert das Setup es aus), Suchpfad, zuletzt
  `E:\Exiftool\exiftool.exe` als historischer Wert dieses Rechners. Keine Versionsprüfung.
  Nur im Inbox-Modus nötig.
- **PowerShell** 5.1 oder 7+.

## Geplant

Weboberfläche und Installationsprogramm sind gebaut, siehe oben. Was offen bleibt: Die
Oberfläche zeigt die Vorschau je Datei, kann aber keine einzelnen Dateien abwählen – der Lauf
ist alles oder nichts. Ein `-Reorganisieren` lässt sich über die Seite anstoßen, die Vorschau
dafür zeigt bislang dieselbe Tabelle wie ein Import. Das Setup trägt keine Signatur,
SmartScreen meldet sich deshalb bei jedem Nutzer einmal; ein Code-Signing-Zertifikat kostet
Geld und ist nicht beschafft.

Für jede Erweiterung gilt weiter: Das Importskript bleibt der Motor und muss eigenständig
per Doppelklick funktionsfähig bleiben. Jede neue Einstellung gehört in die JSON-Datei und
nicht in fest verdrahtete Werte, sonst kennt der Doppelklick-Betrieb sie nicht.
