; x360 Tools v2.0 - Inno Setup Configuration
; This script creates a professional Windows Installer (.exe)

[Setup]
AppName=x360 Tools
AppVersion=2.0
DefaultDirName={autopf}\x360Tools
DefaultGroupName=x360 Tools
UninstallDisplayIcon={app}\x360_tools_flutter.exe
Compression=lzma2/max
SolidCompression=yes
OutputDir=.\installer_output
OutputBaseFilename=x360Tools_Setup
SetupIconFile=x360_tools_flutter\windows\runner\resources\app_icon.ico
WizardStyle=modern

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Flutter Executable and Core DLLs
Source: "x360_tools_flutter\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

; Python Backend (Bundled assets)
; This assumes build_windows.ps1 has been run and assets are in data/flutter_assets/assets/python_backend
Source: "x360_tools_flutter\build\windows\x64\runner\Release\data\flutter_assets\assets\python_backend\*"; DestDir: "{app}\data\flutter_assets\assets\python_backend"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\x360 Tools"; Filename: "{app}\x360_tools_flutter.exe"
Name: "{autodesktop}\x360 Tools"; Filename: "{app}\x360_tools_flutter.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\x360_tools_flutter.exe"; Description: "{cm:LaunchProgram,x360 Tools}"; Flags: nowait postinstall skipifsilent
