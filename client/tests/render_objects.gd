## Dev tool: render the 3D entity views (items, vehicles, laptops, TV, tray,
## elevator / stall doors, the elevator ride) to PNG without a server:
##   godot --path client -s tests/render_objects.gd -- /output/dir [shot ...]
## Shots: items vehicles night laptops tv tray elevator stalls ride.
extends SceneTree

const Building = preload("res://map/building.gd")
const WorldView = preload("res://world3d/world_view.gd")
const PlayerView = preload("res://game/player_view.gd")
const ItemView = preload("res://game/item_view.gd")
const VehicleView = preload("res://game/vehicle_view.gd")
const ComputerView = preload("res://game/computer_view.gd")
const TvView = preload("res://game/tv_view.gd")
const TrayView = preload("res://game/tray_view.gd")
const ElevatorDoorView = preload("res://game/elevator_door_view.gd")
const StallDoorView = preload("res://game/stall_door_view.gd")
const RideMask = preload("res://game/ride_mask.gd")
const ItemArt = preload("res://game/item_art.gd")
const Protocol = preload("res://net/protocol.gd")

const ALL := ["items", "vehicles", "night", "laptops", "tv", "tray", "elevator", "stalls", "ride"]


class FakeGame extends Node:
	var me := PlayerView.new()
	var remotes := {}
	var world := Node2D.new()
	var puddle_layer := Node2D.new()
	var camera := Camera2D.new()
	var game_minute := 600
	var weather := 0
	var light_view = preload("res://game/light_view.gd").new()
	var tvs := {}
	var elevator_doors := {}
	var stall_doors := {}
	var ride_mask = preload("res://game/ride_mask.gd").new()

	static func daylight_color(minute: int) -> Color:
		return preload("res://game/game.gd").daylight_color(minute)


var b
var game: FakeGame
var wv


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else OS.get_user_data_dir()
	var shots: Array = args.slice(1) if args.size() > 1 else ALL
	DisplayServer.window_set_size(Vector2i(1600, 900))
	b = Building.new()
	b.load_path("res://maps/building.json")
	game = FakeGame.new()
	game.light_view.setup(b)
	game.world.add_child(game.ride_mask)
	get_root().add_child(game)
	wv = WorldView.new()
	get_root().add_child(wv)
	wv.setup(game, b)
	game.me.set_seed(7)
	game.me.highlight = true
	for shot in shots:
		for c in game.world.get_children():
			if c != game.ride_mask:
				game.world.remove_child(c)
				c.queue_free()
		game.tvs.clear()
		game.elevator_doors.clear()
		game.stall_doors.clear()
		game.ride_mask.visible = false
		game.me.visible = true
		var spec: Array = call("_shot_" + shot)
		var f: int = spec[0]
		game.game_minute = spec[3] if spec.size() > 3 else 600
		game.light_view.set_floor(f)
		game.light_view.minute = game.game_minute
		wv.show_floor(f)
		wv.set_zoom(spec[2])
		var yaw := deg_to_rad(spec[4]) if spec.size() > 4 else 0.0
		wv.rig._yaw_goal = yaw
		wv.rig.yaw = yaw
		wv.rig._placed = false
		wv.rig._dist = wv.rig.BASE_DIST / spec[2]
		game.me.position = spec[1]
		for i in 50:
			await process_frame
		if shot == "elevator" or shot == "stalls":
			# open the first door after the closed state settled
			for c in game.world.get_children():
				if c is ElevatorDoorView and c.display:
					c.set_state(false, 3, 255)
				if c is StallDoorView and c.tile == _first(f, "stall_door"):
					c.set_state(false, true)
			for i in 40:
				await process_frame
		var img := get_root().get_texture().get_image()
		var path := out.path_join("%s.png" % shot)
		img.save_png(path)
		print("%s -> %s" % [shot, path])
	quit()


## Tiles of a type on floor f.
func _tiles(f: int, type: String) -> Array:
	var m = b.get_floor(f)
	var out := []
	for y in m.height:
		for x in m.width:
			if m.legend.get(m.tile_chars[y * m.width + x], {}).get("type") == type:
				out.append(Vector2i(x, y))
	return out


func _first(f: int, type: String) -> Vector2i:
	var t := _tiles(f, type)
	return t[0] if not t.is_empty() else Vector2i(10, 10)


func _px(t: Vector2i) -> Vector2:
	return (Vector2(t) + Vector2(0.5, 0.5)) * 16.0


func _shot_items() -> Array:
	var m = b.get_floor(3)
	var c := Vector2i(30, 30)
	var kinds := []
	for k in ItemArt.NAMES:
		kinds.append(k)
	var i := 0
	for y in range(-4, 5):
		for x in range(-7, 8):
			if i >= kinds.size():
				break
			var t := c + Vector2i(x, y)
			if m.is_blocked(t.x, t.y) or (x == 0 and y == 0):
				continue
			var iv := ItemView.new()
			iv.setup(kinds[i])
			iv.position = _px(t)
			game.world.add_child(iv)
			i += 1
	return [3, _px(c), 1.7]


func _street_row() -> int:
	var rows := {}
	for t in _tiles(0, "street"):
		rows[t.y] = rows.get(t.y, 0) + 1
	var best := 0
	for y in rows:
		if rows[y] > rows.get(best, 0):
			best = y
	return best


func _shot_vehicles() -> Array:
	var y := _street_row()
	var tr := _tiles(0, "tram_track")
	var ty: int = tr[0].y if not tr.is_empty() else y - 3
	var specs := [[VehicleView.CAR, 20, y, 3], [VehicleView.TAXI, 26, y, 3], [VehicleView.POLICE, 32, y, 2],
		[VehicleView.FIRE_ENGINE, 40, y, 2], [VehicleView.TRAM, 30, ty, 2], [VehicleView.BIKE, 36, y - 2, 3]]
	var id := 0
	for s in specs:
		var v := VehicleView.new()
		v.setup(s[0], id)
		v.push(_px(Vector2i(s[1], s[2])), s[3])
		game.world.add_child(v)
		id += 1
	game.me.visible = false
	return [0, _px(Vector2i(31, y - 1)), 0.75]


func _shot_night() -> Array:
	var r := _shot_vehicles()
	r.append(1290)
	return r


func _shot_laptops() -> Array:
	var desks := _tiles(3, "desk")
	var flags := [0, Protocol.PC_FLAG_IN_USE, Protocol.PC_FLAG_LOCKED, 0, Protocol.PC_FLAG_IN_USE]
	var t0: Vector2i = desks[desks.size() / 2]
	var n := 0
	for t in desks:
		if (t - t0).length() < 3.5 and n < 6:
			var cv := ComputerView.new()
			cv.set_flags(flags[n % flags.size()])
			cv.position = _px(t)
			game.world.add_child(cv)
			n += 1
	return [3, _px(t0 + Vector2i(0, 1)), 2.4, 1100]


func _shot_tv() -> Array:
	var t := _first(4, "tv")
	var tv := TvView.new()
	tv.position = Vector2(t) * 16.0
	tv.weather = "deszcz"
	game.world.add_child(tv)
	game.tvs["4:%d:%d" % [t.x, t.y]] = [tv, 4]
	tv.show_channel(1, 12.0)
	return [4, _px(t + Vector2i(1, -2)), 1.6, 600, 180.0]


func _shot_tray() -> Array:
	var t := _first(4, "table")
	for f in [4, 3]:
		for c in _tiles(f, "table"):
			var m = b.get_floor(f)
			if m.room_types.get(m.room_at_tile(c.x, c.y), "") == "chill":
				var tv := TrayView.new()
				tv.set_state(ItemArt.DONUT, 6)
				tv.position = _px(c)
				game.world.add_child(tv)
				return [f, _px(c + Vector2i(0, 2)), 2.4]
	var tv := TrayView.new()
	tv.set_state(ItemArt.DONUT, 6)
	tv.position = _px(t)
	game.world.add_child(tv)
	return [4, _px(t + Vector2i(0, 2)), 2.4]


func _doors(f: int) -> void:
	var m = b.get_floor(f)
	game.elevator_doors[f] = []
	game.stall_doors[f] = []
	for t in _tiles(f, "elevator_door"):
		var ev := ElevatorDoorView.new()
		ev.tile = t
		ev.position = _px(t)
		var is_door := func(dx: int) -> bool: return m.legend.get(m.tile_chars[t.y * m.width + t.x + dx], {}).get("type") == "elevator_door"
		ev.display = is_door.call(-1) and is_door.call(1)
		ev.set_state(true, 2, 3)
		game.world.add_child(ev)
		game.elevator_doors[f].append(ev)
	for t in _tiles(f, "stall_door"):
		var dv := StallDoorView.new()
		dv.tile = t
		dv.across = m.is_blocked(t.x - 1, t.y) and m.is_blocked(t.x + 1, t.y)
		dv.position = _px(t)
		dv.set_state(t.x % 2 == 0, false)
		game.world.add_child(dv)
		game.stall_doors[f].append(dv)


func _shot_elevator() -> Array:
	_doors(3)
	var t := _first(3, "elevator_door")
	return [3, _px(t + Vector2i(1, 2)), 1.8]


func _shot_stalls() -> Array:
	for f in [4, 3, 0]:
		if not _tiles(f, "stall_door").is_empty():
			_doors(f)
			var t := _first(f, "stall_door")
			return [f, _px(t + Vector2i(0, 1)), 2.0]
	return [3, Vector2(480, 480), 1.0]


func _shot_ride() -> Array:
	_doors(3)
	var m = b.get_floor(3)
	for l in m.links:
		if l.kind == "elevator":
			var r: Rect2i = l.rect
			game.ride_mask.show_cabin(Rect2(Vector2(r.position) * 16.0, Vector2(r.size) * 16.0).grow(2))
			for dv in game.elevator_doors[3]:
				dv.visible = false
			return [3, _px(r.position + r.size / 2), 1.8]
	return [3, Vector2(480, 480), 1.0]
