## Shared materials of the 3D world. Every batch is vertex-coloured, so a
## handful of materials covers the whole building (few draw calls).
## Keys used by MeshBatch / props.gd:
##   ground  - floors and the street (procedural pattern from UV2.x, see GROUND_*)
##   wall    - walls (cutaway around the player, see wall.gdshader)
##   matte   - painted / plastic things, plaster
##   wood    - wooden furniture (a bit of sheen)
##   fabric  - sofas, chairs, carpets on furniture
##   metal   - steel, chrome
##   glass   - windows, glass doors (transparent)
##   screen  - glowing screens / signs (emissive)
##   leaf    - plants (soft)
extends RefCounted

## Ground patterns (UV2.x of the ground quads).
const GROUND_PLAIN := 0
const GROUND_PLANKS := 1
const GROUND_TILES := 2
const GROUND_CARPET := 3
const GROUND_GRASS := 4
const GROUND_ASPHALT := 5
const GROUND_PAVING := 6
const GROUND_STONE := 7
const GROUND_METAL := 8

static var _cache := {}


static func get_all() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	_cache = {
		"ground": _shader_mat("res://world3d/shaders/ground.gdshader"),
		"wall": _shader_mat("res://world3d/shaders/wall.gdshader"),
		"matte": _std(0.85, 0.0),
		"wood": _std(0.55, 0.0),
		"fabric": _std(1.0, 0.0),
		"metal": _std(0.32, 0.75),
		"leaf": _std(0.9, 0.0),
		"glass": _glass(),
		"screen": _screen(),
	}
	return _cache


## The cutaway parameters (camera, player) live on the wall material.
static func wall() -> ShaderMaterial:
	return get_all()["wall"]


## Vertex-coloured surface (prop.gdshader: darkened in unlit rooms).
static func _std(rough: float, metal: float) -> ShaderMaterial:
	var m := _shader_mat("res://world3d/shaders/prop.gdshader")
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("metallic", metal)
	return m


## See-through; glows at night when the room's lamp is on (glass.gdshader).
static func _glass() -> ShaderMaterial:
	return _shader_mat("res://world3d/shaders/glass.gdshader")


static func _screen() -> ShaderMaterial:
	return _shader_mat("res://world3d/shaders/screen.gdshader")


static func _shader_mat(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	return m
