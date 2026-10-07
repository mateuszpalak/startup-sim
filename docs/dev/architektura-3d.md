# Architektura — warstwa 3D klienta

*Architektura: [przegląd](architektura.md) · [klient](architektura-klient.md) · [protokół](protokol.md)*

Klient 3D to osobny projekt Godota w `client3d/`, obok klienta 2D (`client/`);
oba łączą się z tym samym serwerem (`server/`). Uruchomienie:
`godot --path client3d`.

Serwer i protokół są bez zmian. Klient 3D zmienia tylko prezentację: cała
logika (`game.gd`: sieć, predykcja, rekoncyliacja, interpolacja, podpowiedzi,
UI) zostaje. Widoki 2D (`game/*_view.gd`) dalej istnieją jako **niewidoczne
nośniki stanu** (pozycja w px, kierunek, status, wygląd, nick, dymek) pod
`game.hidden_2d`. Warstwa 3D (`client3d/world3d/`) co klatkę czyta ten stan i
go rysuje.

## Moduły

| plik | rola |
|---|---|
| `world3d/coords.gd` | przeliczanie 2D ↔ 3D (jedyne miejsce ze stałymi skali) |
| `world3d/world_view.gd` | korzeń 3D (dziecko `game`, dodane na końcu): środowisko, słońce, piętra, awatary, zastępniki encji, lampy, plakietki z nickami |
| `world3d/map_builder.gd` | piętro z `MapData` → geometria: podłogi, cienkie ściany z oknami, drzwi, schody, płoty/barierki, meble, otoczenie parteru, lampy, napisy schodów |
| `world3d/props.gd` | **rejestr mebli**: typ z legendy mapy → funkcja budująca |
| `world3d/mesh_batch.gd` | zbieranie prymitywów w jeden `ArrayMesh` (powierzchnia na materiał) |
| `world3d/materials.gd`, `world3d/shaders/` | wspólne materiały (kolor z wierzchołków, sRGB); podłogi z proceduralnym wzorem (`UV2.x`), ściany z wycięciem |
| `world3d/avatar_3d.gd` | postać 3D śledząca `PlayerView` (chód, siedzenie, leżenie, zatoczenia) |
| `world3d/item_3d.gd`, `item_models.gd` | przedmioty na podłodze: model 3D każdego rodzaju (cache siatek per rodzaj, też na tacy) |
| `world3d/vehicle_3d.gd` | auto, taksówka, policja (koguty), straż (drabina), tramwaj (przegub, pantograf), rower; koła toczą się, płynny obrót, światła nocą |
| `world3d/computer_3d.gd` | laptop na biurku: ekran świeci wg stanu (logowanie / w użyciu / zablokowany) |
| `world3d/tv_3d.gd` | obraz TV: kopia `TvView` rysuje do `SubViewport`, ekran = `ViewportTexture` na meblu „tv” |
| `world3d/tray_3d.gd` | taca ze słodyczami (sztuki z `item_models`) |
| `world3d/elevator_door_3d.gd`, `stall_door_3d.gd` | drzwi windy (rozsuwane skrzydła, wyświetlacz piętra), drzwi kabin (obrót na zawiasie do środka kabiny, czerwone/zielone okienko) |
| `world3d/ride_cabin_3d.gd` | jazda windą: piętro ukryte, widać tylko kabinę (tło czarne) |
| `world3d/camera_rig.gd` | kamera: pochylenie 55°, płynne śledzenie, zoom, obrót |
| `touch/touch.gd` | tryb dotykowy: wykrycie (iOS / Android / ekran dotykowy, `--touch[=phone\|tablet]`), skala UI na telefonie (krótszy bok = 520 jednostek, tablet 720), bezpieczny obszar (`safe_rect`, `--safe-area=l,t,r,b`), `place_center` (okno w bezpiecznym obszarze, zmniejszone do ekranu), `press` / `tap` (sztuczne klawisze) |
| `touch/touch_controls.gd` | przyciski na ekranie w grze: joystick, E, F/Q/G, Tab, V/B, menu / czat / dziennik, ✕ (Esc) przy oknach; stuknięcie w świat (idź / podejdź i E — `game.touch_tap_world`), szczypanie i obrót dwoma palcami (`camera_rig.turn_by`) |
| `touch/keyboard_lift.gd` | pole tekstowe nad klawiaturą ekranową (przesuwa CanvasLayer pola; `--fake-keyboard=0.4` udaje klawiaturę) |
| `pad/pad_map.gd` | pad: jedna tabela akcji (klawisz gry ↔ przyciski / osie pada, rejestrowana w InputMap jako `pad_*`), gałka → 8 kierunków, rodzina glifów po nazwie pada (xbox / ps / nintendo), podpowiedzi `[E] …` → przycisk |
| `pad/pad.gd` | węzeł w `main`: zdarzenia pada wg kontekstu — w świecie naciska klawisze akcji (jak `Touch.press`; bity ruchu = klawiatura), kamera z prawej gałki; w oknie kursor fokusu; podłączanie / odłączanie, wibracje (`Pad.rumble`), `Pad.active` (ostatnie wejście z pada) |
| `pad/pad_cursor.gd` | ramka fokusu w dowolnym oknie: znajduje przyciski, pola, suwaki, listy wyboru i klikane kontrolki; krzyżak — najbliższa w danym kierunku, A — `pressed` / klik / klawiatura; meta `pad_default`, `pad_press`, `pad_skip` |
| `pad/pad_keyboard.gd`, `pad/pad_glyphs.gd` | klawiatura ekranowa dla pada (zwroty przy czacie); glify przycisków rysowane jak `Kit.draw_keycap` (który przy padzie sam rysuje glify przez `Kit.key_glyph`) |
| `tests/render_objects.gd` | podgląd widoków encji: `godot --path client3d -s tests/render_objects.gd -- /katalog [items vehicles tram night laptops tv tray elevator stalls ride]` |
| `tests/render_3d.gd` | podgląd bez serwera: `godot --path client3d -s tests/render_3d.gd -- /katalog [nazwa:piętro:x,y:zoom:obrót:minuta]` |

## Współrzędne

1 kafel (16 px) = 1 m. Punkt mapy `(x, y)` px na piętrze `f` →
`Vector3(x/16, floor_y(f), y/16)`; mapa „w górę” (−y) = −z, czyli od kamery.
`floor_y(f) = level(f) · 3,2 m`, `level` = numer piętra, a półpiętra klatki
(5, 6) mają 1,5 i 3,5. Ściany 2,7 m, bez sufitów (diorama). Kafel `(x, y)`
zajmuje `x..x+1`, `z = y..y+1`. Schody są tylko wizualne (serwer ma płaskie
piętra): wysokość stopni pod postacią z meta `heights` piętra.

## Zasady

- Nie zmieniaj symulacji ani pakietów. Kolizje = `solid` w mapie; wygląd mebla nie może ich zmieniać.
- Klawisze ruchu są kierunkami ekranu; `camera_rig.screen_to_map` obraca je o ćwiartki obrotu kamery, input na drutach zostaje w osiach mapy.
- Nowy widok 3D encji: osobny plik w `world3d/`, tworzony w `world_view` dla odpowiadającego widoku 2D (wpis w `ENTITY_VIEWS`: `setup(widok_2d, world_view)`, `sync(pozycja, delta)`; zastępuje pudełko z `ENTITY_PROXIES`); stan czytaj z widoku 2D, nie z sieci.
- Geometria statyczna przez `MeshBatch` (jedno wywołanie rysowania na materiał), kolory jako sRGB w wierzchołkach.
- Ściany używają `wall.gdshader` (parametry `focus`, `cam_pos` ustawia `world_view`); inne wysokie rzeczy, które mają znikać, też muszą z niego korzystać.
- Pad: tak samo — w świecie przycisk pada to klawisz jego akcji (`pad/pad_map.gd`, jedno miejsce do zmiany układu, np. przy porcie na konsolę), więc predykcja i serwer widzą te same bity. Okna nie muszą nic wiedzieć o padzie: `pad_cursor.gd` sam znajduje, co da się nacisnąć; nowe okno w grze trzeba tylko dopisać do `game.pad_modal()` (okna z `main` na warstwach ≥ 20 są znajdowane same). Podpowiedzi z kluczem `[K] …` i `Kit.draw_keycap` same pokazują glify. Test: scenariusz `gamepad`; zrzuty: `pad_tour` (`--shots=/katalog`, poza `run.py`) → `docs/media/3d/pad/`.
- Dotyk: przyciski naciskają te same klawisze co klawiatura (`Touch.press`), więc gra ma jedną ścieżkę wejścia; nowy klawisz = przycisk w `touch_controls.gd` albo pozycja w menu akcji (`_actions_here`). Nowe okno na środku ekranu: po ustawieniu pozycji `Touch.place_center(panel, get_viewport())`, teksty z klawiszami przez `Touch.say(klawiatura, palec)`. Zrzuty: scenariusze `touch_tour` / `touch_computer` (`--touch=phone --shots=/katalog`) → `docs/media/ios/touch/`.
- UI to `CanvasLayer`y nad 3D. Wygląd: `ui/ui_kit.gd` (tokeny kolorów, promieni, rozmiarów, czcionka Nunito, panele, ikony wektorowe `draw_icon`, animacje `pop_in`/`fade_in`), ikony przedmiotów renderowane z modeli 3D (`ui/item_icons.gd`), tło menu to żywy świat 3D (`ui/title_backdrop_3d.gd`, tworzony przez `main.gd`, nie w trybie headless), podgląd postaci 3D (`ui/avatar_preview.gd`). Zrzuty UI: scenariusz `ui_tour` (`--scenario=ui_tour --shots=/katalog`, poza `run.py`) → `docs/media/3d/ui/`. Nicki i dymki to te same węzły 2D (`PlayerView._tag`), stawiane na ekranie nad głową (`_place_tags`).
- Dane gracza: zawsze przez `UserPaths.at(plik)` (e2e dostaje własny podkatalog). Klient 3D ma własny katalog `user://` („Startup Sim 3D”, osobny od 2D: ustawienia, piny, `session.cfg`, `logs/`); jednorazowa migracja z katalogu 2D w `net/user_migration.gd` — ścieżki per system w [wydania.md](wydania.md#katalogi-danych-gracza). Nowy plik wspólny dla obu klientów (np. preferencja) dopisz do migracji, jeśli ma przejść z 2D.

## Do przeniesienia (właściciele)

| element | plik 2D (stan) | docelowo |
|---|---|---|
| dym i czujki | `game/smoke_view.gd` | `world3d/smoke_3d.gd` (GPUParticles3D / mgła wolumetryczna) |
| kałuże, wymiociny, smugi | `game/puddle_view.gd` | `world3d/puddle_3d.gd` (Decal) |
| krew | `game/blood_splash.gd` | `world3d/blood_3d.gd` |
| jasność pokoi (ciemne bez okien, wyłącznik) | `game/light_view.gd` (logika zostaje) | lampy w `world_view` + przyciemnianie |
| pogoda w świecie (deszcz, mgła) | `ui/weather_fx.gd` (ekranowa, działa) | `world3d/weather_3d.gd` |
| szczegóły postaci (trzymany przedmiot, parasol, chmurka smrodu, „zzz”) | `game/player_view.gd` | `world3d/avatar_3d.gd` |
| tabliczki na drzwiach, znaki EXIT, wiaty | `map/map_painter.gd` | `world3d/map_builder.gd` / `props.gd` |
