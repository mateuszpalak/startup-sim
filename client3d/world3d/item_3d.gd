## An item lying on the floor (mirrors game/item_view.gd): its 3D model
## (item_models.gd), a little bigger than life so it reads from the camera,
## turned by where it lies, with a soft glint so it stands out on the floor.
extends Node3D

const ItemModels = preload("res://world3d/item_models.gd")

const SCALE := 2.3

var view: Node2D
var _kind := -1
var _mesh := MeshInstance3D.new()
var _t := 0.0


func setup(p_view: Node2D, _wv: Node3D) -> void:
	view = p_view
	_mesh.scale = Vector3.ONE * SCALE
	add_child(_mesh)


func sync(pos: Vector3, delta: float) -> void:
	if view.kind != _kind:
		_kind = view.kind
		_mesh.mesh = ItemModels.mesh(_kind)
		# a stable random turn per spot
		var h := int(view.position.x * 7.0 + view.position.y * 13.0)
		_mesh.rotation.y = float(h % 360) * PI / 180.0
	if position.distance_squared_to(pos) > 0.0001:
		position = pos
	_t += delta
	# a slow breathing bob, like something you can pick up
	_mesh.position.y = 0.012 + 0.012 * (0.5 + 0.5 * sin(_t * 2.4 + position.x))
