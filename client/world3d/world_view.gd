## The 3D presentation of the game world. game.gd keeps all the logic
## (network, prediction, interpolation, hints, UI) and its 2D views as
## invisible state holders; this node mirrors them in 3D every frame:
##   - environment, sun and sky by the time of day / weather,
##   - one built mesh per floor (map_builder.gd), the current one shown,
##     the street level under the upper floors,
##   - an Avatar3D per PlayerView (me + remotes), nick / bubble tags placed
##     on screen over their heads (the 2D tags, re-used),
##   - a 3D view per entity / door 2D view (ENTITY_VIEWS: items, vehicles,
##     laptops, TVs, trays, elevator and stall doors), placeholder boxes for
##     the rest (ENTITY_PROXIES),
##   - the elevator car alone while riding (RideCabin3D, from game.ride_mask),
##   - room lamps (from LightView's state), the camera with wall cutaway.
extends Node3D

const Coords = preload("res://world3d/coords.gd")
const MapBuilder = preload("res://world3d/map_builder.gd")
const Materials = preload("res://world3d/materials.gd")
const CameraRig = preload("res://world3d/camera_rig.gd")
const Avatar3D = preload("res://world3d/avatar_3d.gd")
const PlayerView = preload("res://game/player_view.gd")
const Protocol = preload("res://net/protocol.gd")

const RideCabin3D = preload("res://world3d/ride_cabin_3d.gd")

## 2D view script (under game.world) -> its 3D view script. A 3D view has
## setup(view_2d, world_view) and sync(world_pos, delta); it is shown while
## the 2D view is visible.
const ENTITY_VIEWS := {
	"res://game/item_view.gd": preload("res://world3d/item_3d.gd"),
	"res://game/vehicle_view.gd": preload("res://world3d/vehicle_3d.gd"),
	"res://game/computer_view.gd": preload("res://world3d/computer_3d.gd"),
	"res://game/tv_view.gd": preload("res://world3d/tv_3d.gd"),
	"res://game/tray_view.gd": preload("res://world3d/tray_3d.gd"),
	"res://game/elevator_door_view.gd": preload("res://world3d/elevator_door_3d.gd"),
	"res://game/stall_door_view.gd": preload("res://world3d/stall_door_3d.gd"),
}
## 2D entity view script -> [size (x, y, z) m, colour]: plain boxes until
## each gets its own 3D view.
const ENTITY_PROXIES := {
	"res://game/puddle_view.gd": [Vector3(0.7, 0.01, 0.6), Color(0.85, 0.8, 0.3, 0.7)],
	"res://game/blood_splash.gd": [Vector3(0.4, 0.01, 0.4), Color("#9b1b1b")],
}

var game: Node   # game.gd
var building
var rig := CameraRig.new()
var sun := DirectionalLight3D.new()
var env := WorldEnvironment.new()
var floors := {}        # floor -> Node3D (built map)
var floor_shown := -1
var avatars := {}       # PlayerView (instance id) -> Avatar3D
var proxies := {}       # 2D node (instance id) -> MeshInstance3D
var views3d := {}       # 2D node (instance id) -> 3D view (ENTITY_VIEWS)
var ride_cabin := RideCabin3D.new()
var _lamps := {}        # floor -> Array of [OmniLight3D, room]
var _sky_mat := ProceduralSkyMaterial.new()
var _riding := false


func setup(p_game: Node, p_building) -> void:
	game = p_game
	building = p_building
	name = "World3D"
	_setup_environment()
	add_child(rig)
	rig.camera.make_current()
	add_child(ride_cabin)
	var names := {}  # where stairs lead (not "to the stairwell")
	for g in building.floors.size():
		if not building.floors[g].stairwell:
			names[g] = building.floor_name(g)
	var t0 := Time.get_ticks_msec()
	for f in building.floors.size():
		if building.get_floor(f) == null:
			continue
		var node: Node3D = MapBuilder.new().build(building, f, names)
		node.visible = false
		add_child(node)
		floors[f] = node
		_add_lamps(f, node)
	print("3D: floors built in %d ms" % (Time.get_ticks_msec() - t0))


func _setup_environment() -> void:
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	_sky_mat.sky_top_color = Color("#6f9fd8")
	_sky_mat.sky_horizon_color = Color("#d9e4ee")
	_sky_mat.ground_bottom_color = Color("#3e4a3a")
	_sky_mat.ground_horizon_color = Color("#c9d4dc")
	_sky_mat.sun_angle_max = 20.0
	sky.sky_material = _sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#b9b4c4")
	e.ambient_light_energy = 0.5
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.82
	e.tonemap_white = 6.0
	e.ssao_enabled = true
	e.ssao_radius = 0.9
	e.ssao_intensity = 3.0
	e.ssao_power = 1.6
	e.ssao_detail = 0.6
	e.ssil_enabled = false
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_strength = 0.9
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 1.1
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.2
	e.adjustment_contrast = 1.08
	e.fog_enabled = false
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


func _add_lamps(f: int, node: Node3D) -> void:
	_lamps[f] = []
	for l in node.get_meta("lamps", []):
		var o := OmniLight3D.new()
		o.position = l.pos
		o.omni_range = l.range
		o.omni_attenuation = 1.2
		o.light_color = Color("#ffd9a8")
		o.light_energy = 0.0
		o.shadow_enabled = false
		o.light_specular = 0.3
		o.visible = false
		node.add_child(o)
		_lamps[f].append([o, l.room])


## Show floor `f` (and the street below an upper floor).
func show_floor(f: int) -> void:
	floor_shown = f
	for k in floors:
		floors[k].visible = k == f or (k == 0 and f != 0)
	for k in _lamps:
		for pair in _lamps[k]:
			pair[0].visible = k == f
	Materials.wall().set_shader_parameter("floor_y", Coords.floor_y(f))


func set_zoom(z: float) -> void:
	rig.zoom_level = z


## Map direction of a movement key under the current camera turn.
func screen_to_map(d: Vector2i) -> Vector2i:
	return rig.screen_to_map(d)


## World position of something on the shown floor at world pixels `p`
## (+ the height of stairs under it).
func px_to_world(p: Vector2) -> Vector3:
	var v := Coords.px_to_world(p, maxi(floor_shown, 0))
	var node: Node3D = floors.get(floor_shown)
	if node:
		var hs: Dictionary = node.get_meta("heights", {})
		if not hs.is_empty():
			var t := Vector2i(floori(p.x / Coords.TILE_PX), floori(p.y / Coords.TILE_PX))
			v.y += hs.get(t, 0.0)
	return v


func _process(delta: float) -> void:
	if game == null or floor_shown < 0:
		return
	_sync_avatars(delta)
	_sync_proxies()
	_sync_views(delta)
	_sync_ride()
	var me: Node2D = game.me
	var focus := px_to_world(me.position)
	rig.shake = game.camera.offset
	rig.follow(focus, delta)
	var wall := Materials.wall()
	wall.set_shader_parameter("focus", focus + Vector3(0, 1.0, 0))
	wall.set_shader_parameter("cam_pos", rig.camera.global_position)
	_place_tags()
	_update_sky(delta)


# ------------------------------------------------------------- characters

func _views() -> Array:
	var out: Array = [game.me]
	out.append_array(game.remotes.values())
	return out


func _sync_avatars(delta: float) -> void:
	var seen := {}
	for v in _views():
		if not is_instance_valid(v):
			continue
		var id: int = v.get_instance_id()
		seen[id] = true
		var a: Node3D = avatars.get(id)
		if a == null:
			a = Avatar3D.new()
			add_child(a)
			a.setup(v)
			avatars[id] = a
		a.sync(px_to_world(v.position), delta)
	for id in avatars.keys():
		if not seen.has(id):
			avatars[id].queue_free()
			avatars.erase(id)


## The 2D nick / bubble tags of the PlayerViews, put on screen over the
## 3D heads (they live on a CanvasLayer that doesn't follow the 2D camera).
func _place_tags() -> void:
	var cam := rig.camera
	for id in avatars:
		var a: Node3D = avatars[id]
		var v: Node2D = a.view
		if not is_instance_valid(v):
			continue
		var tag: Node2D = v._tag
		var head: Vector3 = a.global_position + Vector3(0, 1.85, 0)
		if cam.is_position_behind(head) or not a.visible:
			tag.visible = false
			continue
		tag.visible = true
		tag.position = cam.unproject_position(head) - Vector2(0, PlayerView.HEAD_TOP)


# ------------------------------------------------------------- other things

func _sync_proxies() -> void:
	var seen := {}
	for n in game.world.get_children():
		if n is PlayerView or not (n is Node2D):
			continue
		var path: String = n.get_script().resource_path if n.get_script() else ""
		if not ENTITY_PROXIES.has(path):
			continue
		var id: int = n.get_instance_id()
		seen[id] = true
		var mi: MeshInstance3D = proxies.get(id)
		if mi == null:
			mi = _make_proxy(path)
			add_child(mi)
			proxies[id] = mi
		mi.visible = n.visible
		var p := px_to_world(n.position)
		mi.position = p + Vector3(0, (mi.mesh as BoxMesh).size.y / 2 if mi.mesh is BoxMesh else 0.0, 0)
	for n in game.puddle_layer.get_children():
		var id: int = n.get_instance_id()
		seen[id] = true
		var mi: MeshInstance3D = proxies.get(id)
		if mi == null:
			mi = _make_proxy("res://game/puddle_view.gd")
			add_child(mi)
			proxies[id] = mi
		mi.position = px_to_world(n.position) + Vector3(0, 0.01, 0)
	for id in proxies.keys():
		if not seen.has(id):
			proxies[id].queue_free()
			proxies.erase(id)


func _make_proxy(path: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.6
	var spec: Array = ENTITY_PROXIES[path]
	box.size = spec[0]
	mat.albedo_color = spec[1]
	if spec[1].a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.mesh = box
	mi.material_override = mat
	return mi


## The 3D views of ENTITY_VIEWS, following their 2D views.
func _sync_views(delta: float) -> void:
	var seen := {}
	for n in game.world.get_children():
		if n is PlayerView or not (n is Node2D) or n.get_script() == null:
			continue
		var script = ENTITY_VIEWS.get(n.get_script().resource_path)
		if script == null:
			continue
		var id: int = n.get_instance_id()
		seen[id] = true
		var v: Node3D = views3d.get(id)
		if v == null:
			v = script.new()
			add_child(v)
			v.setup(n, self)
			views3d[id] = v
		v.visible = n.visible
		if n.visible:
			v.sync(px_to_world(n.position), delta)
	for id in views3d.keys():
		if not seen.has(id):
			views3d[id].queue_free()
			views3d.erase(id)


## Riding the elevator (game.ride_mask up): only the car is drawn - the
## floor, its lamps and everybody outside the car are hidden, the sky goes
## black.
func _sync_ride() -> void:
	var mask = game.get("ride_mask")
	var riding: bool = mask != null and mask.visible
	if riding:
		var h: Rect2 = mask.hole.grow(-2.0)
		ride_cabin.show_cabin(Rect2(h.position * Coords.PX, h.size * Coords.PX), Coords.floor_y(maxi(floor_shown, 0)))
		for id in avatars:
			var a: Node3D = avatars[id]
			var p: Vector2 = a.view.position
			if not h.grow(4.0).has_point(p):
				a.visible = false
		for k in floors:
			floors[k].visible = false
	if riding == _riding:
		return
	_riding = riding
	ride_cabin.visible = riding
	if not riding:
		show_floor(floor_shown)
	var e: Environment = env.environment
	e.background_mode = Environment.BG_COLOR if riding else Environment.BG_SKY
	e.background_color = Color("#0b0c10")


# ------------------------------------------------------------- light

## Sun, sky and lamps by the game's time of day and weather.
func _update_sky(delta: float) -> void:
	var minute: int = game.game_minute
	var weather: int = game.weather
	var lv = game.light_view
	var day: float = lv.daylight(minute) * lv.weather_factor(weather)
	var tint: Color = game.daylight_color(minute)
	# the sun travels from the east (morning) to the west (evening)
	var t := clampf((minute - 6 * 60) / float(16 * 60), 0.0, 1.0)
	var elev := lerpf(12.0, 62.0, sin(t * PI))
	var az := lerpf(-80.0, 80.0, t) - 25.0
	sun.rotation = sun.rotation.lerp(Vector3(deg_to_rad(-elev), deg_to_rad(az), 0), minf(1.0, delta * 2.0))
	sun.light_color = Color("#ffe4c2") * tint
	sun.light_energy = lerpf(0.06, 1.45, day)
	var e: Environment = env.environment
	e.ambient_light_energy = lerpf(0.12, 0.5, day)
	e.ambient_light_color = Color("#5a6488").lerp(Color("#bdb6c2"), day)
	_sky_mat.sky_top_color = Color("#141a33").lerp(Color("#6f9fd8"), day) * Color(tint.r, tint.g, tint.b)
	_sky_mat.sky_horizon_color = Color("#2a2f4a").lerp(Color("#dfe6ee"), day) * tint
	_sky_mat.ground_horizon_color = _sky_mat.sky_horizon_color
	_sky_mat.sky_energy_multiplier = lerpf(0.35, 1.0, day)
	var gray := weather in [Protocol.WEATHER_CLOUDY, Protocol.WEATHER_RAIN, Protocol.WEATHER_STORM, Protocol.WEATHER_FOG]
	sun.shadow_opacity = 0.55 if gray else 1.0
	e.fog_enabled = weather == Protocol.WEATHER_FOG
	e.fog_density = 0.02
	e.fog_light_color = Color("#c9ccd2")
	# lamps: the rooms LightView says are lit (or always-lit), stronger at night
	var m = building.get_floor(floor_shown)
	var lamp_e := lerpf(1.6, 0.35, day)
	for pair in _lamps.get(floor_shown, []):
		var on: bool = m != null and lv.lamp_on(m, pair[1])
		var o: OmniLight3D = pair[0]
		o.light_energy = move_toward(o.light_energy, lamp_e if on else 0.0, delta * 4.0)
		o.visible = o.light_energy > 0.01
