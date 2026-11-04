## Trees on the lawns: where there is open grass all around, on a jittered
## grid (deterministic, the same on every client). Two layers:
## `ground` - the trunk and the shade under the crown, with patches of
## sunlight moving through the leaves (dapple.gdshader) - drawn over the
## floor, under the people; `canopy` - the crowns, over the people, swaying a
## little in the wind and see-through over the local player (`focus`).
## Only decoration: the server knows nothing about trees (they don't block).
extends Node2D

const DAPPLE = preload("res://map/dapple.gdshader")
const KINDS := ["leafy", "leafy", "leafy", "blossom", "leafy", "leafy", "autumn", "leafy", "blossom"]

var ground := Node2D.new()
var canopy := Node2D.new()
var _trunks := Node2D.new()   # over the shade, without the sun spots
## The local player: crowns over them fade out.
var focus: Node2D = null
var _trees: Array = []   # [{pos, r, kind, node}]


## Spots for trees on this floor: [{pos: Vector2 (px), r: float (px), kind}].
static func places(map) -> Array:
	var out := []
	var tp: float = map.tile_px
	var step := 5
	for gy in range(0, map.height, step):
		for gx in range(0, map.width, step):
			var h := absi((gx * 73856093) ^ (gy * 19349663) ^ 0x5bd1e995)
			if h % 5 == 0:
				continue  # a gap now and then, so it isn't an orchard
			var tx := gx + 1 + h % 3
			var ty := gy + 1 + (h / 7) % 3
			if not _open_grass(map, tx, ty, 2):
				continue
			var r := tp * (1.9 + float((h / 31) % 5) * 0.15)
			var p := (Vector2(tx, ty) + Vector2(0.5, 0.5)) * tp + Vector2(float(h % 7) - 3.0, float((h / 11) % 7) - 3.0)
			out.append({"pos": p, "r": r, "kind": KINDS[(h / 13) % KINDS.size()]})
	return out


static func _open_grass(map, tx: int, ty: int, rad: int) -> bool:
	for y in range(ty - rad, ty + rad + 1):
		for x in range(tx - rad, tx + rad + 1):
			if x < 0 or y < 0 or x >= map.width or y >= map.height:
				return false
			var c: String = map.tile_chars[y * map.width + x]
			if not map.legend.has(c) or map.legend[c]["type"] != "grass":
				return false
			if not map.room_outdoor.has(map.room_at_tile(x, y)):
				return false
	return true


func build(map) -> void:
	add_child(ground)
	var mat := ShaderMaterial.new()
	mat.shader = DAPPLE
	ground.material = mat
	ground.draw.connect(_draw_ground)
	ground.add_child(_trunks)
	_trunks.draw.connect(_draw_trunks)
	canopy.z_index = 1
	for t in places(map):
		var n := Crown.new()
		n.kind = t.kind
		n.r = t.r
		n.position = t.pos + Vector2(0, -t.r * 0.55)  # the crown sits up the trunk
		n.phase = fmod(t.pos.x * 0.37 + t.pos.y * 0.11, TAU)
		canopy.add_child(n)
		t["node"] = n
		_trees.append(t)
	ground.queue_redraw()
	_trunks.queue_redraw()
	set_process(not _trees.is_empty())


func _draw_ground() -> void:
	for t in _trees:
		var p: Vector2 = t.pos
		var r: float = t.r
		# The shade of the crown, falling down and to the right of the trunk.
		var c: Vector2 = p + Vector2(r * 0.25, -r * 0.2)
		for k in 4:
			var rr := r * (1.15 - k * 0.12)
			ground.draw_set_transform(c, 0.0, Vector2(1.0, 0.8))
			ground.draw_circle(Vector2.ZERO, rr, Color(0.03, 0.07, 0.1, 0.17))
		ground.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The trunks and their roots.
func _draw_trunks() -> void:
	for t in _trees:
		var p: Vector2 = t.pos
		_trunks.draw_circle(p + Vector2(0.8, 1.0), 3.6, Color(0.05, 0.05, 0.08, 0.3))
		for a in [0.4, 2.2, 3.6, 5.1]:
			_trunks.draw_line(p, p + Vector2.from_angle(a) * 4.2, Color("#5a3d27"), 1.6, true)
		_trunks.draw_rect(Rect2(p + Vector2(-2.0, -t.r * 0.5), Vector2(4.0, t.r * 0.5)), Color("#5a3d27"))
		_trunks.draw_rect(Rect2(p + Vector2(-2.0, -t.r * 0.5), Vector2(1.4, t.r * 0.5)), Color("#7a5538"))
		_trunks.draw_circle(p, 2.8, Color("#4a3121"))
		_trunks.draw_circle(p + Vector2(-0.6, -0.6), 2.0, Color("#6e4b31"))


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var at: Vector2 = focus.position if focus and is_instance_valid(focus) else Vector2.INF
	for tree in _trees:
		var n: Crown = tree.node
		n.rotation = sin(t * 0.7 + n.phase) * 0.018
		n.scale = Vector2.ONE * (1.0 + sin(t * 1.1 + n.phase * 2.0) * 0.008)
		var under := at != Vector2.INF and at.distance_to(n.position) < n.r * 1.05
		n.modulate.a = move_toward(n.modulate.a, 0.35 if under else 1.0, delta * 3.0)


## One tree's crown: a handful of leafy clumps (drawn back to front), each
## shaded on its own - dark underneath and to the right, lit at the top
## left - with small leaf dabs over them; blossom trees get petals.
class Crown extends Node2D:
	var kind := "leafy"
	var r := 32.0
	var phase := 0.0

	func _draw() -> void:
		var cols: Array
		match kind:
			"blossom":
				cols = [Color("#7a4057"), Color("#b86b88"), Color("#e297b0"), Color("#f7c9d8")]
			"autumn":
				cols = [Color("#5e3a1c"), Color("#9c5a26"), Color("#c98a3a"), Color("#e6b860")]
			_:
				cols = [Color("#1f3f24"), Color("#2f5f31"), Color("#4a8a3c"), Color("#8cc05a")]
		var rng := RandomNumberGenerator.new()
		rng.seed = int(phase * 1000.0) + 7
		var clumps := []
		var n := 6 + rng.randi() % 4
		for i in n:
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * r * 0.5
			clumps.append([Vector2.from_angle(a) * Vector2(d * 1.1, d * 0.9), r * (0.34 + rng.randf() * 0.16)])
		clumps.append([Vector2(0, 0), r * 0.5])
		clumps.sort_custom(func(p, q): return p[0].y < q[0].y)
		# A dark rim and the shadow side under everything.
		for c in clumps:
			draw_circle(c[0] + Vector2(0.6, 1.0), c[1] + 1.2, cols[0])
		for c in clumps:
			var p: Vector2 = c[0]
			var cr: float = c[1]
			draw_circle(p, cr, cols[1])
			draw_circle(p + Vector2(-0.18, -0.22) * cr, cr * 0.74, cols[2])
			draw_circle(p + Vector2(-0.34, -0.4) * cr, cr * 0.36, cols[3].lerp(cols[2], 0.35))
			# Leaf dabs: light ones up and left, dark ones down and right.
			for k in 7:
				var q := p + Vector2.from_angle(rng.randf() * TAU) * cr * 0.8 * sqrt(rng.randf())
				var lit := (q - p).dot(Vector2(-0.7, -0.7)) > 0.0
				draw_set_transform(q, rng.randf() * PI, Vector2(1.0, 0.55))
				draw_circle(Vector2.ZERO, 1.3 + rng.randf() * 0.7, Color(cols[3], 0.7) if lit else Color(cols[0], 0.45))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if kind == "blossom":
			for i in 18:
				var q := Vector2.from_angle(rng.randf() * TAU) * r * 0.75 * sqrt(rng.randf())
				draw_circle(q, 0.8, Color("#fff4f7", 0.9))
