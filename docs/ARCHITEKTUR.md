# Architektur und Begründungen

Diese Datei trägt die Einzelheiten, die `CLAUDE.md` nur in einer Zeile nennt: warum der
Code so aussieht, welche Fallen darin stecken und was beim Ändern mitgeändert werden muss.
`CLAUDE.md` bleibt die kurze Handreichung und verweist für jeden Abschnitt hierher.

Maßgeblich ist der Code. Weicht diese Datei davon ab, ist sie veraltet – dann bitte hier
nachziehen, nicht den Code daran anpassen.

## Inhalt

- [Einstellungen](#einstellungen)
- [Modus Inbox (Standard)](#modus-inbox-standard)
- [Modus -Reorganisieren](#modus--reorganisieren)
- [Gemeinsame Teile beider Modi](#gemeinsame-teile-beider-modi)
- [Ergebnisse, Fortschritt und Zeiten](#ergebnisse-fortschritt-und-zeiten)
- [Weboberfläche](#weboberfläche)
- [Installationsprogramm](#installationsprogramm)
- [Der Prozess im Einzelnen](#der-prozess-im-einzelnen)
- [Prüfen und Testen](#prüfen-und-testen)

Das Importskript hat zwei Modi, die sich denselben Protokoll- und Zusammenfassungs-Code
teilen. Die Verzweigung liegt bei `if ($Reorganisieren)`.

## Einstellungen

`Get-Einstellungen` liest `config\einstellungen.json` per `ConvertFrom-Json`,
`Get-Einstellung` holt einzelne Werte mit Rückfall auf den eingebauten Standard. Die
Rangfolge ist: ausdrücklich übergebener Parameter, dann Datei, dann eingebauter Standard.
Ob ein Parameter ausdrücklich kam, entscheidet `$PSBoundParameters.ContainsKey(...)` – ohne
diese Prüfung ließe sich ein Parameter-Default nicht von einer bewussten Angabe
unterscheiden. Eine fehlende oder kaputte Datei erzeugt nur eine Warnung; der
Doppelklick-Betrieb darf daran nie scheitern.

Das Skript liest genau diese zehn Schlüssel:

| Schlüssel | Typ | Eingebauter Standard | Parameter |
|---|---|---|---|
| `Inbox` | string | `<Root>\inbox` | `-Inbox` |
| `Mediathek` | string | `<Root>\mediathek` | `-Mediathek` |
| `Protokolle` | string | `<Root>\protokolle` | `-Protokolle` |
| `Gruppierung` | string | `JahrMonat` | `-Gruppierung` |
| `Praefix` | string | `""` | `-Praefix` |
| `Erweiterungen` | string[] | 22 Endungen, siehe `$standardErweiterungen` | `-Erweiterungen` |
| `UnterordnerAlsEreignisse` | bool | `true` | `-OhneUnterordner` (invertiert) |
| `EreignisOrdnerName` | string | `Ereignisse` | `-EreignisOrdnerName` |
| `ExifToolPath` | string | `E:\Exiftool\exiftool.exe` | `-ExifToolPath` |
| `VideoZeitAlsOrtszeit` | bool | `true` | keiner, nur über die Datei |

Die drei Ordner sind ein Sonderfall: Sie werden **nach** dem Lesen der Datei gesetzt, nicht
oben bei den übrigen Pfaden, weil sie aus der Datei kommen dürfen. `Get-Ordnerpfad` setzt
die Rangfolge Parameter > Datei > Ordner neben dem Skript um und löst einen relativen Pfad
gegen `$Root` auf, damit `..\Fotos` nicht vom Arbeitsverzeichnis des Aufrufers abhängt. Ein
leerer Wert in der Datei zählt wie ein fehlender. `-EinstellungsDatei` bleibt der einzige
Pfad, der nur über die Kommandozeile geht – er muss feststehen, bevor die Datei gelesen
werden kann.

`config\einstellungen.json` liegt **nicht** im Repository: Sie trägt absolute Pfade eines
Rechners und greift vor den eingebauten Standardwerten, ein Klon zeigte sonst ins Leere.
Versioniert ist `config\einstellungen.vorlage.json` mit leeren Ordnerangaben – ein leerer
Wert zählt wie ein fehlender, ein Klon landet damit bei den Ordnern neben dem Skript. Der
Installer macht aus der Vorlage die echte Datei und trägt die Ordner aus dem Assistenten
ein; eine vorhandene Datei fasst er nicht an.

Der leere `ExifToolPath` der Vorlage ist der Grund für je eine zusätzliche Zeile in beiden
Skripten: `Get-Einstellung` prüft auf `$null`, ein leerer String kommt also durch. Ohne
diese Zeile bräche ein Lauf mit „ExifTool nicht gefunden: " ohne Pfad ab.

Wer einen Schlüssel ergänzt, braucht dafür eine eigene `Get-Einstellung`-Zeile – die Datei
wird nicht automatisch auf Parameter abgebildet.

`"Erweiterungen": []` schaltet den Endungsfilter **ab** und wirkt damit wie `-AlleDateien`.
`Get-Einstellung` prüft auf `$null -ne $wert`, und ein leeres Array ist nicht `$null`, kommt
also durch. Danach ist die Filterbedingung `-not $AlleDateien -and $Erweiterungen -and
$Erweiterungen.Count -gt 0` falsch, und der Filter entfällt; das Protokoll vermerkt
„Endungsfilter: keiner". Geprüft mit einer `liesmich.txt` in der Inbox: sie wird dann zum
Verschieben eingeplant. Wer die eingebaute Liste will, lässt den Schlüssel ganz weg statt
ihn auf `[]` zu setzen. Der Vergleich trimmt auf beiden Seiten führende Punkte, `".jpg"`
funktioniert in der Datei also genauso wie `"jpg"`.

Vorsicht bei `$Gruppierung`: Das `[ValidateSet]` der Variablen wirkt auch bei *späteren*
Zuweisungen. Ein ungültiger Wert aus der JSON-Datei würde beim Zuweisen eine rohe
PowerShell-Fehlermeldung werfen, deshalb wird der Wert vorher geprüft und nur bei Treffer
zugewiesen. Neue Parameter mit `ValidateSet` brauchen dieselbe Behandlung.

## Modus Inbox (Standard)

ExifTool wird **einmal für den ganzen Inbox-Ordner** aufgerufen, immer mit `-r`. Ein
Prozessstart statt einer pro Datei ist die zentrale Optimierung; sie darf nicht aufgeweicht
werden.

Abgefragt werden `-CreateDate -DateTimeOriginal -ModifyDate -FileName -Directory` und
`-FileSize#`, das Datum formatiert ExifTool selbst über `-d` – das Skript parst keine
Datumsstrings, es gibt bewusst kein `ParseExact`. Das `#` an `-FileSize` ist Pflicht: ohne
das Zeichen liefert ExifTool `"7.7 MB"` als Text statt der Bytezahl. Damit steht die
Datenmenge des Laufs ohne eine einzige zusätzliche Dateiabfrage fest.

Der Aufruf verwirft stderr mit `2>$null`; Warnungen von ExifTool zu einzelnen Dateien sieht
niemand. Wer einem Verdacht nachgeht, ruft ExifTool von Hand ohne diese Umleitung auf.

`-api QuickTimeUTC=1` rechnet Videozeiten von UTC in Ortszeit um. Ohne diese Option
sortieren sich Videos gegenüber Fotos desselben Tages um den Zeitzonenversatz verschoben
ein (im Sommer zwei Stunden). Genau dieser Fehler steckt im Altbestand des
Vorgängerprojekts. Abschaltbar über `"VideoZeitAlsOrtszeit": false`.

`$e.Directory` kommt aus ExifTool **mit Schrägstrichen** (`E:/.../inbox/Handy`). Jeder
Pfadvergleich muss vorher `-replace '/','\'` anwenden, sonst schlägt er fehl. Aus demselben
Grund wird die Quelldatei aus `$e.Directory` zusammengesetzt und nicht aus `$Inbox`.

Fallback-Reihenfolge des Datums ist `CreateDate` → `DateTimeOriginal` → `ModifyDate` →
Änderungsdatum der Datei. Der letzte Schritt ist neu gegenüber dem Vorgängerprojekt und
nötig, weil Screenshots und Messenger-Bilder oft gar kein EXIF haben; er wird im Protokoll
als „Datum aus Dateisystem" vermerkt.

**Der eigene Programmordner.** Liegt `$Root` innerhalb der Inbox, werden seine Dateien
still übergangen und der Lauf gibt dazu einen Hinweis aus. Ohne diese Sperre zählt und
verschiebt der Import seine eigene Installation mit – bei `-AlleDateien` samt ExifTool und
den eigenen Skripten; geprüft, dabei landeten `perl532.dll` und `liesmich.txt` in
`Ereignisse\Programm\`. Nur diese eine Richtung wird ausgeschlossen: Im Projektordner liegt
die Inbox umgekehrt **unter** `$Root`, dort darf nichts übergangen werden. Dieselbe Regel
steht im Assistenten (gegen `WizardDirValue`) und in `Set-EinstellungenObjekt`; `Get-Lage`
rechnet die Dateien aus der Zählung heraus und meldet `programmInDerInbox`, damit die Seite
warnen kann, statt eine stillschweigend richtige Zahl zu zeigen.

**Bereits benannte Dateien.** Trägt der Dateiname schon einen Datumsvorsatz, gilt dieser als
Aufnahmedatum und das Skript stellt keinen zweiten voran. Ohne diese Regel bekäme eine
zurückgelegte Datei einen neuen Zielnamen, die Kollisionsprüfung liefe nie an, und dieselbe
Aufnahme läge zweimal in der Mediathek. Im Protokoll steht dann „Datum aus Dateiname".
Geprüft wird gegen `$datumsVorsatzMuster` – dieselbe Variable, gegen die auch
`-Reorganisieren` filtert, damit die beiden Modi nicht auseinanderlaufen. Das Muster prüft
Monat, Tag und Uhrzeit auf Plausibilität, ein Name wie `12345678_901234_x.jpg` fällt deshalb
auf das EXIF zurück und bekommt einen normalen Vorsatz.

Umbenennen und Verschieben passieren in **einem** `Move-Item`.

**`-OhneUnterordner` schaltet nur die Ereignis-Zuordnung ab, nicht die Rekursion.** `$label`
bleibt dann leer und die Dateien aus den Unterordnern landen im Datumsbaum (geprüft). Das
`-r` im ExifTool-Aufruf hing früher an dieser Einstellung; ohne Rekursion sah ExifTool die
Unterordner gar nicht und ihre Dateien blieben unbemerkt in der Inbox liegen. Wer an den
ExifTool-Argumenten arbeitet, darf `-r` deshalb nicht wieder an eine Bedingung hängen. Leere
Inbox-Unterordner bleiben in beiden Fällen stehen: in der Inbox löscht das Skript nichts.

## Modus -Reorganisieren

Liest **keine** Metadaten. Er nimmt Dateien in der Mediathek, deren Name auf
`$datumsVorsatzMuster` passt, und leitet den Zielordner aus dem Namenspräfix ab. Der
Dateiname ist hier die einzige Wahrheit. Der `Ereignisse`-Zweig ist ausgenommen: seine
Ablage folgt nicht dem Dateinamen, ein Umsortieren würde die Ereignisse stillschweigend
auflösen. `-Reorganisieren` zusammen mit `-Ereignis` bricht deshalb mit `exit 1` ab.

Am Ende räumt der Modus leere Unterordner unterhalb von `mediathek\` per `Remove-Item
-Recurse -Force` weg; das ist die einzige löschende Operation im Skript. Dieses Aufräumen
umfasst auch den `Ereignisse`-Zweig: die Ausnahme oben gilt nur für das Verschieben. Ein
leerer, von Hand angelegter Ereignisordner verschwindet also (geprüft). Bei `-WhatIf` bleibt
er stehen, weil `Remove-Item` selbst ShouldProcess unterstützt.

## Gemeinsame Teile beider Modi

**`Get-Unterordner`** bekommt einen Datumspräfix (`yyyyMMdd_HHmmss`) und das Schema und
liefert den relativen Unterordner. Beide Modi rufen sie auf, deswegen ergibt sich dasselbe
Layout, egal ob eine Datei frisch aus der Inbox kommt oder nachträglich umsortiert wird.
Eine Schema-Änderung gehört ausschließlich in diese Funktion. Der Ereignis-Zweig entsteht
**daneben**, nicht darin.

**`-DatumsFormat`** ist an drei weitere Stellen gekoppelt und deshalb praktisch
unveränderlich: an den Fallback `LastWriteTime.ToString("yyyyMMdd_HHmmss")`, an die Regex
`^(\d{4})(\d{2})(\d{2})` in `Get-Unterordner` und an `$datumsVorsatzMuster`, das beide Modi
auswerten. Ein anderes Format läuft ohne Fehlermeldung durch, sortiert die Dateien aber
falsch ein und macht sie für `-Reorganisieren` unsichtbar. Wer es ändert, ändert alle vier
Stellen.

**`Get-QuellLabel`** leitet den Ereignisnamen aus dem Inbox-Unterordner ab, indem sie den
Inbox-Pfad vorne abschneidet. Sie normalisiert dafür die Schrägstriche aus ExifTool und
vergleicht die Präfixe von Hand: `[System.IO.Path]::GetRelativePath` gibt es in
PowerShell 5.1 nicht.

**`Test-GleicheDatei`** vergleicht erst die Länge, dann SHA256 – ein Hash über eine große
Videodatei kostet sonst unnötig Zeit. Die Funktion nutzt bewusst `System.IO` und
`System.Security.Cryptography` statt `Get-Item`/`Get-FileHash`: die Cmdlets melden unter
Windows PowerShell 5.1 bei `-WhatIf` ihre Provider-Zugriffe und verrauschen die Vorschau.
Neue rein lesende Prüfungen bitte genauso bauen.

**Kollisionen** führen nie zum Überschreiben. Verglichen wird mit der Datei am Ziel, wenn
es sie schon gibt – sonst mit der Quelldatei, die denselben Zielnamen in diesem Lauf
belegt hat (`$geplanteQuelle`, Zielname → Quellpfad). Der zweite Fall tritt nur in der
Vorschau auf, wo noch nichts verschoben wurde. Ohne ihn kündigte die Vorschau für zwei
gleiche Dateien im selben Lauf einen Zähler an, während der echte Lauf die zweite als
Dublette übersprang – die Vorschau sagte also etwas anderes, als dann geschah, und genau
auf ihr beruht das Vertrauen in das Programm.

Der Inhalt wird allerdings erst verglichen, wenn der **Zielname** belegt ist; eine Dublette
unter anderem Namen erkennt das Skript nicht. Deshalb ist die Regel zu den bereits benannten Dateien oben kein Schönheitsfix,
sondern Voraussetzung dafür, dass ein zweiter Import überhaupt als Dublette auffällt.
Identische Datei: `SKIP` mit Grund „Dublette, identische Datei vorhanden". Verschiedene
Datei: `Get-FreierZielName` hängt einen Zähler an, bis `_999`; danach gibt sie auf, und die
Datei wird als `FEHLER` mit Grund „kein freier Zielname gefunden" protokolliert. Ein
`HashSet` `$geplanteZiele` verhindert, dass zwei Quelldateien in derselben Vorschau auf
denselben Zielnamen zeigen.

**Pfade** werden aus `Split-Path -Parent $PSScriptRoot` abgeleitet. Das Skript muss also in
`scripts\` liegen. `-Inbox`, `-Mediathek`, `-Protokolle` und `-EinstellungsDatei`
überschreiben das jeweils einzeln.

**`-WhatIf`** kommt aus `[CmdletBinding(SupportsShouldProcess)]`. `$WhatIfPreference` wirkt
automatisch auch auf das abschließende `Set-Content`, deshalb entsteht bei einer Vorschau
kein Protokoll – das ist gewollt, nicht vergessen. Neue schreibende Aktionen müssen entweder
in einen `ShouldProcess`-Block oder ein Cmdlet nutzen, das ShouldProcess selbst unterstützt.

Was eine Vorschau **nicht** zeigt: `OK`-Einträge entstehen erst innerhalb von
`ShouldProcess`, also nur im echten Lauf. Eine Vorschau meldet deshalb immer
„Verschoben: 0" und sammelt in `$ergebnisse` nur `SKIP` und `FEHLER` (geprüft). Was
verschoben würde, steht ausschließlich in den `WhatIf:`-Zeilen von PowerShell. Die
Weboberfläche muss die Vorschau aus diesen Zeilen lesen, nicht aus der Zusammenfassung.

Dabei zwei Fallen, beide geprüft. Die Schlusszeile nennt auch bei `-WhatIf` einen
Protokollpfad, obwohl an dieser Stelle keine Datei entsteht. Und das unterdrückte
`Set-Content` erzeugt seinerseits eine `WhatIf:`-Zeile („Inhalt festlegen"), die keine
Dateibewegung ist und beim Auswerten herausfallen muss.

**Fehlerbehandlung.** Fehlt ExifTool oder der Inbox-Ordner, bricht das Skript mit `exit 1`
ab. Ein Fehler an einer einzelnen Datei wird gefangen, als `FEHLER` protokolliert und der
Lauf geht weiter – ein defektes Bild darf den Rest nicht stoppen.

## Ergebnisse, Fortschritt und Zeiten

**Ergebnisse** sammelt eine `List[object]` mit den Feldern `Status` / `Alt` / `Neu` /
`Grund`. Aus ihr entstehen sowohl die Konsolenausgabe als auch die Detailtabelle im
Protokoll. Statuswerte sind `OK`, `SKIP` und `FEHLER`. `Grund` trägt auch bei `OK` Text,
etwa „Datum aus Dateisystem". Wer eine neue Abbruchbedingung einbaut, fügt dort einen
Eintrag hinzu, sonst fehlt der Fall im Protokoll.

`$uebersprungen` zählt auch die `FEHLER`-Fälle mit. Die Spalte „Übersprungen" in
Zusammenfassung und Protokoll ist also SKIP plus FEHLER; die Gesamtzahl kommt aus
`$ergebnisse.Count`.

**Fortschritt.** Der Lauf ist in zwei Schritte geteilt, die er auch so benennt: „Schritt 1
von 2" ist der ExifTool-Durchlauf, „Schritt 2 von 2" das Einsortieren. Vorher war der erste
Schritt stumm – bei 480 Dateien rund zwölf Sekunden, in denen nichts passiert, was man sehen
kann. Zwischen beiden steht ein **Vorlauf**, der die drei Filter (Programmordner,
Namensfilter, Endungsfilter) schon einmal anwendet und `$zuTun` samt `$summeBytes` füllt.
Nur deshalb kann der Fortschritt „Datei 12 von 480" sagen statt „12 von 3.200": ExifTool
meldet auch `.txt`, `.xmp` und alles, was die Filter gleich wieder aussortieren. Wer an den
Filtern arbeitet, ändert sie **im Vorlauf**; in der Hauptschleife stehen sie nicht mehr.

Je Datei zeichnet `Write-Fortschritt` ein `Write-Progress`, gedrosselt auf 200 ms (unter
Windows PowerShell 5.1 kostet jeder Aufruf spürbar Zeit) und am Ende mit `-Completed`
abgeräumt. Bewusst `Write-Progress` und keine zusätzliche Zeile auf stdout: Der
Progress-Stream erreicht `Read-SkriptAusgabe` im Dienst nicht. Bei `-WhatIf` entfällt die
Anzeige, die Vorschau verschiebt ja nichts.

**Neue Ausgabezeilen müssen gegen `Read-SkriptAusgabe` geprüft werden.** Die Funktion im
Dienst prüft jede Zeile gegen feste Muster. `OK`/`SKIP`/`FEHLER` sind mit `^` und `$`
verankert – ein vorangestellter oder angehängter Zähler bricht sie. Die `OK`-Zeile trägt
seit 1.2.0 den Grund in Klammern hinter dem Ziel (`OK 'a.JPG' -> '2026\…' (Datum aus
Dateisystem)`); die Klammer ist im Muster als optionale dritte Fangklammer vorgesehen.
Motor und Parser gehören hier zusammen: Wer die eine Zeile anfasst, ändert das Muster mit.
Jede Meldung trägt seitdem `status`, `datei`, `ziel` und `grund` als eigene Felder – vorher
stand bei `OK` der Zielpfad in der Spalte „Grund", während das Protokoll es längst richtig
machte. Eine neue Zeile darf

- nicht mit `OK `, `SKIP `, `FEHLER`, `Protokoll:`, `WARNUNG` oder `Keine Dateien` beginnen;
- nicht mit `ExifTool nicht gefunden`, `Inbox-Ordner existiert nicht`, `JSON-Fehler` oder
  `FEHLER:` beginnen – diese vier gelten als `ABBRUCH` und erscheinen auf der Seite als
  Grund eines gescheiterten Laufs, auch wenn der Lauf in Wahrheit durchlief;
- nicht auf `Verschoben:\s*(\d+),\s*\S+:\s*(\d+)` passen;
- und die Wortfolge `Verschieben nach` oder `Einsortieren nach` an keiner Stelle tragen:
  Diese Prüfung läuft unverankert und vor allen anderen, eine solche Zeile landete sonst als
  Dateibewegung in der Vorschautabelle.

Die Zeilen `Zeiten:` und `Durchsatz:` stehen deshalb **nach** `Protokoll:` – die Reihenfolge
der erkannten Zeilen bleibt damit unangetastet. Dasselbe gilt für die Zeile über die
Dateien ohne Aufnahmedatum.

**Die Schlusszeilen unterscheiden Vorschau und Lauf.** Ein echter Lauf meldet „Fertig …
Verschoben: n, Übersprungen: m" und darunter den Protokollpfad. Eine Vorschau meldet
stattdessen „Vorschau beendet … n Dateien würden verschoben, m blieben liegen." und
„Es wurde nichts verändert und kein Protokoll geschrieben." – beides trifft zu, die alten
Zeilen taten es nicht: Eine Vorschau verschob nie etwas und legte nie das genannte
Protokoll an. Gezählt wird dafür `$geplant` im `else`-Zweig von `ShouldProcess`; `$verschoben`
geht nur im echten Lauf hoch. Die neue Zeile darf das Muster `Verschoben:\s*(\d+),…` nicht
treffen, sonst liest der Dienst die Vorschau als abgeschlossenen Lauf.

**Ein geschätztes Datum steht auch im Text von `ShouldProcess`.** Stammt das Datum aus dem
Dateisystem, hängt der Motor ` (Datum aus Dateisystem)` an den Vorgangstext; die Angabe
steht damit in der `WhatIf:`-Zeile, und die Vorschau kann die betroffenen Dateien
auszeichnen, obwohl sie keine `OK`-Zeilen kennt. `Read-SkriptAusgabe` prüft dafür auf genau
diesen Wortlaut (`geschaetzt`-Feld je Aktion) und nicht auf eine beliebige Klammer: Pfade
dürfen Klammern enthalten.

**Laufwerke.** `Test-GleichesLaufwerk` vergleicht die `GetPathRoot` von Inbox und Mediathek.
Auf demselben Laufwerk ist `Move-Item` ein Umbenennen und kostet nichts; über eine
Laufwerksgrenze kopiert Windows jede Datei und löscht danach die Quelle. Gemessen mit 480
Bildern zu je 7,7 MB (3,6 GB): auf demselben Laufwerk 10,4 s für den ganzen Lauf, über die
Grenze 23,0 s, davon 10,8 s reines Verschieben – ein `robocopy /MOV` derselben Daten brauchte
30,5 s, der Motor liegt also nicht über der physikalischen Untergrenze. Bei verschiedenen
Laufwerken gibt der Lauf dazu einen Hinweis aus, und die Seite zeigt ihn über
`Get-Lage.verschiedeneLaufwerke` schon vorher. Die Zeiten je Phase, die bewegte Datenmenge
und der Durchsatz stehen in der Schlusszeile und im Protokollkopf; ohne sie lässt sich eine
Rückmeldung wie „dauert ewig" nicht nachrechnen.

## Weboberfläche

`scripts\Starte-Weboberflaeche.ps1` ist ein HTTP-Dienst, `web\index.html` die Seite. Der
Motor bleibt unangetastet und weiß nichts von der Oberfläche. Wer beide Dateien löscht,
verliert nichts am Import; der Doppelklick-Betrieb hängt nicht an ihnen.

**Der Motor läuft als eigener Prozess**, nicht dot-sourced und nicht im selben Runspace. Das
Importskript beendet sich bei fehlendem ExifTool mit `exit 1`, und das würde den Dienst
mitreißen. `Invoke-Importskript` startet deshalb `powershell.exe` und liest dessen Ausgabe.
Der Exit-Code kommt sauber zurück, der Dienst überlebt (geprüft).

**Parametername und Wert müssen getrennt übergeben werden.** Ein Name in Anführungszeichen
ist für PowerShell kein Parameter, sondern ein Wert: `& skript.ps1 '-Inbox' 'C:\x'` bindet
`-Inbox` an den ersten Positionsparameter `-Gruppierung` und scheitert am `ValidateSet`.
Deshalb liefert `Get-LaufArgumente` Objekte mit `Name`/`Wert`/`IstSchalter`, und nur der Wert
wird gequotet. **Diese Falle ist gefährlicher, als sie aussieht:** kommen `-Inbox`,
`-Mediathek` und `-Protokolle` nicht an, fällt das Importskript still auf seine
Standardpfade zurück – also auf die echte Inbox und die echte Mediathek. Genau so entstand am
2026-09-23 ein ungewollter echter Lauf gegen den Produktivordner. Wer an der Argumentübergabe
arbeitet, prüft zuerst im Protokoll, welche Pfade tatsächlich benutzt wurden.

**stderr nebenher lesen.** Erst `StandardOutput.ReadToEnd()` und danach stderr blockiert den
Kindprozess, sobald dessen stderr-Puffer voll läuft. Der Dienst startet deshalb
`StandardError.ReadToEndAsync()`, bevor er stdout liest.

**Keine `Get-Content`-Ergebnisse in eine JSON-Antwort.** `Get-Content` hängt an jeden String
die Provider-Eigenschaften `PSPath`, `PSParentPath`, `PSChildName`, `PSDrive`, `PSProvider`
und `ReadCount`. `ConvertTo-Json` steigt in diesen Objektgraph ab und blieb im
Dienst-Runspace stehen, ohne Fehler und ohne Rückkehr – die Anfrage lief einfach in den
Timeout. Dateien werden deshalb mit `[System.IO.File]::ReadAllText()` gelesen, und die
Antwort nutzt `-Depth 4` statt 8. Das ist dieselbe Linie wie bei `Test-GleicheDatei`: rein
lesende Zugriffe über `System.IO`, nicht über die Provider-Cmdlets.

**Die Vorschau entsteht aus den `WhatIf:`-Zeilen**, wie im Abschnitt zu `-WhatIf` gefordert.
Geparst wird aber nicht der Satzbau: PowerShell 5.1 schreibt `WhatIf: Ausführen des Vorgangs
"…" für das Ziel "…"`, PowerShell 7 dagegen `What If: Der Vorgang „…" wird … ausgeführt` –
andere Wortstellung, andere Anführungszeichen. `Read-SkriptAusgabe` filtert stattdessen auf
`Verschieben nach` bzw. `Einsortieren nach` (Text aus unserem eigenen `ShouldProcess`-Aufruf)
und zieht die Windows-Pfade aus der Zeile: erster Treffer Ziel, zweiter Quelle. Die
`Set-Content`-Zeile des unterdrückten Protokolls fällt damit von selbst weg.

**Der Port steht nicht fest.** Der Dienst probiert ab `-Port` (Standard 8787) bis zu zwanzig
Ports aufwärts und nimmt den ersten freien; erst danach bricht er mit `exit 1` ab. Die
tatsächliche Adresse steht beim Start auf der Konsole. Wer den Dienst von außen anspricht,
darf 8787 deshalb nicht fest verdrahten – ein zweiter laufender Dienst sitzt auf 8788.

**Zugriffsschutz.** Der Dienst bindet nur an `http://127.0.0.1:<port>/` – das geht ohne
Adminrechte, eine URL-ACL ist nicht nötig (geprüft). Jeder API-Aufruf verlangt ein beim Start
erzeugtes Token, das in der Startadresse steht; ohne Token antwortet der Dienst mit 403. Das
ist kein Zierrat: Ein Formular-POST von einer beliebigen fremden Webseite an localhost ist
dem Browser nicht verboten, und `/api/import` verschiebt Dateien. Zusätzlich wird der
`Host`-Kopf gegen `127.0.0.1`/`localhost` geprüft (DNS-Rebinding), und `/api/protokoll`
akzeptiert nur Namen nach dem Muster `protokoll_<ziffern>.md`, damit darüber keine beliebigen
Dateien lesbar werden.

**`Get-Lage` zählt zweimal.** `inboxDateien` ist der ganze Inbox-Baum, `inboxZuImportieren`
nur das, was Namens- und Endungsfilter übrig lassen – dieselben Werte aus derselben Datei,
die auch der Motor zieht. Ohne die zweite Zahl meldete die Seite nach einem vollständigen
Import weiter wartende Dateien, obwohl nur Textdateien, XMP-Beidateien und `Thumbs.db`
liegen geblieben waren. Wer den Filter im Motor ändert, ändert ihn hier mit, sonst weichen
Lageband und Vorschau voneinander ab.

**Die Seite holt die Lage beim Zurückwechseln neu** (`visibilitychange`), nicht über einen
Timer: Der Dienst bedient eine Anfrage nach der anderen, und ein Sekundentakt läge einem
laufenden Import im Weg. Während eines Laufs ist der Vorschauknopf gesperrt; daran erkennt
die Seite, dass sie gerade nichts abfragen soll.

**Daneben steht ein Knopf, der dasselbe auf Zuruf tut** (`knopfAktualisieren`, links neben
„Vorschau"). Der Wechsel ins Fenster deckt nur einen Teil der Fälle ab: Wer die Seite gar
nicht verlässt und nebenher Dateien in die Inbox schiebt, hatte sonst nur F5 – und das wirft
Vorschau und Ergebnistabelle mit weg (R-20). Der Knopf ist aus demselben Grund wie der
Vorschauknopf während eines Laufs gesperrt und dreht sein Symbol, solange die Anfrage läuft.

**Das Protokoll wird in der Seite gesetzt, nicht roh angezeigt.** `protokollAlsHtml` kennt
die wenigen Zeilenarten der eigenen Protokolle: `#`/`##`, `- **Label:** Wert`, Tabellen und
einzelne Sätze. Kein Markdown-Übersetzer von außen – die Seite lädt nichts nach. Eine Falle
steckt darin: Kursiv mit Unterstrichen gibt es bewusst nicht, weil jeder Dateiname im
Protokoll Unterstriche trägt (`20260910_101530_IMG.JPG`) und eine solche Regel mitten durch
die Namen schnitte. Nur eine Zeile, die ganz in Unterstrichen steht, gilt als kursiv.

**Die Ordner kommen bei jeder Anfrage frisch aus der Datei.** Der Dienst friert sie nicht
beim Start ein, sonst würde eine Änderung über die Seite erst nach einem Neustart greifen.
`Get-AktuellePfade` liefert die Rangfolge Sitzungsvorgabe > Datei > Ordner neben dem Skript;
die Sitzungsvorgabe entsteht nur, wenn dem Dienst beim Start `-Inbox`, `-Mediathek` oder
`-Protokolle` mitgegeben wurde – dafür ist `$PfadUeberschreibung` da, und die Seite sperrt
die betroffenen Felder samt Begründung. Genau diese Pfade gibt `Get-LaufArgumente` auch an
den Motor weiter, damit Anzeige und Lauf nie auseinanderlaufen können.

Beim Speichern prüft `Set-EinstellungenObjekt` die Ordner: die Inbox muss existieren, bei
Mediathek und Protokolle reicht ein vorhandener Elternordner (den Rest legt der Motor an),
und Inbox und Mediathek dürfen weder derselbe Ordner sein noch ineinanderliegen. Schlägt eine
Prüfung fehl, wird gar nichts geschrieben; die Datei bleibt auf ihrem letzten gültigen Stand
(geprüft).

**Die Oberfläche weigert sich, eine leere Dateityp-Liste zu speichern.** Nach dem oben
beschriebenen Verhalten von `"Erweiterungen": []` würde sie den Endungsfilter abschalten
statt nichts zu importieren – wer alle Haken entfernt, meint aber das Gegenteil. Die Prüfung
sitzt in `Set-EinstellungenObjekt` und zusätzlich in der Seite, damit der Knopf gar nicht
erst aktiv ist.

**Der Aufbau der Seite.** Oben ein Lageband: ein Satz zur Lage, darunter die drei Kennzahlen,
rechts die beiden Lauf-Knöpfe. Sie sitzen bewusst dort und nicht mehr im Import-Reiter — der
Riegel bleibt derselbe, `knopfImport` wird erst nach einer Vorschau scharf
(`vorschauGesehen`). Alle Element-Kennungen haben die Umgestaltung unverändert überlebt; wer
am Skriptteil arbeitet, kann sich weiter auf `lage`, `lagehinweis`, `knopfVorschau`,
`knopfImport`, `laufstatus` und `ortMediathek` verlassen. Symbole stecken als Inline-SVG in
der Seite, weil sie nichts von außen nachlädt. Der Hell/Dunkel-Knopf stempelt `data-theme` auf
`<html>` und merkt sich die Wahl in `localStorage`; ohne gespeicherte Wahl gilt weiter die
Systemeinstellung, und jede Farbe steht als Marke in `:root`, damit beide Fassungen dieselben
Regeln benutzen.

Vor jedem Überschreiben legt der Dienst `einstellungen.json.bak` an. Die Sicherung steht nicht
unter Versionskontrolle und ist damit die Rücknahme zwischen zwei Commits. `ConvertTo-Json`
maskiert unter PowerShell 5.1 Umlaute als `\uXXXX`; das wird zurückgewandelt, damit die Datei
von Hand lesbar bleibt.

Die API, alles tokenpflichtig außer `/`:

| Aufruf | Zweck |
|---|---|
| `GET /` | die Seite |
| `GET /api/lage` | Zählungen für Inbox und Mediathek, ExifTool vorhanden |
| `GET/POST /api/einstellungen` | `config\einstellungen.json` lesen und schreiben |
| `POST /api/vorschau` | Motor mit `-WhatIf`, liefert die geplanten Bewegungen |
| `POST /api/import` | echter Lauf, liefert Zusammenfassung und Protokollinhalt |
| `GET /api/protokolle` | die letzten 50 Protokolle |
| `GET /api/protokoll?name=` | ein Protokoll im Volltext |

Der Dienst bedient eine Anfrage nach der anderen. Das reicht für eine Oberfläche mit einem
Benutzer und hält den Code klein; ein Import blockiert währenddessen die Seite, was richtig
ist, weil zwei gleichzeitige Läufe auf derselben Inbox nichts Gutes ergäben.

## Installationsprogramm

`installer\` baut aus dem Projektordner eine einzelne `Setup.exe` (Inno Setup 6). Sie
installiert ins Benutzerprofil nach `%LOCALAPPDATA%\Programs\GoDigital Medienimport`, ohne
Administratorrechte: Das Programm schreibt Protokolle und Einstellungen in den eigenen Ordner,
unter `C:\Programme` dürfte es das nicht.

```powershell
.\installer\Baue-Setup.ps1                      # Version aus VERSION, ExifTool-Fassung frisch
.\installer\Baue-Setup.ps1 -OhneExifTool        # schneller, nutzt exiftool-fassung.txt weiter
.\installer\Baue-Setup.ps1 -ArchivDatei <zip>   # falls der SourceForge-Download klemmt
```

**ExifTool wird beim Installieren geladen, nicht mitgeliefert.** Das hält das Setup bei rund
einem Megabyte. Das Bauskript holt die Versionsnummer von `https://exiftool.org/ver.txt`, lädt
das Archiv von SourceForge – die einzige Quelle, `exiftool.org` liefert für die ZIP-Datei 404
–, bildet die SHA256-Summe und schreibt alles nach `installer\exiftool-fassung.txt`. Diese
Datei ist versioniert: Aus ihr geht hervor, welche ExifTool-Fassung in einem Release steckt.

**Das Bauskript meldet sich mit einem eigenen User-Agent.** SourceForge schickt browserartigen
Clients eine HTML-Zwischenseite mit ablaufendem Mirror-Token statt der Datei; der Standardwert
von `Invoke-WebRequest` fällt darunter, mit einem echten Browser-Kennzeichen kommt sogar 403.
Nicht-browserartige Clients bekommen die Datei direkt – Inno Setup gehört dazu, der Installer
selbst war nie betroffen. Die Prüfung auf die ZIP-Kennung `PK` fängt den Fall trotzdem ab,
damit nie die Prüfsumme einer Fehlerseite in ein Release wandert.

**Geladen wird an zwei Stellen, und das hat einen Grund.** Der bediente Ablauf lädt auf einer
eigenen Seite (`CreateDownloadPage`, angestoßen in `NextButtonClick` an `wpReady`), die stille
Installation in `PrepareToInstall`. Nur `PrepareToInstall` läuft auch bei `/VERYSILENT`, das
gar keine Assistentenseiten durchläuft – ohne diesen Zweig entstünde dort eine Installation
ganz ohne ExifTool. Hat die Seite das Archiv schon geholt, steigt `PrepareToInstall` sofort
wieder aus; `ArchivPfad` ist die Weiche.

**Warum nicht allein `PrepareToInstall`?** Weil dort kein Fortschritt zu sehen ist. Während
der Funktion ist `wpPreparing` (Seite 11) die sichtbare Seite, `WizardForm.ProgressGauge` und
`WizardForm.StatusLabel` gehören aber zu `wpInstalling` (Seite 12). Dort gesetzter Fortschritt
und dort geschriebener Text kommen beim Nutzer nicht an. Gemessen am 2026-10-17 mit einem
Wegwerf-Setup, das `WizardForm.CurPageID` aus `PrepareToInstall` heraus protokolliert. Der
Download ist mit rund 11 MB der längste Schritt der Installation; ohne sichtbare Regung sieht
das Setup aus, als hänge es – so gemeldet im Betatest (R-19).

Schlägt der Download auf der Seite fehl oder bricht ihn der Nutzer ab, geht es trotzdem
weiter: Dann greift die Kette in `PrepareToInstall` mit ihren Rückfragen (noch einmal
versuchen, vorhandene `exiftool.exe` wählen, vorhandene Installation weiterbenutzen). Zwei
Fehlerbehandlungen nebeneinander wären eine zu viel.

Ein nicht leerer Rückgabewert von `PrepareToInstall` bricht sauber ab – geprüft mit einer
falschen Prüfsumme: Exitcode 7, kein Zielordner. Die Prüfsumme prüfen `DownloadTemporaryFile`
und die Downloadseite selbst.

**Die Arbeit steckt in PowerShell, nicht in Pascal.** `Entpacke-ExifTool.ps1` und
`Schreibe-Einstellungen.ps1` laufen aus `{tmp}` (`Flags: dontcopy`) und sind einzeln auf der
Kommandozeile prüfbar. Im Pascal-Teil bleiben Seiten und Prüfungen. Jeder Pfad geht dabei in
Anführungszeichen an PowerShell: Zielordner und Medienordner dürfen Leerzeichen und Umlaute
tragen (geprüft mit einer Installation nach `…\Programs\Prüfordner`).

**Das Archiv wird durchsucht, nicht vorausgesetzt.** Die ausführbare Datei heißt
`exiftool(-k).exe`; das `-k` ließe sie nach jedem Aufruf auf einen Tastendruck warten, der
Import bliebe hängen. `Entpacke-ExifTool.ps1` sucht sie samt `exiftool_files` im entpackten
Baum, statt einen Ordnernamen anzunehmen, und benennt beim Kopieren um. Fehlt `exiftool_files`,
bricht es mit Code 1 und einer Begründung ab.

**Die `AppId` `{{89A23525-B7D0-45C9-BA38-83D6BF357836}` bleibt für immer gleich.** Ändert sie
sich, hält Windows ein Update für ein zweites Programm, und der Nutzer hat beides.

**Eine vorhandene `einstellungen.json` bleibt unangetastet** (Rückgabe 2 des Schreibskripts).
Die Schlussseite sagt es, sonst wunderte sich ein Nutzer, warum seine im Assistenten gewählten
Ordner nicht greifen.

**Die Ordnerprüfungen stehen in `installer\Ordnerpruefung.iss`** und werden per `#include` in
den `[Code]`-Abschnitt gezogen. Der Grund ist die Prüfbarkeit: Ein Assistent lässt sich nur von
Hand bedienen, dieselben Funktionen laufen so aber aus einem Wegwerf-Setup heraus gegen eine
Fallliste. Die Datei ist ASCII ohne BOM und kommentiert mit `//` – innerhalb von `[Code]` gilt
Pascal, ein `;`-Kommentar bricht den Compiler mit „BEGIN expected" ab.

Die Ordnerseite lehnt ab, dass Inbox und Mediathek derselbe Ordner sind **oder einer im anderen
liegt** – sonst läse der Import die Mediathek bei jedem Lauf noch einmal mit –, und sie legt
beide Ordner probeweise an, damit ein fehlendes Laufwerk hier auffällt und nicht erst beim
ersten Import. Dieselbe Verschachtelungsregel steckt in `Set-EinstellungenObjekt` der
Weboberfläche (`Test-LiegtInnerhalb`): Was der Assistent verbietet, darf die Seite nicht
hinterher wieder erlauben. Wer eine der beiden Stellen ändert, ändert beide. Beide prüfen
zusätzlich, dass der **Programmordner** nicht in Inbox oder Mediathek liegt – umgekehrt ist es
erlaubt, Inbox und Mediathek unterhalb des Programmordners sind das alte, harmlose Layout.

**Vorbelegt wird `{%USERPROFILE}\Pictures`, nicht der Bilderordner der Shell.** Den biegt
OneDrive auf einen Synchronisationsordner um (auf dem Entwicklungsrechner `…\OneDrive\Bilder
1`), und eine Mediathek mit mehreren Gigabyte gehört nicht ungefragt in die Cloud. Eine
Konstante `{userpics}` kennt Inno Setup ohnehin nicht – sie führt zu einem Laufzeitfehler, der
die Installation vollständig abbricht.

Die `.iss` ist **UTF-8 mit BOM**, wie die Skripte: Ohne BOM zeigt der Assistent zerlegte
Umlaute.

**Das Icon hängt an drei Stellen.** `SetupIconFile` trägt es auf die `Setup.exe`,
`UninstallDisplayIcon` auf den Eintrag in „Apps & Features", und `IconFilename` auf jede
Verknüpfung. Das Letzte ist kein Schönheitsfix: Die Verknüpfungen zeigen auf `.cmd`-Dateien und
erben sonst das Symbol der Eingabeaufforderung. Damit die beiden ersten greifen, muss die
`.ico` mitinstalliert werden — ein `UninstallDisplayIcon` auf eine nach der Installation
fehlende Datei zeigt wieder das leere Blatt (geprüft: nach einer stillen Installation steht der
Pfad in der Registry unter `HKCU:\…\Uninstall` und die Datei liegt dort).

Gebaut wird die `.ico` mit `installer\Baue-Icon.ps1` aus `installer\GoDigital-Medienimport.svg`.
Geändert wird nur die SVG. Das Skript rendert **jede Größe einzeln** mit Chrome statt eine große
herunterzuskalieren; nur so bleiben 16 und 20 Pixel scharf, und genau die sieht man in der
Taskleiste und in der Programmliste. Zwei Fallen stecken darin, beide kommentiert: Die
Fenstergröße muss als eine Zeichenkette übergeben werden (`"--window-size=$g,$g"`), sonst macht
PowerShell zwei Argumente daraus und Chrome nimmt die Größe aus seinem Profil. Und Chrome meldet
den Erfolg auf stderr, was unter `$ErrorActionPreference = 'Stop'` einen Abbruch auslöst. Die
Einträge sind PNG-komprimiert; `System.Drawing` liefert daraus die 256er Fassung nicht aus,
Windows und der Explorer dagegen schon.

## Der Prozess im Einzelnen

1. Neue Dateien kommen ausschließlich in `inbox\`.
2. Verarbeitet wird per Doppelklick auf `Medien importieren.cmd` oder über die
   PowerShell-Aufrufe aus `CLAUDE.md`.
3. Jede Datei wird in einem Schritt umbenannt und nach `mediathek\` verschoben.
4. **Niemals überschreiben:** Bei belegtem Zielnamen entscheidet der Inhaltsvergleich zwischen
   Dublette (`SKIP`) und Zähler-Suffix (`OK`). Dateien, die bereits einen Datumsvorsatz tragen,
   behalten ihn, damit eine zurückgelegte Datei denselben Zielnamen ergibt und als Dublette
   erkannt wird.
5. Unterordner der Inbox werden zu `mediathek\Ereignisse\<Name>\`. `-Ereignis` schlägt den
   Unterordnernamen.
6. Nur Dateitypen aus `-Erweiterungen` werden angefasst; `-AlleDateien` schaltet den Filter ab.
   Zusätzlich übergeht ExifTool beim Ordnerdurchlauf `Thumbs.db` und `desktop.ini` von sich
   aus; sie erreichen das Skript also gar nicht, auch mit `-AlleDateien` nicht (geprüft). Nicht
   übergangen werden Typen, die ExifTool kennt, ohne dass sie Medien sind: `.txt`, `.xmp`,
   `.pdf` und ähnliche tauchen in der Ausgabe auf. Der Endungsfilter ist der einzige Schutz
   davor, dass `-AlleDateien` Textdateien und XMP-Beidateien in die Mediathek zieht.
7. Dateien ohne jedes ermittelbare Datum werden übersprungen und protokolliert.
8. Nach jedem echten Lauf entsteht automatisch ein Protokoll in `protokolle\`.

## Prüfen und Testen

Es gibt keine automatisierten Tests. Geprüft wird von Hand gegen Wegwerf-Ordner.

**Rauchtest des Motors.** Testdateien brauchen kein EXIF: ExifTool listet auch eine 1-Byte-Datei
mit Endung `.JPG`, das Skript greift dann auf das Dateisystemdatum zurück.

```powershell
$t = "$env:TEMP\mt"; Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue
mkdir "$t\inbox\2026-09_Test", "$t\ziel", "$t\log" | Out-Null
"x" > "$t\inbox\IMG_0001.JPG"; "y" > "$t\inbox\2026-09_Test\IMG_0002.JPG"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Importiere-Medien.ps1 `
  -Inbox "$t\inbox" -Mediathek "$t\ziel" -Protokolle "$t\log" `
  -EinstellungsDatei "$t\einstellungen.json" -WhatIf
```

`powershell.exe` statt `pwsh` ist Absicht: die `.cmd`-Starter rufen 5.1 auf.

`-EinstellungsDatei` steht nicht zur Zierde dabei: Ohne sie zieht auch ein Rauchtest die echte
`config\einstellungen.json` und damit deren Gruppierung, Filter und ExifTool-Pfad. Zeigt der Pfad
ins Leere, gelten die eingebauten Werte; wer am Einstellungs-Code arbeitet, legt sich dort eine
Testdatei an.

**Die Oberfläche bedienen, ohne zu klicken.** Chrome headless mit `--remote-debugging-port` und
einem eigenen `--user-data-dir` genügt. Über die WebSocket-Adresse aus
`http://127.0.0.1:<port>/json/list` lassen sich `Runtime.evaluate` (Klicks auf `knopfVorschau`,
`knopfImport`, `reiter-einstellungen` …) und `Page.captureScreenshot` schicken; eine
Browser-Erweiterung braucht es dafür nicht.

Die Falle dabei: Die Seite fragt vor dem echten Lauf mit `confirm()` nach. In headless Chrome
blockiert dieser Dialog den Renderer, und jede weitere Antwort des Protokolls bleibt aus – der
Test hängt ohne Fehlermeldung. Vor dem Klick `window.confirm = function(){ return true; }`
setzen; der Fragetext lässt sich dabei in einer Variablen mitlesen und prüfen.

Auch hier gilt die Regel aus `CLAUDE.md`: den Dienst mit eigenen `-Inbox`/`-Mediathek`/
`-Protokolle` und eigener `-EinstellungsDatei` gegen Wegwerf-Ordner starten, nie gegen die echte
Mediathek.

**Den Screenshot für das README** (`docs\weboberflaeche.png`) genauso aufnehmen: Wegwerf-Ordner,
eigene Einstellungsdatei, dann Chrome `--headless=new --screenshot`. Das Lageband zeigt die
vollen Pfade, und das Bild liegt öffentlich im README.
