# Wydania

*Dla deweloperów · [dokumentacja](../README.md) · [uruchomienie](uruchomienie.md)*

Dwa klienty, jeden serwer: **2D** w `client/` i **3D** w `client3d/`, oba na
macOS, iOS, Android i Windows. Skrypty iOS / Android / Windows domyślnie
budują klienta 3D, z `CLIENT=client` — 2D (`tools/client.sh`: pliki
`StartupSim-<wersja>-…` zamiast `StartupSim3D-<wersja>-…`, identyfikator
`pl.mateuszpalak.startupsim` zamiast `pl.mateuszpalak.startupsim3d`, katalogi
`build/ios2d*`); `tools/build-macos.sh` domyślnie 2D, z `--3d` — 3D.

Klient 2D na telefonach: renderer Compatibility
(`rendering_method.mobile="gl_compatibility"`), bo gra jest płaska: działa na każdym telefonie, w emulatorze Androida i w
symulatorze iOS bez osobnych ustawień (na komputerze zostaje Forward+).
Kod platform: `client/platform/platform.gd` i `android.gd` (jak w 3D, bez
profilu jakości 3D).

## Katalogi danych gracza

Klienty mają osobne katalogi `user://` (ustawienia, przypięte certyfikaty
serwerów, zapamiętane logowanie, `session.cfg` wykrywania awarii, `logs/`
wysyłane w raporcie awarii). 3D ma `application/config/use_custom_user_dir`
z nazwą „Startup Sim 3D”; 2D zostaje przy domyślnym katalogu Godota (nazwa
okna/aplikacji to nadal „Startup Sim”).

| system | 3D | 2D |
|---|---|---|
| macOS | `~/Library/Application Support/Startup Sim 3D` | `~/Library/Application Support/Godot/app_userdata/Startup Sim` |
| Windows | `%APPDATA%\Startup Sim 3D` | `%APPDATA%\Godot\app_userdata\Startup Sim` |
| Linux | `~/.local/share/Startup Sim 3D` | `~/.local/share/godot/app_userdata/Startup Sim` |
| iOS / Android | piaskownica aplikacji (osobny identyfikator `…startupsim3d`) | piaskownica aplikacji |

Do wersji 0.4.0 oba klienty dzieliły katalog 2D. Przy pierwszym starcie na
komputerze 3D jednorazowo kopiuje stamtąd (`client3d/net/user_migration.gd`):
przypięte certyfikaty (`known_servers.cfg`), ostatni serwer i nick (bez
tokenu logowania — odświeżenie w jednym kliencie wylogowałoby drugi, więc
trzeba się zalogować raz jeszcze), głośności, mikrofon i zgodę na raporty
awarii. Nie kopiuje sesji, logów, ustawień grafiki/okna ani szkicu postaci;
starego katalogu nie zmienia. Znacznik `migrated_from_2d.cfg` w katalogu 3D
pilnuje, żeby działo się to raz. Scenariusze e2e (`--scenario`) i
`STARTUP_SIM_NO_MIGRATE=1` ją pomijają.

## Budowanie klienta na macOS

```bash
tools/build-macos.sh              # → build/StartupSim-<wersja>.dmg
tools/build-macos.sh --app-only   # sama aplikacja, bez podpisu
tools/build-macos.sh --3d         # → build/StartupSim3D-<wersja>-macos.dmg (klient 3D), też z --app-only
```

Skrypt najpierw buduje przeglądarkę w grze (`tools/build_webview.sh`, godot_wry
ze źródeł) — Godot wkłada ją do `Contents/Frameworks`, a skrypt podpisuje ją
jako osobny framework przed aplikacją. Aplikacja uniwersalna (Intel + Apple Silicon), podpisana Developer ID z
hardened runtime i uprawnieniem do mikrofonu, a z profilem `notarytool` także
notaryzowana. Kto podpisuje: `IDENTITY` / `NOTARY_PROFILE` w środowisku albo w
`tools/macos/signing.env` (poza repozytorium). `--app-only` — do własnego
podpisania z `tools/macos/entitlements.plist`. Wymaga szablonów eksportu
Godota 4.7.2; wersja w `client/export_presets.cfg` (z `--3d`:
`client3d/export_presets.cfg`).

## Budowanie klienta na iOS

```bash
tools/build-ios.sh sim       # symulator: eksport, build, instalacja, start (SIM="iPhone 18 Pro")
tools/build-ios.sh device    # podłączony iPhone (wymaga DEVELOPMENT_TEAM)
tools/build-ios.sh archive   # build/ios/StartupSim.ipa do TestFlight / App Store
tools/build-ios.sh project   # sam projekt Xcode w build/ios (do otwarcia w Xcode)
CLIENT=client tools/build-ios.sh sim   # klient 2D (build/ios2d*, pl.mateuszpalak.startupsim)
```

Godot eksportuje projekt Xcode (preset „iOS”, `client3d/export_presets.cfg`:
identyfikator `pl.mateuszpalak.startupsim3d`, iOS 16+, iPhone i iPad, tylko
poziomo, ikona `client3d/icons/icon_ios.png` — kwadrat bez przezroczystości,
obraz do krawędzi; ikony telefonów, także adaptacyjne Androida, robi z
`icon.svg` skrypt `python3 tools/make_icons.py`), a `xcodebuild` go buduje i podpisuje. W repozytorium nie ma
zespołu: w presecie jest zaślepka `XXXXXXXXXX`, prawdziwy **Team ID** idzie
do `xcodebuild` z `DEVELOPMENT_TEAM` (środowisko albo
`tools/ios/signing.env`, poza repozytorium, np. `DEVELOPMENT_TEAM=AB12CD34EF`).
Team ID: Xcode → Settings → Accounts → zespół, albo developer.apple.com →
Membership. Podpis automatyczny (`-allowProvisioningUpdates`): Xcode sam
zakłada profil i certyfikat „Apple Development”.

**Renderer.** Na telefonie gra używa renderera Mobile (Metal;
`rendering_method.mobile`) i profilu jakości „mobile” (`client3d/platform/platform.gd`:
skala 3D 0,67 z FSR, jedna kaskada cienia słońca 2048 px, bez SSAO, mniej
kropli deszczu i dymu; piętra pocięte na komórki 8 m, bo Mobile oświetla
siatkę najwyżej 8 lampami). Podgląd na Macu:
`godot --path client3d --rendering-method mobile -- --quality=mobile`.

**Symulator** pokazuje UI i przebieg gry, nie wygląd ani wydajność: GPU
symulatora nie obsługuje rendererów Metal Godota (brak tablic cube map), więc
preset „iOS Simulator” używa renderera Compatibility (OpenGL), a oficjalne
szablony Godota nie mają biblioteki arm64 dla symulatora — skrypt linkuje
bibliotekę urządzenia przestemplowaną na symulator
(`tools/ios/retag_simulator.py`, dwa brakujące symbole Metal w
`tools/ios/sim_stubs.m`). Symulator widzi serwer lokalny pod `127.0.0.1`.
Emulowany OpenGL jest bardzo wolny (start ok. 2 min, budowa pięter blokuje
grę na tyle długo, że klient łapie „Łączenie ponownie”). Argumenty
deweloperskie po `--`, np.
`tools/build-ios.sh sim -- --nick=Ala --server=127.0.0.1:7777 --autoconnect`.
Zrzuty w symulatorze są tylko do sprawdzania UI (renderer OpenGL); zrzuty dotyku: [HUD](../media/3d/dotyk.jpg), [komputer](../media/3d/dotyk_komputer.jpg).

### Na własny telefon

1. Xcode → Settings → Accounts → „+” → Apple ID (wystarczy darmowe konto).
2. Telefon: kabel, odblokuj, „Zaufaj temu komputerowi”; Ustawienia →
   Prywatność i ochrona → **Tryb dewelopera** → włącz (restart).
3. `DEVELOPMENT_TEAM=<Team ID> tools/build-ios.sh device`
4. Przy pierwszym uruchomieniu: Ustawienia → Ogólne → VPN i zarządzanie
   urządzeniami → zaufaj certyfikatowi deweloperskiemu.

Darmowe konto („Personal Team”): aplikacja działa 7 dni, potem trzeba ją
zainstalować ponownie (to samo polecenie); najwyżej 3 aplikacje naraz. Płatne
konto (Apple Developer Program, 99 USD/rok): rok, do 100 urządzeń, TestFlight.

### TestFlight

1. Płatne konto; w App Store Connect → Aplikacje → „+” → nowa aplikacja z
   identyfikatorem `pl.mateuszpalak.startupsim3d`.
2. Podbij `application/version` w presecie „iOS” (każdy wysłany build musi
   mieć wyższy numer).
3. `DEVELOPMENT_TEAM=<Team ID> ASC_DESTINATION=upload tools/build-ios.sh archive`
   (albo bez `ASC_DESTINATION` → `build/ios/StartupSim.ipa` i wysyłka przez
   aplikację Transporter).
4. App Store Connect → TestFlight: po przetworzeniu buildu dodaj testerów
   (wewnętrznych od razu, zewnętrznych po przeglądzie Apple). Szyfrowanie:
   preset deklaruje `ITSAppUsesNonExemptEncryption = false` (tylko TLS
   systemowy / standardowy).

Na iOS gra nie proponuje „Pobierz” (nie ma tam .dmg) — panel nowej wersji
mówi „Zaktualizuj grę w TestFlight”.

## Budowanie klienta na Androida

```bash
tools/build-android.sh                # → build/StartupSim3D-<wersja>-android-debug.apk
tools/build-android.sh --install      # to samo + adb install i uruchomienie
tools/build-android.sh --release      # → build/StartupSim3D-<wersja>-android.aab (Google Play, Gradle)
tools/build-android.sh --release-apk  # → build/StartupSim3D-<wersja>-android.apk (podpisany, do instalacji ręcznej)
CLIENT=client tools/build-android.sh  # klient 2D → build/StartupSim-<wersja>-android-debug.apk (i tak dalej)
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
szablon trafia do `client3d/android/` (poza repozytorium).

Presety w `client3d/export_presets.cfg`: „Android” (arm64-v8a, renderer Mobile
na Vulkanie), „Android AAB” (Gradle, min SDK 24) i „Android (emulator)”
(arm64 + x86_64, uruchamiany z `--rendering-method gl_compatibility`, bo
emulator nie wyświetla obrazu z Vulkana — na ekranie jest czarno).
Kod tylko dla Androida: `client3d/platform/android.gd` (przycisk Wstecz działa
jak Esc, prośba o mikrofon przy pierwszym czacie głosowym); jakość grafiki
to wspólny profil „mobile” z `client3d/platform/platform.gd` (jak na iOS).
Gra jest zawsze na pełnym ekranie (tryb immersyjny, bez pasków systemu).

Na telefonie: włącz *Opcje programisty → Debugowanie USB*, podłącz kabel i
`tools/build-android.sh --install` (albo `adb install -r build/StartupSim3D-<wersja>-android-debug.apk`).
Serwer: gra oferuje serwery z `client3d/net/servers.cfg` (wkładany do
paczki) oraz „Inny serwer…” — pole adres:port (np. serwer domowy), wyraźnie
oznaczone jako spoza listy gry; jego certyfikat jest przypinany przy
pierwszym połączeniu jak każdego innego. Żeby grać z telefonu na serwerze z komputera w tej samej sieci
(`cargo run` w `server/`), dopisz go tam przed budowaniem, np. sekcja
`[dom]` z `name="Serwer domowy"` i `address="192.168.1.20:7777"`.

Emulator (obraz systemu z SDK):

```bash
avdmanager create avd -n s3d -k "system-images;android-35;google_apis;arm64-v8a" -d pixel_6
emulator -avd s3d -gpu host &
godot --headless --path client3d --export-debug "Android (emulator)" ../build/emu.apk
adb install -r build/emu.apk
adb shell am start -n pl.mateuszpalak.startupsim3d/com.godot.game.GodotAppLauncher
```

Z emulatora komputer to `10.0.2.2` — build debug na Androidzie ma na liście
„Serwer lokalny (emulator)” (`10.0.2.2:7777`).

## Budowanie klienta na Windows

```bash
tools/build-windows.sh          # → dist/StartupSim3D-<wersja>-windows-x86_64.zip
tools/build-windows.sh --arm64  # → …-windows-arm64.zip (Snapdragon itp.)
tools/build-windows.sh --all    # oba
CLIENT=client tools/build-windows.sh --all  # klient 2D → dist/StartupSim-<wersja>-windows-<arch>.zip
```

Eksport działa bez Windowsa (macOS, Linux albo Git Bash na Windows): presety
„Windows” i „Windows arm64” w `client3d/export_presets.cfg`, jeden
`StartupSim.exe` z wbudowanymi danymi gry (PCK), ikona z `client3d/icons/icon.ico`,
nazwa, firma i wersja (z `config/version`) we właściwościach pliku. Renderer
Forward+ na D3D12 (domyślny w Godocie na Windows), a gdy karta/sterownik go
nie obsługuje — Vulkan. Ustawienia i logi gracza: 3D — `%APPDATA%\Startup Sim 3D`,
2D — `%APPDATA%\Godot\app_userdata\Startup Sim` (stamtąd raporty awarii biorą log;
zob. [katalogi danych gracza](#katalogi-danych-gracza)). Przeglądarki w grze (godot_wry) na
Windows na razie nie ma — biuro proponuje otwarcie strony w przeglądarce
gracza. Mikrofon: Windows nie pyta okienkiem, ale musi być włączony
„Dostęp do mikrofonu dla aplikacji klasycznych” (Ustawienia → Prywatność);
inaczej czat głosowy jest cichy.

Podpis (opcjonalny, sekretów nie ma w repozytorium): bez niego SmartScreen
ostrzega przy pierwszym uruchomieniu („Więcej informacji” → „Uruchom mimo
to”). Z certyfikatem podpisz exe przed spakowaniem — na Windows
`signtool sign /fd sha256 /tr http://timestamp.digicert.com /td sha256 /a StartupSim.exe`,
na macOS/Linux `osslsigncode`.

CI (`.github/workflows/windows.yml`, macierz: `client` i `client3d`) na
`windows-latest` pobiera Godota 4.7.2 z szablonami, uruchamia tam testy
klienta, eksportuje zipy (x86_64 i arm64) i zostawia je jako artefakty
„startupsim-windows-client” / „startupsim-windows-client3d”. Po wypchnięciu tagu `v<wersja>` dokłada
je do wydania (gdy wydania jeszcze nie ma — tworzy szkic do uzupełnienia).

## Aktualizacje u graczy

Gra przy starcie sprawdza najnowsze wydanie na GitHubie i, jeśli jest nowsze,
proponuje „Pobierz” na ekranie tytułowym. Na Windows przycisk prowadzi
wprost do zipa dla danej architektury (`…-windows-x86_64.zip` /
`…-windows-arm64.zip` w zasobach wydania), na Androidzie do `…-android.apk`, na
macOS do dmg, a gdy go brak — na stronę wydania. Każdy klient bierze tylko
swoje pliki (`ASSET_PREFIX` w `net/updates.gd`: 2D `StartupSim-`, 3D
`StartupSim3D-`), nigdy pliku drugiego klienta. Serwer odrzucający starą wersję
(inny protokół) też kończy się tym przyciskiem. Szkiców i wydań
„pre-release” klienci nie proponują.

## Nowe wydanie

1. Podbij wersję w `client/project.godot` i `client3d/project.godot`
   (`config/version`) oraz w `export_presets.cfg` obu klientów (`application/short_version` i o 1 wyżej
   `application/version`) — po niej klienci poznają, że jest nowsza.
2. Zbuduj dmg: `tools/build-macos.sh` (2D) albo `tools/build-macos.sh --3d` (3D).
3. `git tag -a v<wersja> -m "Startup Sim <wersja>"` i `git push origin v<wersja>`.
4. `gh release create v<wersja> build/StartupSim-<wersja>.dmg build/StartupSim3D-<wersja>-macos.dmg build/StartupSim3D-<wersja>-android.apk build/StartupSim-<wersja>-android.apk --title "Startup Sim <wersja>" --notes "…"`
   (tag `v<wersja>` musi zgadzać się z `config/version`).
5. Zipy dla Windows dołącza CI po tagu (albo ręcznie:
   `tools/build-windows.sh --all` i `gh release upload v<wersja> dist/*.zip`).
6. Przy zmianie protokołu wdróż też serwer (`deploy/deploy.sh`) — stare
   klienty dostaną „pobierz najnowszą”.

## Zwiastun

Nagranie i montaż: [tools/trailer](../../tools/trailer/README.md). GIF do
README robi się z gotowego mp4 (opis tamże).
