#!/bin/bash
# The iOS client: Godot exports an Xcode project, xcodebuild builds it,
# simctl / devicectl install it.
#
#   tools/build-ios.sh sim       -> build, install and launch in the iOS Simulator
#                                   (SIM="iPhone 18 Pro" by default; unsigned)
#   tools/build-ios.sh device    -> build signed for a phone and install it on the
#                                   connected one (needs DEVELOPMENT_TEAM)
#   tools/build-ios.sh archive   -> build/ios/StartupSim.ipa for TestFlight / App Store
#                                   (needs DEVELOPMENT_TEAM, paid account)
#   tools/build-ios.sh project   -> only the Xcode project in build/ios (open it in Xcode)
#   CLIENT=client tools/build-ios.sh ...  -> the same for the 2D client (in build/ios2d*)
#
# Who signs: DEVELOPMENT_TEAM (the 10-character Team ID, Xcode → Settings →
# Accounts) from the environment or tools/ios/signing.env (not in the
# repository). The export preset has only a placeholder team; xcodebuild
# gets the real one, with automatic signing (-allowProvisioningUpdates).
# DEVICE: name or UDID of the phone (default: the first connected one).
#
# Simulator: the official Godot templates have no arm64 simulator library
# and the simulator GPU cannot run Godot's Metal renderers, so the "iOS
# Simulator" preset uses the Compatibility (OpenGL) renderer and this script
# links the device library retagged for the simulator. Good for checking UI
# and flow, not looks or speed - those only on a phone (Mobile renderer).
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
# Which client: the 3D one (client3d/, default) or CLIENT=client for the 2D
# one; file names and app ids follow (StartupSim3D-* / StartupSim-*).
CLIENT=${CLIENT:-client3d}
. "$ROOT/tools/client.sh"
[ -f "$ROOT/tools/ios/signing.env" ] && . "$ROOT/tools/ios/signing.env"
MODE=${1:-sim}
TEAM=${DEVELOPMENT_TEAM:-}
SIM=${SIM:-iPhone 18 Pro}
GODOT=${GODOT:-godot}

case "$MODE" in
  sim) PRESET="iOS Simulator"; OUT="$ROOT/build/ios$DIR_TAG-sim" ;;
  device|archive|project) PRESET="iOS"; OUT="$ROOT/build/ios$DIR_TAG" ;;
  *) echo "użycie: $0 sim|device|archive|project"; exit 1 ;;
esac
if [ "$MODE" = device ] || [ "$MODE" = archive ]; then
  [ -n "$TEAM" ] || { echo "brak DEVELOPMENT_TEAM (Team ID z Xcode → Settings → Accounts) — w środowisku albo w tools/ios/signing.env"; exit 1; }
fi
[ -f "$ROOT/$CLIENT/net/servers.cfg" ] || echo "uwaga: brak $CLIENT/net/servers.cfg — klient będzie znał tylko serwer lokalny"

echo "== eksport z Godota ($PRESET)"
rm -rf "$OUT" && mkdir -p "$OUT"
"$GODOT" --headless --path "$ROOT/$CLIENT" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT/$CLIENT" --export-debug "$PRESET" "$OUT/StartupSim.xcodeproj" >"$OUT/export.log" 2>&1 \
  || { tail -20 "$OUT/export.log"; exit 1; }
[ -d "$OUT/StartupSim.xcodeproj" ] || { tail -20 "$OUT/export.log"; exit 1; }
[ "$MODE" = project ] && { echo "gotowe: $OUT/StartupSim.xcodeproj"; exit 0; }

DD="$OUT/dd"
XB=(xcodebuild -project "$OUT/StartupSim.xcodeproj" -scheme StartupSim -derivedDataPath "$DD" -quiet)

if [ "$MODE" = sim ]; then
  echo "== biblioteka Godota dla symulatora (arm64)"
  LIB="$OUT/StartupSim.xcframework/ios-arm64_x86_64-simulator/libgodot.a"
  cp "$OUT/StartupSim.xcframework/ios-arm64/libgodot.a" "$LIB"
  python3 "$ROOT/tools/ios/retag_simulator.py" "$LIB"
  xcrun -sdk iphonesimulator clang -arch arm64 -mios-simulator-version-min=16.0 -fobjc-arc \
    -c "$ROOT/tools/ios/sim_stubs.m" -o "$OUT/sim_stubs.o"
  echo "== xcodebuild (symulator)"
  "${XB[@]}" -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO \
    OTHER_LDFLAGS="\$(inherited) $OUT/sim_stubs.o" build
  APP="$DD/Build/Products/Debug-iphonesimulator/StartupSim.app"
  UDID=$(xcrun simctl list devices available | grep -F "    $SIM (" | head -1 | grep -oE '[0-9A-F-]{36}')
  [ -n "$UDID" ] || { echo "brak symulatora „$SIM” (xcrun simctl list devices)"; exit 1; }
  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  open "$(xcode-select -p)/Applications/Simulator.app" --args -CurrentDeviceUDID "$UDID" 2>/dev/null || true
  xcrun simctl terminate "$UDID" "$APP_ID" 2>/dev/null || true
  xcrun simctl install "$UDID" "$APP"
  xcrun simctl launch "$UDID" "$APP_ID" "${@:2}"
  echo "gotowe: $SIM ($UDID) — zrzut: xcrun simctl io $UDID screenshot plik.png"
  exit 0
fi

SIGN=(DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development"
  PROVISIONING_PROFILE_SPECIFIER="" PROVISIONING_PROFILE="")

if [ "$MODE" = device ]; then
  echo "== xcodebuild (telefon, zespół $TEAM)"
  "${XB[@]}" -configuration Release -destination 'generic/platform=iOS' -allowProvisioningUpdates \
    "${SIGN[@]}" build
  APP="$DD/Build/Products/Release-iphoneos/StartupSim.app"
  DEV=${DEVICE:-$(xcrun devicectl list devices 2>/dev/null | grep physical | grep -E "iPhone|iPad" \
    | grep -v unavailable | grep -oE '[0-9A-F]{8}-[0-9A-F]{16}' | head -1)}
  [ -n "$DEV" ] || { echo "nie widzę telefonu — podłącz go, odblokuj i zaufaj temu Macowi (albo DEVICE=<UDID>)"; exit 1; }
  echo "== instalacja na $DEV"
  xcrun devicectl device install app --device "$DEV" "$APP"
  xcrun devicectl device process launch --device "$DEV" "$APP_ID" || \
    echo "zainstalowane; przy pierwszym uruchomieniu: Ustawienia → Ogólne → VPN i urządzenia → zaufaj deweloperowi"
  exit 0
fi

echo "== archiwum (App Store Connect / TestFlight)"
"${XB[@]}" -configuration Release -destination 'generic/platform=iOS' -allowProvisioningUpdates \
  "${SIGN[@]}" -archivePath "$OUT/StartupSim.xcarchive" archive
cat >"$OUT/export.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>${ASC_DESTINATION:-export}</string>
</dict></plist>
EOF
xcodebuild -exportArchive -archivePath "$OUT/StartupSim.xcarchive" -exportOptionsPlist "$OUT/export.plist" \
  -exportPath "$OUT" -allowProvisioningUpdates
echo "gotowe: $OUT/StartupSim.ipa (ASC_DESTINATION=upload wysyła od razu do App Store Connect)"
