## Weather in the 3D world: rain streaks and splashes over the outdoor
## tiles (GPU-animated MultiMeshes, rain.gdshader / splash.gdshader), a
## storm with lightning flashes in sync with the thunder (weather_fx's
## signal, which also plays the sound). Fog, wet ground and the sky are in
## lighting_3d.gd. The 2D screen overlay (ui/weather_fx.gd) is hidden but
## keeps running for its lightning timing.
extends Node3D

const Protocol = preload("res://net/protocol.gd")

const RAIN_MAX := 5000
const SPLASH_MAX := 900

var wv: Node3D   # world_view.gd
var _rain := MultiMeshInstance3D.new()
var _splash := MultiMeshInstance3D.new()
var _rain_mat := ShaderMaterial.new()
var _splash_mat := ShaderMaterial.new()
var _amount := 0.0   # 0..1 of RAIN_MAX, eased
var _wisps := GPUParticles3D.new()   # fog banks drifting low over the ground
var _snap := true    # next update: no easing (first frame, previews)


func setup(p_wv: Node3D) -> void:
	wv = p_wv
	name = "Weather"
	_rain_mat.shader = load("res://world3d/shaders/rain.gdshader")
	_splash_mat.shader = load("res://world3d/shaders/splash.gdshader")
	for pair in [[_rain, _rain_mat, RAIN_MAX], [_splash, _splash_mat, SPLASH_MAX]]:
		var mi: MultiMeshInstance3D = pair[0]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		mm.mesh = q
		mm.instance_count = pair[2]
		var buf := PackedFloat32Array()
		buf.resize(pair[2] * 12)
		for i in pair[2]:
			buf[i * 12] = 1.0       # identity: the shader places the drops
			buf[i * 12 + 5] = 1.0
			buf[i * 12 + 10] = 1.0
		mm.buffer = buf
		mm.visible_instance_count = 0
		mi.multimesh = mm
		mi.material_override = pair[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-500, -50, -500), Vector3(1000, 200, 1000))
		mi.visible = false
		add_child(mi)
	_setup_wisps()
	var fx = wv.game.get("weather_fx")
	if fx:
		fx.visible = false  # the 3D rain replaces the screen overlay
		fx.lightning.connect(strike)


func _setup_wisps() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(24, 1.0, 18)
	pm.direction = Vector3(1, 0, 0.3)
	pm.spread = 20.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.8
	pm.scale_max = 1.6
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 1))
	fade.add_point(0.7, Color(1, 1, 1, 1))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = preload("res://world3d/smoke_3d.gd")._soft_disc()
	mat.albedo_color = Color(0.85, 0.87, 0.9, 0.4)
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 1.5
	var q := QuadMesh.new()
	q.size = Vector2(7, 7)
	q.material = mat
	_wisps.amount = 120
	_wisps.lifetime = 24.0
	_wisps.preprocess = 24.0
	_wisps.local_coords = false
	_wisps.process_material = pm
	_wisps.draw_pass_1 = q
	_wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wisps.visibility_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 15, 80))
	_wisps.emitting = false
	_wisps.visible = false
	add_child(_wisps)


## Jump to the current weather on the next update (no easing).
func snap() -> void:
	_snap = true
	wv.lighting.snap()


## A lightning strike (the thunder plays from the same signal).
func strike() -> void:
	wv.lighting.strike()


func update(delta: float, focus: Vector3) -> void:
	var weather: int = wv.game.weather
	var want: float = {Protocol.WEATHER_RAIN: 0.5, Protocol.WEATHER_STORM: 1.0}.get(weather, 0.0)
	_amount = want if _snap else move_toward(_amount, want, delta * 0.4)
	_snap = false
	var fog := weather == Protocol.WEATHER_FOG
	_wisps.emitting = fog
	_wisps.visible = fog or _wisps.emitting
	if fog:
		_wisps.position = Vector3(focus.x, focus.y + 2.2, focus.z)
		var dl: float = lerpf(0.25, 1.0, wv.lighting.day)
		_wisps.draw_pass_1.material.albedo_color = Color(0.85 * dl, 0.87 * dl, 0.9 * dl, 0.4)
	var n := int(_amount * RAIN_MAX)
	_rain.multimesh.visible_instance_count = n
	_splash.multimesh.visible_instance_count = int(_amount * SPLASH_MAX)
	_rain.visible = n > 0
	_splash.visible = n > 0
	if n == 0:
		return
	var storm := weather == Protocol.WEATHER_STORM
	var lit: float = lerpf(0.3, 0.9, wv.lighting.day) + wv.lighting.flash * 0.5
	var c := Vector3(focus.x, 0, focus.z)
	_rain_mat.set_shader_parameter("center", c)
	_rain_mat.set_shader_parameter("wind", 0.32 if storm else 0.12)
	_rain_mat.set_shader_parameter("speed", 16.0 if storm else 13.0)
	_rain_mat.set_shader_parameter("tint", Color(0.72 * lit, 0.8 * lit, 0.92 * lit, 0.5))
	_splash_mat.set_shader_parameter("center", c)
	_splash_mat.set_shader_parameter("tint", Color(0.8 * lit, 0.86 * lit, 0.95 * lit, 0.35))
