# 发版手册（RELEASING）

> 面向下一个发版的人（或 AI）。0.4.0 是第一个照此流程发的版本，
> 本文把当时踩过的坑一并记录。全流程可以在一台 Windows 机器上完成
> （DMG 由 GitHub Actions 的 macOS 跑机代打）。

## 版本号要改哪几处

一次发版 = 同一个版本号出现在这些地方（grep 旧版本号确认无遗漏）：

| 位置 | 说明 |
|---|---|
| `CHANGELOG.md` | `[Unreleased]` 归档成 `[x.y.z] — 日期`，底部加 compare 链接 |
| `app/build.sh` | `MYCO_VERSION:-x.y.z` 默认值（macOS） |
| `app/package_dmg.sh` | 同上 |
| `app-windows/Myco.csproj` | `<Version>` |
| `app-windows/build.ps1` | `$Version` 参数默认值 |
| `app-windows/installer.iss` | `MyAppVersion` 默认值 |
| `app-windows/Views/SettingsView.xaml` | 设置页落款「v0.x」 |

## 发版步骤

```powershell
# 0) 确认干净 & CI 绿
git status; git log origin/master..master

# 1) 归档 CHANGELOG + 统一版本号（见上表），提交

# 2) 打 Windows 产物（zip + 安装器）
Get-Process Myco -EA SilentlyContinue | Stop-Process -Force   # 见坑 #1
app-windows\build.ps1 -Installer
# 产物：app-windows\dist\Myco-win-<v>.zip / Myco-Setup-<v>.exe

# 3) 烟测分发包（脱离仓库、用包内 Python）
#    MYCO_PREVIEW=1 启动 dist 里的 exe，确认面板五页正常

# 4) tag + 推送
git tag v<x.y.z>
git push origin master v<x.y.z>

# 5) 建 Release（发布说明手写，参考上一版的结构；中英混排）
gh release create v<x.y.z> --title "v<x.y.z> — <一句话主题>" `
  --notes-file <notes.md> --latest `
  app-windows\dist\Myco-Setup-<v>.exe app-windows\dist\Myco-win-<v>.zip

# 6) DMG：release-macos.yml 会在 Release 发布时自动触发；
#    没触发/失败就手动跑：
gh workflow run release-macos.yml -f tag=v<x.y.z>
gh run watch --exit-status   # 成功后 Myco-<v>.dmg 自动挂到 Release

# 7) 复核资产齐全（exe + zip + dmg）
gh release view v<x.y.z> --json assets
```

## 发布说明的固定结构

参考 v0.4.0 / v0.3.1：主题标题 → 分区（New / Changed / Fixed，带 emoji
小标题）→ `Install (Windows)` / `Install (macOS)` 指引（含 SmartScreen /
Gatekeeper 一次性放行说明）→ Full changelog compare 链接。
`CHANGELOG.md` 对应版本段就是底稿。

## 踩过的坑（0.4.0 实录）

1. **打包前必须杀掉运行中的 Myco.exe**，否则 `dotnet publish` 写不进
   `dist\Myco-win\`（file in use）。顽固锁再补一发
   `dotnet build-server shutdown`。
2. **不要用 PublishSingleFile**：单文件 bundler 的"写入→立即重开"会被
   杀软实时扫描抢句柄，稳定失败。`build.ps1` 已固定为普通自包含发布。
3. **PowerShell 提交信息里别放英文双引号**：PS 5.1 给原生 exe 传参会把
   内嵌 `"` 吃掉，git 会把消息劈成多个参数报 pathspec 错误。
4. **tag 打早了要挪**：Release 未创建前可以安全地
   `git push origin :refs/tags/vX`（删远端）再重推；Release 已建就别动。
5. **gh 授权**是一次性的（设备码流程，15 分钟内在浏览器完成），
   令牌存在系统凭据库里，之后发版不用重来。
6. **DMG 与 README 链接**：README 安装节的 macOS 链接指向
   `releases/latest`——前提是每个 Release 都有 DMG。如果 DMG 工作流
   失败，要么修好重跑，要么临时把链接指到最近一个带 DMG 的 tag。

## 平台产物一览

| 产物 | 打法 | 大小量级 |
|---|---|---|
| `Myco-Setup-<v>.exe` | 本地 `build.ps1 -Installer`（Inno Setup 6） | ~57MB |
| `Myco-win-<v>.zip` | 本地 `build.ps1` | ~77MB |
| `Myco-<v>.dmg` | CI：`release-macos.yml`（macos-14，Apple Silicon） | ~0.5MB |
