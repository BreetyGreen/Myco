#!/usr/bin/env bash
# build.sh — 编译 Myco 并组装成自包含、可分发的纯菜单栏 .app
#            （无需 Xcode，仅 Command Line Tools）。
#
# 产物 Myco.app 是自包含的：Python 引擎 + 随附 skills 都打进 Contents/Resources/，
# 双击即可运行，不依赖 MYCO_REPO 环境变量或任何外部仓库路径。
set -euo pipefail

cd "$(dirname "$0")"
APP_NAME="Myco"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
REPO_ROOT="$(cd .. && pwd)"
VERSION="${MYCO_VERSION:-0.3.1}"

echo "==> [1/6] swift build -c release"
swift build -c release

echo "==> [2/6] 组装 $APP_BUNDLE 骨架"
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BUILD_DIR/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME"

echo "==> [3/6] 打包引擎资源进 bundle（自包含关键）"
# 只拷运行时真正需要的：Python 引擎包 + 随附 skills。排除缓存。
mkdir -p "$CONTENTS/Resources/engine" "$CONTENTS/Resources/skills"
rsync -a --exclude='__pycache__' --exclude='*.pyc' \
      "$REPO_ROOT/engine/" "$CONTENTS/Resources/engine/"
rsync -a "$REPO_ROOT/skills/" "$CONTENTS/Resources/skills/"

echo "==> [4/6] 生成 .icns 应用图标（源：assets/logo-icon.png）"
ICON_SRC="$REPO_ROOT/assets/logo-icon.png"
if [[ -f "$ICON_SRC" ]]; then
  ICONSET="$(mktemp -d)/Myco.iconset"
  mkdir -p "$ICONSET"
  for sz in 16 32 64 128 256 512; do
    sips -z $sz $sz "$ICON_SRC" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null 2>&1
    dbl=$((sz*2))
    sips -z $dbl $dbl "$ICON_SRC" --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null 2>&1
  done
  iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns" 2>/dev/null || true
  rm -rf "$(dirname "$ICONSET")"
  echo "    ✓ AppIcon.icns"
else
  echo "    ⚠ 未找到 $ICON_SRC，跳过图标"
fi

echo "==> [5/6] 写 Info.plist"
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>com.myco.app</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
PLIST

echo "==> [6/6] ad-hoc 代码签名（无 Apple 开发者账号）"
# ad-hoc 签名（-s -）让 App 能在本机运行；分发时用户仍需在"系统设置>隐私与安全性"放行一次。
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null \
  && echo "    ✓ 已 ad-hoc 签名" \
  || echo "    ⚠ 签名失败（不影响本机运行，但 Gatekeeper 提示会更严格）"

echo ""
echo "==> 完成: $(pwd)/$APP_BUNDLE  (v$VERSION, 自包含)"
echo "    直接运行:   open \"$(pwd)/$APP_BUNDLE\""
echo "    安装到系统: cp -R \"$(pwd)/$APP_BUNDLE\" /Applications/"
echo "    开发调试:   MYCO_REPO=\"$REPO_ROOT\" open \"$(pwd)/$APP_BUNDLE\""
