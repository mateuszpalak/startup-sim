## Dev tool: render the 3D characters to PNG without a server or a map
## (needs a renderer - run without --headless):
##   godot --path client -s world3d/avatar/preview.gd -- /output/dir [scene ...]
## Scenes: looks, hair, states, items, walk, crowd (default: all).
extends SceneTree

const Avatar3D = preload("res://world3d/avatar_3d.gd")
const PlayerView = preload("res://game/player_view.gd")
const ItemArt = preload("res://game/item_art.gd")
const M = preload("res://world3d/avatar/avatar_mesh.gd")

var root3d := Node3D.new()
var cam := Camera3D.new()
var people: Array = []   # [view, avatar, pos, walk_dir]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else OS.get_user_data_dir()
	var scenes: Array = args.slice(1) if args.size() > 1 else ["looks", "hair", "states", "items", "walk", "closeup", "crowd"]
	DisplayServer.window_set_size(Vector2i(1600, 900))
	get_root().add_child(root3d)
	_env()
	root3d.add_child(cam)
	cam.fov = 38.0
	await process_frame
	for sc in scenes:
		_clear()
		await call("_scene_" + sc)
		for i in 50:
			await process_frame
			_tick(1.0 / 60.0)
		var img := get_root().get_texture().get_image()
		var path: String = out.path_join("%s.png" % sc)
		img.save_png(path)
		print("%s -> %s" % [sc, path])
	quit()


func _env() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#cfd8df")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#b9b4c4")
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.82
	e.tonemap_white = 6.0
	e.ssao_enabled = preload("res://platform/platform.gd").supports_ssao()
	e.ssao_radius = 0.9
	e.ssao_intensity = 3.0
	e.ssao_power = 1.6
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_hdr_threshold = 1.1
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.2
	e.adjustment_contrast = 1.08
	we.environment = e
	root3d.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#fff1dc")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-35), 0)
	root3d.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	floor_mi.mesh = pm
	floor_mi.material_override = M.mat(Color("#d8c3a0"), false, 0.9)
	root3d.add_child(floor_mi)


func _clear() -> void:
	for p in people:
		p[1].queue_free()
		p[0].queue_free()
	people.clear()
	for n in root3d.get_children():
		if n.has_meta("prop"):
			n.queue_free()


## Camera as in the game (pitch 55°), looking at `at` from `dist`.
func _cam(at: Vector3, dist: float, yaw := 0.0) -> void:
	var pitch := deg_to_rad(55.0)
	cam.position = at + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.look_at(at, Vector3.UP)


func _person(pos: Vector3, seed_id: int, look := 0, setup := Callable()) -> PlayerView:
	var v := PlayerView.new()
	v._talk.visible = false
	v.look = look
	v.set_seed(seed_id * 7919 + 13)
	if setup.is_valid():
		setup.call(v)
	var a := Avatar3D.new()
	root3d.add_child(a)
	a.setup(v)
	people.append([v, a, pos, Vector3.ZERO])
	a.sync(pos, 0.016)
	return v


func _walker(pos: Vector3, dir: Vector3, seed_id: int, look := 0, setup := Callable()) -> void:
	_person(pos, seed_id, look, setup)
	people[-1][3] = dir


func _box(pos: Vector3, size: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = M.box(size)
	mi.material_override = M.mat(col, false, 0.8)
	mi.position = pos + Vector3(0, size.y / 2, 0)
	mi.set_meta("prop", true)
	root3d.add_child(mi)


func _label(pos: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.004
	l.modulate = Color("#2a2118")
	l.outline_size = 0
	l.rotation.x = -PI / 2
	l.position = pos + Vector3(0, 0.01, 0)
	l.set_meta("prop", true)
	root3d.add_child(l)


func _tick(dt: float) -> void:
	for p in people:
		var dir: Vector3 = p[3]
		if dir != Vector3.ZERO:
			# back and forth over 2.4 m (the jump back reads as a teleport)
			if p.size() == 4:
				p.append(p[2])
				p.append(0.0)
			p[5] += dt * dir.length()
			p[2] = p[4] + dir.normalized() * (fmod(p[5], 2.4) - 1.2)
		p[1].sync(p[2], dt)


# ------------------------------------------------------------------- scenes

func _scene_looks() -> void:
	var looks := [0, 0, PlayerView.LOOK_PORTER, PlayerView.LOOK_OFFICE, PlayerView.LOOK_GUARD,
		PlayerView.LOOK_POLICE, PlayerView.LOOK_CLEANER, PlayerView.LOOK_FIREFIGHTER, PlayerView.LOOK_SHOP]
	var names := ["gracz", "gracz", "portierka", "biuro/HR", "ochrona", "policja", "sprzątaczka", "strażak", "kasjer"]
	for i in looks.size():
		var p := Vector3(-4.0 + i * 1.0, 0, 0)
		_person(p, 11 + i * 5, looks[i])
		_label(p + Vector3(0, 0, 0.6), names[i])
	_cam(Vector3(0, 0.7, 0.2), 8.6)


func _scene_hair() -> void:
	var names := ["krótkie", "długie", "kok", "jeżyk", "kucyk", "łysy"]
	for i in 6:
		for row in 2:
			var p := Vector3(-2.5 + i * 1.0, 0, -0.7 + row * 1.5)
			_person(p, 3 + i * 13 + row * 7, 0, func(v):
				v.hair_style = i
				v.skin = PlayerView.SKINS[(i + row * 2) % 4]
				v.hair = PlayerView.HAIRS[(i * 2 + row) % PlayerView.HAIRS.size()]
				v.facing = PlayerView.FACING_DOWN if row == 1 else PlayerView.FACING_UP)
			if row == 1:
				_label(p + Vector3(0, 0, 0.6), names[i])
	_cam(Vector3(0, 0.6, 0.1), 6.5)


func _scene_states() -> void:
	var states := [
		["komputer", func(v): v.status = PlayerView.ACT_COMPUTER; v.facing = PlayerView.FACING_UP],
		["sofa", func(v): v.status = PlayerView.ACT_SOFA],
		["toaleta", func(v): v.status = PlayerView.ACT_TOILET],
		["kupa", func(v): v.status = PlayerView.ACT_POOPING],
		["papieros", func(v): v.status = PlayerView.ACT_SMOKING],
		["ekspres", func(v): v.status = PlayerView.ACT_BREWING],
		["mycie rąk", func(v): v.status = PlayerView.ACT_WASHING],
		["wymioty", func(v): v.status = PlayerView.ACT_VOMITING; v.facing = PlayerView.FACING_RIGHT],
		["sika", func(v): v.status = PlayerView.ACT_PEEING; v.facing = PlayerView.FACING_RIGHT],
		["bójka", func(v): v.status = PlayerView.ACT_ATTACKING; v.facing = PlayerView.FACING_RIGHT],
		["zemdlał", func(v): v.status = PlayerView.ACT_PASSED_OUT],
		["nokaut", func(v): v.status = PlayerView.ACT_KNOCKED_OUT],
		["pijany", func(v): v.drunk = 3],
		["mówi", func(v): v._tag.add_child(v._talk); v._talk.visible = true],
		["śmierdzi, zmęczony", func(v): v.smelly = true; v.slow = true],
		["parasol", func(v): v.umbrella = true],
	]
	for i in states.size():
		var col := i % 8
		var row := i / 8
		var p := Vector3(-5.6 + col * 1.6, 0, -1.2 + row * 2.4)
		var s: Array = states[i]
		if s[0] == "komputer":
			_box(p + Vector3(0, 0, -0.55), Vector3(0.9, 0.76, 0.5), Color("#c9a77c"))
			_box(p + Vector3(0, 0, 0.0), Vector3(0.44, 0.44, 0.42), Color("#3d4f6b"))
		elif s[0] in ["sofa"]:
			_box(p + Vector3(0, 0, -0.05), Vector3(0.9, 0.42, 0.6), Color("#7a5a8a"))
			_box(p + Vector3(0, 0, -0.35), Vector3(0.9, 0.85, 0.2), Color("#6a4a7a"))
		elif s[0] in ["toaleta", "kupa"]:
			_box(p + Vector3(0, 0, -0.05), Vector3(0.4, 0.42, 0.5), Color("#f2f2f2"))
		_person(p, 40 + i * 9, 0, s[1])
		_label(p + Vector3(0, 0, 0.75), s[0])
	_cam(Vector3(0, 0.5, 0.2), 11.5)


func _scene_items() -> void:
	var kinds := [ItemArt.LAPTOP, ItemArt.COFFEE, ItemArt.EMPLOYEE_CARD, ItemArt.GUEST_PASS, ItemArt.FRUIT,
		ItemArt.SANDWICH_HAM, ItemArt.BURGER, ItemArt.FRIES, ItemArt.DONUT, ItemArt.BEER, ItemArt.WINE,
		ItemArt.WATER, ItemArt.ENERGY_DRINK, ItemArt.CIGARETTES, ItemArt.UMBRELLA, ItemArt.PIZZA,
		ItemArt.SALAD, ItemArt.KNIFE, ItemArt.BOOMBOX, ItemArt.MILK, ItemArt.MALPKA, ItemArt.CHIPS,
		ItemArt.REMOTE, ItemArt.PIEROGI]
	for i in kinds.size():
		var col := i % 8
		var row := i / 8
		var p := Vector3(-4.2 + col * 1.2, 0, -1.6 + row * 1.6)
		_person(p, 70 + i * 3, 0, func(v): v.held = kinds[i])
		_label(p + Vector3(0, 0, 0.55), ItemArt.item_name(kinds[i]))
	_cam(Vector3(0, 0.5, 0.0), 9.5)


func _scene_walk() -> void:
	for i in 6:
		var p := Vector3(-3.5 + i * 1.3, 0, -0.6)
		var dirs := [Vector3(0, 0, 3), Vector3(3, 0, 0), Vector3(-3, 0, 0), Vector3(0, 0, -3), Vector3(2.1, 0, 2.1), Vector3(0, 0, 1.6)]
		_walker(p, dirs[i].normalized() * (5.6 if i < 5 else 3.3), 200 + i * 31, [0, 0, PlayerView.LOOK_OFFICE, 0, PlayerView.LOOK_CLEANER, 0][i],
			func(v):
				if i == 5:
					v.slow = true
				if i == 1:
					v.held = ItemArt.COFFEE)
	_cam(Vector3(0, 0.6, 0.3), 7.5)


func _scene_closeup() -> void:
	_person(Vector3(-0.8, 0, 0), 5, PlayerView.LOOK_OFFICE)
	_person(Vector3(0.0, 0, 0), 9, 0, func(v): v._tag.add_child(v._talk); v._talk.visible = true; v.held = ItemArt.COFFEE)
	_person(Vector3(0.8, 0, 0), 17, PlayerView.LOOK_PORTER)
	_cam(Vector3(0, 0.9, 0), 3.6)


func _scene_crowd() -> void:
	# game-like distance: readability check
	for i in 14:
		var p := Vector3(-4.0 + (i % 7) * 1.3, 0, -1.0 + (i / 7) * 2.0)
		_person(p, 300 + i * 17, [0, 0, 0, PlayerView.LOOK_OFFICE, 0, PlayerView.LOOK_SHOP, 0][i % 7], func(v):
			v.facing = i % 4
			if i == 3:
				v.highlight = true
			if i == 9:
				v.held = ItemArt.LAPTOP
			if i == 11:
				v.status = PlayerView.ACT_SMOKING)
	_cam(Vector3(0, 0.6, 0.0), 17.0)
