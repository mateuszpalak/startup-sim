## The live 3D backdrop of the menus (title, login, character creation):
## the real building and street from world3d (WorldView with a stand-in
## game, as tests/render_3d.gd), a slow cinematic orbit of the camera, a
## random time of day and weather. main.gd creates it while no game runs
## and frees it when the game starts (not in headless runs).
extends Node

const WorldView = preload("res://world3d/world_view.gd")
const PlayerView = preload("res://game/player_view.gd")
const Coords = preload("res://world3d/coords.gd")

## Moods: [minute of the day, weather (Protocol.WEATHER_*)].
const MOODS := [[8 * 60 + 30, 1], [11 * 60, 2], [17 * 60 + 40, 1], [19 * 60 + 50, 1], [14 * 60, 3]]
## Shots: [floor, focus tile, distance, pitch deg].
const SHOTS := [[0, Vector2(36, 52), 34.0, 30.0], [3, Vector2(30, 34), 30.0, 38.0], [4, Vector2(30, 30), 30.0, 38.0]]
const ORBIT_SPEED := 0.035   # rad/s


## Stand-in for game.gd: just what WorldView reads.
class FakeGame extends Node:
	var me := PlayerView.new()
	var remotes := {}
	var world := Node2D.new()
	var puddle_layer := Node2D.new()
	var camera := Camera2D.new()
	var game_minute := 600
	var weather := 1
	var light_view = preload("res://game/light_view.gd").new()
	var smoke_view = preload("res://game/smoke_view.gd").new()

	static func daylight_color(minute: int) -> Color:
		return preload("res://game/game.gd").daylight_color(minute)


var building
var mood := -1   # index into MOODS (-1: random)
var shot := -1   # index into SHOTS (-1: random)
var _game := FakeGame.new()
var _wv := WorldView.new()
var _yaw := 0.0
var _shot: Array
var _centre := Vector3.ZERO
var _t := 0.0


func _init(p_building) -> void:
	building = p_building


func _ready() -> void:
	process_priority = 100  # after the world view's own camera follow
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var m: Array = MOODS[mood if mood >= 0 else rng.randi() % MOODS.size()]
	_shot = SHOTS[shot if shot >= 0 else rng.randi() % SHOTS.size()]
	_yaw = rng.randf() * TAU
	_game.game_minute = m[0]
	_game.weather = m[1]
	_game.light_view.setup(building)
	_game.smoke_view.setup(building)
	add_child(_game)
	add_child(_wv)
	_wv.setup(_game, building)
	_game.me.set_seed(7)
	_game.me.visible = false
	var f: int = _shot[0]
	_game.light_view.set_floor(f)
	_game.light_view.minute = _game.game_minute
	_game.light_view.weather = _game.weather
	_game.light_view.on_lights({"floor": f, "rooms": building.get_floor(f).room_names.keys() if _game.game_minute > 17 * 60 else []})
	_game.smoke_view.set_floor(f)
	_wv.show_floor(f)
	# The focus of the orbit (and of the walls' cut-away).
	var focus: Vector2 = _shot[1]
	_game.me.position = (focus + Vector2(0.5, 0.5)) * 16.0
	_centre = Coords.px_to_world(_game.me.position, f)
	_wv.weather.snap()


func _process(delta: float) -> void:
	_t += delta
	_yaw += delta * ORBIT_SPEED
	var dist: float = _shot[2] + sin(_t * 0.07) * 3.0
	var pitch := deg_to_rad(_shot[3] + sin(_t * 0.05) * 3.0)
	var cam: Camera3D = _wv.rig.camera
	var back := Basis(Vector3.UP, _yaw) * Vector3(0, sin(pitch), cos(pitch)) * dist
	var look := _centre + Vector3(0, 1.5, 0)
	cam.global_position = look + back
	cam.look_at(look, Vector3.UP)
