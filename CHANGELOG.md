# Änderungen

Die Versionsnummer steht in `VERSION`; diese Datei sagt, was dahintersteckt.
Ein Tag `v<Version>` löst den Bau des Setups aus.

## 1.0.0 – 2026-10-10

Erste veröffentlichte Fassung.

- Import nach Aufnahmedatum: Fotos und Videos werden in einem Schritt umbenannt
  und nach `<Jahr>\<Jahr-Monat>\` einsortiert. Das Datum kommt aus den
  Metadaten, mit Rückfall auf den Dateinamen und zuletzt auf das Dateidatum.
- Videozeiten werden von UTC in Ortszeit umgerechnet, damit sie neben den Fotos
  desselben Tages richtig einsortieren.
- Unterordner der Inbox werden zu benannten Ereignissen unter
  `mediathek\Ereignisse\`.
- Überschrieben wird nie: Bei gleichem Zielnamen entscheidet ein Inhaltsvergleich
  zwischen Dublette und einem Zähler im Namen.
- Vorschau über `-WhatIf`, die nichts verändert, und ein Markdown-Protokoll nach
  jedem echten Lauf.
- Weboberfläche auf `127.0.0.1` mit Vorschau, Einstellungen und Protokollansicht.
  Jeder Aufruf verlangt ein Token, das beim Start erzeugt wird.
- Bestehende Mediathek nachträglich umsortieren über `-Reorganisieren`.
- Installationsprogramm für Windows ohne Administratorrechte. ExifTool wird
  während der Installation geladen und mit Prüfsumme verglichen.
- Eigenes Programmsymbol auf dem Setup, den Verknüpfungen und dem Eintrag in
  „Apps & Features".
- Bebilderte Anleitung als PDF, dazu `ANLEITUNG.md` für die Einzelheiten.
