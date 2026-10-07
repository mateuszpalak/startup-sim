# Architektura — warstwa 3D klienta

*Architektura: [przegląd](architektura.md) · [klient](architektura-klient.md) · [protokół](protokol.md)*

Serwer i protokół są bez zmian. Klient 3D zmienia tylko prezentację: cała
logika (`game.gd`: sieć, predykcja, rekoncyliacja, interpolacja, podpowiedzi,
UI) zostaje. Widoki 2D (`game/*_view.gd`) dalej istnieją jako **niewidoczne
nośniki stanu** (pozycja w px, kierunek, status, wygląd, nick, dymek) pod
`game.hidden_2d`. Warstwa 3D (`client/world3d/`) co klatkę czyta ten stan i
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
| `tests/render_objects.gd` | podgląd widoków encji: `godot --path client -s tests/render_objects.gd -- /katalog [items vehicles tram night laptops tv tray elevator stalls ride]` |
| `tests/render_3d.gd` | podgląd bez serwera: `godot --path client -s tests/render_3d.gd -- /katalog [nazwa:piętro:x,y:zoom:obrót:minuta]` |

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
- Dotyk: przyciski naciskają te same klawisze co klawiatura (`Touch.press`), więc gra ma jedną ścieżkę wejścia; nowy klawisz = przycisk w `touch_controls.gd` albo pozycja w menu akcji (`_actions_here`). Nowe okno na środku ekranu: po ustawieniu pozycji `Touch.place_center(panel, get_viewport())`, teksty z klawiszami przez `Touch.say(klawiatura, palec)`. Zrzuty: scenariusze `touch_tour` / `touch_computer` (`--touch=phone --shots=/katalog`) → `docs/media/ios/touch/`.
- UI to `CanvasLayer`y nad 3D. Wygląd: `ui/ui_kit.gd` (tokeny kolorów, promieni, rozmiarów, czcionka Nunito, panele, ikony wektorowe `draw_icon`, animacje `pop_in`/`fade_in`), ikony przedmiotów renderowane z modeli 3D (`ui/item_icons.gd`), tło menu to żywy świat 3D (`ui/title_backdrop_3d.gd`, tworzony przez `main.gd`, nie w trybie headless), podgląd postaci 3D (`ui/avatar_preview.gd`). Zrzuty UI: scenariusz `ui_tour` (`--scenario=ui_tour --shots=/katalog`, poza `run.py`) → `docs/media/3d/ui/`. Nicki i dymki to te same węzły 2D (`PlayerView._tag`), stawiane na ekranie nad głową (`_place_tags`).

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
