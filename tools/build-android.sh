#!/bin/bash
# The Android client.
#
#   tools/build-android.sh                 -> build/StartupSim-<version>-debug.apk
#   tools/build-android.sh --install       -> the same, installed and started via adb
#   tools/build-android.sh --release       -> build/StartupSim-<version>.aab (Google Play)
#   tools/build-android.sh --release-apk   -> build/StartupSim-<version>.apk (signed, to sideload)
#
# Needs: Godot 4.7.2 + Android export templates, JDK 17 and the Android SDK
# (paths in Godot's editor settings: export/android/java_sdk_path,
# export/android/android_sdk_path). The debug build is signed with the debug
# keystore from the editor settings.
#
# Release signing only from the environment (never in the repository):
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/path/to/release.keystore
#   GODOT_ANDROID_KEYSTORE_RELEASE_USER=<alias>
#   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<password>
# The .aab is built with Gradle (the build template lands in client/android/,
# not in the repository).
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GODOT=${GODOT:-godot}
SDK=${ANDROID_HOME:-$HOME/Library/Android/sdk}
ADB="$SDK/platform-tools/adb"
PKG=com.mateuszpalak.startupsim3d
VERSION=$(sed -n 's/^config\/version="\(.*\)"/\1/p' "$ROOT/client/project.godot")
mkdir -p "$ROOT/build"

case "${1:-}" in
  --release|--release-apk)
    if [ -z "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]; then
      echo "brak GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD (klucz do podpisu wydania)"
      exit 1
    fi
    if [ "$1" = --release ]; then
      TEMPLATE=()
      [ -d "$ROOT/client/android/build" ] || TEMPLATE=(--install-android-build-template)
      OUT="$ROOT/build/StartupSim-$VERSION.aab"
      "$GODOT" --headless --path "$ROOT/client" ${TEMPLATE[@]+"${TEMPLATE[@]}"} --export-release "Android AAB" "$OUT"
    else
      OUT="$ROOT/build/StartupSim-$VERSION.apk"
      "$GODOT" --headless --path "$ROOT/client" --export-release "Android" "$OUT"
    fi
    ;;
  ""|--install)
    OUT="$ROOT/build/StartupSim-$VERSION-debug.apk"
    "$GODOT" --headless --path "$ROOT/client" --export-debug "Android" "$OUT"
    ;;
  *)
    sed -n '2,8p' "$0"; exit 1 ;;
esac
[ -f "$OUT" ] || { echo "eksport się nie udał"; exit 1; }
echo "-> $OUT"

if [ "${1:-}" = --install ]; then
  "$ADB" install -r "$OUT"
  "$ADB" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
fi
