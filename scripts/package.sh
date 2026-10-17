#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="Moonplay"
CONFIG="Release"
DERIVED="${ROOT}/build/DerivedData"
APP="${DERIVED}/Build/Products/Release/Moonplay.app"
DIST="${ROOT}/dist"
VERSION="${1:-1}"

mkdir -p "${DIST}"

echo "==> xcodebuild ${CONFIG}"
xcodebuild \
  -scheme "${SCHEME}" \
  -configuration "${CONFIG}" \
  -derivedDataPath "${DERIVED}" \
  build \
  -quiet

if [[ ! -d "${APP}" ]]; then
  echo "error: missing ${APP}" >&2
  exit 1
fi

STAMP="$(date +%Y%m%d-%H%M)"
BASENAME="Moonplay-v${VERSION}-${STAMP}"

STAGE="$(mktemp -d /tmp/moonplaypkg.XXXXXX)"
cleanup() { rm -rf "${STAGE}"; }
trap cleanup EXIT

cp -R "${APP}" "${STAGE}/"
ln -sf /Applications "${STAGE}/Applications"

DMG="${DIST}/${BASENAME}.dmg"
ZIP="${DIST}/${BASENAME}.zip"

echo "==> DMG -> ${DMG}"
rm -f "${DMG}"
hdiutil create \
  -volname "Moonplay" \
  -srcfolder "${STAGE}" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "${DMG}"

echo "==> ZIP -> ${ZIP}"
rm -f "${ZIP}"
ditto -c -k --keepParent "${APP}" "${ZIP}"

echo "==> done"
ls -lh "${DMG}" "${ZIP}"
