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
| `world3d/camera_rig.gd` | kamera: pochylenie 55°, płynne śledzenie, zoom, obrót |
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
- Nowy widok 3D encji: osobny plik w `world3d/`, tworzony w `world_view` dla odpowiadającego widoku 2D (zastąp wpis w `ENTITY_PROXIES`); stan czytaj z widoku 2D, nie z sieci.
- Geometria statyczna przez `MeshBatch` (jedno wywołanie rysowania na materiał), kolory jako sRGB w wierzchołkach.
- Ściany używają `wall.gdshader` (parametry `focus`, `cam_pos` ustawia `world_view`); inne wysokie rzeczy, które mają znikać, też muszą z niego korzystać.
- UI to `CanvasLayer`y nad 3D — bez zmian. Nicki i dymki to te same węzły 2D (`PlayerView._tag`), stawiane na ekranie nad głową (`_place_tags`).

## Do przeniesienia (właściciele)

| element | plik 2D (stan) | docelowo |
|---|---|---|
| przedmioty na podłodze | `game/item_view.gd`, `item_art.gd` | `world3d/item_3d.gd` |
| pojazdy (auto, rower, taksówka, tramwaj, policja, straż) | `game/vehicle_view.gd` | `world3d/vehicle_3d.gd` |
| laptopy na biurkach | `game/computer_view.gd` | `world3d/computer_3d.gd` |
| telewizory (obraz kanałów) | `game/tv_view.gd` | `world3d/tv_3d.gd` (ekran jako ViewportTexture) |
| dym i czujki | `game/smoke_view.gd` | `world3d/smoke_3d.gd` (GPUParticles3D / mgła wolumetryczna) |
| kałuże, wymiociny, smugi | `game/puddle_view.gd` | `world3d/puddle_3d.gd` (Decal) |
| krew | `game/blood_splash.gd` | `world3d/blood_3d.gd` |
| tace ze słodyczami | `game/tray_view.gd` | `world3d/tray_3d.gd` |
| drzwi windy (rozsuwanie, wyświetlacz) | `game/elevator_door_view.gd` | `world3d/elevator_door_3d.gd` |
| drzwi kabin w toaletach | `game/stall_door_view.gd` | `world3d/stall_door_3d.gd` |
| jazda windą (widać tylko kabinę) | `game/ride_mask.gd` | `world_view` (ukryć piętro poza kabiną) |
| jasność pokoi (ciemne bez okien, wyłącznik) | `game/light_view.gd` (logika zostaje) | lampy w `world_view` + przyciemnianie |
| pogoda w świecie (deszcz, mgła) | `ui/weather_fx.gd` (ekranowa, działa) | `world3d/weather_3d.gd` |
| szczegóły postaci (trzymany przedmiot, parasol, chmurka smrodu, „zzz”) | `game/player_view.gd` | `world3d/avatar_3d.gd` |
| tabliczki na drzwiach, znaki EXIT, wiaty | `map/map_painter.gd` | `world3d/map_builder.gd` / `props.gd` |
