; Inno Setup — Todo Flutter Windows 安装程序（由 desktop.yml 传入 /DAppVersion=）
#define MyAppName "Todo Flutter"
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#define MyAppExeName "zh_cloud_todo_flutter.exe"
#define MyAppPublisher "ZH Cloud"
#define MyAppURL "https://client-todo.zh04.com"
#define MyOutputBase "todo-flutter-{#AppVersion}-x86_64"

[Setup]
AppId={{A3F8C2E1-9B4D-4F6A-8C1E-2D5E7A9B0C3F}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\Todo Flutter
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputBaseFilename={#MyOutputBase}
OutputDir=..\..\.gha-dist\desktop
Compression=lzma2
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
