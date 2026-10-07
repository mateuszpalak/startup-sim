## Item icons for the UI rendered from the same 3D models as in the world
## (world3d/item_models.gd): one small transparent SubViewport per kind,
## rendered once (UPDATE_ONCE) and kept, so the inventory, containers and
## menus show the cozy 3D look instead of pixel art.
extends RefCounted

const ItemModels = preload("res://world3d/item_models.gd")

const PX := 128

static var _tex := {}
static var _holder: Node


static func texture(kind: int) -> Texture2D:
	if kind == 0:
		return null
	if _tex.has(kind):
		return _tex[kind]
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	if _holder == null or not is_instance_valid(_holder):
		_holder = Node.new()
		_holder.name = "ItemIcons"
		tree.root.add_child.call_deferred(_holder)
	var vp := SubViewport.new()
	vp.size = Vector2i(PX, PX)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var mesh := ItemModels.mesh(kind)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var aabb := mesh.get_aabb() if mesh else AABB(Vector3(-0.1, 0, -0.1), Vector3(0.2, 0.2, 0.2))
	var centre := aabb.get_center()
	var radius := maxf(aabb.size.length() * 0.5, 0.02)
	mi.position = -centre
	var pivot := Node3D.new()
	pivot.rotation = Vector3(0, deg_to_rad(-35), 0)
	pivot.add_child(mi)
	vp.add_child(pivot)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = radius * 2.15
	cam.near = 0.01
	cam.far = radius * 10 + 1
	var dir := Vector3(0.0, 0.6, 1).normalized()
	cam.position = dir * radius * 4
	vp.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3.ZERO)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff4e6")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.1
	sun.light_color = Color("#fff1dc")
	sun.rotation_degrees = Vector3(-50, -30, 0)
	vp.add_child(sun)
	_holder.add_child.call_deferred(vp)
	var t := vp.get_texture()
	_tex[kind] = t
	return t


## Draw the icon of `kind` into `rect` of `c` (nothing for an empty slot).
static func draw(c: CanvasItem, kind: int, rect: Rect2) -> void:
	var fresh := kind != 0 and not _tex.has(kind)
	var t := texture(kind)
	if t:
		c.draw_texture_rect(t, rect, false)
	if fresh and c.is_inside_tree():  # rendered on a later frame: draw again then
		var ref: WeakRef = weakref(c)
		c.get_tree().create_timer(0.15).timeout.connect(func():
			var ci = ref.get_ref()
			if ci:
				ci.queue_redraw())
