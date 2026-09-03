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

[Code]
var
  TunServiceExistedBeforeUpgrade: Boolean;
  TunServiceWasRunningBeforeUpgrade: Boolean;

function TunServiceExists(): Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec(ExpandConstant('{sys}\sc.exe'), 'query LitchiTunService', '',
    SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
end;

function TunServiceIsRunning(): Boolean;
var
  ResultCode: Integer;
  PowerShellPath: String;
  Command: String;
begin
  PowerShellPath := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
  Command := '-NoProfile -NonInteractive -ExecutionPolicy Bypass -Command ' +
    '"$s=Get-Service -Name ''LitchiTunService'' -ErrorAction SilentlyContinue; ' +
    'if ($null -eq $s) { exit 1 }; if ($s.Status -eq ''Running'') { exit 0 }; exit 1"';
  Result := Exec(PowerShellPath, Command, '', SW_HIDE, ewWaitUntilTerminated,
    ResultCode) and (ResultCode = 0);
end;

function StopTunServiceAndWait(): Boolean;
var
  ResultCode: Integer;
  PowerShellPath: String;
  Command: String;
begin
  PowerShellPath := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
  Command := '-NoProfile -NonInteractive -ExecutionPolicy Bypass -Command ' +
    '"$s=Get-Service -Name ''LitchiTunService'' -ErrorAction SilentlyContinue; ' +
    'if ($null -eq $s) { exit 0 }; ' +
    'if ($s.Status -ne ''Stopped'') { ' +
    'Stop-Service -InputObject $s -Force -ErrorAction Stop; ' +
    '$s.WaitForStatus(''Stopped'',[TimeSpan]::FromSeconds(15)) }; exit 0"';
  Result := Exec(PowerShellPath, Command, '', SW_HIDE, ewWaitUntilTerminated,
    ResultCode) and (ResultCode = 0);
end;

function WaitForTunServiceDeleted(): Boolean;
var
  Attempt: Integer;
begin
  for Attempt := 0 to 40 do
  begin
    if not TunServiceExists() then
    begin
      Result := True;
      Exit;
    end;
    Sleep(125);
  end;
  Result := False;
end;

function RemoveTunServiceForUninstall(): Boolean;
var
  ResultCode: Integer;
  CorePath: String;
begin
  Result := True;
  if not TunServiceExists() then
    Exit;

  if not StopTunServiceAndWait() then
  begin
    Result := False;
    Exit;
  end;

  CorePath := ExpandConstant('{app}\litchi-core.exe');
  if FileExists(CorePath) then
  begin
    if Exec(CorePath, 'tun-service uninstall', '', SW_HIDE,
      ewWaitUntilTerminated, ResultCode) and (ResultCode = 0) then
    begin
      Result := WaitForTunServiceDeleted();
      if Result then
        Exit;
    end;
  end;

  ; Fall back to the SCM directly. This path also handles a manually damaged
  ; installation where litchi-core.exe is missing but the service remains.
  if not Exec(ExpandConstant('{sys}\sc.exe'), 'delete LitchiTunService', '',
    SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    Result := False;
    Exit;
  end;
  if (ResultCode <> 0) and TunServiceExists() then
  begin
    Result := False;
    Exit;
  end;
  Result := WaitForTunServiceDeleted();
end;

function InitializeUninstall(): Boolean;
begin
  Result := RemoveTunServiceForUninstall();
  if not Result then
    MsgBox(
      '无法安全移除 Litchi TUN 服务。请重启电脑后再次卸载，避免留下失效的管理员服务。',
      mbError, MB_OK);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  TunServiceExistedBeforeUpgrade := TunServiceExists();
  TunServiceWasRunningBeforeUpgrade := False;

  if not TunServiceExistedBeforeUpgrade then
    Exit;

  TunServiceWasRunningBeforeUpgrade := TunServiceIsRunning();
  if not StopTunServiceAndWait() then
    Result := '无法安全停止 Litchi TUN 服务。请关闭 Litchi 后重试安装，避免升级过程中核心文件被占用。';
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    ; Preserve the service state across upgrades. A service that the user had
    ; intentionally stopped must not be started just because the app updated.
    if TunServiceExistedBeforeUpgrade and TunServiceWasRunningBeforeUpgrade then
      Exec(ExpandConstant('{sys}\sc.exe'), 'start LitchiTunService', '', SW_HIDE,
        ewWaitUntilTerminated, ResultCode);
  end;
end;