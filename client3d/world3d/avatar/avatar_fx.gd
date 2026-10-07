## The little animated extras around a character, as in the 2D view: zzz,
## knockout stars, typing / brewing dots, cigarette smoke, coffee steam, the
## smell cloud, soap bubbles, the sweat drop of a tired walk, hiccups,
## throwing up, peeing, the toilet roll. Lives under the avatar root (not
## the turning body), so things rise straight up whatever the pose.
## Pools are made on first use and just hidden when not needed.
extends Node3D

const M = preload("res://world3d/avatar/avatar_mesh.gd")

const SMOKE := Color(0.86, 0.85, 0.82, 0.55)
const STEAM := Color(1, 1, 1, 0.42)
const SMELL := Color(0.52, 0.72, 0.22, 0.42)
const SMELL_LINE := Color(0.42, 0.66, 0.16, 0.85)
const BUBBLE := Color(0.82, 0.93, 1.0, 0.55)
const VOMIT := Color("#9bb83a")
const PEE := Color("#e8d23a")

var _pools := {}     # name -> Array[Node3D]
var _seed := 0.0


func _init(seed_val := 0.0) -> void:
	_seed = seed_val


func _pool(key: String, count: int, maker: Callable) -> Array:
	var p: Array = _pools.get(key, [])
	if p.is_empty():
		for i in count:
			var n: Node3D = maker.call(i)
			n.visible = false
			add_child(n)
			p.append(n)
		_pools[key] = p
	return p


func _hide_unused(active: Dictionary) -> void:
	for key in _pools:
		if not active.has(key):
			for n in _pools[key]:
				n.visible = false


static func _ball(r: float, mat: Material, segs := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = M.sphere(r, segs, maxi(segs / 2, 3))
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _label(text: String, size := 64) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 14
	l.pixel_size = 0.0045
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	l.modulate = Color.WHITE
	l.outline_modulate = Color(M.INK, 1.0)
	l.shaded = false
	return l


## `s` holds what to show and where (all positions local to this node):
##   zzz, stars, dots (color or null), smoke (Vector3 tip or null),
##   steam (Vector3 or null), smell, bubbles (Vector3 or null), sweat,
##   hiccup, vomit (mouth Vector3 or null), pee (Vector3 or null),
##   poop (Vector3 or null), roll; head (Vector3), side (Vector3, the
##   body's right), fwd (Vector3, the body's front).
func update(s: Dictionary, t: float) -> void:
	var active := {}
	var head: Vector3 = s.head
	var top := head + Vector3(0, 0.34, 0)
	t += _seed
	if s.get("zzz", false):
		active["zzz"] = true
		var zs := _pool("zzz", 3, func(_i): return _label("Z", 72))
		for i in zs.size():
			var k := fmod(t * 0.55 + i / 3.0, 1.0)
			var z: Label3D = zs[i]
			z.visible = true
			z.position = top + Vector3(0.12 + k * 0.22 + sin(k * 5.0) * 0.04, k * 0.5 - 0.1, 0)
			z.font_size = int(46 + 40 * k)
			z.modulate = Color(1, 1, 1, sin(k * PI))
			z.outline_modulate = Color(M.INK, sin(k * PI))
	if s.get("stars", false):
		active["stars"] = true
		var st := _pool("stars", 3, func(_i):
			var mi := MeshInstance3D.new()
			mi.mesh = M.cached("star", func(): return M.star(0.1, 0.02))
			mi.material_override = M.mat(Color("#f4d03f"), true, 0.4, 0.6)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			return mi)
		for i in st.size():
			var a := t * 3.2 + i * TAU / 3.0
			var n: Node3D = st[i]
			n.visible = true
			n.position = head + Vector3(cos(a) * 0.32, 0.3 + sin(a * 2.0) * 0.03, sin(a) * 0.32)
			n.rotation = Vector3(0, -a, t * 4.0)
	if s.get("dots") != null:
		active["dots"] = true
		var col: Color = s.dots
		var ds := _pool("dots", 3, func(_i): return _ball(0.035, M.mat(Color.WHITE, true, 0.5)))
		var shown := int(t / 0.3) % 4
		for i in ds.size():
			var d: MeshInstance3D = ds[i]
			d.visible = i < shown
			d.material_override = M.mat(col, true, 0.5)
			d.position = top + Vector3(-0.12 + i * 0.12, 0.02 + sin(t * 6.0 + i) * 0.015, 0)
	if s.get("smoke") != null:
		active["smoke"] = true
		_puffs("smoke", 5, s.smoke, t, 1.6, 0.55, 0.035, 0.09, M.fx_mat(SMOKE))
	if s.get("steam") != null:
		active["steam"] = true
		_puffs("steam", 3, s.steam, t, 1.3, 0.28, 0.018, 0.045, M.fx_mat(STEAM))
	if s.get("smell", false):
		active["smell"] = true
		var ps := _pool("smell", 4, func(_i): return _ball(0.12, M.fx_mat(SMELL), 10))
		for i in ps.size():
			var k := fmod(t * 0.35 + i / 4.0, 1.0)
			var a := i * 1.7 + t * 0.4
			var p: Node3D = ps[i]
			p.visible = true
			p.position = Vector3(cos(a) * 0.32, 0.3 + k * 1.4, sin(a) * 0.32)
			p.scale = Vector3.ONE * (0.6 + k * 1.2) * sin(k * PI)
		var ls := _pool("smell_lines", 3, func(_i):
			var pts := PackedVector3Array()
			for j in 9:
				pts.append(Vector3(sin(j * 1.1) * 0.05, j * 0.05, 0))
			var mi := MeshInstance3D.new()
			mi.mesh = M.cached("stink", func(): return M.tube(pts, 0.012, 5))
			mi.material_override = M.mat(SMELL_LINE, false, 0.9)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			return mi)
		for i in ls.size():
			var k := fmod(t * 0.5 + i / 3.0, 1.0)
			var l: Node3D = ls[i]
			l.visible = true
			l.position = Vector3(-0.3 + i * 0.3, head.y - 0.1 + k * 0.6, 0.05)
			l.rotation.y = t * 0.3
			l.scale = Vector3.ONE * sin(k * PI) * 1.2
	if s.get("bubbles") != null:
		active["bubbles"] = true
		var bs := _pool("bubbles", 6, func(_i): return _ball(0.03, M.fx_mat(BUBBLE)))
		var at: Vector3 = s.bubbles
		for i in bs.size():
			var k := fmod(t * 0.9 + i / 6.0, 1.0)
			var b: Node3D = bs[i]
			b.visible = true
			b.position = at + Vector3(sin(i * 2.3) * 0.1, k * 0.45, cos(i * 1.7) * 0.06)
			b.scale = Vector3.ONE * (0.6 + 0.8 * k) * (1.0 - k * k)
	if s.get("sweat", false) and fmod(t, 1.0) < 0.75:
		active["sweat"] = true
		var sw := _pool("sweat", 1, func(_i):
			var root := Node3D.new()
			var mat := M.mat(Color("#9fd8ff"), true, 0.15)
			var b := _ball(0.03, mat)
			root.add_child(b)
			var c := MeshInstance3D.new()
			c.mesh = M.cyl(0.0, 0.029, 0.05, 8)
			c.material_override = mat
			c.position.y = 0.035
			root.add_child(c)
			return root)
		var k := fmod(t, 1.0)
		sw[0].visible = true
		sw[0].position = head + s.side * 0.27 + Vector3(0, 0.1 - k * 0.1, 0) + s.fwd * 0.05
	if s.get("hiccup", false):
		active["hiccup"] = true
		var h := _pool("hiccup", 1, func(_i): return _label("hyk!", 44))
		var period := 2.4
		var k := fmod(t, period) / 0.55
		var l: Label3D = h[0]
		l.visible = k < 1.0
		l.position = top + s.side * 0.25 + Vector3(0, k * 0.15 - 0.1, 0)
		l.modulate = Color(1, 1, 1, 1.0 - k)
		l.outline_modulate = Color(M.INK, 1.0 - k)
	if s.get("vomit") != null:
		active["vomit"] = true
		var from: Vector3 = s.vomit
		var to: Vector3 = Vector3(from.x, 0.02, from.z) + s.fwd * 0.18
		_stream("vomit", 10, from, to, 0.04, t, M.mat(VOMIT, true, 0.3), 0.0)
	if s.get("pee") != null:
		active["pee"] = true
		var from: Vector3 = s.pee
		var to: Vector3 = Vector3(from.x, 0.02, from.z) + s.fwd * 0.45
		_stream("pee", 9, from, to, 0.016, t, M.mat(PEE, false, 0.2), 0.12)
	if s.get("poop") != null:
		active["poop"] = true
		var pp := _pool("poop", 1, func(_i): return _ball(0.04, M.mat(Color("#6b4423"), true, 0.6)))
		var from: Vector3 = s.poop
		var k := fmod(t / 0.9, 1.0)
		pp[0].visible = true
		pp[0].position = from.lerp(Vector3(from.x, 0.1, from.z), k * k)
	if s.get("roll", false):
		active["roll"] = true
		var r := _pool("roll", 1, func(_i):
			var root := Node3D.new()
			var a := MeshInstance3D.new()
			a.mesh = M.cyl(0.07, 0.07, 0.11, 14)
			a.material_override = M.mat(Color("#f6f6f2"), true, 0.9)
			a.rotation.z = PI / 2
			root.add_child(a)
			var b := MeshInstance3D.new()
			b.mesh = M.cyl(0.026, 0.026, 0.115, 10)
			b.material_override = M.mat(Color("#b8a58a"), false)
			b.rotation.z = PI / 2
			root.add_child(b)
			return root)
		r[0].visible = true
		r[0].position = top + Vector3(0, 0.08 + sin(t * 2.4) * 0.03, 0)
		r[0].rotation.y = sin(t * 1.3) * 0.5
	_hide_unused(active)


## Puffs from `at` rising and growing, then shrinking away.
func _puffs(key: String, count: int, at: Vector3, t: float, period: float, rise: float, r0: float, r1: float, mat: Material) -> void:
	var ps := _pool(key, count, func(_i): return _ball(1.0, mat, 8))
	for i in ps.size():
		var k := fmod(t / period + float(i) / count, 1.0)
		var p: Node3D = ps[i]
		p.visible = true
		p.position = at + Vector3(sin(k * TAU + i) * 0.04 * (1.0 + k), k * rise, cos(k * 4.0 + i) * 0.03)
		p.scale = Vector3.ONE * lerpf(r0, r1, k) * minf(1.0, (1.0 - k) * 3.0)


## A wobbly stream of drops from `from` arcing to `to` (vomit, pee).
func _stream(key: String, count: int, from: Vector3, to: Vector3, r: float, t: float, mat: Material, arc_h: float) -> void:
	var ps := _pool(key, count, func(_i): return _ball(1.0, mat, 6))
	for i in ps.size():
		var k := fmod(float(i) / count + t * 2.2, 1.0)
		var p: Node3D = ps[i]
		p.visible = true
		var q := from.lerp(to, k) + Vector3(0, sin(k * PI) * arc_h, 0)
		q += Vector3(sin(t * 17.0 + k * 9.0), 0, cos(t * 13.0 + k * 7.0)) * 0.012
		p.position = q
		p.scale = Vector3.ONE * r * (1.25 - 0.4 * k)
