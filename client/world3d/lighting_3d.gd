## Light of the 3D world: environment (tonemap, SSAO, glow, fog), the sun /
## moon and the sky by the time of day and weather, lightning flashes, room
## lamps (from LightView's state), street lamps at night, and the shader
## globals of atmos.gdshaderinc (the per-tile mask of the shown floor:
## outdoors, dark rooms, lamps; wet ground, night, clouds).
extends Node3D

const Coords = preload("res://world3d/coords.gd")
const Protocol = preload("res://net/protocol.gd")

## Colours through the day: [minute, sun, sky top, horizon].
const DAY_KEYS := [
	[0, Color("#4a5c9a"), Color("#04060f"), Color("#101830")],
	[330, Color("#4a5c9a"), Color("#070b1c"), Color("#1a2240")],
	[375, Color("#ff7436"), Color("#2c3a6c"), Color("#f08a5a")],
	[450, Color("#ffcf9c"), Color("#5a8cce"), Color("#f2cfae")],
	[600, Color("#fff3e4"), Color("#5f98dc"), Color("#d6e5f2")],
	[1020, Color("#fff0dc"), Color("#6396d8"), Color("#e0e4e8")],
	[1170, Color("#ffac62"), Color("#4b6aa8"), Color("#f4b47e")],
	[1260, Color("#ff6038"), Color("#262c5c"), Color("#c8645a")],
	[1320, Color("#4a5c9a"), Color("#080c1c"), Color("#161e3a")],
	[1440, Color("#4a5c9a"), Color("#04060f"), Color("#101830")],
]
const LAMP_COLOR := Color("#ffcf94")
const STREET_LAMP_COLOR := Color("#ffbf6e")

var wv: Node3D   # world_view.gd
var env := WorldEnvironment.new()
var sun := DirectionalLight3D.new()
var flash_light := DirectionalLight3D.new()
var night := 0.0       # 0 day .. 1 night (lamps, windows)
var day := 1.0         # LightView's daylight x weather
var flash := 0.0       # lightning 0..1
var _sky_mat := ShaderMaterial.new()
var _lamps := {}       # floor -> Array of [OmniLight3D, room]
var _street: Array = []  # OmniLight3D
var _rooms := {}       # floor -> PackedInt32Array per tile: room, -1 void, -2 wall
var _room_val := {}    # room -> Vector2(light, lamp) eased
var _mask_img: Image
var _mask_tex: ImageTexture
var _mask_floor := -1
var _wet := 0.0
var _clouds := 0.2
var _flash_t := 0.0
var riding := false  # in the elevator car: no lamps, black sky
var _snap := true    # next update: no easing (first frame, previews)


func setup(p_wv: Node3D) -> void:
	wv = p_wv
	name = "Lighting"
	_setup_environment()
	var w := 1
	var h := 1
	for f in wv.building.floors.size():
		var m = wv.building.get_floor(f)
		if m == null:
			continue
		w = maxi(w, m.width)
		h = maxi(h, m.height)
		var ids := PackedInt32Array()
		ids.resize(m.width * m.height)
		for y in m.height:
			for x in m.width:
				var ch: String = m.tile_chars[y * m.width + x]
				ids[y * m.width + x] = -1 if ch == "~" else (-2 if ch == "#" else m.room_at_tile(x, y))
		_rooms[f] = ids
	_mask_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	_mask_img.fill(Color(1, 1, 0, 0))
	_mask_tex = ImageTexture.create_from_image(_mask_img)
	RenderingServer.global_shader_parameter_set("atmos_mask", _mask_tex)
	RenderingServer.global_shader_parameter_set("atmos_mask_size", Vector2(w, h))


func _setup_environment() -> void:
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	_sky_mat.shader = load("res://world3d/shaders/sky.gdshader")
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#b9b4c4")
	e.ambient_light_energy = 0.5
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.05
	e.tonemap_white = 8.0
	e.ssao_enabled = true
	e.ssao_radius = 0.9
	e.ssao_intensity = 2.6
	e.ssao_power = 1.5
	e.ssao_detail = 0.6
	e.ssao_light_affect = 0.15
	e.ssil_enabled = false  # too costly at Retina resolution
	e.ssil_radius = 3.0
	e.ssil_intensity = 0.7
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.glow_strength = 0.9
	e.glow_bloom = 0.03
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.18
	e.adjustment_contrast = 1.06
	e.fog_enabled = false
	e.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	e.fog_sky_affect = 0.6
	env.environment = e
	add_child(env)
	sun.light_color = Color("#fff1dc")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 55.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-35), 0)
	add_child(sun)
	# lightning: a cold light from high above, no shadows, off between strikes
	flash_light.light_color = Color("#dfe6ff")
	flash_light.light_energy = 0.0
	flash_light.shadow_enabled = false
	flash_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	flash_light.rotation = Vector3(deg_to_rad(-75), deg_to_rad(20), 0)
	flash_light.visible = false
	add_child(flash_light)


## Room lamps of a built floor (map_builder's "lamps" meta); floor 0 also
## gets lights in its street lamps.
func add_lamps(f: int, node: Node3D) -> void:
	_lamps[f] = []
	for l in node.get_meta("lamps", []):
		var o := OmniLight3D.new()
		o.position = l.pos
		o.omni_range = l.range
		o.omni_attenuation = 1.1
		o.light_color = LAMP_COLOR
		o.light_energy = 0.0
		o.shadow_enabled = false
		o.light_specular = 0.35
		o.visible = false
		o.distance_fade_enabled = true
		o.distance_fade_begin = 45.0
		o.distance_fade_length = 10.0
		node.add_child(o)
		_lamps[f].append([o, l.room])
	if f != 0:
		return
	# Same rule as map_builder's street lamps: the head hangs over the street.
	var m = wv.building.get_floor(0)
	for y in m.height:
		for x in range(2, m.width - 2, 7):
			if _type(m, x, y) == "sidewalk" and _type(m, x, y + 1) == "street":
				var o := OmniLight3D.new()
				o.position = Vector3(x + 0.5, 3.3, y + 0.6 + 0.58)
				o.omni_range = 7.0
				o.omni_attenuation = 1.7
				o.light_color = STREET_LAMP_COLOR
				o.light_energy = 0.0
				o.shadow_enabled = false
				o.visible = false
				o.distance_fade_enabled = true
				o.distance_fade_begin = 40.0
				o.distance_fade_length = 10.0
				node.add_child(o)
				_street.append(o)


static func _type(m, x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= m.width or y >= m.height:
		return ""
	return m.legend.get(m.tile_chars[y * m.width + x], {}).get("type", "")


func show_floor(f: int) -> void:
	for k in _lamps:
		for pair in _lamps[k]:
			pair[0].visible = k == f and pair[0].light_energy > 0.01
	RenderingServer.global_shader_parameter_set("atmos_floor_y", Coords.floor_y(f))
	_room_val.clear()
	_mask_floor = -1


## Riding the elevator: lamps and street lights off, a black background.
func set_ride(on: bool) -> void:
	riding = on
	var e: Environment = env.environment
	e.background_mode = Environment.BG_COLOR if on else Environment.BG_SKY
	e.background_color = Color("#0b0c10")
	if on:
		for k in _lamps:
			for pair in _lamps[k]:
				pair[0].visible = false
		for o in _street:
			o.visible = false


## Jump to the current time / weather on the next update (no easing).
func snap() -> void:
	_snap = true


## Lightning (in sync with the thunder: weather_fx's signal).
func strike() -> void:
	flash = 1.0
	_flash_t = 0.0


static func _key_colors(minute: float) -> Array:
	for i in DAY_KEYS.size() - 1:
		var a: Array = DAY_KEYS[i]
		var b: Array = DAY_KEYS[i + 1]
		if minute >= a[0] and minute <= b[0]:
			var t := smoothstep(0.0, 1.0, (minute - a[0]) / float(b[0] - a[0]))
			return [a[1].lerp(b[1], t), a[2].lerp(b[2], t), a[3].lerp(b[3], t)]
	return [DAY_KEYS[0][1], DAY_KEYS[0][2], DAY_KEYS[0][3]]


## Sun, sky, fog, lamps and the mask, every frame.
func update(delta: float) -> void:
	var game = wv.game
	var minute: int = game.game_minute
	var weather: int = game.weather
	var lv = game.light_view
	var wf: float = lv.weather_factor(weather)
	day = lv.daylight(minute) * wf
	night = clampf((0.62 - day) / 0.42, 0.0, 1.0)
	var keys := _key_colors(minute)
	var gray := 1.0 - wf  # 0 sunny .. 0.6 storm
	var sun_col: Color = keys[0].lerp(Color(0.75, 0.78, 0.82), clampf(gray * 1.4, 0.0, 0.8))
	# the sun from the east (morning) to the west (evening); the moon at night
	var t := (minute - 6 * 60) / float(15.5 * 60)
	var aim: Vector3
	if t > 0.0 and t < 1.0:
		var elev := lerpf(5.0, 62.0, sin(t * PI))
		aim = Vector3(deg_to_rad(-elev), deg_to_rad(lerpf(-80.0, 80.0, t) - 25.0), 0)
	else:
		aim = Vector3(deg_to_rad(-48), deg_to_rad(30), 0)
	var k := 1.0 if _snap else minf(1.0, delta * 2.0)
	sun.rotation = Vector3(lerp_angle(sun.rotation.x, aim.x, k), lerp_angle(sun.rotation.y, aim.y, k), 0)
	sun.light_color = sun_col
	sun.light_energy = lerpf(0.14, 1.5, day)
	sun.shadow_opacity = lerpf(1.0, 0.35, clampf(gray * 1.6, 0.0, 1.0))
	# lightning: a double flicker, fading
	if flash > 0.0:
		_flash_t += delta
		var flicker := 1.0 if _flash_t < 0.07 or (_flash_t > 0.16 and _flash_t < 0.3) else 0.35
		flash = maxf(0.0, flash - delta * 1.6)
		flash_light.light_energy = flash * flicker * 1.6
	flash_light.visible = flash > 0.0
	var fl := flash * (1.0 if _flash_t < 0.3 else 0.4)
	var e: Environment = env.environment
	var amb_day: Color = Color("#c2bccb").lerp(keys[2], 0.15)
	e.ambient_light_color = Color("#46507e").lerp(amb_day, clampf(day * 1.2, 0.0, 1.0)).lerp(Color("#9aa4b4"), gray * 0.5)
	e.ambient_light_energy = lerpf(0.2, 0.55, day) + fl * 0.3
	var top: Color = keys[1].lerp(Color("#5d6470") * lerpf(0.3, 1.0, day), clampf(gray * 1.5, 0.0, 0.85))
	var hor: Color = keys[2].lerp(Color("#8a929c") * lerpf(0.3, 1.0, day), clampf(gray * 1.5, 0.0, 0.85))
	_sky_mat.set_shader_parameter("top_color", top)
	_sky_mat.set_shader_parameter("horizon_color", hor)
	_sky_mat.set_shader_parameter("ground_color", hor.darkened(0.55))
	_sky_mat.set_shader_parameter("cloud_color", hor.lerp(Color(1, 1, 1) * lerpf(0.15, 1.0, day), 0.6))
	_sky_mat.set_shader_parameter("night", night * (1.0 - clampf(gray * 1.4, 0.0, 0.9)))
	_sky_mat.set_shader_parameter("flash", fl)
	_sky_mat.set_shader_parameter("energy", lerpf(0.5, 1.0, day))
	var want_clouds: float = {Protocol.WEATHER_CLOUDY: 0.65, Protocol.WEATHER_RAIN: 0.9, Protocol.WEATHER_STORM: 1.0, Protocol.WEATHER_FOG: 0.5}.get(weather, 0.15)
	_clouds = want_clouds if _snap else move_toward(_clouds, want_clouds, delta * 0.2)
	_sky_mat.set_shader_parameter("clouds", _clouds)
	# fog: thick ground fog in fog weather, a light haze in rain
	var fog_d: float = {Protocol.WEATHER_FOG: 0.025, Protocol.WEATHER_RAIN: 0.012, Protocol.WEATHER_STORM: 0.018}.get(weather, 0.0)
	e.fog_density = fog_d if _snap else move_toward(e.fog_density if e.fog_enabled else 0.0, fog_d, delta * 0.02)
	e.fog_enabled = e.fog_density > 0.0005
	e.fog_light_color = hor.lerp(Color("#c4c8cc") * lerpf(0.25, 1.0, day), 0.5)
	e.fog_light_energy = 1.0
	e.fog_height = Coords.floor_y(maxi(wv.floor_shown, 0)) + 2.2
	e.fog_height_density = 0.35 if weather == Protocol.WEATHER_FOG else 0.0
	e.fog_aerial_perspective = 0.2
	e.glow_intensity = lerpf(0.9, 0.5, day)
	e.tonemap_exposure = lerpf(1.1, 1.05, day)
	# wet ground: soaks quickly in the rain, dries slowly
	var raining := weather == Protocol.WEATHER_RAIN or weather == Protocol.WEATHER_STORM
	_wet = move_toward(_wet, 1.0 if raining else 0.0, 1.0 if _snap else delta * (0.15 if raining else 0.01))
	RenderingServer.global_shader_parameter_set("atmos_wet", _wet)
	RenderingServer.global_shader_parameter_set("atmos_night", night)
	RenderingServer.global_shader_parameter_set("atmos_clouds", _clouds)
	_update_lamps(100.0 if _snap else delta, lv)
	_update_mask(delta, lv)
	_snap = false


func _update_lamps(delta: float, lv) -> void:
	var f: int = wv.floor_shown
	var m = wv.building.get_floor(f)
	if riding:
		return
	var lamp_e := lerpf(1.0, 0.35, day) + night * 0.2
	for pair in _lamps.get(f, []):
		var on: bool = m != null and lv.lamp_on(m, pair[1])
		var o: OmniLight3D = pair[0]
		o.light_energy = move_toward(o.light_energy, lamp_e if on else 0.0, delta * 4.0)
		o.visible = o.light_energy > 0.01
	var street_e := smoothstep(0.25, 0.75, night) * 3.2
	for o in _street:
		o.light_energy = move_toward(o.light_energy, street_e, delta * 1.5)
		o.visible = o.light_energy > 0.01


## The per-tile mask of the shown floor (eased per room; the texture is
## re-uploaded only when something changed).
func _update_mask(delta: float, lv) -> void:
	var f: int = wv.floor_shown
	var m = wv.building.get_floor(f)
	if m == null:
		return
	var changed := _mask_floor != f
	var fresh := changed
	var targets := {}
	for r in m.room_names:
		targets[r] = _room_target(m, r, lv)
	targets[0] = Vector2(1, 0)
	for r in targets:
		var want: Vector2 = targets[r]
		var was: Vector2 = _room_val.get(r, Vector2(-1, -1))
		var now := want if fresh or was.x < 0.0 else Vector2(move_toward(was.x, want.x, delta * 3.0), move_toward(was.y, want.y, delta * 3.0))
		if now != was:
			_room_val[r] = now
			changed = true
	if not changed:
		return
	if fresh:
		_mask_img.fill(Color(1, 1, 0, 0))
	_mask_floor = f
	var ids: PackedInt32Array = _rooms[f]
	var w: int = m.width
	for y in m.height:
		for x in w:
			var r: int = ids[y * w + x]
			if r == -1:
				_mask_img.set_pixel(x, y, Color(1, 1, 0, 0))
				continue
			var rr := r
			if r == -2:
				rr = _wall_room(ids, w, m.height, x, y)
			var v: Vector2 = _room_val.get(rr, Vector2(1, 0))
			var outdoor := 1.0 if r >= 0 and m.room_outdoor.has(r) else 0.0
			_mask_img.set_pixel(x, y, Color(outdoor, v.x, 1.0, v.y))
	_mask_tex.update(_mask_img)


## A wall tile takes the light of a room next to it (the darker one).
static func _wall_room(ids: PackedInt32Array, w: int, h: int, x: int, y: int) -> int:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = Vector2i(x, y) + d
		if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and ids[q.y * w + q.x] >= 0:
			return ids[q.y * w + q.x]
	return 0


## (light, lamp) of a room: windowless rooms with the lamp off are dark,
## as in LightView.
static func _room_target(m, r: int, lv) -> Vector2:
	var lamp_room: int = m.room_lit_by.get(r, r)
	var kind: String = m.room_light.get(lamp_room, "")
	if m.room_outdoor.has(r) or (kind == "" and not m.room_lit_by.has(r)):
		return Vector2(1, 0)
	if lv.lamp_on(m, r):
		return Vector2(1, 1)
	return Vector2(1, 0) if m.room_windows.has(r) else Vector2(0.14, 0)
