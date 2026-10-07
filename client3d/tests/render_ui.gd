## Dev tool: screenshots of the special UI screens without a server (needs a
## renderer - run without --headless), over the live 3D menu backdrop:
##   godot --path client3d -s tests/render_ui.gd -- /output/dir [name ...]
## Names: tv, boombox, lift, roll, brush, coffee, plaque, commute, home, portal.
extends SceneTree

const Kit = preload("res://ui/ui_kit.gd")
const Building = preload("res://map/building.gd")
const Backdrop = preload("res://ui/title_backdrop_3d.gd")
const Protocol = preload("res://net/protocol.gd")
const ItemArt = preload("res://game/item_art.gd")

const ALL := ["tv", "boombox", "lift", "roll", "brush", "coffee", "plaque", "commute", "home", "portal"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else OS.get_user_data_dir()
	var names: Array = args.slice(1) if args.size() > 1 else ALL
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(1280, 720)
	ThemeDB.fallback_font = Kit.font()
	ThemeDB.get_default_theme().merge_with(Kit.theme())
	root.theme = Kit.theme()
	var b = Building.new()
	b.load_path("res://maps/building.json")
	var bd := Backdrop.new(b)
	bd.mood = 1
	bd.shot = 1
	root.add_child(bd)
	for n in names:
		var layer := CanvasLayer.new()
		root.add_child(layer)
		var node := _make(n, layer)
		for i in 40:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, n])
		print("saved ", n)
		layer.queue_free()
		await process_frame
	quit()


func _make(n: String, layer: CanvasLayer) -> Node:
	match n:
		"tv", "boombox", "lift":
			var g = preload("res://ui/gadget_view.gd").new()
			layer.add_child(g)
			if n == "tv":
				g.tv_channel = 2
				g.open({"id": 253, "npc": 9, "text": "", "options": ["TVP Info", "Polsat Sport", "MTV", "Wyłącz"]})
			elif n == "boombox":
				g.track = 1
				g.open({"id": 254, "npc": 9, "text": "", "options": ["Disco polo", "Rock", "Jazz", "Wyłącz"]})
			else:
				g.lift_floor = 3
				g.open({"id": 120, "npc": 0, "text": "Wybierz piętro", "options": ["Parter", "Piętro 1", "Piętro 2", "Piętro 3", "Piętro 4"], "items": [0, 1, 1, 1, 1]})
			return g
		"roll":
			var r = preload("res://ui/roll_game.gd").new()
			layer.add_child(r)
			r.start()
			return r
		"brush":
			var r = preload("res://ui/brush_game.gd").new()
			layer.add_child(r)
			r.start()
			return r
		"coffee":
			var c = preload("res://ui/coffee_window.gd").new()
			layer.add_child(c)
			c.held = ItemArt.CUP
			c.show_machine({"machine": 1, "water": 5, "grounds": 2, "max": 8, "busy": 0})
			return c
		"plaque":
			var d = preload("res://ui/door_plaque.gd").new()
			layer.add_child(d)
			d.open(3, "Produkt / IT", "")
			return d
		"commute", "home":
			var d = preload("res://ui/day_screen.gd").new()
			layer.add_child(d)
			if n == "commute":
				d.on_clock({"day": 3, "minute": 7 * 60 + 10, "place": Protocol.PLACE_COMMUTING, "arrive": Protocol.NO_TIME,
					"depart": 7 * 60 + 40, "mode": 5, "money": 4200, "weather": 2, "night": false, "pay_minutes": 0, "pay": 0, "skip": 0})
			else:
				d.on_clock({"day": 3, "minute": 18 * 60 + 30, "place": Protocol.PLACE_HOME, "arrive": Protocol.NO_TIME,
					"depart": 0, "mode": 5, "money": 4200, "weather": 1, "night": false, "pay_minutes": 480, "pay": 24000, "skip": 0})
			return d
		"portal":
			var d = preload("res://ui/desktop.gd").new()
			layer.add_child(d)
			d.set_profile("Ola", {"gender": 1, "age": 25, "city": "Kraków", "email": "ola@poczta.pl",
				"appearance": {"skin": 0, "hair_style": 1, "hair_color": 2, "shirt": 1, "pants": 0}})
			d._open_window("browser")
			return d
	return null
