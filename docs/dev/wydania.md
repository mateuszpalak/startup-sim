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

## Budowanie klienta na Windows

```bash
tools/build-windows.sh          # → dist/StartupSim3D-<wersja>-windows-x86_64.zip
tools/build-windows.sh --arm64  # → …-windows-arm64.zip (Snapdragon itp.)
tools/build-windows.sh --all    # oba
```

Eksport działa bez Windowsa (macOS, Linux albo Git Bash na Windows): presety
„Windows” i „Windows arm64” w `client/export_presets.cfg`, jeden
`StartupSim.exe` z wbudowanymi danymi gry (PCK), ikona z `client/icons/icon.ico`,
nazwa, firma i wersja (z `config/version`) we właściwościach pliku. Renderer
Forward+ na D3D12 (domyślny w Godocie na Windows), a gdy karta/sterownik go
nie obsługuje — Vulkan. Ustawienia i logi gracza: `%APPDATA%\Godot\app_userdata\Startup Sim`
(stamtąd raporty awarii biorą log). Przeglądarki w grze (godot_wry) na
Windows na razie nie ma — biuro proponuje otwarcie strony w przeglądarce
gracza. Mikrofon: Windows nie pyta okienkiem, ale musi być włączony
„Dostęp do mikrofonu dla aplikacji klasycznych” (Ustawienia → Prywatność);
inaczej czat głosowy jest cichy.

Podpis (opcjonalny, sekretów nie ma w repozytorium): bez niego SmartScreen
ostrzega przy pierwszym uruchomieniu („Więcej informacji” → „Uruchom mimo
to”). Z certyfikatem podpisz exe przed spakowaniem — na Windows
`signtool sign /fd sha256 /tr http://timestamp.digicert.com /td sha256 /a StartupSim.exe`,
na macOS/Linux `osslsigncode`.

CI (`.github/workflows/windows.yml`) na `windows-latest` pobiera Godota 4.7.2
z szablonami, uruchamia tam testy klienta, eksportuje oba zipy i zostawia je
jako artefakt „startupsim-windows”. Po wypchnięciu tagu `v<wersja>` dokłada
je do wydania (gdy wydania jeszcze nie ma — tworzy szkic do uzupełnienia).

## Aktualizacje u graczy

Gra przy starcie sprawdza najnowsze wydanie na GitHubie i, jeśli jest nowsze,
proponuje „Pobierz” na ekranie tytułowym. Na Windows przycisk prowadzi
wprost do zipa dla danej architektury (`…-windows-x86_64.zip` /
`…-windows-arm64.zip` w zasobach wydania), a gdy go brak — na stronę wydania. Serwer odrzucający starą wersję
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
5. Zipy dla Windows dołącza CI po tagu (albo ręcznie:
   `tools/build-windows.sh --all` i `gh release upload v<wersja> dist/*.zip`).
6. Przy zmianie protokołu wdróż też serwer (`deploy/deploy.sh`) — stare
   klienty dostaną „pobierz najnowszą”.

## Zwiastun

Nagranie i montaż: [tools/trailer](../../tools/trailer/README.md). GIF do
README robi się z gotowego mp4 (opis tamże).
