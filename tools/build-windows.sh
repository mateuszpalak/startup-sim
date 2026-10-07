#!/bin/bash
# The Windows client as a zip: StartupSim.exe (the game data embedded) and a
# short README, exported headless from macOS or Linux (or Git Bash on Windows).
#
#   tools/build-windows.sh            -> dist/StartupSim3D-<version>-windows-x86_64.zip
#   tools/build-windows.sh --arm64    -> dist/StartupSim3D-<version>-windows-arm64.zip
#   tools/build-windows.sh --all      -> both
#
# Needs: Godot 4.7.2 + its export templates (GODOT=/path/to/godot to pick one).
# No in-game browser on Windows yet (tools/build_webview.sh is macOS only):
# the office browser offers the player's own browser instead.
#
# Signing (optional, not done here): with a code-signing certificate, sign
# the exe before zipping, e.g. on Windows
#   signtool sign /fd sha256 /tr http://timestamp.digicert.com /td sha256 /a StartupSim.exe
# or from macOS/Linux with osslsigncode. Unsigned builds work, but
# SmartScreen warns on first start ("More info" -> "Run anyway").
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GODOT=${GODOT:-godot}
case "${1:-}" in
  "") ARCHS="x86_64" ;;
  --arm64) ARCHS="arm64" ;;
  --all) ARCHS="x86_64 arm64" ;;
  *) echo "użycie: $0 [--arm64|--all]"; exit 1 ;;
esac
VERSION=$(sed -n 's/^config\/version="\(.*\)"/\1/p' "$ROOT/client/project.godot")
[ -n "$VERSION" ] || { echo "brak config/version w client/project.godot"; exit 1; }
[ -f "$ROOT/client/net/servers.cfg" ] || echo "uwaga: brak client/net/servers.cfg — klient będzie znał tylko serwer lokalny"

mkdir -p "$ROOT/dist"
"$GODOT" --headless --path "$ROOT/client" --import >/dev/null 2>&1 || true
for ARCH in $ARCHS; do
  PRESET="Windows"; [ "$ARCH" = arm64 ] && PRESET="Windows arm64"
  NAME="StartupSim3D-$VERSION-windows-$ARCH"
  STAGE="$ROOT/build/$NAME"
  rm -rf "$STAGE" && mkdir -p "$STAGE"
  echo "== eksport z Godota ($PRESET)"
  LOG="$ROOT/build/$NAME.log"
  "$GODOT" --headless --path "$ROOT/client" --export-release "$PRESET" "$STAGE/StartupSim.exe" 2>&1 | tee "$LOG"
  [ -s "$STAGE/StartupSim.exe" ] || { echo "brak $STAGE/StartupSim.exe"; exit 1; }
  if grep -qE "^(ERROR|SCRIPT ERROR)" "$LOG"; then echo "błędy eksportu — zob. $LOG"; exit 1; fi
  printf 'Startup Sim %s (Windows %s)\r\n\r\nUruchom StartupSim.exe. Windows SmartScreen moze ostrzec przy pierwszym\r\nuruchomieniu: "Wiecej informacji" -> "Uruchom mimo to".\r\nUstawienia i logi: %%APPDATA%%\\Godot\\app_userdata\\Startup Sim\r\n' "$VERSION" "$ARCH" > "$STAGE/README.txt"
  ZIP="$ROOT/dist/$NAME.zip"
  rm -f "$ZIP"
  if command -v zip >/dev/null; then
    (cd "$ROOT/build" && zip -qr9 "$ZIP" "$NAME")
  else  # Git Bash on Windows has no zip
    powershell -NoProfile -Command "Compress-Archive -Path '$(cygpath -w "$STAGE")' -DestinationPath '$(cygpath -w "$ZIP")'"
  fi
  echo "gotowe: $ZIP ($(du -h "$ZIP" | cut -f1))"
done
