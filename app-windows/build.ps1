# build.ps1 — 编译 Myco Windows 版并组装成绿色免安装分发包。
#             （对齐 macOS 版 app/build.sh 的"自包含"哲学）
#
# 产物 dist/Myco-win-<version>.zip 内含：
#   Myco.exe + .NET 运行时（self-contained 单文件）
#   engine/  Python 引擎（纯 stdlib）
#   skills/  随附可分发 skill
#   python/  官方 embeddable Python（可用 -NoPython 跳过，改用系统 Python）
#
# 用法：  .\build.ps1                 # 完整包（含内嵌 Python，约 80MB）
#         .\build.ps1 -NoPython       # 轻量包（要求系统装有 Python 3）
param(
    [string]$Version = "0.4.0",
    [switch]$NoPython,
    [string]$PythonEmbedVersion = "3.12.8"
)
$ErrorActionPreference = 'Stop'

$appDir = $PSScriptRoot
$repoRoot = Split-Path $appDir -Parent
$dist = Join-Path $appDir 'dist'
$stage = Join-Path $dist 'Myco-win'

Write-Host "==> [1/4] dotnet publish (self-contained, win-x64, v$Version)"
# 不用 PublishSingleFile：单文件 bundler 的"写入→立即重开"动作会被杀软
# 实时扫描抢占句柄而失败（GenerateBundle: file in use）。普通自包含发布
# 没有这个竞态，代价只是目录里多一批 DLL——双击 Myco.exe 的体验不变。
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
dotnet publish "$appDir\Myco.csproj" -c Release -r win-x64 --self-contained `
    -p:Version=$Version -o $stage --nologo -v q
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed" }
Get-ChildItem $stage -Filter '*.pdb' | Remove-Item

Write-Host "==> [2/4] 打包引擎资源（自包含关键）"
# 只拷运行时真正需要的：Python 引擎 + 随附 skills。排除缓存。
Copy-Item "$repoRoot\engine" "$stage\engine" -Recurse
Get-ChildItem "$stage\engine" -Recurse -Directory -Filter '__pycache__' |
    Remove-Item -Recurse -Force
Copy-Item "$repoRoot\skills" "$stage\skills" -Recurse

if (-not $NoPython) {
    Write-Host "==> [3/4] 内嵌官方 embeddable Python $PythonEmbedVersion"
    $cache = Join-Path $dist 'cache'
    New-Item -ItemType Directory -Force $cache | Out-Null
    $zip = Join-Path $cache "python-$PythonEmbedVersion-embed-amd64.zip"
    if (-not (Test-Path $zip)) {
        $url = "https://www.python.org/ftp/python/$PythonEmbedVersion/python-$PythonEmbedVersion-embed-amd64.zip"
        Write-Host "    下载 $url"
        Invoke-WebRequest $url -OutFile $zip
    } else {
        Write-Host "    ✓ 使用缓存 $zip"
    }
    Expand-Archive $zip "$stage\python"
} else {
    Write-Host "==> [3/4] 跳过内嵌 Python（-NoPython；运行时需系统 Python 3）"
}

Write-Host "==> [4/4] 压缩 Myco-win-$Version.zip"
$out = Join-Path $dist "Myco-win-$Version.zip"
if (Test-Path $out) { Remove-Item $out }
Compress-Archive "$stage\*" $out

Write-Host ""
Write-Host "==> 完成: $out"
Write-Host "    解压后双击 Myco.exe 即用（托盘图标在任务栏右下角）。"
