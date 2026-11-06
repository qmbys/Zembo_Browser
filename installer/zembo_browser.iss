; Установщик Zembo Browser (Inno Setup 6.1 или новее).
; Собирается скриптом build_installer.ps1 — он сам подготовит папку stage.

#define AppName "Zembo Browser"
#define AppVersion "1.0.0"
#define AppExe "zembo_browser.exe"
#define AppPublisher "Zembo"
#define StageDir "stage"

[Setup]
AppId={{B7C1D1E4-5A1F-4C27-9E3B-6A0F1D7E2C41}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\Zembo Browser
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=output
OutputBaseFilename=ZemboBrowser-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Можно ставить без прав администратора (в профиль) или для всех пользователей.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
CloseApplications=yes
RestartApplications=no
UsePreviousAppDir=yes

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "ukrainian"; MessagesFile: "compiler:Languages\Ukrainian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
russian.DeleteData=Удалить также настройки, историю и сохранённые пароли Zembo Browser?
ukrainian.DeleteData=Видалити також налаштування, історію та збережені паролі Zembo Browser?
english.DeleteData=Also delete Zembo Browser settings, history and saved passwords?
russian.InstallingWebView2=Устанавливаю компонент Microsoft WebView2...
ukrainian.InstallingWebView2=Встановлюю компонент Microsoft WebView2...
english.InstallingWebView2=Installing the Microsoft WebView2 component...
russian.SetDefault=Сделать Zembo Browser браузером по умолчанию (откроются настройки Windows)
ukrainian.SetDefault=Зробити Zembo Browser браузером за замовчуванням (відкриються налаштування Windows)
english.SetDefault=Make Zembo Browser the default browser (Windows settings will open)
russian.WebView2Failed=Не удалось установить Microsoft WebView2. Браузер может не запуститься: установите WebView2 Runtime вручную с сайта Microsoft.
ukrainian.WebView2Failed=Не вдалося встановити Microsoft WebView2. Браузер може не запуститися: встановіть WebView2 Runtime вручну з сайту Microsoft.
english.WebView2Failed=Could not install Microsoft WebView2. The browser may not start: install the WebView2 Runtime manually from Microsoft's website.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#StageDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Registry]
; Zembo Browser появляется в списке браузеров Windows («Приложения по умолчанию»).
Root: HKA; Subkey: "Software\Classes\ZemboBrowserURL"; ValueType: string; ValueData: "Zembo Browser URL"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\ZemboBrowserURL"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\ZemboBrowserURL\DefaultIcon"; ValueType: string; ValueData: """{app}\{#AppExe}"",0"
Root: HKA; Subkey: "Software\Classes\ZemboBrowserURL\shell\open\command"; ValueType: string; ValueData: """{app}\{#AppExe}"" ""%1"""
Root: HKA; Subkey: "Software\Classes\ZemboBrowserHTML"; ValueType: string; ValueData: "Zembo Browser HTML Document"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\ZemboBrowserHTML\DefaultIcon"; ValueType: string; ValueData: """{app}\{#AppExe}"",0"
Root: HKA; Subkey: "Software\Classes\ZemboBrowserHTML\shell\open\command"; ValueType: string; ValueData: """{app}\{#AppExe}"" ""%1"""
Root: HKA; Subkey: "Software\Clients\StartMenuInternet\ZemboBrowser"; ValueType: string; ValueData: "Zembo Browser"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Clients\StartMenuInternet\ZemboBrowser\DefaultIcon"; ValueType: string; ValueData: """{app}\{#AppExe}"",0"
Root: HKA; Subkey: "Software\Clients\StartMenuInternet\ZemboBrowser\shell\open\command"; ValueType: string; ValueData: """{app}\{#AppExe}"""
Root: HKA; Subkey: "Software\Clients\StartMenuInternet\ZemboBrowser\Capabilities"; ValueType: string; ValueName: "ApplicationName"; ValueData: "Zembo Browser"
Root: HKA; Subkey: "Software\Clients\StartMenuInternet\ZemboBrowser\Capabilities"; ValueType: string; ValueName: "ApplicationDescription"; ValueData: "Zembo Browser"
Root: HKA; Subkey: "Software\Clients\StartMenuInternet\ZemboBrowser\Capabilities"; ValueType: string; ValueName: "ApplicationIcon"; ValueData: """{app}\{#AppExe}"",0"
Root: HKA; Subkey: "Software\Clients\StartMenuInternet\ZemboBrowser\Capabilities\StartMenu"; ValueType: string; ValueName: "StartMenuInternet"; ValueData: "ZemboBrowser"
Root: HKA; Subkey: "Software\Clients\StartMenuInternet\ZemboBrowser\Capabilities\URLAssociations"; ValueType: string; ValueName: "http"; ValueData: "ZemboBrowserURL"
Root: HKA; Subkey: "Software\Clients\StartMenuInternet\ZemboBrowser\Capabilities\URLAssociations"; ValueType: string; ValueName: "https"; ValueData: "ZemboBrowserURL"
Root: HKA; Subkey: "Software\Clients\StartMenuInternet\ZemboBrowser\Capabilities\FileAssociations"; ValueType: string; ValueName: ".htm"; ValueData: "ZemboBrowserHTML"
Root: HKA; Subkey: "Software\Clients\StartMenuInternet\ZemboBrowser\Capabilities\FileAssociations"; ValueType: string; ValueName: ".html"; ValueData: "ZemboBrowserHTML"
Root: HKA; Subkey: "Software\Clients\StartMenuInternet\ZemboBrowser\Capabilities\FileAssociations"; ValueType: string; ValueName: ".shtml"; ValueData: "ZemboBrowserHTML"
Root: HKA; Subkey: "Software\Clients\StartMenuInternet\ZemboBrowser\Capabilities\FileAssociations"; ValueType: string; ValueName: ".xhtml"; ValueData: "ZemboBrowserHTML"
Root: HKA; Subkey: "Software\RegisteredApplications"; ValueType: string; ValueName: "ZemboBrowser"; ValueData: "Software\Clients\StartMenuInternet\ZemboBrowser\Capabilities"; Flags: uninsdeletevalue

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
Filename: "ms-settings:defaultbrowser"; Description: "{cm:SetDefault}"; Flags: shellexec postinstall skipifsilent unchecked

[Code]
const
  WebView2Guid = '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}';

function WebView2Installed: Boolean;
var
  v: String;
begin
  Result := False;
  if RegQueryStringValue(HKLM, 'SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\' + WebView2Guid, 'pv', v) then
    Result := (v <> '') and (v <> '0.0.0.0');
  if not Result then
    if RegQueryStringValue(HKCU, 'Software\Microsoft\EdgeUpdate\Clients\' + WebView2Guid, 'pv', v) then
      Result := (v <> '') and (v <> '0.0.0.0');
end;

// Браузеру нужен Microsoft WebView2 (в Windows 11 он уже есть). Если его нет — скачиваем.
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  setupPath: String;
  code: Integer;
begin
  Result := '';
  if WebView2Installed then Exit;
  WizardForm.StatusLabel.Caption := CustomMessage('InstallingWebView2');
  try
    DownloadTemporaryFile('https://go.microsoft.com/fwlink/p/?LinkId=2124703',
      'MicrosoftEdgeWebview2Setup.exe', '', nil);
    setupPath := ExpandConstant('{tmp}\MicrosoftEdgeWebview2Setup.exe');
    if (not Exec(setupPath, '/silent /install', '', SW_HIDE, ewWaitUntilTerminated, code)) or (code <> 0) then
      MsgBox(CustomMessage('WebView2Failed'), mbInformation, MB_OK);
  except
    MsgBox(CustomMessage('WebView2Failed'), mbInformation, MB_OK);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    if not UninstallSilent then
      if MsgBox(CustomMessage('DeleteData'), mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
        DelTree(ExpandConstant('{userappdata}\ZemboBrowser'), True, True, True);
  end;
end;
