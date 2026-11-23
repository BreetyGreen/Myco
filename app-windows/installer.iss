; installer.iss — Myco Windows 安装程序（Inno Setup）。
;
; 设计对齐项目的轻量哲学：
;   - 按用户安装（%LOCALAPPDATA%\Programs\Myco），不需要管理员权限
;   - 开始菜单快捷方式 + 系统「卸载程序」标准入口
;   - 可选任务：桌面快捷方式、开机自启（默认都不勾）
;   - 载荷直接取 build.ps1 产出的 dist\Myco-win\（先跑 build.ps1 再编译本脚本）
;
; 编译：  iscc installer.iss    （或 build.ps1 -Installer 一条龙）
; 产物：  dist\Myco-Setup-<version>.exe

#define MyAppName "Myco"
#ifndef MyAppVersion
  #define MyAppVersion "0.4.1"
#endif
#define MyAppPublisher "BreetyGreen"
#define MyAppURL "https://github.com/BreetyGreen/Myco"
#define MyAppExeName "Myco.exe"

[Setup]
; 固定 GUID：升级安装时用它识别旧版本，绝不要改
AppId={{8E5A2C64-3F1B-4D2A-9C7E-6B4F0A1D8E55}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
; 按用户安装：不弹 UAC，装到 %LOCALAPPDATA%\Programs\Myco
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=dist
OutputBaseFilename=Myco-Setup-{#MyAppVersion}
SetupIconFile=app.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; 升级/卸载前先请求关闭正在运行的 Myco
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; Flags: unchecked
Name: "startup"; Description: "Start Myco automatically when I sign in"; Flags: unchecked

[Files]
; 整个自包含发布目录：exe + .NET 运行时 + engine/ + skills/ + python/
Source: "dist\Myco-win\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startup

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

; 卸载时清理托盘应用进程；用户数据（文档\Myco）刻意保留，绝不删。
[UninstallRun]
Filename: "taskkill"; Parameters: "/f /im {#MyAppExeName}"; Flags: runhidden skipifdoesntexist; RunOnceId: "KillMyco"
