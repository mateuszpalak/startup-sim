## Gamepad play (Xbox / PlayStation / Switch Pro / Steam Deck: anything
## SDL knows). One node under main; it takes every pad event before the
## rest of the game sees it and decides by context:
##  - in the world (no window open): a pad press is the keyboard key of its
##    action (pad_map.gd), held while the button is held, as the touch
##    buttons do; the left stick / d-pad walk (eight directions, the keys'
##    bits), the right stick zooms the camera (2D: nothing to turn), its
##    click resets the zoom;
##  - a window, menu or screen open: pad_cursor.gd moves a focus ring over
##    its buttons, A presses, B is Esc; text fields get pad_keyboard.gd.
## `active` says the last input came from a pad: the hints show its
## buttons, the touch controls hide; any key, click or touch turns it off.
extends Node

const PadMap = preload("res://pad/pad_map.gd")
const PadGlyphs = preload("res://pad/pad_glyphs.gd")
const PadCursor = preload("res://pad/pad_cursor.gd")
const PadKeyboard = preload("res://pad/pad_keyboard.gd")
const Ink = preload("res://ui/ink_ui.gd")
const Settings = preload("res://ui/settings.gd")

## Synthetic key / mouse events carry this device id (not "the user").
const SYNTH_DEVICE := 7777
const REPEAT_FIRST := 0.36
const REPEAT_NEXT := 0.11
const ZOOM_SPEED := 1.2     # zoom factor per second at full tilt (log)
const SCROLL_SPEED := 900.0 # px/s

signal mode_changed

static var inst: Node = null
## The last input was a pad (hints show pad buttons).
static var active := false
## Glyph family of the pad in use: "xbox", "ps", "nintendo".
static var style := "xbox"
static var device := 0

var main: Node = null
var cursor := PadCursor.new()
var keyboard := PadKeyboard.new()
var _layer := CanvasLayer.new()
var _toast := Label.new()
var _toast_t := 0.0
var _held := {}          # Key -> true (keys this node holds down)
var _move_keys := {}     # the movement keys now held
var _buttons := {}       # JoyButton -> pressed
var _axes := {}          # JoyAxis -> value (from the events)
var _ui_dir := Vector2i.ZERO
var _ui_repeat := 0.0
var _pocket := -1
var _ctx := ""
## A menu the cursor opened (StartOS): the pad walks it with its keys.
var popup: PopupMenu = null


func _ready() -> void:
	inst = self
	PadMap.register()
	Ink.key_glyph = _key_glyph
	_layer.layer = 90
	add_child(_layer)
	keyboard.pad = self
	cursor.pad = self
	_layer.add_child(keyboard)
	_layer.add_child(cursor)
	_toast.visible = false
	_toast.add_theme_stylebox_override("normal", Ink.box("hud"))
	Ink.style_label(_toast, 16, Ink.TEXT)
	_layer.add_child(_toast)
	Input.joy_connection_changed.connect(_on_joy)
	for d in Input.get_connected_joypads():
		style = PadMap.style_for(Input.get_joy_name(d))
		device = d


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var real: bool = event is InputEventJoypadButton or absf(event.axis_value) >= PadMap.DEADZONE
		if real:
			_set_active(true, event.device)
		if event is InputEventJoypadButton:
			_button(event.button_index, event.pressed)
		else:
			_axes[event.axis] = event.axis_value
			if event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
				_trigger(event.axis, event.axis_value)
		get_viewport().set_input_as_handled()
		return
	if event.device == SYNTH_DEVICE:
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch \
			or (event is InputEventMouseMotion and event.relative.length() > 4.0):
		_set_active(false)


func _set_active(on: bool, dev := -1) -> void:
	if dev >= 0 and dev != device:
		device = dev
		var s := PadMap.style_for(Input.get_joy_name(dev))
		if s != style:
			style = s
			if active:
				mode_changed.emit()
	if on == active:
		return
	active = on
	cursor.queue_redraw()
	mode_changed.emit()


## What the pad drives now: "keyboard" (typing), "ui" (a window / menu),
## "game" (walking around), "" (nothing to do: loading).
func context() -> String:
	if popup and is_instance_valid(popup) and popup.visible:
		return "popup"
	if keyboard.visible:
		return "keyboard"
	if ui_root() != null:
		return "ui"
	if main and main.game and is_instance_valid(main.game) and main.game.is_inside_tree():
		return "game"
	return ""


## The window the pad's cursor works in: the top menu layer of main with
## something to press (title, login, pause, the day screen, the home
## computer...), else the game's open window, else main's lower layers.
func ui_root() -> Node:
	if main == null:
		return null
	var layers: Array = []
	for c in main.get_children():
		if c is CanvasLayer and c.visible:
			layers.append(c)
	layers.sort_custom(func(a, b): return a.layer > b.layer)
	for l in layers:
		if l.layer >= 20 and cursor.has_candidates(l):
			return l
	var g = main.game
	if g and is_instance_valid(g) and g.is_inside_tree() and g.has_method("pad_modal"):
		var w = g.pad_modal()
		if w:
			return w
		return null
	for l in layers:
		if l.layer < 20 and cursor.has_candidates(l):
			return l
	return null


func _button(b: int, down: bool) -> void:
	_buttons[b] = down
	var ctx := context()
	if ctx == "popup":
		var key: Key = {JOY_BUTTON_DPAD_UP: KEY_UP, JOY_BUTTON_DPAD_DOWN: KEY_DOWN, JOY_BUTTON_A: KEY_ENTER,
			JOY_BUTTON_B: KEY_ESCAPE, JOY_BUTTON_START: KEY_ESCAPE}.get(b, KEY_NONE)
		if key != KEY_NONE:
			press(key, down)
		return
	if ctx == "keyboard":
		if down:
			keyboard.pad_button(b)
		return
	if ctx == "ui":
		_ui_button(b, down)
		return
	if ctx != "game":
		return
	if b in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		return  # polled with the stick in _process
	var action := PadMap.action_of_button(b)
	if action == "zoom_reset":
		if down:
			main.game.set_zoom_level(Settings.zoom)
		return
	if action in ["pocket_prev", "pocket_next"]:
		if down:
			_pocket = posmod(_pocket + (1 if action == "pocket_next" else -1), 3)
			tap(KEY_1 + _pocket)
		return
	var key := PadMap.key_of(action)
	if key != KEY_NONE:
		press(key, down)


func _trigger(axis: int, value: float) -> void:
	var key: Key = KEY_B if axis == JOY_AXIS_TRIGGER_LEFT else KEY_V
	var on := value >= PadMap.TRIGGER and context() == "game"
	press(key, on)


func _ui_button(b: int, down: bool) -> void:
	var root := ui_root()
	var g = main.game if main else null
	# Rolling a cigarette: A is the space bar (held).
	if g and is_instance_valid(g) and root == g.get("roll_game"):
		if b == JOY_BUTTON_A:
			press(KEY_SPACE, down)
			return
	if b in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		return  # _process
	if not down:
		if b == JOY_BUTTON_A:
			press(KEY_SPACE, false)
		return
	match b:
		JOY_BUTTON_A:
			cursor.set_root(root)
			cursor.activate()
		JOY_BUTTON_B, JOY_BUTTON_START:
			tap(KEY_ESCAPE)
		JOY_BUTTON_Y:
			tap(KEY_TAB)  # (closes the action menu)
		JOY_BUTTON_LEFT_SHOULDER:
			cursor.set_root(root)
			cursor.page(-1)
		JOY_BUTTON_RIGHT_SHOULDER:
			cursor.set_root(root)
			cursor.page(1)


# ---------------------------------------------------------------- keys

## Press / release a key as the keyboard would (both key codes).
func press(code: Key, down: bool) -> void:
	if down == _held.get(code, false):
		return
	_held[code] = down
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	ev.device = SYNTH_DEVICE
	Input.parse_input_event(ev)


## A short press (down now, up a little later: polling code sees it).
func tap(code: Key, hold := 0.1) -> void:
	press(code, true)
	get_tree().create_timer(hold).timeout.connect(func(): press(code, false))


func release_all() -> void:
	for k in _held.keys():
		if _held[k]:
			press(k, false)
	_move_keys.clear()


# ---------------------------------------------------------------- polling

func _stick(x_axis: int, y_axis: int) -> Vector2:
	return Vector2(_axes.get(x_axis, 0.0), _axes.get(y_axis, 0.0))


func _dpad() -> Vector2i:
	var d := Vector2i.ZERO
	if _buttons.get(JOY_BUTTON_DPAD_UP, false): d.y -= 1
	if _buttons.get(JOY_BUTTON_DPAD_DOWN, false): d.y += 1
	if _buttons.get(JOY_BUTTON_DPAD_LEFT, false): d.x -= 1
	if _buttons.get(JOY_BUTTON_DPAD_RIGHT, false): d.x += 1
	return d


## Left stick + d-pad -> one of eight directions (screen axes, as WASD).
func move_dir() -> Vector2i:
	var d := _dpad()
	if d == Vector2i.ZERO:
		d = PadMap.stick_dir(_stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y))
	return d


func _process(delta: float) -> void:
	_toast_t -= delta
	_toast.visible = _toast_t > 0.0
	var ctx := context()
	if ctx != _ctx:
		# The chat opened from the world: its keyboard at once.
		if _ctx == "game" and ctx == "ui" and active:
			var chat = main.game.get("chat_box")
			if chat and ui_root() == chat:
				keyboard.open_for(chat._input)
				ctx = "keyboard"
		_ctx = ctx
		# Another context: nothing stays held (a Start pressed in the world
		# would else keep Esc down under the menu it opened).
		release_all()
		_ui_dir = Vector2i.ZERO
	cursor.set_root(ui_root() if ctx == "ui" else (keyboard if ctx == "keyboard" else null))
	cursor.visible = active and cursor.root != null
	if not active:
		return
	var d := move_dir()
	match ctx:
		"game":
			_walk(d)
			_camera(delta)
		"ui", "keyboard", "popup":
			_brush_or_nav(d, delta)
			var rs := PadMap.stick_value(_stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y))
			if rs.y != 0.0:
				cursor.scroll(rs.y * SCROLL_SPEED * delta)


## A direction -> the movement keys a keyboard player holds for it.
static func keys_for(d: Vector2i) -> Array:
	var out := []
	if d.y < 0: out.append(KEY_W)
	if d.y > 0: out.append(KEY_S)
	if d.x < 0: out.append(KEY_A)
	if d.x > 0: out.append(KEY_D)
	return out


func _walk(d: Vector2i) -> void:
	var want := keys_for(d)
	for k in [KEY_W, KEY_A, KEY_S, KEY_D]:
		var on: bool = k in want
		if on != _move_keys.has(k):
			press(k, on)
			if on:
				_move_keys[k] = true
			else:
				_move_keys.erase(k)


## The right stick: up / down zooms the camera (2D: no turning).
func _camera(delta: float) -> void:
	var g = main.game
	var rs := PadMap.stick_value(_stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y))
	if absf(rs.y) > 0.0:
		var y := -rs.y if Settings.pad_invert_y else rs.y
		g.set_zoom_level(g.zoom_level * exp(-y * ZOOM_SPEED * Settings.pad_sensitivity * delta))


func _brush_or_nav(d: Vector2i, delta: float) -> void:
	var g = main.game if main else null
	if g and is_instance_valid(g) and cursor.root == g.get("brush_game"):
		var v := PadMap.stick_value(_stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y))
		if v == Vector2.ZERO:
			v = Vector2(_dpad())
		g.brush_game.pad_move(v * 420.0 * delta)
		return
	if d != _ui_dir:
		_ui_dir = d
		_ui_repeat = REPEAT_FIRST
		if d != Vector2i.ZERO:
			_nav(d)
		return
	if d == Vector2i.ZERO:
		return
	_ui_repeat -= delta
	if _ui_repeat <= 0.0:
		_ui_repeat = REPEAT_NEXT
		_nav(d)


## One step: a slider / choice list changes with left / right, the rest
## moves the focus.
func _nav(d: Vector2i) -> void:
	if _ctx == "popup":
		if d.y != 0 and not _buttons.get(JOY_BUTTON_DPAD_UP, false) and not _buttons.get(JOY_BUTTON_DPAD_DOWN, false):
			tap(KEY_DOWN if d.y > 0 else KEY_UP, 0.05)
		return
	if d.x != 0 and d.y == 0 and cursor.adjust(d.x):
		return
	cursor.move(Vector2(0, d.y) if d.x != 0 and d.y != 0 else Vector2(d))


# ---------------------------------------------------------------- the rest

## The label of a button on the pad in use ("A", "Krzyżyk", "RB"...).
static func label(button: int) -> String:
	var l := PadMap.button_label(button, style)
	if l == "":
		l = {"cross": "Krzyżyk", "circle": "Kółko", "square": "Kwadrat", "triangle": "Trójkąt"}.get(PadMap.ps_shape(button), "?")
	return l


## Hint key caps (ink_ui draw_keycap): the pad's glyph instead of the key.
## -1: no pad now (draw the key), -2: the pad has no button for it (hide).
func _key_glyph(ci: CanvasItem, at: Vector2, key: String, fsize: int, draw: bool) -> float:
	if not active:
		return -1.0
	var b := PadMap.hint_button(key)
	if b < 0:
		return -2.0
	var h := fsize + 6.0
	if not draw:
		return PadGlyphs.width(b, style, h)
	return PadGlyphs.draw(ci, at, b, style, h)


func _on_joy(dev: int, connected: bool) -> void:
	if connected:
		style = PadMap.style_for(Input.get_joy_name(dev))
		show_toast("Pad podłączony: %s" % Input.get_joy_name(dev))
		return
	show_toast("Pad odłączony")
	if dev == device and active:
		release_all()
		_buttons.clear()
		_axes.clear()
		# In the world: the game menu (as a console pauses).
		if context() == "game" and main and main.has_method("open_pause"):
			main.open_pause()
		_set_active(false)


func show_toast(text: String) -> void:
	_toast.text = text
	_toast.reset_size()
	var vs := get_viewport().get_visible_rect().size
	_toast.position = Vector2((vs.x - _toast.size.x) / 2, 18)
	_toast_t = 3.0


## A short rumble on the pad in use (if the player allows it).
static func rumble(weak: float, strong: float, seconds: float) -> void:
	if not Settings.pad_vibration or not active:
		return
	Input.start_joy_vibration(device, weak, strong, seconds)
