## The 3D presentation of the game world. game.gd keeps all the logic
## (network, prediction, interpolation, hints, UI) and its 2D views as
## invisible state holders; this node mirrors them in 3D every frame:
##   - environment, sun and sky by the time of day / weather,
##   - one built mesh per floor (map_builder.gd), the current one shown,
##     the street level under the upper floors,
##   - an Avatar3D per PlayerView (me + remotes), nick / bubble tags placed
##     on screen over their heads (the 2D tags, re-used),
##   - a 3D view per entity / door 2D view (ENTITY_VIEWS: items, vehicles,
##     laptops, TVs, trays, elevator and stall doors),
##   - the elevator car alone while riding (RideCabin3D, from game.ride_mask),
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
var views3d := {}       # 2D node (instance id) -> 3D view (ENTITY_VIEWS)
var ride_cabin := RideCabin3D.new()
var _riding := false


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
		var head: Vector3 = a.head_top()
		if cam.is_position_behind(head) or not a.visible:
			tag.visible = false
			continue
		tag.visible = true
		tag.position = cam.unproject_position(head) - Vector2(0, PlayerView.HEAD_TOP)


# ------------------------------------------------------------- other things

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
	lighting.set_ride(riding)
