## Door leaves and door furniture for map_builder's door tiles.
##   - door / board_door / card_door: an open leaf swung back against the
##     wall on the room side (the 2D game shows them as passable openings),
##     a lever handle; card doors get a reader with a green light.
##   - service_door / storeroom_door / locked_door: a closed leaf with its
##     marking (red band, keyhole, padlock), as in the 2D painter.
##   - glass_door: slim sliding glass panels parked at the sides + a sensor.
## Elevator and stall doors belong to their own views.
extends RefCounted

const MeshBatch = preload("res://world3d/mesh_batch.gd")
const S = preload("res://world3d/art/shapes.gd")

const LEAF := {"door": Color("#a6764c"), "board_door": Color("#5e2f22"), "card_door": Color("#7d8288"),
	"service_door": Color("#6b4128"), "storeroom_door": Color("#7a5a3a"), "locked_door": Color("#4a2f24")}
const CHROME := Color("#d8dee3")
const BRASS := Color("#c8a040")


## mb: the map builder (map queries); a, b: the opening's corners (floor
## level, across the wall thickness); horiz: the wall runs along x.
static func build(mb, x: int, y: int, t: String, a: Vector3, b: Vector3, horiz: bool, top: float, prev_same: bool, next_same: bool) -> void:
	var things: MeshBatch = mb.things
	match t:
		"door", "board_door", "card_door":
			var side := _swing_side(mb, x, y, horiz)
			# hinge at the end of the run (double doors: one leaf per tile)
			if not prev_same:
				_open_leaf(things, a, b, horiz, top, side, true, LEAF[t], t)
			elif not next_same:
				_open_leaf(things, a, b, horiz, top, side, false, LEAF[t], t)
			if t == "card_door" and not next_same:
				_card_reader(things, a, b, horiz, side)
		"service_door", "storeroom_door", "locked_door":
			_closed_leaf(things, a, b, horiz, top, t)
		"glass_door":
			_glass_panels(things, a, b, horiz, top, prev_same, next_same)


## The side (+1 / -1 along the wall's normal) the door opens into: into a
## room rather than into the corridor.
static func _swing_side(mb, x: int, y: int, horiz: bool) -> int:
	var best := 1
	var found := false
	for s in mb.map.door_sides(x, y):
		var d: Vector2i = s[1]
		var comp := d.y if horiz else d.x
		if comp == 0:
			continue
		var rt: String = mb.map.room_types.get(s[0], "")
		if not found or rt not in ["corridor", "hall", "stairs", "outside", "entrance"]:
			best = comp
			found = rt not in ["corridor", "hall", "stairs", "outside", "entrance"]
	return best


## Local frame at a hinge: X runs away from the opening along the wall
## (mirrored for the other end), Y up, Z into the room on `side`.
static func _frame(a: Vector3, b: Vector3, horiz: bool, side: int, at_a: bool) -> Transform3D:
	var mid := (a + b) / 2
	var half := 0.14 + 0.005
	if horiz:
		var hx := a.x + 0.07 if at_a else b.x - 0.07
		var X := Vector3(1, 0, 0) if at_a else Vector3(-1, 0, 0)
		return Transform3D(Basis(X, Vector3.UP, Vector3(0, 0, side)), Vector3(hx, 0, mid.z + side * half))
	var hz := a.z + 0.07 if at_a else b.z - 0.07
	var Xv := Vector3(0, 0, 1) if at_a else Vector3(0, 0, -1)
	return Transform3D(Basis(Xv, Vector3.UP, Vector3(side, 0, 0)), Vector3(mid.x + side * half, 0, hz))


static func _open_leaf(things: MeshBatch, a: Vector3, b: Vector3, horiz: bool, top: float, side: int, at_a: bool, col: Color, t: String) -> void:
	var span := (b.x - a.x) if horiz else (b.z - a.z)
	var L := span - 0.14
	var keep := things.xf
	things.xf = _frame(a, b, horiz, side, at_a) * Transform3D(Basis(Vector3.UP, 0.14), Vector3.ZERO)
	var h := top - 0.08
	S.rbox(things, Vector3(-L, 0.02, 0.0), Vector3(0, h, 0.045), 0.008, "wood" if t != "card_door" else "plastic", col)
	# raised panels on the visible face
	var pc := col.lightened(0.06)
	S.rbox(things, Vector3(-L + 0.1, 0.15, 0.045), Vector3(-0.1, h * 0.45, 0.055), 0.006, "wood" if t != "card_door" else "plastic", pc)
	if t == "card_door":
		things.box(Vector3(-L + 0.14, h * 0.55, 0.045), Vector3(-0.14, h - 0.15, 0.05), "glass", Color(0.75, 0.88, 0.95, 0.5), 16 | 4)
	else:
		S.rbox(things, Vector3(-L + 0.1, h * 0.52, 0.045), Vector3(-0.1, h - 0.12, 0.055), 0.006, "wood", pc)
	# lever handle on both faces, far from the hinge
	var hx := -L + 0.08
	var hc := BRASS if t == "board_door" else CHROME
	for zf in [0.06, -0.015]:
		S.rbox(things, Vector3(hx - 0.02, 0.98, zf - 0.005), Vector3(hx + 0.02, 1.1, zf + 0.005), 0.004, "chrome", hc)
		S.rbox(things, Vector3(hx - 0.005, 1.0, zf + (0.01 if zf > 0 else -0.03)), Vector3(hx + 0.13, 1.025, zf + (0.03 if zf > 0 else -0.01)), 0.005, "chrome", hc)
	# hinges
	for hy in [0.25, h - 0.3]:
		S.tube(things, Vector3(0.0, hy, 0.0), Vector3(0.0, hy + 0.1, 0.0), 0.012, "chrome", hc, 5)
	things.xf = keep


static func _card_reader(things: MeshBatch, a: Vector3, b: Vector3, horiz: bool, side: int) -> void:
	var keep := things.xf
	# on the wall just beyond the far post, on both faces
	for sd in [1, -1]:
		things.xf = _frame(a, b, horiz, sd, false)
		S.rbox(things, Vector3(-0.2, 1.05, 0.0), Vector3(-0.1, 1.22, 0.025), 0.008, "plastic", Color("#3a3d42"))
		things.box(Vector3(-0.17, 1.17, 0.025), Vector3(-0.13, 1.19, 0.03), "screen", Color("#6fd06b"), 16)
	things.xf = keep


static func _closed_leaf(things: MeshBatch, a: Vector3, b: Vector3, horiz: bool, top: float, t: String) -> void:
	var col: Color = LEAF[t]
	var keep := things.xf
	var mid := (a + b) / 2
	var basis := Basis.IDENTITY if horiz else Basis(Vector3.UP, PI / 2)
	things.xf = Transform3D(basis, Vector3(mid.x, 0, mid.z))
	var L := ((b.x - a.x) if horiz else (b.z - a.z)) / 2 - 0.07
	var h := top - 0.07
	S.rbox(things, Vector3(-L, 0.02, -0.03), Vector3(L, h, 0.03), 0.01, "wood", col)
	for sz in [1.0, -1.0]:
		var zf: float = sz * 0.03
		var zo: float = sz * 0.04
		match t:
			"service_door":
				things.box(Vector3(-L + 0.12, 1.45, minf(zf, zo)), Vector3(L - 0.12, 1.62, maxf(zf, zo)), "matte", Color("#a8402f"), 63 & ~8)
				_knob(things, L - 0.12, 1.0, zf, sz, Color("#d4b870"))
			"storeroom_door":
				things.box(Vector3(-L + 0.1, 0.25, minf(zf, zo)), Vector3(L - 0.1, h - 0.2, maxf(zf, zo)), "wood", col.lightened(0.1), 63 & ~8)
				_knob(things, L - 0.14, 1.0, zf, sz, BRASS)
				things.box(Vector3(L - 0.16, 0.86, minf(zf, zo) - 0.003), Vector3(L - 0.12, 0.92, maxf(zf, zo) + 0.003), "matte", Color("#1c1c1c"), 63 & ~8)
			"locked_door":
				things.box(Vector3(-L + 0.05, 1.0, minf(zf, zo)), Vector3(L - 0.05, 1.18, maxf(zf, zo)), "matte", Color("#b0382c"), 63 & ~8)
				# a padlock on a hasp
				var pz: float = zf + sz * 0.04
				S.rbox(things, Vector3(-0.07, 0.82, minf(zf, pz)), Vector3(0.07, 0.96, maxf(zf, pz)), 0.015, "chrome", Color("#d4b870"))
				S.tube(things, Vector3(-0.045, 0.96, zf + sz * 0.02), Vector3(-0.045, 1.02, zf + sz * 0.02), 0.01, "chrome", CHROME, 5)
				S.tube(things, Vector3(0.045, 0.96, zf + sz * 0.02), Vector3(0.045, 1.02, zf + sz * 0.02), 0.01, "chrome", CHROME, 5)
				S.tube(things, Vector3(-0.045, 1.02, zf + sz * 0.02), Vector3(0.045, 1.02, zf + sz * 0.02), 0.01, "chrome", CHROME, 5)
	things.xf = keep


static func _knob(things: MeshBatch, x: float, y: float, zf: float, sz: float, col: Color) -> void:
	S.tube(things, Vector3(x, y, zf), Vector3(x, y, zf + sz * 0.05), 0.012, "chrome", col, 5)
	things.sphere(Vector3(x, y, zf + sz * 0.06), 0.028, "chrome", col, Vector3.ONE, 2, 6)


## Automatic sliding doors, open: a glass panel parked against the wall at
## each end of the run, a sensor above.
static func _glass_panels(things: MeshBatch, a: Vector3, b: Vector3, horiz: bool, top: float, prev_same: bool, next_same: bool) -> void:
	var keep := things.xf
	var mid := (a + b) / 2
	things.xf = Transform3D(Basis.IDENTITY if horiz else Basis(Vector3.UP, -PI / 2), Vector3(mid.x, 0, mid.z))
	var half := 0.5
	var frame := Color("#8d969e")
	for e in [-1.0, 1.0]:
		if (e < 0 and prev_same) or (e > 0 and next_same):
			continue
		var x0: float = e * half - e * 0.18
		var x1: float = e * half + e * 0.6
		var lo := minf(x0, x1)
		var hi := maxf(x0, x1)
		for sz in [-1.0, 1.0]:
			var z: float = sz * 0.17
			things.box(Vector3(lo, 0.02, z - 0.012), Vector3(hi, top - 0.28, z + 0.012), "glass", Color(0.72, 0.86, 0.95, 0.3), 63)
			things.box(Vector3(lo, 0.02, z - 0.02), Vector3(hi, 0.08, z + 0.02), "metal", frame, 63 & ~8)
			things.box(Vector3(lo, top - 0.33, z - 0.02), Vector3(hi, top - 0.28, z + 0.02), "metal", frame, 63)
			things.box(Vector3(lo, 0.02, z - 0.02), Vector3(lo + 0.04, top - 0.28, z + 0.02), "metal", frame, 63 & ~8)
	# the motion sensor
	if not prev_same:
		for sz in [-1.0, 1.0]:
			S.rbox(things, Vector3(0.3, top - 0.2, sz * 0.15 - 0.03), Vector3(0.5, top - 0.1, sz * 0.15 + 0.03), 0.01, "plastic", Color("#2c2e35"))
	things.xf = keep
