## A live 3D preview of a character (character creation, the online
## interview): the same Avatar3D as in the world, mirroring a PlayerView that
## holds the look, in its own little world with soft studio light.
extends SubViewportContainer

const Avatar3D = preload("res://world3d/avatar_3d.gd")

var view: Node2D            # the PlayerView with the appearance / facing
var _vp := SubViewport.new()
var _avatar := Avatar3D.new()
var _pivot := Node3D.new()


func setup(p_view: Node2D, px := Vector2i(220, 280)) -> void:
	view = p_view
	stretch = true
	custom_minimum_size = Vector2(px)
	_vp.size = px
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff3e6")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color("#fff0da")
	key.light_energy = 1.2
	key.shadow_enabled = true
	key.rotation_degrees = Vector3(-45, -35, 0)
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("#c9d8ff")
	rim.light_energy = 0.5
	rim.rotation_degrees = Vector3(-20, 150, 0)
	_vp.add_child(rim)
	# A soft round plinth under the feet.
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.44
	cyl.height = 0.04
	cyl.radial_segments = 48
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#f1e3d3")
	mat.roughness = 0.9
	cyl.material = mat
	disc.mesh = cyl
	disc.position.y = -0.02
	_vp.add_child(disc)
	var cam := Camera3D.new()
	cam.fov = 30
	cam.cull_mask = 0xFFFFF
	_vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.35, 4.1), Vector3(0, 0.72, 0))
	_vp.add_child(_pivot)
	_pivot.add_child(_avatar)
	_avatar.setup(view)


func _process(delta: float) -> void:
	if view and is_visible_in_tree():
		_avatar.sync(Vector3.ZERO, delta)
