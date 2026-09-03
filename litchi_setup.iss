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
; v1.1.3 and older shipped the Windows core as an in-process DLL. Remove it
; explicitly during upgrades so old runtime files can never shadow the new
; isolated litchi-core.exe architecture.
Type: files; Name: "{app}\litchi_singbox.dll"
Type: files; Name: "{app}\core\litchi_singbox.dll"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "启动 {#MyAppName}"; Flags: nowait postinstall skipifsilent runasoriginaluser

[UninstallRun]
; The TUN service is installed lazily on first TUN use. Remove it before the
; bundled core executable disappears so no privileged service is orphaned.
Filename: "{app}\litchi-core.exe"; Parameters: "tun-service uninstall"; Flags: runhidden waituntilterminated skipifdoesntexist

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssInstall then
  begin
    ; A running Windows service locks litchi-core.exe. Stop it before upgrade
    ; file replacement. Missing service is expected on first install.
    Exec(ExpandConstant('{sys}\sc.exe'), 'stop LitchiTunService', '', SW_HIDE,
      ewWaitUntilTerminated, ResultCode);
    Sleep(1200);
  end
  else if CurStep = ssPostInstall then
  begin
    ; If the user had already installed the lazy TUN service, bring it back on
    ; the freshly installed binary. Missing service remains a harmless no-op.
    Exec(ExpandConstant('{sys}\sc.exe'), 'start LitchiTunService', '', SW_HIDE,
      ewWaitUntilTerminated, ResultCode);
  end;
end;
