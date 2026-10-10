; GoDigital Medienimport - Installationsprogramm
; Gebaut mit Inno Setup 6. Siehe installer\liesmich.md.
;
; AppVersion kommt als /D-Definition vom Bauskript, das VERSION liest. Die
; Versionsnummer steht ausschliesslich dort; der Wert hier faengt nur den Fall
; ab, dass jemand den Compiler von Hand aufruft.

#ifndef AppVersion
  #define AppVersion "0.0.0-handbetrieb"
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

[Code]
var
  OrdnerSeite: TInputDirWizardPage;

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
