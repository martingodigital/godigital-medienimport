# Installationsprogramm für GoDigital Medienimport

**Datum:** 2026-10-03
**Status:** Entwurf, mit dem Auftraggeber abgestimmt
**Betrifft:** neues Teilsystem `installer\`, dazu drei Korrekturen am bestehenden Motor

## Ziel

Ein Nutzer ohne IT-Kenntnisse lädt von GitHub eine einzelne Datei herunter, startet sie,
klickt durch einen deutschsprachigen Assistenten und hat danach ein lauffähiges Werkzeug:
Skripte, Weboberfläche, ExifTool, Ordner, Verknüpfungen und eine passende
Einstellungsdatei. Kein Entpacken von Hand, kein Suchen nach ExifTool, kein Bearbeiten von
Pfaden.

Als Erfolg gilt: Auf einem frischen Windows-Benutzerkonto genügen der Download, eine
SmartScreen-Bestätigung und das Durchklicken des Assistenten mit seinen Vorgaben. Kein
Entpacken, kein Pfad von Hand, kein zweiter Download.

## Nicht-Ziele

- Kein Installationsprogramm für andere Betriebssysteme. Der Motor ist Windows-PowerShell.
- Keine zentrale Software-Verteilung, kein MSI für Firmenumgebungen. Zielgruppe sind
  private Rechner, auf denen der Nutzer selbst Administrator ist.
- Keine automatische Aktualisierung des Programms. Ein Update ist ein neues Setup, das über
  die bestehende Installation läuft.
- Keine Migration aus `E:\Drohne-Foto-Workflow` oder einer bestehenden Mediathek. Wer schon
  eine Mediathek hat, trägt deren Ordner im Assistenten ein.

## Rahmenbedingungen

Abgestimmte Festlegungen, jede mit dem Grund, aus dem sie so und nicht anders ist:

**Inno Setup als Werkzeug.** Freier Compiler, der aus einer Textdatei eine einzelne
`Setup.exe` baut. Er bringt Assistentenseiten, eigene Seiten mit Pascal-Skript,
Verknüpfungen, den Eintrag unter „Apps & Features" und einen Deinstallierer fertig mit. Ein
Eigenbau in PowerShell müsste all das nachbilden.

**Installation ins Benutzerprofil, nicht nach `C:\Programme`.** Das Programm schreibt
Protokolle und Einstellungen in den eigenen Ordner. Unter `C:\Programme` darf der
angemeldete Nutzer das nicht, beides schlüge fehl. Ziel ist deshalb
`%LOCALAPPDATA%\Programs\GoDigital Medienimport`. Nebeneffekt: Windows fragt nicht nach
Administratorrechten, die Installation wird um eine Rückfrage kürzer
(`PrivilegesRequired=lowest`).

**ExifTool wird bei der Installation heruntergeladen, nicht mitgeliefert.** Das hält das
Setup bei rund einem Megabyte. Version und SHA256-Prüfsumme werden beim Bauen festgelegt;
der Installer lädt genau diese Datei und prüft sie vor dem Entpacken. Damit ist die
Installation gegen eine veränderte Datei auf dem Spiegelserver geschützt, und es ist
jederzeit bekannt, welche Fassung beim Nutzer ankommt.

**Deutschsprachiger Assistent mit mehreren Schritten.** Der Nutzer soll Mediathek und Inbox
selbst bestimmen können, weil eine Mediathek groß wird und viele sie auf eine zweite Platte
legen.

**Herausgeber:** Martin Goßner GoDigital. **Lizenz:** MIT, das Repository wird dafür
öffentlich.

## Was über ExifTool bekannt ist

Geprüft am 2026-10-03:

| Sache | Stand |
|---|---|
| Aktuelle Version | 13.59, abrufbar als Klartext unter `https://exiftool.org/ver.txt` |
| Windows-Paket | `exiftool-<ver>_64.zip`, rund 11 MB |
| Bezugsquelle | nur SourceForge: `https://sourceforge.net/projects/exiftool/files/exiftool-<ver>_64.zip/download` |
| exiftool.org direkt | liefert für die ZIP-Datei 404, scheidet aus |
| GitHub | veröffentlicht das Windows-Programm nicht |
| „latest"-Adresse | existiert nicht, der Dateiname trägt immer die Versionsnummer |

Zwei Fallen im Archiv: Die ausführbare Datei heißt `exiftool(-k).exe`. Das `-k` lässt das
Programm nach jedem Aufruf auf einen Tastendruck warten, unser Skript würde daran hängen
bleiben. Sie muss beim Entpacken in `exiftool.exe` umbenannt werden. Daneben liegt der
Ordner `exiftool_files`, der zwingend mitwandern muss; ohne ihn startet die Datei nicht.

Lizenzrechtlich ist die Weitergabe unproblematisch (Perl Artistic License beziehungsweise
GPL), die beiliegende Lizenzdatei von ExifTool wird mitinstalliert.

## Neue Dateien

```
installer\GoDigital-Medienimport.iss     Inno-Setup-Quelle, die Beschreibung des Setups
installer\Baue-Setup.ps1                 Bauskript: ermittelt Version und Prüfsumme, ruft den Compiler
installer\liesmich.md                    Wie man das Setup baut, für den Entwickler
VERSION                                  Eine Zeile, die Versionsnummer des Programms
LICENSE                                  MIT, Inhaber Martin Goßner
README.md                                Einstieg auf GitHub, Downloadlink, Voraussetzungen
```

Die Versionsnummer steht ausschließlich in `VERSION`. Bauskript und Inno-Quelle lesen sie
von dort. Eine zweite Stelle würde über kurz oder lang abweichen.

`Baue-Setup.ps1` holt `ver.txt`, lädt das ZIP-Archiv herunter, bildet die SHA256-Prüfsumme,
schreibt Version und Prüfsumme nach `installer\exiftool-fassung.txt` und ruft `ISCC.exe`
auf. Das Archiv selbst kommt nicht ins Repository und wird nach dem Bauen verworfen.
Ergebnis ist `installer\ausgabe\GoDigital-Medienimport-Setup-<version>.exe`.

## Ablauf der Installation

Die Seitenfolge des Assistenten:

1. **Willkommen.** Nennt Programm und Version.
2. **Lizenz.** MIT-Text, dazu der Hinweis auf ExifTool und dessen eigene Lizenz.
3. **Installationsordner.** Vorbelegt mit `%LOCALAPPDATA%\Programs\GoDigital Medienimport`.
4. **Ordner für Medien.** Eigene Seite mit zwei Auswahlfeldern: Mediathek, vorbelegt mit
   `%USERPROFILE%\Bilder\GoDigital Mediathek`, und Inbox, vorbelegt mit
   `%USERPROFILE%\Bilder\GoDigital Inbox`. Die Seite prüft beim Weiterblättern, dass beide
   Angaben nicht leer und nicht derselbe Ordner sind. Dieselbe Regel steckt schon in
   `Set-EinstellungenObjekt` der Weboberfläche; sie darf im Installer nicht fehlen, sonst
   richtet der Assistent eine Installation ein, die die Oberfläche später ablehnt.
5. **Verknüpfungen.** Ein Haken für die Desktop-Verknüpfung, vorausgewählt.
6. **Bereit.** Zusammenfassung aller gewählten Ordner.
7. **ExifTool holen.** Downloadseite mit Fortschrittsbalken, danach Prüfsumme und Entpacken.
8. **Installation.** Dateien kopieren, Ordner anlegen, Einstellungsdatei schreiben.
9. **Fertig.** Zwei Haken: „Weboberfläche jetzt starten" und „Anleitung öffnen", beide
   vorausgewählt.

Inno Setup ab 6.1 bringt die Downloadseite als `CreateDownloadPage` mit; eine
Fremdkomponente ist nicht nötig. Entpackt wird über die PowerShell (`Expand-Archive`), die
auf jedem Windows 10 und 11 vorhanden ist, weil deren Verfügbarkeit nicht von der
Inno-Version abhängt.

## Was auf dem Rechner landet

```
%LOCALAPPDATA%\Programs\GoDigital Medienimport\
    scripts\            Importiere-Medien.ps1, Starte-Weboberflaeche.ps1
    web\                index.html
    exiftool\           exiftool.exe, exiftool_files\, Lizenz
    config\             einstellungen.json (vom Installer erzeugt)
    protokolle\         zunächst leer, nimmt die Laufprotokolle auf
    inbox\              nur falls der Nutzer die Vorgabe nicht ändert
    Medien importieren.cmd, Vorschau (aendert nichts).cmd, Weboberflaeche starten.cmd
    ANLEITUNG.md, GoDigital-Medienimport_Anleitung-bebildert.pdf
```

Verknüpfungen: auf dem Desktop eine einzige, die die Weboberfläche startet. Im Startmenü
eine Gruppe mit vier Einträgen, dazu der Deinstallierer.

## Was der Installer schreibt

Er legt Mediathek, Inbox und `protokolle\` an und erzeugt `config\einstellungen.json` aus
den Angaben des Assistenten: die drei Ordner und `ExifToolPath` auf die mitinstallierte
Datei. Die übrigen Schlüssel kommen aus der Vorlage.

Existiert die Datei bereits, bleibt sie unverändert. Andernfalls verlöre ein Nutzer bei
einem Update seine Einstellungen. Die Schlussseite sagt in diesem Fall ausdrücklich, dass
die vorhandenen Einstellungen beibehalten wurden.

## Änderungen am bestehenden Code

Drei Korrekturen, ohne die auf einem fremden Rechner nichts läuft:

**1. Rückfallkette für ExifTool.** `E:\Exiftool\exiftool.exe` steht fest verdrahtet in
`scripts\Importiere-Medien.ps1:102` und zweimal in `scripts\Starte-Weboberflaeche.ps1`
(Zeilen 286 und 388). Neue Reihenfolge: Parameter, dann Einstellungsdatei, dann
`exiftool\exiftool.exe` neben dem Programm, dann der Suchpfad, dann der bisherige Wert als
letzter Rückfall. Die bestehende Installation auf `E:` läuft unverändert weiter, weil ihre
Einstellungsdatei den Pfad ohnehin setzt.

**2. `config\einstellungen.json` aus der Versionierung nehmen.** Die Datei trägt vier
absolute `E:`-Pfade und greift laut der dokumentierten Rangfolge vor den eingebauten
Standardwerten. Jeder Klon und jedes Setup lieferte diese Pfade mit aus. Sie wird per
`git rm --cached` aus dem Repository genommen (die lokale Datei bleibt liegen), `.gitignore`
bekommt einen Eintrag, und an ihre Stelle tritt `config\einstellungen.vorlage.json` mit
leeren Ordnerangaben.

**3. Versionsnummer.** Neue Datei `VERSION` mit `1.0.0`. Das Importskript nennt sie im
Protokollkopf, damit aus einem Protokoll hervorgeht, welche Fassung gelaufen ist.

Dazu die Dokumentation: `CLAUDE.md` bekommt einen Abschnitt zum Installer, `ANLEITUNG.md`
und die bebilderte Anleitung beschreiben die Installation aus Nutzersicht. Die bebilderte
Anleitung wird über die HTML-Quelle geändert und neu nach PDF gedruckt.

## Fehlerfälle

| Fall | Verhalten |
|---|---|
| Download scheitert oder Prüfsumme stimmt nicht | Der Assistent bietet an, es erneut zu versuchen oder eine vorhandene `exiftool.exe` auf dem Rechner auszuwählen. Hilft beides nicht, bricht die Installation mit einer verständlichen Meldung ab, statt ein halbfertiges Programm zu hinterlassen. |
| Gewählter Mediathek-Ordner nicht beschreibbar | Prüfung auf der Ordnerseite, Hinweis, kein Weiterblättern. |
| Mediathek und Inbox gleich | Dasselbe. |
| Einstellungsdatei vorhanden | Bleibt unverändert, Hinweis auf der Schlussseite. |
| Kein Internet | Der Download scheitert, siehe erster Fall. |
| SmartScreen | Nicht abwendbar ohne Code-Signing-Zertifikat. Wird mit Bild in der Anleitung und im Release-Text beschrieben. |

## Deinstallation und Updates

Der Deinstallierer entfernt den Programmordner samt ExifTool und die Verknüpfungen.
Mediathek, Inbox und Protokolle rührt er nicht an, und er sagt das auch: Wer Windows kennt,
rechnet an dieser Stelle mit dem Schlimmsten.

Ein neues Setup über eine bestehende Installation ist ein Update. Die `AppId` bleibt
gleich, Dateien werden ersetzt, Einstellungen und Medien bleiben.

## Veröffentlichung über GitHub

Das Repository `martingodigital/godigital-medienimport` wird öffentlich und bekommt eine
MIT-Lizenzdatei. Das fertige Setup hängt als Anhang an einem Release mit dem Tag `v1.0.0`.
Die `README.md` entsteht neu und nennt oben den Downloadlink, die Systemvoraussetzungen und
den SmartScreen-Hinweis.

Nicht veröffentlicht werden Medien, Laufprotokolle und die lokale Einstellungsdatei; dafür
sorgt die bestehende `.gitignore` samt der oben beschriebenen Ergänzung.

## Prüfung

Automatisierte Tests gibt es im Projekt nicht, und ein Installationsprogramm prüft sich
ohnehin nur auf einem unberührten System sinnvoll. Vorgesehen ist eine Durchlaufliste,
abgearbeitet auf einem zweiten Windows-Benutzerkonto oder, besser, in einer virtuellen
Maschine:

1. Setup starten, SmartScreen bestätigen, Standardvorgaben durchklicken.
2. Protokollkopf nach dem ersten Lauf prüfen: Stehen dort die Ordner aus dem Assistenten?
3. Installation in einen Pfad mit Leerzeichen und Umlauten wiederholen.
4. Vorschau über die `.cmd`, danach echter Import mit zwei Testbildern.
5. Weboberfläche starten, Einstellungen speichern, Protokoll ansehen.
6. Deinstallieren und prüfen, dass Mediathek, Inbox und Protokolle erhalten bleiben.
7. Erneut installieren und prüfen, dass die Einstellungsdatei unverändert bleibt.
8. Nach jedem Schritt notieren, ob Windows Defender eingreift.

Zusätzlich gilt die Hausregel des Projekts: alles unter Windows PowerShell 5.1 prüfen, nicht
nur unter PowerShell 7.

## Annahmen

- Der Nutzer ist auf seinem Rechner Administrator. Die Installation braucht das zwar nicht,
  die SmartScreen-Bestätigung unter Umständen schon.
- Windows 10 oder 11 mit vorhandener Windows PowerShell 5.1. Beides ist seit Windows 10 Teil
  des Systems.
- Der Baurechner hat Internetzugang und Inno Setup 6.1 oder neuer. Auf dem Entwicklungs-PC
  ist Fassung 6.7.3 installiert, der Compiler liegt unter
  `%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe`. Das Bauskript sucht ihn dort und in den
  beiden Programmordnern, statt den Pfad fest zu verdrahten.
- SourceForge hält auch ältere ExifTool-Fassungen weiter vor. Trifft das für eine beim Bauen
  festgelegte Version einmal nicht zu, hilft ein neuer Baustand.
