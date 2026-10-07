## Elevator doors on one tile (mirrors game/elevator_door_view.gd): two
## brushed-steel leaves that slide apart into the frame when the door is
## open, and - on the middle door - the floor display above it (amber
## digits and an arrow while the car moves, on both sides of the wall).
extends Node3D

const MeshBatch = preload("res://world3d/mesh_batch.gd")
const Materials = preload("res://world3d/materials.gd")
const ElevatorDoorView = preload("res://game/elevator_door_view.gd")

const TOP := 2.2 - 0.07     # under the frame head (map_builder)
const LEAF_T := 0.05
const SPEED := 2.2          # opening per second (0..1)

var view: Node2D
var _leaves: Array[MeshInstance3D] = []
var _open := 0.0
var _labels: Array[Label3D] = []
var _label_text := ""


func setup(p_view: Node2D, wv: Node3D) -> void:
	view = p_view
	var horiz := _horizontal(wv)
	# local frame: the leaves run along x, the wall's faces are +-z
	rotation.y = 0.0 if horiz else PI / 2
	var b := MeshBatch.new()
	b.box(Vector3(0, 0.02, -LEAF_T / 2), Vector3(0.5, TOP, LEAF_T / 2), "matte", Color("#b8c0c3"), 63)
	for k in 3:
		var x := 0.08 + k * 0.12
		for sz in [-1.0, 1.0]:
			b.box(Vector3(x, 0.15, sz * LEAF_T / 2 - 0.002), Vector3(x + 0.01, TOP - 0.15, sz * LEAF_T / 2 + 0.002), "matte", Color("#dfe4e6"), 16 | 32)
	var mesh := b.commit(Materials.get_all())
	for side in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		if side < 0:
			mi.scale.x = -1.0
		add_child(mi)
		_leaves.append(mi)
	if view.display:
		var db := MeshBatch.new()
		for sz in [-1.0, 1.0]:
			var z: float = sz * (WALL_T / 2 + 0.02)
			db.box(Vector3(-0.17, 2.26, z - 0.005), Vector3(0.17, 2.38, z + 0.005), "matte", Color("#15171c"), 63)
		var dm := MeshInstance3D.new()
		dm.mesh = db.commit(Materials.get_all())
		add_child(dm)
		for sz in [-1.0, 1.0]:
			var l := Label3D.new()
			l.font_size = 64
			l.pixel_size = 0.0016
			l.modulate = Color("#ffb347") * 1.8
			l.outline_size = 0
			l.shaded = false
			l.double_sided = false
			l.position = Vector3(0, 2.32, sz * (WALL_T / 2 + 0.03))
			l.rotation.y = 0.0 if sz > 0 else PI
			add_child(l)
			_labels.append(l)
	_open = 0.0 if view.closed else 1.0


const WALL_T := 0.28  # map_builder.WALL_T


## In a wall running left-right (like map_builder's doorways)?
func _horizontal(wv: Node3D) -> bool:
	var m = wv.building.get_floor(maxi(wv.floor_shown, 0))
	var f := _floor_of(wv)
	if f >= 0:
		m = wv.building.get_floor(f)
	if m == null:
		return true
	var x: int = view.tile.x
	var y: int = view.tile.y
	var t := func(xx: int, yy: int) -> String:
		if xx < 0 or yy < 0 or xx >= m.width or yy >= m.height:
			return "void"
		return m.legend.get(m.tile_chars[yy * m.width + xx], {}).get("type", "void")
	var joins := func(xx: int, yy: int) -> bool:
		return t.call(xx, yy) in ["wall", "garage_shutter", "elevator_door"] or m.is_blocked(xx, yy)
	if joins.call(x - 1, y) and joins.call(x + 1, y):
		return true
	if joins.call(x, y - 1) and joins.call(x, y + 1):
		return false
	return true


func _floor_of(wv: Node3D) -> int:
	var g = wv.game
	if "elevator_doors" in g:
		for f in g.elevator_doors:
			if view in g.elevator_doors[f]:
				return f
	return -1


func sync(pos: Vector3, delta: float) -> void:
	position = pos
	_open = move_toward(_open, 0.0 if view.closed else 1.0, delta * SPEED)
	var e := _open * _open * (3.0 - 2.0 * _open)  # smoothstep
	# each leaf telescopes into its side of the frame
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var leaf := _leaves[i]
		leaf.position.x = side * e * 0.44
		leaf.visible = e < 0.98
	if not _labels.is_empty():
		var txt: String = ElevatorDoorView.floor_label(view.lift_floor)
		if view.lift_target != 255 and view.lift_target != view.lift_floor:
			txt = ("▲" if view.lift_target > view.lift_floor else "▼") + txt
		if txt != _label_text:
			_label_text = txt
			for l in _labels:
				l.text = txt
