## The 3D presentation of the game world. game.gd keeps all the logic
## (network, prediction, interpolation, hints, UI) and its 2D views as
## invisible state holders; this node mirrors them in 3D every frame:
##   - environment, sun and sky by the time of day / weather,
##   - one built mesh per floor (map_builder.gd), the current one shown,
##     the street level under the upper floors,
##   - an Avatar3D per PlayerView (me + remotes), nick / bubble tags placed
##     on screen over their heads (the 2D tags, re-used),
##   - placeholder stand-ins for other entities (items, vehicles... - see
##     ENTITY_PROXIES; each gets a proper 3D view later),
##   - the camera with wall cutaway,
##   - atmosphere: light / sky / lamps / dark rooms (lighting_3d.gd), rain and
##     lightning (weather_3d.gd), smoke (smoke_3d.gd), puddles (puddle_3d.gd),
##     blood (blood_3d.gd).
extends Node3D

const Coords = preload("res://world3d/coords.gd")
const MapBuilder = preload("res://world3d/map_builder.gd")
const Materials = preload("res://world3d/materials.gd")
const CameraRig = preload("res://world3d/camera_rig.gd")
const Avatar3D = preload("res://world3d/avatar_3d.gd")
const PlayerView = preload("res://game/player_view.gd")
const Protocol = preload("res://net/protocol.gd")
const Lighting3D = preload("res://world3d/lighting_3d.gd")
const Weather3D = preload("res://world3d/weather_3d.gd")
const Smoke3D = preload("res://world3d/smoke_3d.gd")
const Puddle3D = preload("res://world3d/puddle_3d.gd")
const Blood3D = preload("res://world3d/blood_3d.gd")

## 2D entity view script -> [size (x, y, z) m, colour]: plain boxes until
## each gets its own 3D view.
const ENTITY_PROXIES := {
	"res://game/item_view.gd": [Vector3(0.25, 0.12, 0.2), Color("#e0c060")],
	"res://game/computer_view.gd": [Vector3(0.36, 0.03, 0.26), Color("#3a3d44")],
	"res://game/tray_view.gd": [Vector3(0.5, 0.05, 0.35), Color("#d8d2c4")],
	"res://game/tv_view.gd": [Vector3(0.0, 0.0, 0.0), Color.BLACK],
}
const VEHICLE_SIZES := {1: Vector3(3.6, 1.4, 1.7), 2: Vector3(1.6, 1.1, 0.4), 3: Vector3(3.8, 1.5, 1.7),
	4: Vector3(14.0, 3.0, 2.4), 5: Vector3(3.8, 1.5, 1.7), 6: Vector3(6.0, 2.6, 2.3)}

var game: Node   # game.gd
var building
var rig := CameraRig.new()
var lighting := Lighting3D.new()
var weather := Weather3D.new()
var smoke := Smoke3D.new()
var puddles := Puddle3D.new()
var blood := Blood3D.new()
var floors := {}        # floor -> Node3D (built map)
var floor_shown := -1
var avatars := {}       # PlayerView (instance id) -> Avatar3D
var proxies := {}       # 2D node (instance id) -> MeshInstance3D


func setup(p_game: Node, p_building) -> void:
	game = p_game
	building = p_building
	name = "World3D"
	add_child(lighting)
	lighting.setup(self)
	for fx in [weather, smoke, puddles, blood]:
		add_child(fx)
		fx.setup(self)
	add_child(rig)
	rig.camera.make_current()
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
		lighting.add_lamps(f, node)
	print("3D: floors built in %d ms" % (Time.get_ticks_msec() - t0))


## Show floor `f` (and the street below an upper floor).
func show_floor(f: int) -> void:
	floor_shown = f
	for k in floors:
		floors[k].visible = k == f or (k == 0 and f != 0)
	lighting.show_floor(f)
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
	var me: Node2D = game.me
	var focus := px_to_world(me.position)
	rig.shake = game.camera.offset
	rig.follow(focus, delta)
	var wall := Materials.wall()
	wall.set_shader_parameter("focus", focus + Vector3(0, 1.0, 0))
	wall.set_shader_parameter("cam_pos", rig.camera.global_position)
	_place_tags()
	lighting.update(delta)
	weather.update(delta, focus)
	smoke.update(delta)
	puddles.update()
	blood.update()


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
		var is_vehicle := path == "res://game/vehicle_view.gd"
		if not is_vehicle and not ENTITY_PROXIES.has(path):
			continue
		var id: int = n.get_instance_id()
		seen[id] = true
		var mi: MeshInstance3D = proxies.get(id)
		if mi == null:
			mi = _make_proxy(n, path, is_vehicle)
			add_child(mi)
			proxies[id] = mi
		mi.visible = n.visible
		var p := px_to_world(n.position)
		mi.position = p + Vector3(0, (mi.mesh as BoxMesh).size.y / 2 if mi.mesh is BoxMesh else 0.0, 0)
		if is_vehicle:
			mi.rotation.y = 0.0 if n.facing >= 2 else PI / 2
	for id in proxies.keys():
		if not seen.has(id):
			proxies[id].queue_free()
			proxies.erase(id)


func _make_proxy(n: Node2D, path: String, is_vehicle: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.6
	if is_vehicle:
		box.size = VEHICLE_SIZES.get(n.kind, Vector3(3.6, 1.4, 1.7))
		mat.albedo_color = n.color if n.kind != 4 else Color("#d8433a")
		mat.metallic = 0.4
	else:
		var spec: Array = ENTITY_PROXIES[path]
		box.size = spec[0]
		mat.albedo_color = spec[1]
		if spec[1].a < 1.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.mesh = box
	mi.material_override = mat
	return mi
