## Shows the upper storeys' shell (art/exterior.gd) only while the street
## floor is the one shown and the player is outside the building - from
## inside, or on an upper floor, the diorama stays open.
extends Node

const Materials = preload("res://world3d/materials.gd")

var shell: Node3D
## Vector2i tile -> true: the building's footprint.
var footprint := {}


func _process(_delta: float) -> void:
	if shell == null:
		return
	var floor_node := get_parent().get_parent() as Node3D
	var show := floor_node != null and floor_node.is_visible_in_tree()
	if show and floor_node.get_parent() != null:
		for n in floor_node.get_parent().get_children():
			if n != floor_node and n is Node3D and String(n.name).begins_with("Floor") and n.visible:
				show = false
				break
	if show:
		var f = Materials.wall().get_shader_parameter("focus")
		if f is Vector3:
			var t := Vector2i(floori(f.x), floori(f.z))
			for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if footprint.has(t + d):
					show = false
	if shell.visible != show:
		shell.visible = show
