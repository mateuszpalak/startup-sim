## Turns one floor of the map (MapData) into 3D geometry: floors, thin walls
## with windows, door frames, stairs, wall-like objects (fences, railings,
## shutters...) and furniture (props.gd). Everything is merged into a few
## MeshBatches per floor (one draw call per material).
##
## Layout: the returned Node3D sits at y = Coords.floor_y(f); inside it, one
## tile = 1 m, tile (x, y) spans x..x+1, z = y..y+1 (see coords.gd).
## Its metadata: "heights" (Vector2i tile -> extra height of stairs/steps,
## for placing characters), "lamps" (Array of {room, pos: Vector3, range}).
extends RefCounted

const Coords = preload("res://world3d/coords.gd")
const MeshBatch = preload("res://world3d/mesh_batch.gd")
const Materials = preload("res://world3d/materials.gd")
const Props = preload("res://world3d/props.gd")
const ArtMaterials = preload("res://world3d/art/art_materials.gd")
const Doors = preload("res://world3d/art/doors.gd")
const Signage = preload("res://world3d/art/signage.gd")
const Exterior = preload("res://world3d/art/exterior.gd")
const S = preload("res://world3d/art/shapes.gd")
const Kit = preload("res://ui/ui_kit.gd")

const WALL_T := 0.28          # wall thickness
const DOOR_H := 2.15          # top of door openings
const SILL := 0.9             # windows: bottom / top
const WIN_TOP := 2.25
const CHUNK_M := 8.0          # Mobile renderer: mesh cell size (m)
const SLAB := 0.35            # floor slab thickness (edges seen from above)

## Floor types -> [pattern, colour] (the legend colour is blended in).
const GROUND := {
	"floor": [Materials.GROUND_PLANKS, "#b88a5c"],
	"carpet": [Materials.GROUND_CARPET, ""],
	"tiles": [Materials.GROUND_TILES, "#cfd2d2"],
	"lobby": [Materials.GROUND_STONE, "#ddd0b4"],
	"parking": [Materials.GROUND_ASPHALT, "#6c6d70"],
	"grass": [Materials.GROUND_GRASS, "#5f8a45"],
	"sidewalk": [Materials.GROUND_PAVING, "#b9b6ab"],
	"street": [Materials.GROUND_ASPHALT, "#4a4d53"],
	"tram_track": [Materials.GROUND_PAVING, "#7a7066"],
	"smoking_area": [Materials.GROUND_PAVING, "#9a8d74"],
	"balcony": [Materials.GROUND_PLANKS, "#a8794e"],
	"ramp": [Materials.GROUND_ASPHALT, "#55585e"],
	"elevator": [Materials.GROUND_METAL, "#a9b3ba"],
	"stairs": [Materials.GROUND_STONE, "#bfae96"],
	"steps": [Materials.GROUND_STONE, "#bfae96"],
}

## Carpet colour by room type.
const CARPETS := {"department": Color("#56637f"), "meeting": Color("#5e6e57"), "common": Color("#8a6650"),
	"board": Color("#6e3434"), "corridor": Color("#646873"), "hall": Color("#646873"), "chill": Color("#7a5a72")}

const DOOR_TYPES := ["door", "glass_door", "card_gate", "card_door", "garage_gate", "elevator_door", "board_door",
	"stall_door", "service_door", "locked_door", "storeroom_door"]
## Tiles a wall connects to (full-height, in a wall line).
const WALLISH := ["wall", "garage_shutter"]
## Per-tile wall-like objects (not furniture).
const LINEAR := ["fence", "railing", "ramp_wall", "shelter_glass", "garage_shutter", "boom_barrier"]

const PLASTER := Color("#ddd2c0")
const FACADE := Color("#b89c80")
const SKIRTING := Color("#6d5a4a")
const WALL_TOP := Color("#5e5047")
const ROOM_WALLS := {"bathroom": Color("#bfd3da"), "stall": Color("#bfd3da"), "kitchen": Color("#e3c890"),
	"board": Color("#9c7a5a"), "server": Color("#a9b2bc"), "chill": Color("#d9a99a"), "shop": Color("#c9dcb8"),
	"department": Color("#d6cdbd"), "meeting": Color("#a9bfa0")}

var map
var f := 0
var ground := MeshBatch.new()
var walls := MeshBatch.new()
var things := MeshBatch.new()
var heights := {}
var props := Props.new()


func build(building, floor_index: int, floor_names := {}) -> Node3D:
	map = building.get_floor(floor_index)
	f = floor_index
	# The Mobile renderer (phones) lights each mesh with at most 8 omni
	# lights: cut the floor into cells so every room keeps its lamps.
	if RenderingServer.get_current_rendering_method() == "mobile":
		for batch in [ground, walls, things]:
			batch.chunk = CHUNK_M
	var root := Node3D.new()
	root.name = "Floor%d" % f
	root.position.y = Coords.floor_y(f)
	_ground()
	if f != 0:
		_slab_edges()
	_walls()
	_stairs()
	_props()
	_linear()
	if f == 0:
		_outdoors()
		Exterior.street(self)
	Signage.build(self, root)
	var mats := ArtMaterials.merged(Materials.get_all())
	if f == 0:
		var ext := Exterior.storeys(self, mats)
		if ext:
			root.add_child(ext)
	for pair in [[ground, "Ground"], [walls, "Walls"], [things, "Things"]]:
		var b: MeshBatch = pair[0]
		if not b.is_empty():
			root.add_child(b.to_node(mats, pair[1]))
	_labels(root, floor_names)
	root.set_meta("heights", heights)
	root.set_meta("lamps", _lamps())
	return root


# ------------------------------------------------------------- map queries

func _ch(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= map.width or y >= map.height:
		return ""
	return map.tile_chars[y * map.width + x]


func _type(x: int, y: int) -> String:
	var c := _ch(x, y)
	return map.legend[c]["type"] if c != "" else "void"


func _solid(x: int, y: int) -> bool:
	return map.is_blocked(x, y)


func _is_door(x: int, y: int) -> bool:
	return _type(x, y) in DOOR_TYPES


func _is_wallish(x: int, y: int) -> bool:
	return _type(x, y) in WALLISH


## Does a wall at (x, y) connect towards this neighbour?
func _joins(x: int, y: int) -> bool:
	var t := _type(x, y)
	return t in WALLISH or t in DOOR_TYPES


## Outside: beyond the map, open air, a hedge, or an outdoor room.
func _outside(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= map.width or y >= map.height:
		return true
	var t := _type(x, y)
	if t in WALLISH:
		return false
	if t in ["void", "fence"]:
		return true
	return map.room_outdoor.has(map.room_at_tile(x, y))


## Floor under a solid object / door / wall: the most common walkable
## neighbour's type (a door takes its own room's).
func _floor_under(x: int, y: int) -> String:
	var counts := {}
	var own: int = map.room_at_tile(x, y) if _is_door(x, y) else -1
	for pass_i in 2:
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			var t := _type(nx, ny)
			if _solid(nx, ny) or t in DOOR_TYPES or t in ["stairs", "void", "steps"] or not GROUND.has(t):
				continue
			if pass_i == 0 and own != -1 and map.room_at_tile(nx, ny) != own:
				continue
			counts[t] = counts.get(t, 0) + 1
		if not counts.is_empty():
			break
	var best := ""
	var best_n := 0
	for t in counts:
		if counts[t] > best_n:
			best_n = counts[t]
			best = t
	return best


func _legend_color(x: int, y: int) -> Color:
	var c := _ch(x, y)
	return Color(map.legend[c].get("color", "#888888")) if c != "" else Color.GRAY


func _hash(x: int, y: int, salt := 0) -> int:
	return absi(hash(Vector3i(x, y, salt + f * 7919)))


# ------------------------------------------------------------- ground

## Ground style of a tile: [pattern, colour] or [] for none.
func _ground_style(x: int, y: int) -> Array:
	var t := _type(x, y)
	if t == "void":
		return []
	var src := Vector2i(x, y)
	if not GROUND.has(t):
		var under := _floor_under(x, y)
		if under == "":
			return [] if t != "fence" else _style_of("grass", src)
		# use a neighbour of that type for the colour
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			if _type(x + d.x, y + d.y) == under:
				src = Vector2i(x + d.x, y + d.y)
				break
		t = under
	return _style_of(t, src)


func _style_of(t: String, src: Vector2i) -> Array:
	var g: Array = GROUND.get(t, [Materials.GROUND_PLAIN, ""])
	var legend := _legend_color(src.x, src.y)
	var col: Color = legend if g[1] == "" else Color(g[1]).lerp(legend, 0.35)
	if t == "carpet":
		var rt: String = map.room_types.get(map.room_at_tile(src.x, src.y), "")
		col = CARPETS.get(rt, legend.darkened(0.25).lerp(Color("#6d7180"), 0.3))
	return [g[0], col]


func _ground() -> void:
	for y in map.height:
		var x := 0
		while x < map.width:
			var s := _ground_style(x, y)
			if s.is_empty():
				x += 1
				continue
			var x1 := x + 1
			while x1 < map.width and _ground_style(x1, y) == s:
				x1 += 1
			ground.quad_up(x, y, x1, y + 1, 0.0, "ground", s[1], Vector2(s[0], 0))
			x = x1


## Upper floors: the thickness of the slab where the floor ends in open air.
func _slab_edges() -> void:
	var col := Color("#8b8378")
	for y in map.height:
		for x in map.width:
			if _type(x, y) == "void":
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _type(x + d.x, y + d.y) != "void":
					continue
				var n := Vector3(d.x, 0, d.y)
				var cx: float = x + 0.5 + d.x * 0.5
				var cz: float = y + 0.5 + d.y * 0.5
				var ax := Vector3(absf(d.y) * 0.5, 0, absf(d.x) * 0.5)
				var c := Vector3(cx, 0, cz)
				ground.quad(c - ax + Vector3(0, -SLAB, 0), c + ax + Vector3(0, -SLAB, 0), c + ax, c - ax, n, "matte", col)


# ------------------------------------------------------------- walls

## Colour of a wall face looking at tile (x, y).
func _face_color(x: int, y: int) -> Color:
	if _outside(x, y):
		return FACADE
	var rt: String = map.room_types.get(map.room_at_tile(x, y), "")
	return ROOM_WALLS.get(rt, PLASTER)


## A window in this wall tile? Returns the direction to the inside, or zero.
## (Same rule as the 2D painter: straight walls of rooms with windows, a
## pillar every 4 tiles.)
func _window_dir(x: int, y: int) -> Vector2i:
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var ix: int = x + d.x
		var iy: int = y + d.y
		if _is_wallish(ix, iy) or not _outside(x - d.x, y - d.y):
			continue
		var r: int = map.room_at_tile(ix, iy)
		if not map.room_windows.has(r) or map.room_outdoor.has(r):
			continue
		var along := Vector2i(d.y, d.x)
		if not (_is_wallish(x + along.x, y + along.y) and _is_wallish(x - along.x, y - along.y)):
			continue
		if (x if along.x != 0 else y) % 4 == 0:
			continue
		return d
	return Vector2i.ZERO


func _walls() -> void:
	for y in map.height:
		for x in map.width:
			var t := _type(x, y)
			if t == "wall":
				_wall_tile(x, y)
			elif t in DOOR_TYPES:
				_door_tile(x, y, t)


## A thin wall through the tile centre, with arms towards connected walls /
## doors. Faces get the colour of the room they look into.
func _wall_tile(x: int, y: int) -> void:
	var e := _joins(x + 1, y)
	var w := _joins(x - 1, y)
	var s := _joins(x, y + 1)
	var n := _joins(x, y - 1)
	var h := Coords.WALL_H
	var lo := 0.5 - WALL_T / 2
	var hi := 0.5 + WALL_T / 2
	var win := _window_dir(x, y)
	var segs := []  # [x0, z0, x1, z1, faces mask]
	if e or w or not (n or s):
		segs.append([x + (0.0 if w else lo), y + lo, x + (1.0 if e else hi), y + hi, (0 if e else 1) | (0 if w else 2) | 4 | 16 | 32])
		if n:
			segs.append([x + lo, y + 0.0, x + hi, y + lo, 1 | 2 | 4])
		if s:
			segs.append([x + lo, y + hi, x + hi, y + 1.0, 1 | 2 | 4])
	else:
		segs.append([x + lo, y + (0.0 if n else lo), x + hi, y + (1.0 if s else hi), 1 | 2 | 4 | (0 if s else 16) | (0 if n else 32)])
	for sg in segs:
		var cols := {
			1: _face_color(x + 1, y), 2: _face_color(x - 1, y), 16: _face_color(x, y + 1), 32: _face_color(x, y - 1)}
		if win != Vector2i.ZERO:
			_window_wall(sg, cols, win, h)
		else:
			_wall_box(Vector3(sg[0], 0, sg[1]), Vector3(sg[2], h, sg[3]), sg[4], cols)


## One wall box: plaster faces with a skirting board, a dark top.
func _wall_box(lo: Vector3, hi: Vector3, faces: int, cols: Dictionary, skirting := true) -> void:
	if faces & 4:
		walls.quad_up(lo.x, lo.z, hi.x, hi.z, hi.y, "wall", WALL_TOP)
	var sk := 0.12 if skirting and lo.y < 0.01 else 0.0
	for bit in [1, 2, 16, 32]:
		if not (faces & bit):
			continue
		var col: Color = cols[bit]
		var skirt := SKIRTING if col != FACADE else col.darkened(0.25)
		if sk > 0.0:
			walls.box(lo, Vector3(hi.x, lo.y + sk, hi.z), "wall", skirt, bit)
		walls.box(Vector3(lo.x, lo.y + sk, lo.z), hi, "wall", col, bit)


## A wall piece with a window: sill wall, glass, lintel wall.
func _window_wall(sg: Array, cols: Dictionary, win: Vector2i, h: float) -> void:
	var lo := Vector3(sg[0], 0, sg[1])
	var hi := Vector3(sg[2], h, sg[3])
	var faces: int = sg[4]
	_wall_box(lo, Vector3(hi.x, SILL, hi.z), faces & ~4, cols)
	walls.quad_up(lo.x, lo.z, hi.x, hi.z, SILL, "wall", Color("#f4f1ea"))  # sill
	_wall_box(Vector3(lo.x, WIN_TOP, lo.z), hi, faces, cols, false)
	walls.box(Vector3(lo.x, WIN_TOP - 0.02, lo.z), Vector3(hi.x, WIN_TOP, hi.z), "wall", Color("#f4f1ea"), 8)
	# glass in the middle of the wall, a frame around it
	var along_x := hi.x - lo.x > hi.z - lo.z
	var c := (lo + hi) / 2
	if along_x:
		things.box(Vector3(lo.x, SILL, c.z - 0.015), Vector3(hi.x, WIN_TOP, c.z + 0.015), "glass", Color(0.72, 0.86, 0.95, 0.28), 63)
		things.box(Vector3(c.x - 0.03, SILL, c.z - 0.04), Vector3(c.x + 0.03, WIN_TOP, c.z + 0.04), "matte", Color("#f4f1ea"), 1 | 2 | 16 | 32)
	else:
		things.box(Vector3(c.x - 0.015, SILL, lo.z), Vector3(c.x + 0.015, WIN_TOP, hi.z), "glass", Color(0.72, 0.86, 0.95, 0.28), 63)
		things.box(Vector3(c.x - 0.04, SILL, c.z - 0.03), Vector3(c.x + 0.04, WIN_TOP, c.z + 0.03), "matte", Color("#f4f1ea"), 1 | 2 | 16 | 32)


## Doorways: the wall above the opening, a frame, and what fills it.
func _door_tile(x: int, y: int, t: String) -> void:
	# Orientation: in a wall running left-right, or up-down.
	var horiz := (_joins(x - 1, y) or _solid(x - 1, y)) and (_joins(x + 1, y) or _solid(x + 1, y))
	if not horiz and not ((_joins(x, y - 1) or _solid(x, y - 1)) and (_joins(x, y + 1) or _solid(x, y + 1))):
		horiz = _joins(x - 1, y) or _joins(x + 1, y)
	var h := Coords.WALL_H
	var lo := 0.5 - WALL_T / 2
	var hi := 0.5 + WALL_T / 2
	var a: Vector3
	var b: Vector3
	var prev_same: bool
	var next_same: bool
	if horiz:
		a = Vector3(x, 0, y + lo)
		b = Vector3(x + 1, 0, y + hi)
		prev_same = _type(x - 1, y) == t
		next_same = _type(x + 1, y) == t
	else:
		a = Vector3(x + lo, 0, y)
		b = Vector3(x + hi, 0, y + 1)
		prev_same = _type(x, y - 1) == t
		next_same = _type(x, y + 1) == t
	var cols := {1: _face_color(x + 1, y), 2: _face_color(x - 1, y), 16: _face_color(x, y + 1), 32: _face_color(x, y - 1)}
	var top := DOOR_H if t not in ["garage_gate", "elevator_door"] else (2.4 if t == "garage_gate" else 2.2)
	if t == "garage_gate":
		top = minf(2.5, h - 0.1)
	var side_faces := (16 | 32) if horiz else (1 | 2)
	_wall_box(Vector3(a.x, top, a.z), Vector3(b.x, h, b.z), 4 | 8 | side_faces, cols, false)
	var frame_col: Color = {"door": Color("#8a5a3a"), "board_door": Color("#5a3a26"), "service_door": Color("#6f6a66"),
		"storeroom_door": Color("#6f6a66"), "locked_door": Color("#7a2a2a"), "stall_door": Color("#9fb3c8"),
		"glass_door": Color("#a3abb3"), "card_door": Color("#5d6168"), "card_gate": Color("#5d6168"),
		"elevator_door": Color("#b8c4cc"), "garage_gate": Color("#e0b030")}.get(t, Color("#8a5a3a"))
	var mat := "metal" if t in ["glass_door", "card_door", "card_gate", "elevator_door", "garage_gate", "service_door"] else "wood"
	var fw := 0.07
	# Frame posts at the ends of a run of the same door; a head under the lintel.
	var th := Vector3(0.02, 0, 0.02) * (Vector3(0, 0, 1) if horiz else Vector3(1, 0, 0))
	if horiz:
		if not prev_same:
			things.box(Vector3(a.x, 0, a.z - 0.02), Vector3(a.x + fw, top, b.z + 0.02), mat, frame_col)
		if not next_same:
			things.box(Vector3(b.x - fw, 0, a.z - 0.02), Vector3(b.x, top, b.z + 0.02), mat, frame_col)
		things.box(Vector3(a.x, top - fw, a.z - 0.02), Vector3(b.x, top, b.z + 0.02), mat, frame_col, 8 | 16 | 32)
	else:
		if not prev_same:
			things.box(Vector3(a.x - 0.02, 0, a.z), Vector3(b.x + 0.02, top, a.z + fw), mat, frame_col)
		if not next_same:
			things.box(Vector3(a.x - 0.02, 0, b.z - fw), Vector3(b.x + 0.02, top, b.z), mat, frame_col)
		things.box(Vector3(a.x - 0.02, top - fw, a.z), Vector3(b.x + 0.02, top, b.z), mat, frame_col, 8 | 1 | 2)
	var mid := (a + b) / 2
	Doors.build(self, x, y, t, a, b, horiz, top, prev_same, next_same)
	match t:
		"glass_door":
			# a glass fan light over the opening (the doors slide away)
			things.box(Vector3(a.x, top - 0.25, mid.z - 0.01) if horiz else Vector3(mid.x - 0.01, top - 0.25, a.z),
				Vector3(b.x, top - fw, mid.z + 0.01) if horiz else Vector3(mid.x + 0.01, top - fw, b.z), "glass", Color(0.7, 0.85, 0.95, 0.35), 63)
		"card_door", "card_gate":
			# a turnstile: two posts with glass flaps (open/closed is the server's business)
			var p0 := Vector3(mid.x - 0.42, 0, mid.z) if horiz else Vector3(mid.x, 0, mid.z - 0.42)
			var p1 := Vector3(mid.x + 0.42, 0, mid.z) if horiz else Vector3(mid.x, 0, mid.z + 0.42)
			for p in [p0, p1]:
				things.block(p.x, p.z, 0.12 if horiz else 0.5, 0.5 if horiz else 0.12, 0, 1.0, "metal", Color("#3a3d44"), Color("#5a5e66"))
				things.box(p + Vector3(-0.06, 0.98, -0.06), p + Vector3(0.06, 1.0, 0.06), "screen", Color("#40e070"), 4)
		"garage_gate":
			for i in 6:
				var u := float(i) / 6.0
				var col := Color("#e0b030") if i % 2 == 0 else Color("#24262b")
				if horiz:
					things.box(Vector3(a.x + u, top - 0.2, a.z - 0.03), Vector3(a.x + u + 1.0 / 6.0, top, b.z + 0.03), "matte", col, 16 | 32 | 8)
				else:
					things.box(Vector3(a.x - 0.03, top - 0.2, a.z + u), Vector3(b.x + 0.03, top, a.z + u + 1.0 / 6.0), "matte", col, 1 | 2 | 8)
		"elevator_door":
			# the steel surround; the sliding doors are the elevator door view's job
			if not prev_same and not next_same or (prev_same and next_same):
				var ind := Vector3(mid.x, top + 0.12, mid.z)
				var o := Vector3(0, 0, WALL_T / 2 + 0.01) if horiz else Vector3(WALL_T / 2 + 0.01, 0, 0)
				for sgn in [-1.0, 1.0]:
					var pc: Vector3 = ind + o * sgn
					things.box(pc - Vector3(0.18 if horiz else 0.005, 0.07, 0.005 if horiz else 0.18), pc + Vector3(0.18 if horiz else 0.005, 0.07, 0.005 if horiz else 0.18), "screen", Color("#ffb347"), 63)


## A closed door leaf in the opening.
func _leaf(a: Vector3, b: Vector3, horiz: bool, top: float, col: Color) -> void:
	var mid := (a + b) / 2
	if horiz:
		things.box(Vector3(a.x + 0.07, 0.02, mid.z - 0.03), Vector3(b.x - 0.07, top - 0.07, mid.z + 0.03), "wood", col, 63 & ~8)
	else:
		things.box(Vector3(mid.x - 0.03, 0.02, a.z + 0.07), Vector3(mid.x + 0.03, top - 0.07, b.z - 0.07), "wood", col, 63 & ~8)


# ------------------------------------------------------------- stairs

## Connected groups of tiles of the given types.
func _groups(types: Array) -> Array:
	var seen := {}
	var out := []
	for y in map.height:
		for x in map.width:
			if seen.has(Vector2i(x, y)) or _type(x, y) not in types:
				continue
			var c := _ch(x, y)
			var tiles: Array[Vector2i] = []
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			seen[Vector2i(x, y)] = true
			while not stack.is_empty():
				var t: Vector2i = stack.pop_back()
				tiles.append(t)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nb: Vector2i = t + d
					if not seen.has(nb) and _ch(nb.x, nb.y) == c:
						seen[nb] = true
						stack.append(nb)
			var r := Rect2i(tiles[0], Vector2i.ONE)
			for t in tiles:
				r = r.expand(t).expand(t + Vector2i.ONE)
			out.append({"type": _type(x, y), "rect": r, "tiles": tiles})
	return out


## Steps rising away from the side you walk in from. Visual only (the
## server's floors are flat); `heights` lets characters follow them.
func _stairs() -> void:
	for g in _groups(["stairs", "steps"]):
		var r: Rect2i = g.rect
		# entry side: the one with the most walkable, non-stair neighbours
		var best := Vector2i(0, 1)
		var best_n := -1
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var cnt := 0
			for t: Vector2i in g.tiles:
				var nb: Vector2i = t + d
				if not r.has_point(nb) and not _solid(nb.x, nb.y) and _type(nb.x, nb.y) not in ["stairs", "steps", "void"]:
					cnt += 1
			if cnt > best_n:
				best_n = cnt
				best = d
		# steps run along -best (away from the entry)
		var run := -best
		var length := r.size.y if run.y != 0 else r.size.x
		var steps := length * 3
		var rise := minf(0.15, 1.2 / steps) if g.type == "steps" else 0.12
		var col := Color("#c9b9a0")
		for i in steps:
			var u0 := float(i) / 3.0
			var u1 := float(i + 1) / 3.0
			var hgt := (i + 1) * rise
			var lo: Vector3
			var hi: Vector3
			match run:
				Vector2i(0, -1): lo = Vector3(r.position.x, 0, r.end.y - u1); hi = Vector3(r.end.x, hgt, r.end.y - u0)
				Vector2i(0, 1): lo = Vector3(r.position.x, 0, r.position.y + u0); hi = Vector3(r.end.x, hgt, r.position.y + u1)
				Vector2i(-1, 0): lo = Vector3(r.end.x - u1, 0, r.position.y); hi = Vector3(r.end.x - u0, hgt, r.end.y)
				_: lo = Vector3(r.position.x + u0, 0, r.position.y); hi = Vector3(r.position.x + u1, hgt, r.end.y)
			things.box(lo, hi, "matte", col.darkened(0.04 * (i % 2)), 63 & ~8, col.lightened(0.06))
		for t: Vector2i in g.tiles:
			var along := float(t.y - r.position.y) if run.y != 0 else float(t.x - r.position.x)
			if run.y < 0 or run.x < 0:
				along = float(length - 1) - along
			heights[t] = (along + 0.5) * 3.0 * rise


# ------------------------------------------------------------- furniture

func _props() -> void:
	var types := []
	for t in Props.BUILDERS:
		types.append(t)
	var index := 0
	for g in _groups(types):
		var r: Rect2i = g.rect
		var face := _facing(r, g.type)
		var size := Vector2(r.size)
		var center := Vector2(r.position) + size / 2
		var yaw := atan2(float(face.x), float(face.y))
		var w := size.x if face.y != 0 else size.y
		var d := size.y if face.y != 0 else size.x
		var origin := Vector3(center.x, 0, center.y)
		if g.type in Props.WALL_HUGGERS and _against_wall(r, -face):
			origin -= Vector3(face.x, 0, face.y) * (0.5 - WALL_T / 2)  # flush with the thin wall
		things.xf = Transform3D(Basis(Vector3.UP, yaw), origin)
		props.build(things, g.type, {"w": w, "d": d, "tiles": r, "index": index, "color": _legend_color(r.position.x, r.position.y),
			"room_type": map.room_types.get(map.room_at_tile(r.position.x, r.position.y), ""), "map": map, "center": center})
		things.xf = Transform3D.IDENTITY
		index += 1


## All tiles on side `d` of the rect are walls?
func _against_wall(r: Rect2i, d: Vector2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var nb := Vector2i(x, y) + d
			if not r.has_point(nb) and not _is_wallish(nb.x, nb.y):
				return false
	return true


## Which way an object faces: away from the wall it stands against
## (north wall first), else towards the camera (south).
func _facing(r: Rect2i, type: String) -> Vector2i:
	if type in Props.WALL_HUGGERS:
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			if _against_wall(r, d):
				return -d
		if type == "desk":
			return Vector2i(0, 1)
		# no wall: face the open side
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var free := true
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					var nb: Vector2i = Vector2i(x, y) + d
					if not r.has_point(nb) and _solid(nb.x, nb.y):
						free = false
			if free:
				return d
	return Vector2i(0, 1)


# ------------------------------------------------------------- wall-likes

func _linear() -> void:
	for y in map.height:
		for x in map.width:
			var t := _type(x, y)
			if t not in LINEAR:
				continue
			var same := func(dx: int, dy: int) -> bool: return _type(x + dx, y + dy) == t or (t != "fence" and _joins(x + dx, y + dy))
			var e: bool = same.call(1, 0)
			var w: bool = same.call(-1, 0)
			var s: bool = same.call(0, 1)
			var n: bool = same.call(0, -1)
			match t:
				"fence":
					# a trimmed hedge along the plot's edge: one rounded block
					# per straight run (drawn from the run's first tile)
					var hc := Color("#4c7a3a").lerp(Color("#5d8c42"), float(_hash(x, y) % 4) / 4.0)
					var runs := []
					if e and not w:
						var x1: int = x
						while _type(x1 + 1, y) == t:
							x1 += 1
						runs.append(Rect2(x, y, x1 - x + 1, 1))
					if s and not n:
						var y1: int = y
						while _type(x, y1 + 1) == t:
							y1 += 1
						runs.append(Rect2(x, y, 1, y1 - y + 1))
					if not (e or w or n or s):
						runs.append(Rect2(x, y, 1, 1))
					for r: Rect2 in runs:
						S.rbox(things, Vector3(r.position.x + 0.08, 0, r.position.y + 0.08), Vector3(r.end.x - 0.08, 1.0, r.end.y - 0.08), 0.14, "leaf", hc, hc.lightened(0.08))
					for k in 2:
						var p := Vector3(x + 0.25 + 0.5 * k, 0.93, y + 0.3 + float(_hash(x, y, k + 3) % 40) / 100.0)
						things.sphere(p, 0.2 + float(_hash(x, y, k) % 3) * 0.03, "leaf", hc.lightened(0.04 * k), Vector3(1, 0.55, 1), 2, 6)
				"railing":
					_thin_line(x, y, e, w, n, s, 0.06, 1.0, "glass", Color(0.75, 0.88, 0.95, 0.3))
					_thin_line(x, y, e, w, n, s, 0.08, 0.06, "metal", Color("#d0d6db"), 1.0)
				"ramp_wall":
					_thin_line(x, y, e, w, n, s, 0.3, 1.0, "matte", Color("#b5b2aa"))
				"shelter_glass":
					_thin_line(x, y, e, w, n, s, 0.05, 2.2, "glass", Color(0.66, 0.85, 0.92, 0.4))
					_thin_line(x, y, e, w, n, s, 0.07, 0.08, "metal", Color("#5a6470"), 2.2)
				"garage_shutter":
					_thin_line(x, y, e, w, n, s, 0.18, Coords.WALL_H, "metal", Color("#4a4e55"))
				"boom_barrier":
					things.block(x + 0.5, y + 0.5, 0.18, 0.18, 0, 1.0, "metal", Color("#e8e8e8"))
					var col := Color("#d23b2e") if (x + y) % 2 == 0 else Color("#f2f2f2")
					if e or w:
						things.box(Vector3(x, 0.92, y + 0.45), Vector3(x + 1, 1.0, y + 0.55), "matte", col)
					else:
						things.box(Vector3(x + 0.45, 0.92, y), Vector3(x + 0.55, 1.0, y + 1), "matte", col)


## A thin vertical strip through the tile centre, joined to neighbours.
func _thin_line(x: int, y: int, e: bool, w: bool, n: bool, s: bool, t: float, h: float, mat: String, col: Color, y0 := 0.0) -> void:
	var lo := 0.5 - t / 2
	var hi := 0.5 + t / 2
	if e or w or not (n or s):
		things.box(Vector3(x + (0.0 if w else lo), y0, y + lo), Vector3(x + (1.0 if e else hi), y0 + h, y + hi), mat, col, 63)
	if n or s:
		things.box(Vector3(x + lo, y0, y + (0.0 if n else lo)), Vector3(x + hi, y0 + h, y + (1.0 if s else hi)), mat, col, 63)


# ------------------------------------------------------------- outdoors

## Floor 0: the land around the plot, trees on the lawns, street lamps,
## tram rails.
func _outdoors() -> void:
	var col := Color("#557f40")
	var m := 60.0
	var W: float = map.width
	var H: float = map.height
	for q in [[-m, -m, W + m, 0.0], [-m, H, W + m, H + m], [-m, 0.0, 0.0, H], [W, 0.0, W + m, H]]:
		ground.quad_up(q[0], q[1], q[2], q[3], -0.01, "ground", col, Vector2(Materials.GROUND_GRASS, 0))
	var c := {"index": 0, "color": Color.WHITE, "room_type": "", "map": map, "w": 1.0, "d": 1.0}
	# trees: lawn tiles well away from anything else
	for y in map.height:
		for x in map.width:
			if _type(x, y) != "grass" or _hash(x, y, 5) % 9 != 0:
				continue
			var ok := true
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if _type(x + dx, y + dy) != "grass":
						ok = false
			if not ok:
				continue
			c.tiles = Rect2i(x, y, 1, 1)
			things.xf = Transform3D(Basis(Vector3.UP, float(_hash(x, y, 2) % 628) / 100.0), Vector3(x + 0.5, 0, y + 0.5))
			props.build(things, "tree", c)
	# a row of trees outside the plot, beyond the hedge
	for i in range(0, map.width + 8, 5):
		for side in [-3.5, H + 3.5]:
			c.tiles = Rect2i(i, int(side), 1, 1)
			things.xf = Transform3D(Basis(Vector3.UP, float(i) * 1.3), Vector3(i - 2.0, 0, side))
			props.build(things, "tree", c)
	# street lamps along the pavement next to the street
	for y in map.height:
		for x in range(2, map.width - 2, 7):
			if _type(x, y) == "sidewalk" and _type(x, y + 1) == "street":
				c.tiles = Rect2i(x, y, 1, 1)
				things.xf = Transform3D(Basis.IDENTITY, Vector3(x + 0.5, 0, y + 0.6))
				props.build(things, "street_lamp", c)
	things.xf = Transform3D.IDENTITY
	# tram rails
	for y in map.height:
		for x in map.width:
			if _type(x, y) == "tram_track":
				for z in [0.28, 0.72]:
					things.box(Vector3(x, 0, y + z - 0.03), Vector3(x + 1, 0.04, y + z + 0.03), "metal", Color("#8d8f93"), 4 | 16 | 32)


# ------------------------------------------------------------- labels, lamps

func _labels(root: Node3D, floor_names: Dictionary) -> void:
	for link in map.links:
		if link.kind != "stairs" or not floor_names.has(link.to_floor):
			continue
		var a: Rect2i = link.rect
		var l := Label3D.new()
		l.text = "▸ " + floor_names[link.to_floor]
		l.font = Kit.font()
		l.font_size = 48
		l.outline_size = 12
		l.modulate = Kit.PAPER_HI
		l.outline_modulate = Kit.INK
		l.pixel_size = 0.006
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.position = Vector3(a.position.x + a.size.x / 2.0, 2.0, a.position.y + a.size.y / 2.0)
		root.add_child(l)


## Ceiling lamps: one per room with lights (the bigger rooms get a grid).
func _lamps() -> Array:
	var tiles := {}
	for y in map.height:
		for x in map.width:
			var r: int = map.room_at_tile(x, y)
			if r == 0 or _solid(x, y):
				continue
			if not tiles.has(r):
				tiles[r] = []
			tiles[r].append(Vector2i(x, y))
	var out := []
	for r in tiles:
		if map.room_outdoor.has(r):
			continue
		var ts: Array = tiles[r]
		var bb := Rect2i(ts[0], Vector2i.ONE)
		for t in ts:
			bb = bb.expand(t).expand(t + Vector2i.ONE)
		var nx := maxi(1, int(round(bb.size.x / 7.0)))
		var nz := maxi(1, int(round(bb.size.y / 7.0)))
		for i in nx:
			for j in nz:
				var p := Vector2(bb.position.x + bb.size.x * (i + 0.5) / nx, bb.position.y + bb.size.y * (j + 0.5) / nz)
				var rng := maxf(bb.size.x / float(nx), bb.size.y / float(nz)) * 0.9 + 2.0
				out.append({"room": r, "pos": Vector3(p.x, Coords.WALL_H - 0.3, p.y), "range": rng})
	return out
