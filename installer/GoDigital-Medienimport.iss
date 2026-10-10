; GoDigital Medienimport - Installationsprogramm
; Gebaut mit Inno Setup 6. Siehe installer\liesmich.md.
;
; AppVersion kommt als /D-Definition vom Bauskript, das VERSION liest. Die
; Versionsnummer steht ausschliesslich dort; der Wert hier faengt nur den Fall
; ab, dass jemand den Compiler von Hand aufruft.

#ifndef AppVersion
  #define AppVersion "0.0.0-handbetrieb"
#endif

#ifndef ExifToolVersion
  #define ExifToolVersion "unbekannt"
  #define ExifToolDatei "exiftool.zip"
  #define ExifToolUrl ""
  #define ExifToolHash ""
#endif

#define AppName "GoDigital Medienimport"
#define AppPublisher "Martin Goßner GoDigital"
#define AppUrl "https://github.com/martingodigital/godigital-medienimport"

[Setup]
; Die AppId bleibt ueber alle Fassungen gleich. Aendert sie sich, haelt Windows
; ein Update fuer ein zweites Programm und der Nutzer hat beides.
AppId={{89A23525-B7D0-45C9-BA38-83D6BF357836}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}
VersionInfoVersion={#AppVersion}
; Installation ins Benutzerprofil: das Programm schreibt Protokolle und
; Einstellungen in den eigenen Ordner, unter C:\Programme duerfte es das nicht.
; Nebeneffekt: Windows fragt nicht nach Administratorrechten.
DefaultDirName={localappdata}\Programs\GoDigital Medienimport
DefaultGroupName={#AppName}
PrivilegesRequired=lowest
DisableWelcomePage=no
LicenseFile=..\LICENSE
OutputDir=ausgabe
OutputBaseFilename=GoDigital-Medienimport-Setup-{#AppVersion}
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
UninstallDisplayName={#AppName}

[Languages]
Name: "de"; MessagesFile: "compiler:Languages\German.isl"

[Messages]
de.ConfirmUninstall=Soll %1 wirklich entfernt werden?%n%nEntfernt werden das Programm, ExifTool, die Einstellungen und die Verknüpfungen.%n%nIhre Mediathek, die Inbox und die Protokolle bleiben erhalten.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\scripts\Importiere-Medien.ps1";     DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "..\scripts\Starte-Weboberflaeche.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "..\web\index.html";                    DestDir: "{app}\web";     Flags: ignoreversion
Source: "..\Medien importieren.cmd";            DestDir: "{app}";         Flags: ignoreversion
Source: "..\Vorschau (aendert nichts).cmd";     DestDir: "{app}";         Flags: ignoreversion
Source: "..\Weboberflaeche starten.cmd";        DestDir: "{app}";         Flags: ignoreversion
Source: "..\ANLEITUNG.md";                      DestDir: "{app}";         Flags: ignoreversion
Source: "..\VERSION";                           DestDir: "{app}";         Flags: ignoreversion
Source: "..\LICENSE";                           DestDir: "{app}";         Flags: ignoreversion
Source: "..\config\einstellungen.vorlage.json"; DestDir: "{app}\config";  Flags: ignoreversion
Source: "..\protokolle\GoDigital-Medienimport_Anleitung-bebildert.pdf"; DestDir: "{app}"; Flags: ignoreversion
; Laeuft zur Laufzeit aus {tmp}, wird nicht mitinstalliert.
Source: "Entpacke-ExifTool.ps1"; Flags: dontcopy
Source: "Schreibe-Einstellungen.ps1"; Flags: dontcopy

[Dirs]
Name: "{app}\protokolle"
Name: "{code:MediathekOrdner}"
Name: "{code:InboxOrdner}"

[Icons]
Name: "{group}\Weboberfläche starten";    Filename: "{app}\Weboberflaeche starten.cmd";   WorkingDir: "{app}"
Name: "{group}\Medien importieren";       Filename: "{app}\Medien importieren.cmd";       WorkingDir: "{app}"
Name: "{group}\Vorschau (ändert nichts)"; Filename: "{app}\Vorschau (aendert nichts).cmd"; WorkingDir: "{app}"
Name: "{group}\Anleitung";                Filename: "{app}\GoDigital-Medienimport_Anleitung-bebildert.pdf"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}";         Filename: "{app}\Weboberflaeche starten.cmd";   WorkingDir: "{app}"; Tasks: desktopicon

[UninstallDelete]
; Beides entsteht erst zur Laufzeit und wuerde sonst stehen bleiben.
Type: filesandordirs; Name: "{app}\exiftool"
Type: filesandordirs; Name: "{app}\config"

[Run]
Filename: "{app}\Weboberflaeche starten.cmd"; Description: "Weboberfläche jetzt starten";   WorkingDir: "{app}"; Flags: postinstall shellexec skipifsilent
Filename: "{app}\GoDigital-Medienimport_Anleitung-bebildert.pdf"; Description: "Anleitung öffnen";   Flags: postinstall shellexec skipifsilent

[Code]
var
  OrdnerSeite: TInputDirWizardPage;
  ArchivPfad: String;
  VorhandenesExifTool: String;
  EinstellungenBehalten: Boolean;

procedure InitializeWizard;
begin
  OrdnerSeite := CreateInputDirPage(wpSelectDir,
    'Ordner für Ihre Medien',
    'Wo sollen die Bilder liegen?',
    'Die Mediathek nimmt die fertig einsortierten Fotos und Videos auf. Sie wird mit der Zeit groß;' + #13#10 +
    'viele legen sie deshalb auf eine zweite Festplatte.' + #13#10#13#10 +
    'Die Inbox ist der Eingang: Dort legen Sie neue Fotos ab, die noch einsortiert werden sollen.' + #13#10#13#10 +
    'Beide Ordner werden angelegt, falls es sie noch nicht gibt.',
    False, '');
  OrdnerSeite.Add('Mediathek');
  OrdnerSeite.Add('Inbox');
  // Bewusst {%USERPROFILE}\Pictures und nicht der Bilderordner der Shell: Den
  // biegt OneDrive auf einen Synchronisationsordner um, und eine Mediathek mit
  // mehreren Gigabyte hat in der Cloud nichts verloren, solange der Nutzer das
  // nicht selbst waehlt. Wer es anders will, traegt auf dieser Seite seinen
  // eigenen Ordner ein. (Eine Konstante {userpics} kennt Inno Setup ohnehin nicht.)
  OrdnerSeite.Values[0] := ExpandConstant('{%USERPROFILE}\Pictures\GoDigital Mediathek');
  OrdnerSeite.Values[1] := ExpandConstant('{%USERPROFILE}\Pictures\GoDigital Inbox');
  ArchivPfad := '';
  VorhandenesExifTool := '';
  EinstellungenBehalten := False;
end;

function MediathekOrdner(Param: String): String;
begin
  Result := Trim(OrdnerSeite.Values[0]);
end;

function InboxOrdner(Param: String): String;
begin
  Result := Trim(OrdnerSeite.Values[1]);
end;

#include "Ordnerpruefung.iss"

function OrdnerSeiteGeprueft(): Boolean;
var
  Mediathek, Inbox: String;
begin
  Result := False;
  Mediathek := Trim(OrdnerSeite.Values[0]);
  Inbox     := Trim(OrdnerSeite.Values[1]);

  if (Mediathek = '') or (Inbox = '') then
  begin
    MsgBox('Bitte tragen Sie beide Ordner ein.', mbError, MB_OK);
    Exit;
  end;

  if IstDerselbe(Mediathek, Inbox) then
  begin
    MsgBox('Mediathek und Inbox dürfen nicht derselbe Ordner sein.' + #13#10#13#10 +
           'Die Inbox ist der Eingang, die Mediathek das Ergebnis.', mbError, MB_OK);
    Exit;
  end;

  // Die Weboberflaeche prueft nur auf Gleichheit. Liegt die Inbox in der
  // Mediathek, liest der Import sie bei jedem Lauf mit und sortiert die
  // Mediathek in sich selbst um.
  if LiegtInnerhalb(Inbox, Mediathek) then
  begin
    MsgBox('Die Inbox darf nicht innerhalb der Mediathek liegen.' + #13#10#13#10 +
           'Der Import würde die Mediathek sonst bei jedem Lauf noch einmal mitlesen.', mbError, MB_OK);
    Exit;
  end;

  if LiegtInnerhalb(Mediathek, Inbox) then
  begin
    MsgBox('Die Mediathek darf nicht innerhalb der Inbox liegen.' + #13#10#13#10 +
           'Der Import würde die bereits einsortierten Dateien sonst immer wieder einlesen.', mbError, MB_OK);
    Exit;
  end;

  if not OrdnerBeschreibbar(Mediathek) then
  begin
    MsgBox('Der Ordner für die Mediathek lässt sich nicht anlegen oder nicht beschreiben:' + #13#10#13#10 +
           Mediathek + #13#10#13#10 +
           'Bitte prüfen Sie, ob das Laufwerk vorhanden ist, und wählen Sie einen anderen Ordner.', mbError, MB_OK);
    Exit;
  end;

  if not OrdnerBeschreibbar(Inbox) then
  begin
    MsgBox('Der Ordner für die Inbox lässt sich nicht anlegen oder nicht beschreiben:' + #13#10#13#10 +
           Inbox + #13#10#13#10 +
           'Bitte wählen Sie einen anderen Ordner.', mbError, MB_OK);
    Exit;
  end;

  Result := True;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = OrdnerSeite.ID then
    Result := OrdnerSeiteGeprueft();
end;

function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo,
  MemoTypeInfo, MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
begin
  Result := MemoDirInfo + NewLine + NewLine +
            'Mediathek:' + NewLine + Space + MediathekOrdner('') + NewLine + NewLine +
            'Inbox (Eingang):' + NewLine + Space + InboxOrdner('') + NewLine + NewLine +
            MemoTasksInfo;
end;

function OnDownloadProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  if ProgressMax > 0 then
    WizardForm.StatusLabel.Caption := 'ExifTool {#ExifToolVersion} wird geladen: ' +
      IntToStr(Progress div 1024) + ' von ' + IntToStr(ProgressMax div 1024) + ' KB';
  Result := True;
end;

function VorhandeneExifToolDateiWaehlen(): Boolean;
var
  Pfad: String;
begin
  Result := False;
  Pfad := '';
  if GetOpenFileName('exiftool.exe auswählen', Pfad, '', 'Programme (*.exe)|*.exe|Alle Dateien (*.*)|*.*', 'exe') then
  begin
    if FileExists(Pfad) then
    begin
      VorhandenesExifTool := Pfad;
      Result := True;
    end;
  end;
end;

// Bewusst PrepareToInstall und keine eigene Downloadseite an wpReady: Dieser
// Haken laeuft auch bei einer stillen Installation (/VERYSILENT), die gar keine
// Assistentenseiten durchlaeuft. Sonst entstuende dort eine Installation ohne
// ExifTool. Die Pruefsumme prueft DownloadTemporaryFile selbst; stimmt sie
// nicht, wirft es eine Ausnahme und es wird nichts entpackt.
// Ein nicht leerer Rueckgabewert bricht die Installation sauber ab, statt etwas
// Halbfertiges zu hinterlassen.
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Fertig: Boolean;
begin
  Result := '';
  Fertig := False;
  repeat
    try
      DownloadTemporaryFile('{#ExifToolUrl}', '{#ExifToolDatei}', '{#ExifToolHash}', @OnDownloadProgress);
      ArchivPfad := ExpandConstant('{tmp}\{#ExifToolDatei}');
      Fertig := True;
    except
      if WizardSilent then
        Result := 'ExifTool ließ sich nicht laden: ' + GetExceptionMessage
      else if MsgBox('ExifTool ließ sich nicht laden, oder die geladene Datei stimmt nicht mit der erwarteten überein.' + #13#10#13#10 +
                     GetExceptionMessage + #13#10#13#10 +
                     'Möchten Sie es noch einmal versuchen?', mbError, MB_YESNO) = IDNO then
      begin
        if MsgBox('Haben Sie ExifTool bereits auf diesem Rechner?' + #13#10#13#10 +
                  'Dann können Sie die Datei exiftool.exe jetzt auswählen. Andernfalls wird die' + #13#10 +
                  'Installation abgebrochen; es bleibt nichts Halbfertiges zurück.', mbConfirmation, MB_YESNO) = IDYES then
        begin
          if VorhandeneExifToolDateiWaehlen() then
            Fertig := True
          else
            Result := 'Es wurde keine exiftool.exe ausgewählt.';
        end
        else
          Result := 'ExifTool wurde nicht geladen. Ohne ExifTool kann das Programm das Aufnahmedatum nicht aus den Fotos lesen.';
      end;
    end;
  until Fertig or (Result <> '');
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Code: Integer;
  Befehl, ExifZiel: String;
begin
  if CurStep <> ssPostInstall then
    Exit;

  if VorhandenesExifTool <> '' then
  begin
    // Der Nutzer hat eine vorhandene Installation gewaehlt: nichts entpacken,
    // der Pfad wandert direkt in die Einstellungsdatei.
    ExifZiel := VorhandenesExifTool;
  end
  else
  begin
    ExifZiel := ExpandConstant('{app}\exiftool\exiftool.exe');
    ExtractTemporaryFile('Entpacke-ExifTool.ps1');
    // Jeder Pfad in Anfuehrungszeichen: Zielordner und Archivpfad duerfen
    // Leerzeichen und Umlaute enthalten.
    Befehl := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{tmp}\Entpacke-ExifTool.ps1') + '"' +
              ' -Archiv "' + ArchivPfad + '"' +
              ' -Ziel "' + ExpandConstant('{app}\exiftool') + '"';
    if (not Exec('powershell.exe', Befehl, '', SW_HIDE, ewWaitUntilTerminated, Code)) or (Code <> 0) then
      MsgBox('ExifTool ließ sich nicht entpacken (Rückgabe ' + IntToStr(Code) + ').' + #13#10#13#10 +
             'Das Programm ist installiert, findet aber kein ExifTool. Tragen Sie in den' + #13#10 +
             'Einstellungen der Weboberfläche den Pfad zu einer exiftool.exe ein.', mbError, MB_OK);
  end;

  // Rueckgabe 2 heisst: Es gab schon eine Einstellungsdatei, sie bleibt stehen.
  // Ein Update darf die Einstellungen des Nutzers nicht ueberschreiben.
  ExtractTemporaryFile('Schreibe-Einstellungen.ps1');
  Befehl := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{tmp}\Schreibe-Einstellungen.ps1') + '"' +
            ' -Vorlage "'      + ExpandConstant('{app}\config\einstellungen.vorlage.json') + '"' +
            ' -Ziel "'         + ExpandConstant('{app}\config\einstellungen.json') + '"' +
            ' -Inbox "'        + InboxOrdner('') + '"' +
            ' -Mediathek "'    + MediathekOrdner('') + '"' +
            ' -Protokolle "'   + ExpandConstant('{app}\protokolle') + '"' +
            ' -ExifToolPath "' + ExifZiel + '"';
  if not Exec('powershell.exe', Befehl, '', SW_HIDE, ewWaitUntilTerminated, Code) then
    Code := -1;
  if Code = 2 then
    EinstellungenBehalten := True
  else if Code <> 0 then
    MsgBox('Die Einstellungsdatei ließ sich nicht schreiben (Rückgabe ' + IntToStr(Code) + ').' + #13#10#13#10 +
           'Sie können die Ordner nach dem Start in der Weboberfläche eintragen.', mbError, MB_OK);
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if (CurPageID = wpFinished) and EinstellungenBehalten then
    WizardForm.FinishedLabel.Caption :=
      WizardForm.FinishedLabel.Caption + #13#10#13#10 +
      'Auf diesem Rechner waren bereits Einstellungen vorhanden. Sie wurden beibehalten; ' +
      'die im Assistenten gewählten Ordner gelten deshalb erst, wenn Sie sie in der ' +
      'Weboberfläche eintragen.';
end;
