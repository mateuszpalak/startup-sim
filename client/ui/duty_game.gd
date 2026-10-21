## A duty's minigame (`DutyStart`): hold E (or the space bar, a finger) until
## the bar fills, or pick one of the answers. The server checks the result.
extends Control

const Ink = preload("res://ui/ink_ui.gd")
const Touch = preload("res://touch/touch.gd")
const Protocol = preload("res://net/protocol.gd")

signal finished(session: int, value: int)
signal put_off

## Letting go drains the bar this many times slower than holding fills it.
const DRAIN := 0.5
const DONE_SHOW := 0.6

var session := 0
var kind := 0
var seconds := 1.0
var progress := 0.0
var _holding := false
var _sent := false
var _done_t := -1.0
var _panel := PanelContainer.new()
var _title := Label.new()
var _text := Label.new()
var _hint := Label.new()
var _bar := Control.new()
var _opts := VBoxContainer.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel.add_theme_stylebox_override("panel", Ink.box("paper"))
	_panel.custom_minimum_size = Vector2(520, 0)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	Ink.style_label(_title, 22, Ink.TEXT_INK)
	col.add_child(_title)
	Ink.style_label(_text, 17, Ink.TEXT_INK)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(480, 0)
	col.add_child(_text)
	_bar.custom_minimum_size = Vector2(480, 40)
	_bar.draw.connect(func(): Ink.draw_bar(_bar, Rect2(Vector2(0, 6), Vector2(_bar.size.x, 28)), progress, Ink.GREEN))
	_bar.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			_holding = e.pressed)
	col.add_child(_bar)
	_opts.add_theme_constant_override("separation", 6)
	col.add_child(_opts)
	Ink.style_label(_hint, 14, Ink.TEXT_MUTED)
	col.add_child(_hint)
	get_viewport().size_changed.connect(_place)


func _place() -> void:
	var vs := get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	_panel.reset_size()
	_panel.position = Vector2((vs.x - _panel.size.x) / 2, vs.y * 0.28)
	Touch.place_center(_panel, get_viewport())


## The server's `DutyStart`: open it (a resend of the open one changes nothing).
func on_start(p: Dictionary) -> void:
	if p.session == 0:
		close()
		return
	if visible and p.session == session:
		return
	session = p.session
	kind = p.kind
	seconds = maxf(float(p.seconds), 0.5)
	progress = 0.0
	_holding = false
	_sent = false
	_done_t = -1.0
	_title.text = p.title
	_text.text = p.text
	for c in _opts.get_children():
		c.queue_free()
	_bar.visible = kind == Protocol.DUTY_HOLD
	if kind == Protocol.DUTY_CHOICE:
		for i in p.options.size():
			var choice: int = i
			var b := Ink.button("%d. %s" % [i + 1, p.options[i]])
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.focus_mode = Control.FOCUS_NONE
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if Touch.active:
				b.custom_minimum_size.y = 50
			b.pressed.connect(func(): _finish(choice))
			_opts.add_child(b)
		_hint.text = "Stuknij odpowiedź  ·  ✕ — później" if Touch.active else "1–%d — odpowiedz  ·  Esc — później" % p.options.size()
	else:
		_hint.text = "Przytrzymaj palec na pasku  ·  ✕ — później" if Touch.active else "Przytrzymaj E albo SPACJĘ  ·  Esc — później"
	visible = true
	_panel.reset_size()
	_place.call_deferred()


func close() -> void:
	visible = false
	session = 0


## Esc: not now; E at that place does its usual thing for a while.
func later() -> void:
	if visible and not _sent and session != 0:
		finished.emit(session, Protocol.DUTY_LATER)
		put_off.emit()
	close()


## Tests: skip the playing.
func auto_finish(value: int) -> void:
	_finish(value)


func _process(delta: float) -> void:
	if not visible:
		return
	if _done_t >= 0.0:
		_done_t += delta
		if _done_t >= DONE_SHOW:
			visible = false
		return
	if kind != Protocol.DUTY_HOLD:
		return
	var held := _holding or Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_SPACE)
	progress = clampf(progress + (delta if held else -delta * DRAIN) / seconds, 0.0, 1.0)
	_bar.queue_redraw()
	if progress >= 1.0:
		_title.text += " — gotowe!"
		_finish(0)


func _finish(value: int) -> void:
	if _sent or session == 0:
		return
	_sent = true
	finished.emit(session, value)
	if kind == Protocol.DUTY_HOLD:
		_done_t = 0.0
	else:
		visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		later()
		get_viewport().set_input_as_handled()
	elif kind == Protocol.DUTY_CHOICE and event.keycode >= KEY_1 and event.keycode <= KEY_4:
		var i: int = event.keycode - KEY_1
		if i < _opts.get_child_count():
			_finish(i)
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_E, KEY_SPACE]:
		get_viewport().set_input_as_handled()
