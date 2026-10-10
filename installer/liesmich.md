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

Die Versionsnummer kommt aus `VERSION` im Projektordner.

## Das Icon

`GoDigital-Medienimport.ico` ist eingecheckt und muss nur neu gebaut werden, wenn
sich das Bildzeichen ändert. Geändert wird dafür `GoDigital-Medienimport.svg`:

```powershell
.\installer\Baue-Icon.ps1
```

Das Skript rendert die SVG mit Chrome in neun Größen (16 bis 256) und setzt daraus
die `.ico` zusammen. Chrome oder Edge muss installiert sein.

## Veröffentlichen

Von Hand bauen muss man dafür nichts. Eine neue Fassung bedeutet:

1. `VERSION` auf die neue Nummer setzen.
2. `CHANGELOG.md` um den Abschnitt dieser Fassung ergänzen.
3. Beides committen.
4. `git tag v<Version> && git push --tags`

`.github\workflows\release.yml` baut daraufhin auf einem Windows-Runner, hängt die
`.exe` an ein GitHub-Release und nimmt die Release-Notizen aus dem passenden
Abschnitt von `CHANGELOG.md`. Passen Tag und `VERSION` nicht zusammen, bricht der
Lauf ab, bevor etwas veröffentlicht wird.

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
