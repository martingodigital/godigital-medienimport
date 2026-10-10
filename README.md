# GoDigital Medienimport

[![Aktuelle Fassung](https://img.shields.io/github/v/release/martingodigital/godigital-medienimport?label=Download&color=2b7a4b)](https://github.com/martingodigital/godigital-medienimport/releases/latest)
[![Lizenz](https://img.shields.io/badge/Lizenz-MIT-blue)](LICENSE)

Fotos und Videos nach ihrem Aufnahmedatum umbenennen und in eine chronologisch
sortierte Mediathek einsortieren. Für Windows, ohne Administratorrechte.

## Herunterladen

### [Setup herunterladen (Windows)](https://github.com/martingodigital/godigital-medienimport/releases/latest)

Auf der Release-Seite die Datei `GoDigital-Medienimport-Setup-<Version>.exe`
anklicken. Rund 2 MB.

## Installieren

1. Die heruntergeladene Datei starten.
2. Windows zeigt beim ersten Start den blauen Hinweis „Der Computer wurde durch
   Windows geschützt". Auf **Weitere Informationen** klicken, dann auf
   **Trotzdem ausführen**. Der Hinweis kommt, weil das Setup keine gekaufte
   Signatur trägt, nicht weil etwas damit nicht stimmt.
3. Durch den Assistenten klicken. Die Vorgaben passen für die meisten.

Das Setup braucht keine Administratorrechte und installiert ins Benutzerprofil.
Während der Installation wird [ExifTool](https://exiftool.org/) geladen (rund 11 MB),
dafür ist einmalig eine Internetverbindung nötig.

## Was das Programm macht

Aus einem Durcheinander von Handyfotos, Kamerabildern und Drohnenaufnahmen wird
eine Mediathek, in der die Dateinamen von selbst chronologisch sortieren:

```
inbox\IMG_1001.JPG          →  mediathek\2026\2026-09\20260910_101530_IMG_1001.JPG
inbox\Italien\DJI_0042.MP4  →  mediathek\Ereignisse\Italien\20260912_164500_DJI_0042.MP4
```

Das Aufnahmedatum kommt aus den Metadaten der Datei, nicht aus dem Dateidatum.
Bedient wird alles über eine Oberfläche im Browser, die nur auf dem eigenen
Rechner läuft. Vor jedem Import lässt sich eine Vorschau ansehen; überschrieben
wird nie etwas.

![Die Weboberfläche mit Lageband, Kennzahlen und den Einstellungen für den
nächsten Lauf](docs/weboberflaeche.png)

## Anleitung

- [Bebilderte Anleitung (PDF)](docs/GoDigital-Medienimport_Anleitung-bebildert.pdf) –
  für den Einstieg, mit Zeichnungen. Das Setup legt sie auch ins Startmenü.
- [ANLEITUNG.md](ANLEITUNG.md) – ausführlich, alle Einstellungen und Sonderfälle.

## Voraussetzungen

- Windows 10 oder 11
- Windows PowerShell 5.1 (seit Windows 10 Teil des Systems)

## Selbst bauen

Das Setup entsteht mit Inno Setup 6 aus diesem Repository; die Schritte stehen in
[installer/liesmich.md](installer/liesmich.md). Jeder Tag `v<Version>` löst den
Bau außerdem automatisch aus und hängt die fertige Datei an ein Release.

## Lizenz

MIT, siehe [LICENSE](LICENSE). Mitgeliefert wird ExifTool von Phil Harvey unter
eigener Lizenz (Perl Artistic License / GPL).
