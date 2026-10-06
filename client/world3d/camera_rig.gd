## The follow camera: looks down at ~55 degrees from the south (so "up" on
## the keyboard walks away from the camera, as in 2D), follows the player
## smoothly, zooms with the game's zoom level, turns with the right mouse
## button or , / . (Home: back to north-up) in 45-degree steps. Movement
## keys follow the turn (`screen_to_map`), so the wire input stays in map
## axes and matches what's on screen.
extends Node3D

const PITCH_DEG := 55.0
## Distance at zoom level 1.0 (the game's zoom_level multiplies in).
const BASE_DIST := 17.0
const FOLLOW := 9.0

var camera := Camera3D.new()
var target := Vector3.ZERO
var zoom_level := 1.0
var yaw := 0.0
var _yaw_goal := 0.0
var _dist := BASE_DIST
var _dragging := false
## Screen shake in world pixels (from the 2D camera's offset).
var shake := Vector2.ZERO
var _placed := false


func _ready() -> void:
	camera.fov = 38.0
	camera.near = 0.3
	camera.far = 400.0
	add_child(camera)


func snap_to(p: Vector3) -> void:
	target = p
	position = p
	_placed = true


func follow(p: Vector3, delta: float) -> void:
	target = p
	if not _placed:
		snap_to(p)
	position = position.lerp(target, 1.0 - exp(-FOLLOW * delta))
	if absf(position.y - target.y) > 2.5:
		position.y = target.y  # changed floors: no slow glide through slabs
	yaw = lerp_angle(yaw, _yaw_goal, 1.0 - exp(-10.0 * delta))
	var goal := BASE_DIST / zoom_level
	_dist = lerpf(_dist, goal, 1.0 - exp(-12.0 * delta))
	var pitch := deg_to_rad(PITCH_DEG)
	var back := Basis(Vector3.UP, yaw) * Vector3(0, sin(pitch), cos(pitch)) * _dist
	camera.global_position = position + back + Vector3(0, 0.6, 0)
	camera.look_at(position + Vector3(0, 0.6, 0), Vector3.UP)
	camera.h_offset = shake.x * 0.04
	camera.v_offset = -shake.y * 0.04


## The turn in quarter turns (0..3), for mapping movement keys.
func input_quadrant() -> int:
	return posmod(int(round(_yaw_goal / (PI / 2))), 4)


## Screen direction (x right, y down: as the keys) -> world/map direction,
## in eight directions: at a 45-degree turn "up" walks diagonally (up the
## screen), a diagonal key pair walks along a map axis.
func screen_to_map(d: Vector2i) -> Vector2i:
	if d == Vector2i.ZERO:
		return d
	var steps := posmod(int(round(_yaw_goal / (PI / 4))), 8)
	var v := Vector2(d).normalized().rotated(-steps * PI / 4)
	return Vector2i(_unit(v.x), _unit(v.y))


static func _unit(x: float) -> int:
	return 1 if x > 0.38 else (-1 if x < -0.38 else 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_dragging = event.pressed
		if not event.pressed:
			_yaw_goal = round(_yaw_goal / (PI / 4)) * (PI / 4)  # settle on 45 degrees
	elif event is InputEventMouseMotion and _dragging:
		_yaw_goal -= event.relative.x * 0.008
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_COMMA: _yaw_goal -= PI / 4
			KEY_PERIOD: _yaw_goal += PI / 4
			KEY_HOME: _yaw_goal = 0.0
