## A vehicle on the street (mirrors game/vehicle_view.gd): car, taxi, patrol
## car, fire engine, tram, bike. Built facing +x; turned smoothly to where
## it drives, wheels roll with the distance travelled, lights at night,
## flashing beacons on the patrol car and the fire engine.
extends Node3D

const MeshBatch = preload("res://world3d/mesh_batch.gd")
const Materials = preload("res://world3d/materials.gd")
const V = preload("res://game/vehicle_view.gd")

const GLASS := Color(0.16, 0.22, 0.3, 0.88)
const TYRE := Color("#16171b")
const RIM := Color("#b9c0c6")
const HEAD := Color("#fff4d0")
const TAIL := Color("#e02a2a")

var view: Node2D
var _kind := -1
var _body := Node3D.new()
var _wheels: Array[Node3D] = []
var _wheel_r := 0.32
var _beacons: Array = []   # [MeshInstance3D, OmniLight3D, phase]
var _head_lights: Array[SpotLight3D] = []
var _last := Vector3.INF
var _yaw_goal := 0.0
var _wv: Node3D
var _t := 0.0


func setup(p_view: Node2D, wv: Node3D) -> void:
	view = p_view
	_wv = wv
	add_child(_body)


## Yaw that turns +x towards the facing of the 2D view.
static func facing_yaw(f: int) -> float:
	match f:
		0: return -PI / 2   # down (+z)
		1: return PI / 2    # up (-z)
		2: return PI        # left
	return 0.0             # right


func sync(pos: Vector3, delta: float) -> void:
	if view.kind != _kind:
		_build(view.kind)
	_t += delta
	_yaw_goal = facing_yaw(view.facing)
	if _last == Vector3.INF:
		rotation.y = _yaw_goal
		_last = pos
	rotation.y = lerp_angle(rotation.y, _yaw_goal, minf(1.0, delta * 6.0))
	var moved := Vector2(pos.x - _last.x, pos.z - _last.z).length()
	_last = pos
	position = pos
	# roll the wheels; a little body sway while driving
	for w in _wheels:
		w.rotation.z -= moved / _wheel_r
	var speed := moved / maxf(delta, 0.001)
	_body.rotation.x = lerpf(_body.rotation.x, sin(_t * 9.0) * 0.006 * minf(speed, 8.0) / 8.0, minf(1.0, delta * 5.0))
	for bc in _beacons:
		var on: bool = int(_t * 4.0 + bc[2]) % 2 == 0
		bc[0].visible = on
		bc[1].visible = on
	var night := _night()
	for l in _head_lights:
		l.visible = night


## Lights on with the world's night (lighting_3d: dusk, storm darkness).
func _night() -> bool:
	if _wv == null or not ("lighting" in _wv):
		return false
	return _wv.lighting.night > 0.35


func _build(kind: int) -> void:
	_kind = kind
	for c in _body.get_children():
		c.queue_free()
	_wheels.clear()
	_beacons.clear()
	_head_lights.clear()
	var b := MeshBatch.new()
	match kind:
		V.CAR, V.TAXI, V.POLICE:
			var col: Color = view.color if kind == V.CAR else (Color("#f4c20d") if kind == V.TAXI else Color("#eef1f4"))
			_car(b, col, 3.9, 1.72, kind)
		V.FIRE_ENGINE:
			_fire_engine(b)
		V.TRAM:
			_tram(b)
		V.BIKE:
			_bike(b, view.color)
		_:
			_car(b, view.color, 3.9, 1.72, V.CAR)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(Materials.get_all())
	_body.add_child(mi)


func _wheel(at: Vector3, r: float, w: float, rim := RIM) -> void:
	var n := Node3D.new()
	n.position = at
	_body.add_child(n)
	var b := MeshBatch.new()
	b.xf = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO)
	b.cylinder(Vector3(0, -w / 2, 0), r, r, w, "matte", TYRE, 14)
	b.cylinder(Vector3(0, -w / 2 - 0.005, 0), r * 0.58, r * 0.58, w + 0.01, "metal", rim, 7)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(Materials.get_all())
	n.add_child(mi)
	_wheels.append(n)
	_wheel_r = r


func _beacon(at: Vector3, col: Color, phase: float) -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.09
	s.height = 0.12
	m.mesh = s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col * 2.5
	m.material_override = mat
	m.position = at
	_body.add_child(m)
	var o := OmniLight3D.new()
	o.light_color = col
	o.light_energy = 2.0
	o.omni_range = 4.0
	o.position = at + Vector3(0, 0.2, 0)
	_body.add_child(o)
	_beacons.append([m, o, phase])


func _lights(b: MeshBatch, len: float, wid: float, y: float) -> void:
	for sz in [-1.0, 1.0]:
		var z: float = sz * (wid / 2 - 0.22)
		b.box(Vector3(len / 2 - 0.01, y, z - 0.14), Vector3(len / 2 + 0.01, y + 0.1, z + 0.14), "screen", HEAD, 1)
		b.box(Vector3(-len / 2 - 0.01, y, z - 0.14), Vector3(-len / 2 + 0.01, y + 0.1, z + 0.14), "screen", TAIL, 2)
	var sp := SpotLight3D.new()
	sp.position = Vector3(len / 2 + 0.1, y + 0.05, 0)
	sp.rotation = Vector3(0, -PI / 2, 0)
	sp.rotate_object_local(Vector3.RIGHT, -0.18)
	sp.spot_range = 9.0
	sp.spot_angle = 32.0
	sp.light_energy = 3.0
	sp.light_color = HEAD
	sp.visible = false
	_body.add_child(sp)
	_head_lights.append(sp)


## A hatchback/saloon: body, glasshouse, roof, bumpers, mirrors, wheels.
func _car(b: MeshBatch, col: Color, len: float, wid: float, kind: int) -> void:
	var dark := col.darkened(0.35)
	var r := 0.32
	var y0 := 0.22
	# lower body (with wheel arches darkened)
	b.box(Vector3(-len / 2, y0, -wid / 2), Vector3(len / 2, 0.82, wid / 2), "metal", col)
	b.box(Vector3(len / 2 - 0.9, 0.82, -wid / 2 + 0.02), Vector3(len / 2 - 0.05, 0.9, wid / 2 - 0.02), "metal", col)  # bonnet
	# bumpers
	b.box(Vector3(len / 2, y0, -wid / 2 + 0.05), Vector3(len / 2 + 0.06, 0.45, wid / 2 - 0.05), "matte", Color("#2a2c31"))
	b.box(Vector3(-len / 2 - 0.06, y0, -wid / 2 + 0.05), Vector3(-len / 2, 0.45, wid / 2 - 0.05), "matte", Color("#2a2c31"))
	# glasshouse: a slanted windscreen, side windows, rear window
	var gx0 := -len / 2 + 0.35
	var gx1 := len / 2 - 0.95
	var top := 1.42
	var inset := 0.14
	var wz := wid / 2 - 0.08
	var rz := wid / 2 - inset
	b.quad(Vector3(gx1, 0.86, -wz), Vector3(gx1, 0.86, wz), Vector3(gx1 - 0.55, top, rz), Vector3(gx1 - 0.55, top, -rz), Vector3(0.7, 0.7, 0).normalized(), "glass", GLASS)
	b.quad(Vector3(gx0, 0.86, -wz), Vector3(gx0, 0.86, wz), Vector3(gx0 + 0.35, top, rz), Vector3(gx0 + 0.35, top, -rz), Vector3(-0.8, 0.6, 0).normalized(), "glass", GLASS)
	for sz in [-1.0, 1.0]:
		b.quad(Vector3(gx0, 0.86, sz * wz), Vector3(gx1, 0.86, sz * wz), Vector3(gx1 - 0.55, top, sz * rz), Vector3(gx0 + 0.35, top, sz * rz), Vector3(0, 0.25, sz).normalized(), "glass", GLASS)
		# pillar between the doors
		var px := (gx0 + gx1) / 2 - 0.1
		b.quad(Vector3(px - 0.04, 0.86, sz * (wz + 0.005)), Vector3(px + 0.04, 0.86, sz * (wz + 0.005)), Vector3(px + 0.04, top, sz * (rz + 0.005)), Vector3(px - 0.04, top, sz * (rz + 0.005)), Vector3(0, 0.25, sz).normalized(), "metal", dark)
		# mirror, door handle line
		b.box(Vector3(gx1 - 0.05, 0.86, sz * wid / 2 - 0.06), Vector3(gx1 + 0.08, 0.98, sz * wid / 2 + 0.06), "metal", col)
		b.box(Vector3(-len / 2 + 0.1, 0.6, sz * wid / 2 - 0.005), Vector3(len / 2 - 0.1, 0.62, sz * wid / 2 + 0.005), "matte", dark, 16 | 32)
	b.box(Vector3(gx0 + 0.35, top, -rz), Vector3(gx1 - 0.55, top + 0.04, rz), "metal", col.lightened(0.08))  # roof
	# underbody shadow-ish skirt
	b.box(Vector3(-len / 2 + 0.2, 0.12, -wid / 2 + 0.1), Vector3(len / 2 - 0.2, y0, wid / 2 - 0.1), "matte", Color("#1b1c20"))
	_lights(b, len, wid, 0.58)
	var top_y := top + 0.04
	match kind:
		V.TAXI:
			b.block(0, 0, 0.36, 0.18, top_y, 0.16, "screen", Color("#ffe066"))
			b.block(0, 0, 0.38, 0.2, top_y, 0.03, "matte", Color("#15171c"))
			# a checker band on the sides
			for i in 12:
				var x := -1.2 + i * 0.2
				for sz in [-1.0, 1.0]:
					b.box(Vector3(x, 0.66, sz * wid / 2 - 0.006), Vector3(x + 0.1, 0.74, sz * wid / 2 + 0.006), "matte", Color("#15171c"), 16 | 32)
		V.POLICE:
			for sz in [-1.0, 1.0]:
				b.box(Vector3(-len / 2 + 0.05, 0.5, sz * wid / 2 - 0.006), Vector3(len / 2 - 0.05, 0.62, sz * wid / 2 + 0.006), "matte", Color("#1f3a8a"), 16 | 32)
			b.block(0, 0, 0.3, 1.1, top_y, 0.06, "matte", Color("#22242a"))
			_beacon(Vector3(0, top_y + 0.1, -0.3), Color("#2f6bff"), 0.0)
			_beacon(Vector3(0, top_y + 0.1, 0.3), Color("#ff3030"), 1.0)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_wheel(Vector3(sx * (len / 2 - 0.72), r, sz * (wid / 2 - 0.12)), r, 0.22)


func _fire_engine(b: MeshBatch) -> void:
	var len := 7.2
	var wid := 2.4
	var red := Color("#d32f2f")
	var r := 0.48
	# cab at the front, box body behind
	var cab0 := len / 2 - 1.8
	b.box(Vector3(cab0, 0.4, -wid / 2), Vector3(len / 2, 2.5, wid / 2), "metal", red)
	b.box(Vector3(len / 2 - 0.01, 1.4, -wid / 2 + 0.12), Vector3(len / 2 + 0.01, 2.3, wid / 2 - 0.12), "glass", GLASS, 1)
	for sz in [-1.0, 1.0]:
		b.box(Vector3(cab0 + 0.6, 1.4, sz * wid / 2 - 0.01), Vector3(len / 2 - 0.15, 2.3, sz * wid / 2 + 0.01), "glass", GLASS, 16 | 32)
	b.box(Vector3(-len / 2, 0.4, -wid / 2), Vector3(cab0 - 0.05, 2.7, wid / 2), "metal", red)
	# lockers (shutters) and a yellow stripe
	for i in 4:
		var x := -len / 2 + 0.25 + i * 1.25
		for sz in [-1.0, 1.0]:
			b.box(Vector3(x, 0.9, sz * wid / 2 - 0.01), Vector3(x + 1.1, 2.4, sz * wid / 2 + 0.01), "metal", Color("#c9ced3"), 16 | 32)
	for sz in [-1.0, 1.0]:
		b.box(Vector3(-len / 2, 0.6, sz * wid / 2 - 0.015), Vector3(len / 2, 0.75, sz * wid / 2 + 0.015), "matte", Color("#f1e05a"), 16 | 32)
	# ladder on the roof
	for sz in [-0.4, 0.4]:
		b.box(Vector3(-len / 2 + 0.2, 2.75, sz - 0.04), Vector3(cab0 + 1.0, 2.83, sz + 0.04), "metal", Color("#cfd4da"))
	for i in 14:
		var x := -len / 2 + 0.3 + i * 0.4
		b.box(Vector3(x, 2.75, -0.4), Vector3(x + 0.04, 2.8, 0.4), "metal", Color("#cfd4da"))
	b.box(Vector3(-len / 2 + 0.3, 2.7, -0.15), Vector3(-len / 2 + 0.7, 2.75, 0.15), "metal", Color("#cfd4da"))
	b.box(Vector3(len / 2, 0.4, -wid / 2 + 0.05), Vector3(len / 2 + 0.1, 0.8, wid / 2 - 0.05), "metal", Color("#cfd4da"))  # bumper
	_lights(b, len, wid, 0.9)
	_beacon(Vector3(len / 2 - 0.3, 2.62, -0.6), Color("#2f6bff"), 0.0)
	_beacon(Vector3(len / 2 - 0.3, 2.62, 0.6), Color("#2f6bff"), 1.0)
	for x in [len / 2 - 1.0, -len / 2 + 1.2, -len / 2 + 2.3]:
		for sz in [-1.0, 1.0]:
			_wheel(Vector3(x, r, sz * (wid / 2 - 0.2)), r, 0.32)


func _tram(b: MeshBatch) -> void:
	var len := 15.0
	var wid := 2.35
	var red := Color("#c62828")
	var cream := Color("#f4e9d0")
	var r := 0.36
	var seg := 2
	for s in seg:
		var x0 := -len / 2 + s * (len / 2) + (0.15 if s == 1 else 0.0)
		var x1 := x0 + len / 2 - 0.15
		b.box(Vector3(x0, 0.35, -wid / 2), Vector3(x1, 1.1, wid / 2), "metal", red)
		b.box(Vector3(x0, 2.15, -wid / 2), Vector3(x1, 3.1, wid / 2), "metal", cream)
		b.box(Vector3(x0 + 0.3, 3.1, -wid / 2 + 0.3), Vector3(x1 - 0.3, 3.3, wid / 2 - 0.3), "matte", Color("#8a939c"))  # roof gear
		# window band: glass with pillars
		for sz in [-1.0, 1.0]:
			b.box(Vector3(x0, 1.1, sz * (wid / 2 - 0.03) - 0.01), Vector3(x1, 2.15, sz * (wid / 2 - 0.03) + 0.01), "glass", GLASS, 16 | 32)
			var n := 6
			for i in n + 1:
				var x := x0 + (x1 - x0) * i / n
				b.box(Vector3(x - 0.06, 1.1, sz * wid / 2 - 0.04), Vector3(x + 0.06, 2.15, sz * wid / 2 + 0.01), "metal", red)
			# doors
			for dx in [0.33, 0.66]:
				var x: float = x0 + (x1 - x0) * dx
				b.box(Vector3(x - 0.55, 0.35, sz * wid / 2 - 0.02), Vector3(x + 0.55, 2.15, sz * wid / 2 + 0.02), "metal", Color("#9a1f1f"), 16 | 32)
				b.box(Vector3(x - 0.45, 1.2, sz * wid / 2 - 0.03), Vector3(x + 0.45, 2.0, sz * wid / 2 + 0.03), "glass", GLASS, 16 | 32)
		b.box(Vector3(x0, 1.1, -wid / 2 + 0.05), Vector3(x1, 2.15, wid / 2 - 0.05), "matte", Color("#3a3028"), 4 | 8)
		for wx in [x0 + 1.2, x1 - 1.2]:
			for sz in [-1.0, 1.0]:
				_wheel(Vector3(wx, r, sz * (wid / 2 - 0.25)), r, 0.18, Color("#6d757d"))
	# articulation bellows
	b.box(Vector3(-0.15, 0.4, -wid / 2 + 0.15), Vector3(0.15, 3.0, wid / 2 - 0.15), "fabric", Color("#2a2c31"))
	# cab windscreens and destination displays at both ends
	for sx in [-1.0, 1.0]:
		var ex: float = sx * len / 2
		b.box(Vector3(ex - 0.01, 1.1, -wid / 2 + 0.1), Vector3(ex + 0.01, 2.2, wid / 2 - 0.1), "glass", GLASS, 1 | 2)
		b.box(Vector3(ex - 0.02, 2.4, -0.7), Vector3(ex + 0.02, 2.75, 0.7), "screen", Color("#ffb347"), 1 | 2)
	_lights(b, len, wid, 0.75)
	# pantograph
	b.box(Vector3(2.0, 3.3, -0.05), Vector3(3.2, 3.36, 0.05), "metal", Color("#3a3d44"))
	b.box(Vector3(2.5, 3.9, -0.6), Vector3(2.6, 3.95, 0.6), "metal", Color("#3a3d44"))
	b.quad(Vector3(2.0, 3.35, 0), Vector3(2.1, 3.35, 0), Vector3(2.6, 3.92, 0), Vector3(2.5, 3.92, 0), Vector3.BACK, "metal", Color("#3a3d44"))


func _bike(b: MeshBatch, col: Color) -> void:
	var r := 0.34
	var fx := 0.55
	var bx := -0.5
	# frame tubes as thin boxes between points (in the x-y plane)
	var tube := func(p0: Vector2, p1: Vector2, th: float, c: Color) -> void:
		var d := p1 - p0
		var n := Vector2(-d.y, d.x).normalized() * th / 2
		var a3 := Vector3(p0.x + n.x, p0.y + n.y, 0)
		var b3 := Vector3(p1.x + n.x, p1.y + n.y, 0)
		var c3 := Vector3(p1.x - n.x, p1.y - n.y, 0)
		var d3 := Vector3(p0.x - n.x, p0.y - n.y, 0)
		var z := Vector3(0, 0, th / 2)
		b.quad(a3 + z, b3 + z, c3 + z, d3 + z, Vector3.BACK, "metal", c)
		b.quad(a3 - z, b3 - z, c3 - z, d3 - z, Vector3.FORWARD, "metal", c)
		b.quad(a3 - z, b3 - z, b3 + z, a3 + z, Vector3(n.x, n.y, 0).normalized(), "metal", c)
		b.quad(d3 - z, c3 - z, c3 + z, d3 + z, Vector3(-n.x, -n.y, 0).normalized(), "metal", c)
	var hub_b := Vector2(bx, r)
	var hub_f := Vector2(fx, r)
	var crank := Vector2(0.0, r - 0.02)
	var seat := Vector2(-0.18, 0.95)
	var head := Vector2(0.42, 0.92)
	tube.call(hub_b, crank, 0.04, col)
	tube.call(hub_b, seat, 0.04, col)
	tube.call(crank, seat, 0.045, col)
	tube.call(crank, head, 0.05, col)
	tube.call(seat + Vector2(0, -0.05), head, 0.045, col)
	tube.call(head, hub_f, 0.04, Color("#9aa4ab"))
	tube.call(head, head + Vector2(0.02, 0.16), 0.035, Color("#9aa4ab"))
	b.block(seat.x - 0.02, 0, 0.24, 0.1, seat.y + 0.02, 0.05, "fabric", Color("#15171c"))
	b.block(head.x + 0.02, 0, 0.05, 0.56, head.y + 0.15, 0.035, "metal", Color("#2a2c31"))
	for sz in [-0.26, 0.26]:
		b.block(head.x + 0.02, sz, 0.06, 0.1, head.y + 0.14, 0.05, "fabric", Color("#15171c"))
	b.cylinder(Vector3(crank.x, crank.y - 0.04, -0.06), 0.08, 0.08, 0.02, "metal", Color("#6d757d"), 10)
	b.box(Vector3(head.x + 0.05, 0.75, -0.06), Vector3(head.x + 0.1, 0.83, 0.06), "screen", HEAD, 1)
	for at in [hub_b, hub_f]:
		var n := Node3D.new()
		n.position = Vector3(at.x, at.y, 0)
		_body.add_child(n)
		var wb := MeshBatch.new()
		# a thin tyre ring + spokes
		for i in 16:
			var a0 := TAU * i / 16.0
			var a1 := TAU * (i + 1) / 16.0
			var p0 := Vector3(cos(a0), sin(a0), 0) * r
			var p1 := Vector3(cos(a1), sin(a1), 0) * r
			var q0 := p0 * 0.86
			var q1 := p1 * 0.86
			for zz in [-0.02, 0.02]:
				wb.quad(p0 + Vector3(0, 0, zz), p1 + Vector3(0, 0, zz), q1 + Vector3(0, 0, zz), q0 + Vector3(0, 0, zz), Vector3(0, 0, signf(zz)), "matte", TYRE)
			wb.quad(p0 + Vector3(0, 0, -0.02), p1 + Vector3(0, 0, -0.02), p1 + Vector3(0, 0, 0.02), p0 + Vector3(0, 0, 0.02), ((p0 + p1) / 2).normalized(), "matte", TYRE)
			if i % 2 == 0:
				wb.box(Vector3(-0.004, -r * 0.85, -0.004), Vector3(0.004, r * 0.85, 0.004), "metal", RIM, 63)
		wb.xf = Transform3D(Basis(Vector3.BACK, PI / 4), Vector3.ZERO)
		wb.box(Vector3(-0.004, -r * 0.85, -0.004), Vector3(0.004, r * 0.85, 0.004), "metal", RIM, 63)
		wb.xf = Transform3D(Basis(Vector3.BACK, -PI / 4), Vector3.ZERO)
		wb.box(Vector3(-0.004, -r * 0.85, -0.004), Vector3(0.004, r * 0.85, 0.004), "metal", RIM, 63)
		wb.xf = Transform3D.IDENTITY
		var mi := MeshInstance3D.new()
		mi.mesh = wb.commit(Materials.get_all())
		n.add_child(mi)
		_wheels.append(n)
	_wheel_r = r
