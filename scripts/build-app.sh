#!/usr/bin/env bash
#
# Build a release binary and wrap it in MenuBarManager.app.
#
# Usage (from anywhere):
#   ./scripts/build-app.sh
#
# The .app is written to the repository root. It is gitignored.
# `swift build` alone produces a bare executable, which is enough to run,
# but Launch at Login and the Finder "no Dock icon" flag need this bundle's
# Info.plist (LSUIElement).

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: MenuBarManager.app can only be built on macOS." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

PLIST="${ROOT}/Resources/Info.plist"
APP="${ROOT}/MenuBarManager.app"

plutil -lint "${PLIST}" >/dev/null

echo "Building release binary…"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
BINARY="${BIN_DIR}/MenuBarManager"

if [[ ! -x "${BINARY}" ]]; then
  echo "error: missing executable at ${BINARY}" >&2
  exit 1
fi

rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"

cp "${BINARY}" "${APP}/Contents/MacOS/MenuBarManager"
chmod +x "${APP}/Contents/MacOS/MenuBarManager"
cp "${PLIST}" "${APP}/Contents/Info.plist"
# Traditional bundle marker: 'APPL' plus a four-byte creator code.
printf 'APPL????' > "${APP}/Contents/PkgInfo"

# Ad-hoc signature. SMAppService refuses an unsigned bundle. A stable
# Developer ID signature is still required before distributing the app.
codesign --force --sign - "${APP}"

LSUI="$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "${APP}/Contents/Info.plist")"
if [[ "${LSUI}" != "true" ]]; then
  echo "error: bundled Info.plist has LSUIElement=${LSUI}, expected true" >&2
  exit 1
fi

echo "Built ${APP}"
echo "Launch it with: open \"${APP}\""
