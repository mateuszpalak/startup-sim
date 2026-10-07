# Wydania

*Dla deweloperów · [dokumentacja](../README.md) · [uruchomienie](uruchomienie.md)*

## Budowanie klienta na macOS

```bash
tools/build-macos.sh              # → build/StartupSim-<wersja>.dmg
tools/build-macos.sh --app-only   # sama aplikacja, bez podpisu
```

Skrypt najpierw buduje przeglądarkę w grze (`tools/build_webview.sh`, godot_wry
ze źródeł) — Godot wkłada ją do `Contents/Frameworks`, a skrypt podpisuje ją
jako osobny framework przed aplikacją. Aplikacja uniwersalna (Intel + Apple Silicon), podpisana Developer ID z
hardened runtime i uprawnieniem do mikrofonu, a z profilem `notarytool` także
notaryzowana. Kto podpisuje: `IDENTITY` / `NOTARY_PROFILE` w środowisku albo w
`tools/macos/signing.env` (poza repozytorium). `--app-only` — do własnego
podpisania z `tools/macos/entitlements.plist`. Wymaga szablonów eksportu
Godota 4.7.2; wersja w `client/export_presets.cfg`.

## Budowanie klienta na Androida

```bash
tools/build-android.sh                # → build/StartupSim-<wersja>-debug.apk
tools/build-android.sh --install      # to samo + adb install i uruchomienie
tools/build-android.sh --release      # → build/StartupSim-<wersja>.aab (Google Play, Gradle)
tools/build-android.sh --release-apk  # → podpisany .apk do instalacji ręcznej
```

Wymaga szablonów eksportu Godota 4.7.2 dla Androida, JDK 17
(`brew install openjdk@17`) i Android SDK. Ścieżki w ustawieniach edytora
Godota: `export/android/java_sdk_path`
(`/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`) i
`export/android/android_sdk_path` (`~/Library/Android/sdk`). Debug podpisuje
klucz z `export/android/debug_keystore` — gdy go nie ma:

```bash
keytool -genkeypair -keystore ~/Library/Application\ Support/Godot/keystores/debug.keystore \
  -storepass android -alias androiddebugkey -keypass android -keyalg RSA -validity 10000 \
  -dname "CN=Android Debug,O=Android,C=US"
```

Wydanie podpisuje się tylko ze środowiska (klucze i hasła nigdy w repozytorium):
`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`,
`GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`. `.aab` budowany jest Gradle'em —
szablon trafia do `client/android/` (poza repozytorium).

Presety w `client/export_presets.cfg`: „Android” (arm64-v8a, renderer Mobile
na Vulkanie), „Android AAB” (Gradle, min SDK 24) i „Android (emulator)”
(arm64 + x86_64, uruchamiany z `--rendering-method gl_compatibility`, bo
emulator nie wyświetla obrazu z Vulkana — na ekranie jest czarno).
Kod tylko dla Androida: `client/platform/android.gd` (przycisk Wstecz działa
jak Esc, prośba o mikrofon przy pierwszym czacie głosowym, lżejsze cienie).

Na telefonie: włącz *Opcje programisty → Debugowanie USB*, podłącz kabel i
`tools/build-android.sh --install` (albo `adb install -r build/StartupSim-<wersja>-debug.apk`).
Serwer: gra oferuje serwery z `client/net/servers.cfg` (wkładany do
paczki). Żeby grać z telefonu na serwerze z komputera w tej samej sieci
(`cargo run` w `server/`), dopisz go tam przed budowaniem, np. sekcja
`[dom]` z `name="Serwer domowy"` i `address="192.168.1.20:7777"`.

Emulator (obraz systemu z SDK):

```bash
avdmanager create avd -n s3d -k "system-images;android-35;google_apis;arm64-v8a" -d pixel_6
emulator -avd s3d -gpu host &
godot --headless --path client --export-debug "Android (emulator)" ../build/emu.apk
adb install -r build/emu.apk
adb shell am start -n com.mateuszpalak.startupsim3d/com.godot.game.GodotAppLauncher
```

Z emulatora komputer to `10.0.2.2` — build debug na Androidzie ma na liście
„Serwer lokalny (emulator)” (`10.0.2.2:7777`).

## Aktualizacje u graczy

Gra przy starcie sprawdza najnowsze wydanie na GitHubie i, jeśli jest nowsze,
proponuje „Pobierz” na ekranie tytułowym. Serwer odrzucający starą wersję
(inny protokół) też kończy się tym przyciskiem. Szkiców i wydań
„pre-release” klienci nie proponują.

## Nowe wydanie

1. Podbij wersję w `client/project.godot` (`config/version`) i w
   `client/export_presets.cfg` (`application/short_version` i o 1 wyżej
   `application/version`) — po niej klienci poznają, że jest nowsza.
2. Zbuduj dmg: `tools/build-macos.sh`.
3. `git tag -a v<wersja> -m "Startup Sim <wersja>"` i `git push origin v<wersja>`.
4. `gh release create v<wersja> build/StartupSim-<wersja>.dmg --title "Startup Sim <wersja>" --notes "…"`
   (tag `v<wersja>` musi zgadzać się z `config/version`).
5. Przy zmianie protokołu wdróż też serwer (`deploy/deploy.sh`) — stare
   klienty dostaną „pobierz najnowszą”.

## Zwiastun

Nagranie i montaż: [tools/trailer](../../tools/trailer/README.md). GIF do
README robi się z gotowego mp4 (opis tamże).
