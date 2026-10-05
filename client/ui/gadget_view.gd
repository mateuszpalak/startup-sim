## The TV remote, the boombox and the lift's floor panel in the middle of
## the screen (the server's question): a remote with round channel buttons,
## a small display and the red power button; a silver boombox with
## speakers, the cassette window and a key per track; the lift's steel
## panel with a display, the card reader (red until a card is held to it)
## and a round button per floor - only the ground floor's works without the
## card. A click (or keys) picks; Esc puts it away.
extends Control

const Ink = preload("res://ui/ink_ui.gd")

## The option picked (index; the last one = off).
signal pick(choice: int)

const TV_DIALOG := 253
const BOOMBOX_DIALOG := 254

## The lift panel is a dialog from "npc" 0.
var lift := false
## The floor the lift stands at (set by the game).
var lift_floor := 0

## What's on now (set by the game): TV channel / boombox track, 0 = off.
var tv_channel := 0
var track := 0
var dialog_id := 0
var _options: Array = []
var _body := PanelContainer.new()
var _speakers: Array[Control] = []
var _locked: Array = []  # lift: per option, 1 = waits for the card


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	add_child(_body)
	_body.resized.connect(_place)
	get_viewport().size_changed.connect(_place)


func _place() -> void:
	var vs := get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	_body.reset_size()
	_body.position = ((vs - _body.size) / 2).floor()


func open(p: Dictionary) -> void:
	dialog_id = p.id
	_options = p.options
	lift = p.npc == 0
	_locked = p.get("items", [])
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_body.size = Vector2.ZERO  # (the remote is taller than the boombox)
	_speakers.clear()
	if lift:
		_lift_panel(str(p.get("text", "")))
	elif dialog_id == TV_DIALOG:
		_remote()
	else:
		_boombox()
	visible = true
	_place.call_deferred()


func close() -> void:
	visible = false
	dialog_id = 0
	lift = false


## A floor's button label: "Parter" -> "P", "Piętro 3" -> "3".
static func floor_label(name: String) -> String:
	if name.begins_with("Parter"):
		return "P"
	var digits := ""
	for ch in name:
		if ch >= "0" and ch <= "9":
			digits += ch
	return digits if digits != "" else name.left(1)


func _lift_panel(text: String) -> void:
	var floors := _options.size() - 2  # then "stay", then the card reader
	var carded := not _locked.has(1)
	_body.add_theme_stylebox_override("panel", _flat(Color("#b9bec6"), 14, 5, 20))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_body.add_child(col)
	# The display: where the car is.
	var lcd := PanelContainer.new()
	lcd.add_theme_stylebox_override("panel", _flat(Color("#1d1f24"), 6, 3, 8))
	var here := _text("▲▼  %s" % ("P" if lift_floor == 0 else str(lift_floor)), 30, Color("#e8823a"))
	here.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lcd.add_child(here)
	col.add_child(lcd)
	# The card reader: a click (or K) holds the card to it.
	var reader := Button.new()
	reader.focus_mode = Control.FOCUS_NONE
	reader.custom_minimum_size = Vector2(200, 64)
	reader.tooltip_text = "Przyłóż kartę (K)"
	reader.add_theme_stylebox_override("normal", _flat(Color("#2f3238"), 8, 3))
	reader.add_theme_stylebox_override("hover", _flat(Color("#3b3f46"), 8, 3))
	reader.add_theme_stylebox_override("pressed", _flat(Color("#25272c"), 8, 3))
	reader.draw.connect(func():
		var led := Color("#3ddc6a") if carded else Color("#e0453a")
		reader.draw_circle(Vector2(24, 32), 9, Ink.INK)
		reader.draw_circle(Vector2(24, 32), 7, led)
		reader.draw_circle(Vector2(22, 30), 2, Color(1, 1, 1, 0.5))
		var f := Ink.font()
		var t := "Karta OK" if carded else "Przyłóż kartę"
		reader.draw_string(f, Vector2(44, 28), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#f4ead0"))
		reader.draw_string(f, Vector2(44, 48), "czytnik (K)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#9aa0a8")))
	reader.pressed.connect(func(): _pick(_options.size() - 1))
	col.add_child(reader)
	# Floor buttons, the top floor first.
	var order: Array = range(floors)
	var rank := func(i: int) -> int:
		var l := floor_label(_options[i])
		return -1 if l == "P" else int(l)
	order.sort_custom(func(a, b): return rank.call(a) > rank.call(b))
	for i in order:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var locked: bool = i < _locked.size() and _locked[i] == 1
		var b := _key(floor_label(_options[i]), Color("#6e737b") if locked else Color("#3b3f46"), Vector2(56, 56), 28, i, 24)
		if not locked:
			var ring := _flat(Color("#3b3f46"), 28, 3)
			ring.border_color = Color("#e8b85a")
			ring.set_border_width_all(4)
			b.add_theme_stylebox_override("normal", ring)
		row.add_child(b)
		var name := _text(str(_options[i]) + ("  (karta)" if locked else ""), 17, Color("#2a2d33") if not locked else Color("#5d6168"))
		name.custom_minimum_size = Vector2(130, 0)
		row.add_child(name)
		col.add_child(row)
	var stay := _key("◀ ▶   Zostań", Color("#4d5159"), Vector2(200, 40), 8, floors, 17)
	col.add_child(stay)
	var hint := _text(text, 13, Color("#3a3d45"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(200, 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)


static func _flat(color: Color, radius: int, border := 4, margin := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = Ink.INK
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s


## A drawn key: `color`, round (`radius`) or square-ish; picks `choice`.
func _key(text: String, color: Color, key_size: Vector2, radius: int, choice: int, font := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = key_size
	b.add_theme_font_override("font", Ink.font())
	b.add_theme_font_size_override("font_size", font)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(state, Color("#f4f1ea"))
	var pad := 12 if key_size.x > key_size.y else 0
	for st in [["normal", color], ["hover", color.lightened(0.18)], ["pressed", color.darkened(0.25)]]:
		var box := _flat(st[1], radius, 3)
		box.content_margin_left = pad
		box.content_margin_right = pad
		b.add_theme_stylebox_override(st[0], box)
	b.pressed.connect(func(): _pick(choice))
	return b


func _text(t: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", Ink.font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _remote() -> void:
	_body.add_theme_stylebox_override("panel", _flat(Color("#2c2c33"), 38, 5, 22))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_body.add_child(col)
	var top := HBoxContainer.new()
	top.add_child(_text("PILOT", 16, Color("#8d8d99")))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	top.add_child(_key("⏻", Color("#c0392b"), Vector2(46, 46), 23, _options.size() - 1, 22))
	col.add_child(top)
	# The little display: what's on.
	var lcd := PanelContainer.new()
	lcd.add_theme_stylebox_override("panel", _flat(Color("#9fb98c"), 8, 3, 8))
	var on := "Teraz: %s" % _options[tv_channel - 1] if tv_channel > 0 and tv_channel < _options.size() else "— wyłączony —"
	lcd.add_child(_text(on, 17, Color("#1f2a17")))
	col.add_child(lcd)
	for i in _options.size() - 1:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var lit := i + 1 == tv_channel
		row.add_child(_key(str(i + 1), Color("#d4a94a") if lit else Color("#4d4d57"), Vector2(44, 44), 22, i, 20))
		var name := _text(str(_options[i]), 18, Color("#f4ead0") if lit else Color("#c9c9d1"))
		name.custom_minimum_size = Vector2(150, 0)
		name.mouse_filter = Control.MOUSE_FILTER_STOP
		var choice := i
		name.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_pick(choice))
		row.add_child(name)
		col.add_child(row)
	var brand := _text("Startup TV  ·  Esc — odłóż pilota", 13, Color("#8d8d99"))
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(brand)


func _boombox() -> void:
	_body.add_theme_stylebox_override("panel", _flat(Color("#c3c7ce"), 20, 5, 18))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_body.add_child(row)
	row.add_child(_speaker())
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 10)
	row.add_child(mid)
	var title := _text("BOOMBOX", 20, Color("#3a3d45"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(title)
	# The cassette window: the track playing.
	var tape := PanelContainer.new()
	tape.add_theme_stylebox_override("panel", _flat(Color("#25262b"), 10, 3, 10))
	var now := "▶  %s" % _options[track - 1] if track > 0 and track < _options.size() else "◼  cisza"
	var t := _text(now, 18, Color("#e8b85a"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.custom_minimum_size = Vector2(260, 0)
	tape.add_child(t)
	mid.add_child(tape)
	for i in _options.size() - 1:
		var lit := i + 1 == track
		var k := _key("%d   %s" % [i + 1, _options[i]], Color("#b8862f") if lit else Color("#3a3d45"), Vector2(260, 38), 6, i, 17)
		k.alignment = HORIZONTAL_ALIGNMENT_LEFT
		mid.add_child(k)
	mid.add_child(_key("◼   Stop", Color("#8e2f25"), Vector2(260, 38), 6, _options.size() - 1, 17))
	var hint := _text("Esc — odłóż", 13, Color("#4a4d55"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(hint)
	row.add_child(_speaker())


## A round speaker (drawn), pulsing a little while music plays.
func _speaker() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(120, 120)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.draw.connect(func():
		var m := c.size / 2
		var r := 56.0 + (sin(Time.get_ticks_msec() / 90.0) * 2.0 if track > 0 else 0.0)
		c.draw_circle(m, r + 4, Ink.INK)
		c.draw_circle(m, r, Color("#3a3d45"))
		for k in 3:
			c.draw_arc(m, r * (0.35 + k * 0.2), 0, TAU, 40, Color("#2a2c31"), 3.0, true)
		c.draw_circle(m, r * 0.18, Color("#8b8f98")))
	_speakers.append(c)
	return c


func _process(_delta: float) -> void:
	if visible and track > 0:
		for s in _speakers:
			s.queue_redraw()


func _pick(i: int) -> void:
	if visible and i >= 0 and i < _options.size():
		pick.emit(i)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if lift:
		_lift_key(event)
		return
	if event.keycode == KEY_ESCAPE:
		close()
	elif event.keycode == KEY_0:
		_pick(_options.size() - 1)
	elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
		_pick(event.keycode - KEY_1)
	else:
		return
	get_viewport().set_input_as_handled()


## The lift: P / 0 = the ground floor, a digit = that floor, K = the card,
## Esc = stay.
func _lift_key(event: InputEventKey) -> void:
	var floors := _options.size() - 2
	var want := ""
	match event.keycode:
		KEY_ESCAPE:
			_pick(floors)
		KEY_K:
			_pick(_options.size() - 1)
		KEY_P, KEY_0:
			want = "P"
		_:
			if event.keycode >= KEY_1 and event.keycode <= KEY_9:
				want = str(event.keycode - KEY_0)
			else:
				return
	for i in floors:
		if want != "" and floor_label(_options[i]) == want:
			_pick(i)
	get_viewport().set_input_as_handled()
