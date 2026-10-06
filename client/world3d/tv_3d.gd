## The picture of a TV (mirrors game/tv_view.gd): the 2D channel drawing is
## re-used - a copy of the TvView renders into a SubViewport, shown on the
## screen of the TV set (props.gd "tv") as a glowing ViewportTexture. The
## set itself is static furniture; this finds it from the map (the run of
## "tv" tiles starting at the view's tile) and puts the picture on it.
extends Node3D

const TvView = preload("res://game/tv_view.gd")
const Coords = preload("res://world3d/coords.gd")

const PX_SCALE := 6          # viewport pixels per 2D pixel
const PIC_W := 48.0          # the 2D set incl. its frame (TvView.W + 4)
const PIC_H := 30.0
const SCREEN_Y0 := 0.8       # the set's screen in props._tv
const SCREEN_Y1 := 1.55
const WALL_T := 0.28         # map_builder.WALL_T

var view: Node2D
var _port := SubViewport.new()
var _mirror: Node2D = TvView.new()
var _quad := MeshInstance3D.new()
var _mat := StandardMaterial3D.new()
var _glow := OmniLight3D.new()
var _wv: Node3D
var _placed := false


func setup(p_view: Node2D, wv: Node3D) -> void:
	view = p_view
	_wv = wv
	_port.size = Vector2i(int(PIC_W) * PX_SCALE, int(PIC_H) * PX_SCALE)
	_port.transparent_bg = false
	_port.disable_3d = true
	_port.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_port)
	# the drawing's rect starts at (2 - 2, -H + 6 - 2) = (0, -22)
	_mirror.scale = Vector2.ONE * PX_SCALE
	_mirror.position = Vector2(0, 22) * PX_SCALE
	_port.add_child(_mirror)
	var h := SCREEN_Y1 - SCREEN_Y0 - 0.04
	var q := QuadMesh.new()
	q.size = Vector2(h * PIC_W / PIC_H * 1.3, h)  # a bit wider: the set is a widescreen
	_quad.mesh = q
	_mat.albedo_texture = _port.get_texture()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_quad.material_override = _mat
	_quad.position = Vector3(0, (SCREEN_Y0 + SCREEN_Y1) / 2, 0)
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_quad)
	_glow.position = Vector3(0, 1.2, 0.6)
	_glow.omni_range = 3.5
	_glow.light_energy = 0.0
	_glow.shadow_enabled = false
	add_child(_glow)


## Where the set stands: [centre of the screen plane, yaw] from the map.
func _place(f: int) -> void:
	var m = _wv.building.get_floor(f)
	if m == null:
		return
	var t := Vector2i(floori(view.position.x / 16.0), floori(view.position.y / 16.0))
	var r := Rect2i(t, Vector2i.ONE)
	while _type(m, r.end.x, t.y) == "tv":
		r.size.x += 1
	while _type(m, t.x, r.end.y) == "tv":
		r.size.y += 1
	# facing: away from the wall behind it (north first), like map_builder
	var face := Vector2i(0, 1)
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if _wall_side(m, r, d):
			face = -d
			break
	var size := Vector2(r.size)
	var c := Vector2(r.position) + size / 2
	var origin := Vector3(c.x, Coords.floor_y(f), c.y)
	if _wall_side(m, r, -face):
		origin -= Vector3(face.x, 0, face.y) * (0.5 - WALL_T / 2)
	var yaw := atan2(float(face.x), float(face.y))
	transform = Transform3D(Basis(Vector3.UP, yaw), origin)
	_quad.position.z = -0.008
	_placed = true


static func _type(m, x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= m.width or y >= m.height:
		return "void"
	return m.legend.get(m.tile_chars[y * m.width + x], {}).get("type", "void")


static func _wall_side(m, r: Rect2i, d: Vector2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var nb := Vector2i(x, y) + d
			if not r.has_point(nb) and _type(m, nb.x, nb.y) not in ["wall", "garage_shutter"]:
				return false
	return true


func sync(_pos: Vector3, delta: float) -> void:
	if not _placed:
		_place(_tv_floor())
	_mirror.weather = view.weather
	if _mirror.channel != view.channel or absf(_mirror._t - view._t) > 0.5:
		_mirror.show_channel(view.channel, view._t)
	var on: bool = view.channel != 0
	_glow.light_energy = move_toward(_glow.light_energy, 0.6 if on else 0.0, delta * 2.0)
	_glow.light_color = Color("#9cc8ff")
	_glow.visible = _glow.light_energy > 0.01
	_mat.albedo_color = Color(1.3, 1.3, 1.3) if on else Color(0.6, 0.6, 0.6)


func _tv_floor() -> int:
	var g = _wv.game
	if "tvs" in g:
		for key in g.tvs:
			if g.tvs[key][0] == view:
				return g.tvs[key][1]
	return maxi(_wv.floor_shown, 0)
