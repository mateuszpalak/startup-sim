## The street-level exterior (floor 0 only):
##   - the upper storeys as a solid shell over the ground floor's footprint
##     (facades with windows, cornices, a roof with a parapet and plant),
##     shown only while the player is outside (art/storeys_toggle.gd);
##   - canopies over the entrances, curbs, benches and litter bins.
extends RefCounted

const MeshBatch = preload("res://world3d/mesh_batch.gd")
const S = preload("res://world3d/art/shapes.gd")
const Coords = preload("res://world3d/coords.gd")
const Toggle = preload("res://world3d/art/storeys_toggle.gd")

const WALL_T := 0.28
const STOREYS := 4                   # storeys above the ground floor
const PLASTER := Color("#ddd0bd")
const CORNICE := Color("#f1ebe0")
const FRAME := Color("#3d4048")
const GLASS := Color("#4a5d70")
const LIT := Color("#ffd99a")
const ROOF := Color("#8d8a84")


static func top_y() -> float:
	return STOREYS * Coords.STOREY + Coords.STOREY


## The shell over the floor's footprint, as its own node (the toggle shows
## it from the street only).
static func storeys(mb, mats: Dictionary) -> Node3D:
	var fp := footprint(mb)
	if fp.is_empty():
		return null
	var b := MeshBatch.new()
	var inset := 0.5 - WALL_T / 2
	var yt := top_y()
	for t: Vector2i in fp:
		var x0: float = t.x + (inset if not fp.has(t + Vector2i(-1, 0)) else 0.0)
		var x1: float = t.x + 1 - (inset if not fp.has(t + Vector2i(1, 0)) else 0.0)
		var z0: float = t.y + (inset if not fp.has(t + Vector2i(0, -1)) else 0.0)
		var z1: float = t.y + 1 - (inset if not fp.has(t + Vector2i(0, 1)) else 0.0)
		b.quad_up(x0, z0, x1, z1, yt, "wall", ROOF.darkened(float(absi(hash(t)) % 5) * 0.012))
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if fp.has(t + d):
				continue
			_facade(b, fp, t, d, Vector2(x0, z0), Vector2(x1, z1), yt)
	_roof_plant(b, fp, yt)
	var mi := b.to_instance(mats, "Storeys")
	var tg := Toggle.new()
	tg.name = "StoreysToggle"
	tg.shell = mi
	tg.footprint = fp
	var holder := Node3D.new()
	holder.name = "Exterior"
	holder.add_child(mi)
	holder.add_child(tg)
	return holder


## Tiles of the building on this floor: walls, doors and indoor rooms.
static func footprint(mb) -> Dictionary:
	var fp := {}
	for y in mb.map.height:
		for x in mb.map.width:
			var t: String = mb._type(x, y)
			if t == "void" or mb._outside(x, y):
				continue
			if t in ["fence", "grass", "sidewalk", "street"]:
				continue
			fp[Vector2i(x, y)] = true
	# only keep tiles enclosed by the building's outer walls: drop indoor
	# bits that touch the outside without a wall (none expected)
	return fp


## One facade face of a footprint tile, looking along `d`, from the top of
## the ground floor's walls to the roof: storey bands, windows, cornices,
## and the parapet.
static func _facade(b: MeshBatch, fp: Dictionary, t: Vector2i, d: Vector2i, lo: Vector2, hi: Vector2, yt: float) -> void:
	var n := Vector3(d.x, 0, d.y)
	# the face's ends (along it) and its plane
	var a: Vector3
	var c: Vector3
	if d.x != 0:
		var px: float = hi.x if d.x > 0 else lo.x
		a = Vector3(px, 0, lo.y)
		c = Vector3(px, 0, hi.y)
	else:
		var pz: float = hi.y if d.y > 0 else lo.y
		a = Vector3(lo.x, 0, pz)
		c = Vector3(hi.x, 0, pz)
	var along := Vector2i(absi(d.y), absi(d.x))
	# a window: straight run on both sides, a pier every third tile
	var straight := fp.has(t + along) and fp.has(t - along) and not fp.has(t + along + d) and not fp.has(t - along + d)
	var k := t.x if along.x != 0 else t.y
	var win := straight and k % 3 != 0
	var y0 := Coords.WALL_H
	for s in STOREYS + 1:
		var base := float(s) * Coords.STOREY
		var lo_y := maxf(y0, base)
		var hi_y := base + Coords.STOREY
		if s == 0:
			lo_y = y0
			hi_y = Coords.STOREY
			_face(b, a, c, lo_y, hi_y, n, PLASTER.darkened(0.12))
			continue
		if not win:
			_face(b, a, c, lo_y, hi_y, n, PLASTER)
		else:
			var w0 := base + 0.85
			var w1 := base + 2.45
			_face(b, a, c, lo_y, w0, n, PLASTER)
			_face(b, a, c, w1, hi_y, n, PLASTER)
			_window(b, a, c, w0, w1, n, absi(hash(Vector3i(t.x, t.y, s))))
		# a cornice at each slab
		_band(b, a, c, base - 0.12, base + 0.1, n, 0.06, CORNICE)
	# a parapet on the roof, a coping on top
	_face(b, a, c, yt, yt + 0.5, n, PLASTER)
	_band(b, a, c, yt + 0.42, yt + 0.55, n, 0.05, CORNICE)
	var inner := -n * 0.25
	b.quad(a + inner + Vector3(0, yt, 0), c + inner + Vector3(0, yt, 0), c + inner + Vector3(0, yt + 0.5, 0), a + inner + Vector3(0, yt + 0.5, 0), -n, "wall", PLASTER.darkened(0.15))
	b.quad(a + Vector3(0, yt + 0.5, 0), c + Vector3(0, yt + 0.5, 0), c + inner + Vector3(0, yt + 0.5, 0), a + inner + Vector3(0, yt + 0.5, 0), Vector3.UP, "wall", CORNICE)


static func _face(b: MeshBatch, a: Vector3, c: Vector3, y0: float, y1: float, n: Vector3, col: Color) -> void:
	if y1 <= y0:
		return
	b.quad(a + Vector3(0, y0, 0), c + Vector3(0, y0, 0), c + Vector3(0, y1, 0), a + Vector3(0, y1, 0), n, "wall", col)


## A horizontal band standing out of the face by `out`.
static func _band(b: MeshBatch, a: Vector3, c: Vector3, y0: float, y1: float, n: Vector3, out: float, col: Color) -> void:
	var o := n * out
	b.quad(a + o + Vector3(0, y0, 0), c + o + Vector3(0, y0, 0), c + o + Vector3(0, y1, 0), a + o + Vector3(0, y1, 0), n, "wall", col)
	b.quad(a + Vector3(0, y1, 0), c + Vector3(0, y1, 0), c + o + Vector3(0, y1, 0), a + o + Vector3(0, y1, 0), Vector3.UP, "wall", col.lightened(0.05))
	b.quad(a + Vector3(0, y0, 0), c + Vector3(0, y0, 0), c + o + Vector3(0, y0, 0), a + o + Vector3(0, y0, 0), Vector3.DOWN, "wall", col.darkened(0.2))


## A recessed window: reveals, a dark glass pane (some lit), a mullion and
## a sill.
static func _window(b: MeshBatch, a: Vector3, c: Vector3, y0: float, y1: float, n: Vector3, h: int) -> void:
	var dirv := (c - a).normalized()
	var p0 := a + dirv * 0.12
	var p1 := c - dirv * 0.12
	var r := -n * 0.12
	# side piers of the face around the opening
	_face(b, a, p0, y0, y1, n, PLASTER)
	_face(b, p1, c, y0, y1, n, PLASTER)
	# reveals
	var rc := PLASTER.darkened(0.18)
	b.quad(p0 + Vector3(0, y0, 0), p0 + r + Vector3(0, y0, 0), p0 + r + Vector3(0, y1, 0), p0 + Vector3(0, y1, 0), dirv, "wall", rc)
	b.quad(p1 + Vector3(0, y0, 0), p1 + r + Vector3(0, y0, 0), p1 + r + Vector3(0, y1, 0), p1 + Vector3(0, y1, 0), -dirv, "wall", rc)
	b.quad(p0 + Vector3(0, y1, 0), p1 + Vector3(0, y1, 0), p1 + r + Vector3(0, y1, 0), p0 + r + Vector3(0, y1, 0), Vector3.DOWN, "wall", rc.darkened(0.2))
	b.quad(p0 + Vector3(0, y0, 0), p1 + Vector3(0, y0, 0), p1 + r + Vector3(0, y0, 0), p0 + r + Vector3(0, y0, 0), Vector3.UP, "wall", CORNICE)
	# the pane
	var lit := h % 7 == 0
	var gcol := LIT if lit else GLASS.lerp(Color("#7fa0bc"), float(h % 5) / 10.0)
	b.quad(p0 + r + Vector3(0, y0, 0), p1 + r + Vector3(0, y0, 0), p1 + r + Vector3(0, y1, 0), p0 + r + Vector3(0, y1, 0), n, "screen" if lit else "chrome", gcol)
	# frame: mullion and transom
	var m := (p0 + p1) / 2 + r + n * 0.01
	var tf := Transform3D(Basis(dirv, Vector3.UP, n), m)
	var keep := b.xf
	b.xf = tf
	b.box(Vector3(-0.025, y0, 0), Vector3(0.025, y1, 0.03), "metal", FRAME, 63 & ~8)
	b.box(Vector3(-(p1 - p0).length() / 2, y1 - 0.45, 0), Vector3((p1 - p0).length() / 2, y1 - 0.41, 0.03), "metal", FRAME, 63 & ~8)
	b.xf = keep
	# sill
	var s0 := a + dirv * 0.06 + n * 0.08
	var s1 := c - dirv * 0.06 + n * 0.08
	b.quad(s0 + Vector3(0, y0, 0), s1 + Vector3(0, y0, 0), s1 - n * 0.08 + Vector3(0, y0, 0), s0 - n * 0.08 + Vector3(0, y0, 0), Vector3.UP, "wall", CORNICE)
	b.quad(s0 + Vector3(0, y0 - 0.06, 0), s1 + Vector3(0, y0 - 0.06, 0), s1 + Vector3(0, y0, 0), s0 + Vector3(0, y0, 0), n, "wall", CORNICE.darkened(0.08))


## Roof plant: AC units, a lift motor room, a skylight.
static func _roof_plant(b: MeshBatch, fp: Dictionary, yt: float) -> void:
	var r := Rect2i()
	var first := true
	for t: Vector2i in fp:
		r = Rect2i(t, Vector2i.ONE) if first else r.expand(t).expand(t + Vector2i.ONE)
		first = false
	var c := Vector2(r.get_center())
	# lift / stair housing
	S.rbox(b, Vector3(c.x - 3.5, yt, c.y - 2.0), Vector3(c.x - 0.5, yt + 2.2, c.y + 1.0), 0.06, "plaster", PLASTER.darkened(0.06), CORNICE)
	S.rbox(b, Vector3(c.x - 2.2, yt, c.y + 0.98), Vector3(c.x - 1.3, yt + 1.9, c.y + 1.04), 0.01, "metal", FRAME)
	for i in 3:
		var p := Vector2(c.x + 2.0 + i * 1.6, c.y - 3.0)
		if fp.has(Vector2i(p)) and fp.has(Vector2i(p) + Vector2i(1, 1)):
			S.rbox(b, Vector3(p.x, yt, p.y), Vector3(p.x + 1.2, yt + 0.9, p.y + 0.9), 0.04, "metal", Color("#c9ccce"))
			S.lathe(b, Vector3(p.x + 0.6, yt + 0.9, p.y + 0.45), [Vector2(0.35, 0), Vector2(0.35, 0.03)], "metal", Color("#3a3d44"), 12, true)
	# skylights
	for i in 3:
		var p := Vector2(c.x - 4.0 + i * 3.2, c.y + 5.0)
		if fp.has(Vector2i(p)) and fp.has(Vector2i(p) + Vector2i(2, 1)):
			S.rbox(b, Vector3(p.x, yt, p.y), Vector3(p.x + 2.0, yt + 0.25, p.y + 1.2), 0.03, "metal", FRAME)
			b.quad_up(p.x + 0.08, p.y + 0.08, p.x + 1.92, p.y + 1.12, yt + 0.26, "chrome", Color("#7fa0bc"))
	# solar panels
	for i in 4:
		var p := Vector2(r.position.x + 3.0 + i * 2.0, r.end.y - 5.0)
		if fp.has(Vector2i(p)) and fp.has(Vector2i(p) + Vector2i(2, 2)):
			var keep := b.xf
			b.xf = Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(p.x, yt + 0.2, p.y))
			S.rbox(b, Vector3(0, 0, 0), Vector3(1.7, 0.05, 1.1), 0.01, "chrome", Color("#2c3e5a"))
			b.xf = keep
			b.box(Vector3(p.x + 0.1, yt, p.y + 0.9), Vector3(p.x + 0.15, yt + 0.6, p.y + 0.95), "metal", FRAME)
			b.box(Vector3(p.x + 1.55, yt, p.y + 0.9), Vector3(p.x + 1.6, yt + 0.6, p.y + 0.95), "metal", FRAME)


# ------------------------------------------------------------- street level

static func street(mb) -> void:
	var things: MeshBatch = mb.things
	var map = mb.map
	var fp := footprint(mb)
	# canopies over the entrances (glass doors in the outer wall)
	for g in mb._groups(["glass_door"]):
		var r: Rect2i = g.rect
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var out: Vector2i = r.position + d if d.x < 0 or d.y < 0 else r.end - Vector2i.ONE + d
			if fp.has(out) or mb._type(out.x, out.y) == "void":
				continue
			if d.y != 0:
				var z: float = (r.end.y - 0.5 + WALL_T / 2) if d.y > 0 else (r.position.y + 0.5 - WALL_T / 2)
				_canopy(things, Vector3(r.position.x - 0.4, 2.45, z), Vector3(r.end.x + 0.4, 2.45, z), Vector3(0, 0, d.y))
			else:
				var x: float = (r.end.x - 0.5 + WALL_T / 2) if d.x > 0 else (r.position.x + 0.5 - WALL_T / 2)
				_canopy(things, Vector3(x, 2.45, r.position.y - 0.4), Vector3(x, 2.45, r.end.y + 0.4), Vector3(d.x, 0, 0))
			break
	# curbs between the pavement and the road
	for y in map.height:
		for x in map.width:
			if mb._type(x, y) != "sidewalk":
				continue
			for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				if mb._type(x + d.x, y + d.y) not in ["street", "parking", "ramp"]:
					continue
				var e := Vector3(x + 0.5 + d.x * 0.5, 0, y + 0.5 + d.y * 0.5)
				var half := Vector3(absf(d.y) * 0.5, 0, absf(d.x) * 0.5)
				var inn := Vector3(d.x, 0, d.y) * 0.14
				things.box((e - half - inn).min(e + half), (e + half - inn).max(e - half) + Vector3(0, 0.07, 0), "matte", Color("#c9c6bd"), 63 & ~8)
	# benches and bins on the lawn beside the pavement, facing it
	var placed := 0
	for x in range(3, map.width - 3):
		for y in map.height:
			if placed > 12 or (x + y * 3) % 9 != 0:
				continue
			if mb._type(x, y) != "grass" or mb._type(x - 1, y) != "grass" or mb._type(x + 1, y) != "grass":
				continue
			var face := Vector2i.ZERO
			for d in [Vector2i(0, 1), Vector2i(0, -1)]:
				if mb._type(x, y + d.y) == "sidewalk" or mb._type(x, y + d.y) == "street":
					face = d
			if face == Vector2i.ZERO:
				continue
			var keep := things.xf
			things.xf = Transform3D(Basis(Vector3.UP, 0.0 if face.y > 0 else PI), Vector3(x + 0.5, 0, y + 0.55))
			_park_bench(things)
			things.xf = Transform3D(Basis.IDENTITY, Vector3(x + 1.6, 0, y + 0.5))
			_litter_bin(things)
			things.xf = keep
			placed += 1


static func _canopy(b: MeshBatch, p0: Vector3, p1: Vector3, out: Vector3) -> void:
	var depth := 1.7
	var lo := p0.min(p1).min(p0 + out * depth).min(p1 + out * depth)
	var hi := p0.max(p1).max(p0 + out * depth).max(p1 + out * depth)
	S.rbox(b, Vector3(lo.x, 2.45, lo.z), Vector3(hi.x, 2.62, hi.z), 0.04, "metal", Color("#3d4048"), Color("#4a4e57"))
	# glass top inset, downlights, tie rods to the wall
	var along := (p1 - p0).normalized()
	var L := (p1 - p0).length()
	for i in int(L / 1.2) + 1:
		var q := p0 + along * (0.6 + i * 1.2) + out * (depth * 0.6)
		if (q - p0).dot(along) > L - 0.3:
			break
		S.disc(b, Vector3(q.x, 2.445, q.z), 0.07, "screen", Color("#fff1c4"), 8, true)
	for e in [0.3, L - 0.3]:
		var w: Vector3 = p0 + along * e + Vector3(0, 0.95, 0)
		S.tube(b, w, p0 + along * e + out * (depth - 0.1) + Vector3(0, 0.17, 0), 0.02, "chrome", Color("#d8dee3"), 4)


static func _park_bench(b: MeshBatch) -> void:
	var wood := Color("#a8794e")
	for k in 3:
		S.rbox(b, Vector3(-0.8, 0.42, -0.22 + k * 0.13), Vector3(0.8, 0.46, -0.12 + k * 0.13), 0.01, "wood", wood)
	for k in 2:
		var keep := b.xf
		b.xf = b.xf * Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 0.58 + k * 0.15, -0.26))
		S.rbox(b, Vector3(-0.8, 0, -0.02), Vector3(0.8, 0.11, 0.02), 0.01, "wood", wood)
		b.xf = keep
	for sx in [-0.62, 0.62]:
		S.rbox(b, Vector3(sx - 0.03, 0, -0.26), Vector3(sx + 0.03, 0.42, 0.2), 0.012, "metal", Color("#2d3138"))
		S.tube(b, Vector3(sx, 0.42, -0.24), Vector3(sx, 0.92, -0.36), 0.025, "metal", Color("#2d3138"), 5)
		S.rbox(b, Vector3(sx - 0.03, 0.6, -0.1), Vector3(sx + 0.03, 0.64, 0.2), 0.01, "metal", Color("#2d3138"))


static func _litter_bin(b: MeshBatch) -> void:
	S.lathe(b, Vector3.ZERO, [Vector2(0.06, 0), Vector2(0.05, 0.3)], "metal", Color("#2d3138"), 6, false)
	S.lathe(b, Vector3(0, 0.3, 0), [Vector2(0.2, 0), Vector2(0.22, 0.5), Vector2(0.23, 0.55), Vector2(0.18, 0.55)], "metal", Color("#3e6b4f"), 10, false)
	S.disc(b, Vector3(0, 0.33, 0), 0.2, "metal", Color("#2d3138"), 10)
