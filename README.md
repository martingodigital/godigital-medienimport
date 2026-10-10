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
