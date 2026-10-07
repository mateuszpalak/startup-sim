## 2D map space (pixels / tiles of one floor) <-> 3D world (metres).
## One tile (16 px) = 1 m. Map x -> world x, map y -> world z, so "up" on the
## map (smaller y) is -z, away from the default camera. Floors stack on y.
extends RefCounted

const TILE_PX := 16.0
## Metres per world pixel.
const PX := 1.0 / TILE_PX
## Height of one storey (floor slab to floor slab).
const STOREY := 3.2
## Interior wall height (no ceilings: the building is an open diorama).
const WALL_H := 2.7
## Building levels of the floor indices that aren't plain storeys: the
## stairwell landings sit halfway between the floors they join.
const LEVELS := {5: 1.5, 6: 3.5}


## Storey number of a floor index (0 = street level).
static func level(f: int) -> float:
	return LEVELS.get(f, float(f))


## World y of a floor's walking surface.
static func floor_y(f: int) -> float:
	return level(f) * STOREY


## A position in world pixels (as in PlayerView.position) on floor `f`.
static func px_to_world(p: Vector2, f: int) -> Vector3:
	return Vector3(p.x * PX, floor_y(f), p.y * PX)


## Centre of a tile on floor `f`.
static func tile_to_world(t: Vector2i, f: int) -> Vector3:
	return Vector3(t.x + 0.5, floor_y(f), t.y + 0.5)


## World point -> world pixels on the map grid (drops the height).
static func world_to_px(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z) * TILE_PX
