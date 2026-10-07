## Tab: what can be done here and now - tiles with a picture, the key and
## what it does; pick one with its number (or a click), Tab / Esc closes
## it. The game gives the list (game.gd `_actions_here`).
extends Control

const Kit = preload("res://ui/ui_kit.gd")
const ItemIcons = preload("res://ui/item_icons.gd")
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
		_grid.remove_child(c)
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


const ICONS := {"hand": "hand", "pocket": "briefcase", "give": "arrow", "hit": "energy", "lock": "lock",
	"mischief": "fun", "chat": "chat", "log": "book", "roll": "cig"}


func _draw_tile(b: Button, i: int, a: Dictionary) -> void:
	var r := Rect2(Vector2.ZERO, b.size)
	var hot := b.is_hovered()
	Kit.draw_rrect(b, r, Color("#4a3f4f") if hot else Color(Kit.DARK_HI, 0.9), Kit.R_MD, Kit.ACCENT if hot else Color(1, 1, 1, 0.1), 2)
	var icon: Variant = a.get("icon", "")
	var c := Vector2(b.size.x / 2, 46)
	if icon is int and icon != 0:
		ItemIcons.draw(b, icon, Rect2(c - Vector2(26, 26), Vector2(52, 52)))
		if a.key == "Q":
			Kit.draw_icon(b, "down", c + Vector2(26, 8), 8.0, Kit.GOLD, 2.5)
	else:
		b.draw_circle(c, 24, Color(1, 1, 1, 0.08), true, -1.0, true)
		Kit.draw_icon(b, ICONS.get(str(icon), "star"), c, 13.0, Kit.TEXT, 2.4)
	var f := Kit.font_bold()
	# The number to press (and the key it stands for).
	Kit.draw_rrect(b, Rect2(6, 6, 22, 22), Kit.ACCENT, 11)
	b.draw_string(f, Vector2(6, 22), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 22, 14, Color.WHITE)
	var key: String = a.key
	var kw := f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	Kit.draw_keycap(b, Vector2(b.size.x - maxf(kw + 12, 22) - 6, 6), key, 12)
	# What it does, up to two lines.
	var tf := Kit.font()
	var lines := _wrap(a.text, b.size.x - 12, tf, 14)
	for k in lines.size():
		b.draw_string(tf, Vector2(0, 92 + k * 17), lines[k], HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 14, Kit.TEXT)


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
