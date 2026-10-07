## Tab: what can be done here and now - tiles with a picture, the key and
## what it does; pick one with its number (or a click), Tab / Esc closes
## it. The game gives the list (game.gd `_actions_here`).
extends Control

const Kit = preload("res://ui/ui_kit.gd")
const ItemArt = preload("res://game/item_art.gd")

const TILE := Vector2(132, 124)
const COLUMNS := 4

var _panel := PanelContainer.new()
var _grid := GridContainer.new()
var _empty := Label.new()
var _runs: Array[Callable] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel.add_theme_stylebox_override("panel", Kit.box("paper"))
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	var title := Label.new()
	Kit.style_label(title, 20, Kit.TEXT_INK)
	title.text = "Co mogę teraz zrobić?"
	col.add_child(title)
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	col.add_child(_grid)
	Kit.style_label(_empty, 16, Kit.TEXT_MUTED)
	_empty.text = "Nic tu nie ma do zrobienia — podejdź do czegoś albo do kogoś."
	col.add_child(_empty)
	var hint := Label.new()
	Kit.style_label(hint, 14, Kit.TEXT_MUTED)
	hint.text = "Klawisz numeru albo klik · Tab / Esc zamknij"
	col.add_child(hint)
	get_viewport().size_changed.connect(_place)


## `actions`: [{"key": "E", "text": "Porozmawiaj: HR", "run": Callable,
## "icon": "talk" or an item kind (int)}, ...]
func open(actions: Array) -> void:
	for c in _grid.get_children():
		c.queue_free()
	_runs.clear()
	for a in actions:
		var i := _runs.size()
		_runs.append(a.run)
		_grid.add_child(_tile(i, a))
	_grid.columns = clampi(actions.size(), 1, COLUMNS)
	_empty.visible = actions.is_empty()
	visible = true
	_place.call_deferred()


func _tile(i: int, a: Dictionary) -> Control:
	var b := Button.new()
	b.custom_minimum_size = TILE
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.tooltip_text = "[%s] %s" % [a.key, a.text]
	b.pressed.connect(func(): _pick(i))
	b.draw.connect(func(): _draw_tile(b, i, a))
	b.mouse_entered.connect(b.queue_redraw)
	b.mouse_exited.connect(b.queue_redraw)
	return b


func _draw_tile(b: Button, i: int, a: Dictionary) -> void:
	var r := Rect2(Vector2.ZERO, b.size)
	Kit.box("slot_active" if b.is_hovered() else "slot").draw(b.get_canvas_item(), r)
	var icon: Variant = a.get("icon", "")
	var c := Vector2(b.size.x / 2, 44)
	if icon is int and icon != 0:
		ItemArt.draw(b, icon, c - Vector2(24, 24), 3.0)
		if a.key == "Q":
			_arrow_down(b, c + Vector2(26, 6))
	else:
		_icon(b, str(icon), c)
	var f := Kit.font()
	# The number to press (and the key it stands for).
	var num := str(i + 1)
	b.draw_string_outline(f, Vector2(8, 22), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Kit.INK)
	b.draw_string(f, Vector2(8, 22), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Kit.GOLD)
	var key: String = a.key
	var kw := f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var kr := Rect2(b.size.x - kw - 18, 6, kw + 12, 20)
	b.draw_rect(kr, Kit.INK)
	b.draw_rect(kr.grow(-1.5), Color("#3b3026"))
	b.draw_string(f, Vector2(kr.position.x + 6, 21), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Kit.PAPER_HI)
	# What it does, up to two lines.
	var text: String = a.text
	var lines := _wrap(text, b.size.x - 12, f, 15)
	for k in lines.size():
		var lw := f.get_string_size(lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var at := Vector2((b.size.x - lw) / 2, 92 + k * 17)
		b.draw_string_outline(f, at, lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Kit.INK)
		b.draw_string(f, at, lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Kit.PAPER_HI)


static func _wrap(text: String, width: float, f: Font, fs: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for w in text.split(" "):
		var t := w if line == "" else line + " " + w
		if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and line != "":
			out.append(line)
			line = w
		else:
			line = t
	if line != "":
		out.append(line)
	if out.size() > 2:
		out = out.slice(0, 2)
		out[1] = out[1].left(maxi(out[1].length() - 1, 1)) + "…"
	return out


## A simple ink picture for an action that isn't an item.
func _icon(c: CanvasItem, name: String, m: Vector2) -> void:
	var ink := Kit.INK
	var paper := Kit.PAPER_HI
	var gold := Kit.GOLD
	match name:
		"hand":  # E: use what's next to you
			c.draw_circle(m + Vector2(0, 6), 15, ink)
			c.draw_circle(m + Vector2(0, 6), 12, paper)
			for k in 4:
				var x := -10.5 + k * 7.0
				c.draw_rect(Rect2(m + Vector2(x - 3.5, -20 + absf(k - 1.5) * 3), Vector2(7, 22)), ink)
				c.draw_rect(Rect2(m + Vector2(x - 2, -18.5 + absf(k - 1.5) * 3), Vector2(4, 21)), paper)
			c.draw_line(m + Vector2(-14, 6), m + Vector2(-22, -6), ink, 7, true)
			c.draw_line(m + Vector2(-14, 6), m + Vector2(-21, -5), paper, 3.5, true)
		"pocket":  # put away
			var pts := PackedVector2Array([m + Vector2(-18, -14), m + Vector2(18, -14), m + Vector2(16, 12), m + Vector2(0, 20), m + Vector2(-16, 12)])
			c.draw_colored_polygon(pts, Color("#5b7fa6"))
			pts.append(pts[0])
			c.draw_polyline(pts, ink, 3, true)
			c.draw_line(m + Vector2(-18, -6), m + Vector2(18, -6), ink, 2, true)
			_arrow_down(c, m + Vector2(0, -22))
		"give":
			c.draw_line(m + Vector2(-20, 4), m + Vector2(14, 4), ink, 6, true)
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(22, 4), m + Vector2(10, -8), m + Vector2(10, 16)]), ink)
			c.draw_circle(m + Vector2(-8, -14), 7, gold)
			c.draw_arc(m + Vector2(-8, -14), 7, 0, TAU, 20, ink, 2, true)
		"hit":
			c.draw_rect(Rect2(m + Vector2(-16, -12), Vector2(30, 26)), ink)
			c.draw_rect(Rect2(m + Vector2(-13, -9), Vector2(24, 20)), Color("#e3b48c"))
			for k in 3:
				c.draw_line(m + Vector2(-13 + k * 8 + 8, -9), m + Vector2(-13 + k * 8 + 8, 3), ink, 2)
			for a in [-0.6, 0.0, 0.6]:
				var d := Vector2.from_angle(a - PI / 2)
				c.draw_line(m + Vector2(18, -16) + d * 4, m + Vector2(18, -16) + d * 12, Color("#c0392b"), 3, true)
		"lock":
			c.draw_arc(m + Vector2(0, -8), 11, PI, TAU, 20, ink, 5, true)
			c.draw_rect(Rect2(m + Vector2(-16, -8), Vector2(32, 26)), ink)
			c.draw_rect(Rect2(m + Vector2(-13, -5), Vector2(26, 20)), gold)
			c.draw_circle(m + Vector2(0, 3), 4, ink)
		"mischief":  # a little devil
			c.draw_circle(m + Vector2(0, 4), 17, ink)
			c.draw_circle(m + Vector2(0, 4), 14, Color("#c0392b"))
			for s in [-1, 1]:
				c.draw_colored_polygon(PackedVector2Array([m + Vector2(s * 6, -8), m + Vector2(s * 16, -10), m + Vector2(s * 14, -22)]), ink)
				c.draw_circle(m + Vector2(s * 6, 0), 3, paper)
			c.draw_arc(m + Vector2(0, 8), 7, 0.3, PI - 0.3, 12, ink, 2.5, true)
		"chat":
			c.draw_rect(Rect2(m + Vector2(-20, -18), Vector2(40, 28)), ink)
			c.draw_rect(Rect2(m + Vector2(-17, -15), Vector2(34, 22)), paper)
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-8, 9), m + Vector2(4, 9), m + Vector2(-10, 20)]), ink)
			for k in 3:
				c.draw_circle(m + Vector2(-9 + k * 9, -4), 2.5, ink)
		"log":  # a book
			c.draw_rect(Rect2(m + Vector2(-18, -18), Vector2(36, 38)), ink)
			c.draw_rect(Rect2(m + Vector2(-15, -15), Vector2(30, 32)), Color("#8e5a3c"))
			c.draw_rect(Rect2(m + Vector2(-9, -9), Vector2(18, 8)), paper)
			c.draw_line(m + Vector2(-15, 14), m + Vector2(15, 14), paper, 3)
		"roll":
			c.draw_line(m + Vector2(-20, 6), m + Vector2(16, -6), ink, 9, true)
			c.draw_line(m + Vector2(-19, 6), m + Vector2(15, -6), paper, 5, true)
			c.draw_circle(m + Vector2(19, -7), 4, Color("#e8823a"))
		_:
			c.draw_circle(m, 14, ink)
			c.draw_circle(m, 11, gold)


func _arrow_down(c: CanvasItem, at: Vector2) -> void:
	c.draw_line(at + Vector2(0, -10), at + Vector2(0, 6), Kit.INK, 5, true)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-8, 4), at + Vector2(8, 4), at + Vector2(0, 14)]), Kit.INK)


func close() -> void:
	visible = false


func _pick(i: int) -> void:
	if i < _runs.size():
		var run := _runs[i]
		close()
		run.call()


func _place() -> void:
	var vs := get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	_panel.reset_size()
	_panel.size = _panel.get_combined_minimum_size()
	_panel.position = ((vs - _panel.size) / 2).floor()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode in [KEY_TAB, KEY_ESCAPE]:
		close()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
		_pick(event.physical_keycode - KEY_1)
		get_viewport().set_input_as_handled()
