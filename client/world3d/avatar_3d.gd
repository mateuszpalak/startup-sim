## A character in 3D: a stylised low-poly figure (big head, simple limbs)
## mirroring a 2D PlayerView / RemotePlayer, which still owns the state
## (position, facing, status, appearance, nick, bubble). world_view.gd
## calls `sync()` every frame; nothing here talks to the network.
##
## Model space: feet at the origin, front = +z, 1 unit = 1 m.
extends Node3D

const Coords = preload("res://world3d/coords.gd")
const PlayerView = preload("res://game/player_view.gd")

## The 2D view this avatar follows.
var view: Node2D
var _mats := {}       # part -> StandardMaterial3D
var _body := Node3D.new()   # everything that turns / bends
var _hips := Node3D.new()
var _leg_l := Node3D.new()
var _leg_r := Node3D.new()
var _arm_l := Node3D.new()
var _arm_r := Node3D.new()
var _head := Node3D.new()
var _hair_parts: Array[MeshInstance3D] = []
var _held := MeshInstance3D.new()
var _ring := MeshInstance3D.new()
var _look := ""     # appearance key last applied
var _yaw := 0.0
var _phase := 0.0
var _last := Vector3.INF
var _moving := 0.0
var _hair_style := -1

static var _meshes := {}


static func _mesh(key: String) -> Mesh:
	if _meshes.has(key):
		return _meshes[key]
	var m: Mesh
	match key:
		"leg":
			var c := CapsuleMesh.new()
			c.radius = 0.085
			c.height = 0.82
			c.radial_segments = 8
			c.rings = 2
			m = c
		"arm":
			var c := CapsuleMesh.new()
			c.radius = 0.065
			c.height = 0.62
			c.radial_segments = 8
			c.rings = 2
			m = c
		"torso":
			var c := CapsuleMesh.new()
			c.radius = 0.21
			c.height = 0.66
			c.radial_segments = 10
			c.rings = 3
			m = c
		"head":
			var s := SphereMesh.new()
			s.radius = 0.215
			s.height = 0.43
			s.radial_segments = 14
			s.rings = 8
			m = s
		"hair":
			var s := SphereMesh.new()
			s.radius = 0.235
			s.height = 0.47
			s.radial_segments = 14
			s.rings = 8
			s.is_hemisphere = true
			m = s
		"ball":
			var s := SphereMesh.new()
			s.radius = 0.1
			s.height = 0.2
			s.radial_segments = 8
			s.rings = 4
			m = s
		"eye":
			var s := SphereMesh.new()
			s.radius = 0.028
			s.height = 0.056
			s.radial_segments = 6
			s.rings = 3
			m = s
		"shoe":
			var b := BoxMesh.new()
			b.size = Vector3(0.13, 0.08, 0.24)
			m = b
		"box":
			var b := BoxMesh.new()
			b.size = Vector3(0.16, 0.12, 0.1)
			m = b
		"ring":
			var t := TorusMesh.new()
			t.inner_radius = 0.34
			t.outer_radius = 0.42
			t.rings = 24
			t.ring_segments = 4
			m = t
	_meshes[key] = m
	return m


func _mat(part: String) -> StandardMaterial3D:
	if not _mats.has(part):
		var m := StandardMaterial3D.new()
		m.roughness = 0.8 if part != "eye" else 0.2
		_mats[part] = m
	return _mats[part]


func _part(parent: Node3D, mesh: String, mat: String, pos: Vector3, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(mesh)
	mi.material_override = _mat(mat)
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)
	return mi


func setup(p_view: Node2D) -> void:
	view = p_view
	add_child(_body)
	_body.add_child(_hips)
	_hips.position.y = 0.86
	# legs hang from the hips
	for pair in [[_leg_l, -0.1], [_leg_r, 0.1]]:
		var leg: Node3D = pair[0]
		leg.position = Vector3(pair[1], 0, 0)
		_hips.add_child(leg)
		_part(leg, "leg", "pants", Vector3(0, -0.42, 0))
		_part(leg, "shoe", "shoe", Vector3(0, -0.82, 0.04))
	_part(_hips, "torso", "shirt", Vector3(0, 0.3, 0), Vector3(1, 1, 0.72))
	# arms from the shoulders
	for pair in [[_arm_l, -0.27], [_arm_r, 0.27]]:
		var arm: Node3D = pair[0]
		arm.position = Vector3(pair[1], 0.52, 0)
		_hips.add_child(arm)
		_part(arm, "arm", "shirt", Vector3(0, -0.26, 0))
		_part(arm, "ball", "skin", Vector3(0, -0.56, 0), Vector3(0.62, 0.62, 0.62))
	_head.position = Vector3(0, 0.88, 0)
	_hips.add_child(_head)
	_part(_head, "head", "skin", Vector3.ZERO)
	_part(_head, "eye", "eye", Vector3(-0.075, -0.02, 0.195))
	_part(_head, "eye", "eye", Vector3(0.075, -0.02, 0.195))
	_held.mesh = _mesh("box")
	_held.material_override = _mat("held")
	_held.position = Vector3(0, -0.58, 0.1)
	_held.visible = false
	_arm_r.add_child(_held)
	# own character: a soft ring under the feet
	_ring.mesh = _mesh("ring")
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1.0, 0.92, 0.55, 0.75)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring.material_override = rm
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position.y = 0.02
	_ring.scale = Vector3(1, 0.2, 1)
	_ring.visible = false
	add_child(_ring)
	_mat("eye").albedo_color = Color("#1d1712")
	_mat("shoe").albedo_color = Color("#2a2420")
	_apply_look()


func _apply_look() -> void:
	var key := "%s|%s|%s|%s|%d" % [view.skin, view.hair, view.shirt, view.pants, view.hair_style]
	if key == _look:
		return
	_look = key
	_mat("skin").albedo_color = view.skin
	_mat("hair").albedo_color = view.hair
	_mat("shirt").albedo_color = view.shirt
	_mat("pants").albedo_color = view.pants
	if view.hair_style != _hair_style:
		_hair_style = view.hair_style
		for p in _hair_parts:
			p.queue_free()
		_hair_parts.clear()
		# 0 short, 1 long, 2 bun, 3 spiky, 4 ponytail, 5 bald
		if _hair_style != 5:
			var cap := _part(_head, "hair", "hair", Vector3(0, 0.0, -0.015), Vector3(1, 1.05, 1))
			cap.rotation.x = -0.55
			_hair_parts.append(cap)
		match _hair_style:
			1:
				_hair_parts.append(_part(_head, "ball", "hair", Vector3(0, -0.14, -0.12), Vector3(2.2, 2.0, 1.1)))
			2:
				_hair_parts.append(_part(_head, "ball", "hair", Vector3(0, 0.25, -0.08), Vector3(0.9, 0.9, 0.9)))
			3:
				for i in 4:
					_hair_parts.append(_part(_head, "ball", "hair", Vector3(-0.12 + i * 0.08, 0.2, 0.02 - (i % 2) * 0.07), Vector3(0.4, 0.7, 0.4)))
			4:
				_hair_parts.append(_part(_head, "ball", "hair", Vector3(0, 0.02, -0.26), Vector3(0.7, 1.2, 0.7)))


## Follow the 2D view. `pos` is the feet position in the world.
func sync(pos: Vector3, delta: float) -> void:
	_apply_look()
	visible = view.visible
	_ring.visible = view.highlight
	_held.visible = view.held != 0
	if view.held != 0:
		_mat("held").albedo_color = Color.from_hsv(float(view.held * 47 % 360) / 360.0, 0.55, 0.9)
	# movement: walk phase from distance, heading from motion (else facing)
	var step := 0.0
	if _last != Vector3.INF:
		step = Vector2(pos.x - _last.x, pos.z - _last.z).length()
		if step > 2.0:
			step = 0.0  # teleport
	_last = pos
	position = pos
	var speed := step / maxf(delta, 0.0001)
	_moving = move_toward(_moving, 1.0 if speed > 0.3 else 0.0, delta * 6.0)
	_phase += step * 5.2
	var want := _yaw
	match view.facing:
		PlayerView.FACING_DOWN: want = 0.0
		PlayerView.FACING_UP: want = PI
		PlayerView.FACING_LEFT: want = -PI / 2
		PlayerView.FACING_RIGHT: want = PI / 2
	_yaw = lerp_angle(_yaw, want, minf(1.0, delta * 14.0))
	_body.rotation = Vector3(0, _yaw, 0)
	_pose(delta)


func _pose(_delta: float) -> void:
	var swing := sin(_phase) * 0.62 * _moving
	var st: int = view.status
	var sitting: bool = st in [PlayerView.ACT_COMPUTER, PlayerView.ACT_SOFA, PlayerView.ACT_TOILET]
	var lying: bool = st in PlayerView.LYING
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	_arm_l.rotation.x = -swing * 0.8
	_arm_r.rotation.x = swing * 0.8
	_arm_l.rotation.z = -0.08
	_arm_r.rotation.z = 0.08
	_hips.position.y = 0.86 + absf(sin(_phase)) * 0.03 * _moving
	_hips.rotation = Vector3.ZERO
	if view.held != 0:
		_arm_r.rotation.x = -0.9
	if sitting:
		_hips.position.y = 0.5
		_leg_l.rotation.x = -1.45
		_leg_r.rotation.x = -1.45
		_arm_l.rotation.x = -0.6
		_arm_r.rotation.x = -0.6
	if st == PlayerView.ACT_COMPUTER:
		_arm_l.rotation.x = -1.1
		_arm_r.rotation.x = -1.1
	if lying:
		_hips.position.y = 0.15
		_hips.rotation.x = -PI / 2
		_hips.position.z = 0.0
	# drunk: a sway from the feet
	if view.drunk > 0 and not lying:
		var t := Time.get_ticks_msec() / 1000.0
		_body.rotation.z = sin(t * (1.6 + view.drunk * 0.3)) * 0.06 * view.drunk
	else:
		_body.rotation.z = 0.0
