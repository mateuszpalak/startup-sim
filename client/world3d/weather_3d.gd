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
	var fx = wv.game.get("weather_fx")
	if fx:
		fx.visible = false  # the 3D rain replaces the screen overlay
		fx.lightning.connect(strike)


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
	var n := int(_amount * RAIN_MAX)
	_rain.multimesh.visible_instance_count = n
	_splash.multimesh.visible_instance_count = int(_amount * SPLASH_MAX)
	_rain.visible = n > 0
	_splash.visible = n > 0
	if n == 0:
		return
	var storm := weather == Protocol.WEATHER_STORM
	var lit: float = lerpf(0.3, 0.9, wv.lighting.day) + wv.lighting.flash * 2.0
	var c := Vector3(focus.x, 0, focus.z)
	_rain_mat.set_shader_parameter("center", c)
	_rain_mat.set_shader_parameter("wind", 0.32 if storm else 0.12)
	_rain_mat.set_shader_parameter("speed", 16.0 if storm else 13.0)
	_rain_mat.set_shader_parameter("tint", Color(0.72 * lit, 0.8 * lit, 0.92 * lit, 0.5))
	_splash_mat.set_shader_parameter("center", c)
	_splash_mat.set_shader_parameter("tint", Color(0.8 * lit, 0.86 * lit, 0.95 * lit, 0.35))
