## Furniture and other map objects as procedural low-poly meshes.
##
## THE REGISTRY for map art: one builder per legend `type` (see
## client/maps/*.json). An art agent upgrades a look by rewriting its builder
## (or swapping it for a .glb loader) - nothing else depends on the shapes:
## collision stays in the map's `solid` flags.
##
## A builder gets the MeshBatch `b` (its `xf` is already set: origin at the
## object's centre on the floor, local +z = the side facing into the room,
## i.e. where people stand / sit) and `c`, the context:
##   c.w, c.d     - size across (local x) and deep (local z), metres
##   c.tiles      - Rect2i of the map tiles it covers
##   c.index      - running number (for variation)
##   c.color      - the legend colour of the tile
##   c.room_type  - type of the room it's in ("department", "kitchen", ...)
##   c.map        - MapData (read only)
##   c.center     - Vector2 world x/z of the centre
## Connected tiles with the same map char form one object (like the 2D
## painter did), e.g. a 4-tile "WWWW" row is one desk block.
extends RefCounted

const MeshBatch = preload("res://world3d/mesh_batch.gd")

## type -> builder method name. Types not listed here and not handled by
## map_builder.gd (walls, doors, floors) fall back to `_fallback`.
const BUILDERS := {
	"desk": "_desk", "table": "_table", "counter": "_counter", "shelf": "_shelf",
	"sofa": "_sofa", "armchair": "_armchair", "plant": "_plant", "rack": "_rack",
	"bench": "_bench", "ashtray": "_ashtray", "toilet": "_toilet", "sink": "_sink",
	"urinal": "_urinal", "car": "_car", "coffee_machine": "_coffee_machine",
	"kitchen_counter": "_kitchen_counter", "kitchen_sink": "_kitchen_sink",
	"cupboard": "_cupboard", "dishwasher": "_dishwasher", "fridge": "_fridge",
	"fruit_bowl": "_fruit_bowl", "partition": "_partition", "sanitizer": "_sanitizer",
	"bike_rack": "_bike_rack", "wardrobe": "_wardrobe", "bin": "_bin", "trash_bin": "_trash_bin",
	"tv": "_tv", "medicine_cabinet": "_medicine_cabinet", "key_hook": "_key_hook",
	"liquor_cabinet": "_liquor_cabinet", "shelter_bench": "_shelter_bench",
	"tree": "_tree", "street_lamp": "_street_lamp",
}

## Types that stand against a wall: they turn their front away from it.
const WALL_HUGGERS := ["shelf", "counter", "kitchen_counter", "kitchen_sink", "cupboard", "dishwasher", "fridge",
	"coffee_machine", "wardrobe", "medicine_cabinet", "key_hook", "liquor_cabinet", "tv", "toilet", "sink",
	"urinal", "rack", "sofa", "armchair", "sanitizer", "trash_bin", "fruit_bowl", "bench", "desk"]

const WOOD := Color("#b98a57")
const WOOD_DARK := Color("#6e4c31")
const WHITE := Color("#eeebe4")
const STEEL := Color("#9aa3ab")
const DARK := Color("#2e2f36")
const SCREENS := [Color("#7fc4ef"), Color("#92e0a0"), Color("#f2d27a"), Color("#c8a8f0")]
const FABRICS := [Color("#5b7fa8"), Color("#c46a4f"), Color("#6f9a62"), Color("#d4a24c"), Color("#8a6aa8")]
const CAR_COLORS := [Color("#c0392b"), Color("#2e5fa8"), Color("#ecf0f1"), Color("#2c2f36"), Color("#27ae60"), Color("#8e44ad"), Color("#e6a23c")]


static func has_builder(type: String) -> bool:
	return BUILDERS.has(type)


## Build one object (call on an instance: `Props.new().build(...)`).
func build(b: MeshBatch, type: String, c: Dictionary) -> void:
	call(BUILDERS.get(type, "_fallback"), b, c)


static func _h(c: Dictionary, salt := 0) -> int:
	return absi(hash(Vector3i(c.tiles.position.x, c.tiles.position.y, salt)))


## Is the tile at local (lx, lz) walkable? (Only for unturned objects.)
static func _free(c: Dictionary, lx: float, lz: float) -> bool:
	var p: Vector2 = c.center + Vector2(lx, lz)
	return not c.map.is_blocked(int(floor(p.x)), int(floor(p.y)))


# ----------------------------------------------------------------- fallback

static func _fallback(b: MeshBatch, c: Dictionary) -> void:
	b.block(0, 0, c.w * 0.9, c.d * 0.9, 0, 0.8, "matte", c.color)


# ------------------------------------------------------------- office

static func _chair(b: MeshBatch, x: float, z: float, yaw: float, col: Color) -> void:
	var keep := b.xf
	b.xf = keep * Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0, z))
	b.cylinder(Vector3(0, 0.0, 0), 0.22, 0.03, 0.08, "metal", DARK, 5)
	b.cylinder(Vector3(0, 0.08, 0), 0.03, 0.03, 0.34, "metal", STEEL, 6)
	b.block(0, 0, 0.46, 0.44, 0.42, 0.08, "fabric", col)
	b.block(0, 0.21, 0.44, 0.07, 0.5, 0.5, "fabric", col)
	b.xf = keep


static func _desk(b: MeshBatch, c: Dictionary) -> void:
	var w: float = c.w - 0.06
	var d: float = c.d * 0.78
	var z0: float = -c.d / 2 + 0.03
	var top := WOOD if c.room_type != "department" else Color("#d9c4a0")
	b.box(Vector3(-w / 2, 0.72, z0), Vector3(w / 2, 0.76, z0 + d), "wood", top)
	# legs / side panels
	b.box(Vector3(-w / 2, 0, z0 + 0.04), Vector3(-w / 2 + 0.04, 0.72, z0 + d - 0.04), "matte", Color("#5d5f66"))
	b.box(Vector3(w / 2 - 0.04, 0, z0 + 0.04), Vector3(w / 2, 0.72, z0 + d - 0.04), "matte", Color("#5d5f66"))
	var n := int(round(c.w))
	var dept: bool = c.room_type == "department"
	for i in n:
		var x: float = -c.w / 2 + 0.5 + i
		if dept or (_h(c, i) % 3 != 0):
			# monitor
			var sc: Color = SCREENS[(_h(c, i) / 5) % SCREENS.size()]
			b.block(x, z0 + 0.18, 0.2, 0.14, 0.76, 0.02, "metal", DARK)
			b.block(x, z0 + 0.18, 0.04, 0.04, 0.78, 0.18, "metal", DARK)
			b.box(Vector3(x - 0.3, 0.9, z0 + 0.16), Vector3(x + 0.3, 1.22, z0 + 0.2), "matte", DARK)
			b.box(Vector3(x - 0.27, 0.92, z0 + 0.2), Vector3(x + 0.27, 1.2, z0 + 0.205), "screen", sc, 16)
			# keyboard + mug
			b.block(x, z0 + 0.45, 0.42, 0.14, 0.76, 0.02, "matte", Color("#3a3c44"))
			if _h(c, i + 7) % 3 == 0:
				b.cylinder(Vector3(x + 0.33, 0.76, z0 + 0.4), 0.04, 0.04, 0.09, "matte", [Color("#e85d4a"), WHITE, Color("#3b82c4")][_h(c, i) % 3], 7)
		# chair on the free side
		_chair(b, x, c.d / 2 + 0.25, 0.0, [Color("#2f3138"), Color("#3d4f6b"), Color("#5a3d3d")][_h(c, 1) % 3])


static func _table(b: MeshBatch, c: Dictionary) -> void:
	var w: float = c.w - 0.1
	var d: float = c.d - 0.1
	var round_top: bool = c.w <= 2.01 and c.d <= 2.01
	if round_top and c.w == c.d:
		b.cylinder(Vector3(0, 0.72, 0), w / 2, w / 2, 0.05, "wood", WOOD, 16)
		b.cylinder(Vector3(0, 0, 0), 0.25, 0.05, 0.72, "metal", DARK, 8)
	else:
		b.box(Vector3(-w / 2, 0.72, -d / 2), Vector3(w / 2, 0.77, d / 2), "wood", WOOD if c.index % 2 == 0 else Color("#e4ddd0"))
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				b.block(sx * (w / 2 - 0.08), sz * (d / 2 - 0.08), 0.06, 0.06, 0, 0.72, "metal", DARK)
	# chairs around (meeting / dining tables)
	if c.room_type in ["meeting", "kitchen", "common", "board", "canteen", "chill", "department"] or c.w * c.d >= 4:
		var col: Color = FABRICS[c.index % FABRICS.size()]
		var nx := maxi(1, int(c.w))
		for i in nx:
			var x: float = -c.w / 2 + 0.5 + i
			if _free(c, x, -c.d / 2 - 0.5):
				_chair(b, x, -c.d / 2 - 0.3, PI, col)
			if _free(c, x, c.d / 2 + 0.5):
				_chair(b, x, c.d / 2 + 0.3, 0.0, col)


static func _counter(b: MeshBatch, c: Dictionary) -> void:
	b.box(Vector3(-c.w / 2, 0, -c.d / 2 + 0.05), Vector3(c.w / 2, 1.0, c.d / 2 - 0.05), "wood", Color("#c9a37a"))
	b.box(Vector3(-c.w / 2 - 0.03, 1.0, -c.d / 2), Vector3(c.w / 2 + 0.03, 1.06, c.d / 2), "matte", Color("#efe7da"))
	b.box(Vector3(-c.w / 2 + 0.05, 0.08, c.d / 2 - 0.05), Vector3(c.w / 2 - 0.05, 0.92, c.d / 2 - 0.02), "wood", Color("#a8835a"), 16)


static func _shelf(b: MeshBatch, c: Dictionary) -> void:
	var h := 1.9
	var w: float = c.w - 0.05
	var d: float = minf(c.d, 0.6)
	var z0: float = -c.d / 2 + 0.02
	b.box(Vector3(-w / 2, 0, z0), Vector3(w / 2, h, z0 + 0.04), "matte", Color("#7a7f8a"))
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * w / 2 - (0.04 if sx > 0 else 0.0), 0, z0), Vector3(sx * w / 2 + (0.0 if sx > 0 else 0.04), h, z0 + d), "metal", Color("#8b919b"))
	for k in 5:
		var y := 0.1 + k * 0.42
		b.box(Vector3(-w / 2, y, z0), Vector3(w / 2, y + 0.03, z0 + d), "metal", Color("#a7adb6"))
		# goods
		var x := -w / 2 + 0.06
		var i := 0
		while x < w / 2 - 0.12 and k < 4:
			var gw := 0.12 + float((_h(c, k * 31 + i) % 5)) * 0.04
			var gh := 0.18 + float(_h(c, k * 17 + i) % 4) * 0.05
			var col := Color.from_hsv(float(_h(c, k * 7 + i) % 360) / 360.0, 0.45, 0.85)
			if x + gw < w / 2 - 0.04:
				b.box(Vector3(x, y + 0.03, z0 + 0.06), Vector3(x + gw, y + 0.03 + gh, z0 + d - 0.06), "matte", col)
			x += gw + 0.03
			i += 1


static func _sofa(b: MeshBatch, c: Dictionary) -> void:
	var col: Color = FABRICS[(c.index + 1) % FABRICS.size()]
	var w: float = c.w - 0.1
	var d: float = c.d - 0.1
	b.box(Vector3(-w / 2, 0.08, -d / 2), Vector3(w / 2, 0.42, d / 2), "fabric", col)
	b.box(Vector3(-w / 2, 0.42, -d / 2), Vector3(w / 2, 0.85, -d / 2 + 0.22), "fabric", col.darkened(0.08))
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * w / 2 - (0.18 if sx > 0 else 0.0), 0.42, -d / 2), Vector3(sx * w / 2 + (0.0 if sx > 0 else 0.18), 0.62, d / 2), "fabric", col.darkened(0.12))
	# cushions
	var n := maxi(1, int(round(w / 0.9)))
	for i in n:
		var x0 := -w / 2 + 0.2 + i * (w - 0.4) / n
		var x1 := x0 + (w - 0.4) / n - 0.04
		b.box(Vector3(x0, 0.42, -d / 2 + 0.24), Vector3(x1, 0.5, d / 2 - 0.04), "fabric", col.lightened(0.08))
	for sx in [-1.0, 1.0]:
		b.block(sx * (w / 2 - 0.1), d / 2 - 0.1, 0.06, 0.06, 0, 0.08, "wood", WOOD_DARK)


static func _armchair(b: MeshBatch, c: Dictionary) -> void:
	var col := Color("#8a4a5a")
	b.box(Vector3(-0.38, 0.1, -0.38), Vector3(0.38, 0.45, 0.38), "fabric", col)
	b.box(Vector3(-0.38, 0.45, -0.38), Vector3(0.38, 0.9, -0.18), "fabric", col.darkened(0.1))
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.38 - (0.12 if sx > 0 else 0.0), 0.45, -0.38), Vector3(sx * 0.38 + (0.0 if sx > 0 else 0.12), 0.65, 0.38), "fabric", col.darkened(0.15))


static func _plant(b: MeshBatch, c: Dictionary) -> void:
	var pot: Color = [Color("#c9714a"), Color("#e8e2d6"), Color("#3a3b40")][c.index % 3]
	b.cylinder(Vector3.ZERO, 0.2, 0.26, 0.45, "matte", pot, 10)
	b.cylinder(Vector3(0, 0.45, 0), 0.24, 0.24, 0.01, "matte", Color("#4a3426"), 10)
	var green := Color("#3f8a3a").lerp(Color("#6aa84f"), float(c.index % 4) / 4.0)
	match c.index % 3:
		0:  # bushy
			b.sphere(Vector3(0, 0.85, 0), 0.38, "leaf", green, Vector3(1, 1.1, 1))
			b.sphere(Vector3(0.12, 1.15, 0.05), 0.24, "leaf", green.lightened(0.1))
		1:  # tall (ficus)
			b.cylinder(Vector3(0, 0.45, 0), 0.03, 0.02, 0.9, "wood", WOOD_DARK, 5)
			b.sphere(Vector3(0, 1.35, 0), 0.34, "leaf", green, Vector3(1, 1.2, 1))
			b.sphere(Vector3(-0.15, 1.1, 0.1), 0.22, "leaf", green.darkened(0.1))
		_:  # snake plant: blades
			for i in 7:
				var a := TAU * i / 7.0
				var keep := b.xf
				b.xf = keep * Transform3D(Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), 0.18), Vector3(cos(a) * 0.07, 0.45, sin(a) * 0.07))
				b.box(Vector3(-0.04, 0, -0.01), Vector3(0.04, 0.7 + (i % 3) * 0.15, 0.01), "leaf", green.lerp(Color("#c8d36a"), 0.15 * (i % 2)), 63)
				b.xf = keep


static func _rack(b: MeshBatch, c: Dictionary) -> void:
	# server racks: one per tile
	var n := int(round(c.w))
	for i in n:
		var x: float = -c.w / 2 + 0.5 + i
		b.box(Vector3(x - 0.45, 0, -c.d / 2 + 0.05), Vector3(x + 0.45, 2.0, c.d / 2 - 0.05), "metal", Color("#24262c"))
		for k in 12:
			var y := 0.15 + k * 0.15
			b.box(Vector3(x - 0.4, y, c.d / 2 - 0.05), Vector3(x + 0.4, y + 0.1, c.d / 2 - 0.04), "matte", Color("#33363e"), 16)
			b.box(Vector3(x + 0.25, y + 0.04, c.d / 2 - 0.04), Vector3(x + 0.28, y + 0.06, c.d / 2 - 0.035), "screen",
				[Color("#4cff7a"), Color("#4cff7a"), Color("#ffb04c"), Color("#4cc3ff")][(_h(c, i * 13 + k)) % 4], 16)


static func _bench(b: MeshBatch, c: Dictionary) -> void:
	var w: float = c.w - 0.1
	for k in 3:
		b.box(Vector3(-w / 2, 0.42, -0.2 + k * 0.14), Vector3(w / 2, 0.46, -0.1 + k * 0.14), "wood", WOOD)
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * (w / 2 - 0.1) - 0.03, 0, -0.22), Vector3(sx * (w / 2 - 0.1) + 0.03, 0.42, 0.2), "metal", DARK)


static func _shelter_bench(b: MeshBatch, c: Dictionary) -> void:
	_bench(b, c)


static func _ashtray(b: MeshBatch, c: Dictionary) -> void:
	b.cylinder(Vector3.ZERO, 0.14, 0.14, 0.85, "metal", Color("#6d6d6d"), 10)
	b.cylinder(Vector3(0, 0.85, 0), 0.17, 0.17, 0.05, "metal", Color("#8a8a8a"), 10)


static func _toilet(b: MeshBatch, c: Dictionary) -> void:
	b.box(Vector3(-0.2, 0.0, -0.45), Vector3(0.2, 0.75, -0.28), "matte", WHITE)  # cistern
	b.cylinder(Vector3(0, 0, -0.05), 0.14, 0.2, 0.4, "matte", WHITE, 10)
	b.cylinder(Vector3(0, 0.4, -0.05), 0.21, 0.21, 0.04, "matte", Color("#f7f5f0"), 10)


static func _sink(b: MeshBatch, c: Dictionary) -> void:
	b.box(Vector3(-0.3, 0.78, -0.48), Vector3(0.3, 0.9, -0.05), "matte", WHITE)
	b.box(Vector3(-0.22, 0.86, -0.4), Vector3(0.22, 0.9, -0.12), "metal", Color("#cdd6dc"))
	b.block(0, -0.4, 0.04, 0.12, 0.9, 0.12, "metal", STEEL)
	b.box(Vector3(-0.28, 1.15, -0.5), Vector3(0.28, 1.65, -0.48), "metal", Color("#cfe3ee"), 16)  # mirror


static func _urinal(b: MeshBatch, c: Dictionary) -> void:
	b.box(Vector3(-0.18, 0.45, -0.48), Vector3(0.18, 1.05, -0.25), "matte", WHITE)


static func _car(b: MeshBatch, c: Dictionary) -> void:
	# along the long side of the tile block
	var long_x: bool = c.w >= c.d
	var keep := b.xf
	if not long_x:
		b.xf = keep * Transform3D(Basis(Vector3.UP, PI / 2), Vector3.ZERO)
	var L: float = maxf(c.w, c.d) - 0.3
	var W: float = minf(c.w, c.d) - 0.25
	var col: Color = CAR_COLORS[_h(c, 3) % CAR_COLORS.size()]
	b.box(Vector3(-L / 2, 0.22, -W / 2), Vector3(L / 2, 0.75, W / 2), "metal", col)
	b.box(Vector3(-L / 2 + 0.7, 0.75, -W / 2 + 0.08), Vector3(L / 2 - 0.9, 1.25, W / 2 - 0.08), "glass", Color(0.12, 0.16, 0.22, 0.85))
	b.box(Vector3(-L / 2 + 0.75, 1.25, -W / 2 + 0.12), Vector3(L / 2 - 0.95, 1.3, W / 2 - 0.12), "metal", col)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var keep2 := b.xf
			b.xf = b.xf * Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(sx * (L / 2 - 0.55), 0.3, sz * (W / 2 - 0.05)))
			b.cylinder(Vector3(0, -0.1, 0), 0.3, 0.3, 0.2, "matte", Color("#1c1c1f"), 10)
			b.xf = keep2
	b.box(Vector3(L / 2 - 0.02, 0.5, -W / 2 + 0.1), Vector3(L / 2, 0.62, -W / 2 + 0.35), "screen", Color("#fff3c4"), 1)
	b.box(Vector3(L / 2 - 0.02, 0.5, W / 2 - 0.35), Vector3(L / 2, 0.62, W / 2 - 0.1), "screen", Color("#fff3c4"), 1)
	b.xf = keep


static func _coffee_machine(b: MeshBatch, c: Dictionary) -> void:
	_kitchen_counter(b, c)
	b.box(Vector3(-0.22, 0.94, -0.4), Vector3(0.22, 1.5, 0.05), "metal", Color("#2b2c30"))
	b.box(Vector3(-0.15, 1.3, 0.05), Vector3(0.15, 1.42, 0.06), "screen", Color("#7fd8ff"), 16)
	b.cylinder(Vector3(0, 0.94, -0.0), 0.04, 0.045, 0.1, "matte", WHITE, 7)


static func _kitchen_counter(b: MeshBatch, c: Dictionary) -> void:
	b.box(Vector3(-c.w / 2, 0, -c.d / 2), Vector3(c.w / 2, 0.88, c.d / 2 - 0.05), "matte", Color("#e9e4da"))
	b.box(Vector3(-c.w / 2, 0.88, -c.d / 2), Vector3(c.w / 2, 0.94, c.d / 2), "wood", Color("#8a6a4a"))
	var n := maxi(1, int(round(c.w)))
	for i in n:
		var x: float = -c.w / 2 + 0.5 + i
		b.box(Vector3(x - 0.08, 0.7, c.d / 2 - 0.05), Vector3(x + 0.08, 0.72, c.d / 2 - 0.02), "metal", STEEL, 16)


static func _kitchen_sink(b: MeshBatch, c: Dictionary) -> void:
	_kitchen_counter(b, c)
	b.box(Vector3(-0.3, 0.9, -0.3), Vector3(0.3, 0.95, 0.25), "metal", Color("#c3ccd2"))
	b.block(0, -0.35, 0.04, 0.04, 0.94, 0.3, "metal", STEEL)


static func _cupboard(b: MeshBatch, c: Dictionary) -> void:
	_kitchen_counter(b, c)
	b.box(Vector3(-c.w / 2, 1.45, -c.d / 2), Vector3(c.w / 2, 2.15, -c.d / 2 + 0.35), "matte", Color("#f1ece2"))


static func _dishwasher(b: MeshBatch, c: Dictionary) -> void:
	_kitchen_counter(b, c)
	b.box(Vector3(-0.42, 0.08, c.d / 2 - 0.05), Vector3(0.42, 0.85, c.d / 2 - 0.02), "metal", Color("#c3ccd2"), 16)


static func _fridge(b: MeshBatch, c: Dictionary) -> void:
	b.box(Vector3(-0.42, 0, -c.d / 2 + 0.05), Vector3(0.42, 1.95, c.d / 2 - 0.05), "metal", Color("#dfe4e8"))
	b.box(Vector3(0.3, 0.9, c.d / 2 - 0.05), Vector3(0.34, 1.4, c.d / 2), "metal", STEEL, 16 | 1 | 2)


static func _fruit_bowl(b: MeshBatch, c: Dictionary) -> void:
	_kitchen_counter(b, c)
	b.cylinder(Vector3(0, 0.94, 0), 0.12, 0.2, 0.08, "matte", WHITE, 10)
	for i in 5:
		var a := TAU * i / 5.0
		b.sphere(Vector3(cos(a) * 0.09, 1.04, sin(a) * 0.09), 0.055, "matte", [Color("#e84a3a"), Color("#f2c230"), Color("#7ab648"), Color("#f08a24")][i % 4], Vector3.ONE, 3, 6)


static func _partition(b: MeshBatch, c: Dictionary) -> void:
	# toilet cubicle walls: thin panels across the tile row
	b.box(Vector3(-c.w / 2, 0.15, -0.03), Vector3(c.w / 2, 2.0, 0.03), "matte", Color("#9fb3c8"), 63)


static func _sanitizer(b: MeshBatch, c: Dictionary) -> void:
	b.block(0, -0.3, 0.06, 0.06, 0, 1.0, "metal", STEEL)
	b.box(Vector3(-0.1, 1.0, -0.38), Vector3(0.1, 1.3, -0.22), "matte", WHITE)
	b.box(Vector3(-0.06, 1.12, -0.22), Vector3(0.06, 1.22, -0.21), "screen", Color("#7fd8a8"), 16)


static func _bike_rack(b: MeshBatch, c: Dictionary) -> void:
	var n := maxi(2, int(round(c.w * 2)))
	for i in n:
		var x: float = -c.w / 2 + (i + 0.5) * c.w / n
		b.box(Vector3(x - 0.02, 0, -0.3), Vector3(x + 0.02, 0.7, -0.26), "metal", STEEL, 63)
		b.box(Vector3(x - 0.02, 0, 0.26), Vector3(x + 0.02, 0.7, 0.3), "metal", STEEL, 63)
		b.box(Vector3(x - 0.02, 0.66, -0.3), Vector3(x + 0.02, 0.7, 0.3), "metal", STEEL, 63)


static func _wardrobe(b: MeshBatch, c: Dictionary) -> void:
	b.box(Vector3(-c.w / 2 + 0.03, 0, -c.d / 2 + 0.05), Vector3(c.w / 2 - 0.03, 2.1, c.d / 2 - 0.1), "wood", Color("#8a6040"))
	var n := maxi(1, int(round(c.w)))
	for i in n:
		var x: float = -c.w / 2 + 0.5 + i
		b.box(Vector3(x - 0.03, 0.95, c.d / 2 - 0.1), Vector3(x + 0.03, 1.25, c.d / 2 - 0.07), "metal", STEEL, 16)


static func _bin(b: MeshBatch, c: Dictionary) -> void:
	b.cylinder(Vector3.ZERO, 0.17, 0.2, 0.5, "matte", Color("#4f5560"), 10)


static func _trash_bin(b: MeshBatch, c: Dictionary) -> void:
	b.box(Vector3(-0.25, 0, -0.3), Vector3(0.25, 0.75, 0.2), "matte", Color("#3d6b4a"))
	b.box(Vector3(-0.27, 0.75, -0.32), Vector3(0.27, 0.8, 0.22), "matte", Color("#2f5439"))


static func _tv(b: MeshBatch, c: Dictionary) -> void:
	# a low cabinet with a big screen (the picture itself: tv_view port)
	b.box(Vector3(-c.w / 2 + 0.1, 0, -c.d / 2 + 0.05), Vector3(c.w / 2 - 0.1, 0.5, c.d / 2 - 0.2), "wood", WOOD_DARK)
	b.box(Vector3(-c.w / 2 + 0.15, 0.75, -0.08), Vector3(c.w / 2 - 0.15, 1.6, -0.02), "matte", Color("#121317"))
	b.box(Vector3(-c.w / 2 + 0.2, 0.8, -0.02), Vector3(c.w / 2 - 0.2, 1.55, -0.015), "screen", Color("#1d2a3a"), 16)
	b.block(0, -0.06, 0.1, 0.06, 0.5, 0.25, "metal", DARK)


static func _medicine_cabinet(b: MeshBatch, c: Dictionary) -> void:
	b.box(Vector3(-0.3, 1.1, -c.d / 2), Vector3(0.3, 1.7, -c.d / 2 + 0.2), "matte", WHITE)
	b.box(Vector3(-0.05, 1.3, -c.d / 2 + 0.2), Vector3(0.05, 1.5, -c.d / 2 + 0.21), "matte", Color("#2fa84f"), 16)
	b.box(Vector3(-0.1, 1.35, -c.d / 2 + 0.2), Vector3(0.1, 1.45, -c.d / 2 + 0.21), "matte", Color("#2fa84f"), 16)


static func _key_hook(b: MeshBatch, c: Dictionary) -> void:
	b.box(Vector3(-0.2, 1.3, -c.d / 2), Vector3(0.2, 1.55, -c.d / 2 + 0.04), "wood", WOOD)
	b.box(Vector3(-0.02, 1.32, -c.d / 2 + 0.04), Vector3(0.02, 1.4, -c.d / 2 + 0.06), "metal", Color("#e0b84a"), 63)


static func _liquor_cabinet(b: MeshBatch, c: Dictionary) -> void:
	b.box(Vector3(-c.w / 2 + 0.05, 0, -c.d / 2 + 0.05), Vector3(c.w / 2 - 0.05, 1.1, c.d / 2 - 0.15), "wood", Color("#5a3a26"))
	for i in 5:
		var x := -0.3 + i * 0.15
		b.cylinder(Vector3(x, 1.1, -0.1), 0.04, 0.04, 0.22 + (i % 2) * 0.06, "glass", [Color(0.5, 0.25, 0.1, 0.85), Color(0.2, 0.45, 0.2, 0.85), Color(0.85, 0.85, 0.9, 0.7)][i % 3], 6)


# ------------------------------------------------------------- outdoors

static func _tree(b: MeshBatch, c: Dictionary) -> void:
	var s := 0.8 + float(_h(c, 9) % 5) * 0.12
	b.cylinder(Vector3.ZERO, 0.14 * s, 0.1 * s, 1.6 * s, "wood", Color("#6b4a33"), 6)
	var g := Color("#4f8a3c").lerp(Color("#7aa646"), float(_h(c, 2) % 5) / 5.0)
	b.sphere(Vector3(0, 2.2 * s, 0), 1.0 * s, "leaf", g, Vector3(1, 0.9, 1), 4, 7)
	b.sphere(Vector3(0.35 * s, 2.8 * s, 0.1 * s), 0.65 * s, "leaf", g.lightened(0.08), Vector3.ONE, 4, 7)
	b.sphere(Vector3(-0.4 * s, 2.5 * s, -0.2 * s), 0.6 * s, "leaf", g.darkened(0.08), Vector3.ONE, 4, 7)


static func _street_lamp(b: MeshBatch, c: Dictionary) -> void:
	b.cylinder(Vector3.ZERO, 0.07, 0.05, 3.6, "metal", Color("#2d3138"), 6)
	b.box(Vector3(-0.05, 3.55, -0.05), Vector3(0.05, 3.6, 0.6), "metal", Color("#2d3138"))
	b.box(Vector3(-0.12, 3.45, 0.4), Vector3(0.12, 3.55, 0.75), "screen", Color("#ffe2a8"), 8 | 4 | 1 | 2 | 16 | 32)
