# GoDigital Medienimport – Anleitung

Fotos und Videos landen in der Inbox, per Doppelklick werden sie nach Aufnahmedatum
umbenannt und in die Mediathek einsortiert. Die Mediathek bleibt dadurch chronologisch
sortierbar, egal von welcher Kamera oder welchem Handy die Dateien stammen.

---

## 1. Was der Workflow macht

Aus einer Datei in der Inbox

```
IMG_1001.JPG
```

wird

```
mediathek\2026\2026-09\20260910_101530_IMG_1001.JPG
```

Vorne steht das Aufnahmedatum im Format `JahrMonatTag_StundeMinuteSekunde`, dahinter der
ursprüngliche Dateiname. Dadurch sortiert jeder Dateimanager die Bilder von allein
chronologisch.

---

## 2. Installieren

Wer das Programm schon eingerichtet hat, überspringt diesen Abschnitt.

1. Das Setup von der Projektseite herunterladen und starten.
2. Windows zeigt beim ersten Start einen blauen Hinweis: „Der Computer wurde durch Windows
   geschützt". Auf **Weitere Informationen** klicken, dann auf **Trotzdem ausführen**. Der
   Hinweis erscheint, weil das Setup keine gekaufte Signatur trägt – nicht, weil etwas damit
   nicht stimmt.
3. Durch den Assistenten klicken.

Der Assistent fragt nach zwei Ordnern:

- **Mediathek** – hier liegen die fertig einsortierten Fotos und Videos. Dieser Ordner wächst
  mit der Zeit auf viele Gigabyte; wer eine zweite Festplatte hat, wählt sie hier.
- **Inbox** – der Eingang für neue Dateien.

Beide Ordner dürfen nicht derselbe sein, und keiner darf im anderen liegen: Sonst würde das
Programm die bereits einsortierten Bilder bei jedem Lauf noch einmal einlesen. Der Assistent
sagt es, falls die Angaben nicht zusammenpassen.

Während der Installation wird **ExifTool** aus dem Internet geladen, rund 11 MB. Das ist das
Hilfsprogramm, das das Aufnahmedatum aus den Fotos liest; einmal Internet ist dafür nötig.
Schlägt der Download fehl, bietet der Assistent an, es noch einmal zu versuchen oder eine
schon vorhandene `exiftool.exe` auszuwählen.

Am Ende legt das Setup eine Verknüpfung auf dem Desktop an, die die Weboberfläche startet.
Im Startmenü liegt eine Gruppe mit allen Einträgen.

**Aktualisieren:** Ein neueres Setup einfach über die vorhandene Installation laufen lassen.
Ihre Einstellungen und Ihre Bilder bleiben dabei unberührt; der Assistent sagt auf der letzten
Seite, dass die vorhandenen Einstellungen beibehalten wurden.

**Entfernen:** Über „Apps & Features" in den Windows-Einstellungen. Entfernt werden das
Programm, ExifTool und die Verknüpfungen. **Ihre Mediathek, die Inbox und die Protokolle
bleiben erhalten** – die Bilder gehören Ihnen, nicht dem Programm.

---

## 3. In drei Schritten

1. Dateien von Kamera, Drohne oder Handy nach `inbox\` kopieren.
2. Doppelklick auf **Vorschau (aendert nichts).cmd** – zeigt nur an, was passieren würde.
3. Doppelklick auf **Medien importieren.cmd** – macht es wirklich.

Nach Schritt 3 liegt ein Protokoll in `protokolle\`.

---

## 4. Die Weboberfläche

Wer lieber klickt als doppelklickt: **Weboberflaeche starten.cmd** öffnet eine Seite im
Browser, auf der sich alles bedienen lässt. Das schwarze Fenster, das dabei aufgeht, muss
offen bleiben, solange die Seite benutzt wird. Zum Beenden das Fenster schließen.

Ganz oben steht in einem Satz, was ansteht — etwa „2 Dateien warten in der Inbox" —, daneben
die beiden Knöpfe **Vorschau** und **Wirklich ausführen**. Darunter drei Zahlen: Dateien in
der Inbox, Ereignisordner und Dateien in der Mediathek; die Inbox-Kachel färbt sich, sobald
dort etwas liegt. Fehlt ExifTool, erscheint darunter ein Hinweis darauf.

Rechts oben wechselt ein Knopf zwischen heller und dunkler Darstellung. Ohne Zutun folgt die
Seite der Windows-Einstellung. Ganz unten stehen die drei letzten Läufe; ein Klick darauf
öffnet das zugehörige Protokoll.

Die Seite hat drei Reiter:

- **Import** sammelt die Angaben für einen einzelnen Lauf: Ereignisname, Namensfilter und
  Ordnerschema, dazu drei Schalter. Der erste sortiert die Unterordner der Inbox nach Datum
  ein, statt sie zu Ereignissen zu machen. Der zweite schaltet den Endungsfilter ab und
  zieht dann auch Textdateien und XMP-Beidateien mit in die Mediathek. Der dritte macht
  etwas ganz anderes als die beiden: Er lässt die Inbox in Ruhe und sortiert stattdessen
  die vorhandene Mediathek um, genau wie `-Reorganisieren` in Abschnitt 8, inklusive
  Löschen leerer Ordner. Ist er gesetzt, sind Ereignisname, Namensfilter und die beiden
  anderen Schalter gesperrt; das Ordnerschema bleibt wählbar, denn danach wird umsortiert.
  Die Rückfrage vor dem Start weist eigens auf die Löschung hin.

  Ein Klick auf **Vorschau** zeigt in einer Tabelle, welche Datei wohin wandern würde.
  Erst danach wird **Wirklich ausführen** anklickbar, und auch dann folgt noch eine
  Rückfrage. Wer anschließend noch etwas am Formular ändert, braucht eine neue Vorschau.
  Einzelne Dateien lassen sich nicht abwählen: Der Lauf nimmt immer alles aus der Tabelle.
- **Einstellungen** bearbeitet dieselben Werte wie `config\einstellungen.json`, nur als
  Formular. Ganz oben stehen die drei Ordner: wo die Inbox liegt, wohin einsortiert wird und
  wohin die Protokolle kommen. Vor dem Speichern legt das Programm eine Sicherung als
  `einstellungen.json.bak` daneben. Mindestens ein Dateityp muss angehakt bleiben.
- **Protokolle** zeigt die letzten 50 Protokolle, ohne im Explorer zu suchen.

Die Seite läuft nur auf dem eigenen Rechner. Andere im Netzwerk erreichen sie nicht, und
ohne die Adresse aus dem Starterfenster funktioniert sie auch im eigenen Browser nicht.
Das verhindert, dass eine fremde Webseite im Hintergrund einen Import auslöst.

Am Ablauf ändert sich dadurch nichts: Die Oberfläche ruft genau dasselbe Programm auf wie
die beiden anderen `.cmd`-Dateien. Wer sie nicht mag, benutzt weiter den Doppelklick.

Die Seite läuft auf Port 8787. Ist der belegt, probiert das Programm die nächsten zwanzig
Ports durch und schreibt die vollständige Adresse ins Starterfenster. Ein fester Port oder
ein Start, der den Browser nicht selbst öffnet, geht über die Kommandozeile:

```powershell
.\scripts\Starte-Weboberflaeche.ps1 -Port 9000 -OhneBrowser
```

Bekommt der Dienst beim Start `-Inbox`, `-Mediathek` oder `-Protokolle` mit, gelten diese
Ordner nur für die laufende Sitzung. Die Seite zeigt das an und sperrt das betroffene Feld,
damit Anzeige und Lauf nicht auseinanderlaufen.

---

## 5. Ereignisse: Urlaub, Feier, Projekt

Sollen Aufnahmen zusammenbleiben statt über Monatsordner verteilt zu werden, legt man in
der Inbox einen Ordner an und benennt ihn wie gewünscht:

```
inbox\
  2026-09_Urlaub Italien\
      IMG_1001.HEIC
      IMG_1002.HEIC
      VID_0007.mp4
```

Nach dem Import:

```
mediathek\
  Ereignisse\
    2026-09_Urlaub Italien\
        20260910_090000_IMG_1001.HEIC
        20260910_091500_IMG_1002.HEIC
        20260912_101500_VID_0007.mp4
```

Der Ordnername wird eins zu eins übernommen. Reist man über den Monatswechsel, bleibt
trotzdem alles in einem Ordner; die zeitliche Reihenfolge liefert der Datumsvorsatz im
Dateinamen.

Lose Dateien direkt in `inbox\` wandern weiterhin in die normalen Datumsordner. Beides
lässt sich in einem Lauf mischen.

---

## 6. Die Ordner

| Ordner / Datei | Bedeutung |
|---|---|
| `inbox\` | Hier kommen neue Dateien hinein. Unterordner werden zu Ereignissen. |
| `mediathek\` | Das Ergebnis. Hier nichts von Hand umbenennen. |
| `mediathek\Ereignisse\` | Die benannten Ereignisordner. |
| `protokolle\` | Ein Protokoll je echtem Lauf. |
| `config\einstellungen.json` | Standardwerte, siehe Abschnitt 9. |
| `scripts\Importiere-Medien.ps1` | Das Programm. |
| `scripts\Starte-Weboberflaeche.ps1` | Der Dienst hinter der Weboberfläche. |
| `web\index.html` | Die Seite selbst. |
| `Medien importieren.cmd` | Doppelklick-Start. |
| `Weboberflaeche starten.cmd` | Startet die Bedienoberfläche im Browser. |
| `Vorschau (aendert nichts).cmd` | Doppelklick-Vorschau. |

---

## 7. Die Regeln

Nichts wird überschrieben. Trifft eine Datei auf einen bereits belegten Zielnamen,
vergleicht das Programm den Inhalt:

- Beide Dateien sind identisch: die neue bleibt in der Inbox liegen und steht im Protokoll
  als Dublette. So lässt sich dieselbe Speicherkarte gefahrlos zweimal importieren.
- Die Dateien sind verschieden: die neue bekommt einen Zähler, etwa
  `20260910_090000_IMG_1001_1.HEIC`.

Eine Datei, die schon einmal importiert wurde und deren Name deshalb mit dem
Datumsvorsatz beginnt, bekommt keinen zweiten. Sie behält ihren Namen und wird dadurch
als Dublette erkannt, wenn sie erneut in die Inbox gerät – etwa weil sie aus der
Mediathek zurückkopiert wurde. Im Protokoll steht dann „Datum aus Dateiname".

Verglichen wird erst, wenn der Zielname schon belegt ist. Dieselbe Aufnahme unter einem
ganz anderen Namen fällt dem Programm deshalb nicht auf.

Als Aufnahmedatum gilt sonst der erste gefundene Wert aus `CreateDate`, `DateTimeOriginal`,
`ModifyDate`. Hat eine Datei keinen dieser Werte – häufig bei Screenshots, Messenger-Bildern
und Downloads – wird das Änderungsdatum der Datei genommen. Im Protokoll steht dann
„Datum aus Dateisystem".

Videozeiten werden in Ortszeit umgerechnet. Ohne diese Umrechnung würden Videos gegenüber
Fotos desselben Tages um den Zeitzonenversatz verschoben einsortiert, im Sommer also um
zwei Stunden.

Verarbeitet werden nur die Dateitypen aus der Einstellungsdatei. Alles andere bleibt
liegen. `Thumbs.db` und `desktop.ini` übergeht ExifTool ohnehin von sich aus; die landen
auch dann nicht in der Mediathek, wenn der Endungsfilter abgeschaltet ist. Andere
Nicht-Medien kennt ExifTool dagegen sehr wohl: `.txt`, `.xmp` oder `.pdf` würden ohne
Endungsfilter mitwandern.

---

## 8. Für Fortgeschrittene: der direkte Aufruf

```powershell
# Vorschau, ändert nichts und schreibt kein Protokoll
.\scripts\Importiere-Medien.ps1 -WhatIf

# Echter Lauf
.\scripts\Importiere-Medien.ps1

# Alles in einen festen Ereignisordner, egal wie die Inbox aufgebaut ist
.\scripts\Importiere-Medien.ps1 -Ereignis "2026-09_Urlaub Italien"

# Nur Drohnendateien anfassen
.\scripts\Importiere-Medien.ps1 -Praefix "DJI_"

# Unterordner nicht als Ereignis werten, sondern nach Datum einsortieren
.\scripts\Importiere-Medien.ps1 -OhneUnterordner

# Nur bestimmte Dateitypen
.\scripts\Importiere-Medien.ps1 -Erweiterungen jpg,heic,mp4

# Endungsfilter ganz abschalten
.\scripts\Importiere-Medien.ps1 -AlleDateien
```

`-OhneUnterordner` importiert die Dateien aus den Unterordnern trotzdem, nur eben in die
Datumsordner statt in einen Ereignisordner. Die dann leeren Unterordner bleiben in der
Inbox stehen; das Programm löscht in der Inbox nichts.

`-AlleDateien` ist mit Bedacht zu benutzen: Ohne Endungsfilter wandert alles mit, was
ExifTool auflistet, also auch `.txt`, `.xmp` und `.pdf`.

Selten gebraucht werden `-ExifToolPath` für einen anderen Pfad zur `exiftool.exe`,
`-EreignisOrdnerName` für einen anderen Namen des Zweigs `Ereignisse` und
`-EinstellungsDatei` für eine andere Einstellungsdatei, etwa beim Ausprobieren. Den
Parameter `-DatumsFormat` gibt es zwar auch, er sollte aber unangetastet bleiben: Ein
anderes Format läuft ohne Fehlermeldung durch, sortiert die Dateien aber falsch ein und
macht sie für `-Reorganisieren` unsichtbar.

Ordnerschema über `-Gruppierung`:

| Wert | Ergebnis |
|---|---|
| `JahrMonat` (Standard) | `mediathek\2026\2026-09\datei.jpg` |
| `Jahr` | `mediathek\2026\datei.jpg` |
| `Tag` | `mediathek\2026-09-10\datei.jpg` |
| `Keine` | `mediathek\datei.jpg` |

Die Mediathek nachträglich in ein anderes Schema umsortieren:

```powershell
.\scripts\Importiere-Medien.ps1 -Reorganisieren -WhatIf
.\scripts\Importiere-Medien.ps1 -Reorganisieren -Gruppierung Jahr
```

Die Ereignisordner werden dabei nicht umsortiert. `-Reorganisieren` zusammen mit
`-Ereignis` lehnt das Programm ab, weil das die ganze Mediathek in einen Ordner ziehen
würde.

Eine Einschränkung: Zum Schluss räumt der Lauf leere Ordner aus der Mediathek, und das
betrifft auch leere Ereignisordner. Wer einen Ereignisordner auf Vorrat anlegt und noch
nicht gefüllt hat, verliert ihn beim nächsten `-Reorganisieren`. Die Vorschau mit
`-WhatIf` löscht nichts.

Zum Ausprobieren ohne Risiko lassen sich alle Pfade einzeln umbiegen:

```powershell
.\scripts\Importiere-Medien.ps1 -Inbox C:\Test\ein -Mediathek C:\Test\aus -Protokolle C:\Test\log -WhatIf
```

---

## 9. Einstellungen

`config\einstellungen.json` enthält die Standardwerte. Das Setup legt sie beim Installieren
an und trägt die Ordner aus dem Assistenten ein. So ist die Datei aufgebaut, die Pfade
stammen aus einer Beispielinstallation und die Liste der Dateitypen ist gekürzt:

```json
{
  "Inbox": "C:\\Users\\Martin\\Pictures\\GoDigital Inbox",
  "Mediathek": "C:\\Users\\Martin\\Pictures\\GoDigital Mediathek",
  "Protokolle": "C:\\Users\\Martin\\AppData\\Local\\Programs\\GoDigital Medienimport\\protokolle",
  "Gruppierung": "JahrMonat",
  "Praefix": "",
  "Erweiterungen": ["jpg", "jpeg", "heic", "mp4", "mov"],
  "UnterordnerAlsEreignisse": true,
  "EreignisOrdnerName": "Ereignisse",
  "ExifToolPath": "C:\\Users\\Martin\\AppData\\Local\\Programs\\GoDigital Medienimport\\exiftool\\exiftool.exe",
  "VideoZeitAlsOrtszeit": true
}
```

Ein beim Aufruf angegebener Parameter hat immer Vorrang vor der Datei. Fehlt die Datei
oder ist sie fehlerhaft, erscheint eine Warnung und der Lauf geht mit den eingebauten
Standardwerten weiter – der Doppelklick-Betrieb bleibt also in jedem Fall funktionsfähig.

Die drei Ordner lassen sich am bequemsten über die Weboberfläche setzen. Die Mediathek darf
auch auf einer anderen Platte liegen, etwa `"Mediathek": "D:\\Fotoarchiv"`. Fehlen die drei
Angaben, liegen die Ordner wie bisher neben dem Programm. Den Inbox-Ordner muss es geben;
Mediathek und Protokolle werden beim ersten Lauf angelegt, sofern der übergeordnete Ordner
vorhanden ist.

Rückwärtsstriche in Pfaden müssen in JSON doppelt geschrieben werden: `D:\\Fotoarchiv`.

Inbox und Mediathek dürfen nicht derselbe Ordner sein, und keiner der beiden darf im anderen
liegen – sonst würde das Programm die bereits einsortierten Bilder bei jedem Durchgang noch
einmal einlesen. Dasselbe gilt für den Ordner, in dem das Programm selbst installiert ist: Er
darf weder die Inbox noch die Mediathek sein und in keinem von beiden liegen, sonst zählt das
Programm seine eigenen Dateien mit. Die Weboberfläche lehnt solche Angaben beim Speichern ab
und sagt, warum.

Eine leere Liste `"Erweiterungen": []` schaltet den Endungsfilter ab und wirkt wie
`-AlleDateien` – nicht etwa umgekehrt. Wer die eingebaute Liste will, lässt den Schlüssel
ganz weg. Aus demselben Grund lässt sich über die Weboberfläche nicht speichern, solange
kein einziger Dateityp angehakt ist.

---

## 10. Protokolle

Jeder echte Lauf schreibt `protokolle\protokoll_<Zeitstempel>.md`. Darin stehen die
verwendeten Einstellungen, eine Zusammenfassung und eine Tabelle mit einer Zeile je Datei:

| Status | Bedeutung |
|---|---|
| `OK` | verschoben |
| `SKIP` | übersprungen, Grund steht daneben |
| `FEHLER` | fehlgeschlagen, Meldung steht daneben |

Ein Fehler an einer einzelnen Datei bricht den Lauf nicht ab; die übrigen Dateien werden
weiter verarbeitet. In der Zusammenfassung zählt die Spalte „Übersprungen" die Fehler mit.

Bei einer Vorschau (`-WhatIf`) entsteht bewusst kein Protokoll. In der Vorschau steht in
der Zusammenfassung außerdem immer „Verschoben: 0", weil nichts verschoben wird. Was
passieren würde, steht in den Zeilen darüber, die mit `WhatIf:` beginnen. Die allerletzte
Zeile nennt trotzdem einen Protokollpfad; diese Datei wird bei einer Vorschau nicht
angelegt.

---

## 11. Gut zu wissen

ExifTool muss vorhanden sein. Das Setup legt es in den Unterordner `exiftool` der
Installation; genau dort sucht das Programm zuerst, danach im Suchpfad von Windows. Wer
einen anderen Pfad braucht, trägt ihn in den Einstellungen ein. Ohne ExifTool bricht der
Import mit einer Meldung ab. Für `-Reorganisieren` wird es nicht gebraucht. Sonst wird nichts weiter benötigt: Das in Windows enthaltene PowerShell 5.1
genügt, PowerShell 7 geht auch.

Scheitert ein direkter `.ps1`-Aufruf an der Ausführungsrichtlinie, hilft die `.cmd`
(startet mit `-ExecutionPolicy Bypass`) oder einmalig:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Der ältere `E:\Drohne-Foto-Workflow` bleibt unverändert bestehen und hat seine eigene
Mediathek. Beide Projekte arbeiten unabhängig voneinander.

---

## 12. Kurzreferenz

| Ich will … | … das tun |
|---|---|
| Normale Fotos importieren | Dateien nach `inbox\`, Doppelklick auf `Medien importieren.cmd` |
| Erst sehen, was passiert | Doppelklick auf `Vorschau (aendert nichts).cmd` |
| Alles per Formular bedienen | Doppelklick auf `Weboberflaeche starten.cmd` |
| Mediathek auf eine andere Platte legen | Weboberfläche, Reiter Einstellungen, Feld Mediathek |
| Einen Urlaub zusammenhalten | Ordner `inbox\2026-09_Urlaub Italien\` anlegen und füllen |
| Nur Drohnenbilder | `.\scripts\Importiere-Medien.ps1 -Praefix "DJI_"` |
| Anderes Ordnerschema | `.\scripts\Importiere-Medien.ps1 -Gruppierung Jahr` |
| Mediathek umsortieren | Weboberfläche, Reiter Import, unterster Haken – oder `.\scripts\Importiere-Medien.ps1 -Reorganisieren -WhatIf` |
| Nachsehen, was gelaufen ist | Neueste Datei in `protokolle\` öffnen |
