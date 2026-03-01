#define MyAppName "Video Block"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Video Block"
#define MyAppExeName "video_block.exe"

; ─────────────────────────────────────────────────────────────────────────────
; WebView2 Evergreen Bootstrapper
; Được tải tự động bởi build_exe_installer.ps1 trước khi compile installer này.
; Bootstrapper (~1.8 MB) sẽ tải WebView2 Runtime từ Microsoft CDN lúc cài đặt.
; ─────────────────────────────────────────────────────────────────────────────
#define WebView2Bootstrapper "MicrosoftEdgeWebview2Setup.exe"

[Setup]
AppId={{B2B2E5FD-91EF-4CE8-AFAD-6D46A36C5531}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\build\installer
OutputBaseFilename=video_block_setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
; App files
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; WebView2 bootstrapper – chỉ cần trong quá trình cài, xóa sau khi xong
Source: "{#WebView2Bootstrapper}"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; 1. Cài WebView2 Runtime nếu máy chưa có (silent, không cần restart)
Filename: "{tmp}\{#WebView2Bootstrapper}"; Parameters: "/silent /install"; \
  StatusMsg: "Installing Microsoft Edge WebView2 Runtime (required)..."; \
  Check: not IsWebView2Installed; Flags: waituntilterminated
; 2. Chạy ứng dụng sau khi cài xong
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[Code]
// ─── Kiểm tra WebView2 Evergreen Runtime đã được cài chưa ───────────────────
// Microsoft đăng ký runtime tại registry key sau, với giá trị pv là version string.
// Nếu pv = "0.0.0.0" hoặc rỗng → chưa cài.
function IsWebView2Installed: Boolean;
var
  version: String;
begin
  // Kiểm tra 64-bit registry (Windows 64-bit)
  Result := RegQueryStringValue(
    HKLM,
    'SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
    'pv', version
  ) and (version <> '') and (version <> '0.0.0.0');

  // Fallback: kiểm tra native registry path
  if not Result then
    Result := RegQueryStringValue(
      HKLM,
      'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
      'pv', version
    ) and (version <> '') and (version <> '0.0.0.0');

  // Fallback: kiểm tra HKCU (installed per-user)
  if not Result then
    Result := RegQueryStringValue(
      HKCU,
      'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
      'pv', version
    ) and (version <> '') and (version <> '0.0.0.0');
end;
