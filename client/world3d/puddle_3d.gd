## Puddles on the floor (PuddleViews in game.puddle_layer): decals - neon
## yellow, vomit, blood (glossy), a skid mark on the toilet bowl - and a
## little 3D pile with circling flies. The blob textures are drawn once per
## kind; every puddle turns them by its own angle.
extends Node3D

const Coords = preload("res://world3d/coords.gd")

## kind -> [size m, base colour, edge colour, roughness, emission]
const KINDS := {
	"pee": [0.95, Color("#f4ec1a"), Color("#c8b400"), 0.05, 0.35],
	"vomit": [0.95, Color("#b9b44e"), Color("#7d7430"), 0.25, 0.0],
	"blood": [0.6, Color("#7e0f13"), Color("#4a0508"), 0.08, 0.0],
	"stain": [0.32, Color("#6b4423"), Color("#4a2e17"), 0.6, 0.0],
}

var wv: Node3D
var _items := {}       # PuddleView instance id -> Node3D
var _tex := {}         # kind -> [albedo, orm, emission]
var _fly_mat := StandardMaterial3D.new()


func setup(p_wv: Node3D) -> void:
	wv = p_wv
	name = "Puddles"
	_fly_mat.albedo_color = Color("#15120f")


static func kind_of(pv) -> String:
	if pv.stain:
		return "stain"
	if pv.poop:
		return "poop"
	if pv.blood:
		return "blood"
	return "vomit" if pv.vomit else "pee"


func update() -> void:
	var layer: Node = wv.game.get("puddle_layer")
	if layer == null:
		return
	var seen := {}
	var t := Time.get_ticks_msec() / 1000.0
	for pv in layer.get_children():
		if not (pv is Node2D) or not ("poop" in pv):
			continue
		var id: int = pv.get_instance_id()
		seen[id] = true
		var n: Node3D = _items.get(id)
		var kind := kind_of(pv)
		if n == null or n.get_meta("kind") != kind:
			if n:
				n.queue_free()
			n = _make(kind, id)
			add_child(n)
			_items[id] = n
		n.visible = pv.visible
		n.position = wv.px_to_world(pv.position)
		if kind == "stain":
			n.position.y += 0.2  # projected onto the bowl
		if kind == "poop":
			for i in 2:
				var a := t * (3.0 + i) + i * PI
				n.get_child(3 + i).position = Vector3(cos(a) * 0.32, 0.45 + sin(a * 1.7) * 0.08, sin(a) * 0.32)
	for id in _items.keys():
		if not seen.has(id):
			_items[id].queue_free()
			_items.erase(id)


func _make(kind: String, id: int) -> Node3D:
	if kind == "poop":
		return _make_pile()
	var spec: Array = KINDS[kind]
	var tx: Array = _textures(kind)
	var d := Decal.new()
	d.set_meta("kind", kind)
	d.size = Vector3(spec[0], 0.5 if kind != "stain" else 0.6, spec[0] * (0.75 if kind != "stain" else 0.6))
	d.texture_albedo = tx[0]
	d.texture_orm = tx[1]
	if spec[4] > 0.0:
		d.texture_emission = tx[2]
		d.emission_energy = spec[4]
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	d.cull_mask = 1
	d.rotation.y = float(hash(id) % 628) / 100.0
	return d


## Albedo (with alpha), ORM (wet = smooth), emission of a blobby puddle.
func _textures(kind: String) -> Array:
	if _tex.has(kind):
		return _tex[kind]
	var spec: Array = KINDS[kind]
	var s := 128
	var alb := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var orm := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var blobs := [[Vector2.ZERO, 0.42]]
	for i in 5:
		var a := TAU * i / 5.0 + rng.randf_range(-0.5, 0.5)
		blobs.append([Vector2(cos(a), sin(a)) * rng.randf_range(0.25, 0.45), rng.randf_range(0.15, 0.28)])
	if kind == "stain":
		blobs = [[Vector2(-0.3, -0.1), 0.18], [Vector2(0.0, 0.0), 0.2], [Vector2(0.3, 0.1), 0.16], [Vector2(0.1, 0.3), 0.12]]
	for y in s:
		for x in s:
			var p := Vector2(x, y) / s * 2.0 - Vector2.ONE
			var f := 0.0
			for b in blobs:
				f = maxf(f, 1.0 - p.distance_to(b[0]) / b[1])
			var a := clampf(f * 6.0, 0.0, 1.0)
			var edge := 1.0 - clampf(f * 3.0, 0.0, 1.0)
			var c: Color = spec[1].lerp(spec[2], edge * 0.8)
			if kind == "vomit" and rng.randf() < 0.05:
				c = c.darkened(0.35)
			alb.set_pixel(x, y, Color(c, a * (0.9 if kind != "stain" else 0.8)))
			orm.set_pixel(x, y, Color(1.0, spec[3], 0.0, 1.0))
	alb.generate_mipmaps()
	var em := alb.duplicate()
	_tex[kind] = [ImageTexture.create_from_image(alb), ImageTexture.create_from_image(orm), ImageTexture.create_from_image(em)]
	return _tex[kind]


## The brown swirl of three blobs, a shine, two flies.
func _make_pile() -> Node3D:
	var root := Node3D.new()
	root.set_meta("kind", "poop")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#6b4423")
	mat.roughness = 0.35
	for b in [[0.0, 0.16], [0.11, 0.12], [0.2, 0.08]]:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = b[1]
		sm.height = b[1] * 1.3
		sm.radial_segments = 12
		sm.rings = 6
		mi.mesh = sm
		mi.material_override = mat
		mi.position = Vector3(0, b[0] + b[1] * 0.5, 0)
		root.add_child(mi)
	for i in 2:
		var fly := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.025
		fm.height = 0.05
		fm.radial_segments = 6
		fm.rings = 3
		fly.mesh = fm
		fly.material_override = _fly_mat
		root.add_child(fly)
	return root
