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

## Budowanie klienta na iOS

```bash
tools/build-ios.sh sim       # symulator: eksport, build, instalacja, start (SIM="iPhone 18 Pro")
tools/build-ios.sh device    # podłączony iPhone (wymaga DEVELOPMENT_TEAM)
tools/build-ios.sh archive   # build/ios/StartupSim.ipa do TestFlight / App Store
tools/build-ios.sh project   # sam projekt Xcode w build/ios (do otwarcia w Xcode)
```

Godot eksportuje projekt Xcode (preset „iOS”, `client/export_presets.cfg`:
identyfikator `com.mateuszpalak.startupsim3d`, iOS 16+, iPhone i iPad, tylko
poziomo, ikona `client/icons/icon_ios.png` — kwadrat bez przezroczystości,
z `icon.svg`), a `xcodebuild` go buduje i podpisuje. W repozytorium nie ma
zespołu: w presecie jest zaślepka `XXXXXXXXXX`, prawdziwy **Team ID** idzie
do `xcodebuild` z `DEVELOPMENT_TEAM` (środowisko albo
`tools/ios/signing.env`, poza repozytorium, np. `DEVELOPMENT_TEAM=AB12CD34EF`).
Team ID: Xcode → Settings → Accounts → zespół, albo developer.apple.com →
Membership. Podpis automatyczny (`-allowProvisioningUpdates`): Xcode sam
zakłada profil i certyfikat „Apple Development”.

**Renderer.** Na telefonie gra używa renderera Mobile (Metal;
`rendering_method.mobile`) i profilu jakości „mobile” (`client/platform/platform.gd`:
skala 3D 0,67 z FSR, jedna kaskada cienia słońca 2048 px, bez SSAO, mniej
kropli deszczu i dymu; piętra pocięte na komórki 8 m, bo Mobile oświetla
siatkę najwyżej 8 lampami). Podgląd na Macu:
`godot --path client --rendering-method mobile -- --quality=mobile`.

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
Zrzuty: [ekran tytułowy](../media/ios/tytul.png), [w grze](../media/ios/gra.png).

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
   identyfikatorem `com.mateuszpalak.startupsim3d`.
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
