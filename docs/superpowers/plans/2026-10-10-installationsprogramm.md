# Installationsprogramm – Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Ziel:** Eine einzelne `Setup.exe`, mit der ein Nutzer ohne IT-Kenntnisse GoDigital Medienimport samt ExifTool, Ordnern, Verknüpfungen und passender Einstellungsdatei installiert.

**Aufbau:** Das neue Teilsystem `installer\` baut mit Inno Setup 6 eine `Setup.exe`, die ins Benutzerprofil installiert und ExifTool beim Installieren von SourceForge lädt. Die Arbeit, die Logik braucht – Archiv entpacken, Einstellungsdatei schreiben –, liegt in zwei eigenständigen PowerShell-Skripten, die der Installer aufruft; im Pascal-Teil bleiben nur Assistentenseiten und Prüfungen. Davor stehen drei Korrekturen am bestehenden Motor, ohne die auf einem fremden Rechner nichts läuft.

**Technik:** Inno Setup 6 (Pascal Script, ISPP), Windows PowerShell 5.1, Git.

**Spec:** `docs/superpowers/specs/2026-10-03-installationsprogramm-design.md`

## Globale Randbedingungen

- Zielordner der Installation: `%LOCALAPPDATA%\Programs\GoDigital Medienimport`, `PrivilegesRequired=lowest`.
- Compiler: Inno Setup 6.1 oder neuer. Auf dem Entwicklungs-PC liegt 6.7.3 unter `%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe`. Das Bauskript sucht ihn dort und in beiden Programmordnern, statt den Pfad fest zu verdrahten.
- Der Assistent ist deutsch (`compiler:Languages\German.isl`).
- ExifTool wird nicht mitgeliefert, sondern beim Installieren geladen. Quelle ist ausschließlich `https://sourceforge.net/projects/exiftool/files/exiftool-<ver>_64.zip/download`; Version und SHA256 werden beim Bauen festgelegt.
- Herausgeber: `Martin Goßner GoDigital`. Lizenz: MIT.
- Die Versionsnummer steht ausschließlich in `VERSION`. Das Bauskript liest sie von dort und reicht sie als `/DAppVersion` an den Compiler.
- Alle PowerShell-Dateien sind **UTF-8 mit BOM**, die `.iss` ebenfalls (Inno Setup 6 liest sonst die Umlaute als ANSI). Bezeichner, Parameter und Dateinamen bleiben ASCII, nur gelesener Text bekommt Umlaute.
- Geprüft wird unter **Windows PowerShell 5.1** (`powershell.exe`), nicht unter `pwsh`.
- Jeder Testlauf des Importskripts bekommt **alle drei** Ordner mit (`-Inbox`, `-Mediathek`, `-Protokolle`) und dazu `-EinstellungsDatei` auf eine nicht vorhandene Datei. Danach im Protokollkopf nachsehen, ob die Pfade angekommen sind. Ein falsch gebauter Aufruf fällt ohne Fehlermeldung auf die echte Mediathek zurück.
- Die echte Mediathek unter `E:\GoDigital Medienimport\mediathek` wird nicht angefasst. `E:\Drohne-Foto-Workflow` ebenfalls nicht.
- Jede Commit-Nachricht endet mit `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.
- Automatisierte Tests gibt es im Projekt nicht. Jeder Prüfschritt unten ist ein Befehl mit einer erwarteten Ausgabe; „bestanden" heißt, die Ausgabe wurde gelesen.

## Prüfschwerpunkte

Fünf Fälle, die die Spec voraussetzt, ohne sie zu beschreiben. Jeder hat unten in der zuständigen Task einen Prüfschritt:

1. **Die Inbox liegt innerhalb der Mediathek** (oder umgekehrt). Die Spec prüft nur auf „derselbe Ordner". Liegt die Inbox darin, liest der Import sie bei jedem Lauf mit und sortiert die Mediathek in sich selbst um. Erwartung: Der Assistent lehnt die Kombination ab. → Task 7.
2. **Pfade mit Leerzeichen und Umlauten.** Der Installer ruft PowerShell aus Pascal heraus auf; ein ungequoteter Pfad bricht genau dort. Erwartung: Installation nach `D:\Prüfordner für Bilder\…` funktioniert. → Task 8 und Task 9.
3. **Das ExifTool-Archiv hat einen anderen Aufbau** als erwartet (keine `exiftool(-k).exe`, kein Oberordner). Erwartung: Das Entpackskript sucht die Datei, statt den Aufbau vorauszusetzen, und meldet verständlich, wenn sie fehlt. → Task 8.
4. **Leerer `ExifToolPath` in der Einstellungsdatei.** Die neue Vorlage trägt genau das, und `Get-Einstellung` liefert einen leeren String durch. Erwartung: Der Standard greift, nicht der leere Wert. → Task 2 und Task 3.
5. **Der gewählte Mediathek-Ordner lässt sich nicht anlegen** (fehlendes Laufwerk `Z:\Fotos`, schreibgeschützter Pfad). Erwartung: Die Ordnerseite hält an, statt die Installation später mit halber Einrichtung enden zu lassen. → Task 7.

---

## Dateiübersicht

Neu:

| Datei | Verantwortung |
|---|---|
| `VERSION` | Eine Zeile, die Versionsnummer. Einzige Quelle. |
| `LICENSE` | MIT, Inhaber Martin Goßner. |
| `README.md` | Einstieg auf GitHub: Downloadlink, Voraussetzungen, SmartScreen. |
| `config\einstellungen.vorlage.json` | Alle zehn Schlüssel, Ordner und ExifTool-Pfad leer. |
| `installer\GoDigital-Medienimport.iss` | Beschreibung des Setups: Seiten, Dateien, Verknüpfungen, Deinstallation. |
| `installer\Baue-Setup.ps1` | Bauskript: Version lesen, ExifTool-Fassung bestimmen, Compiler rufen. |
| `installer\Entpacke-ExifTool.ps1` | Archiv entpacken, `exiftool(-k).exe` umbenennen, `exiftool_files` mitnehmen. |
| `installer\Schreibe-Einstellungen.ps1` | Einstellungsdatei aus der Vorlage erzeugen, vorhandene nicht anfassen. |
| `installer\exiftool-fassung.txt` | Beim Bauen geschrieben: Version, Dateiname, URL, SHA256. |
| `installer\liesmich.md` | Wie man das Setup baut. Für den Entwickler, nicht für den Nutzer. |

Geändert:

| Datei | Änderung |
|---|---|
| `scripts\Importiere-Medien.ps1` | Programmversion und ExifTool-Pfad ins Protokoll, Rückfallkette für ExifTool. |
| `scripts\Starte-Weboberflaeche.ps1` | Dieselbe Rückfallkette an zwei Stellen. |
| `.gitignore` | `config/einstellungen.json`, `installer/ausgabe/`. |
| `CLAUDE.md`, `ANLEITUNG.md`, `protokolle\…Anleitung-bebildert.html` + `.pdf` | Dokumentation nachziehen. |

Die beiden Hilfsskripte im Installer sind Absicht: Pascal Script hat keine Tests und lässt sich nur durch Anklicken prüfen. Was in einer `.ps1` steht, läuft einzeln auf der Kommandozeile und ist damit prüfbar.

---

### Task 1: Programmversion und ExifTool-Pfad im Protokollkopf

Der Protokollkopf ist die einzige Stelle, an der sich von außen ablesen lässt, mit welchen Werten ein Lauf tatsächlich gearbeitet hat. Die Tasks 2 und 3 prüfen ihre Rückfallkette darüber, deshalb steht diese Task vorn.

**Dateien:**
- Neu: `VERSION`
- Ändern: `scripts/Importiere-Medien.ps1` (nach Zeile 93 `$start = Get-Date`; Protokollkopf ab Zeile 483)

**Schnittstellen:**
- Liefert: Datei `VERSION` mit einer Zeile `1.0.0` (von Task 6 gelesen); Variable `$Programmversion`; die Protokollzeilen `- **Programmversion:**` und `- **ExifTool:**`, auf die die Prüfschritte der Tasks 2, 3 und 11 sich stützen.

- [ ] **Schritt 1: `VERSION` anlegen**

```powershell
Set-Content -LiteralPath ".\VERSION" -Value "1.0.0" -Encoding ASCII -NoNewline
```

- [ ] **Schritt 2: Version im Importskript lesen**

In `scripts/Importiere-Medien.ps1` direkt **nach** der Zeile `$start = Get-Date` einfügen:

```powershell

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
```

- [ ] **Schritt 3: Protokollkopf erweitern**

In `scripts/Importiere-Medien.ps1` die Zeile

```powershell
[void]$md.AppendLine("- **Ende:**  $($ende.ToString('yyyy-MM-dd HH:mm:ss'))")
```

ersetzen durch:

```powershell
[void]$md.AppendLine("- **Ende:**  $($ende.ToString('yyyy-MM-dd HH:mm:ss'))")
[void]$md.AppendLine("- **Programmversion:** $Programmversion")
[void]$md.AppendLine("- **ExifTool:** ``$ExifToolPath``")
```

- [ ] **Schritt 4: Echten Lauf gegen Wegwerf-Ordner ausführen**

```powershell
$t = "$env:TEMP\gdmi-t1"
Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "$t\inbox","$t\ziel","$t\log" -Force | Out-Null
"x" > "$t\inbox\IMG_0001.JPG"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Importiere-Medien.ps1" `
  -Inbox "$t\inbox" -Mediathek "$t\ziel" -Protokolle "$t\log" -EinstellungsDatei "$t\keine.json"
```

- [ ] **Schritt 5: Protokollkopf lesen**

```powershell
Get-Content (Get-ChildItem "$t\log\protokoll_*.md" | Select-Object -Last 1).FullName -TotalCount 12
```

Erwartet: Der Kopf nennt `- **Programmversion:** 1.0.0`, `- **ExifTool:** `E:\Exiftool\exiftool.exe``, als Inbox und Mediathek die Ordner unter `$t` und als Einstellungen `(keine, Standardwerte)`. Steht dort ein Pfad unter `E:\GoDigital Medienimport`, ist der Aufruf falsch gebaut – nicht weitermachen, bis der Kopf stimmt.

- [ ] **Schritt 6: Commit**

```bash
git add VERSION scripts/Importiere-Medien.ps1
git commit -m "Programmversion und ExifTool-Pfad im Protokollkopf" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Rückfallkette für ExifTool im Importskript

`E:\Exiftool\exiftool.exe` steht fest verdrahtet in Zeile 102. Auf einem fremden Rechner gibt es diesen Pfad nicht. Neue Reihenfolge: Parameter, dann Einstellungsdatei, dann `exiftool\exiftool.exe` neben dem Programm, dann der Suchpfad, zuletzt der bisherige Wert. Die bestehende Installation auf `E:` läuft unverändert weiter, weil ihre Einstellungsdatei den Pfad ohnehin setzt.

**Dateien:**
- Ändern: `scripts/Importiere-Medien.ps1:102` und `:175-177`

**Schnittstellen:**
- Nutzt: `$Root` (Zeile 92), die Protokollzeile `- **ExifTool:**` aus Task 1.
- Liefert: Funktion `Get-ExifToolStandard -ProgrammWurzel <pfad>` → `[string]`. Task 3 baut dieselbe Funktion wortgleich in den Webdienst ein.

- [ ] **Schritt 1: Prüfbaum anlegen und den Fehlstand belegen**

```powershell
$p = "$env:TEMP\gdmi-prog"
$t = "$env:TEMP\gdmi-t2"
Remove-Item $p,$t -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "$p\scripts","$p\exiftool","$t\inbox","$t\ziel","$t\log" -Force | Out-Null
Copy-Item ".\scripts\Importiere-Medien.ps1" "$p\scripts\"
Copy-Item ".\VERSION" "$p\"
Copy-Item "E:\Exiftool\exiftool.exe" "$p\exiftool\"
Copy-Item "E:\Exiftool\exiftool_files" "$p\exiftool\" -Recurse
"x" > "$t\inbox\IMG_0001.JPG"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$p\scripts\Importiere-Medien.ps1" `
  -Inbox "$t\inbox" -Mediathek "$t\ziel" -Protokolle "$t\log" -EinstellungsDatei "$t\keine.json"
Get-Content (Get-ChildItem "$t\log\protokoll_*.md" | Select-Object -Last 1).FullName -TotalCount 12
```

Erwartet: Der Kopf nennt `E:\Exiftool\exiftool.exe`, obwohl `$p\exiftool\exiftool.exe` danebenliegt. Genau das ist der Fehlstand.

- [ ] **Schritt 2: Rückfallkette einbauen**

In `scripts/Importiere-Medien.ps1` die Zeile

```powershell
$standardExifTool = "E:\Exiftool\exiftool.exe"
```

ersetzen durch:

```powershell
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
```

- [ ] **Schritt 3: Leeren Wert aus der Einstellungsdatei abfangen**

`Get-Einstellung` prüft auf `$null -ne $wert`; ein leerer String kommt also durch. Die neue Vorlage aus Task 4 trägt genau das, und über die Weboberfläche lässt sich das Feld ebenfalls leeren. Ohne diese Zeile bricht der Lauf mit „ExifTool nicht gefunden: " ohne Pfad ab.

In `scripts/Importiere-Medien.ps1` den Block

```powershell
if (-not $PSBoundParameters.ContainsKey('ExifToolPath')) {
    $ExifToolPath = [string](Get-Einstellung $konfig 'ExifToolPath' $standardExifTool)
}
```

ersetzen durch:

```powershell
if (-not $PSBoundParameters.ContainsKey('ExifToolPath')) {
    $ExifToolPath = [string](Get-Einstellung $konfig 'ExifToolPath' $standardExifTool)
    # Ein leerer Wert in der Datei zaehlt wie ein fehlender: die mitgelieferte
    # Vorlage traegt hier nichts ein, und ueber die Seite laesst sich das Feld
    # leeren. Sonst stuende im Fehlertext ein leerer Pfad.
    if (-not $ExifToolPath) { $ExifToolPath = $standardExifTool }
}
```

- [ ] **Schritt 4: Fall „neben dem Programm" prüfen**

```powershell
Copy-Item ".\scripts\Importiere-Medien.ps1" "$p\scripts\" -Force
Remove-Item "$t\log\*","$t\ziel\*" -Recurse -Force
"x" > "$t\inbox\IMG_0002.JPG"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$p\scripts\Importiere-Medien.ps1" `
  -Inbox "$t\inbox" -Mediathek "$t\ziel" -Protokolle "$t\log" -EinstellungsDatei "$t\keine.json"
Get-Content (Get-ChildItem "$t\log\protokoll_*.md" | Select-Object -Last 1).FullName -TotalCount 12
```

Erwartet: `- **ExifTool:** `C:\...\gdmi-prog\exiftool\exiftool.exe``, und die Datei ist nach `$t\ziel` gewandert (`Verschoben: 1`).

- [ ] **Schritt 5: Fall „Suchpfad" prüfen**

```powershell
$q = "$env:TEMP\gdmi-pfad"
Remove-Item $q -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $q -Force | Out-Null
Copy-Item "E:\Exiftool\exiftool.exe" $q
Copy-Item "E:\Exiftool\exiftool_files" $q -Recurse
Remove-Item "$p\exiftool" -Recurse -Force
$env:PATH = "$q;$env:PATH"
Remove-Item "$t\log\*" -Recurse -Force
"x" > "$t\inbox\IMG_0003.JPG"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$p\scripts\Importiere-Medien.ps1" `
  -Inbox "$t\inbox" -Mediathek "$t\ziel" -Protokolle "$t\log" -EinstellungsDatei "$t\keine.json"
Get-Content (Get-ChildItem "$t\log\protokoll_*.md" | Select-Object -Last 1).FullName -TotalCount 12
```

Erwartet: `- **ExifTool:** `C:\...\gdmi-pfad\exiftool.exe``.

- [ ] **Schritt 6: Fall „leerer Wert in der Datei" prüfen (Prüfschwerpunkt 4)**

```powershell
'{ "ExifToolPath": "" }' | Set-Content -LiteralPath "$t\leer.json" -Encoding UTF8
Remove-Item "$t\log\*" -Recurse -Force
"x" > "$t\inbox\IMG_0004.JPG"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$p\scripts\Importiere-Medien.ps1" `
  -Inbox "$t\inbox" -Mediathek "$t\ziel" -Protokolle "$t\log" -EinstellungsDatei "$t\leer.json"
Get-Content (Get-ChildItem "$t\log\protokoll_*.md" | Select-Object -Last 1).FullName -TotalCount 12
```

Erwartet: Der Lauf bricht **nicht** ab, der Kopf nennt den Pfad aus dem Suchpfad (`$q\exiftool.exe`), und `- **Einstellungen:**` zeigt `$t\leer.json`.

- [ ] **Schritt 7: Commit**

```bash
git add scripts/Importiere-Medien.ps1
git commit -m "ExifTool: Rueckfallkette statt festem E-Pfad" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Rückfallkette im Webdienst

Derselbe feste Pfad steht zweimal in `Starte-Weboberflaeche.ps1`: als Vorbelegung der Einstellungsseite (Zeile 286) und in der Lageanzeige (Zeile 388). Die Funktion wird kopiert, nicht geteilt – genau wie `$standardErweiterungen`, das in beiden Skripten steht. Der Motor darf nichts vom Dienst wissen und der Dienst nichts vom Motor außer dem Aufruf.

**Dateien:**
- Ändern: `scripts/Starte-Weboberflaeche.ps1` (nach Zeile 88, dann `:286`, `:290-297`, `:388-391`)

**Schnittstellen:**
- Nutzt: `Get-ExifToolStandard` aus Task 2, wortgleich übernommen; `$Root` (Zeile 60).
- Liefert: Variable `$standardExifTool` im Dienst-Runspace.

- [ ] **Schritt 1: Funktion einsetzen**

In `scripts/Starte-Weboberflaeche.ps1` direkt **nach** dem Block `$standardErweiterungen = @( … )` einfügen:

```powershell

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
```

- [ ] **Schritt 2: Vorbelegung der Einstellungsseite**

In `Get-EinstellungenObjekt` die Zeile

```powershell
        ExifToolPath             = "E:\Exiftool\exiftool.exe"
```

ersetzen durch:

```powershell
        ExifToolPath             = $standardExifTool
```

- [ ] **Schritt 3: Leeren Wert aus der Datei abfangen (Prüfschwerpunkt 4)**

In `Get-EinstellungenObjekt` **nach** der `foreach`-Schleife über die Schlüsselnamen und **vor** dem `return` einfügen:

```powershell
    # Ein leerer ExifTool-Pfad steht so in der mitgelieferten Vorlage. Er darf den
    # Standard nicht verdraengen, sonst zeigt die Seite ein leeres Feld an und der
    # Nutzer muesste einen Pfad eintragen, den das Setup laengst eingerichtet hat.
    if (-not [string]$werte['ExifToolPath']) { $werte['ExifToolPath'] = $standardExifTool }
```

- [ ] **Schritt 4: Lageanzeige**

In `Get-Lage` die Zeile

```powershell
    $exif  = "E:\Exiftool\exiftool.exe"
```

ersetzen durch:

```powershell
    $exif  = $standardExifTool
```

- [ ] **Schritt 5: Dienst gegen Wegwerf-Ordner starten**

```powershell
$p = "$env:TEMP\gdmi-prog"
$t = "$env:TEMP\gdmi-t3"
Remove-Item $p,$t -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "$p\scripts","$p\web","$p\exiftool","$t\inbox","$t\ziel","$t\log" -Force | Out-Null
Copy-Item ".\scripts\*.ps1" "$p\scripts\"
Copy-Item ".\web\index.html" "$p\web\"
Copy-Item ".\VERSION" "$p\"
Copy-Item "E:\Exiftool\exiftool.exe" "$p\exiftool\"
Copy-Item "E:\Exiftool\exiftool_files" "$p\exiftool\" -Recurse
$dienst = Start-Process powershell.exe -PassThru -RedirectStandardOutput "$t\dienst.log" -ArgumentList `
  '-NoProfile','-ExecutionPolicy','Bypass','-File',"$p\scripts\Starte-Weboberflaeche.ps1",
  '-OhneBrowser','-Port','8899','-EinstellungsDatei',"$t\keine.json",
  '-Inbox',"$t\inbox",'-Mediathek',"$t\ziel",'-Protokolle',"$t\log"
```

- [ ] **Schritt 6: Antworten prüfen**

```powershell
$zeile = (Select-String -Path "$t\dienst.log" -Pattern 'Adresse: (\S+)').Matches[0].Groups[1].Value
$port  = ([uri]$zeile).Port
$token = ([uri]$zeile).Query.Substring(3)
$kopf  = @{ 'X-Token' = $token }
(Invoke-RestMethod "http://127.0.0.1:$port/api/einstellungen" -Headers $kopf).werte.ExifToolPath
(Invoke-RestMethod "http://127.0.0.1:$port/api/lage" -Headers $kopf) | Select-Object exifToolDa, exifToolPfad
Stop-Process -Id $dienst.Id -Force
```

Erwartet: Beide Aufrufe nennen `C:\...\gdmi-prog\exiftool\exiftool.exe`. Antwortet der Dienst gar nicht, zuerst `$t\dienst.log` lesen – ein Startfehler steht dort. (Heißen die Felder der Lage anders, die Namen aus `Get-Lage` übernehmen; geprüft wird der Pfad, nicht der Feldname.)

- [ ] **Schritt 7: Commit**

```bash
git add scripts/Starte-Weboberflaeche.ps1
git commit -m "Weboberflaeche: ExifTool-Rueckfallkette uebernommen" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Einstellungsdatei entversionieren, Vorlage anlegen

`config\einstellungen.json` trägt vier absolute `E:`-Pfade und greift vor den eingebauten Standardwerten. Jeder Klon und jedes Setup lieferte diese Pfade mit aus und zeigte damit ins Leere. Die Datei verlässt das Repository, die lokale bleibt liegen, an ihre Stelle tritt eine Vorlage.

**Dateien:**
- Neu: `config/einstellungen.vorlage.json`
- Ändern: `.gitignore`
- Aus der Versionierung nehmen: `config/einstellungen.json`

**Schnittstellen:**
- Liefert: `config/einstellungen.vorlage.json` mit allen zehn Schlüsseln. Task 6 installiert sie, Task 9 liest sie als Grundlage der erzeugten Einstellungsdatei.

- [ ] **Schritt 1: Ausgangsstand sichern**

```powershell
git status --short
Copy-Item ".\config\einstellungen.json" "$env:TEMP\einstellungen.json.vorTask4"
```

Erwartet: `git status` meldet nichts Offenes. Meldet es etwas, erst committen.

- [ ] **Schritt 2: Vorlage anlegen**

Neue Datei `config/einstellungen.vorlage.json`:

```json
{
    "Inbox":  "",
    "Mediathek":  "",
    "Protokolle":  "",
    "Gruppierung":  "JahrMonat",
    "Praefix":  "",
    "Erweiterungen":  [
                          "jpg",
                          "jpeg",
                          "heic",
                          "heif",
                          "png",
                          "tif",
                          "tiff",
                          "dng",
                          "raw",
                          "cr2",
                          "cr3",
                          "nef",
                          "arw",
                          "orf",
                          "rw2",
                          "mp4",
                          "mov",
                          "avi",
                          "mts",
                          "m2ts",
                          "m4v",
                          "mkv"
                      ],
    "UnterordnerAlsEreignisse":  true,
    "EreignisOrdnerName":  "Ereignisse",
    "ExifToolPath":  "",
    "VideoZeitAlsOrtszeit":  true
}
```

Die leeren Ordnerangaben sind kein Versehen: `Get-Ordnerpfad` wertet einen leeren Wert wie einen fehlenden und nimmt die Ordner neben dem Skript. Die Vorlage ist damit auch ohne Installer brauchbar.

- [ ] **Schritt 3: `.gitignore` ergänzen**

Ans Ende von `.gitignore` anfügen:

```gitignore

# Die eigene Einstellungsdatei gehoert zum Rechner, nicht ins Repository: sie
# traegt absolute Pfade und greift vor den eingebauten Standardwerten. Versioniert
# ist nur die Vorlage daneben.
config/einstellungen.json

# Das gebaute Setup.
installer/ausgabe/
```

`installer/exiftool-fassung.txt` wird bewusst **nicht** ignoriert: Aus ihr geht hervor, welche ExifTool-Fassung in einem Release steckt.

- [ ] **Schritt 4: Datei aus dem Index nehmen**

```bash
git rm --cached config/einstellungen.json
git status --short
```

Erwartet: `D  config/einstellungen.json`, dazu die neuen Dateien als `??` bzw. `A`. Die lokale Datei muss weiter existieren:

```powershell
Test-Path ".\config\einstellungen.json"
```

Erwartet: `True`.

- [ ] **Schritt 5: Prüfen, dass der Doppelklick-Betrieb unberührt bleibt**

```powershell
$t = "$env:TEMP\gdmi-t4"
Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "$t\inbox","$t\ziel","$t\log" -Force | Out-Null
"x" > "$t\inbox\IMG_0001.JPG"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Importiere-Medien.ps1" `
  -Inbox "$t\inbox" -Mediathek "$t\ziel" -Protokolle "$t\log" -WhatIf
```

Erwartet: Die Vorschau läuft, die `WhatIf:`-Zeilen zeigen das Verschieben nach `$t\ziel`. Die echte `config\einstellungen.json` liegt noch an ihrem Platz und wird weiter gelesen.

- [ ] **Schritt 6: Vorlage gegenprüfen**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Importiere-Medien.ps1" `
  -Inbox "$t\inbox" -Mediathek "$t\ziel" -Protokolle "$t\log" `
  -EinstellungsDatei ".\config\einstellungen.vorlage.json"
Get-Content (Get-ChildItem "$t\log\protokoll_*.md" | Select-Object -Last 1).FullName -TotalCount 12
```

Erwartet: Kein Abbruch, kein `WARNUNG: Einstellungsdatei unlesbar`, der Kopf nennt die Ordner unter `$t` und als ExifTool den Wert aus der Rückfallkette.

- [ ] **Schritt 7: Commit**

```bash
git add .gitignore config/einstellungen.vorlage.json
git commit -m "Einstellungsdatei aus der Versionierung, Vorlage daneben" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: LICENSE und README.md

**Dateien:**
- Neu: `LICENSE`, `README.md`

**Schnittstellen:**
- Liefert: `LICENSE` – von Task 6 als `LicenseFile` in den Assistenten eingebunden und nach `{app}` installiert.

- [ ] **Schritt 1: `LICENSE` anlegen**

```
MIT License

Copyright (c) 2026 Martin Goßner

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Schritt 2: `README.md` anlegen**

```markdown
# GoDigital Medienimport

Fotos und Videos nach ihrem Aufnahmedatum umbenennen und in eine chronologisch
sortierte Mediathek einsortieren. Für Windows.

## Installieren

1. [Setup herunterladen](https://github.com/martingodigital/godigital-medienimport/releases/latest)
2. Die heruntergeladene Datei starten.
3. Windows zeigt beim ersten Start den blauen Hinweis „Der Computer wurde durch
   Windows geschützt". Auf **Weitere Informationen** klicken, dann auf
   **Trotzdem ausführen**. Der Hinweis kommt, weil das Setup keine gekaufte
   Signatur trägt, nicht weil etwas damit nicht stimmt.
4. Durch den Assistenten klicken. Die Vorgaben passen für die meisten.

Das Setup braucht keine Administratorrechte und installiert ins Benutzerprofil.
Während der Installation wird ExifTool geladen (rund 11 MB), dafür ist einmalig
eine Internetverbindung nötig.

## Voraussetzungen

- Windows 10 oder 11
- Windows PowerShell 5.1 (seit Windows 10 Teil des Systems)

## Benutzen

Neue Fotos und Videos kommen in den Eingangsordner (Inbox). Dann die Weboberfläche
über die Desktop-Verknüpfung starten, Vorschau ansehen, importieren. Alles Weitere
steht in `ANLEITUNG.md` und in der bebilderten Anleitung, die das Setup mitbringt.

## Lizenz

MIT, siehe `LICENSE`. Mitgeliefert wird [ExifTool](https://exiftool.org/) von
Phil Harvey unter eigener Lizenz (Perl Artistic License / GPL).
```

- [ ] **Schritt 3: Prüfen**

```powershell
Get-Content .\README.md -TotalCount 5
Select-String -Path .\LICENSE -Pattern "Martin"
```

Erwartet: Beide Dateien liegen vor, die Lizenz nennt den Inhaber. Der Downloadlink zeigt noch ins Leere – das Release entsteht in Task 11.

- [ ] **Schritt 4: Commit**

```bash
git add LICENSE README.md
git commit -m "MIT-Lizenz und README" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Setup-Gerüst, das sich bauen und installieren lässt

Erst das tragende Gerüst: Dateien, Ordner, Verknüpfungen, Deinstallation. ExifTool und die eigenen Assistentenseiten kommen in den Tasks 7 bis 9 dazu. So lässt sich jeder Schritt einzeln bauen und still installieren.

**Dateien:**
- Neu: `installer/GoDigital-Medienimport.iss`, `installer/Baue-Setup.ps1`, `installer/liesmich.md`

**Schnittstellen:**
- Nutzt: `VERSION` (Task 1), `LICENSE` (Task 5), `config/einstellungen.vorlage.json` (Task 4).
- Liefert: `installer\ausgabe\GoDigital-Medienimport-Setup-<version>.exe`; die ISPP-Definition `AppVersion`; die `AppId` `{{89A23525-B7D0-45C9-BA38-83D6BF357836}`, die über alle künftigen Fassungen gleich bleiben muss, sonst wird aus einem Update eine zweite Installation.

- [ ] **Schritt 1: `installer/GoDigital-Medienimport.iss` anlegen**

Datei als **UTF-8 mit BOM** speichern, sonst zeigt der Assistent zerlegte Umlaute.

```pascal
; GoDigital Medienimport - Installationsprogramm
; Gebaut mit Inno Setup 6. Siehe installer\liesmich.md.
;
; AppVersion kommt als /D-Definition vom Bauskript, das VERSION liest. Die
; Versionsnummer steht ausschliesslich dort; der Wert hier faengt nur den Fall
; ab, dass jemand den Compiler von Hand aufruft.

#ifndef AppVersion
  #define AppVersion "0.0.0-handbetrieb"
#endif

#define AppName "GoDigital Medienimport"
#define AppPublisher "Martin Goßner GoDigital"
#define AppUrl "https://github.com/martingodigital/godigital-medienimport"

[Setup]
; Die AppId bleibt ueber alle Fassungen gleich. Aendert sie sich, haelt Windows
; ein Update fuer ein zweites Programm und der Nutzer hat beides.
AppId={{89A23525-B7D0-45C9-BA38-83D6BF357836}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}
VersionInfoVersion={#AppVersion}
; Installation ins Benutzerprofil: das Programm schreibt Protokolle und
; Einstellungen in den eigenen Ordner, unter C:\Programme duerfte es das nicht.
; Nebeneffekt: Windows fragt nicht nach Administratorrechten.
DefaultDirName={localappdata}\Programs\GoDigital Medienimport
DefaultGroupName={#AppName}
PrivilegesRequired=lowest
DisableWelcomePage=no
LicenseFile=..\LICENSE
OutputDir=ausgabe
OutputBaseFilename=GoDigital-Medienimport-Setup-{#AppVersion}
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\scripts\Importiere-Medien.ps1

[Languages]
Name: "de"; MessagesFile: "compiler:Languages\German.isl"

[Messages]
de.ConfirmUninstall=Soll %1 wirklich entfernt werden?%n%nEntfernt werden das Programm, ExifTool, die Einstellungen und die Verknüpfungen.%n%nIhre Mediathek, die Inbox und die Protokolle bleiben erhalten.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\scripts\Importiere-Medien.ps1";     DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "..\scripts\Starte-Weboberflaeche.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "..\web\index.html";                    DestDir: "{app}\web";     Flags: ignoreversion
Source: "..\Medien importieren.cmd";            DestDir: "{app}";         Flags: ignoreversion
Source: "..\Vorschau (aendert nichts).cmd";     DestDir: "{app}";         Flags: ignoreversion
Source: "..\Weboberflaeche starten.cmd";        DestDir: "{app}";         Flags: ignoreversion
Source: "..\ANLEITUNG.md";                      DestDir: "{app}";         Flags: ignoreversion
Source: "..\VERSION";                           DestDir: "{app}";         Flags: ignoreversion
Source: "..\LICENSE";                           DestDir: "{app}";         Flags: ignoreversion
Source: "..\config\einstellungen.vorlage.json"; DestDir: "{app}\config";  Flags: ignoreversion
Source: "..\protokolle\GoDigital-Medienimport_Anleitung-bebildert.pdf"; DestDir: "{app}"; Flags: ignoreversion

[Dirs]
Name: "{app}\protokolle"

[Icons]
Name: "{group}\Weboberfläche starten";    Filename: "{app}\Weboberflaeche starten.cmd";   WorkingDir: "{app}"
Name: "{group}\Medien importieren";       Filename: "{app}\Medien importieren.cmd";       WorkingDir: "{app}"
Name: "{group}\Vorschau (ändert nichts)"; Filename: "{app}\Vorschau (aendert nichts).cmd"; WorkingDir: "{app}"
Name: "{group}\Anleitung";                Filename: "{app}\GoDigital-Medienimport_Anleitung-bebildert.pdf"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}";         Filename: "{app}\Weboberflaeche starten.cmd";   WorkingDir: "{app}"; Tasks: desktopicon

[UninstallDelete]
; Beides entsteht erst zur Laufzeit und wuerde sonst stehen bleiben.
Type: filesandordirs; Name: "{app}\exiftool"
Type: filesandordirs; Name: "{app}\config"
```

Zur Architektur gibt es keine Angabe (`ArchitecturesAllowed`): Sie verlangt je nach Inno-Fassung unterschiedliche Schlüsselwörter, und die Spec nennt 6.1 als Untergrenze. Windows 10/11 auf 32 Bit ist praktisch nicht mehr anzutreffen; träte der Fall ein, scheiterte erst das 64-Bit-ExifTool, nicht die Installation.

- [ ] **Schritt 2: `installer/Baue-Setup.ps1` anlegen**

Als UTF-8 mit BOM speichern.

```powershell
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
```

- [ ] **Schritt 3: `installer/liesmich.md` anlegen**

````markdown
# Setup bauen

Nur für die Entwicklung. Nutzer brauchen diesen Ordner nicht.

## Voraussetzungen

- Inno Setup 6.1 oder neuer. Auf dem Entwicklungs-PC liegt 6.7.3 unter
  `%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe`.
- Internetzugang: Das Bauskript holt die aktuelle ExifTool-Fassung und bildet
  deren Prüfsumme.

## Bauen

```powershell
.\installer\Baue-Setup.ps1
```

Ergebnis: `installer\ausgabe\GoDigital-Medienimport-Setup-<version>.exe`.

Die Versionsnummer kommt aus `VERSION` im Projektordner. Eine neue Fassung
bedeutet: `VERSION` ändern, neu bauen, Release anlegen.

## Still installieren zum Prüfen

```powershell
& ".\installer\ausgabe\GoDigital-Medienimport-Setup-1.0.0.exe" /VERYSILENT /SUPPRESSMSGBOXES `
  "/DIR=$env:TEMP\gdmi-probe" /MERGETASKS=!desktopicon /LOG="$env:TEMP\gdmi-setup.log"
```

Wieder entfernen:

```powershell
& "$env:TEMP\gdmi-probe\unins000.exe" /VERYSILENT
```

`/MERGETASKS=!desktopicon` verhindert, dass bei jedem Prüflauf eine Verknüpfung
auf dem Desktop landet.
````

- [ ] **Schritt 4: Bauen**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\installer\Baue-Setup.ps1"
```

Erwartet: `Fertig: …\installer\ausgabe\GoDigital-Medienimport-Setup-1.0.0.exe`. Meldet der Compiler einen Fehler zu einer Quelldatei, stimmt ein Pfad in `[Files]` nicht – die Pfade dort sind relativ zum `installer\`-Ordner.

- [ ] **Schritt 5: Still installieren und nachsehen**

```powershell
$ziel = "$env:TEMP\gdmi-probe"
Remove-Item $ziel -Recurse -Force -ErrorAction SilentlyContinue
& ".\installer\ausgabe\GoDigital-Medienimport-Setup-1.0.0.exe" /VERYSILENT /SUPPRESSMSGBOXES `
  "/DIR=$ziel" /MERGETASKS=!desktopicon /LOG="$env:TEMP\gdmi-setup.log" | Out-Null
Start-Sleep -Seconds 3
Get-ChildItem $ziel -Recurse -File | Select-Object -ExpandProperty FullName
```

Erwartet: `scripts\Importiere-Medien.ps1`, `scripts\Starte-Weboberflaeche.ps1`, `web\index.html`, die drei `.cmd`, `ANLEITUNG.md`, `VERSION`, `LICENSE`, das PDF, `config\einstellungen.vorlage.json`, `unins000.exe`, dazu der leere Ordner `protokolle`.

- [ ] **Schritt 6: Installierte Fassung starten**

```powershell
& "$ziel\Vorschau (aendert nichts).cmd"
```

Erwartet: Das Fenster öffnet sich, der Lauf bricht mit „Inbox-Ordner existiert nicht" ab – die Einstellungsdatei entsteht erst in Task 9. Das ist an dieser Stelle richtig; wichtig ist, dass die `.cmd` die Skripte findet und PowerShell startet.

- [ ] **Schritt 7: Wieder entfernen**

```powershell
& "$ziel\unins000.exe" /VERYSILENT
Start-Sleep -Seconds 3
Test-Path $ziel
```

Erwartet: `False` oder ein Ordner, in dem nur noch das steckt, was nach der Installation entstanden ist.

- [ ] **Schritt 8: Commit**

```bash
git add installer/GoDigital-Medienimport.iss installer/Baue-Setup.ps1 installer/liesmich.md
git commit -m "Setup-Geruest mit Inno Setup" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Ordnerseite im Assistenten

Der Nutzer soll Mediathek und Inbox selbst bestimmen können, weil eine Mediathek groß wird und viele sie auf eine zweite Platte legen. Die Seite prüft dieselben Regeln wie `Set-EinstellungenObjekt` in der Weboberfläche und zusätzlich zwei, die dort fehlen.

**Dateien:**
- Ändern: `installer/GoDigital-Medienimport.iss` (Abschnitt `[Dirs]`, neuer Abschnitt `[Code]`)

**Schnittstellen:**
- Liefert: die Scripted Constants `{code:MediathekOrdner}` und `{code:InboxOrdner}`, dazu die Pascal-Funktionen `MediathekOrdner(Param: String): String` und `InboxOrdner(Param: String): String`. Task 9 übergibt beide an `Schreibe-Einstellungen.ps1`.
- Liefert: `function NextButtonClick(CurPageID: Integer): Boolean` – Task 8 erweitert genau diese Funktion um den Download; sie darf nicht ein zweites Mal angelegt werden.

- [ ] **Schritt 1: `[Dirs]` erweitern**

```pascal
[Dirs]
Name: "{app}\protokolle"
Name: "{code:MediathekOrdner}"
Name: "{code:InboxOrdner}"
```

- [ ] **Schritt 2: `[Code]` anlegen**

Ans Ende der `.iss` anfügen:

```pascal
[Code]
var
  OrdnerSeite: TInputDirWizardPage;

procedure InitializeWizard;
begin
  OrdnerSeite := CreateInputDirPage(wpSelectDir,
    'Ordner für Ihre Medien',
    'Wo sollen die Bilder liegen?',
    'Die Mediathek nimmt die fertig einsortierten Fotos und Videos auf. Sie wird mit der Zeit groß;' + #13#10 +
    'viele legen sie deshalb auf eine zweite Festplatte.' + #13#10#13#10 +
    'Die Inbox ist der Eingang: Dort legen Sie neue Fotos ab, die noch einsortiert werden sollen.' + #13#10#13#10 +
    'Beide Ordner werden angelegt, falls es sie noch nicht gibt.',
    False, '');
  OrdnerSeite.Add('Mediathek');
  OrdnerSeite.Add('Inbox');
  OrdnerSeite.Values[0] := ExpandConstant('{userpics}\GoDigital Mediathek');
  OrdnerSeite.Values[1] := ExpandConstant('{userpics}\GoDigital Inbox');
end;

function MediathekOrdner(Param: String): String;
begin
  Result := Trim(OrdnerSeite.Values[0]);
end;

function InboxOrdner(Param: String): String;
begin
  Result := Trim(OrdnerSeite.Values[1]);
end;

// Vergleich auf Ordnerebene. Gross- und Kleinschreibung spielt unter Windows
// keine Rolle, der abschliessende Backslash ebenfalls nicht.
function OrdnerSchluessel(const Ordner: String): String;
begin
  Result := AddBackslash(Lowercase(Trim(Ordner)));
end;

function IstDerselbe(const A, B: String): Boolean;
begin
  Result := OrdnerSchluessel(A) = OrdnerSchluessel(B);
end;

// Liegt Unten innerhalb von Oben? Der Backslash am Ende ist wichtig: ohne ihn
// gaelte C:\Bilder2 als Unterordner von C:\Bilder.
function LiegtInnerhalb(const Unten, Oben: String): Boolean;
var
  U, O: String;
begin
  U := OrdnerSchluessel(Unten);
  O := OrdnerSchluessel(Oben);
  Result := (Length(U) > Length(O)) and (Copy(U, 1, Length(O)) = O);
end;

// Anlegen und eine Datei schreiben. Nur so faellt ein fehlendes Laufwerk oder
// ein schreibgeschuetzter Pfad hier auf und nicht erst beim ersten Import.
function OrdnerBeschreibbar(const Ordner: String): Boolean;
var
  Probe: String;
begin
  Result := False;
  if not ForceDirectories(Ordner) then
    Exit;
  Probe := AddBackslash(Ordner) + 'gdmi-schreibprobe.tmp';
  if SaveStringToFile(Probe, 'Schreibprobe', False) then
  begin
    DeleteFile(Probe);
    Result := True;
  end;
end;

function OrdnerSeiteGeprueft(): Boolean;
var
  Mediathek, Inbox: String;
begin
  Result := False;
  Mediathek := Trim(OrdnerSeite.Values[0]);
  Inbox     := Trim(OrdnerSeite.Values[1]);

  if (Mediathek = '') or (Inbox = '') then
  begin
    MsgBox('Bitte tragen Sie beide Ordner ein.', mbError, MB_OK);
    Exit;
  end;

  if IstDerselbe(Mediathek, Inbox) then
  begin
    MsgBox('Mediathek und Inbox dürfen nicht derselbe Ordner sein.' + #13#10#13#10 +
           'Die Inbox ist der Eingang, die Mediathek das Ergebnis.', mbError, MB_OK);
    Exit;
  end;

  // Die Weboberflaeche prueft nur auf Gleichheit. Liegt die Inbox in der
  // Mediathek, liest der Import sie bei jedem Lauf mit und sortiert die
  // Mediathek in sich selbst um.
  if LiegtInnerhalb(Inbox, Mediathek) then
  begin
    MsgBox('Die Inbox darf nicht innerhalb der Mediathek liegen.' + #13#10#13#10 +
           'Der Import würde die Mediathek sonst bei jedem Lauf noch einmal mitlesen.', mbError, MB_OK);
    Exit;
  end;

  if LiegtInnerhalb(Mediathek, Inbox) then
  begin
    MsgBox('Die Mediathek darf nicht innerhalb der Inbox liegen.' + #13#10#13#10 +
           'Der Import würde die bereits einsortierten Dateien sonst immer wieder einlesen.', mbError, MB_OK);
    Exit;
  end;

  if not OrdnerBeschreibbar(Mediathek) then
  begin
    MsgBox('Der Ordner für die Mediathek lässt sich nicht anlegen oder nicht beschreiben:' + #13#10#13#10 +
           Mediathek + #13#10#13#10 +
           'Bitte prüfen Sie, ob das Laufwerk vorhanden ist, und wählen Sie einen anderen Ordner.', mbError, MB_OK);
    Exit;
  end;

  if not OrdnerBeschreibbar(Inbox) then
  begin
    MsgBox('Der Ordner für die Inbox lässt sich nicht anlegen oder nicht beschreiben:' + #13#10#13#10 +
           Inbox + #13#10#13#10 +
           'Bitte wählen Sie einen anderen Ordner.', mbError, MB_OK);
    Exit;
  end;

  Result := True;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = OrdnerSeite.ID then
    Result := OrdnerSeiteGeprueft();
end;

function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo,
  MemoTypeInfo, MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
begin
  Result := MemoDirInfo + NewLine + NewLine +
            'Mediathek:' + NewLine + Space + MediathekOrdner('') + NewLine + NewLine +
            'Inbox (Eingang):' + NewLine + Space + InboxOrdner('') + NewLine + NewLine +
            MemoTasksInfo;
end;
```

`{userpics}` ist der Bilderordner des Nutzers; auf einem deutschen Windows zeigt der Explorer ihn als „Bilder".

- [ ] **Schritt 3: Bauen**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\installer\Baue-Setup.ps1"
```

Erwartet: `Fertig: …Setup-1.0.0.exe`. Meldet der Compiler „Unknown identifier", fehlt eine der Hilfsfunktionen oder sie steht hinter ihrer ersten Verwendung – Pascal Script braucht die Reihenfolge von oben nach unten.

- [ ] **Schritt 4: Still installieren (Vorgaben greifen)**

```powershell
$ziel = "$env:TEMP\gdmi-probe"
Remove-Item $ziel -Recurse -Force -ErrorAction SilentlyContinue
& ".\installer\ausgabe\GoDigital-Medienimport-Setup-1.0.0.exe" /VERYSILENT /SUPPRESSMSGBOXES `
  "/DIR=$ziel" /MERGETASKS=!desktopicon | Out-Null
Start-Sleep -Seconds 3
Test-Path "$env:USERPROFILE\Pictures\GoDigital Mediathek"
Test-Path "$env:USERPROFILE\Pictures\GoDigital Inbox"
```

Erwartet: beide `True`. Danach aufräumen:

```powershell
& "$ziel\unins000.exe" /VERYSILENT
Start-Sleep -Seconds 3
Remove-Item "$env:USERPROFILE\Pictures\GoDigital Mediathek","$env:USERPROFILE\Pictures\GoDigital Inbox" -Recurse -Force
```

- [ ] **Schritt 5: Ordnerseite von Hand durchspielen (Prüfschwerpunkte 1 und 5)**

Das Setup ohne Schalter starten und auf der Seite „Ordner für Ihre Medien" der Reihe nach eintragen. Nach jedem Fall auf **Weiter** klicken und die Meldung lesen:

| Eingabe | Erwartete Meldung |
|---|---|
| Mediathek `%USERPROFILE%\Pictures\MT`, Inbox derselbe Pfad | „dürfen nicht derselbe Ordner sein" |
| Mediathek `%USERPROFILE%\Pictures\MT`, Inbox `%USERPROFILE%\Pictures\MT\inbox` | „Die Inbox darf nicht innerhalb der Mediathek liegen" |
| Mediathek `%USERPROFILE%\Pictures\MT\unten`, Inbox `%USERPROFILE%\Pictures\MT` | „Die Mediathek darf nicht innerhalb der Inbox liegen" |
| Mediathek `%USERPROFILE%\Pictures\MT2`, Inbox leer | „Bitte tragen Sie beide Ordner ein" |
| Mediathek `Z:\Fotos` (nicht vorhandenes Laufwerk) | „lässt sich nicht anlegen oder nicht beschreiben" |
| Mediathek `%USERPROFILE%\Pictures\MT`, Inbox `%USERPROFILE%\Pictures\IN` | Weiter geht's; die Seite „Bereit" zeigt beide Ordner |

Danach den Assistenten abbrechen und die beim Prüfen angelegten Ordner `MT`, `MT2`, `IN` entfernen. Die Schreibprobe legt die Ordner an, auch wenn die Prüfung danach an einer anderen Regel scheitert – das ist hinnehmbar, aber beim Aufräumen zu bedenken.

- [ ] **Schritt 6: Commit**

```bash
git add installer/GoDigital-Medienimport.iss
git commit -m "Assistentenseite fuer Mediathek und Inbox" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: ExifTool laden, prüfen, entpacken

Das Setup bleibt dadurch bei rund einem Megabyte. Version und Prüfsumme werden beim Bauen festgelegt; der Installer lädt genau diese Datei. Zwei Fallen im Archiv: Die ausführbare Datei heißt `exiftool(-k).exe` – das `-k` lässt sie nach jedem Aufruf auf einen Tastendruck warten, der Import bliebe daran hängen. Und der Ordner `exiftool_files` daneben muss mitwandern, sonst startet gar nichts.

**Dateien:**
- Neu: `installer/Entpacke-ExifTool.ps1`
- Ändern: `installer/Baue-Setup.ps1`, `installer/GoDigital-Medienimport.iss`
- Erzeugt beim Bauen: `installer/exiftool-fassung.txt`

**Schnittstellen:**
- Nutzt: `NextButtonClick` aus Task 7 – erweitert, nicht ersetzt.
- Liefert: die ISPP-Definitionen `ExifToolUrl`, `ExifToolDatei`, `ExifToolHash`, `ExifToolVersion`; die Pascal-Variable `VorhandenesExifTool: String` (leer, wenn ExifTool geladen wurde, sonst der vom Nutzer gewählte Pfad) – Task 9 wertet sie aus.
- Liefert: `Entpacke-ExifTool.ps1 -Archiv <zip> -Ziel <ordner>`, Rückgabecode 0 bei Erfolg, 1 bei Fehler.

- [ ] **Schritt 1: `installer/Entpacke-ExifTool.ps1` anlegen**

Als UTF-8 mit BOM speichern.

```powershell
<#
.SYNOPSIS
    Entpackt das ExifTool-Archiv in den Zielordner.

.DESCRIPTION
    Wird vom Installationsprogramm aufgerufen, laeuft aber auch einzeln.

    Die ausfuehrbare Datei im Archiv heisst exiftool(-k).exe. Das -k laesst das
    Programm nach jedem Aufruf auf einen Tastendruck warten; das Importskript
    bliebe daran haengen. Sie wird deshalb in exiftool.exe umbenannt. Der Ordner
    exiftool_files daneben muss mit, ohne ihn startet die Datei nicht.

    Der Aufbau des Archivs wird gesucht, nicht vorausgesetzt: Eine neue Fassung
    darf die Dateien auch ohne Oberordner oder bereits ohne -k mitbringen.

.PARAMETER Archiv
    Pfad zur heruntergeladenen ZIP-Datei.

.PARAMETER Ziel
    Ordner, in dem exiftool.exe danach liegt. Wird neu angelegt.

.EXAMPLE
    .\Entpacke-ExifTool.ps1 -Archiv C:\Temp\exiftool-13.59_64.zip -Ziel C:\Programme\exiftool
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Archiv,
    [Parameter(Mandatory = $true)][string]$Ziel
)

$ErrorActionPreference = 'Stop'

try {
    if (-not (Test-Path -LiteralPath $Archiv -PathType Leaf)) {
        throw "Archiv nicht gefunden: $Archiv"
    }

    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ("gdmi-exiftool-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temp -Force | Out-Null

    try {
        Expand-Archive -LiteralPath $Archiv -DestinationPath $temp -Force

        $exe = Get-ChildItem -LiteralPath $temp -Recurse -File |
               Where-Object { $_.Name -eq 'exiftool(-k).exe' -or $_.Name -eq 'exiftool.exe' } |
               Select-Object -First 1
        if (-not $exe) {
            throw "Im Archiv steckt keine exiftool.exe. Stimmt die heruntergeladene Datei?"
        }

        $quellOrdner = $exe.DirectoryName
        $beidateien  = Join-Path $quellOrdner 'exiftool_files'
        if (-not (Test-Path -LiteralPath $beidateien -PathType Container)) {
            throw "Neben $($exe.Name) fehlt der Ordner exiftool_files; ohne ihn startet ExifTool nicht."
        }

        if (Test-Path -LiteralPath $Ziel -PathType Container) {
            Remove-Item -LiteralPath $Ziel -Recurse -Force
        }
        New-Item -ItemType Directory -Path $Ziel -Force | Out-Null

        Copy-Item -LiteralPath $exe.FullName -Destination (Join-Path $Ziel 'exiftool.exe') -Force
        Copy-Item -LiteralPath $beidateien -Destination $Ziel -Recurse -Force

        # Alles andere aus demselben Ordner mitnehmen, darunter die Lizenz- und
        # README-Dateien von ExifTool.
        Get-ChildItem -LiteralPath $quellOrdner -File |
            Where-Object { $_.FullName -ne $exe.FullName } |
            ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $Ziel -Force }

        $zielExe = Join-Path $Ziel 'exiftool.exe'
        if (-not (Test-Path -LiteralPath $zielExe -PathType Leaf)) {
            throw "Nach dem Entpacken fehlt $zielExe."
        }
        Write-Host "ExifTool entpackt nach: $Ziel"
    } finally {
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
} catch {
    Write-Host "FEHLER: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
```

- [ ] **Schritt 2: Entpackskript gegen beide Archivaufbauten prüfen (Prüfschwerpunkt 3)**

```powershell
$w = "$env:TEMP\gdmi-zip"
Remove-Item $w -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "$w\mitOberordner\exiftool-13.59_64","$w\ohneOberordner" -Force | Out-Null

# Fall A: wie das echte Archiv - Oberordner, Datei mit -k
Copy-Item "E:\Exiftool\exiftool.exe" "$w\mitOberordner\exiftool-13.59_64\exiftool(-k).exe"
Copy-Item "E:\Exiftool\exiftool_files" "$w\mitOberordner\exiftool-13.59_64\" -Recurse
"Lizenztext" | Set-Content "$w\mitOberordner\exiftool-13.59_64\README.txt"
Compress-Archive -Path "$w\mitOberordner\*" -DestinationPath "$w\A.zip" -Force

# Fall B: kein Oberordner, Datei heisst schon exiftool.exe
Copy-Item "E:\Exiftool\exiftool.exe" "$w\ohneOberordner\"
Copy-Item "E:\Exiftool\exiftool_files" "$w\ohneOberordner\" -Recurse
Compress-Archive -Path "$w\ohneOberordner\*" -DestinationPath "$w\B.zip" -Force

# Fall C: unbrauchbar - exiftool_files fehlt
New-Item -ItemType Directory -Path "$w\kaputt" -Force | Out-Null
Copy-Item "E:\Exiftool\exiftool.exe" "$w\kaputt\exiftool(-k).exe"
Compress-Archive -Path "$w\kaputt\*" -DestinationPath "$w\C.zip" -Force

foreach ($fall in 'A','B','C') {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\installer\Entpacke-ExifTool.ps1" `
      -Archiv "$w\$fall.zip" -Ziel "$w\ziel-$fall"
    "$fall -> Code $LASTEXITCODE"
}
& "$w\ziel-A\exiftool.exe" -ver
```

Erwartet: A und B liefern Code 0, C liefert Code 1 mit der Meldung zu `exiftool_files`. `exiftool.exe -ver` in `ziel-A` gibt die Versionsnummer aus und kehrt sofort zurück – wartet es auf einen Tastendruck, wurde nicht umbenannt. In `ziel-A` liegt außerdem `README.txt`.

- [ ] **Schritt 3: `Baue-Setup.ps1` um die ExifTool-Fassung erweitern**

Den Parameterblock ersetzen durch:

```powershell
[CmdletBinding()]
param(
    [string]$ISCC,
    [string]$ArchivDatei,
    [switch]$OhneExifTool
)
```

Und vor dem Abschnitt `# --- Bauen ---` einfügen:

```powershell
# --- ExifTool-Fassung festlegen ----------------------------------------------
# Version und Pruefsumme werden beim Bauen bestimmt. Nur so steht fest, welche
# Datei beim Nutzer ankommt, und nur so merkt der Installer, wenn auf dem
# Spiegelserver etwas anderes liegt.
$FassungsDatei = Join-Path $Hier "exiftool-fassung.txt"

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
        Invoke-WebRequest -Uri $exifUrl -OutFile $temp -UseBasicParsing
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
Write-Host "ExifTool: $($fassung['Version'])  SHA256 $($fassung['SHA256'])"
```

Den Compiler-Aufruf ersetzen durch:

```powershell
& $Compiler "/DAppVersion=$Version" `
            "/DExifToolVersion=$($fassung['Version'])" `
            "/DExifToolDatei=$($fassung['Datei'])" `
            "/DExifToolUrl=$($fassung['URL'])" `
            "/DExifToolHash=$($fassung['SHA256'])" `
            $Quelle
```

Den Hilfetext oben um die beiden neuen Parameter ergänzen:

```powershell
.PARAMETER ArchivDatei
    Bereits heruntergeladenes ExifTool-Archiv, falls der Download scheitert.
.PARAMETER OhneExifTool
    Fassung nicht neu ermitteln, sondern exiftool-fassung.txt wiederverwenden.
```

- [ ] **Schritt 4: `.iss` um Download und Entpacken erweitern**

Oben bei den Defines ergänzen:

```pascal
#ifndef ExifToolVersion
  #define ExifToolVersion "unbekannt"
  #define ExifToolDatei "exiftool.zip"
  #define ExifToolUrl ""
  #define ExifToolHash ""
#endif
```

In `[Files]` ergänzen:

```pascal
; Laeuft zur Laufzeit aus {tmp}, wird nicht mitinstalliert.
Source: "Entpacke-ExifTool.ps1"; Flags: dontcopy
```

Im `[Code]`-Abschnitt die Variablen erweitern:

```pascal
var
  OrdnerSeite: TInputDirWizardPage;
  DownloadSeite: TDownloadWizardPage;
  ArchivPfad: String;
  VorhandenesExifTool: String;
```

**Auf die Reihenfolge achten:** Pascal Script kennt keine Vorwärtsdeklaration. Jede Funktion
muss über ihrer ersten Verwendung stehen. `OnDownloadProgress` wird in `InitializeWizard`
gebraucht und gehört deshalb **direkt hinter den `var`-Block, vor `InitializeWizard`**.
`ExifToolLaden` ruft `OnDownloadProgress` nicht selbst auf, wird aber von `NextButtonClick`
gebraucht und muss daher **vor `NextButtonClick`** stehen – am einfachsten ebenfalls oben,
hinter `OnDownloadProgress`. Steht eine der beiden weiter unten, bricht der Compiler mit
„Unknown identifier" ab.

Beide Funktionen also hinter den `var`-Block setzen:

```pascal
function OnDownloadProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  if ProgressMax > 0 then
    DownloadSeite.SetProgress(Progress, ProgressMax);
  Result := True;
end;

// Der Download gibt die Pruefsumme mit: schlaegt sie fehl, wirft Download eine
// Ausnahme und es wird nichts entpackt.
function ExifToolLaden(): Boolean;
begin
  DownloadSeite.Clear;
  DownloadSeite.Add('{#ExifToolUrl}', '{#ExifToolDatei}', '{#ExifToolHash}');
  DownloadSeite.Show;
  try
    try
      DownloadSeite.Download;
      ArchivPfad := ExpandConstant('{tmp}\{#ExifToolDatei}');
      Result := True;
    except
      Result := False;
      if MsgBox('ExifTool ließ sich nicht laden, oder die geladene Datei stimmt nicht mit der erwarteten überein.' + #13#10#13#10 +
                GetExceptionMessage + #13#10#13#10 +
                'Möchten Sie es noch einmal versuchen?', mbError, MB_YESNO) = IDNO then
      begin
        if MsgBox('Haben Sie ExifTool bereits auf diesem Rechner?' + #13#10#13#10 +
                  'Dann können Sie die Datei exiftool.exe jetzt auswählen. Andernfalls brechen Sie' + #13#10 +
                  'die Installation bitte ab und versuchen es später noch einmal.', mbConfirmation, MB_YESNO) = IDYES then
        begin
          VorhandenesExifTool := '';
          if GetOpenFileName('exiftool.exe auswählen', VorhandenesExifTool, '',
                             'Programme (*.exe)|*.exe|Alle Dateien (*.*)|*.*', 'exe') then
          begin
            if FileExists(VorhandenesExifTool) then
              Result := True
            else
              VorhandenesExifTool := '';
          end;
        end;
      end;
    end;
  finally
    DownloadSeite.Hide;
  end;
end;
```

`InitializeWizard` um die Downloadseite erweitern (die Zeilen zur Ordnerseite bleiben):

```pascal
  DownloadSeite := CreateDownloadPage('ExifTool wird geladen',
    'GoDigital Medienimport liest das Aufnahmedatum mit ExifTool aus Ihren Fotos und Videos.',
    @OnDownloadProgress);
  ArchivPfad := '';
  VorhandenesExifTool := '';
```

`NextButtonClick` aus Task 7 ersetzen durch:

```pascal
function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = OrdnerSeite.ID then
    Result := OrdnerSeiteGeprueft()
  else if CurPageID = wpReady then
    Result := ExifToolLaden();
end;
```

Und das Entpacken anfügen:

```pascal
procedure CurStepChanged(CurStep: TSetupStep);
var
  Code: Integer;
  Befehl: String;
begin
  if CurStep <> ssPostInstall then
    Exit;

  // Der Nutzer hat eine vorhandene Installation gewaehlt: nichts entpacken,
  // der Pfad wandert in die Einstellungsdatei.
  if VorhandenesExifTool <> '' then
    Exit;

  ExtractTemporaryFile('Entpacke-ExifTool.ps1');
  // Jeder Pfad in Anfuehrungszeichen: Zielordner und Archivpfad duerfen
  // Leerzeichen und Umlaute enthalten.
  Befehl := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{tmp}\Entpacke-ExifTool.ps1') + '"' +
            ' -Archiv "' + ArchivPfad + '"' +
            ' -Ziel "' + ExpandConstant('{app}\exiftool') + '"';
  if (not Exec('powershell.exe', Befehl, '', SW_HIDE, ewWaitUntilTerminated, Code)) or (Code <> 0) then
    MsgBox('ExifTool ließ sich nicht entpacken (Rückgabe ' + IntToStr(Code) + ').' + #13#10#13#10 +
           'Das Programm ist installiert, findet aber kein ExifTool. Tragen Sie in den' + #13#10 +
           'Einstellungen der Weboberfläche den Pfad zu einer exiftool.exe ein.', mbError, MB_OK);
end;
```

- [ ] **Schritt 5: Bauen und die Fassungsdatei ansehen**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\installer\Baue-Setup.ps1"
Get-Content .\installer\exiftool-fassung.txt
```

Erwartet: Die Datei nennt eine Version wie `13.59`, einen Dateinamen `exiftool-13.59_64.zip`, die SourceForge-Adresse und einen 64-stelligen Hash. Scheitert der Download, die Adresse im Browser öffnen und mit `-ArchivDatei "<pfad>"` erneut bauen.

- [ ] **Schritt 6: Installation mit Download prüfen**

Das Setup ohne Schalter starten, durchklicken und auf der Seite „ExifTool wird geladen" den Fortschrittsbalken beobachten. Danach:

```powershell
$ziel = "$env:LOCALAPPDATA\Programs\GoDigital Medienimport"
Get-ChildItem "$ziel\exiftool" | Select-Object -ExpandProperty Name
& "$ziel\exiftool\exiftool.exe" -ver
```

Erwartet: `exiftool.exe`, `exiftool_files`, dazu die README-Datei. `-ver` gibt die Versionsnummer aus und kehrt zurück, ohne auf eine Taste zu warten.

- [ ] **Schritt 7: Fehlerfall Prüfsumme prüfen**

```powershell
(Get-Content .\installer\exiftool-fassung.txt) -replace '^SHA256=.*','SHA256=0000000000000000000000000000000000000000000000000000000000000000' |
  Set-Content .\installer\exiftool-fassung.txt -Encoding UTF8
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\installer\Baue-Setup.ps1" -OhneExifTool
```

Das so gebaute Setup starten und durchklicken. Erwartet: Nach dem Download erscheint die Meldung „ließ sich nicht laden, oder die geladene Datei stimmt nicht" mit der Rückfrage. Auf **Nein**, dann noch einmal **Nein** – der Assistent bleibt auf der Seite „Bereit", nichts ist installiert. Danach den Assistenten abbrechen und die echte Fassungsdatei wiederherstellen:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\installer\Baue-Setup.ps1"
```

- [ ] **Schritt 8: Prüfinstallation entfernen**

```powershell
& "$env:LOCALAPPDATA\Programs\GoDigital Medienimport\unins000.exe" /VERYSILENT
```

- [ ] **Schritt 9: Commit**

```bash
git add installer/Entpacke-ExifTool.ps1 installer/Baue-Setup.ps1 installer/GoDigital-Medienimport.iss installer/exiftool-fassung.txt
git commit -m "ExifTool beim Installieren laden, pruefen und entpacken" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Einstellungsdatei schreiben und Schlussseite

Ohne Einstellungsdatei zeigt die frische Installation auf ihre eigenen Unterordner statt auf die Ordner aus dem Assistenten. Existiert die Datei schon, bleibt sie unverändert – sonst verlöre ein Nutzer bei jedem Update seine Einstellungen.

**Dateien:**
- Neu: `installer/Schreibe-Einstellungen.ps1`
- Ändern: `installer/GoDigital-Medienimport.iss`

**Schnittstellen:**
- Nutzt: `MediathekOrdner`, `InboxOrdner` (Task 7), `VorhandenesExifTool` (Task 8), `config/einstellungen.vorlage.json` (Task 4).
- Liefert: `Schreibe-Einstellungen.ps1 -Vorlage <datei> -Ziel <datei> -Inbox <pfad> -Mediathek <pfad> -Protokolle <pfad> -ExifToolPath <datei>` mit den Rückgabecodes 0 (geschrieben), 2 (vorhanden, nichts geändert), 1 (Fehler).

- [ ] **Schritt 1: `installer/Schreibe-Einstellungen.ps1` anlegen**

Als UTF-8 mit BOM speichern.

```powershell
<#
.SYNOPSIS
    Erzeugt config\einstellungen.json aus der Vorlage.

.DESCRIPTION
    Wird vom Installationsprogramm aufgerufen. Die Ordner und der ExifTool-Pfad
    kommen aus dem Assistenten, alle uebrigen Schluessel aus der Vorlage.

    Eine vorhandene Datei bleibt unangetastet: Ein Update darf die Einstellungen
    des Nutzers nicht ueberschreiben. Rueckgabe 2 sagt dem Installer, dass nichts
    geschrieben wurde, damit die Schlussseite es erwaehnen kann.

.EXAMPLE
    .\Schreibe-Einstellungen.ps1 -Vorlage .\config\einstellungen.vorlage.json `
        -Ziel .\config\einstellungen.json -Inbox C:\In -Mediathek C:\MT `
        -Protokolle C:\Log -ExifToolPath C:\Prog\exiftool\exiftool.exe
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Vorlage,
    [Parameter(Mandatory = $true)][string]$Ziel,
    [Parameter(Mandatory = $true)][string]$Inbox,
    [Parameter(Mandatory = $true)][string]$Mediathek,
    [Parameter(Mandatory = $true)][string]$Protokolle,
    [Parameter(Mandatory = $true)][string]$ExifToolPath
)

$ErrorActionPreference = 'Stop'

try {
    if (Test-Path -LiteralPath $Ziel -PathType Leaf) {
        Write-Host "Einstellungen vorhanden, sie bleiben unveraendert: $Ziel"
        exit 2
    }
    if (-not (Test-Path -LiteralPath $Vorlage -PathType Leaf)) {
        throw "Vorlage nicht gefunden: $Vorlage"
    }

    $konfig = [System.IO.File]::ReadAllText($Vorlage) | ConvertFrom-Json
    $konfig.Inbox        = $Inbox
    $konfig.Mediathek    = $Mediathek
    $konfig.Protokolle   = $Protokolle
    $konfig.ExifToolPath = $ExifToolPath

    # ConvertTo-Json maskiert unter Windows PowerShell 5.1 Umlaute als \uXXXX.
    # Gueltiges JSON, aber die Datei soll von Hand lesbar bleiben - dieselbe
    # Behandlung wie beim Speichern ueber die Weboberflaeche.
    $json = $konfig | ConvertTo-Json -Depth 5
    $json = [regex]::Replace($json, '\\u([0-9a-fA-F]{4})', {
        param($m) [char][int]("0x" + $m.Groups[1].Value)
    })

    $ordner = Split-Path -Parent $Ziel
    if ($ordner -and -not (Test-Path -LiteralPath $ordner -PathType Container)) {
        New-Item -ItemType Directory -Path $ordner -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Ziel, $json, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "Einstellungen geschrieben: $Ziel"
} catch {
    Write-Host "FEHLER: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
```

- [ ] **Schritt 2: Skript einzeln prüfen, auch mit Umlauten (Prüfschwerpunkt 2)**

```powershell
$s = "$env:TEMP\gdmi-einst"
Remove-Item $s -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "$s\Prüfordner für Bilder" -Force | Out-Null
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\installer\Schreibe-Einstellungen.ps1" `
  -Vorlage ".\config\einstellungen.vorlage.json" -Ziel "$s\config\einstellungen.json" `
  -Inbox "$s\Prüfordner für Bilder\Eingang" -Mediathek "$s\Prüfordner für Bilder\Mediathek" `
  -Protokolle "$s\Prüfordner für Bilder\Protokolle" -ExifToolPath "$s\exiftool\exiftool.exe"
"Code $LASTEXITCODE"
Get-Content "$s\config\einstellungen.json"
```

Erwartet: Code 0, die Datei nennt die vier Werte mit echten Umlauten (nicht `\u00fc`) und bringt die 22 Endungen aus der Vorlage mit.

- [ ] **Schritt 3: Zweiten Aufruf prüfen**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\installer\Schreibe-Einstellungen.ps1" `
  -Vorlage ".\config\einstellungen.vorlage.json" -Ziel "$s\config\einstellungen.json" `
  -Inbox "C:\anders" -Mediathek "C:\anders" -Protokolle "C:\anders" -ExifToolPath "C:\anders\x.exe"
"Code $LASTEXITCODE"
Select-String -Path "$s\config\einstellungen.json" -Pattern "anders"
```

Erwartet: Code 2, die Meldung „Einstellungen vorhanden", und `Select-String` findet nichts – die Datei ist unverändert.

- [ ] **Schritt 4: `.iss` erweitern**

In `[Files]` ergänzen:

```pascal
Source: "Schreibe-Einstellungen.ps1"; Flags: dontcopy
```

Im `[Code]`-Abschnitt eine Variable ergänzen:

```pascal
  EinstellungenBehalten: Boolean;
```

In `InitializeWizard` dazu:

```pascal
  EinstellungenBehalten := False;
```

Und in `CurStepChanged` **nach** dem Entpacken anfügen (der frühe `Exit` bei `VorhandenesExifTool` muss dafür weichen – unten die vollständige Fassung der Prozedur):

```pascal
procedure CurStepChanged(CurStep: TSetupStep);
var
  Code: Integer;
  Befehl, ExifZiel: String;
begin
  if CurStep <> ssPostInstall then
    Exit;

  if VorhandenesExifTool <> '' then
  begin
    // Der Nutzer hat eine vorhandene Installation gewaehlt: nichts entpacken,
    // der Pfad wandert direkt in die Einstellungsdatei.
    ExifZiel := VorhandenesExifTool;
  end
  else
  begin
    ExifZiel := ExpandConstant('{app}\exiftool\exiftool.exe');
    ExtractTemporaryFile('Entpacke-ExifTool.ps1');
    // Jeder Pfad in Anfuehrungszeichen: Zielordner und Archivpfad duerfen
    // Leerzeichen und Umlaute enthalten.
    Befehl := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{tmp}\Entpacke-ExifTool.ps1') + '"' +
              ' -Archiv "' + ArchivPfad + '"' +
              ' -Ziel "' + ExpandConstant('{app}\exiftool') + '"';
    if (not Exec('powershell.exe', Befehl, '', SW_HIDE, ewWaitUntilTerminated, Code)) or (Code <> 0) then
      MsgBox('ExifTool ließ sich nicht entpacken (Rückgabe ' + IntToStr(Code) + ').' + #13#10#13#10 +
             'Das Programm ist installiert, findet aber kein ExifTool. Tragen Sie in den' + #13#10 +
             'Einstellungen der Weboberfläche den Pfad zu einer exiftool.exe ein.', mbError, MB_OK);
  end;

  ExtractTemporaryFile('Schreibe-Einstellungen.ps1');
  Befehl := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{tmp}\Schreibe-Einstellungen.ps1') + '"' +
            ' -Vorlage "'      + ExpandConstant('{app}\config\einstellungen.vorlage.json') + '"' +
            ' -Ziel "'         + ExpandConstant('{app}\config\einstellungen.json') + '"' +
            ' -Inbox "'        + InboxOrdner('') + '"' +
            ' -Mediathek "'    + MediathekOrdner('') + '"' +
            ' -Protokolle "'   + ExpandConstant('{app}\protokolle') + '"' +
            ' -ExifToolPath "' + ExifZiel + '"';
  if not Exec('powershell.exe', Befehl, '', SW_HIDE, ewWaitUntilTerminated, Code) then
    Code := -1;
  if Code = 2 then
    EinstellungenBehalten := True
  else if Code <> 0 then
    MsgBox('Die Einstellungsdatei ließ sich nicht schreiben (Rückgabe ' + IntToStr(Code) + ').' + #13#10#13#10 +
           'Sie können die Ordner nach dem Start in der Weboberfläche eintragen.', mbError, MB_OK);
end;
```

Die Schlussseite anfügen:

```pascal
procedure CurPageChanged(CurPageID: Integer);
begin
  if (CurPageID = wpFinished) and EinstellungenBehalten then
    WizardForm.FinishedLabel.Caption :=
      WizardForm.FinishedLabel.Caption + #13#10#13#10 +
      'Auf diesem Rechner waren bereits Einstellungen vorhanden. Sie wurden beibehalten; ' +
      'die im Assistenten gewählten Ordner gelten deshalb erst, wenn Sie sie in der ' +
      'Weboberfläche eintragen.';
end;
```

Die beiden Haken der Schlussseite in `[Run]` ergänzen (am Ende der `.iss`, vor `[Code]`):

```pascal
[Run]
Filename: "{app}\Weboberflaeche starten.cmd"; Description: "Weboberfläche jetzt starten"; \
  WorkingDir: "{app}"; Flags: postinstall shellexec skipifsilent
Filename: "{app}\GoDigital-Medienimport_Anleitung-bebildert.pdf"; Description: "Anleitung öffnen"; \
  Flags: postinstall shellexec skipifsilent
```

- [ ] **Schritt 5: Durchlauf mit Umlauten im Zielordner (Prüfschwerpunkt 2)**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\installer\Baue-Setup.ps1" -OhneExifTool
```

Das Setup starten, als Installationsordner `%LOCALAPPDATA%\Programs\Prüfordner Medienimport` eintragen, als Mediathek `%USERPROFILE%\Pictures\Prüfung Mediathek` und als Inbox `%USERPROFILE%\Pictures\Prüfung Eingang`. Durchklicken, beide Haken auf der Schlussseite abwählen. Danach:

```powershell
$ziel = "$env:LOCALAPPDATA\Programs\Prüfordner Medienimport"
Get-Content "$ziel\config\einstellungen.json"
```

Erwartet: Die Datei nennt die drei Ordner mit Umlauten und `ExifToolPath` auf `$ziel\exiftool\exiftool.exe`.

- [ ] **Schritt 6: Import aus der Installation heraus**

```powershell
"x" > "$env:USERPROFILE\Pictures\Prüfung Eingang\IMG_0001.JPG"
& "$ziel\Medien importieren.cmd"
Get-ChildItem "$env:USERPROFILE\Pictures\Prüfung Mediathek" -Recurse -File | Select-Object -ExpandProperty FullName
Get-Content (Get-ChildItem "$ziel\protokolle\protokoll_*.md" | Select-Object -Last 1).FullName -TotalCount 14
```

Erwartet: Die Datei liegt als `…\<Jahr>\<Jahr-Monat>\<datum>_IMG_0001.JPG` in der Mediathek. Der Protokollkopf nennt die Ordner aus dem Assistenten, `- **Programmversion:** 1.0.0` und den ExifTool-Pfad in der Installation.

- [ ] **Schritt 7: Update über die bestehende Installation**

Dasselbe Setup noch einmal starten, diesmal mit anderen Ordnerangaben durchklicken. Danach:

```powershell
Select-String -Path "$ziel\config\einstellungen.json" -Pattern "Prüfung Mediathek"
```

Erwartet: Treffer – die Einstellungen sind unverändert, und die Schlussseite hat darauf hingewiesen.

- [ ] **Schritt 8: Deinstallieren und nachsehen, was bleibt**

```powershell
& "$ziel\unins000.exe"
```

Nach dem Durchlauf:

```powershell
Test-Path $ziel
Get-ChildItem "$env:USERPROFILE\Pictures\Prüfung Mediathek" -Recurse -File | Select-Object -ExpandProperty FullName
```

Erwartet: Der Programmordner ist weg oder enthält nur noch `protokolle` mit den Laufprotokollen. Die Mediathek steht unverändert mit der importierten Datei. Danach die Prüfordner von Hand entfernen.

- [ ] **Schritt 9: Commit**

```bash
git add installer/Schreibe-Einstellungen.ps1 installer/GoDigital-Medienimport.iss
git commit -m "Einstellungsdatei aus dem Assistenten schreiben" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: Dokumentation nachziehen

**Dateien:**
- Ändern: `CLAUDE.md`, `ANLEITUNG.md`, `protokolle/GoDigital-Medienimport_Anleitung-bebildert.html`
- Neu erzeugt: `protokolle/GoDigital-Medienimport_Anleitung-bebildert.pdf`

**Schnittstellen:**
- Nutzt: alles aus den Tasks 1 bis 9. Diese Task fügt keinen Code hinzu.

- [ ] **Schritt 1: `CLAUDE.md` – Ordnertabelle**

In der Tabelle „Ordnerstruktur" ergänzen:

```markdown
| `installer\` | **Installationsprogramm.** Inno-Setup-Quelle, Bauskript und zwei Hilfsskripte, die das Setup zur Laufzeit ruft. Baut die `Setup.exe` für GitHub. |
| `docs\superpowers\` | Specs und Umsetzungspläne. Versioniert, gehört nicht ins Setup. |
| `VERSION` | Eine Zeile, die Versionsnummer. Einzige Quelle; Protokollkopf und Setup lesen sie von hier. |
| `LICENSE` | MIT, Inhaber Martin Goßner. |
| `README.md` | Einstieg auf GitHub: Downloadlink, Voraussetzungen, SmartScreen-Hinweis. |
| `config\einstellungen.vorlage.json` | Versionierte Vorlage mit leeren Ordnerangaben. Der Installer macht daraus die echte Datei. |
```

- [ ] **Schritt 2: `CLAUDE.md` – den überholten Absatz ersetzen**

Der Absatz, der mit „Die eingecheckte `config\einstellungen.json` ist an diesen Rechner gebunden" beginnt, stimmt nicht mehr. Ersetzen durch:

```markdown
`config\einstellungen.json` liegt **nicht** im Repository: Sie trägt absolute Pfade dieses
Rechners und greift vor den eingebauten Standardwerten, ein Klon zeigte sonst ins Leere.
Versioniert ist `config\einstellungen.vorlage.json` mit leeren Ordnerangaben – ein leerer
Wert zählt wie ein fehlender, ein Klon landet damit bei den Ordnern neben dem Skript. Der
Installer macht aus der Vorlage die echte Datei und trägt die Ordner aus dem Assistenten
ein; eine vorhandene Datei fasst er nicht an.

Der leere `ExifToolPath` der Vorlage ist der Grund für je eine zusätzliche Zeile in beiden
Skripten: `Get-Einstellung` prüft auf `$null`, und ein leerer String kommt durch. Ohne diese
Zeile bräche ein Lauf mit „ExifTool nicht gefunden: " ohne Pfad ab.
```

- [ ] **Schritt 3: `CLAUDE.md` – Abschnitt zum Installer**

Vor „Code-Konventionen" einfügen:

````markdown
## Installationsprogramm

`installer\` baut aus dem Projektordner eine einzelne `Setup.exe` (Inno Setup 6). Sie
installiert ins Benutzerprofil nach `%LOCALAPPDATA%\Programs\GoDigital Medienimport`, ohne
Administratorrechte: Das Programm schreibt Protokolle und Einstellungen in den eigenen
Ordner, unter `C:\Programme` dürfte es das nicht.

```powershell
.\installer\Baue-Setup.ps1                      # Version aus VERSION, ExifTool-Fassung frisch
.\installer\Baue-Setup.ps1 -OhneExifTool        # schneller, nutzt exiftool-fassung.txt weiter
.\installer\Baue-Setup.ps1 -ArchivDatei <zip>   # falls der SourceForge-Download klemmt
```

**ExifTool wird beim Installieren geladen, nicht mitgeliefert.** Das hält das Setup bei rund
einem Megabyte. Das Bauskript holt die Versionsnummer von `https://exiftool.org/ver.txt`,
lädt das Archiv von SourceForge – die einzige Quelle, `exiftool.org` liefert für die ZIP-Datei
404 –, bildet die SHA256-Summe und schreibt alles nach `installer\exiftool-fassung.txt`. Der
Installer lädt genau diese Datei und prüft die Summe; `DownloadPage.Add` erledigt das selbst
und wirft bei Abweichung eine Ausnahme.

**Die Arbeit steckt in PowerShell, nicht in Pascal.** `Entpacke-ExifTool.ps1` und
`Schreibe-Einstellungen.ps1` laufen aus `{tmp}` (`Flags: dontcopy`) und sind einzeln auf der
Kommandozeile prüfbar. Im Pascal-Teil bleiben Seiten und Prüfungen. Jeder Pfad geht dabei in
Anführungszeichen an PowerShell: Zielordner und Medienordner dürfen Leerzeichen und Umlaute
tragen.

**Das Archiv wird gesucht, nicht vorausgesetzt.** Die ausführbare Datei heißt
`exiftool(-k).exe`; das `-k` ließe sie nach jedem Aufruf auf einen Tastendruck warten, der
Import bliebe hängen. `Entpacke-ExifTool.ps1` sucht sie samt `exiftool_files` im entpackten
Baum, statt einen Ordnernamen anzunehmen, und benennt beim Kopieren um.

**Die `AppId` `{{89A23525-B7D0-45C9-BA38-83D6BF357836}` bleibt für immer gleich.** Ändert sie
sich, hält Windows ein Update für ein zweites Programm, und der Nutzer hat beides.

**Eine vorhandene `einstellungen.json` bleibt unangetastet** (Rückgabe 2 des Schreibskripts).
Die Schlussseite sagt es, sonst wunderte sich ein Nutzer, warum seine im Assistenten
gewählten Ordner nicht greifen.

Die Ordnerseite prüft mehr als die Weboberfläche: Dort ist nur verboten, dass Inbox und
Mediathek derselbe Ordner sind. Der Assistent lehnt zusätzlich ab, dass einer im anderen
liegt – sonst läse der Import die Mediathek bei jedem Lauf noch einmal mit – und legt beide
Ordner probeweise an, damit ein fehlendes Laufwerk hier auffällt und nicht erst beim ersten
Import.

Die `.iss` ist **UTF-8 mit BOM**, wie die Skripte: Ohne BOM zeigt der Assistent zerlegte
Umlaute.
````

- [ ] **Schritt 4: `CLAUDE.md` – Abschnitt „Geplant"**

Den ersten Absatz von „Geplant" ersetzen durch:

```markdown
Weboberfläche und Installationsprogramm sind gebaut. Was offen bleibt: Die Oberfläche zeigt
die Vorschau je Datei, kann aber keine einzelnen Dateien abwählen – der Lauf ist alles oder
nichts. Ein `-Reorganisieren` lässt sich über die Seite anstoßen, die Vorschau dafür zeigt
bislang dieselbe Tabelle wie ein Import. Das Setup trägt keine Signatur, SmartScreen meldet
sich deshalb bei jedem Nutzer einmal; ein Code-Signing-Zertifikat kostet Geld und ist nicht
beschafft.
```

- [ ] **Schritt 5: `CLAUDE.md` – Voraussetzungen**

Den ExifTool-Punkt ersetzen durch:

```markdown
- **ExifTool.** Gesucht wird in dieser Reihenfolge: `-ExifToolPath`, Einstellungsdatei,
  `exiftool\exiftool.exe` neben dem Programm (so liefert das Setup es aus), Suchpfad,
  zuletzt `E:\Exiftool\exiftool.exe` als historischer Wert dieses Rechners. Keine
  Versionsprüfung. Nur im Inbox-Modus nötig.
```

- [ ] **Schritt 6: `ANLEITUNG.md` – Installation aus Nutzersicht**

Vor dem ersten Abschnitt zur Bedienung einen Abschnitt einfügen, der beschreibt: Setup von GitHub laden, SmartScreen bestätigen (Weitere Informationen → Trotzdem ausführen, mit dem Grund), die Ordnerseite erklären (Mediathek wird groß, Inbox ist der Eingang, beide dürfen nicht ineinanderliegen), der ExifTool-Download braucht einmalig Internet, die Desktop-Verknüpfung startet die Weboberfläche, das Fenster muss offen bleiben. Dazu: Deinstallieren über „Apps & Features" entfernt das Programm, nicht die Bilder. Sprache und Tonfall aus der bestehenden Datei übernehmen; keine Pfade mit `%LOCALAPPDATA%` im Fließtext, sondern „der Ordner, den der Assistent vorschlägt".

- [ ] **Schritt 7: Bebilderte Anleitung ändern**

Geändert wird ausschließlich die HTML-Quelle `protokolle/GoDigital-Medienimport_Anleitung-bebildert.html`; Aufbau und Layout stehen in `DOKU-STIL.md`. Nötig ist ein Abschnitt „Installieren" mit einer Zeichnung der Schrittfolge (Download → SmartScreen → Ordnerseite → ExifTool → fertig), als Inline-SVG wie die übrigen Zeichnungen. Nichts nachladen.

- [ ] **Schritt 8: PDF neu drucken**

```bash
chrome.exe --headless=new --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="E:/GoDigital Medienimport/protokolle/GoDigital-Medienimport_Anleitung-bebildert.pdf" \
  "file:///E:/GoDigital Medienimport/protokolle/GoDigital-Medienimport_Anleitung-bebildert.html"
```

- [ ] **Schritt 9: PDF seitenweise ansehen**

Mit `pypdfium2` jede Seite rendern und ansehen. Erwartet: keine abgeschnittenen SVG-Beschriftungen, keine halb leeren Seiten. Jede Zeichnung steht mit ihrer Bildunterschrift zusammen; der Spickzettel bekommt als einziger Abschnitt einen erzwungenen Seitenumbruch.

- [ ] **Schritt 10: Commit**

```bash
git add CLAUDE.md ANLEITUNG.md "protokolle/GoDigital-Medienimport_Anleitung-bebildert.html" "protokolle/GoDigital-Medienimport_Anleitung-bebildert.pdf"
git commit -m "Dokumentation zum Installationsprogramm nachgezogen" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: Durchlauf auf frischem System und Veröffentlichung

Ein Installationsprogramm prüft sich nur auf einem unberührten System sinnvoll. Die letzten beiden Schritte verändern etwas außerhalb dieses Rechners und brauchen deshalb die ausdrückliche Freigabe des Auftraggebers.

**Dateien:**
- Keine Änderung am Code. Ergebnis ist ein Release.

**Schnittstellen:**
- Nutzt: `installer\ausgabe\GoDigital-Medienimport-Setup-1.0.0.exe` aus Task 8.

- [ ] **Schritt 1: Setup aus dem aktuellen Stand bauen**

```powershell
git status --short
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\installer\Baue-Setup.ps1"
```

Erwartet: `git status` meldet nichts Offenes, der Bau endet mit `Fertig:`.

- [ ] **Schritt 2: Durchlaufliste auf einem zweiten Windows-Benutzerkonto oder in einer virtuellen Maschine**

Abarbeiten und jeden Punkt abhaken:

1. Setup starten, SmartScreen bestätigen, alle Vorgaben durchklicken.
2. Nach dem ersten Import den Protokollkopf prüfen: Stehen dort die Ordner aus dem Assistenten?
3. Installation in einen Pfad mit Leerzeichen und Umlauten wiederholen.
4. Vorschau über die `.cmd`, danach echter Import mit zwei Testbildern.
5. Weboberfläche starten, Einstellungen speichern, Protokoll ansehen.
6. Deinstallieren und prüfen, dass Mediathek, Inbox und Protokolle erhalten bleiben.
7. Erneut installieren und prüfen, dass die Einstellungsdatei unverändert bleibt.
8. Nach jedem Schritt notieren, ob Windows Defender eingreift.

Was dabei auffällt, wird behoben und die betroffene Task erneut geprüft – nicht erst nach dem Release.

- [ ] **Schritt 3: Freigabe einholen**

Die beiden folgenden Schritte dem Auftraggeber vorlegen und bestätigen lassen: Das Repository wird öffentlich und lässt sich nicht stillschweigend zurücknehmen – was einmal öffentlich war, kann gespiegelt sein. Dazu vorher prüfen:

```bash
git log --all --oneline -- config/einstellungen.json
git log --all --stat | grep -iE "mediathek/|inbox/" | head
```

Erwartet: In der Historie steckt die Einstellungsdatei mit den `E:`-Pfaden (bis Task 4), aber keine Medien. Die Pfade sind kein Geheimnis; sollte in der Historie etwas anderes auftauchen, vor dem Öffentlichmachen klären.

- [ ] **Schritt 4: Repository öffentlich machen und Release anlegen**

Erst nach der Freigabe aus Schritt 3:

```bash
git push
gh repo edit martingodigital/godigital-medienimport --visibility public --accept-visibility-change-consequences
gh release create v1.0.0 "installer/ausgabe/GoDigital-Medienimport-Setup-1.0.0.exe" \
  --title "GoDigital Medienimport 1.0.0" \
  --notes "Erste Fassung mit Installationsprogramm. Windows 10/11. Beim ersten Start meldet sich SmartScreen, weil das Setup keine gekaufte Signatur trägt: Weitere Informationen, dann Trotzdem ausführen."
```

- [ ] **Schritt 5: Downloadlink gegenprüfen**

```bash
gh release view v1.0.0 --json assets --jq '.assets[].name'
```

Erwartet: `GoDigital-Medienimport-Setup-1.0.0.exe`. Danach den Link aus `README.md` in einem Browser öffnen und prüfen, dass er auf dieses Release zeigt.
