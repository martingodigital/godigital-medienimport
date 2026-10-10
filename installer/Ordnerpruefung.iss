// Pruefungen der Ordnerseite. Eigene Datei, damit dieselben Funktionen aus einem
// Testsetup heraus ohne Klicken geprueft werden koennen - der Assistent selbst
// laesst sich nur von Hand bedienen. Wird mit #include in den [Code]-Abschnitt
// gezogen und steht dort vor ihrer ersten Verwendung.
//
// Reines ASCII und ohne BOM: Die Datei wird mitten in den [Code]-Abschnitt
// eingefuegt, dort waere ein BOM ein Fremdkoerper. Kommentare mit //, nicht mit
// Semikolon - innerhalb von [Code] gilt Pascal, kein INI-Format.

function OrdnerSchluessel(const Ordner: String): String;
begin
  Result := AddBackslash(Lowercase(Trim(Ordner)));
end;

function IstDerselbe(const A, B: String): Boolean;
begin
  Result := OrdnerSchluessel(A) = OrdnerSchluessel(B);
end;

// Liegt Unten innerhalb von Oben? Der Backslash am Ende ist wichtig: ohne ihn
// gaelte C:\Bilder2 als Unterordner von C:\Bilder.
function LiegtInnerhalb(const Unten, Oben: String): Boolean;
var
  U, O: String;
begin
  U := OrdnerSchluessel(Unten);
  O := OrdnerSchluessel(Oben);
  Result := (Length(U) > Length(O)) and (Copy(U, 1, Length(O)) = O);
end;

// Anlegen und eine Datei schreiben. Nur so faellt ein fehlendes Laufwerk oder
// ein schreibgeschuetzter Pfad hier auf und nicht erst beim ersten Import.
function OrdnerBeschreibbar(const Ordner: String): Boolean;
var
  Probe: String;
begin
  Result := False;
  if not ForceDirectories(Ordner) then
    Exit;
  Probe := AddBackslash(Ordner) + 'gdmi-schreibprobe.tmp';
  if SaveStringToFile(Probe, 'Schreibprobe', False) then
  begin
    DeleteFile(Probe);
    Result := True;
  end;
end;
