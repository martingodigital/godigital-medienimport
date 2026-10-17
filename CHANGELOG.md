# Änderungen

Die Versionsnummer steht in `VERSION`; diese Datei sagt, was dahintersteckt.
Ein Tag `v<Version>` löst den Bau des Setups aus.

## 1.3.0 – 2026-10-17

Zwei Rückmeldungen aus dem Betatest (R-19, R-20).

- Beim Installieren bewegt sich der Fortschrittsbalken wieder. ExifTool wird jetzt auf
  einer eigenen Seite des Assistenten geladen, die einen laufenden Balken mitbringt.
  Bisher lief der Download in einem Abschnitt, in dem Balken und Statustext gar nicht
  zu sehen sind — das Setup sah aus, als hänge es. Beim Entpacken sagt es nun ebenfalls,
  was es tut. Die stille Installation (`/VERYSILENT`) lädt unverändert ohne Seite.
- Die Weboberfläche hat einen Knopf zum Aktualisieren, links neben „Vorschau". Die Zahlen
  kamen seit 1.2.0 nur von selbst, wenn das Fenster wieder nach vorn kam; wer es gar nicht
  verließ, musste die ganze Seite neu laden und verlor dabei Vorschau und Ergebnistabelle.

## 1.2.0 – 2026-10-16

Aus dem Betatest: sechs Stellen, an denen das Programm etwas anderes sagte, als es tat
oder meinte (R-06 bis R-09, R-12, R-13, R-16).

- Die Vorschau sagt jetzt dasselbe wie der echte Lauf. Lagen zwei gleiche Aufnahmen im
  selben Lauf, kündigte sie für die zweite einen Zähler an, während der Lauf sie als
  Dublette übersprang.
- Dateien ohne Aufnahmedatum sind als solche zu erkennen — schon in der Vorschau, mit
  der Marke „Datum geschätzt", und als Zahl unter der Zusammenfassung. Bisher stand das
  nur im Protokoll, und ein geschätztes Datum sah aus wie ein echtes.
- Die Ergebnistabelle hat eine eigene Spalte für das Ziel. Vorher stand der Zielpfad in
  der Spalte „Grund".
- Das Lageband unterscheidet zwischen Dateien in der Inbox und Dateien, die der Import
  anfasst. Nach einem vollständigen Lauf meldete die Seite bisher weiter wartende
  Dateien, obwohl nur Textdateien und Beidateien liegen geblieben waren.
- Die Seite holt ihre Zahlen selbst, sobald das Fenster wieder nach vorn kommt.
- Das Protokoll wird im Reiter Protokolle gesetzt dargestellt, nicht mehr als
  Markdown-Quelltext.
- Eine Vorschau endet nicht mehr mit „Verschoben: 0" und einem Protokollpfad, den es
  nicht gibt, sondern mit der Zahl der Dateien, die verschoben würden.

## 1.1.0 – 2026-10-11

Aus dem Betatest: Ein Lauf mit 480 großen Bildern sah aus, als hänge das Programm.

- Der Lauf sagt jetzt, woran er ist. Die beiden Schritte heißen „Metadaten lesen"
  und „einsortieren"; beim Einsortieren läuft ein Fortschrittsbalken mit dem
  Namen der aktuellen Datei mit. Der erste Schritt war bisher stumm und dauert
  bei vielen Dateien am längsten.
- Am Ende des Laufs und im Protokollkopf stehen die Zeiten je Schritt, die bewegte
  Datenmenge und der Durchsatz. Damit lässt sich eine Rückmeldung wie „dauert
  ewig" nachrechnen.
- Liegen Inbox und Mediathek auf verschiedenen Laufwerken, sagen das jetzt sowohl
  der Lauf als auch die Weboberfläche, und zwar vorher. Jede Datei muss dann
  kopiert und danach gelöscht werden statt nur umbenannt; das ist der Unterschied
  zwischen Sekunden und Minuten.

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
