## Cigarette smoke in the rooms of the shown floor (SmokeView's eased
## levels: the server's Smoke packets) as soft billowing GPU particles,
## thicker with the level; smoke detectors over the rooms, the LED blinking
## (fast and lighting red in a fire alarm).
extends Node3D

const Coords = preload("res://world3d/coords.gd")
const SmokeView = preload("res://game/smoke_view.gd")

const Platform = preload("res://platform/platform.gd")
var max_per_room: int = Platform.quality().smoke_max

var wv: Node3D
var _rooms := {}      # room -> GPUParticles3D (shown floor)
var _floor := -1
var _detectors: Array = []   # [Node3D, OmniLight3D]
var _puff := QuadMesh.new()
var _led_on := StandardMaterial3D.new()
var _led_off := StandardMaterial3D.new()
var _shell := StandardMaterial3D.new()
var _puff_tex: Texture2D


func setup(p_wv: Node3D) -> void:
	wv = p_wv
	name = "Smoke"
	_puff.size = Vector2(1.6, 1.6)
	_puff_tex = _soft_disc()
	_led_on.albedo_color = Color("#ff2d2d")
	_led_on.emission_enabled = true
	_led_on.emission = Color("#ff2d2d")
	_led_on.emission_energy_multiplier = 4.0
	_led_off.albedo_color = Color("#5a1a1a")
	_shell.albedo_color = Color("#eceef1")
	_shell.roughness = 0.6


func _view():
	return wv.game.get("smoke_view")


func show_floor(f: int) -> void:
	if f == _floor:
		return
	_floor = f
	for r in _rooms:
		_rooms[r].queue_free()
	_rooms.clear()
	for d in _detectors:
		d[0].queue_free()
	_detectors.clear()
	var sv = _view()
	if sv == null:
		return
	for pos in sv._detectors.get(f, []):
		var n := Node3D.new()
		n.position = Coords.px_to_world(pos, f) + Vector3(0, Coords.WALL_H - 0.02, 0)
		var shell := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.1
		cyl.bottom_radius = 0.11
		cyl.height = 0.05
		cyl.radial_segments = 12
		shell.mesh = cyl
		shell.material_override = _shell
		n.add_child(shell)
		var led := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.022
		sm.height = 0.044
		sm.radial_segments = 6
		sm.rings = 3
		led.mesh = sm
		led.position = Vector3(0.05, 0.03, 0.05)
		n.add_child(led)
		var light := OmniLight3D.new()
		light.light_color = Color("#ff3020")
		light.omni_range = 4.0
		light.light_energy = 0.0
		light.visible = false
		n.add_child(light)
		add_child(n)
		_detectors.append([n, light, led])


func update(_delta: float) -> void:
	var sv = _view()
	if sv == null:
		return
	show_floor(wv.floor_shown)
	var t := Time.get_ticks_msec() / 1000.0
	var on: bool = sv.led_on(t)
	for d in _detectors:
		d[2].material_override = _led_on if on else _led_off
		d[1].visible = sv.alarm
		d[1].light_energy = 1.5 if on else 0.2
	var tiles: Dictionary = sv._tiles.get(_floor, {})
	for r in sv._shown:
		var level: float = sv._shown[r]
		if not _rooms.has(r):
			if level <= 0.01 or not tiles.has(r):
				continue
			_rooms[r] = _make_room(tiles[r])
			add_child(_rooms[r])
		var p: GPUParticles3D = _rooms[r]
		p.amount_ratio = clampf(0.15 + level, 0.0, 1.0)
		var mat: StandardMaterial3D = p.draw_pass_1.surface_get_material(0)
		var op: float = SmokeView.opacity(level)
		mat.albedo_color = Color(0.78, 0.76, 0.72, 0.12 + op * 0.4)
		p.emitting = level > 0.01
	for r in _rooms:
		if not sv._shown.has(r):
			_rooms[r].emitting = false  # the last puffs drift away


## Particles rising slowly from every tile of the room.
func _make_room(tiles: Array) -> GPUParticles3D:
	var y := Coords.floor_y(_floor)
	var img := Image.create(tiles.size(), 1, false, Image.FORMAT_RGBF)
	for i in tiles.size():
		var t: Vector2i = tiles[i]
		img.set_pixel(i, 0, Color(t.x + 0.5, y + 0.8, t.y + 0.5))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	pm.emission_point_texture = ImageTexture.create_from_image(img)
	pm.emission_point_count = tiles.size()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 80.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.2
	pm.gravity = Vector3(0, 0.04, 0)
	pm.damping_min = 0.05
	pm.damping_max = 0.1
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 4.0
	pm.turbulence_influence_min = 0.02
	pm.turbulence_influence_max = 0.06
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -12.0
	pm.angular_velocity_max = 12.0
	pm.scale_min = 0.7
	pm.scale_max = 1.4
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 1.3))
	var gt := CurveTexture.new()
	gt.curve = grow
	pm.scale_curve = gt
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.25, Color(1, 1, 1, 1))
	fade.add_point(0.7, Color(1, 1, 1, 0.8))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _puff_tex
	mat.roughness = 1.0
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 0.6
	var mesh: QuadMesh = _puff.duplicate()
	mesh.material = mat
	var p := GPUParticles3D.new()
	p.amount = clampi(tiles.size() * 2, 24, max_per_room)
	p.lifetime = 7.0
	p.preprocess = 4.0
	p.local_coords = false
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-200, -10, -200), Vector3(400, 40, 400))
	return p


static func _soft_disc() -> Texture2D:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(s, s) / 2.0) / (s / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
