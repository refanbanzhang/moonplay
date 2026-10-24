#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="${HOME}/Applications/Moonplay Web.app"
CONTENTS="${APP_DIR}/Contents"
RESOURCES="${CONTENTS}/Resources"
MACOS="${CONTENTS}/MacOS"
ICON_SOURCE="${ROOT}/Assets.xcassets/AppIcon.appiconset"
PORT="${1:-8080}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: 需要安装 Python 3 才能启动 Moonplay Web" >&2
  exit 1
fi

rm -rf "${APP_DIR}"
mkdir -p "${MACOS}" "${RESOURCES}"

if command -v iconutil >/dev/null 2>&1; then
  ICONSET="$(mktemp -d "${TMPDIR:-/tmp}/moonplay.XXXXXX.iconset")"
  cleanup_iconset() { rm -rf "${ICONSET}"; }
  trap cleanup_iconset EXIT

  cp "${ICON_SOURCE}/AppIcon-16.png" "${ICONSET}/icon_16x16.png"
  cp "${ICON_SOURCE}/AppIcon-32.png" "${ICONSET}/icon_16x16@2x.png"
  cp "${ICON_SOURCE}/AppIcon-32.png" "${ICONSET}/icon_32x32.png"
  cp "${ICON_SOURCE}/AppIcon-64.png" "${ICONSET}/icon_32x32@2x.png"
  cp "${ICON_SOURCE}/AppIcon-128.png" "${ICONSET}/icon_128x128.png"
  cp "${ICON_SOURCE}/AppIcon-256.png" "${ICONSET}/icon_128x128@2x.png"
  cp "${ICON_SOURCE}/AppIcon-256.png" "${ICONSET}/icon_256x256.png"
  cp "${ICON_SOURCE}/AppIcon-512.png" "${ICONSET}/icon_256x256@2x.png"
  cp "${ICON_SOURCE}/AppIcon-512.png" "${ICONSET}/icon_512x512.png"
  cp "${ICON_SOURCE}/AppIcon-1024.png" "${ICONSET}/icon_512x512@2x.png"
  iconutil -c icns "${ICONSET}" -o "${RESOURCES}/AppIcon.icns"
fi

cat > "${CONTENTS}/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>Moonplay Web</string>
  <key>CFBundleExecutable</key>
  <string>Moonplay Web</string>
  <key>CFBundleIdentifier</key>
  <string>com.moonplay.web-launcher</string>
  <key>CFBundleName</key>
  <string>Moonplay Web</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
</dict>
</plist>
PLIST

cat > "${MACOS}/Moonplay Web" <<LAUNCHER
#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT}"
WEB_DIR="${ROOT}/web"
LOG_FILE="\${TMPDIR:-/tmp}/moonplay-web.log"

if ! curl -fsS "http://127.0.0.1:\${PORT}/" >/dev/null 2>&1; then
  nohup python3 -m http.server "\${PORT}" --bind 127.0.0.1 --directory "\${WEB_DIR}" >"\${LOG_FILE}" 2>&1 &
  for _ in \$(seq 1 20); do
    if curl -fsS "http://127.0.0.1:\${PORT}/" >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done
fi

open "http://127.0.0.1:\${PORT}"
LAUNCHER

chmod +x "${MACOS}/Moonplay Web"
open "${APP_DIR}"

echo "已创建：${APP_DIR}"
echo "把「Moonplay Web.app」拖到 Dock 即可快捷启动。"
