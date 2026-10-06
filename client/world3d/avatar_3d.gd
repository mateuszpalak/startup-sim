## A character in 3D: a stylised, toy-like figure (big round head with a
## face, rounded torso, arms with hands, legs with shoes) mirroring a 2D
## PlayerView / RemotePlayer, which still owns the state (position, facing,
## status, appearance, held item, nick, bubble). world_view.gd calls
## `sync()` every frame; nothing here talks to the network.
##
## Everything is procedural: the rig is a tree of joints posed every frame
## from the view's state (walk / slow walk, idle breathing and glances,
## sitting at a desk, on a sofa or a toilet, lying, drunk sway, typing,
## talking, smoking, washing, throwing up, fighting ...). The extras (zzz,
## stars, smoke ...) are in avatar/avatar_fx.gd, held things in
## avatar/held_item_3d.gd, meshes and materials in avatar/avatar_mesh.gd.
##
## Model space: feet at the origin, front = +z, 1 unit = 1 m. Joint pairs
## are [left (-x), right (+x)].
extends Node3D

const Coords = preload("res://world3d/coords.gd")
const PlayerView = preload("res://game/player_view.gd")
const ItemArt = preload("res://game/item_art.gd")
const M = preload("res://world3d/avatar/avatar_mesh.gd")
const Held = preload("res://world3d/avatar/held_item_3d.gd")
const Fx = preload("res://world3d/avatar/avatar_fx.gd")

# Proportions (metres).
const HIP_H := 0.6          # hip joints above the floor (standing)
const THIGH := 0.27
const SHIN := 0.26
const UPPER_ARM := 0.21
const FOREARM := 0.19
const HEAD_R := 0.25
## Eye line above the head centre (the face sits a bit high: seen from above).
const EYE_Y := 0.03
const NECK_Y := 0.44        # neck base above the pelvis joint
const SHOULDER := Vector3(0.195, 0.37, 0.0)
const SEAT_Y := 0.5         # pelvis height when seated (chairs ~0.46)
const LIE_Y := 0.13
## Torso shape: (radius, y) over the pelvis joint; squashed front-to-back.
const TORSO := [Vector2(0.0, -0.012), Vector2(0.158, -0.012), Vector2(0.168, 0.03), Vector2(0.176, 0.12),
	Vector2(0.174, 0.22), Vector2(0.166, 0.3), Vector2(0.15, 0.36), Vector2(0.118, 0.405),
	Vector2(0.065, 0.435), Vector2(0.0, 0.442)]
const TORSO_DEPTH := 0.78
const SITTING := [PlayerView.ACT_COMPUTER, PlayerView.ACT_SOFA, PlayerView.ACT_TOILET, PlayerView.ACT_POOPING]
## Looks wearing long sleeves (the rest: T-shirts / polos).
const LONG_SLEEVES := [PlayerView.LOOK_PORTER, PlayerView.LOOK_OFFICE, PlayerView.LOOK_GUARD,
	PlayerView.LOOK_POLICE, PlayerView.LOOK_FIREFIGHTER]
const FRAME := Color("#3a2a20")

## The 2D view this avatar follows.
var view: Node2D

# rig
var _body := Node3D.new()       # yaw + drunk sway, pivots at the feet
var _pelvis := Node3D.new()
var _spine := Node3D.new()
var _chest := Node3D.new()      # squashed torso shape + clothing panels
var _neck := Node3D.new()
var _head := Node3D.new()       # at the head centre
var _hip: Array[Node3D] = [Node3D.new(), Node3D.new()]
var _knee: Array[Node3D] = [Node3D.new(), Node3D.new()]
var _shoulder: Array[Node3D] = [Node3D.new(), Node3D.new()]
var _elbow: Array[Node3D] = [Node3D.new(), Node3D.new()]
var _hand: Array[Node3D] = [Node3D.new(), Node3D.new()]
# face
var _eyes: Array[Node3D] = []
var _eye_x: Array[Node3D] = []   # x_x crosses (knocked out)
var _brows: Array[Node3D] = []
var _smile: MeshInstance3D
var _mouth_open: MeshInstance3D
var _mouth_flat: MeshInstance3D
# look-dependent pieces, rebuilt when the look changes
var _hair := Node3D.new()
var _outfit := Node3D.new()      # uniform details on the chest
var _extras := Node3D.new()      # on the neck / limbs (pearls, stripes)
var _hat := Node3D.new()
var _tool: Node3D = null         # the cleaner's mop
var _held_node: Node3D = null
var _held_kind := 0
var _umbrella: Node3D = null
var _cig: Node3D = null
var _ring := MeshInstance3D.new()
var _fx: Node3D

## role -> [[MeshInstance3D, outline]]; colours come from the look.
var _roles := {}
var _colors := {}
var _look := ""     # appearance key last applied

# motion state
var _yaw := 0.0
var _phase := 0.0
var _last := Vector3.INF
var _moving := 0.0
var _speed := 0.0
var _t := 0.0
var _seed := 0.0
var _blink_at := 2.0
var _glance := 0.0
var _glance_goal := 0.0
var _glance_at := 3.0
var _rng := RandomNumberGenerator.new()


# ------------------------------------------------------------------ building

func _add(parent: Node3D, mesh: Mesh, role: String, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE, outline := true, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	if not _roles.has(role):
		_roles[role] = []
	_roles[role].append([mi, outline])
	if _colors.has(role):
		mi.material_override = M.mat(_colors[role], outline)
	return mi


## A part with a fixed colour (not tied to the look).
func _fixed(parent: Node3D, mesh: Mesh, col: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE, outline := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = M.mat(col, outline)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	if not outline:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _set_color(role: String, col: Color) -> void:
	if _colors.get(role) == col:
		return
	_colors[role] = col
	for e in _roles.get(role, []):
		(e[0] as MeshInstance3D).material_override = M.mat(col, e[1])


static func _torso_r(y: float) -> float:
	for i in TORSO.size() - 1:
		var a: Vector2 = TORSO[i]
		var b: Vector2 = TORSO[i + 1]
		if y >= a.y and y <= b.y and b.y > a.y:
			return lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
	return 0.0


## A piece of clothing hugging the torso between heights y0..y1 over the
## angles a0..a1 (0 = front).
static func _torso_band(y0: float, y1: float, grow := 1.03, a0 := 0.0, a1 := TAU, steps := 6) -> Mesh:
	var key := "band%.3f/%.3f/%.3f/%.3f/%.3f" % [y0, y1, grow, a0, a1]
	return M.cached(key, func():
		var prof := PackedVector2Array()
		for k in steps + 1:
			var y := lerpf(y0, y1, float(k) / steps)
			prof.append(Vector2(_torso_r(y) * grow, y))
		return M.lathe(prof, 22 if a1 - a0 > PI else 10, a0, a1))


## A point on the head surface (head-centre space) at (x, y), pushed out.
static func _surf(x: float, y: float, out := 0.0) -> Vector3:
	return Vector3(x, y, sqrt(maxf(HEAD_R * HEAD_R - x * x - y * y, 0.0)) + out)


## A pivot sitting on the head surface, its +z along the surface normal.
func _face_pivot(x: float, y: float, out := 0.0, parent: Node3D = null) -> Node3D:
	var p := Node3D.new()
	var at := _surf(x, y, out)
	p.position = at
	p.basis = Basis.looking_at(-at.normalized(), Vector3.UP)
	(parent if parent else _head).add_child(p)
	return p


func setup(p_view: Node2D) -> void:
	view = p_view
	_seed = float(view.get_instance_id() % 1000) * 0.137
	_rng.seed = view.get_instance_id()
	_blink_at = _rng.randf_range(0.5, 4.0)
	_set_color("shoe", Color("#2a2420"))
	_set_color("eye", M.INK)
	_set_color("white", Color("#ffffff"))
	_set_color("mouth", Color("#5a2626"))
	add_child(_body)
	_body.add_child(_pelvis)
	_pelvis.position.y = HIP_H
	# hips (pants) and legs
	_add(_pelvis, M.cached("hips", func(): return M.lathe(PackedVector2Array([Vector2(0, -0.1),
		Vector2(0.09, -0.098), Vector2(0.14, -0.07), Vector2(0.158, -0.02), Vector2(0.155, 0.03), Vector2(0.0, 0.035)]), 18)),
		"pants", Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, TORSO_DEPTH + 0.04))
	for i in 2:
		var sx := -1.0 if i == 0 else 1.0
		_hip[i].position = Vector3(sx * 0.082, -0.03, 0)
		_pelvis.add_child(_hip[i])
		_add(_hip[i], M.capsule(0.07, THIGH + 0.1), "pants", Vector3(0, -THIGH / 2, 0))
		_knee[i].position.y = -THIGH
		_hip[i].add_child(_knee[i])
		_add(_knee[i], M.capsule(0.062, SHIN + 0.08), "pants", Vector3(0, -SHIN / 2 + 0.01, 0))
		# shoe: a rounded clog, toe forward
		_add(_knee[i], M.capsule(0.062, 0.24), "shoe", Vector3(0, -SHIN - 0.005, 0.045), Vector3(PI / 2, 0, 0), Vector3(1.05, 1.0, 0.72))
	# torso
	_pelvis.add_child(_spine)
	_chest.scale = Vector3(1, 1, TORSO_DEPTH)
	_spine.add_child(_chest)
	_add(_chest, M.cached("torso", func(): return M.lathe(PackedVector2Array(TORSO), 22)), "shirt")
	_chest.add_child(_outfit)
	_neck.position.y = NECK_Y - 0.03
	_spine.add_child(_neck)
	_add(_neck, M.cyl(0.062, 0.07, 0.1, 10), "skin", Vector3(0, 0.03, 0), Vector3.ZERO, Vector3.ONE, false)
	_neck.add_child(_extras)
	# arms
	for i in 2:
		var sx := -1.0 if i == 0 else 1.0
		_shoulder[i].position = Vector3(sx * SHOULDER.x, SHOULDER.y, 0)
		_spine.add_child(_shoulder[i])
		_add(_shoulder[i], M.sphere(0.066, 12, 7), "shirt", Vector3(0, -0.01, 0))
		_add(_shoulder[i], M.capsule(0.058, UPPER_ARM + 0.08), "shirt", Vector3(0, -UPPER_ARM / 2, 0))
		_elbow[i].position.y = -UPPER_ARM
		_shoulder[i].add_child(_elbow[i])
		_add(_elbow[i], M.capsule(0.05, FOREARM + 0.06), "sleeve", Vector3(0, -FOREARM / 2, 0))
		_hand[i].position.y = -FOREARM - 0.04
		_elbow[i].add_child(_hand[i])
		_add(_hand[i], M.sphere(0.06, 12, 7), "skin", Vector3.ZERO, Vector3.ZERO, Vector3(0.9, 1.0, 0.9))
		_add(_hand[i], M.sphere(0.024, 8, 5), "skin", Vector3(-sx * 0.045, 0.012, 0.03), Vector3.ZERO, Vector3.ONE, false, false)  # thumb
	# head
	_head.position = Vector3(0, 0.06 + HEAD_R - 0.03, 0)
	_neck.add_child(_head)
	_add(_head, M.sphere(HEAD_R, 26, 16), "skin")
	for sx in [-1.0, 1.0]:
		_add(_head, M.sphere(0.05, 10, 6), "skin", Vector3(sx * (HEAD_R - 0.005), -0.02, -0.01), Vector3.ZERO, Vector3(0.45, 1.0, 0.75))
	_build_face()
	_head.add_child(_hair)
	_head.add_child(_hat)
	# own character: a soft ring under the feet
	_ring.mesh = M.torus(0.36, 0.43, 32)
	_ring.material_override = M.fx_mat(Color(1.0, 0.92, 0.55, 0.75))
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position.y = 0.02
	_ring.scale = Vector3(1, 0.15, 1)
	_ring.visible = false
	add_child(_ring)
	_fx = Fx.new(_seed)
	add_child(_fx)
	_apply_look()


func _build_face() -> void:
	for sx in [-1.0, 1.0]:
		# eyes: dark ovals with a glint (like the 2D ones)
		var e := _face_pivot(sx * 0.088, EYE_Y, -0.012)
		_add(e, M.sphere(0.05, 12, 8), "eye", Vector3.ZERO, Vector3.ZERO, Vector3(0.68, 1.0, 0.42), false, false)
		_add(e, M.sphere(0.014, 6, 4), "white", Vector3(-0.012, 0.018, 0.019), Vector3.ZERO, Vector3.ONE, false, false)
		_eyes.append(e)
		var x := _face_pivot(sx * 0.088, EYE_Y, -0.004)
		var cross := M.cached("xeye", func(): return M.tube(PackedVector3Array([Vector3(-0.035, -0.035, 0), Vector3(0.035, 0.035, 0)]), 0.009, 5))
		_add(x, cross, "eye", Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false, false)
		_add(x, cross, "eye", Vector3.ZERO, Vector3(0, 0, PI / 2), Vector3.ONE, false, false)
		x.visible = false
		_eye_x.append(x)
		# brows
		var b := _face_pivot(sx * 0.09, EYE_Y + 0.085, -0.004)
		_add(b, M.cached("brow", func(): return M.tube(M.arc(Vector3(0, -0.05, 0), 0.06, PI * 0.36, PI * 0.64, 6), 0.011, 5)), "brow", Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false, false)
		_brows.append(b)
		# cheeks
		var c := _face_pivot(sx * 0.145, EYE_Y - 0.075, -0.012)
		_add(c, M.sphere(0.045, 10, 6), "cheek", Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.62, 0.3), false, false)
	# nose
	var n := _face_pivot(0.0, EYE_Y - 0.045, -0.006)
	_add(n, M.sphere(0.026, 10, 6), "nose", Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.85, 0.8), false, false)
	# mouth: a smile, an open oval (talking, shock) or a flat line (tired)
	var m := _face_pivot(0.0, EYE_Y - 0.105, -0.002)
	_smile = _add(m, M.cached("smile", func(): return M.tube(M.arc(Vector3(0, 0.035, 0), 0.045, PI * 1.25, PI * 1.75, 8), 0.0085, 5)), "mouth", Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false, false)
	_mouth_open = _add(m, M.sphere(0.034, 12, 6), "mouth", Vector3(0, -0.004, -0.006), Vector3.ZERO, Vector3(1.0, 0.7, 0.35), false, false)
	_mouth_flat = _add(m, M.cached("flatmouth", func(): return M.tube(PackedVector3Array([Vector3(-0.03, 0, 0), Vector3(0.03, 0, 0)]), 0.008, 5)), "mouth", Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false, false)


# ---------------------------------------------------------------------- look

func _apply_look() -> void:
	var look: int = view.look
	var key := "%s|%s|%s|%s|%d|%d|%s" % [view.skin, view.hair, view.shirt, view.pants, view.hair_style, look, view.tie]
	if key == _look:
		return
	_look = key
	var skin: Color = view.skin
	_set_color("skin", skin)
	_set_color("hair", view.hair)
	_set_color("brow", (view.hair as Color).darkened(0.35) if look != PlayerView.LOOK_PORTER else Color("#8a8580"))
	_set_color("shirt", view.shirt)
	_set_color("sleeve", view.shirt if look in LONG_SLEEVES else skin)
	_set_color("pants", view.pants)
	_set_color("shoe", Color("#2a2420") if look != PlayerView.LOOK_FIREFIGHTER else Color("#141414"))
	_build_hair(look)
	_build_outfit(look)


## Free the look-dependent children of `n` (and forget their roles).
func _clear(n: Node3D) -> void:
	for c in n.get_children():
		for role in _roles:
			_roles[role] = _roles[role].filter(func(e): return e[0] != c and not c.is_ancestor_of(e[0]))
		n.remove_child(c)
		c.queue_free()


func _build_hair(look: int) -> void:
	_clear(_hair)
	_clear(_hat)
	var hs: int = view.hair_style
	var r := HEAD_R * 1.075
	var covered := look in [PlayerView.LOOK_POLICE, PlayerView.LOOK_FIREFIGHTER]
	if not covered and hs != 5:
		match hs:
			0:  # short, with a side fringe
				_add(_hair, M.cached("hair0", func(): return M.hair_cap(r, 52.0, 96.0, 112.0, 0.03)), "hair")
				_add(_hair, M.sphere(0.12, 12, 7), "hair", Vector3(-0.07, 0.15, 0.15), Vector3(0, 0, 0.5), Vector3(1.0, 0.42, 0.55))
			1:  # long: down to the shoulders, framing the face
				_add(_hair, M.cached("hair1", func(): return M.hair_cap(r, 50.0, 112.0, 128.0, 0.06)), "hair")
				_add(_hair, M.sphere(HEAD_R, 16, 10), "hair", Vector3(0, -0.15, -0.1), Vector3(-0.15, 0, 0), Vector3(1.04, 1.05, 0.62))
				for sx in [-1.0, 1.0]:
					_add(_hair, M.capsule(0.065, 0.32), "hair", Vector3(sx * 0.2, -0.16, 0.02), Vector3(0.05, 0, sx * -0.1))
			2:  # bun on top
				_add(_hair, M.cached("hair2", func(): return M.hair_cap(r, 50.0, 96.0, 112.0, 0.0)), "hair")
				_add(_hair, M.sphere(0.105, 14, 8), "hair", Vector3(0, 0.24, -0.08))
				_add(_hair, M.torus(0.06, 0.085, 14), "hair", Vector3(0, 0.19, -0.065), Vector3(-0.35, 0, 0))
			3:  # spiky
				_add(_hair, M.cached("hair3", func(): return M.hair_cap(r, 58.0, 96.0, 112.0, 0.0)), "hair")
				var spikes := [Vector2(0.0, 0.0), Vector2(-0.45, 0.25), Vector2(0.45, 0.25), Vector2(-0.3, -0.35),
					Vector2(0.3, -0.35), Vector2(0.0, 0.5), Vector2(0.0, -0.6), Vector2(-0.7, -0.1), Vector2(0.7, -0.1)]
				for s in spikes:
					var d := Vector3(s.x, 1.0, s.y).normalized()
					var sp := _add(_hair, M.cyl(0.0, 0.07, 0.17, 6), "hair", d * (r - 0.01))
					sp.basis = Basis(Quaternion(Vector3.UP, d))
			4:  # ponytail
				_add(_hair, M.cached("hair4", func(): return M.hair_cap(r, 50.0, 96.0, 114.0, 0.0)), "hair")
				_fixed(_hair, M.torus(0.035, 0.055, 12), Color("#e84393"), Vector3(0, 0.06, -0.255), Vector3(PI / 2 - 0.3, 0, 0))
				_add(_hair, M.capsule(0.07, 0.34), "hair", Vector3(0, -0.1, -0.31), Vector3(0.38, 0, 0))
	match look:
		PlayerView.LOOK_POLICE:
			_fixed(_hat, M.cyl(HEAD_R * 1.05, HEAD_R * 1.05, 0.13, 22), Color("#17233d"), Vector3(0, 0.15, 0), Vector3.ZERO, Vector3.ONE, true)
			_fixed(_hat, M.cyl(HEAD_R * 1.22, HEAD_R * 1.08, 0.07, 22), Color("#17233d"), Vector3(0, 0.25, -0.01), Vector3(-0.1, 0, 0), Vector3.ONE, true)
			_fixed(_hat, M.cyl(HEAD_R * 1.06, HEAD_R * 1.06, 0.035, 22), Color("#e8e8e8"), Vector3(0, 0.14, 0))
			_fixed(_hat, M.sphere(0.15, 14, 6), Color("#0b0f1a"), Vector3(0, 0.1, 0.2), Vector3(0.25, 0, 0), Vector3(1.05, 0.12, 0.7), true)
			_fixed(_hat, M.sphere(0.03, 8, 5), Color("#e0b84a"), Vector3(0, 0.2, 0.265), Vector3.ZERO, Vector3(1, 1.2, 0.4))
		PlayerView.LOOK_FIREFIGHTER:
			_fixed(_hat, M.cached("helmet", func(): return M.hair_cap(HEAD_R * 1.13, 80.0, 92.0, 98.0, 0.0)), Color("#d62f2f"), Vector3(0, 0.02, 0), Vector3.ZERO, Vector3.ONE, true)
			_fixed(_hat, M.cyl(HEAD_R * 1.38, HEAD_R * 1.45, 0.025, 24), Color("#a31f1f"), Vector3(0, 0.03, -0.04), Vector3(-0.12, 0, 0), Vector3(1, 1, 1.12), true)
			_fixed(_hat, M.box(Vector3(0.025, 0.06, 0.4)), Color("#a31f1f"), Vector3(0, 0.27, -0.02), Vector3(-0.1, 0, 0))
			_fixed(_hat, M.sphere(0.05, 10, 6), Color("#f1e05a"), Vector3(0, 0.17, 0.235), Vector3(-0.6, 0, 0), Vector3(1, 1.2, 0.35))
		PlayerView.LOOK_SHOP:
			_fixed(_hat, M.cached("shopcap", func(): return M.hair_cap(HEAD_R * 1.09, 72.0, 84.0, 92.0, 0.0)), Color("#3aa845"), Vector3(0, 0.03, 0), Vector3(-0.08, 0, 0), Vector3.ONE, true)
			_fixed(_hat, M.sphere(0.16, 14, 6), Color("#2b7f33"), Vector3(0, 0.13, 0.22), Vector3(0.18, 0, 0), Vector3(1.0, 0.1, 0.75), true)
			_fixed(_hat, M.sphere(0.022, 6, 4), Color("#2b7f33"), Vector3(0, 0.3, -0.01))
		PlayerView.LOOK_PORTER:  # Pani Wiesia's glasses
			for sx in [-1.0, 1.0]:
				var g := _face_pivot(sx * 0.088, EYE_Y, 0.012, _hat)
				_fixed(g, M.torus(0.05, 0.062, 18), FRAME, Vector3.ZERO, Vector3(PI / 2, 0, 0))
			_fixed(_face_pivot(0.0, EYE_Y + 0.01, 0.02, _hat), M.box(Vector3(0.06, 0.01, 0.01)), FRAME)


func _build_outfit(look: int) -> void:
	_clear(_outfit)
	_clear(_extras)
	for i in 2:
		for c in _elbow[i].get_children() + _knee[i].get_children():
			if String(c.name).begins_with("Stripe"):
				c.queue_free()
	if _tool:
		_tool.queue_free()
		_tool = null
	var depth := 1.0 / TORSO_DEPTH
	var front := func(y: float, x := 0.0, out := 0.004) -> Vector3:
		# a point on the chest surface (in _chest space)
		return Vector3(x, y, sqrt(maxf(_torso_r(y) * _torso_r(y) - x * x, 0.0)) + out * depth)
	match look:
		PlayerView.LOOK_OFFICE:
			# white shirt, a tie, a clipped badge (reception, HR, staff)
			var tie: Color = view.tie
			_fixed(_outfit, _torso_band(0.37, 0.43, 1.06, -0.9, 0.9, 3), Color("#ffffff"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, true)
			_fixed(_outfit, M.sphere(0.03, 8, 5), tie, front.call(0.385, 0.0, 0.01), Vector3.ZERO, Vector3(1, 1, 0.6), true)
			_fixed(_outfit, M.box(Vector3(0.05, 0.24, 0.014)), tie, front.call(0.25, 0.0, 0.012), Vector3(-0.12, 0, 0), Vector3.ONE, true)
			_fixed(_outfit, M.cyl(0.0, 0.036, 0.045, 4), tie, front.call(0.115, 0.0, 0.015), Vector3(PI, PI / 4, 0), Vector3(1, 1, 0.4), true)
			_fixed(_outfit, M.box(Vector3(0.06, 0.08, 0.008)), Color("#f2eee4"), front.call(0.25, -0.1, 0.006), Vector3(-0.1, -0.5, 0), Vector3.ONE, true)
			_fixed(_outfit, M.box(Vector3(0.062, 0.018, 0.01)), Color("#4f7fb0"), front.call(0.28, -0.1, 0.008), Vector3(-0.1, -0.5, 0))
		PlayerView.LOOK_PORTER:
			# cardigan open over a cream blouse, buttons, pearls
			_fixed(_outfit, _torso_band(0.0, 0.42, 1.02, -0.32, 0.32), Color("#f4ead0"))
			for i in 3:
				_fixed(_outfit, M.sphere(0.014, 6, 4), Color("#f4ead0"), front.call(0.29 - i * 0.09, 0.075, 0.012), Vector3.ZERO, Vector3(1, 1, 0.6), true)
			for i in 11:
				var a := lerpf(-1.25, 1.25, i / 10.0)
				_fixed(_extras, M.sphere(0.014, 6, 4), Color("#f8f4ea"), Vector3(sin(a) * 0.085, -0.025 - cos(a) * 0.01, cos(a) * 0.07))
		PlayerView.LOOK_GUARD:
			_fixed(_outfit, _torso_band(0.25, 0.3, 1.035), Color("#f1c40f"))
			var l := Label3D.new()
			l.text = "OCHRONA"
			l.font_size = 40
			l.pixel_size = 0.0022
			l.outline_size = 0
			l.modulate = Color("#f1c40f")
			l.position = Vector3(0, 0.17, -_torso_r(0.17) - 0.012)
			l.rotation.y = PI
			l.scale = Vector3(1, 1, depth)
			_outfit.add_child(l)
		PlayerView.LOOK_POLICE:
			_fixed(_outfit, _torso_band(0.0, 0.05, 1.04), Color("#141414"))
			_fixed(_outfit, M.box(Vector3(0.03, 0.04, 0.03)), Color("#c9a24a"), front.call(0.025, 0.0, 0.012))
			_fixed(_outfit, M.cyl(0.0, 0.032, 0.012, 5), Color("#e0b84a"), front.call(0.29, -0.085, 0.006), Vector3(PI / 2, 0, 0), Vector3.ONE, true)
			_fixed(_outfit, _torso_band(0.37, 0.43, 1.06, -0.9, 0.9, 3), Color("#2a4270"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, true)
		PlayerView.LOOK_CLEANER:
			_fixed(_outfit, _torso_band(0.0, 0.33, 1.04, -0.85, 0.85), Color("#eef5f0"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, true)
			_fixed(_outfit, M.box(Vector3(0.1, 0.06, 0.012)), Color("#dfe9e3"), front.call(0.12, 0.0, 0.02), Vector3(-0.05, 0, 0), Vector3.ONE, true)
			# the mop, in the right hand
			_tool = Node3D.new()
			_fixed(_tool, M.cyl(0.014, 0.014, 1.3, 6), Color("#a0764b"), Vector3(0, -0.3, 0), Vector3.ZERO, Vector3.ONE, true)
			_fixed(_tool, M.cyl(0.13, 0.09, 0.08, 10), Color("#d9d4c7"), Vector3(0, -0.93, 0), Vector3.ZERO, Vector3(1, 1, 0.6), true)
			add_child(_tool)
		PlayerView.LOOK_FIREFIGHTER:
			for y in [0.17, 0.3]:
				_fixed(_outfit, _torso_band(y, y + 0.035, 1.035), Color("#f1e05a"))
			for i in 2:
				_fixed(_elbow[i], M.cyl(0.054, 0.054, 0.03, 10), Color("#f1e05a"), Vector3(0, -FOREARM * 0.55, 0)).name = "Stripe"
				_fixed(_knee[i], M.cyl(0.066, 0.066, 0.03, 10), Color("#f1e05a"), Vector3(0, -SHIN * 0.5, 0)).name = "Stripe"
		PlayerView.LOOK_SHOP:
			_fixed(_outfit, _torso_band(0.37, 0.43, 1.06, -0.95, 0.95, 3), Color("#2b7f33"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, true)
			_fixed(_outfit, M.box(Vector3(0.075, 0.035, 0.008)), Color("#f4f6f8"), front.call(0.29, 0.085, 0.006), Vector3(-0.15, 0.4, 0), Vector3.ONE, true)
		_:
			# a plain T-shirt: a darker collar
			_fixed(_outfit, _torso_band(0.395, 0.425, 1.05, 0.0, TAU, 2), (view.shirt as Color).darkened(0.18))


func _set_held(kind: int) -> void:
	if kind == _held_kind:
		return
	_held_kind = kind
	if _held_node:
		_held_node.queue_free()
		_held_node = null
	if kind != 0:
		_held_node = Held.build(kind)
		add_child(_held_node)


func _make_umbrella() -> Node3D:
	var u := Node3D.new()
	var blue := Color("#3a5f9e")
	_fixed(u, M.cyl(0.011, 0.011, 0.85, 6), Color("#5c6570"), Vector3(0, 0.4, 0))
	_fixed(u, M.cyl(0.03, 0.46, 0.19, 8), blue, Vector3(0, 0.76, 0), Vector3.ZERO, Vector3.ONE, true)
	_fixed(u, M.cyl(0.46, 0.43, 0.02, 8), blue.darkened(0.25), Vector3(0, 0.65, 0))
	_fixed(u, M.sphere(0.028, 8, 5), Color("#2d3036"), Vector3(0, 0.87, 0))
	_fixed(u, M.tube(M.arc(Vector3(0.035, 0.0, 0), 0.035, PI, TAU, 6), 0.012, 5), FRAME)
	return u


func _make_cig() -> Node3D:
	var c := Node3D.new()
	_fixed(c, M.cyl(0.008, 0.008, 0.075, 6), Color("#f4f1ea"), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	_fixed(c, M.cyl(0.0085, 0.0085, 0.022, 6), Color("#d9a15a"), Vector3(0, 0, -0.03), Vector3(PI / 2, 0, 0))
	var tip := MeshInstance3D.new()
	tip.mesh = M.sphere(0.011, 6, 4)
	tip.material_override = M.mat(Color("#ff7043"), false, 0.5, 3.0)
	tip.position = Vector3(0, 0, 0.04)
	tip.name = "Tip"
	c.add_child(tip)
	return c


# ---------------------------------------------------------------------- sync

## Follow the 2D view. `pos` is the feet position in the world.
func sync(pos: Vector3, delta: float) -> void:
	if not is_inside_tree():
		return
	_apply_look()
	visible = view.visible
	_ring.visible = view.highlight
	_t += delta
	# movement: walk phase from distance, heading from motion (else facing)
	var step := Vector2.ZERO
	if _last != Vector3.INF:
		step = Vector2(pos.x - _last.x, pos.z - _last.z)
		if step.length() > 2.0:
			step = Vector2.ZERO  # teleport
	_last = pos
	position = pos
	var d := step.length()
	var inst := d / maxf(delta, 0.0001)
	_speed = lerpf(_speed, inst, minf(1.0, delta * 8.0))
	_moving = move_toward(_moving, 1.0 if inst > 0.25 else 0.0, delta * (8.0 if inst > 0.25 else 5.0))
	# one stride cycle (two steps) per ~1.5 m at full speed (5.6 m/s, a jog)
	_phase += d * TAU / (1.5 if not view.slow else 1.05)
	var want := _yaw
	if d > 0.002 and inst > 0.25:
		want = atan2(step.x, step.y)
	else:
		match view.facing:
			PlayerView.FACING_DOWN: want = 0.0
			PlayerView.FACING_UP: want = PI
			PlayerView.FACING_LEFT: want = -PI / 2
			PlayerView.FACING_RIGHT: want = PI / 2
	_yaw = lerp_angle(_yaw, want, minf(1.0, delta * 12.0))
	_set_held(view.held)
	_pose(delta)


# ---------------------------------------------------------------------- pose

## Smoothly move a joint's rotation towards `goal`.
static func _ease(n: Node3D, goal: Vector3, k: float) -> void:
	n.rotation = n.rotation.lerp(goal, k)


func _pose(delta: float) -> void:
	var st: int = view.status
	var t := _t + _seed
	var mv := _moving
	var lying: bool = st in PlayerView.LYING
	var sitting: bool = st in SITTING and mv < 0.5 and not lying
	# (the voice glyph / bubble only count once set up, i.e. parented)
	var talking: bool = (view._talk.visible and view._talk.get_parent() != null) or (view.bubble.visible and view.bubble.get_parent() != null)
	var held: int = view.held
	var two_hands: bool = held in Held.TWO_HANDED
	var slow: bool = view.slow
	var drunk: int = view.drunk
	var k := 1.0 - exp(-delta * 13.0)

	# ---- base: standing / walking
	var amp := clampf(_speed / 4.0, 0.5, 1.0) * mv * (0.8 if slow else 1.0)
	var run := clampf((_speed - 2.5) / 2.5, 0.0, 1.0) * mv * (0.0 if slow else 1.0)
	var ph := _phase
	var sw := sin(ph)
	var pel_y := HIP_H - 0.012 + absf(cos(ph)) * (0.035 + 0.035 * run) * amp - (0.025 + 0.03 * run) * mv
	var pel_z := 0.0
	var pel_rot := Vector3.ZERO
	var spine := Vector3((0.08 + 0.14 * run + (0.2 if slow else 0.0)) * mv, sw * 0.16 * amp, 0)
	# chin up a little by default: the camera looks from above
	var head := Vector3(-0.16 + (0.04 - 0.08 * run) * mv + (0.2 if slow else 0.0), -sw * 0.1 * amp, 0)
	var hip := [Vector3(sw * 0.7 * amp, 0, -0.02), Vector3(-sw * 0.7 * amp, 0, 0.02)]
	var kb := (0.9 + 0.5 * run) * amp
	var knee := [Vector3(maxf(0.0, -cos(ph)) * kb + 0.05 + 0.2 * run, 0, 0), Vector3(maxf(0.0, cos(ph)) * kb + 0.05 + 0.2 * run, 0, 0)]
	var sh := [Vector3(-sw * 0.75 * amp, 0, -0.12 - 0.06 * run), Vector3(sw * 0.75 * amp, 0, 0.12 + 0.06 * run)]
	var el := [Vector3(-0.25 - 0.9 * run - 0.3 * mv * maxf(0.0, sw), 0, 0), Vector3(-0.25 - 0.9 * run - 0.3 * mv * maxf(0.0, -sw), 0, 0)]
	var breathe := 1.0 + sin(t * 2.1) * 0.014 * (1.0 - mv)
	# idle life: weight shift, glances, arms swaying a touch
	if mv < 0.5 and not lying and not sitting and st == 0:
		_glance_at -= delta
		if _glance_at <= 0.0:
			_glance_at = _rng.randf_range(1.6, 4.5)
			_glance_goal = 0.0 if _rng.randf() < 0.4 else _rng.randf_range(-0.6, 0.6)
		_glance = lerpf(_glance, _glance_goal, minf(1.0, delta * 4.0))
		head.y += _glance
		head.z += sin(t * 0.7) * 0.04
		pel_rot.z = sin(t * 0.45) * 0.025
		sh[0].z -= sin(t * 2.1) * 0.02
		sh[1].z += sin(t * 2.1) * 0.02
	else:
		_glance = lerpf(_glance, 0.0, minf(1.0, delta * 4.0))

	# ---- held things change the arms
	if held != 0 and not lying:
		if two_hands:
			for i in 2:
				sh[i] = Vector3(-0.45, 0, (-1.0 if i == 0 else 1.0) * 0.08)
				el[i] = Vector3(-1.35, (1.0 if i == 0 else -1.0) * 0.35, 0)
		elif held == ItemArt.UMBRELLA:
			sh[1] = Vector3(-0.15 + sw * 0.15 * amp, 0, 0.1)
			el[1] = Vector3(-0.15, 0, 0)
		else:
			sh[1] = Vector3(-0.45 + sw * 0.1 * amp, 0, 0.1)
			el[1] = Vector3(-1.05, 0, 0)
	if view.umbrella and not lying:
		sh[0] = Vector3(-1.15, 0, -0.05)
		el[0] = Vector3(-1.2, 0.0, 0)
	if _tool and held == 0 and not lying and not sitting:
		sh[1] = Vector3(-0.5 + sw * 0.15 * amp, 0, 0.18)
		el[1] = Vector3(-0.5, 0, 0)

	# ---- talking: the free hand gestures, the head nods
	if talking and not lying and st == 0:
		head.x += sin(t * 5.3) * 0.05
		head.z += sin(t * 2.3) * 0.06
		if not view.umbrella and mv < 0.5:
			var g := sin(t * 3.1) * 0.5 + 0.5
			sh[0] = Vector3(-0.5 - g * 0.3, 0, -0.25)
			el[0] = Vector3(-1.2 - g * 0.3, 0.3, 0)

	# ---- activities
	match st:
		PlayerView.ACT_BREWING:
			for i in 2:
				sh[i] = Vector3(-0.8, 0, (-1.0 if i == 0 else 1.0) * 0.05)
				el[i] = Vector3(-0.7, 0, 0)
			sh[1].x += sin(t * 3.0) * 0.08
			head.x += 0.12
		PlayerView.ACT_WASHING:
			for i in 2:
				var s := 1.0 if i == 0 else -1.0
				sh[i] = Vector3(-0.75 + sin(t * 9.0) * 0.06 * s, 0, -s * 0.18)
				el[i] = Vector3(-0.9, s * 0.4, 0)
			head.x += 0.2
			spine.x += 0.12
		PlayerView.ACT_SMOKING:
			var c := fmod(t, 4.0)
			var up := smoothstep(0.0, 0.5, c) * (1.0 - smoothstep(1.4, 2.0, c))
			sh[1] = Vector3(lerpf(-0.25, -0.55, up), 0, lerpf(0.12, -0.12, up))
			el[1] = Vector3(lerpf(-1.3, -2.35, up), 0, 0)
			sh[0] = Vector3(-0.35, 0, -0.1)
			el[0] = Vector3(-1.45, -0.5, 0)
			head.x += -0.12 * up
		PlayerView.ACT_VOMITING:
			pel_y = HIP_H - 0.06
			for i in 2:
				hip[i].x = -0.35
				knee[i].x = 0.55
				sh[i] = Vector3(-0.7, 0, (-1.0 if i == 0 else 1.0) * 0.15)
				el[i] = Vector3(-0.1, 0, 0)
			spine = Vector3(0.75 + sin(t * 9.0) * 0.06, 0, 0)
			head = Vector3(0.25, 0, 0)
		PlayerView.ACT_ATTACKING:
			var p := fmod(t * 2.6, 2.0)
			var side := 0 if p < 1.0 else 1
			var hit := sin(fmod(p, 1.0) * PI)
			hip[0] = Vector3(-0.3, 0, -0.1)
			hip[1] = Vector3(0.25, 0, 0.1)
			knee[0].x = 0.35
			knee[1].x = 0.15
			pel_y = HIP_H - 0.04
			spine = Vector3(0.18, (0.3 if side == 1 else -0.3) * hit, 0)
			for i in 2:
				var s := -1.0 if i == 0 else 1.0
				sh[i] = Vector3(-1.1, 0, s * 0.05)
				el[i] = Vector3(-1.9, 0, 0)
			sh[side] = Vector3(lerpf(-1.1, -1.55, hit), 0, 0.0)
			el[side] = Vector3(lerpf(-1.9, -0.05, hit), 0, 0)
		PlayerView.ACT_PEEING:
			for i in 2:
				sh[i] = Vector3(-0.35, 0, (-1.0 if i == 0 else 1.0) * -0.05)
				el[i] = Vector3(-0.55, 0, 0)
			head.x += 0.25 + sin(t * 0.6) * 0.05
			head.y += sin(t * 0.4) * 0.2
	if sitting:
		pel_y = SEAT_Y
		for i in 2:
			var s := -1.0 if i == 0 else 1.0
			hip[i] = Vector3(-1.5, 0, s * -0.06)
			knee[i] = Vector3(1.35 + sin(t * 1.3 + i * 1.7) * 0.08, 0, 0)
		match st:
			PlayerView.ACT_COMPUTER:
				pel_z = -0.05
				spine = Vector3(0.12, 0, 0)
				head = Vector3(0.18, sin(t * 0.5) * 0.08, 0)
				for i in 2:
					var s := -1.0 if i == 0 else 1.0
					var tap := maxf(0.0, sin(t * 15.0 + i * 2.1)) * 0.09
					sh[i] = Vector3(-0.85 + tap, 0, s * 0.02)
					el[i] = Vector3(-0.85 - tap, -s * 0.35, 0)
			PlayerView.ACT_SOFA:
				spine = Vector3(-0.32, 0, 0)
				pel_z = 0.05
				head = Vector3(0.12, 0, 0.18 * sin(t * 0.3))
				for i in 2:
					var s := -1.0 if i == 0 else 1.0
					sh[i] = Vector3(-0.1, 0, s * 0.6)
					el[i] = Vector3(-0.4, 0, 0)
			PlayerView.ACT_TOILET:
				spine = Vector3(0.12, 0, 0)
				head = Vector3(0.15, sin(t * 0.4) * 0.3, 0)
				for i in 2:
					sh[i] = Vector3(-0.6, 0, (-1.0 if i == 0 else 1.0) * 0.12)
					el[i] = Vector3(-0.55, 0, 0)
			PlayerView.ACT_POOPING:
				var strain := sin(t * 7.0) * 0.03
				spine = Vector3(0.35 + strain, 0, 0)
				head = Vector3(0.0, 0, strain)
				for i in 2:
					sh[i] = Vector3(-0.85, 0, (-1.0 if i == 0 else 1.0) * 0.25)
					el[i] = Vector3(-1.2, 0, 0)
	if lying:
		pel_y = LIE_Y
		pel_z = 0.2
		pel_rot = Vector3(-PI / 2, 0, 0)
		spine = Vector3.ZERO
		head = Vector3(-0.15, 0.35 if st == PlayerView.ACT_PASSED_OUT else 0.15, 0)
		for i in 2:
			var s := -1.0 if i == 0 else 1.0
			hip[i] = Vector3(0, 0, s * 0.18)
			knee[i] = Vector3(0.1 + i * 0.3, 0, 0)
			sh[i] = Vector3(-0.2, 0, s * 1.15)
			el[i] = Vector3(-0.3 - i * 0.6, 0, 0)
		breathe = 1.0 + sin(t * 1.3) * 0.025

	# ---- apply (eased)
	_pelvis.position = _pelvis.position.lerp(Vector3(0, pel_y, pel_z), k)
	_ease(_pelvis, pel_rot, k)
	_ease(_spine, spine, k)
	_spine.scale = Vector3(1, breathe, 1)
	_ease(_head, head, k)
	for i in 2:
		_ease(_hip[i], hip[i], k)
		_ease(_knee[i], knee[i], k)
		_ease(_shoulder[i], sh[i], k)
		_ease(_elbow[i], el[i], k)
	# body: heading, drunk sway (from the feet), a little shake when straining
	var tilt := Vector3.ZERO
	if drunk > 0 and not lying:
		tilt.z = sin(t * (1.6 + drunk * 0.3)) * 0.05 * drunk + sin(t * 3.7) * 0.015 * (drunk - 1)
		tilt.x = sin(t * 1.1) * 0.02 * drunk
	if st == PlayerView.ACT_POOPING:
		tilt.z += sin(t * 31.0) * 0.008
	_body.rotation = Vector3(tilt.x, _yaw, tilt.z)

	_pose_face(delta, st, talking)
	_place_things(st, held, two_hands, lying, sitting)
	_update_fx(st, held, lying, drunk)


func _pose_face(delta: float, st: int, talking: bool) -> void:
	var t := _t + _seed
	var knocked := st == PlayerView.ACT_KNOCKED_OUT
	var closed := st in [PlayerView.ACT_PASSED_OUT, PlayerView.ACT_VOMITING, PlayerView.ACT_SOFA]
	var eye_h := 1.0
	_blink_at -= delta
	if _blink_at < 0.0:
		eye_h = 0.12
		if _blink_at < -0.11:
			_blink_at = _rng.randf_range(1.8, 5.0)
			if _rng.randf() < 0.2:
				_blink_at = 0.18  # a double blink now and then
	if view.drunk >= 2:
		eye_h = minf(eye_h, 0.55)
	if closed:
		eye_h = 0.1
	if st == PlayerView.ACT_POOPING:
		eye_h = 0.35
	for i in 2:
		_eyes[i].visible = not knocked
		_eye_x[i].visible = knocked
		_eyes[i].scale = Vector3(1, eye_h, 1)
	# brows: up when talking, angry in a fight, worried when straining
	var lift := 0.0
	var tilt := 0.0
	if talking:
		lift = maxf(0.0, sin(t * 4.0)) * 0.012
	if st == PlayerView.ACT_ATTACKING:
		tilt = 0.4
		lift = -0.01
	elif st in [PlayerView.ACT_POOPING, PlayerView.ACT_VOMITING] or view.slow:
		tilt = -0.35
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var base := _surf(s * 0.09, EYE_Y + 0.085 + lift, -0.004)
		_brows[i].transform = Transform3D(Basis.looking_at(-base.normalized(), Vector3.UP) * Basis(Vector3.BACK, -s * tilt), base)
	# mouth
	var open := 0.0
	if talking:
		open = 0.35 + 0.65 * absf(sin(t * 11.0)) * (0.6 + 0.4 * sin(t * 3.3))
	if st in [PlayerView.ACT_VOMITING, PlayerView.ACT_KNOCKED_OUT]:
		open = 0.8
	elif st == PlayerView.ACT_PASSED_OUT and sin(t * 1.3) > 0.2:
		open = 0.4
	var flat: bool = (view.slow or st in [PlayerView.ACT_SOFA, PlayerView.ACT_POOPING, PlayerView.ACT_TOILET]) and open == 0.0
	_mouth_open.visible = open > 0.0
	_mouth_open.scale = Vector3(0.9, 0.25 + open * 0.75, 0.35)
	_smile.visible = open == 0.0 and not flat
	_mouth_flat.visible = flat
	# cheeks: rosy; red when drunk or straining
	var skin: Color = view.skin
	var red := 0.3
	if view.drunk > 0:
		red = 0.45 + 0.15 * view.drunk
	if st == PlayerView.ACT_POOPING:
		red = 0.9
	_set_color("cheek", skin.lerp(Color("#ff4f4f"), red))
	_set_color("nose", skin.darkened(0.06).lerp(Color("#e04848"), 0.5 if view.drunk >= 2 else 0.0))
	_set_color("skin", skin.lerp(Color("#e0605a"), 0.28 if st == PlayerView.ACT_POOPING else 0.0))


## Held item, umbrella, cigarette, mop: placed in the hands each frame,
## kept upright (so drinks don't spill whatever the arm does).
func _place_things(st: int, held: int, two_hands: bool, lying: bool, sitting: bool) -> void:
	var up := Basis(Vector3.UP, _yaw)
	if _held_node:
		_held_node.visible = not lying
		if two_hands:
			var c := (_hand[0].global_position + _hand[1].global_position) * 0.5
			var flat := held != ItemArt.LAPTOP and held != ItemArt.BOOMBOX
			var b := up if flat else up * Basis(Vector3.RIGHT, -0.2)
			_held_node.global_transform = Transform3D(b, c + up * Vector3(0, 0.02 if flat else 0.06, 0.02))
		elif st == PlayerView.ACT_ATTACKING and held == ItemArt.KNIFE:
			var h := _hand[1]
			_held_node.global_transform = Transform3D(h.global_basis.orthonormalized() * Basis(Vector3.RIGHT, PI), h.global_position)
		else:
			_held_node.global_transform = Transform3D(up, _hand[1].global_position + up * Vector3(0, -0.015, 0.02))
	if view.umbrella and not lying:
		if _umbrella == null:
			_umbrella = _make_umbrella()
			add_child(_umbrella)
		_umbrella.visible = true
		_umbrella.global_transform = Transform3D(up * Basis(Vector3.RIGHT, -0.06), _hand[0].global_position)
	elif _umbrella:
		_umbrella.visible = false
	if st == PlayerView.ACT_SMOKING:
		if _cig == null:
			_cig = _make_cig()
			add_child(_cig)
		_cig.visible = true
		_cig.global_transform = Transform3D(up * Basis(Vector3.UP, -0.5), _hand[1].global_position + up * Vector3(-0.03, 0.03, 0.03))
	elif _cig:
		_cig.visible = false
	if _tool:
		_tool.visible = held == 0 and not lying and not sitting
		if _tool.visible:
			# from the fist down to the floor a bit ahead
			var h := _hand[1].global_position
			var base := global_position + up * Vector3(0.28, 0.05, 0.4)
			var dvec := base - h
			var l := dvec.length()
			_tool.global_transform = Transform3D(Basis(Quaternion(Vector3.DOWN, dvec / l)), h)
			var stick: Node3D = _tool.get_child(0)
			stick.scale.y = (l + 0.3) / 1.3
			stick.position.y = 0.3 - (l + 0.3) / 2
			_tool.get_child(1).position.y = -l


func _update_fx(st: int, held: int, lying: bool, drunk: int) -> void:
	var head := to_local(_head.global_position)
	var up := Basis(Vector3.UP, _yaw)
	var s := {
		"head": head if not lying else Vector3(head.x, 0.25, head.z),
		"side": up * Vector3(1, 0, 0),
		"fwd": up * Vector3(0, 0, 1),
	}
	match st:
		PlayerView.ACT_BREWING:
			s.dots = Color("#f4ead0")
		PlayerView.ACT_COMPUTER:
			s.dots = Color("#a8d0f0")
		PlayerView.ACT_SOFA, PlayerView.ACT_PASSED_OUT:
			s.zzz = true
		PlayerView.ACT_KNOCKED_OUT:
			s.stars = true
		PlayerView.ACT_TOILET:
			s.roll = true
		PlayerView.ACT_SMOKING:
			if _cig:
				s.smoke = to_local(_cig.get_node("Tip").global_position)
		PlayerView.ACT_WASHING:
			s.bubbles = to_local((_hand[0].global_position + _hand[1].global_position) * 0.5)
		PlayerView.ACT_VOMITING:
			s.vomit = to_local(_head.global_position + _head.global_basis * Vector3(0, -0.12, 0.24))
		PlayerView.ACT_PEEING:
			s.pee = to_local(_pelvis.global_position + _pelvis.global_basis * Vector3(0, -0.05, 0.14))
		PlayerView.ACT_POOPING:
			s.poop = to_local(_pelvis.global_position) + Vector3(0, -0.12, 0) - s.fwd * 0.05
	if held in Held.HOT and _held_node and _held_node.visible:
		s.steam = to_local(_held_node.global_position) + Vector3(0, 0.13, 0) + s.fwd * 0.03
	if view.smelly:
		s.smell = true
	if view.slow and not lying:
		s.sweat = true
	if drunk >= 2 and not lying and st != PlayerView.ACT_VOMITING:
		s.hiccup = true
	_fx.update(s, _t)
