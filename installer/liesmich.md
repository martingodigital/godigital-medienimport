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
