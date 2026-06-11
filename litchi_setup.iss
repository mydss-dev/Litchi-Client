; All #define values below can be overridden from CI:
;   ISCC /DMyAppName="MyVPN" /DMyAppVersion=1.2.0 /DMyAppPublisher="Acme" litchi_setup.iss

#ifndef MyAppName
  #define MyAppName "Litchi Client"
#endif
#ifndef MyAppPublisher
  #define MyAppPublisher "Litchi"
#endif
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

#define MyAppExeName "litchi_client.exe"
#define BuildDir     "build\windows\x64\runner\Release"
#define AppIcon      "windows\runner\resources\app_icon.ico"

[Setup]
AppId={{6F4A2B8C-D1E3-4F57-9A0B-2C5E8D7F1234}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppVerName={#MyAppName} {#MyAppVersion}
DefaultDirName={autopf}\LitchiClient
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
SetupIconFile={#AppIcon}
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=installer_output
OutputBaseFilename=LitchiClient-Setup-{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
; TUN 模式需要管理员权限写入驱动
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; 卸载前关闭进程
CloseApplications=yes
CloseApplicationsFilter=*{#MyAppExeName}

[Languages]
Name: "english";           MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加选项:"; Flags: checkedonce

[Files]
; 整个 Release 目录（含 sing-box.exe / wintun.dll / Flutter DLLs / data/）
Source: "{#BuildDir}\*"; DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}";                          Filename: "{app}\{#MyAppExeName}"
Name: "{group}\卸载 {#MyAppName}";                     Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}";                    Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; \
  Description: "启动 {#MyAppName}"; \
  Flags: nowait postinstall skipifsilent

[UninstallRun]
; 卸载前强制关闭主进程
Filename: "taskkill.exe"; Parameters: "/F /IM {#MyAppExeName}"; Flags: runhidden; RunOnceId: "KillApp"
