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
##
## Shapes come from art/shapes.gd (chamfered boxes, lathed pots, tubes,
## leaves); materials are the keys of materials.gd + art/art_materials.gd
## (wood / fabric / metal / ceramic / plastic / chrome / rubber ... each a
## subtle procedural texture). Colours vary a little per instance (S.vary).
extends RefCounted

const MeshBatch = preload("res://world3d/mesh_batch.gd")
const S = preload("res://world3d/art/shapes.gd")

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

const WOOD := Color("#c49a6c")
const WOOD_LIGHT := Color("#dcc19a")
const WOOD_DARK := Color("#6e4c31")
const WALNUT := Color("#7a5236")
const WHITE := Color("#f1ede4")
const PORCELAIN := Color("#f7f6f2")
const STEEL := Color("#a9b0b8")
const CHROME := Color("#d8dee3")
const BRASS := Color("#c8a040")
const DARK := Color("#2e2f36")
const CHARCOAL := Color("#3a3c44")
const RUBBER := Color("#1f2024")
const SCREENS := [Color("#7fc4ef"), Color("#92e0a0"), Color("#f2d27a"), Color("#c8a8f0"), Color("#8fd8e0")]
const FABRICS := [Color("#5b7fa8"), Color("#c46a4f"), Color("#6f9a62"), Color("#d4a24c"), Color("#8a6aa8"), Color("#4f8a8b")]
const CHAIRS := [Color("#2f3138"), Color("#3d4f6b"), Color("#5a3d3d"), Color("#3e5a4a")]
const CAR_COLORS := [Color("#c0392b"), Color("#2e5fa8"), Color("#ecf0f1"), Color("#2c2f36"), Color("#27ae60"), Color("#8e44ad"), Color("#e6a23c"), Color("#9aa3ab")]
const GOODS := [Color("#e84a3a"), Color("#f2c230"), Color("#3b82c4"), Color("#7ab648"), Color("#f08a24"), Color("#e8e2d6"),
	Color("#c0508a"), Color("#4fb3b0"), Color("#8a5a3a"), Color("#f4f1ea")]
const MUGS := [Color("#e85d4a"), Color("#f4f1ea"), Color("#3b82c4"), Color("#f2c230"), Color("#5aa86a")]


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


## Move the batch's origin (returns the old transform to restore).
static func _at(b: MeshBatch, x: float, z: float, yaw := 0.0, y := 0.0) -> Transform3D:
	var keep := b.xf
	b.xf = keep * Transform3D(Basis(Vector3.UP, yaw), Vector3(x, y, z))
	return keep


# ----------------------------------------------------------------- fallback

static func _fallback(b: MeshBatch, c: Dictionary) -> void:
	S.rblock(b, 0, 0, c.w * 0.9, c.d * 0.9, 0, 0.8, 0.04, "matte", c.color)


# ------------------------------------------------------------- small things

## Office chair (seat facing -z, backrest at +z): five-star base on
## casters, gas lift, padded seat and back, armrests.
static func _chair(b: MeshBatch, x: float, z: float, yaw: float, col: Color) -> void:
	var keep := _at(b, x, z, yaw)
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		var tip := Vector3(cos(a) * 0.27, 0.07, sin(a) * 0.27)
		S.tube(b, Vector3(0, 0.1, 0), tip, 0.022, "plastic", RUBBER, 4)
		b.sphere(tip + Vector3(0, -0.035, 0), 0.035, "rubber", RUBBER, Vector3.ONE, 2, 5)
	S.lathe(b, Vector3(0, 0.08, 0), [Vector2(0.05, 0), Vector2(0.035, 0.06), Vector2(0.028, 0.08), Vector2(0.028, 0.34)], "chrome", CHROME, 8, false)
	S.rbox(b, Vector3(-0.1, 0.37, -0.1), Vector3(0.1, 0.42, 0.12), 0.01, "plastic", RUBBER)
	S.rbox(b, Vector3(-0.25, 0.41, -0.24), Vector3(0.25, 0.5, 0.22), 0.04, "fabric", col)
	# back: spine + padded shell, a little reclined
	S.rbox(b, Vector3(-0.04, 0.42, 0.18), Vector3(0.04, 0.6, 0.24), 0.015, "plastic", RUBBER)
	var k2 := b.xf
	b.xf = b.xf * Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0, 0.56, 0.24))
	S.rbox(b, Vector3(-0.23, 0.0, -0.04), Vector3(0.23, 0.48, 0.035), 0.035, "fabric", col)
	S.rbox(b, Vector3(-0.21, 0.02, 0.035), Vector3(0.21, 0.46, 0.05), 0.02, "plastic", RUBBER)
	b.xf = k2
	for sx in [-1.0, 1.0]:
		S.tube(b, Vector3(sx * 0.24, 0.47, 0.06), Vector3(sx * 0.25, 0.66, 0.06), 0.015, "plastic", RUBBER, 4)
		S.rbox(b, Vector3(sx * 0.25 - 0.035, 0.65, -0.1), Vector3(sx * 0.25 + 0.035, 0.69, 0.14), 0.015, "plastic", CHARCOAL)
	b.xf = keep


## A wooden chair for dining tables (seat facing -z).
static func _wood_chair(b: MeshBatch, x: float, z: float, yaw: float, col: Color, wood: Color) -> void:
	var keep := _at(b, x, z, yaw)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			S.tube(b, Vector3(sx * 0.18, 0, sz * 0.17), Vector3(sx * 0.19, 0.44, sz * 0.18), 0.02, "wood", wood, 5)
	S.rbox(b, Vector3(-0.22, 0.42, -0.21), Vector3(0.22, 0.47, 0.21), 0.015, "wood", wood)
	S.rbox(b, Vector3(-0.19, 0.47, -0.18), Vector3(0.19, 0.51, 0.17), 0.02, "fabric", col)
	for sx in [-1.0, 1.0]:
		S.tube(b, Vector3(sx * 0.19, 0.47, 0.19), Vector3(sx * 0.19, 0.88, 0.22), 0.018, "wood", wood, 5)
	S.rbox(b, Vector3(-0.21, 0.7, 0.18), Vector3(0.21, 0.88, 0.235), 0.02, "wood", wood)
	b.xf = keep


static func _mug(b: MeshBatch, p: Vector3, col: Color) -> void:
	S.lathe(b, p, [Vector2(0.032, 0), Vector2(0.038, 0.004), Vector2(0.04, 0.09)], "ceramic", col, 9, true, Color("#3a2418"))
	S.tube(b, p + Vector3(0.04, 0.025, 0), p + Vector3(0.04, 0.07, 0), 0.012, "ceramic", col, 4)


## Monitor on a stand, screen facing +z; its foot at local (x, y, z).
static func _monitor(b: MeshBatch, x: float, y: float, z: float, scr: Color, wide := 0.56) -> void:
	S.rbox(b, Vector3(x - 0.12, y, z - 0.08), Vector3(x + 0.12, y + 0.015, z + 0.08), 0.006, "metal", Color("#bfc5cc"))
	S.rbox(b, Vector3(x - 0.025, y, z - 0.05), Vector3(x + 0.025, y + 0.26, z - 0.02), 0.01, "metal", Color("#bfc5cc"))
	var y0 := y + 0.16
	S.rbox(b, Vector3(x - wide / 2, y0, z - 0.03), Vector3(x + wide / 2, y0 + wide * 0.58, z + 0.0), 0.012, "plastic", Color("#1d1e23"))
	b.box(Vector3(x - wide / 2 + 0.018, y0 + 0.03, z), Vector3(x + wide / 2 - 0.018, y0 + wide * 0.58 - 0.014, z + 0.004), "screen", scr, 16)


static func _keyboard(b: MeshBatch, x: float, y: float, z: float) -> void:
	S.rbox(b, Vector3(x - 0.21, y, z - 0.07), Vector3(x + 0.21, y + 0.022, z + 0.07), 0.008, "plastic", Color("#2c2e35"), Color("#4a4d57"))
	b.sphere(Vector3(x + 0.3, y + 0.012, z + 0.01), 0.032, "plastic", Color("#2c2e35"), Vector3(0.8, 0.45, 1.2), 2, 6)


static func _papers(b: MeshBatch, x: float, y: float, z: float, n: int) -> void:
	for i in n:
		var keep := _at(b, x, z, 0.15 * (i - n / 2.0), y + i * 0.006)
		b.box(Vector3(-0.1, 0, -0.14), Vector3(0.1, 0.005, 0.14), "matte", WHITE.darkened(0.02 * i), 63 & ~8)
		b.xf = keep


static func _book_row(b: MeshBatch, x0: float, x1: float, y: float, z0: float, z1: float, seed: int) -> void:
	var x := x0
	var i := 0
	while x < x1 - 0.03:
		var w := 0.03 + float(absi(hash(seed + i)) % 4) * 0.012
		var hh := 0.18 + float(absi(hash(seed * 3 + i)) % 5) * 0.025
		if x + w > x1:
			break
		var col: Color = GOODS[absi(hash(seed * 7 + i)) % GOODS.size()].darkened(0.15)
		if absi(hash(seed + i * 11)) % 9 == 0 and x + hh * 0.4 + w < x1:
			# a leaning book
			var keep := _at(b, x + 0.02, (z0 + z1) / 2, 0.0, y)
			b.xf = b.xf * Transform3D(Basis(Vector3.BACK, -0.35), Vector3.ZERO)
			b.box(Vector3(0, 0, z0 - (z0 + z1) / 2), Vector3(w, hh, z1 - (z0 + z1) / 2), "matte", col)
			b.xf = keep
			x += hh * 0.4 + w
		else:
			b.box(Vector3(x, y, z0), Vector3(x + w, y + hh, z1), "matte", col)
			x += w + 0.004
		i += 1


# ------------------------------------------------------------- office

static func _desk(b: MeshBatch, c: Dictionary) -> void:
	var w: float = c.w - 0.06
	var d: float = c.d * 0.78
	var z0: float = -c.d / 2 + 0.03
	var dept: bool = c.room_type == "department"
	var top := S.vary(WOOD_LIGHT if dept else WOOD, _h(c, 4), 0.04)
	var frame := Color("#4a4c54")
	S.rbox(b, Vector3(-w / 2, 0.72, z0), Vector3(w / 2, 0.76, z0 + d), 0.012, "wood", top)
	# trestle legs at the ends and between every two seats, modesty panel
	var legs := [-w / 2 + 0.06, w / 2 - 0.06]
	var n := int(round(c.w))
	for i in range(2, n, 2):
		legs.append(-c.w / 2 + i)
	for lx in legs:
		for lz in [z0 + 0.08, z0 + d - 0.08]:
			S.rbox(b, Vector3(lx - 0.025, 0, lz - 0.025), Vector3(lx + 0.025, 0.72, lz + 0.025), 0.008, "metal", frame)
		S.rbox(b, Vector3(lx - 0.025, 0.66, z0 + 0.06), Vector3(lx + 0.025, 0.71, z0 + d - 0.06), 0.008, "metal", frame)
		S.rbox(b, Vector3(lx - 0.03, 0, z0 + 0.04), Vector3(lx + 0.03, 0.03, z0 + d - 0.04), 0.008, "metal", frame)
	S.rbox(b, Vector3(-w / 2 + 0.08, 0.3, z0 + 0.04), Vector3(w / 2 - 0.08, 0.7, z0 + 0.06), 0.006, "matte", Color("#6a6e78"))
	for i in n:
		var x: float = -c.w / 2 + 0.5 + i
		var hs := _h(c, i)
		if dept or (hs % 3 != 0):
			var sc: Color = SCREENS[(hs / 5) % SCREENS.size()]
			_monitor(b, x, 0.76, z0 + 0.16, sc)
			if hs % 4 == 0 and dept:
				# a second, smaller screen turned in a little
				var keep := _at(b, x - 0.38, z0 + 0.2, 0.35)
				_monitor(b, 0, 0.76, 0, SCREENS[(hs / 7) % SCREENS.size()], 0.4)
				b.xf = keep
			_keyboard(b, x, 0.76, z0 + 0.46)
		if hs % 3 == 0:
			_mug(b, Vector3(x + 0.36, 0.76, z0 + 0.32), MUGS[hs % MUGS.size()])
		if hs % 5 == 1:
			_papers(b, x - 0.32, 0.76, z0 + 0.4, 1 + hs % 3)
		if hs % 7 == 2:
			# a little succulent
			var sp := Vector3(x - 0.36, 0.76, z0 + 0.14)
			S.lathe(b, sp, [Vector2(0.04, 0), Vector2(0.05, 0.08)], "ceramic", MUGS[(hs / 3) % MUGS.size()], 7, true, Color("#4a3426"))
			for k in 6:
				var a := TAU * k / 6.0
				S.leaf(b, sp + Vector3(0, 0.08, 0), sp + Vector3(cos(a) * 0.08, 0.15, sin(a) * 0.08), 0.04, "leaf", Color("#5f9a54"))
		if hs % 11 == 3:
			# desk lamp
			var lp := Vector3(x + 0.4, 0.76, z0 + 0.1)
			S.lathe(b, lp, [Vector2(0.07, 0), Vector2(0.07, 0.015), Vector2(0.02, 0.025)], "metal", DARK, 8, true)
			S.tube(b, lp + Vector3(0, 0.02, 0), lp + Vector3(-0.02, 0.33, 0.05), 0.01, "metal", DARK, 4)
			S.tube(b, lp + Vector3(-0.02, 0.33, 0.05), lp + Vector3(-0.12, 0.3, 0.16), 0.01, "metal", DARK, 4)
			S.lathe(b, lp + Vector3(-0.12, 0.22, 0.16), [Vector2(0.07, 0), Vector2(0.03, 0.08), Vector2(0.0, 0.09)], "metal", DARK, 8, false)
			S.disc(b, lp + Vector3(-0.12, 0.225, 0.16), 0.055, "screen", Color("#fff1c4"), 8, true)
		# chair on the free side, each pushed / turned a little differently
		var cc: Color = S.vary(CHAIRS[_h(c, 1) % CHAIRS.size()], hs, 0.03)
		var turn := (float(hs % 7) - 3.0) * 0.06
		_chair(b, x + (float(hs % 5) - 2.0) * 0.03, c.d / 2 + 0.25 + float(hs % 3) * 0.04, turn, cc)


static func _table(b: MeshBatch, c: Dictionary) -> void:
	var w: float = c.w - 0.1
	var d: float = c.d - 0.1
	var round_top: bool = c.w <= 2.01 and c.d <= 2.01 and c.w == c.d
	var top := S.vary(WOOD if c.index % 2 == 0 else Color("#e8e2d6"), _h(c, 2), 0.04)
	var office: bool = c.room_type in ["meeting", "board", "department"]
	if round_top:
		S.lathe(b, Vector3(0, 0.71, 0), [Vector2(w / 2 - 0.02, 0), Vector2(w / 2, 0.015), Vector2(w / 2, 0.045), Vector2(w / 2 - 0.015, 0.06)], "wood", top, 20, true)
		S.lathe(b, Vector3.ZERO, [Vector2(0.28, 0), Vector2(0.28, 0.02), Vector2(0.1, 0.05), Vector2(0.04, 0.1), Vector2(0.04, 0.71)], "metal", DARK, 12, false)
	else:
		S.rbox(b, Vector3(-w / 2, 0.71, -d / 2), Vector3(w / 2, 0.77, d / 2), 0.02, "wood", top)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				S.tube(b, Vector3(sx * (w / 2 - 0.12), 0, sz * (d / 2 - 0.12)), Vector3(sx * (w / 2 - 0.08), 0.71, sz * (d / 2 - 0.08)), 0.03, "metal", DARK, 6)
		if c.room_type in ["meeting", "board"]:
			# a cable box and a carafe
			S.rbox(b, Vector3(-0.12, 0.77, -0.05), Vector3(0.12, 0.8, 0.05), 0.01, "metal", Color("#5a5e66"))
			S.lathe(b, Vector3(0.4, 0.77, 0), [Vector2(0.05, 0), Vector2(0.06, 0.1), Vector2(0.03, 0.2), Vector2(0.03, 0.24)], "glass", Color(0.8, 0.9, 0.95, 0.5), 8, false)
	var ty := 0.77 if not round_top else 0.77
	if c.room_type in ["kitchen", "common", "canteen", "chill"]:
		# a vase with flowers and a napkin holder
		S.lathe(b, Vector3(0, ty, 0), [Vector2(0.04, 0), Vector2(0.06, 0.08), Vector2(0.03, 0.18), Vector2(0.035, 0.2)], "ceramic", MUGS[_h(c, 7) % MUGS.size()], 8, true)
		for k in 5:
			var a := TAU * k / 5.0 + 0.4
			var tip := Vector3(cos(a) * 0.08, ty + 0.32 + (k % 2) * 0.05, sin(a) * 0.08)
			S.tube(b, Vector3(0, ty + 0.18, 0), tip, 0.006, "leaf", Color("#4f8a3c"), 3)
			b.sphere(tip, 0.035, "plastic", [Color("#f2c230"), Color("#e85d4a"), Color("#f4f1ea"), Color("#c0508a"), Color("#f08a24")][k], Vector3(1, 0.6, 1), 2, 6)
		if not round_top and c.w > 1.5:
			S.rbox(b, Vector3(0.35, ty, -0.04), Vector3(0.47, ty + 0.1, 0.04), 0.01, "chrome", CHROME)
	elif c.room_type in ["meeting", "board"] and not round_top:
		# notepads and pens in front of a few seats
		for i in maxi(1, int(c.w)):
			if _h(c, i + 40) % 2 == 0:
				var x: float = -c.w / 2 + 0.5 + i
				var zz: float = (d / 2 - 0.22) * (1.0 if i % 2 == 0 else -1.0)
				b.box(Vector3(x - 0.1, ty, zz - 0.14), Vector3(x + 0.1, ty + 0.01, zz + 0.14), "matte", Color("#f6f1d8"), 63 & ~8)
				S.tube(b, Vector3(x + 0.13, ty + 0.008, zz - 0.1), Vector3(x + 0.14, ty + 0.008, zz + 0.06), 0.006, "plastic", Color("#2f6fb0"), 4)
	# chairs around (meeting / dining tables)
	if c.room_type in ["meeting", "kitchen", "common", "board", "canteen", "chill", "department"] or c.w * c.d >= 4:
		var col: Color = FABRICS[c.index % FABRICS.size()]
		var nx := maxi(1, int(c.w))
		for i in nx:
			var x: float = -c.w / 2 + 0.5 + i
			for side in [-1.0, 1.0]:
				if not _free(c, x, side * (c.d / 2 + 0.5)):
					continue
				var j := float(_h(c, i * 3 + int(side + 1)))
				var dz: float = side * (c.d / 2 + 0.28 + fmod(j, 7.0) * 0.015)
				var yaw: float = (PI if side < 0 else 0.0) + (fmod(j, 5.0) - 2.0) * 0.05
				if office:
					_chair(b, x, dz, yaw, col.darkened(0.2))
				else:
					_wood_chair(b, x, dz, yaw, col, WOOD_DARK if c.index % 2 == 0 else WOOD)


## Reception / shop counter: wooden front with slats, a stone top with an
## overhang towards the customers, a screen and bits on the staff side.
static func _counter(b: MeshBatch, c: Dictionary) -> void:
	var w: float = c.w
	var d: float = c.d
	var keep0 := b.xf
	if d > w * 1.5:
		# a long counter seen end-on: turn it so its length runs along x
		b.xf = b.xf * Transform3D(Basis(Vector3.UP, PI / 2), Vector3.ZERO)
		w = c.d
		d = c.w
	var body := S.vary(Color("#c9a37a"), _h(c), 0.03)
	b.box(Vector3(-w / 2 + 0.04, 0, -d / 2 + 0.1), Vector3(w / 2 - 0.04, 0.08, d / 2 - 0.08), "matte", DARK)
	S.rbox(b, Vector3(-w / 2, 0.06, -d / 2 + 0.05), Vector3(w / 2, 1.0, d / 2 - 0.05), 0.02, "wood", body)
	# vertical slats on the customer side (+z)
	var n := int(w / 0.12)
	for i in n:
		var x := -w / 2 + 0.06 + i * (w - 0.12) / maxf(1, n - 1)
		S.rbox(b, Vector3(x - 0.035, 0.1, d / 2 - 0.05), Vector3(x + 0.035, 0.96, d / 2 - 0.01), 0.012, "wood", body.darkened(0.12 if i % 2 else 0.05))
	S.rbox(b, Vector3(-w / 2 - 0.03, 1.0, -d / 2), Vector3(w / 2 + 0.03, 1.05, d / 2 + 0.08), 0.015, "ceramic", Color("#ece6da"))
	# staff side: a monitor, a bell, papers and a mug
	_monitor(b, -w / 4, 1.05, -d / 2 + 0.2, SCREENS[_h(c) % SCREENS.size()], 0.42)
	S.lathe(b, Vector3(w / 4, 1.05, 0.05), [Vector2(0.05, 0), Vector2(0.05, 0.01), Vector2(0.035, 0.04), Vector2(0.0, 0.06)], "chrome", BRASS, 8, false)
	if w > 1.5 or d > 1.5:
		_papers(b, w / 4 - 0.25, 1.05, -0.05, 2)
		_mug(b, Vector3(-w / 4 + 0.35, 1.05, -d / 2 + 0.25), MUGS[_h(c, 5) % MUGS.size()])
	if w > 2.5:
		# a desk phone and a small plant
		S.rbox(b, Vector3(-w / 4 - 0.55, 1.05, -0.1), Vector3(-w / 4 - 0.35, 1.1, 0.06), 0.015, "plastic", CHARCOAL)
		S.lathe(b, Vector3(w / 2 - 0.3, 1.05, -0.05), [Vector2(0.06, 0), Vector2(0.08, 0.12)], "ceramic", WHITE, 8, true, Color("#4a3426"))
		for k in 7:
			var a := TAU * k / 7.0
			S.leaf(b, Vector3(w / 2 - 0.3, 1.15, -0.05), Vector3(w / 2 - 0.3 + cos(a) * 0.16, 1.32, -0.05 + sin(a) * 0.16), 0.08, "leaf", Color("#4f9a44"), 0.06)
	b.xf = keep0


## Shelves (shop gondolas / book shelves): side uprights, back panel,
## shelves stocked with goods (boxes, bottles, cans) or books.
static func _shelf(b: MeshBatch, c: Dictionary) -> void:
	var h := 1.9
	var w: float = c.w - 0.05
	var d: float = minf(c.d, 0.6)
	var z0: float = -c.d / 2 + 0.02
	var shop: bool = c.room_type == "shop"
	var frame := Color("#6e737c") if shop else S.vary(WALNUT, _h(c), 0.05)
	var mat := "metal" if shop else "wood"
	S.rbox(b, Vector3(-w / 2, 0, z0), Vector3(w / 2, h, z0 + 0.03), 0.005, "matte", Color("#d9d6cf") if shop else frame.darkened(0.15))
	for sx in [-1.0, 1.0]:
		S.rbox(b, Vector3(sx * w / 2 - (0.04 if sx > 0 else 0.0), 0, z0), Vector3(sx * w / 2 + (0.0 if sx > 0 else 0.04), h, z0 + d), 0.01, mat, frame)
	S.rbox(b, Vector3(-w / 2, h - 0.06, z0), Vector3(w / 2, h, z0 + 0.06), 0.01, mat, frame)
	b.box(Vector3(-w / 2 + 0.04, 0, z0 + 0.03), Vector3(w / 2 - 0.04, 0.1, z0 + d - 0.02), "matte", frame.darkened(0.3))
	for k in 5:
		var y := 0.1 + k * 0.38
		S.rbox(b, Vector3(-w / 2 + 0.03, y, z0), Vector3(w / 2 - 0.03, y + 0.03, z0 + d), 0.008, mat, frame.lightened(0.1))
		if shop:
			# price strip
			b.box(Vector3(-w / 2 + 0.04, y - 0.01, z0 + d), Vector3(w / 2 - 0.04, y + 0.03, z0 + d + 0.005), "matte", Color("#f6f3ea"), 16)
			_goods_row(b, -w / 2 + 0.06, w / 2 - 0.06, y + 0.03, z0 + 0.05, z0 + d - 0.04, _h(c, k * 31))
		else:
			_book_row(b, -w / 2 + 0.06, w / 2 - 0.06, y + 0.03, z0 + 0.06, z0 + d - 0.12, _h(c, k * 31))


## A stocked shop shelf: runs of identical products (boxes, bottles, cans).
static func _goods_row(b: MeshBatch, x0: float, x1: float, y: float, z0: float, z1: float, seed: int) -> void:
	var x := x0
	var g := 0
	while x < x1 - 0.1:
		var hs := absi(hash(seed + g * 101))
		var col: Color = GOODS[hs % GOODS.size()]
		var kind := (hs / 7) % 3
		var cnt := 2 + (hs / 13) % 4
		var zc := (z0 + z1) / 2
		for i in cnt:
			if kind == 0:  # boxes
				var bw := 0.1 + float((hs / 3) % 3) * 0.03
				var bh := 0.2 + float((hs / 5) % 3) * 0.05
				if x + bw > x1:
					break
				b.box(Vector3(x, y, z0 + 0.02), Vector3(x + bw, y + bh, z1), "matte", col, 63 & ~8, col.lightened(0.15))
				b.box(Vector3(x + 0.015, y + bh * 0.45, z1), Vector3(x + bw - 0.015, y + bh * 0.75, z1 + 0.002), "matte", WHITE, 16)
				x += bw + 0.01
			elif kind == 1:  # bottles
				if x + 0.08 > x1:
					break
				S.lathe(b, Vector3(x + 0.04, y, zc), [Vector2(0.035, 0), Vector2(0.035, 0.18), Vector2(0.014, 0.25), Vector2(0.014, 0.29)], "plastic", col, 6, true, WHITE)
				x += 0.085
			else:  # cans, two deep
				if x + 0.075 > x1:
					break
				for zz in [zc - 0.1, zc + 0.08]:
					S.lathe(b, Vector3(x + 0.035, y, zz), [Vector2(0.033, 0), Vector2(0.033, 0.12)], "metal", col, 7, true, CHROME)
				x += 0.075
		x += 0.03
		g += 1


static func _sofa(b: MeshBatch, c: Dictionary) -> void:
	var col: Color = S.vary(FABRICS[(c.index + 1) % FABRICS.size()], _h(c), 0.04)
	var w: float = c.w - 0.1
	var d: float = c.d - 0.1
	S.rbox(b, Vector3(-w / 2, 0.08, -d / 2), Vector3(w / 2, 0.38, d / 2 - 0.02), 0.05, "fabric", col.darkened(0.1))
	S.rbox(b, Vector3(-w / 2, 0.3, -d / 2), Vector3(w / 2, 0.86, -d / 2 + 0.2), 0.07, "fabric", col.darkened(0.06))
	for sx in [-1.0, 1.0]:
		S.rbox(b, Vector3(sx * w / 2 - (0.2 if sx > 0 else 0.0), 0.08, -d / 2), Vector3(sx * w / 2 + (0.0 if sx > 0 else 0.2), 0.64, d / 2), 0.08, "fabric", col.darkened(0.04))
	# seat and back cushions
	var n := maxi(1, int(round((w - 0.4) / 0.8)))
	var cw := (w - 0.4) / n
	for i in n:
		var x0 := -w / 2 + 0.2 + i * cw + 0.01
		var x1 := x0 + cw - 0.02
		S.rbox(b, Vector3(x0, 0.36, -d / 2 + 0.2), Vector3(x1, 0.5, d / 2 - 0.01), 0.06, "fabric", col.lightened(0.05))
		var keep := b.xf
		b.xf = b.xf * Transform3D(Basis(Vector3.RIGHT, -0.18), Vector3(0, 0.48, -d / 2 + 0.22))
		S.rbox(b, Vector3(x0, 0, -0.07), Vector3(x1, 0.4, 0.09), 0.07, "fabric", col.lightened(0.02))
		b.xf = keep
	# a throw pillow in a contrasting colour
	if _h(c, 3) % 2 == 0:
		var pc: Color = FABRICS[(c.index + 3) % FABRICS.size()].lightened(0.15)
		var keep := _at(b, -w / 2 + 0.36, -d / 2 + 0.36, 0.3, 0.5)
		b.xf = b.xf * Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3.ZERO)
		S.rbox(b, Vector3(-0.17, 0, -0.06), Vector3(0.17, 0.32, 0.06), 0.05, "fabric", pc)
		b.xf = keep
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			S.lathe(b, Vector3(sx * (w / 2 - 0.1), 0, sz * (d / 2 - 0.1)), [Vector2(0.02, 0), Vector2(0.03, 0.08)], "wood", WOOD_DARK, 6)


static func _armchair(b: MeshBatch, c: Dictionary) -> void:
	var col := S.vary(Color("#8a4a5a"), _h(c), 0.05)
	S.rbox(b, Vector3(-0.38, 0.1, -0.38), Vector3(0.38, 0.38, 0.36), 0.05, "fabric", col.darkened(0.1))
	S.rbox(b, Vector3(-0.38, 0.3, -0.4), Vector3(0.38, 0.92, -0.2), 0.08, "fabric", col.darkened(0.04))
	for sx in [-1.0, 1.0]:
		S.rbox(b, Vector3(sx * 0.38 - (0.14 if sx > 0 else 0.0), 0.1, -0.4), Vector3(sx * 0.38 + (0.0 if sx > 0 else 0.14), 0.64, 0.36), 0.06, "fabric", col)
	S.rbox(b, Vector3(-0.25, 0.36, -0.22), Vector3(0.25, 0.5, 0.36), 0.06, "fabric", col.lightened(0.06))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			S.lathe(b, Vector3(sx * 0.3, 0, sz * 0.3), [Vector2(0.02, 0), Vector2(0.03, 0.1)], "wood", WOOD_DARK, 6)


## Potted plants in four kinds, the pot / leaves varying.
static func _plant(b: MeshBatch, c: Dictionary) -> void:
	var hs := _h(c, 1)
	var pots := [Color("#c9714a"), Color("#ece6da"), Color("#3a3b40"), Color("#7d9aa8"), Color("#d8b48a")]
	var pi: int = (c.index + hs) % pots.size()
	var pot: Color = pots[pi]
	S.lathe(b, Vector3.ZERO, [Vector2(0.15, 0), Vector2(0.17, 0.02), Vector2(0.22, 0.38), Vector2(0.245, 0.4), Vector2(0.245, 0.45), Vector2(0.22, 0.45)],
		"matte" if pi == 0 else "ceramic", pot, 12, false)
	S.disc(b, Vector3(0, 0.42, 0), 0.22, "matte", Color("#4a3426"), 12)
	var green := S.vary(Color("#3f8a3a").lerp(Color("#6aa84f"), float(hs % 4) / 4.0), hs, 0.05)
	match (c.index + hs / 3) % 4:
		0:  # leafy bush: rings of leaves
			for ring in 3:
				var nl := 9 - ring * 2
				for i in nl:
					var a := TAU * (i + ring * 0.5) / nl + float(hs % 10) * 0.1
					var r := 0.38 - ring * 0.1
					var y0 := 0.48 + ring * 0.14
					S.leaf(b, Vector3(0, y0, 0), Vector3(cos(a) * r, y0 + 0.35 + ring * 0.12, sin(a) * r), 0.16, "leaf",
						green.lightened(0.05 * ring), 0.12)
		1:  # ficus: a trunk and clouds of leaves
			S.tube(b, Vector3(0, 0.42, 0), Vector3(0.03, 1.0, 0.0), 0.025, "wood", WOOD_DARK, 5)
			S.tube(b, Vector3(0.03, 0.9, 0), Vector3(-0.12, 1.15, 0.06), 0.015, "wood", WOOD_DARK, 4)
			var cl := [[Vector3(0.03, 1.38, 0), 0.3], [Vector3(-0.16, 1.16, 0.08), 0.2], [Vector3(0.14, 1.12, -0.06), 0.2]]
			for k in 3:
				b.sphere(cl[k][0], cl[k][1], "leaf", green.darkened(0.05 * k), Vector3(1, 0.85, 1), 3, 7)
		2:  # snake plant: tall blades
			for i in 9:
				var a := TAU * i / 9.0 + float(hs % 7)
				var r := 0.05 + float(i % 3) * 0.03
				var base := Vector3(cos(a) * r, 0.43, sin(a) * r)
				var top := Vector3(cos(a) * r * 1.6, 0.98 + float((i * 7 + hs) % 4) * 0.1, sin(a) * r * 1.6)
				S.leaf(b, base, top, 0.09, "leaf", green.lerp(Color("#b8c95a"), 0.2 * (i % 2)), 0.0)
		_:  # monstera: big leaves on stems
			for i in 7:
				var a := TAU * i / 7.0 + float(hs % 5)
				var stem_top := Vector3(cos(a) * 0.25, 0.85 + float(i % 3) * 0.12, sin(a) * 0.25)
				S.tube(b, Vector3(0, 0.42, 0), stem_top, 0.01, "leaf", green.darkened(0.15), 3)
				S.leaf(b, stem_top, stem_top + Vector3(cos(a) * 0.3, 0.05, sin(a) * 0.3), 0.3, "leaf", green.darkened(0.08), 0.12)


## Server racks: one per tile, blinking LEDs, a handle, cables on top.
static func _rack(b: MeshBatch, c: Dictionary) -> void:
	var n := int(round(c.w))
	for i in n:
		var x: float = -c.w / 2 + 0.5 + i
		S.rbox(b, Vector3(x - 0.45, 0, -c.d / 2 + 0.05), Vector3(x + 0.45, 2.0, c.d / 2 - 0.06), 0.02, "metal", Color("#23252b"))
		b.box(Vector3(x - 0.4, 0.08, c.d / 2 - 0.06), Vector3(x + 0.4, 1.94, c.d / 2 - 0.05), "matte", Color("#15161a"), 16)
		for k in 12:
			var y := 0.15 + k * 0.145
			b.box(Vector3(x - 0.38, y, c.d / 2 - 0.05), Vector3(x + 0.38, y + 0.1, c.d / 2 - 0.04), "metal", Color("#3a3d46") if k % 3 else Color("#4a4e58"), 16 | 4)
			var led: Color = [Color("#4cff7a"), Color("#4cff7a"), Color("#ffb04c"), Color("#4cc3ff")][(_h(c, i * 13 + k)) % 4]
			b.box(Vector3(x + 0.24, y + 0.035, c.d / 2 - 0.04), Vector3(x + 0.27, y + 0.06, c.d / 2 - 0.035), "screen", led, 16)
			if k % 2 == 0:
				b.box(Vector3(x + 0.19, y + 0.035, c.d / 2 - 0.04), Vector3(x + 0.21, y + 0.06, c.d / 2 - 0.035), "screen", Color("#4cff7a"), 16)
		S.rbox(b, Vector3(x - 0.04, 0.8, c.d / 2 - 0.04), Vector3(x - 0.02, 1.2, c.d / 2 - 0.0), 0.005, "chrome", CHROME)
	b.box(Vector3(-c.w / 2 + 0.1, 2.0, -0.12), Vector3(c.w / 2 - 0.1, 2.06, 0.12), "metal", Color("#8a9099"))
	var cables := [Color("#2f6fb0"), Color("#e8c03a"), Color("#d23b2e"), Color("#5aa86a"), Color("#2f3138")]
	for k in 5:
		S.tube(b, Vector3(-c.w / 2 + 0.15, 2.07, -0.08 + k * 0.04), Vector3(c.w / 2 - 0.15, 2.07, -0.08 + k * 0.04), 0.012, "rubber", cables[k], 4)


static func _bench(b: MeshBatch, c: Dictionary) -> void:
	var w: float = c.w - 0.1
	var wood := S.vary(WOOD, _h(c), 0.05)
	var outdoor: bool = c.room_type in ["", "outside", "smoking", "parking"]
	for k in 4:
		S.rbox(b, Vector3(-w / 2, 0.42, -0.22 + k * 0.11), Vector3(w / 2, 0.46, -0.13 + k * 0.11), 0.01, "wood", wood.darkened(0.03 * (k % 2)))
	if outdoor:
		for k in 2:
			var keep := b.xf
			b.xf = b.xf * Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 0.6 + k * 0.14, -0.26))
			S.rbox(b, Vector3(-w / 2, 0, -0.02), Vector3(w / 2, 0.1, 0.02), 0.01, "wood", wood)
			b.xf = keep
	for sx in [-1.0, 1.0]:
		var x: float = sx * (w / 2 - 0.12)
		S.rbox(b, Vector3(x - 0.03, 0, -0.24), Vector3(x + 0.03, 0.42, -0.18), 0.01, "metal", DARK)
		S.rbox(b, Vector3(x - 0.03, 0, 0.16), Vector3(x + 0.03, 0.42, 0.22), 0.01, "metal", DARK)
		S.rbox(b, Vector3(x - 0.03, 0.36, -0.24), Vector3(x + 0.03, 0.42, 0.22), 0.01, "metal", DARK)
		if outdoor:
			S.tube(b, Vector3(x, 0.4, -0.22), Vector3(x, 0.92, -0.36), 0.025, "metal", DARK, 5)


static func _shelter_bench(b: MeshBatch, c: Dictionary) -> void:
	var w: float = c.w - 0.1
	var keep := b.xf
	if c.d > c.w:
		b.xf = b.xf * Transform3D(Basis(Vector3.UP, PI / 2), Vector3.ZERO)
		w = c.d - 0.1
	for k in 3:
		S.rbox(b, Vector3(-w / 2, 0.42, -0.2 + k * 0.13), Vector3(w / 2, 0.46, -0.1 + k * 0.13), 0.01, "wood", Color("#9a7550"))
	for sx in [-1.0, 1.0]:
		var x: float = sx * (w / 2 - 0.15)
		S.rbox(b, Vector3(x - 0.03, 0, -0.04), Vector3(x + 0.03, 0.42, 0.04), 0.01, "metal", Color("#5d666d"))
		S.rbox(b, Vector3(x - 0.03, 0.38, -0.22), Vector3(x + 0.03, 0.42, 0.2), 0.01, "metal", Color("#5d666d"))
	b.xf = keep


static func _ashtray(b: MeshBatch, c: Dictionary) -> void:
	S.lathe(b, Vector3.ZERO, [Vector2(0.17, 0), Vector2(0.17, 0.03), Vector2(0.14, 0.05), Vector2(0.14, 0.82), Vector2(0.17, 0.86), Vector2(0.17, 0.9)], "metal", Color("#6d7178"), 12, true, Color("#d8cfb4"))
	for i in 4:
		var a := float(i) * 1.7 + float(_h(c) % 5)
		S.tube(b, Vector3(cos(a) * 0.06, 0.91, sin(a) * 0.06), Vector3(cos(a) * 0.1, 0.915, sin(a) * 0.1), 0.006, "matte", Color("#f2ead6"), 3)


# ------------------------------------------------------------- bathroom

static func _toilet(b: MeshBatch, c: Dictionary) -> void:
	S.rbox(b, Vector3(-0.2, 0.42, -0.48), Vector3(0.2, 0.8, -0.3), 0.04, "ceramic", PORCELAIN)  # cistern
	S.rbox(b, Vector3(-0.06, 0.8, -0.42), Vector3(0.06, 0.81, -0.36), 0.004, "chrome", CHROME)
	var keep := b.xf
	b.xf = b.xf * Transform3D(Basis.from_scale(Vector3(1, 1, 1.3)), Vector3(0, 0, -0.06))
	S.lathe(b, Vector3.ZERO, [Vector2(0.12, 0), Vector2(0.13, 0.15), Vector2(0.17, 0.32), Vector2(0.19, 0.4)], "ceramic", PORCELAIN, 14, false)
	S.lathe(b, Vector3(0, 0.4, 0), [Vector2(0.2, 0), Vector2(0.2, 0.03), Vector2(0.13, 0.035), Vector2(0.11, 0.02)], "plastic", WHITE, 14, true, Color("#bcd8e0"))
	b.xf = keep
	S.rbox(b, Vector3(-0.16, 0.42, -0.31), Vector3(0.16, 0.46, -0.26), 0.01, "plastic", WHITE)


static func _sink(b: MeshBatch, c: Dictionary) -> void:
	# a vanity top with an oval basin, a tap, a mirror with a light strip
	S.rbox(b, Vector3(-0.32, 0.8, -0.5), Vector3(0.32, 0.88, -0.06), 0.02, "ceramic", PORCELAIN)
	var keep := b.xf
	b.xf = b.xf * Transform3D(Basis.from_scale(Vector3(1.3, 1, 1)), Vector3(0, 0.88, -0.26))
	S.disc(b, Vector3(0, 0.002, 0), 0.16, "ceramic", Color("#d6e0e4"), 14)
	b.xf = keep
	S.lathe(b, Vector3(0, 0.4, -0.45), [Vector2(0.05, 0), Vector2(0.04, 0.4)], "ceramic", PORCELAIN, 8, false)
	S.tube(b, Vector3(0, 0.88, -0.45), Vector3(0, 1.05, -0.45), 0.018, "chrome", CHROME, 6)
	S.tube(b, Vector3(0, 1.04, -0.45), Vector3(0, 1.02, -0.33), 0.015, "chrome", CHROME, 6)
	S.rbox(b, Vector3(-0.05, 1.05, -0.47), Vector3(0.05, 1.07, -0.42), 0.005, "chrome", CHROME)
	S.rbox(b, Vector3(-0.3, 1.15, -0.505), Vector3(0.3, 1.72, -0.48), 0.01, "metal", Color("#8a9099"))
	b.box(Vector3(-0.28, 1.17, -0.48), Vector3(0.28, 1.7, -0.475), "chrome", Color("#cfe3ee"), 16)
	b.box(Vector3(-0.26, 1.74, -0.5), Vector3(0.26, 1.77, -0.45), "screen", Color("#fff6de"), 16 | 8)
	S.lathe(b, Vector3(0.22, 0.88, -0.42), [Vector2(0.03, 0), Vector2(0.03, 0.1), Vector2(0.01, 0.13)], "plastic", Color("#8fd0c0"), 6, true)


static func _urinal(b: MeshBatch, c: Dictionary) -> void:
	S.rbox(b, Vector3(-0.18, 0.42, -0.48), Vector3(0.18, 1.08, -0.24), 0.08, "ceramic", PORCELAIN)
	b.box(Vector3(-0.12, 0.5, -0.24), Vector3(0.12, 0.95, -0.23), "ceramic", Color("#dfe7ea"), 16)
	S.tube(b, Vector3(0, 1.08, -0.42), Vector3(0, 1.35, -0.42), 0.015, "chrome", CHROME, 6)
	S.rbox(b, Vector3(-0.05, 1.3, -0.48), Vector3(0.05, 1.4, -0.43), 0.01, "chrome", CHROME)


static func _partition(b: MeshBatch, c: Dictionary) -> void:
	# toilet cubicle walls: laminate panels on chrome feet, a top rail
	S.rbox(b, Vector3(-c.w / 2, 0.15, -0.03), Vector3(c.w / 2, 2.0, 0.03), 0.012, "plastic", Color("#9fb3c8"), Color(0, 0, 0, 0), true)
	for x in [-c.w / 2 + 0.1, c.w / 2 - 0.1]:
		S.tube(b, Vector3(x, 0, 0), Vector3(x, 0.16, 0), 0.02, "chrome", CHROME, 6)
	S.rbox(b, Vector3(-c.w / 2, 2.0, -0.025), Vector3(c.w / 2, 2.04, 0.025), 0.008, "chrome", CHROME)


static func _sanitizer(b: MeshBatch, c: Dictionary) -> void:
	S.lathe(b, Vector3(0, 0, -0.3), [Vector2(0.15, 0), Vector2(0.15, 0.02), Vector2(0.03, 0.03), Vector2(0.025, 1.0)], "metal", STEEL, 10, false)
	S.rbox(b, Vector3(-0.1, 1.0, -0.38), Vector3(0.1, 1.32, -0.22), 0.025, "plastic", WHITE)
	b.box(Vector3(-0.06, 1.14, -0.22), Vector3(0.06, 1.24, -0.215), "screen", Color("#7fd8a8"), 16)
	S.rbox(b, Vector3(-0.03, 0.97, -0.26), Vector3(0.03, 1.0, -0.2), 0.006, "plastic", Color("#3a8a6a"))


static func _medicine_cabinet(b: MeshBatch, c: Dictionary) -> void:
	var zf: float = -c.d / 2 + 0.18
	S.rbox(b, Vector3(-0.3, 1.1, -c.d / 2), Vector3(0.3, 1.72, zf), 0.02, "plastic", WHITE)
	b.box(Vector3(-0.005, 1.1, zf), Vector3(0.005, 1.72, zf + 0.005), "matte", Color("#cfcac0"), 16)
	b.box(Vector3(-0.05, 1.3, zf), Vector3(0.05, 1.54, zf + 0.01), "matte", Color("#2fa84f"), 16 | 4 | 8 | 1 | 2)
	b.box(Vector3(-0.12, 1.37, zf), Vector3(0.12, 1.47, zf + 0.01), "matte", Color("#2fa84f"), 16 | 4 | 8 | 1 | 2)
	S.rbox(b, Vector3(0.22, 1.35, zf), Vector3(0.24, 1.47, zf + 0.03), 0.005, "chrome", CHROME)


static func _key_hook(b: MeshBatch, c: Dictionary) -> void:
	var z0: float = -c.d / 2
	S.rbox(b, Vector3(-0.22, 1.3, z0), Vector3(0.22, 1.56, z0 + 0.03), 0.008, "wood", WOOD)
	for i in 4:
		var x := -0.15 + i * 0.1
		S.tube(b, Vector3(x, 1.4, z0 + 0.03), Vector3(x, 1.42, z0 + 0.07), 0.006, "chrome", BRASS, 4)
	S.rbox(b, Vector3(-0.07, 1.3, z0 + 0.04), Vector3(-0.03, 1.39, z0 + 0.05), 0.004, "chrome", Color("#e0b84a"))
	b.box(Vector3(-0.08, 1.22, z0 + 0.04), Vector3(-0.02, 1.3, z0 + 0.05), "plastic", Color("#d23b2e"), 63)


static func _liquor_cabinet(b: MeshBatch, c: Dictionary) -> void:
	var wood := Color("#5a3a26")
	var w: float = c.w - 0.1
	S.rbox(b, Vector3(-w / 2, 0.06, -c.d / 2 + 0.05), Vector3(w / 2, 1.1, c.d / 2 - 0.15), 0.02, "wood", wood)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			S.lathe(b, Vector3(sx * (w / 2 - 0.06), 0, sz * (c.d / 2 - 0.25)), [Vector2(0.025, 0), Vector2(0.03, 0.07)], "wood", wood.darkened(0.2), 6)
	# glass doors with bottles behind
	var zf: float = c.d / 2 - 0.15
	var bottles := [Color(0.5, 0.25, 0.1, 0.9), Color(0.2, 0.45, 0.2, 0.9), Color(0.85, 0.85, 0.9, 0.7)]
	for i in 6:
		var x := -w / 2 + 0.12 + i * (w - 0.24) / 5.0
		S.lathe(b, Vector3(x, 0.53, zf - 0.15), [Vector2(0.035, 0), Vector2(0.035, 0.2), Vector2(0.012, 0.27), Vector2(0.012, 0.32)], "glass", bottles[i % 3], 7, true, BRASS)
	b.box(Vector3(-w / 2 + 0.04, 0.5, zf - 0.32), Vector3(w / 2 - 0.04, 0.53, zf - 0.02), "wood", wood.lightened(0.1))
	b.box(Vector3(-w / 2 + 0.04, 0.5, zf), Vector3(w / 2 - 0.04, 1.04, zf + 0.01), "glass", Color(0.75, 0.85, 0.9, 0.25), 16)
	b.box(Vector3(-0.01, 0.5, zf), Vector3(0.01, 1.04, zf + 0.02), "wood", wood, 16 | 4)
	b.sphere(Vector3(0.05, 0.76, zf + 0.02), 0.015, "chrome", BRASS, Vector3.ONE, 2, 5)
	# a decanter and glasses on top
	S.lathe(b, Vector3(-0.2, 1.1, -0.05), [Vector2(0.06, 0), Vector2(0.08, 0.08), Vector2(0.025, 0.2), Vector2(0.03, 0.26)], "glass", Color(0.7, 0.4, 0.15, 0.8), 8, true)
	for i in 2:
		S.lathe(b, Vector3(0.05 + i * 0.1, 1.1, 0.0), [Vector2(0.03, 0), Vector2(0.035, 0.08)], "glass", Color(0.9, 0.95, 1.0, 0.4), 7, false)


# ------------------------------------------------------------- kitchen

## Base cabinets: plinth, doors with handles, a worktop, a tiled backsplash.
static func _kitchen_counter(b: MeshBatch, c: Dictionary) -> void:
	var w: float = c.w
	var d: float = c.d
	var front := S.vary(Color("#e9e4da"), _h(c, 6), 0.02)
	b.box(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, 0.1, d / 2 - 0.1), "matte", Color("#3a3c44"))
	S.rbox(b, Vector3(-w / 2, 0.1, -d / 2), Vector3(w / 2, 0.88, d / 2 - 0.06), 0.006, "plastic", front.darkened(0.04))
	var n := maxi(1, int(round(w / 0.5)))
	var dw := w / n
	for i in n:
		var x0 := -w / 2 + i * dw + 0.005
		S.rbox(b, Vector3(x0, 0.12, d / 2 - 0.07), Vector3(x0 + dw - 0.01, 0.86, d / 2 - 0.04), 0.008, "plastic", front)
		var hx := x0 + (dw - 0.06 if i % 2 == 0 else 0.06)
		S.rbox(b, Vector3(hx - 0.008, 0.6, d / 2 - 0.04), Vector3(hx + 0.008, 0.78, d / 2 - 0.02), 0.004, "chrome", CHROME)
	S.rbox(b, Vector3(-w / 2, 0.88, -d / 2), Vector3(w / 2, 0.93, d / 2), 0.008, "wood", S.vary(Color("#8a6a4a"), _h(c, 8), 0.03))
	b.box(Vector3(-w / 2, 0.93, -d / 2), Vector3(w / 2, 1.45, -d / 2 + 0.015), "ceramic", Color("#dfe9ea"), 16 | 4)


static func _coffee_machine(b: MeshBatch, c: Dictionary) -> void:
	_kitchen_counter(b, c)
	var y := 0.93
	S.rbox(b, Vector3(-0.22, y, -0.42), Vector3(0.22, y + 0.5, 0.08), 0.03, "metal", Color("#2b2c30"))
	S.rbox(b, Vector3(-0.2, y + 0.5, -0.4), Vector3(0.2, y + 0.53, 0.06), 0.01, "chrome", CHROME)
	b.box(Vector3(-0.15, y + 0.33, 0.08), Vector3(0.15, y + 0.44, 0.085), "screen", Color("#7fd8ff"), 16)
	# brew head, drip tray, a cup under it
	S.rbox(b, Vector3(-0.08, y + 0.2, 0.0), Vector3(0.08, y + 0.27, 0.16), 0.015, "chrome", CHROME)
	S.rbox(b, Vector3(-0.17, y, 0.0), Vector3(0.17, y + 0.03, 0.2), 0.01, "chrome", Color("#9aa0a8"))
	_mug(b, Vector3(0, y + 0.03, 0.1), WHITE)
	# bean hopper
	S.lathe(b, Vector3(0.1, y + 0.53, -0.2), [Vector2(0.05, 0), Vector2(0.08, 0.14), Vector2(0.08, 0.16)], "glass", Color(0.35, 0.2, 0.1, 0.85), 8, true, DARK)
	# a stack of cups and a sugar jar beside
	if c.w > 1.2:
		for i in 3:
			S.lathe(b, Vector3(-0.4, y + i * 0.07, -0.1), [Vector2(0.035, 0), Vector2(0.045, 0.07)], "ceramic", WHITE, 8, false)
		S.lathe(b, Vector3(0.42, y, -0.15), [Vector2(0.05, 0), Vector2(0.05, 0.12), Vector2(0.03, 0.14)], "glass", Color(0.95, 0.95, 0.95, 0.7), 8, true, CHROME)


static func _kitchen_sink(b: MeshBatch, c: Dictionary) -> void:
	_kitchen_counter(b, c)
	S.rbox(b, Vector3(-0.32, 0.925, -0.28), Vector3(0.32, 0.94, 0.26), 0.01, "chrome", Color("#c3ccd2"))
	b.box(Vector3(-0.27, 0.938, -0.22), Vector3(0.27, 0.941, 0.21), "metal", Color("#6f777e"), 4)
	S.tube(b, Vector3(0, 0.93, -0.36), Vector3(0, 1.25, -0.36), 0.018, "chrome", CHROME, 6)
	S.tube(b, Vector3(0, 1.25, -0.36), Vector3(0, 1.22, -0.18), 0.016, "chrome", CHROME, 6)
	S.rbox(b, Vector3(0.06, 0.93, -0.4), Vector3(0.1, 1.02, -0.34), 0.006, "chrome", CHROME)
	if c.w > 1.4:
		# a drying rack with a plate
		S.rbox(b, Vector3(0.45, 0.93, -0.3), Vector3(0.8, 0.95, 0.1), 0.006, "chrome", CHROME)
		var keep := _at(b, 0.62, -0.1, 0.0, 1.05)
		b.xf = b.xf * Transform3D(Basis(Vector3.RIGHT, PI / 2 - 0.3), Vector3.ZERO)
		S.lathe(b, Vector3.ZERO, [Vector2(0.0, 0), Vector2(0.09, 0.005), Vector2(0.12, 0.02)], "ceramic", WHITE, 12, false)
		b.xf = keep


static func _cupboard(b: MeshBatch, c: Dictionary) -> void:
	_kitchen_counter(b, c)
	var w: float = c.w
	var d: float = c.d
	var col := S.vary(Color("#f1ece2"), _h(c, 2), 0.02)
	S.rbox(b, Vector3(-w / 2, 1.45, -d / 2), Vector3(w / 2, 2.15, -d / 2 + 0.35), 0.01, "plastic", col.darkened(0.04))
	var n := maxi(1, int(round(w / 0.5)))
	var dw := w / n
	for i in n:
		var x0 := -w / 2 + i * dw + 0.005
		S.rbox(b, Vector3(x0, 1.46, -d / 2 + 0.35), Vector3(x0 + dw - 0.01, 2.14, -d / 2 + 0.37), 0.008, "plastic", col)
		var hx := x0 + (dw - 0.06 if i % 2 == 0 else 0.06)
		S.rbox(b, Vector3(hx - 0.008, 1.5, -d / 2 + 0.37), Vector3(hx + 0.008, 1.66, -d / 2 + 0.39), 0.004, "chrome", CHROME)
	b.box(Vector3(-w / 2 + 0.05, 1.43, -d / 2 + 0.2), Vector3(w / 2 - 0.05, 1.45, -d / 2 + 0.3), "screen", Color("#fff4dc"), 8)
	var lids := [WOOD, CHROME, Color("#d23b2e")]
	for i in mini(3, int(w / 0.3)):
		S.lathe(b, Vector3(-w / 2 + 0.15 + i * 0.13, 0.93, -d / 2 + 0.12), [Vector2(0.05, 0), Vector2(0.05, 0.15 - i * 0.02)], "glass",
			Color(0.9, 0.85, 0.75, 0.75), 8, true, lids[i])


static func _dishwasher(b: MeshBatch, c: Dictionary) -> void:
	_kitchen_counter(b, c)
	S.rbox(b, Vector3(-0.3, 0.1, c.d / 2 - 0.07), Vector3(0.3, 0.87, c.d / 2 - 0.02), 0.01, "metal", Color("#c3ccd2"))
	S.rbox(b, Vector3(-0.22, 0.76, c.d / 2 - 0.02), Vector3(0.22, 0.79, c.d / 2 + 0.01), 0.006, "chrome", CHROME)
	b.box(Vector3(0.12, 0.81, c.d / 2 - 0.02), Vector3(0.26, 0.84, c.d / 2 - 0.015), "screen", Color("#7fd8ff"), 16)


static func _fridge(b: MeshBatch, c: Dictionary) -> void:
	var col := S.vary(Color("#dfe4e8"), _h(c), 0.02)
	var z1: float = c.d / 2 - 0.05
	S.rbox(b, Vector3(-0.42, 0.02, -c.d / 2 + 0.05), Vector3(0.42, 1.98, z1 - 0.02), 0.04, "plastic", col.darkened(0.06))
	S.rbox(b, Vector3(-0.41, 0.04, z1 - 0.04), Vector3(0.41, 1.22, z1), 0.02, "plastic", col)
	S.rbox(b, Vector3(-0.41, 1.25, z1 - 0.04), Vector3(0.41, 1.96, z1), 0.02, "plastic", col)
	for y in [[0.75, 1.15], [1.3, 1.6]]:
		S.rbox(b, Vector3(0.31, y[0], z1), Vector3(0.34, y[1], z1 + 0.04), 0.01, "chrome", CHROME)
	# magnets and a note
	var hs := _h(c, 3)
	for i in 4:
		var p := Vector3(-0.3 + float((hs / (i + 1)) % 40) / 100.0, 1.35 + float((hs / (i + 3)) % 45) / 100.0, z1)
		b.box(p, p + Vector3(0.05, 0.05, 0.012), "plastic", GOODS[(hs + i) % GOODS.size()], 63 & ~8)
	var keep := _at(b, -0.12, z1 + 0.002, 0.0, 1.45)
	b.xf = b.xf * Transform3D(Basis(Vector3.BACK, 0.08), Vector3.ZERO)
	b.box(Vector3(-0.08, -0.1, 0), Vector3(0.08, 0.1, 0.003), "matte", Color("#fff6b0"), 16)
	b.xf = keep


static func _fruit_bowl(b: MeshBatch, c: Dictionary) -> void:
	_kitchen_counter(b, c)
	S.lathe(b, Vector3(0, 0.93, 0), [Vector2(0.06, 0), Vector2(0.14, 0.03), Vector2(0.2, 0.08), Vector2(0.19, 0.085)], "ceramic", Color("#4f8a8b"), 12, true, Color("#e9e0cc"))
	var cols := [Color("#e84a3a"), Color("#f2c230"), Color("#7ab648"), Color("#f08a24"), Color("#e84a3a"), Color("#c8d84a")]
	for i in 6:
		var a := TAU * i / 6.0
		b.sphere(Vector3(cos(a) * 0.1, 1.04 + (i % 2) * 0.03, sin(a) * 0.1), 0.05, "plastic", cols[i], Vector3.ONE, 3, 6)
	b.sphere(Vector3(0, 1.1, 0), 0.05, "plastic", Color("#f08a24"), Vector3.ONE, 3, 6)
	S.tube(b, Vector3(-0.12, 1.08, 0.02), Vector3(0.0, 1.13, 0.06), 0.022, "plastic", Color("#f2d13a"), 5)
	S.tube(b, Vector3(0.0, 1.13, 0.06), Vector3(0.11, 1.1, 0.0), 0.022, "plastic", Color("#f2d13a"), 5)


# ------------------------------------------------------------- misc rooms

static func _bike_rack(b: MeshBatch, c: Dictionary) -> void:
	# a row of "Sheffield" hoops
	var n := maxi(2, int(round(c.w * 1.5)))
	for i in n:
		var x: float = -c.w / 2 + (i + 0.5) * c.w / n
		var pts := [Vector3(x, 0, -0.3)]
		for k in 9:
			var a := PI * k / 8.0
			pts.append(Vector3(x, 0.5 + sin(a) * 0.3, -cos(a) * 0.3))
		pts.append(Vector3(x, 0, 0.3))
		for k in pts.size() - 1:
			S.tube(b, pts[k], pts[k + 1], 0.025, "metal", Color("#5d6870"), 6)


static func _wardrobe(b: MeshBatch, c: Dictionary) -> void:
	var wood := S.vary(Color("#8a6040"), _h(c), 0.04)
	var z1: float = c.d / 2 - 0.1
	S.rbox(b, Vector3(-c.w / 2 + 0.03, 0.06, -c.d / 2 + 0.05), Vector3(c.w / 2 - 0.03, 2.1, z1 - 0.02), 0.015, "wood", wood.darkened(0.08))
	b.box(Vector3(-c.w / 2 + 0.06, 0, -c.d / 2 + 0.08), Vector3(c.w / 2 - 0.06, 0.06, z1 - 0.05), "matte", DARK)
	S.rbox(b, Vector3(-c.w / 2, 2.1, -c.d / 2 + 0.03), Vector3(c.w / 2, 2.16, z1 + 0.01), 0.012, "wood", wood.darkened(0.15))
	var n := maxi(2, int(round(c.w * 2)))
	var dw: float = (c.w - 0.08) / n
	for i in n:
		var x0: float = -c.w / 2 + 0.04 + i * dw + 0.004
		S.rbox(b, Vector3(x0, 0.08, z1 - 0.03), Vector3(x0 + dw - 0.008, 2.08, z1), 0.01, "wood", wood)
		var hx := x0 + (dw - 0.05 if i % 2 == 0 else 0.05)
		S.rbox(b, Vector3(hx - 0.01, 0.95, z1), Vector3(hx + 0.01, 1.25, z1 + 0.025), 0.004, "chrome", BRASS)


static func _bin(b: MeshBatch, c: Dictionary) -> void:
	S.lathe(b, Vector3.ZERO, [Vector2(0.14, 0), Vector2(0.19, 0.45), Vector2(0.2, 0.47), Vector2(0.18, 0.47)], "plastic", S.vary(Color("#4f5560"), _h(c), 0.05), 12, false)
	S.disc(b, Vector3(0, 0.03, 0), 0.14, "plastic", Color("#2a2d33"), 12)
	if _h(c, 2) % 2 == 0:
		b.sphere(Vector3(0.03, 0.42, 0.02), 0.07, "matte", WHITE, Vector3(1, 0.8, 1), 2, 5)


static func _trash_bin(b: MeshBatch, c: Dictionary) -> void:
	# a wheelie bin: body, a lid with a lip, wheels at the back
	var col := S.vary(Color("#3d6b4a"), _h(c), 0.05)
	S.rbox(b, Vector3(-0.24, 0.05, -0.3), Vector3(0.24, 0.8, 0.22), 0.04, "plastic", col)
	S.rbox(b, Vector3(-0.27, 0.8, -0.34), Vector3(0.27, 0.86, 0.26), 0.02, "plastic", col.darkened(0.2))
	S.rbox(b, Vector3(-0.2, 0.76, -0.38), Vector3(0.2, 0.8, -0.3), 0.01, "plastic", col.darkened(0.2))
	for sx in [-1.0, 1.0]:
		var keep := _at(b, sx * 0.2, -0.28, 0.0, 0.08)
		b.xf = b.xf * Transform3D(Basis(Vector3.BACK, PI / 2), Vector3.ZERO)
		b.cylinder(Vector3(0, -0.04, 0), 0.08, 0.08, 0.08, "rubber", RUBBER, 8)
		b.xf = keep
	b.box(Vector3(-0.15, 0.45, 0.22), Vector3(0.15, 0.6, 0.225), "matte", Color("#f4f1ea"), 16)


## TV furniture: a low media console with doors, a slim TV on a stand (the
## picture itself: tv_view port), a soundbar and a small plant.
static func _tv(b: MeshBatch, c: Dictionary) -> void:
	var wood := S.vary(WOOD_DARK, _h(c), 0.05)
	var x0: float = -c.w / 2 + 0.1
	var x1: float = c.w / 2 - 0.1
	var zb: float = -c.d / 2 + 0.05
	var zf: float = c.d / 2 - 0.2
	S.rbox(b, Vector3(x0, 0.12, zb), Vector3(x1, 0.5, zf), 0.015, "wood", wood)
	for sx in [-1.0, 1.0]:
		for zz in [zf - 0.08, zb + 0.08]:
			S.tube(b, Vector3(sx * (c.w / 2 - 0.2), 0, zz), Vector3(sx * (c.w / 2 - 0.18), 0.13, zz), 0.02, "metal", DARK, 5)
	var n := maxi(2, int(round((x1 - x0) / 0.45)))
	var dw := (x1 - x0) / n
	for i in n:
		var a := x0 + i * dw + 0.01
		S.rbox(b, Vector3(a, 0.15, zf), Vector3(a + dw - 0.02, 0.47, zf + 0.02), 0.008, "wood", wood.lightened(0.06 if i % 2 else 0.02))
		S.rbox(b, Vector3(a + dw / 2 - 0.06, 0.42, zf + 0.02), Vector3(a + dw / 2 + 0.06, 0.43, zf + 0.035), 0.003, "chrome", BRASS)
	# the TV
	S.rbox(b, Vector3(-c.w / 2 + 0.15, 0.75, -0.08), Vector3(c.w / 2 - 0.15, 1.6, -0.02), 0.015, "plastic", Color("#121317"))
	b.box(Vector3(-c.w / 2 + 0.2, 0.8, -0.02), Vector3(c.w / 2 - 0.2, 1.55, -0.015), "screen", Color("#1d2a3a"), 16)
	S.rbox(b, Vector3(-0.05, 0.5, -0.09), Vector3(0.05, 0.78, -0.05), 0.01, "metal", DARK)
	S.rbox(b, Vector3(-0.22, 0.5, -0.16), Vector3(0.22, 0.52, 0.02), 0.008, "metal", DARK)
	S.rbox(b, Vector3(-0.4, 0.52, 0.02), Vector3(0.4, 0.59, 0.1), 0.025, "fabric", Color("#26272c"))
	if c.w > 1.8:
		var px: float = x1 - 0.18
		S.lathe(b, Vector3(px, 0.5, -0.05), [Vector2(0.06, 0), Vector2(0.08, 0.14)], "ceramic", WHITE, 8, true, Color("#4a3426"))
		for k in 6:
			var a2 := TAU * k / 6.0
			S.leaf(b, Vector3(px, 0.62, -0.05), Vector3(px + cos(a2) * 0.15, 0.8, -0.05 + sin(a2) * 0.15), 0.07, "leaf", Color("#4f9a44"), 0.06)


# ------------------------------------------------------------- vehicles

static func _car(b: MeshBatch, c: Dictionary) -> void:
	# along the long side of the tile block
	var long_x: bool = c.w >= c.d
	var keep := b.xf
	if not long_x:
		b.xf = keep * Transform3D(Basis(Vector3.UP, PI / 2), Vector3.ZERO)
	var L: float = maxf(c.w, c.d) - 0.3
	var W: float = minf(c.w, c.d) - 0.25
	var col: Color = S.vary(CAR_COLORS[_h(c, 3) % CAR_COLORS.size()], _h(c, 4), 0.03)
	var glass := Color(0.1, 0.14, 0.2, 0.9)
	if _h(c, 5) % 2 == 0:
		b.xf = b.xf * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)  # bonnet the other way
	S.rbox(b, Vector3(-L / 2, 0.24, -W / 2), Vector3(L / 2, 0.72, W / 2), 0.12, "metal", col)
	_cabin(b, -L / 2 + 0.75, L / 2 - 1.05, W, 0.7, 1.24, glass, col)
	for e in [-1.0, 1.0]:
		S.rbox(b, Vector3(e * L / 2 - 0.06, 0.22, -W / 2 + 0.05), Vector3(e * L / 2 + 0.06, 0.38, W / 2 - 0.05), 0.04, "plastic", Color("#2a2b30"))
	for sz in [-1.0, 1.0]:
		b.box(Vector3(L / 2 - 0.02, 0.5, sz * (W / 2 - 0.22) - 0.12), Vector3(L / 2 + 0.005, 0.6, sz * (W / 2 - 0.22) + 0.12), "screen", Color("#fff3c4"), 1)
		b.box(Vector3(-L / 2 - 0.005, 0.5, sz * (W / 2 - 0.2) - 0.12), Vector3(-L / 2 + 0.02, 0.6, sz * (W / 2 - 0.2) + 0.12), "screen", Color("#d23b2e"), 2)
	b.box(Vector3(L / 2 - 0.01, 0.4, -0.3), Vector3(L / 2 + 0.01, 0.48, 0.3), "plastic", Color("#1c1d21"), 1)
	b.box(Vector3(-L / 2 - 0.07, 0.4, -0.22), Vector3(-L / 2 - 0.06, 0.5, 0.22), "matte", WHITE, 2)
	# wheels with hubs
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var kw := b.xf
			b.xf = b.xf * Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(sx * (L / 2 - 0.62), 0.3, sz * (W / 2 - 0.02)))
			b.cylinder(Vector3(0, -0.11, 0), 0.3, 0.3, 0.22, "rubber", RUBBER, 12)
			S.disc(b, Vector3(0, 0.115 if sz > 0 else -0.115, 0), 0.17, "chrome", Color("#b8bec5"), 8, sz < 0)
			b.xf = kw
	for sz in [-1.0, 1.0]:
		var mx := L / 2 - 1.1
		S.rbox(b, Vector3(mx - 0.08, 0.74, sz * (W / 2 + 0.06) - 0.05), Vector3(mx + 0.04, 0.84, sz * (W / 2 + 0.06) + 0.05), 0.02, "metal", col)
	b.xf = keep


## The car's glasshouse: sloped windscreens, side windows, a roof.
static func _cabin(b: MeshBatch, x0: float, x1: float, W: float, y0: float, y1: float, glass: Color, col: Color) -> void:
	var rake := 0.35
	var z0 := -W / 2 + 0.1
	var z1 := W / 2 - 0.1
	var b0 := Vector3(x0, y0, z0)
	var b1 := Vector3(x1, y0, z0)
	var b2 := Vector3(x1, y0, z1)
	var b3 := Vector3(x0, y0, z1)
	var t0 := Vector3(x0 + rake * 0.7, y1, z0 + 0.08)
	var t1 := Vector3(x1 - rake, y1, z0 + 0.08)
	var t2 := Vector3(x1 - rake, y1, z1 - 0.08)
	var t3 := Vector3(x0 + rake * 0.7, y1, z1 - 0.08)
	b.quad(b1, b2, t2, t1, Vector3(y1 - y0, rake, 0).normalized(), "glass", glass)
	b.quad(b0, b3, t3, t0, Vector3(-(y1 - y0), rake * 0.7, 0).normalized(), "glass", glass)
	b.quad(b0, b1, t1, t0, Vector3(0, 0.15, -1).normalized(), "glass", glass)
	b.quad(b3, b2, t2, t3, Vector3(0, 0.15, 1).normalized(), "glass", glass)
	S.rbox(b, Vector3(t0.x - 0.03, y1, z0 + 0.06), Vector3(t1.x + 0.03, y1 + 0.05, z1 - 0.06), 0.025, "metal", col)
	var m := (x0 + x1) / 2
	for zz in [z0 + 0.02, z1 - 0.02]:
		S.tube(b, Vector3(m, y0, zz), Vector3(m, y1, zz + (0.06 if zz < 0 else -0.06)), 0.03, "metal", col.darkened(0.3), 4)


# ------------------------------------------------------------- outdoors

static func _tree(b: MeshBatch, c: Dictionary) -> void:
	var hs := _h(c, 9)
	var s := 0.8 + float(hs % 5) * 0.12
	var bark := S.vary(Color("#6b4a33"), hs, 0.06)
	S.lathe(b, Vector3.ZERO, [Vector2(0.2 * s, 0), Vector2(0.13 * s, 0.25), Vector2(0.1 * s, 1.7 * s), Vector2(0.06 * s, 2.3 * s)], "wood", bark, 7, true)
	var g := Color("#4f8a3c").lerp(Color("#7aa646"), float(_h(c, 2) % 5) / 5.0)
	if hs % 7 == 0:
		# a conifer: stacked cones
		for k in 4:
			var r := (1.0 - k * 0.2) * s
			S.lathe(b, Vector3(0, (0.9 + k * 0.7) * s, 0), [Vector2(r, 0), Vector2(0.0, 1.2 * s)], "leaf", g.darkened(0.25 - k * 0.04), 9, false)
			S.disc(b, Vector3(0, (0.9 + k * 0.7) * s, 0), r, "leaf", g.darkened(0.4), 9, true)
		return
	for k in 3:
		var a := TAU * k / 3.0 + float(hs % 6)
		S.tube(b, Vector3(0, 1.4 * s, 0), Vector3(cos(a) * 0.5 * s, 2.1 * s, sin(a) * 0.5 * s), 0.05 * s, "wood", bark, 4)
	var blobs := [[Vector3(0, 2.3, 0), 1.0], [Vector3(0.45, 2.75, 0.15), 0.7], [Vector3(-0.5, 2.55, -0.2), 0.65],
		[Vector3(0.1, 3.05, -0.3), 0.55], [Vector3(-0.2, 2.1, 0.5), 0.6]]
	for i in blobs.size():
		var col := g.lightened(0.07) if i % 2 else g.darkened(0.04 * i)
		b.sphere(blobs[i][0] * s, blobs[i][1] * s, "leaf", col, Vector3(1, 0.85, 1), 4, 7)


static func _street_lamp(b: MeshBatch, c: Dictionary) -> void:
	var pole := Color("#2d3138")
	S.lathe(b, Vector3.ZERO, [Vector2(0.14, 0), Vector2(0.14, 0.3), Vector2(0.08, 0.4), Vector2(0.06, 3.5), Vector2(0.04, 3.6)], "metal", pole, 8, true)
	S.tube(b, Vector3(0, 3.5, 0), Vector3(0, 3.62, 0.3), 0.04, "metal", pole, 5)
	S.tube(b, Vector3(0, 3.62, 0.3), Vector3(0, 3.6, 0.6), 0.04, "metal", pole, 5)
	S.rbox(b, Vector3(-0.15, 3.52, 0.4), Vector3(0.15, 3.62, 0.85), 0.04, "metal", pole)
	b.box(Vector3(-0.11, 3.5, 0.44), Vector3(0.11, 3.52, 0.81), "screen", Color("#ffe2a8"), 8)
