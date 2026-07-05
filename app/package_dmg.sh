#!/usr/bin/env bash
# package_dmg.sh — 把 Conduit.app 打包成可拖拽安装的 DMG。
# 依赖 build.sh 先产出 Conduit.app。产物 Conduit-<version>.dmg 用于 GitHub Release 分发。
set -euo pipefail

cd "$(dirname "$0")"
APP_NAME="Conduit"
APP_BUNDLE="$APP_NAME.app"
VERSION="${CONDUIT_VERSION:-0.1.0}"
DMG_NAME="$APP_NAME-$VERSION.dmg"
VOL_NAME="$APP_NAME $VERSION"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "✗ 未找到 $APP_BUNDLE，请先运行 ./build.sh"
  exit 1
fi

echo "==> [1/4] 准备 DMG 暂存目录"
STAGE="$(mktemp -d)/dmg"
mkdir -p "$STAGE"
cp -R "$APP_BUNDLE" "$STAGE/"
# /Applications 软链 —— 用户把 App 往它上面拖即完成安装
ln -s /Applications "$STAGE/Applications"

echo "==> [2/4] 写安装提示"
cat > "$STAGE/安装说明.txt" <<TXT
Conduit — one workspace, every agent

安装：把 Conduit.app 拖到右侧 Applications 文件夹即可。

首次打开（Gatekeeper）：
本 App 使用 ad-hoc 签名（未经 Apple 公证）。首次打开时若被拦截：
  方式一：右键点 Conduit.app → 打开 → 在弹窗里再点“打开”。
  方式二：系统设置 → 隐私与安全性 → 找到 Conduit 的拦截提示 → “仍要打开”。
之后即可从菜单栏（顶部右侧的三层叠图标）正常使用。

需要 macOS 13+，并已安装 Command Line Tools（系统自带 python3 即可）。
TXT

echo "==> [3/4] hdiutil 生成压缩 DMG"
rm -f "$DMG_NAME"
hdiutil create -volname "$VOL_NAME" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG_NAME" >/dev/null

rm -rf "$(dirname "$STAGE")"

echo "==> [4/4] 完成"
SIZE="$(du -h "$DMG_NAME" | awk '{print $1}')"
echo "    ✓ $(pwd)/$DMG_NAME  ($SIZE)"
echo "    分发：上传到 GitHub Release 作为 asset；用户下载后双击 → 拖入 Applications。"
