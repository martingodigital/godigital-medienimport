---
name: anwenderdoku-pdf
description: "Stil und Bauweise für bebilderte Anwenderdokumentation als PDF (Handbuch, Kurzanleitung, Einführung, Schulungsunterlage) für Leser ohne IT-Kenntnisse. Nutzen, wenn jemand eine Doku, Anleitung oder Übersicht als PDF oder Word-Dokument mit Illustrationen möchte, oder wenn eine vorhandene technische Doku in eine Fassung für Anwender überführt werden soll. Beschreibt Aufbau, Layout, Sprache und die Erzeugung über HTML mit eingebetteten SVG-Zeichnungen und den Chrome-Druck nach A4."
---

# Bebilderte Anwenderdokumentation als PDF

Kopie der Skill `anwenderdoku-pdf` aus `~/.claude/skills/anwenderdoku-pdf/SKILL.md`, Stand
2026-09-25. Maßgeblich ist die Datei dort; diese Kopie liegt hier zum Nachlesen im Projekt.
Nach dieser Vorlage ist `docs\GoDigital-Medienimport_Anleitung-bebildert.pdf` gebaut.

Für Dokumente, die jemand ohne Programmier- und IT-Kenntnisse allein verstehen soll. Die
technische Fassung (README, CLAUDE.md, Entwicklerdoku) bleibt davon unberührt und wird nicht
ersetzt.

## Bauweise

HTML mit eingebetteten SVG-Zeichnungen schreiben, daraus ein A4-PDF drucken:

```bash
chrome.exe --headless=new --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="doku.pdf" "file:///.../doku.html"
```

Kein Markdown-nach-PDF-Umweg und keine externen Bilddateien: Alles steht in einer Datei,
die Zeichnungen bleiben als Vektor scharf. Die HTML-Quelle aufbewahren, sonst lässt sich das
PDF später nur neu bauen.

## Layout

- `@page { size: A4; margin: 18mm 16mm 16mm 16mm; }`, Fließtext 11pt, Zeilenhöhe 1.55,
  Schriftfamilie Segoe UI mit Fallback.
- Eine Akzentfarbe für alles (bewährt: `#14607a`), dazu Grau für Nebentext, Grün/Gelb/Rot
  nur für Hinweiskästen und Statusfarben.
- Titelblock mit Dokumentnamen, einer Zeile Untertitel, Stand und Verweis auf die technische
  Fassung. Kein eigenes Deckblatt.
- Abschnitte nummeriert, `h2` mit Trennlinie darüber und der Nummer in der Akzentfarbe.
- Grafiken als `figure` mit Bildunterschrift „**Bild N:** …“, die für sich allein
  verständlich ist.
- Hinweiskästen mit farbigem Balken links: neutral für Erklärungen, grün für nützliche
  Kniffe, gelb für Warnungen. Jeder Kasten bekommt eine fette Kopfzeile.
- Zwei Tabellenformen: „Begriff – Bedeutung“ und „Das sehen Sie – das steckt dahinter“.
- Letzter Abschnitt ist ein Spickzettel: „Ich möchte … / … so geht es“.

## Sprache

Deutsch, sachlich, ohne Werbesprache und ohne Emojis. Zusätzlich gelten die Regeln der
Skill `vermenschlichen`.

- Keine Kommandozeilenaufrufe, keine Parameter, keine Konfigurationsdateien im Anwenderteil.
  Alles über Doppelklick, Menü oder Formular beschreiben.
- Fachwörter ersetzen: Skript wird Programm, Log wird Bericht, Verzeichnis wird Ordner.
- Ein Fachwort bleibt nur stehen, wenn es genau so auf dem Bildschirm oder in einer
  Fehlermeldung erscheint, und wird dann an Ort und Stelle erklärt.
- Leser mit „Sie“ ansprechen, wo eine Handlung gefragt ist.
- Reihenfolge: erst wozu das Ganze gut ist, dann der Normalfall, dann Sonderfälle, dann was
  bei Störungen zu tun ist, zum Schluss der Spickzettel.
- Grenzen und Stolperfallen offen benennen, statt sie wegzulassen.

## Zeichnungen

Faustregel: eine Zeichnung je Abschnitt, die etwas zeigt, das ein Satz schlecht erklärt.
Bewährt haben sich Ablauf mit Pfeilen, Vorher-Nachher nebeneinander, die Anatomie eines
Namens mit Klammern und Beschriftung, ein schematischer Nachbau der Bedienoberfläche, ein
Entscheidungsdiagramm mit Ja/Nein-Zweigen und Varianten nebeneinander als Kacheln.

Handwerkliches: Schrift in SVG nie unter 10px, Text von Hand umbrechen (SVG bricht nicht
selbst um), auf die Breite der `viewBox` achten, sonst wird abgeschnitten, und Beschriftungen
nicht überlappen lassen.

## Prüfen vor der Abgabe

Das PDF seitenweise als Bild rendern und wirklich ansehen:

```bash
python -m pip install pypdfium2
python -c "import pypdfium2 as p; d=p.PdfDocument('doku.pdf'); [d[i].render(scale=1.6).to_pil().save(f'seite{i+1}.png') for i in range(len(d))]"
```

Geprüft wird: abgeschnittener oder überlappender Text in den SVGs, halb leere Seiten,
Tabellenüberschriften allein am Seitenende, Grafiken ohne Bezug zum Text. Dagegen helfen
`figure, .kasten { page-break-inside: avoid }`, `tr { page-break-inside: avoid }` und
`tr:first-child { page-break-after: avoid }`. Erzwungene Seitenumbrüche sparsam setzen, sie
hinterlassen schnell eine halb leere Seite.

Zum Schluss das Dokument aus der Sicht eines Anwenders ohne IT-Kenntnisse lesen und
berichten, welche Begriffe stehen geblieben sind und warum.
