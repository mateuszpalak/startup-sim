## Dev tool: render views of the 3D world to PNG without a server (needs a
## renderer - run without --headless):
##   godot --path client -s tests/render_3d.gd -- /output/dir [shot ...]
## A shot is "name:floor:tile_x,tile_y[:zoom[:yaw_deg[:minute[:weather[:extras]]]]]"
## (weather: Protocol.WEATHER_*; extras: "+"-joined smoke, puddles, blood,
## flash, lamps); without shots a default set is rendered. Prints the frame
## time of every shot (run with --disable-vsync --max-fps 0 to measure). A few stand-in people are placed around
## the focus point.
extends SceneTree

const Building = preload("res://map/building.gd")
const WorldView = preload("res://world3d/world_view.gd")
const Avatar3D = preload("res://world3d/avatar_3d.gd")
const PlayerView = preload("res://game/player_view.gd")
const Coords = preload("res://world3d/coords.gd")

const DEFAULT_SHOTS := [
	"street:0:34,62:0.8:0:600",
	"lobby:0:30,48:1.3:0:600",
	"office3:3:30,30:1.0:0:600",
	"office4:4:30,52:1.0:0:600",
	"kitchen4:4:22,10:1.4:0:600",
	"overview4:4:34,36:0.45:0:600",
	"evening3:3:30,26:1.0:30:1230",
	"stairwell:5:34,12:1.2:0:600",
]


## Stand-in for game.gd: just what WorldView reads.
class FakeGame extends Node:
	var me := PlayerView.new()
	var remotes := {}
	var world := Node2D.new()
	var puddle_layer := Node2D.new()
	var camera := Camera2D.new()
	var game_minute := 600
	var weather := 0
	var light_view = preload("res://game/light_view.gd").new()
	var smoke_view = preload("res://game/smoke_view.gd").new()

	static func daylight_color(minute: int) -> Color:
		return preload("res://game/game.gd").daylight_color(minute)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else OS.get_user_data_dir()
	var shots: Array = args.slice(1) if args.size() > 1 else DEFAULT_SHOTS
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var b = Building.new()
	b.load_path("res://maps/building.json")
	var game := FakeGame.new()
	game.light_view.setup(b)
	game.smoke_view.setup(b)
	get_root().add_child(game)
	var wv := WorldView.new()
	get_root().add_child(wv)
	wv.setup(game, b)
	game.me.set_seed(7)
	game.me.highlight = true
	for i in 5:
		var r := PlayerView.new()
		r.set_seed(100 + i * 37)
		r.facing = [0, 1, 2, 3, 0][i]
		game.remotes[i] = r
	for shot in shots:
		var p: PackedStringArray = shot.split(":")
		var f := int(p[1])
		var t := Vector2i(int(p[2].get_slice(",", 0)), int(p[2].get_slice(",", 1)))
		var zoom := float(p[3]) if p.size() > 3 else 1.0
		var yaw := deg_to_rad(float(p[4])) if p.size() > 4 else 0.0
		game.game_minute = int(p[5]) if p.size() > 5 else 600
		game.weather = int(p[6]) if p.size() > 6 else 1
		var extras: PackedStringArray = p[7].split("+") if p.size() > 7 else PackedStringArray()
		game.light_view.set_floor(f)
		game.light_view.minute = game.game_minute
		game.light_view.weather = game.weather
		game.smoke_view.set_floor(f)
		for c in game.puddle_layer.get_children():
			c.free()
		wv.show_floor(f)
		wv.set_zoom(zoom)
		wv.rig._yaw_goal = yaw
		wv.rig.yaw = yaw
		wv.rig._placed = false
		wv.rig._dist = wv.rig.BASE_DIST / zoom
		game.me.position = (Vector2(t) + Vector2(0.5, 0.5)) * 16.0
		var m = b.get_floor(f)
		var k := 0
		for r in game.remotes.values():
			# people on free tiles near the focus
			for tries in 40:
				var c := t + Vector2i((k * 7 + tries * 3) % 9 - 4, (k * 5 + tries * 7) % 7 - 3)
				if not m.is_blocked(c.x, c.y) and not m.is_blocked(c.x + 1, c.y):
					r.position = (Vector2(c) + Vector2(0.5, 0.5)) * 16.0
					break
			k += 1
		wv.weather.snap()
		var here: int = m.room_at_tile(t.x, t.y)
		if extras.has("lamps"):
			var on := []
			for rid in m.room_names:
				on.append(rid)
			game.light_view.on_lights({"floor": f, "rooms": on})
		else:
			game.light_view.on_lights({"floor": f, "rooms": []})
		if extras.has("smoke"):
			game.smoke_view._shown = {here: 0.7}
			game.smoke_view._target = {here: 0.7}
		else:
			game.smoke_view._shown = {}
			game.smoke_view._target = {}
		if extras.has("puddles"):
			for i in 5:
				var pv = preload("res://game/puddle_view.gd").new()
				pv.setup(i + 1, [0, 1, 3, 2, 0][i])
				pv.position = (Vector2(t) + Vector2(-3 + i * 1.6, 2.5)) * 16.0
				game.puddle_layer.add_child(pv)
		for i in 40:
			if i == 30 and extras.has("blood"):
				wv.blood.burst(wv.px_to_world(game.me.position + Vector2(20, 0)) + Vector3(0, 1.2, 0))
			if i == 37 and extras.has("flash"):
				wv.weather.strike()
			await process_frame
		# frame time (meaningful with --disable-vsync --max-fps 0)
		var t0 := Time.get_ticks_usec()
		for i in 60:
			await process_frame
		var ms := (Time.get_ticks_usec() - t0) / 60000.0
		if extras.has("flash"):
			wv.weather.strike()
			for i in 3:
				await process_frame
		var img := get_root().get_texture().get_image()
		var path := out.path_join("%s.png" % p[0])
		img.save_png(path)
		print("%s -> %s  (%.2f ms / frame)" % [shot, path, ms])
	quit()
