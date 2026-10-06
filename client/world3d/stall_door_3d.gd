## A toilet stall door (mirrors game/stall_door_view.gd): a panel hinged at
## one end of the opening that swings into the stall while someone stands in
## the doorway; a little red / green "occupied / free" window on both faces.
extends Node3D

const MeshBatch = preload("res://world3d/mesh_batch.gd")
const Materials = preload("res://world3d/materials.gd")

const Y0 := 0.15
const Y1 := 2.0        # like the partitions (props._partition)
const T := 0.035
const W := 0.92
const OPEN_ANGLE := deg_to_rad(82.0)

var view: Node2D
var _hinge := Node3D.new()
var _sign_mat := StandardMaterial3D.new()
var _angle := 0.0
var _swing := 1.0      # which way it opens (into the stall)
var _locked := -1


func setup(p_view: Node2D, wv: Node3D) -> void:
	view = p_view
	# local: the door runs along z (hinge at -z), faces +-x; `across` doors
	# are turned a quarter (they stand in a wall running left-right)
	rotation.y = -PI / 2 if view.across else 0.0
	_hinge.position = Vector3(0, 0, -0.5 + 0.03)
	add_child(_hinge)
	var b := MeshBatch.new()
	b.box(Vector3(-T / 2, Y0, 0.02), Vector3(T / 2, Y1, 0.02 + W), "matte", Color("#c4c9cb"), 63)
	b.box(Vector3(-T / 2 - 0.003, Y0 + 0.04, 0.05), Vector3(T / 2 + 0.003, Y0 + 0.25, W - 0.01), "matte", Color("#8f959b"), 1 | 2)
	b.box(Vector3(-T / 2 - 0.012, 1.0, 0.85), Vector3(T / 2 + 0.012, 1.04, 0.9), "metal", Color("#9aa3ab"), 63)  # handle
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(Materials.get_all())
	_hinge.add_child(mi)
	for sx in [-1.0, 1.0]:
		var s := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.035
		cm.height = 0.01
		s.mesh = cm
		s.rotation.z = PI / 2
		s.position = Vector3(sx * (T / 2 + 0.004), 1.25, 0.78)
		s.material_override = _sign_mat
		_hinge.add_child(s)
	_sign_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_swing = _stall_side(wv)


## +1 if the stall (room type "stall") is on the local +x side.
func _stall_side(wv: Node3D) -> float:
	var g = wv.game
	var m = null
	if "stall_doors" in g:
		for f in g.stall_doors:
			if view in g.stall_doors[f]:
				m = wv.building.get_floor(f)
	if m == null:
		m = wv.building.get_floor(maxi(wv.floor_shown, 0))
	if m == null:
		return 1.0
	var t: Vector2i = view.tile
	# local +x is map +x, or map +y (down) for `across` doors
	var plus := t + (Vector2i(0, 1) if view.across else Vector2i(1, 0))
	var minus := t - (Vector2i(0, 1) if view.across else Vector2i(1, 0))
	if m.room_types.get(m.room_at_tile(plus.x, plus.y), "") == "stall":
		return 1.0
	if m.room_types.get(m.room_at_tile(minus.x, minus.y), "") == "stall":
		return -1.0
	return 1.0


func sync(pos: Vector3, delta: float) -> void:
	position = pos
	var goal := OPEN_ANGLE * _swing if view.open else 0.0
	_angle = move_toward(_angle, goal, delta * 5.0)
	_hinge.rotation.y = _angle
	var lk := 1 if view.locked else 0
	if lk != _locked:
		_locked = lk
		_sign_mat.albedo_color = (Color("#e0463a") if view.locked else Color("#6fd04a")) * 1.4
