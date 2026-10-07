## The tray of sweets on the chill-room table (mirrors game/tray_view.gd):
## a round steel tray with the pieces that are left, in a ring.
extends Node3D

const MeshBatch = preload("res://world3d/mesh_batch.gd")
const Materials = preload("res://world3d/materials.gd")
const ItemModels = preload("res://world3d/item_models.gd")

const TABLE_TOP := 0.77
const R := 0.3
const PIECE_SCALE := 1.6

var view: Node2D
var _state := Vector2i(-1, -1)
var _pieces := Node3D.new()


func setup(p_view: Node2D, _wv: Node3D) -> void:
	view = p_view
	var b := MeshBatch.new()
	b.cylinder(Vector3.ZERO, R - 0.02, R, 0.012, "metal", Color("#c9ced3"), 24)
	b.cylinder(Vector3(0, 0.012, 0), R, R + 0.01, 0.02, "metal", Color("#b8bec4"), 24, false)
	b.cylinder(Vector3(0, 0.013, 0), R - 0.03, R - 0.03, 0.001, "matte", Color("#e6ebef"), 24)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(Materials.get_all())
	add_child(mi)
	add_child(_pieces)


func sync(pos: Vector3, _delta: float) -> void:
	position = pos + Vector3(0, TABLE_TOP, 0)
	var st := Vector2i(view.kind, view.pieces)
	if st == _state:
		return
	_state = st
	for c in _pieces.get_children():
		c.queue_free()
	var n: int = view.pieces
	for i in n:
		var a := TAU * i / maxf(n, 1) - PI / 2
		var mi := MeshInstance3D.new()
		mi.mesh = ItemModels.mesh(view.kind)
		mi.scale = Vector3.ONE * PIECE_SCALE
		var rr := 0.17 if n > 1 else 0.0
		mi.position = Vector3(cos(a) * rr, 0.014, sin(a) * rr)
		mi.rotation.y = -a
		_pieces.add_child(mi)
