## Riding the elevator (mirrors game/ride_mask.gd): the floor is hidden and
## only the car is drawn - a steel box (low front wall towards the camera,
## so you can see in), a lit ceiling panel, a handrail and a button panel.
## world_view shows it over the cabin rect while the mask is up.
extends Node3D

const MeshBatch = preload("res://world3d/mesh_batch.gd")
const Materials = preload("res://world3d/materials.gd")

const H := 2.4
const T := 0.08
const STEEL := Color("#8a939c")
const STEEL_LIGHT := Color("#aeb6ba")

var rect := Rect2()     # metres (x, z)
var _mesh := MeshInstance3D.new()
var _light := OmniLight3D.new()


func _init() -> void:
	add_child(_mesh)
	_light.light_color = Color("#fff1dc")
	_light.light_energy = 1.4
	_light.shadow_enabled = false
	add_child(_light)
	visible = false


## Build for the cabin `r` (metres on the map plane), floor at height y.
func show_cabin(r: Rect2, y: float) -> void:
	if r != rect:
		rect = r
		_build()
	position = Vector3(r.position.x, y, r.position.y)
	visible = true


func _build() -> void:
	var w := rect.size.x
	var d := rect.size.y
	var b := MeshBatch.new()
	b.box(Vector3(0, -0.05, 0), Vector3(w, 0.0, d), "matte", Color("#3a3d44"))   # floor
	b.quad_up(0.1, 0.1, w - 0.1, d - 0.1, 0.002, "matte", Color("#4b4f57"))
	b.box(Vector3(-T, -0.05, -T), Vector3(w + T, H, 0), "metal", STEEL, 63)      # back
	b.box(Vector3(-T, -0.05, 0), Vector3(0, H, d), "metal", STEEL_LIGHT, 63)     # left
	b.box(Vector3(w, -0.05, 0), Vector3(w + T, H, d), "metal", STEEL_LIGHT, 63)  # right
	b.box(Vector3(-T, -0.05, d), Vector3(w + T, 0.35, d + T), "metal", STEEL, 63)  # low front
	# brushed panels and a handrail on the back wall
	for i in int(w / 0.5):
		var x := 0.25 + i * 0.5
		b.box(Vector3(x - 0.005, 0.1, 0.0), Vector3(x + 0.005, H - 0.1, 0.004), "metal", STEEL_LIGHT, 16)
	b.box(Vector3(0.15, 0.92, 0.0), Vector3(w - 0.15, 0.96, 0.06), "metal", Color("#c9ced3"), 63)
	# button panel on the right wall
	b.box(Vector3(w - 0.02, 0.95, d * 0.3), Vector3(w, 1.5, d * 0.3 + 0.25), "matte", Color("#22242a"), 2)
	for i in 5:
		b.box(Vector3(w - 0.025, 1.0 + i * 0.09, d * 0.3 + 0.1), Vector3(w - 0.02, 1.05 + i * 0.09, d * 0.3 + 0.15), "screen", Color("#ffb347"), 2)
	# ceiling light strip on top of the back wall, shining in
	b.box(Vector3(0.2, H - 0.12, 0.0), Vector3(w - 0.2, H - 0.04, 0.05), "screen", Color("#fff4d8"), 16 | 8)
	_mesh.mesh = b.commit(Materials.get_all())
	_light.position = Vector3(w / 2, H - 0.3, d / 2)
	_light.omni_range = maxf(w, d) * 1.6 + 1.0
