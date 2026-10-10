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
