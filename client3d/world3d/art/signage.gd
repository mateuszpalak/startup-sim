## Signs of a floor (as the 2D map painter drew them): brass plaques with
## the room's name by the doors, green EXIT signs over the stairwell doors,
## the smokers' shelter roof with its "PALARNIA" sign. Geometry goes into the
## builder's `things` batch; the text is Label3D (culled beyond a few metres
## from the camera, so only the nearby ones cost anything).
extends RefCounted

const MeshBatch = preload("res://world3d/mesh_batch.gd")
const S = preload("res://world3d/art/shapes.gd")
const Kit = preload("res://ui/ui_kit.gd")

const WALL_T := 0.28
const PLATE := Color("#d9c27a")
const EXIT_GREEN := Color("#2f9e4f")


static func build(mb, root: Node3D) -> void:
	_plaques(mb, root)
	_exit_signs(mb, root)
	_shelters(mb, root)


static func _label(text: String, size: int, pixel: float, col: Color, pos: Vector3, facing: Vector3, outline := 0, out_col := Color.BLACK) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = Kit.font()
	l.font_size = size
	l.pixel_size = pixel
	l.modulate = col
	l.outline_size = outline
	l.outline_modulate = out_col
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.shaded = false
	l.position = pos
	l.rotation.y = atan2(facing.x, facing.z)
	l.visibility_range_end = 26.0
	return l


## A small brass plate on the wall beside each doorway, on the side it's
## read from, with the name of the room behind.
static func _plaques(mb, root: Node3D) -> void:
	var map = mb.map
	var things: MeshBatch = mb.things
	for y in map.height:
		for x in map.width:
			if not map.is_plaque_door(x, y):
				continue
			var sides: Array = map.door_sides(x, y)
			for s in sides:
				var across: bool = s[1].y != 0
				var next := Vector2i(x, y) + (Vector2i(1, 0) if across else Vector2i(0, 1))
				if map.is_plaque_door(next.x, next.y):
					continue
				var target := -1
				for o in sides:
					if map.plaque_between(s[0], o[0]):
						target = o[0]
				if target == -1 or not mb._is_wallish(next.x, next.y):
					continue
				var dir := Vector3(s[1].x, 0, s[1].y)
				var along := Vector3(1, 0, 0) if across else Vector3(0, 0, 1)
				# 30 cm past the door's edge, on the reader's face of the wall
				var c := Vector3(next.x + 0.5, 1.5, next.y + 0.5) - along * 0.15 + dir * (WALL_T / 2)
				var keep := things.xf
				things.xf = Transform3D(Basis(along, Vector3.UP, dir), c)
				S.rbox(things, Vector3(-0.24, -0.08, 0.0), Vector3(0.24, 0.08, 0.018), 0.008, "chrome", PLATE)
				things.xf = keep
				var name: String = map.room_name(target)
				var px := minf(0.0026, 0.42 / maxf(1.0, name.length() * 15.0))
				root.add_child(_label(name, 32, px, Kit.INK, c + dir * 0.021, dir))


## Green EXIT signs over the doors into the stairwell, on the side you
## come from.
static func _exit_signs(mb, root: Node3D) -> void:
	var map = mb.map
	var things: MeshBatch = mb.things
	for y in map.height:
		for x in map.width:
			if not mb._is_door(x, y) or mb._is_door(x - 1, y) or mb._is_door(x, y - 1):
				continue
			var sides: Array = map.door_sides(x, y)
			var stairs: Array = sides.filter(func(s): return map.room_types.get(s[0], "") == "stairs")
			var other: Array = sides.filter(func(s): return map.room_types.get(s[0], "") != "stairs")
			if stairs.is_empty() or other.is_empty():
				continue
			var d: Vector2i = other[0][1]
			var dir := Vector3(d.x, 0, d.y)
			var along := Vector3(1, 0, 0) if d.y != 0 else Vector3(0, 0, 1)
			var c := Vector3(x + 0.5, 2.38, y + 0.5) + dir * (WALL_T / 2)
			var keep := things.xf
			things.xf = Transform3D(Basis(along, Vector3.UP, dir), c)
			S.rbox(things, Vector3(-0.2, -0.09, 0.0), Vector3(0.2, 0.09, 0.05), 0.012, "plastic", Color("#e8ece4"))
			things.box(Vector3(-0.18, -0.07, 0.05), Vector3(0.18, 0.07, 0.055), "screen", EXIT_GREEN, 16)
			things.xf = keep
			root.add_child(_label("EXIT", 40, 0.0042, Color("#f4f8ef"), c + dir * 0.06, dir))


## The smokers' shelter, like a bus stop: a glass roof on a steel frame
## over its tiles, posts at the open corners, a blue "PALARNIA" sign.
static func _shelters(mb, root: Node3D) -> void:
	var map = mb.map
	var things: MeshBatch = mb.things
	var glass := Rect2i()
	var found := false
	for y in map.height:
		for x in map.width:
			if mb._type(x, y) in ["shelter_glass", "shelter_bench"]:
				glass = Rect2i(x, y, 1, 1) if not found else glass.merge(Rect2i(x, y, 1, 1))
				found = true
	if not found:
		return
	var room: int = map.room_at_tile(glass.position.x + glass.size.x, glass.position.y + 1)
	var roof := glass
	for y in range(glass.position.y, glass.end.y):
		for x in range(glass.position.x, map.width):
			if map.room_at_tile(x, y) != room:
				break
			roof = roof.merge(Rect2i(x, y, 1, 1))
	var x0 := float(roof.position.x) + 0.35
	var x1 := float(roof.end.x) - 0.05
	var z0 := float(roof.position.y) + 0.3
	var z1 := float(roof.end.y) - 0.3
	var y := 2.3
	var steel := Color("#5d666d")
	# posts at the open corners, a frame, the glass
	for p in [Vector2(x1 - 0.08, z0 + 0.08), Vector2(x1 - 0.08, z1 - 0.08)]:
		S.rbox(things, Vector3(p.x - 0.05, 0, p.y - 0.05), Vector3(p.x + 0.05, y, p.y + 0.05), 0.015, "metal", steel)
	S.rbox(things, Vector3(x0 - 0.1, y, z0 - 0.1), Vector3(x1 + 0.1, y + 0.1, z0 + 0.02), 0.02, "metal", steel)
	S.rbox(things, Vector3(x0 - 0.1, y, z1 - 0.02), Vector3(x1 + 0.1, y + 0.1, z1 + 0.1), 0.02, "metal", steel)
	S.rbox(things, Vector3(x1 - 0.02, y, z0), Vector3(x1 + 0.1, y + 0.1, z1), 0.02, "metal", steel)
	S.rbox(things, Vector3(x0 - 0.1, y, z0), Vector3(x0 + 0.02, y + 0.1, z1), 0.02, "metal", steel)
	for k in range(1, int(x1 - x0)):
		things.box(Vector3(x0 + k - 0.025, y + 0.04, z0), Vector3(x0 + k + 0.025, y + 0.1, z1), "metal", steel)
	things.box(Vector3(x0, y + 0.06, z0), Vector3(x1, y + 0.08, z1), "glass", Color(0.7, 0.85, 0.92, 0.35), 63)
	# the sign, standing on the roof's front edge
	var sc := Vector3(x1 - 1.0, y + 0.35, z1 + 0.04)
	S.rbox(things, sc + Vector3(-0.75, -0.22, -0.06), sc + Vector3(0.75, 0.22, 0.06), 0.03, "plastic", Color("#2f6fb0"))
	root.add_child(_label("PALARNIA", 48, 0.0062, Color.WHITE, sc + Vector3(0, 0, 0.065), Vector3.BACK))
