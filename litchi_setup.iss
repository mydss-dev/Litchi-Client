#ifndef MyAppId
  #define MyAppId "com.litchi.client"
#endif
#ifndef MyAppName
  #define MyAppName "Litchi"
#endif
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#ifndef MyAppPublisher
  #define MyAppPublisher MyAppName
#endif
#ifndef MyAppExeName
  #define MyAppExeName "Client.exe"
#endif
#ifndef MyOutputDir
  #define MyOutputDir "installer_output"
#endif
#ifndef MyOutputBaseFilename
  #define MyOutputBaseFilename MyAppName + "-" + MyAppVersion
#endif

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableDirPage=no
DisableProgramGroupPage=yes
OutputDir={#MyOutputDir}
OutputBaseFilename={#MyOutputBaseFilename}
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=force
RestartApplications=no

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Default.isl,compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加图标："; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
Type: files; Name: "{app}\Client.exe"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "启动 {#MyAppName}"; Flags: nowait postinstall skipifsilent runasoriginaluser
