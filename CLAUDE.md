# CLAUDE.md

**Repository:** `godigital-medienimport`
**Beschreibung:** Fotos und Videos nach Aufnahmedatum einsortieren

Guidance für Claude Code (claude.ai/code) in diesem Ordner.

Diese Datei ist die kurze Handreichung: Befehle, Regeln, die teuren Fallen. Die
Begründungen dahinter – warum der Code so aussieht und was beim Ändern mitgeändert werden
muss – stehen in **[`docs\ARCHITEKTUR.md`](docs/ARCHITEKTUR.md)**. Vor einem Eingriff in
Motor, Weboberfläche oder Installer dort den passenden Abschnitt lesen.

## Worum es geht

Ein von Claude betreuter Prozess-Ordner für Fotos und Videos beliebiger Herkunft (Handy,
Kamera, Drohne, Downloads). Neue Dateien werden nach ihrem Aufnahmedatum umbenannt und in
eine chronologisch sortierbare Mediathek einsortiert. Keine Tests, keine Build-Kette – das
Programm ist ein einziges PowerShell-Skript, dazu ein HTTP-Dienst für die Oberfläche und
ein Inno-Setup-Installer.

Versioniert sind Skripte, Seite, Konfiguration und Dokumentation; Inbox, Mediathek,
Laufprotokolle und `.bak`-Kopien hält die `.gitignore` draußen. `inbox\.gitkeep` hält den
sonst leeren Eingangsordner im Repository – ohne ihn bricht das Skript nach einem Klonen
mit `exit 1` ab. Der Import fasst diese Datei auch mit `-AlleDateien` nicht an (geprüft).

**Dieser Ordner ist nicht die Umgebung, in der das Programm benutzt wird.** Benutzt wird
eine Installation aus dem Setup, mit eigenen Ordnern und häufig mit Inbox und Mediathek auf
verschiedenen Laufwerken. Daraus folgt zweierlei: Eine Änderung hier erreicht den Nutzer
erst über ein neu gebautes Setup (`installer\Baue-Setup.ps1`), und wer eine Rückmeldung zur
Geschwindigkeit nachstellen will, muss den langsamen Fall über die Laufwerksgrenze
nachbauen.

**Verhältnis zu `E:\Drohne-Foto-Workflow`:** Dieses Projekt ist aus dessen Skript
hervorgegangen, läuft aber vollständig getrennt und hat eine eigene Mediathek. Das
Altprojekt ist eingefroren und wird von hier aus **nicht** verändert – weder Skript noch
Mediathek, auch nicht sein `archiv\`.

## Ordnerstruktur

| Ordner / Datei | Zweck |
|---|---|
| `inbox\` | **Eingang.** Lose Dateien nach Datum, Unterordner gelten als Ereignis. |
| `mediathek\` | **Ergebnis.** Datumsbaum `<Jahr>\<Jahr-Monat>\` plus Zweig `Ereignisse\`. Nicht manuell umbenennen. |
| `config\einstellungen.json` | Standardwerte. Nicht im Repository (absolute Pfade); fehlt sie, greifen die eingebauten Werte. |
| `config\einstellungen.vorlage.json` | Versionierte Vorlage mit leeren Ordnerangaben. Der Installer macht daraus die echte Datei. |
| `scripts\Importiere-Medien.ps1` | Der Motor. Läuft eigenständig, kennt die Oberfläche nicht. |
| `scripts\Starte-Weboberflaeche.ps1` | HTTP-Dienst auf 127.0.0.1, ruft den Motor als eigenen Prozess auf. |
| `web\index.html` | Die Oberfläche. Wird vom Dienst ausgeliefert, lädt nichts von außen. |
| `installer\` | Inno-Setup-Quelle, Bauskript, zwei Hilfsskripte für die Laufzeit, `liesmich.md`. |
| `installer\GoDigital-Medienimport.svg` | Das Bildzeichen. Quelle des Icons, hier wird geändert. |
| `installer\GoDigital-Medienimport.ico` | Daraus mit `Baue-Icon.ps1` gebaut, neun Größen. Eingecheckt, weil der Bau Chrome braucht. |
| `installer\ausgabe\` | Die gebaute `Setup.exe`. Nicht im Repository, veröffentlicht wird sie als Release-Datei. |
| `.github\workflows\release.yml` | Baut das Setup bei einem Tag `v*` und hängt es an ein GitHub-Release. |
| `protokolle\` | Ein Markdown-Protokoll pro echtem Lauf. Reiner Laufzeitordner, nicht im Repository. |
| `docs\ARCHITEKTUR.md` | Die Begründungen zu Motor, Oberfläche und Installer. Mitziehen, wenn sich Verhalten ändert. |
| `docs\…_Anleitung-bebildert.pdf` | Bebilderte Anwenderanleitung; das Setup liefert sie mit. Quelle ist die `.html` daneben. |
| `docs\DOKU-STIL.md` | Kopie der Skill `anwenderdoku-pdf` (Stand 2026-09-25). Maßgeblich bleibt die Skill-Datei. |
| `docs\weboberflaeche.png` | Der Screenshot im README. Gegen Wegwerf-Ordner aufgenommen, nicht gegen die echte Mediathek. |
| `docs\superpowers\`, `.superpowers\` | Specs, Pläne und Arbeitsstände. Nur lokal, die `.gitignore` hält sie draußen. |
| `ANLEITUNG.md` | Nutzerdokumentation (nicht-technisch). Muss zum Skript passen. |
| `CHANGELOG.md` | Was sich je Fassung geändert hat. Die Nummer selbst steht nur in `VERSION`. |
| `BETATEST.md` | Rückmeldungen aus dem Betatest, je Meldung nach Nutzen und Aufwand beurteilt. Nur lokal: nennt die Tester. |
| `VERSION` | Eine Zeile, die Versionsnummer. Einzige Quelle; Protokollkopf und Setup lesen sie von hier. |
| `README.md` | Einstieg auf GitHub: Downloadlink, Voraussetzungen, SmartScreen-Hinweis. |
| `Medien importieren.cmd` | **Doppelklick-Start** (ohne Claude). Daneben `Vorschau (aendert nichts).cmd` und `Weboberflaeche starten.cmd`. |
| `LICENSE` | MIT, Inhaber Martin Goßner. |

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

# Setup bauen:
.\installer\Baue-Setup.ps1 -OhneExifTool
```

Scheitert der `.ps1`-Aufruf an der Execution-Policy, hilft die `.cmd` (startet mit
`-ExecutionPolicy Bypass`) oder einmalig `Set-ExecutionPolicy -Scope CurrentUser
RemoteSigned`.

Rauchtest und Bedientest der Oberfläche stehen in
[`docs\ARCHITEKTUR.md`](docs/ARCHITEKTUR.md#prüfen-und-testen).

## Architektur in Kürze

Drei Teile, die einzeln laufen. Der **Motor** (`Importiere-Medien.ps1`) ist das Programm;
er kennt weder Oberfläche noch Installer und muss per Doppelklick funktionsfähig bleiben.
Der **Dienst** (`Starte-Weboberflaeche.ps1`) liefert die Seite aus und ruft den Motor als
eigenen Prozess auf, weil dessen `exit 1` den Dienst sonst mitrisse. Das **Setup** baut
aus dem Projektordner eine `Setup.exe` und lädt ExifTool beim Installieren nach.

Der Motor hat zwei Modi, die sich Protokoll- und Zusammenfassungs-Code teilen; die
Verzweigung liegt bei `if ($Reorganisieren)`. Der Inbox-Modus liest Metadaten mit **einem**
ExifTool-Aufruf für den ganzen Ordner, `-Reorganisieren` liest gar keine und geht nur nach
dem Dateinamen. Einstellungen kommen in der Rangfolge Parameter > `config\einstellungen.json`
> eingebauter Standard; jede neue Einstellung gehört in die JSON-Datei, sonst kennt der
Doppelklick-Betrieb sie nicht.

Wer wo nachliest:

| Vorhaben | Abschnitt in `docs\ARCHITEKTUR.md` |
|---|---|
| Einstellung ergänzen oder ändern | Einstellungen |
| An ExifTool-Aufruf, Datum oder Filtern arbeiten | Modus Inbox |
| Ordnerschema oder Dateinamen ändern | Gemeinsame Teile beider Modi |
| Neue Ausgabezeile im Motor | Ergebnisse, Fortschritt und Zeiten |
| Dienst, API oder Seite ändern | Weboberfläche |
| Setup, Assistent oder Icon ändern | Installationsprogramm |

## Die teuren Fallen

Jede davon hat schon einmal Schaden oder lange Fehlersuche verursacht. Einzelheiten jeweils
im genannten Abschnitt.

- **Falsch gebaute Argumente fallen still auf die echten Ordner zurück.** Kommen `-Inbox`,
  `-Mediathek`, `-Protokolle` nicht an, läuft der Import gegen die Produktivmediathek. Genau
  so entstand am 2026-09-23 ein ungewollter echter Lauf. Nach jedem Testlauf im
  Protokollkopf nachsehen, welche Pfade benutzt wurden. (Weboberfläche)
- **Eine neue Ausgabezeile kann die Weboberfläche fehlleiten.** `Read-SkriptAusgabe` prüft
  jede Zeile gegen feste Muster; eine Zeile mit „Verschieben nach" landet als Dateibewegung
  in der Vorschautabelle, eine mit „JSON-Fehler" als Abbruchgrund. (Ergebnisse, Fortschritt
  und Zeiten)
- **`-WhatIf` zeigt keine `OK`-Zeilen.** Eine Vorschau meldet immer „Verschoben: 0"; was
  verschoben würde, steht nur in den `WhatIf:`-Zeilen. (Gemeinsame Teile)
- **`-r` im ExifTool-Aufruf darf an keine Bedingung.** Ohne Rekursion bleiben Dateien aus
  Unterordnern unbemerkt in der Inbox liegen. (Modus Inbox)
- **`-DatumsFormat` hängt an vier Stellen.** Ein anderes Format läuft fehlerfrei durch und
  sortiert trotzdem falsch ein. (Gemeinsame Teile)
- **`"Erweiterungen": []` schaltet den Filter ab**, statt nichts zu importieren.
  (Einstellungen)
- **`Get-Content` in einer JSON-Antwort lässt den Dienst hängen** – ohne Fehler, bis in den
  Timeout. Lesen über `[System.IO.File]::ReadAllText()`. (Weboberfläche)
- **`confirm()` blockiert headless Chrome.** Ein Bedientest hängt dann ohne Meldung.
  (Prüfen und Testen)

## Regeln für Claude in diesem Ordner

- Vor einem echten Lauf bei Unsicherheit erst `-WhatIf` zeigen.
- Die Mediathek ist die Wahrheit: Dateien dort nicht umbenennen oder löschen ohne
  ausdrückliche Aufforderung. Das gilt besonders für `-Reorganisieren`, das leere Ordner
  wirklich löscht.
- Destruktive Aktionen immer vorher bestätigen lassen.
- Nach jedem Verarbeitungslauf die Protokoll-Zusammenfassung nennen und auf die
  Protokolldatei verlinken.
- Änderungen am Skript zuerst mit eigenen `-Inbox`/`-Mediathek`-Pfaden im Scratchpad prüfen,
  nicht an der echten Mediathek. Es gibt keine automatisierten Tests.
- Beim Testen mit eigenen Pfaden **immer alle drei** angeben (`-Inbox`, `-Mediathek`,
  `-Protokolle`) und danach im Protokollkopf nachsehen, ob sie auch angekommen sind.
- **Immer auch unter Windows PowerShell 5.1 testen** (`powershell.exe`, nicht nur `pwsh`).
  Die `.cmd`-Starter rufen 5.1 auf, und es verhält sich bei `-WhatIf`, Encoding und
  .NET-Methoden anders als PowerShell 7.
- Git trägt die Historie, aber nur so weit sie eingecheckt ist: vor einem größeren Eingriff
  `git status` ansehen und einen ungesicherten Stand erst committen. Geht das nicht, eine
  Kopie als `<Datei>.bak-<zeitstempel>` ablegen – solche Kopien ignoriert Git.
- Ändert sich das Verhalten, `ANLEITUNG.md` und `docs\ARCHITEKTUR.md` mitziehen. Die
  Anleitung ist die Nutzerdoku und beschreibt dieselben Abläufe in nicht-technischer
  Sprache; sie darf nicht auseinanderlaufen.
- Dasselbe gilt für die bebilderte Anleitung in `docs\`. Geändert wird die HTML-Quelle,
  daraus entsteht das PDF neu; das PDF selbst lässt sich nicht bearbeiten. Stil und Aufbau
  stehen in `docs\DOKU-STIL.md`:

  ```bash
  chrome.exe --headless=new --disable-gpu --no-pdf-header-footer \
    --print-to-pdf="GoDigital-Medienimport_Anleitung-bebildert.pdf" \
    "file:///E:/GoDigital Medienimport/docs/GoDigital-Medienimport_Anleitung-bebildert.html"
  ```

  Danach das PDF seitenweise rendern und ansehen (`pypdfium2`), sonst fallen abgeschnittene
  SVG-Beschriftungen und halb leere Seiten erst beim Leser auf. Der Umbruch ist eingestellt,
  nicht zufällig: Jede Zeichnung steht mit ihrer Bildunterschrift zusammen, und der
  Spickzettel bekommt als einziger Abschnitt einen erzwungenen Seitenumbruch.
- Ändert sich das Aussehen der Oberfläche sichtbar, `docs\weboberflaeche.png` neu aufnehmen –
  gegen Wegwerf-Ordner, nie gegen die echte Mediathek: der Screenshot liegt öffentlich im
  README und das Lageband zeigt die vollen Pfade.
- Eine neue Fassung bedeutet: `VERSION` ändern, `CHANGELOG.md` ergänzen, committen, Tag
  `v<Version>` setzen und schieben. Den Rest macht `.github\workflows\release.yml`; passen
  Tag und `VERSION` nicht zusammen, bricht er ab.
- `E:\Drohne-Foto-Workflow` nicht anfassen. Getrenntes, eingefrorenes Projekt.

## Code-Konventionen

- Die Skripte sind **UTF-8 mit BOM**. Das BOM ist Pflicht, sonst liest Windows PowerShell 5.1
  die Umlaute als ANSI. Beim Bearbeiten unbedingt beibehalten. Dasselbe gilt für die `.iss`;
  `installer\Ordnerpruefung.iss` dagegen ist ASCII ohne BOM.
- Ausgaben und Hilfetext dürfen echte Umlaute enthalten. Beide `.cmd`-Starter setzen
  `chcp 65001`, die Anzeige stimmt damit unter Windows PowerShell 5.1 (geprüft). Ein Aufruf
  ohne `chcp`, etwa über das Bash-Werkzeug, zeigt die Umlaute zerlegt. Das ist die Konsole,
  nicht das Skript, und kein Grund, an der Ausgabe zu ändern.
- Das Protokoll entsteht mit `Set-Content -Encoding UTF8`. Unter Windows PowerShell 5.1 ergibt
  das UTF-8 **mit** BOM, unter PowerShell 7 ohne (geprüft). Wer die Protokolle maschinell
  liest, muss beides vertragen.
- **Bezeichner, Parameter und Dateinamen bleiben ASCII** (`$uebersprungen`, `-Praefix`,
  `-Gruppierung`). Nur Text, den jemand liest, bekommt Umlaute.
- Bezeichner, Parameter und Ausgaben sind deutsch. Neue Parameter genauso benennen.

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

Bestehende Zieldateien werden nie überschrieben: Ist die Datei identisch, bleibt sie als
Dublette liegen (`SKIP`); ist sie verschieden, bekommt der Zielname einen Zähler. Dateien mit
vorhandenem Datumsvorsatz behalten ihn – nur so wird eine zurückgelegte Datei als Dublette
erkannt. Der Prozess im Einzelnen steht in
[`docs\ARCHITEKTUR.md`](docs/ARCHITEKTUR.md#der-prozess-im-einzelnen).

## Voraussetzungen

- **ExifTool.** Gesucht wird in dieser Reihenfolge: `-ExifToolPath`, Einstellungsdatei,
  `exiftool\exiftool.exe` neben dem Programm (so liefert das Setup es aus), Suchpfad, zuletzt
  `E:\Exiftool\exiftool.exe` als historischer Wert dieses Rechners. Keine Versionsprüfung.
  Nur im Inbox-Modus nötig.
- **PowerShell** 5.1 oder 7+.

## Geplant

Weboberfläche und Installationsprogramm sind gebaut. Was offen bleibt: Die Oberfläche zeigt
die Vorschau je Datei, kann aber keine einzelnen Dateien abwählen – der Lauf ist alles oder
nichts. Ein `-Reorganisieren` lässt sich über die Seite anstoßen, die Vorschau dafür zeigt
bislang dieselbe Tabelle wie ein Import. Das Setup trägt keine Signatur, SmartScreen meldet
sich deshalb bei jedem Nutzer einmal; ein Code-Signing-Zertifikat kostet Geld und ist nicht
beschafft.
