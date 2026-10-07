## Textured variants of the shared prop materials (art/prop.gdshader) plus a
## few extra keys. map_builder merges these over Materials.get_all() for its
## batches, so "wood", "fabric", ... in props.gd get grain / weave / brushing.
## Extra keys: ceramic (toilets, sinks, mugs), plastic (glossy), chrome,
## rubber (tyres, chair bases), plaster (concrete, facades without cutaway),
## lit (warm window glow, evening facades).
extends RefCounted

const SHADER := preload("res://world3d/art/prop.gdshader")

static var _cache := {}


static func get_all() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	_cache = {
		"matte": _mat(0, 0.82, 0.0, 0.5),
		"wood": _mat(1, 0.5, 0.0, 0.7),
		"fabric": _mat(2, 0.95, 0.0, 0.2),
		"metal": _mat(3, 0.42, 0.35, 0.3),
		"leaf": _mat(4, 0.75, 0.0, 0.8),
		"ceramic": _mat(5, 0.12, 0.0, 0.2),
		"plastic": _mat(0, 0.38, 0.0, 0.2),
		"chrome": _mat(3, 0.18, 0.75, 0.1),
		"rubber": _mat(7, 0.9, 0.0, 0.4),
		"plaster": _mat(6, 0.92, 0.0, 0.6),
	}
	return _cache


## Materials.get_all() with these merged over it.
static func merged(base: Dictionary) -> Dictionary:
	var out := base.duplicate()
	out.merge(get_all(), true)
	return out


static func _mat(kind: int, rough: float, metal: float, bump: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("metal", metal)
	m.set_shader_parameter("bump", bump)
	return m
