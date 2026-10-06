## A laptop on a desk (mirrors game/computer_view.gd): open lid facing the
## chair (south), the screen glows - bright while in use, blue at the login
## screen, dark with a padlock when locked.
extends Node3D

const MeshBatch = preload("res://world3d/mesh_batch.gd")
const Materials = preload("res://world3d/materials.gd")
const Protocol = preload("res://net/protocol.gd")

const DESK_TOP := 0.76
const LID_TILT := 0.32   # radians back from vertical
const W := 0.34
const D := 0.23

var view: Node2D
var _flags := -1
var _screen := MeshInstance3D.new()
var _screen_mat := StandardMaterial3D.new()
var _content := MeshInstance3D.new()
var _glow := OmniLight3D.new()


func setup(p_view: Node2D, _wv: Node3D) -> void:
	view = p_view
	var b := MeshBatch.new()
	# base + keyboard + touchpad
	b.block(0, 0, W, D, 0, 0.018, "metal", Color("#8a939c"), Color("#b4bcc3"))
	b.block(0, -0.02, W - 0.04, D * 0.45, 0.018, 0.002, "matte", Color("#2e3138"))
	b.block(0, 0.075, 0.09, 0.05, 0.018, 0.001, "matte", Color("#a3abb3"))
	var base := MeshInstance3D.new()
	base.mesh = b.commit(Materials.get_all())
	add_child(base)
	# lid: hinged on the back edge, tilted away from the user
	var lid := Node3D.new()
	lid.position = Vector3(0, 0.018, -D / 2)
	lid.rotation.x = -LID_TILT
	add_child(lid)
	var lb := MeshBatch.new()
	lb.box(Vector3(-W / 2, 0, -0.012), Vector3(W / 2, D, 0), "metal", Color("#23262e"), 63)
	var lm := MeshInstance3D.new()
	lm.mesh = lb.commit(Materials.get_all())
	lid.add_child(lm)
	var q := QuadMesh.new()
	q.size = Vector2(W - 0.03, D - 0.03)
	_screen.mesh = q
	_screen.position = Vector3(0, D / 2, 0.001)
	_screen_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_screen.material_override = _screen_mat
	lid.add_child(_screen)
	# what's on it: chat lines / a padlock (small quads just in front)
	_content.position = Vector3(0, D / 2, 0.002)
	lid.add_child(_content)
	_glow.position = Vector3(0, 0.2, 0.15)
	_glow.omni_range = 1.2
	_glow.light_energy = 0.35
	_glow.shadow_enabled = false
	add_child(_glow)


func sync(pos: Vector3, _delta: float) -> void:
	position = pos + Vector3(0, DESK_TOP, 0.04)
	if view.flags == _flags:
		return
	_flags = view.flags
	var locked := (_flags & Protocol.PC_FLAG_LOCKED) != 0
	var in_use := (_flags & Protocol.PC_FLAG_IN_USE) != 0
	var col := Color("#1b2436") if locked else (Color("#e9f1fb") if in_use else Color("#5fb2e8"))
	_screen_mat.albedo_color = col * (1.0 if locked else 1.6)
	_glow.light_color = col
	_glow.visible = not locked
	var b := MeshBatch.new()
	if locked:
		b.box(Vector3(-0.02, -0.03, 0), Vector3(0.02, 0.0, 0.002), "matte", Color("#e0a82e"), 16)
		b.box(Vector3(-0.012, 0.0, 0), Vector3(0.012, 0.025, 0.001), "metal", Color("#9aa4ab"), 16)
	elif in_use:
		for i in 4:
			var w: float = [0.14, 0.2, 0.1, 0.17][i]
			var c: Color = Color("#2e6bd9") if i % 2 == 0 else Color("#8a93a3")
			var x0: float = -0.13 if i % 2 == 0 else 0.13 - w
			b.box(Vector3(x0, 0.06 - i * 0.035, 0), Vector3(x0 + w, 0.075 - i * 0.035, 0.001), "screen", c, 16)
	else:
		b.box(Vector3(-0.06, -0.01, 0), Vector3(0.06, 0.012, 0.001), "matte", Color("#e9f1fb"), 16)
	_content.mesh = b.commit(Materials.get_all())
