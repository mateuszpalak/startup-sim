## An on-screen keyboard for the pad (desktops have none; consoles would
## use their own): opens over a text field the pad's A pressed, at the
## bottom of the screen; the field slides above it (touch/keyboard_lift.gd).
## The focus ring walks the keys; X deletes, Y is a space, LB switches
## Polish letters, RB capitals, Start = OK (Enter: sends the chat, logs
## in...), B closes it. The chat gets a row of ready phrases.
extends Control

const Kit = preload("res://ui/ui_kit.gd")
const PadMap = preload("res://pad/pad_map.gd")
const PadGlyphs = preload("res://pad/pad_glyphs.gd")
const KeyboardLift = preload("res://touch/keyboard_lift.gd")

const ROWS := ["1234567890", "qwertyuiop", "asdfghjkl-", "zxcvbnm,.?"]
const POLISH := {"a": "ą", "c": "ć", "e": "ę", "l": "ł", "n": "ń", "o": "ó", "s": "ś", "z": "ż", "x": "ź"}
const PHRASES := ["Cześć!", "Dzięki!", "Tak", "Nie", "Idę na kawę", "Chodź tu", "Pomóż mi", "Sorki!"]
const KEY := Vector2(46, 42)

var pad: Node = null
var field: Control = null
var shift := false
var polish := false
var _panel := PanelContainer.new()
var _col := VBoxContainer.new()
var _phrases := HFlowContainer.new()
var _letters: Array[Button] = []
var _hints := Control.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel.add_theme_stylebox_override("panel", Kit.box("paper"))
	add_child(_panel)
	_col.add_theme_constant_override("separation", 6)
	_panel.add_child(_col)
	_hints.custom_minimum_size = Vector2(0, 26)
	_hints.draw.connect(_draw_hints)
	_col.add_child(_hints)
	_phrases.add_theme_constant_override("h_separation", 6)
	_phrases.add_theme_constant_override("v_separation", 6)
	for p in PHRASES:
		_phrases.add_child(_key(p, Vector2(0, 36), _type.bind(p + " ")))
	_col.add_child(_phrases)
	for r in ROWS:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 5)
		for ch in r:
			var b := _key(ch, KEY, Callable())
			b.set_meta("pad_press", _letter.bind(b))
			b.pressed.connect(_letter.bind(b))
			b.set_meta("ch", ch)
			_letters.append(b)
			row.add_child(b)
		_col.add_child(row)
	var last := HBoxContainer.new()
	last.alignment = BoxContainer.ALIGNMENT_CENTER
	last.add_theme_constant_override("separation", 5)
	last.add_child(_key("ąę", Vector2(64, KEY.y), _toggle_polish))
	last.add_child(_key("Aa", Vector2(56, KEY.y), _toggle_shift))
	last.add_child(_key("@", KEY, _type.bind("@")))
	last.add_child(_key("Spacja", Vector2(200, KEY.y), _type.bind(" ")))
	last.add_child(_key("Usuń", Vector2(80, KEY.y), backspace))
	var ok := _key("OK", Vector2(90, KEY.y), submit, true)
	ok.set_meta("pad_default", true)
	last.add_child(ok)
	_col.add_child(last)
	get_viewport().size_changed.connect(_place)


func _key(text: String, size: Vector2, run: Callable, primary := false) -> Button:
	var b := Kit.button(text, primary)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = size
	b.add_theme_font_size_override("font_size", 17)
	if run.is_valid():
		b.set_meta("pad_press", run)
		b.pressed.connect(run)
	return b


func open_for(c: Control) -> void:
	field = c
	shift = false
	polish = false
	_phrases.visible = _is_chat(c)
	_relabel()
	visible = true
	_place.call_deferred()


func close() -> void:
	visible = false
	KeyboardLift.cover = 0.0


## The chat line (or the terminal): the quick phrases fit.
static func _is_chat(c: Control) -> bool:
	var p := c.get_parent()
	while p:
		if p.get_script() and str(p.get_script().resource_path).ends_with("chat_box.gd"):
			return true
		p = p.get_parent()
	return false


func _place() -> void:
	if not visible:
		return
	var vs := get_viewport_rect().size
	_panel.reset_size()
	_panel.size = _panel.get_combined_minimum_size()
	_panel.position = Vector2((vs.x - _panel.size.x) / 2, vs.y - _panel.size.y - 10).floor()
	KeyboardLift.cover = (_panel.size.y + 20) / vs.y


func _relabel() -> void:
	for b in _letters:
		var ch: String = b.get_meta("ch")
		if polish and POLISH.has(ch):
			ch = POLISH[ch]
		b.text = ch.to_upper() if shift else ch


func _letter(b: Button) -> void:
	_type(b.text)
	if shift:
		shift = false
		_relabel()


func _toggle_shift() -> void:
	shift = not shift
	_relabel()


func _toggle_polish() -> void:
	polish = not polish
	_relabel()


func _type(text: String) -> void:
	if not _field_ok():
		return
	if field is LineEdit:
		var le: LineEdit = field
		if le.max_length > 0 and le.text.length() + text.length() > le.max_length:
			return
		le.insert_text_at_caret(text)
		le.text_changed.emit(le.text)
	elif field is TextEdit:
		(field as TextEdit).insert_text_at_caret(text)


func backspace() -> void:
	if not _field_ok():
		return
	if field is LineEdit:
		var le: LineEdit = field
		var at := le.caret_column
		if at > 0:
			le.delete_text(at - 1, at)
			le.text_changed.emit(le.text)
	elif field is TextEdit:
		(field as TextEdit).backspace()


## OK: the field's Enter (sends, logs in...) and the keyboard closes.
func submit() -> void:
	var f := field
	close()
	if f is LineEdit and is_instance_valid(f):
		(f as LineEdit).text_submitted.emit((f as LineEdit).text)


func _field_ok() -> bool:
	return field != null and is_instance_valid(field) and field.is_visible_in_tree()


## Pad buttons while typing (A goes to the focus ring).
func pad_button(b: int) -> void:
	match b:
		JOY_BUTTON_A:
			pad.cursor.activate()
		JOY_BUTTON_B:
			close()
		JOY_BUTTON_X:
			backspace()
		JOY_BUTTON_Y:
			_type(" ")
		JOY_BUTTON_LEFT_SHOULDER:
			_toggle_polish()
		JOY_BUTTON_RIGHT_SHOULDER:
			_toggle_shift()
		JOY_BUTTON_START:
			submit()


func _process(_d: float) -> void:
	if visible and not _field_ok():
		close()


func _draw_hints() -> void:
	var st: String = pad.style if pad else "xbox"
	var x := 4.0
	var f := Kit.font()
	for h in [[JOY_BUTTON_A, "wpisz"], [JOY_BUTTON_X, "usuń"], [JOY_BUTTON_Y, "spacja"],
			[JOY_BUTTON_LEFT_SHOULDER, "ąę"], [JOY_BUTTON_RIGHT_SHOULDER, "wielkie"],
			[JOY_BUTTON_START, "OK"], [JOY_BUTTON_B, "zamknij"]]:
		x += PadGlyphs.draw(_hints, Vector2(x, 1), h[0], st, 22) + 5
		_hints.draw_string(f, Vector2(x, 18), h[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Kit.TEXT_INK)
		x += f.get_string_size(h[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 14
