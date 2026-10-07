## On-screen controls for touch screens (in the game): a floating joystick
## under the left thumb (right with the setting), the round action button
## (E: what the hint above the inventory says), buttons around it for the
## held item (F use, Q drop, G give), Tab (what can be done here), voice
## (V: hold to talk, a quick tap latches it on / off; B: whisper), and the
## menu, chat and journal at the top. A window open (dialog, computer,
## mini-game): only a close button (Esc).
##
## On the world itself: a tap walks there (on a person or a piece of
## furniture: walks up and presses E), two fingers pinch to zoom and twist
## to turn the camera.
##
## Buttons press the same keys the keyboard does (touch.gd `press`), so the
## game keeps one input path. Movement: `move_dir()`, read by game.gd.
extends Control

const Kit = preload("res://ui/ui_kit.gd")
const Touch = preload("res://touch/touch.gd")
const Settings = preload("res://ui/settings.gd")
const Movement = preload("res://sim/movement.gd")
const Coords = preload("res://world3d/coords.gd")
const ItemArt = preload("res://game/item_art.gd")
const Protocol = preload("res://net/protocol.gd")
const ItemIcons = preload("res://ui/item_icons.gd")

var game: Node

## Buttons: id -> {icon, key, hold, r, at (centre), shown, down (touch index or -1), label}
var buttons := {}
var _joy_index := -1
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _joy_home := Vector2.ZERO
var _joy_r := 64.0
## World gestures: touch index -> {"pos", "start", "t"}
var _world := {}
var _pinch_d := 0.0
var _pinch_a := 0.0
var _gesture := false
var _talk_latched := false
var _talk_down_ms := 0
var _busy := false
var _flash := Vector2.ZERO
var _flash_ms := -10000


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_add("act", "hand", KEY_E, false)
	_add("use", "use", KEY_F, false, "Użyj")
	_add("drop", "drop", KEY_Q, false, "Upuść")
	_add("give", "give", KEY_G, false, "Podaj")
	_add("menu", "dots", KEY_TAB, false, "Akcje")
	_add("talk", "mic", KEY_V, true, "Mów")
	_add("whisper", "whisper", KEY_B, true, "Szept")
	_add("pause", "menu", KEY_ESCAPE, false)
	_add("chat", "chat", KEY_ENTER, false)
	_add("log", "book", KEY_H, false)
	_add("close", "close", KEY_ESCAPE, false)
	get_viewport().size_changed.connect(layout)
	layout.call_deferred()


func _add(id: String, icon: String, key: Key, hold: bool, label := "") -> void:
	buttons[id] = {"icon": icon, "key": key, "hold": hold, "r": 30.0, "at": Vector2.ZERO,
		"shown": false, "down": -1, "label": label}


## Where everything sits: the safe area, the joystick side, the size setting.
func layout() -> void:
	var sr := Touch.safe_rect(get_viewport())
	var s := Settings.touch_size
	var m := 16.0
	var left := Settings.touch_left
	var ra := 44.0 * s
	var rb := 29.0 * s
	var rs := 26.0 * s
	_joy_r = 62.0 * s
	# Action cluster in the corner opposite the joystick.
	var cx := sr.end.x - m - ra - 8 if left else sr.position.x + m + ra + 8
	var cy := sr.end.y - m - ra - 4
	buttons.act.r = ra
	buttons.act.at = Vector2(cx, cy)
	var d := ra + rb + 12
	var arc := {"use": 180.0, "drop": 216.0, "give": 252.0, "menu": 288.0}
	for id in arc:
		var a := deg_to_rad(arc[id])
		buttons[id].r = rb
		buttons[id].at = Vector2(cx + (cos(a) * d if left else -cos(a) * d), cy + sin(a) * d)  # opens toward the centre
	# Voice above the cluster, on the outer edge.
	var vx := sr.end.x - m - rb if left else sr.position.x + m + rb
	buttons.talk.r = rb
	buttons.talk.at = Vector2(vx, cy - d - rb * 2 - 26)
	buttons.whisper.r = rb * 0.86
	buttons.whisper.at = buttons.talk.at + Vector2(-(rb * 2 + 14) * (1.0 if left else -1.0), rb * 0.3)
	# Menu, chat, journal: a row under the clock (top left).
	var top := sr.position.y + 62
	var x := sr.position.x + m + rs
	for id in ["pause", "chat", "log"]:
		buttons[id].r = rs
		buttons[id].at = Vector2(x, top + rs)
		x += rs * 2 + 12
	buttons.close.r = rs
	buttons.close.at = Vector2(sr.end.x - m - rs, sr.position.y + m + rs + 64)
	_joy_home = Vector2(sr.position.x + m + _joy_r + 24, sr.end.y - m - _joy_r - 20) if left \
		else Vector2(sr.end.x - m - _joy_r - 24, sr.end.y - m - _joy_r - 20)
	queue_redraw()


## Screen direction of the joystick in eight directions (x right, y down).
func move_dir() -> Vector2i:
	if _joy_index < 0:
		return Vector2i.ZERO
	var v := (_joy_pos - _joy_origin) / _joy_r
	if v.length() < 0.3:
		return Vector2i.ZERO
	var a := snappedf(v.angle(), PI / 4)
	return Vector2i(roundi(cos(a)), roundi(sin(a)))


## A ring where a tap sent us walking.
func flash_at(p: Vector2) -> void:
	_flash = p
	_flash_ms = Time.get_ticks_msec()


func joystick_active() -> bool:
	return _joy_index >= 0


func _process(_d: float) -> void:
	if game == null:
		return
	var busy := _is_busy()
	if busy != _busy:
		_busy = busy
		_release_all()
	var held: int = game.me.held if game.me else 0
	var playing: bool = game.have_state and not busy
	buttons.act.shown = playing
	for id in ["use", "drop", "give"]:
		buttons[id].shown = playing and held != 0
	for id in ["menu", "talk", "whisper", "pause", "chat", "log"]:
		buttons[id].shown = playing
	buttons.close.shown = busy and game.have_state and not game.input_blocked
	buttons.close.label = "Wstań" if game.screen.visible else ""
	if _talk_latched and not playing:
		_talk_latched = false
		Touch.press(KEY_V, false)
	queue_redraw()


func _is_busy() -> bool:
	return game.input_blocked or game.window_open() or game.action_menu.visible or game.door_plaque.visible


func _release_all() -> void:
	for id in buttons:
		var b: Dictionary = buttons[id]
		if b.down >= 0 and b.hold and not (id == "talk" and _talk_latched):
			Touch.press(b.key, false)
		b.down = -1
	_joy_index = -1
	_world.clear()
	_gesture = false


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if game == null or not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_button(event.index, event.position):
				get_viewport().set_input_as_handled()
			elif _can_start_joystick(event.position):
				_joy_index = event.index
				_joy_origin = _clamp_joy(event.position)
				_joy_pos = event.position
				game.touch_walk_cancel()
				get_viewport().set_input_as_handled()
		else:
			if event.index == _joy_index:
				_joy_index = -1
				get_viewport().set_input_as_handled()
			for id in buttons:
				if buttons[id].down == event.index:
					_button_up(id)
					get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _joy_index:
			_joy_pos = event.position
			# Dragging beyond the ring pulls the base along.
			var off: Vector2 = _joy_pos - _joy_origin
			if off.length() > _joy_r * 1.25:
				_joy_origin = _joy_pos - off.normalized() * _joy_r * 1.25
			get_viewport().set_input_as_handled()


func _touch_button(index: int, p: Vector2) -> bool:
	for id in buttons:
		var b: Dictionary = buttons[id]
		if b.shown and b.down < 0 and p.distance_to(b.at) <= maxf(b.r, Touch.TARGET / 2) + 6:
			b.down = index
			_button_down(id)
			return true
	return false


func _button_down(id: String) -> void:
	var b: Dictionary = buttons[id]
	if id == "talk":
		_talk_down_ms = Time.get_ticks_msec()
		if _talk_latched:
			_talk_latched = false
			Touch.press(KEY_V, false)
			b.down = -1
			return
		Touch.press(KEY_V, true)
		return
	if b.hold:
		Touch.press(b.key, true)
	elif id == "act":
		game.touch_walk_cancel()
		Touch.tap(KEY_E)
	else:
		Touch.tap(b.key)


func _button_up(id: String) -> void:
	var b: Dictionary = buttons[id]
	b.down = -1
	if id == "talk":
		if Time.get_ticks_msec() - _talk_down_ms < 250:
			_talk_latched = true  # a quick tap: stays on until the next tap
		else:
			Touch.press(KEY_V, false)
		return
	if b.hold:
		Touch.press(b.key, false)


func _can_start_joystick(p: Vector2) -> bool:
	if _joy_index >= 0 or _busy or not game.have_state:
		return false
	var vs := get_viewport_rect().size
	var on_side := p.x < vs.x * 0.42 if Settings.touch_left else p.x > vs.x * 0.58
	if not on_side or p.y < vs.y * 0.3:
		return false
	return not game.hud.panel_rect().grow(6).has_point(p)


func _clamp_joy(p: Vector2) -> Vector2:
	var sr := Touch.safe_rect(get_viewport())
	return p.clamp(sr.position + Vector2.ONE * _joy_r, sr.end - Vector2.ONE * _joy_r)


## Touches nobody else took (not on a button, the joystick or a window):
## taps walk, two fingers zoom and turn.
func _unhandled_input(event: InputEvent) -> void:
	if game == null or not visible or _busy or not game.have_state:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_world[event.index] = {"pos": event.position, "start": event.position, "t": Time.get_ticks_msec()}
			if _world.size() == 2:
				_gesture = true
				_pinch_start()
		else:
			var w: Dictionary = _world.get(event.index, {})
			_world.erase(event.index)
			if not w.is_empty() and not _gesture and _world.is_empty() \
					and Time.get_ticks_msec() - w.t < 350 and w.start.distance_to(event.position) < 16:
				game.touch_tap_world(event.position)
			if _world.size() < 2 and _gesture:
				game.world_view.rig.settle()
			if _world.is_empty():
				_gesture = false
			elif _world.size() == 1:
				pass
	elif event is InputEventScreenDrag and _world.has(event.index):
		_world[event.index].pos = event.position
		if _world.size() >= 2:
			_pinch_move()


func _two() -> Array:
	var keys := _world.keys()
	keys.sort()
	return [_world[keys[0]].pos, _world[keys[1]].pos]


func _pinch_start() -> void:
	var p := _two()
	_pinch_d = maxf(p[0].distance_to(p[1]), 1.0)
	_pinch_a = (p[1] - p[0]).angle()


func _pinch_move() -> void:
	var p := _two()
	var d: float = maxf(p[0].distance_to(p[1]), 1.0)
	var a: float = (p[1] - p[0]).angle()
	game.set_zoom_level(game.zoom_level * d / _pinch_d)
	game.world_view.rig.turn_by(angle_difference(_pinch_a, a))
	_pinch_d = d
	_pinch_a = a


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if game == null:
		return
	var alpha := Settings.touch_opacity
	var ft := (Time.get_ticks_msec() - _flash_ms) / 450.0
	if ft < 1.0:
		draw_arc(_flash, 10.0 + 22.0 * ft, 0, TAU, 32, Color(Kit.PAPER, 0.9 * (1.0 - ft)), 3.0, true)
	# Joystick: the ring where the thumb landed (or a faint hint at home).
	if buttons.act.shown:
		if _joy_index >= 0:
			_draw_joy(_joy_origin, _joy_pos, alpha)
		else:
			draw_circle(_joy_home, _joy_r, Color(Kit.DARK, 0.18 * alpha), true, -1.0, true)
			draw_arc(_joy_home, _joy_r, 0, TAU, 48, Color(1, 1, 1, 0.22 * alpha), 2.0, true)
			draw_circle(_joy_home, _joy_r * 0.42, Color(1, 1, 1, 0.16 * alpha), true, -1.0, true)
	for id in buttons:
		var b: Dictionary = buttons[id]
		if b.shown:
			_draw_button(id, b, alpha)


func _draw_joy(o: Vector2, p: Vector2, alpha: float) -> void:
	draw_circle(o, _joy_r, Color(Kit.DARK, 0.35 * alpha), true, -1.0, true)
	draw_arc(o, _joy_r, 0, TAU, 48, Color(1, 1, 1, 0.45 * alpha), 2.5, true)
	var k := o + (p - o).limit_length(_joy_r)
	draw_circle(k + Vector2(0, 3), _joy_r * 0.44, Color(0, 0, 0, 0.25 * alpha), true, -1.0, true)
	draw_circle(k, _joy_r * 0.44, Color(Kit.PAPER, 0.9 * alpha), true, -1.0, true)
	draw_arc(k, _joy_r * 0.44, 0, TAU, 32, Color(Kit.ACCENT, 0.9 * alpha), 3.0, true)


func _draw_button(id: String, b: Dictionary, alpha: float) -> void:
	var c: Vector2 = b.at
	var r: float = b.r
	var down: bool = b.down >= 0 or (id == "talk" and _talk_latched)
	var bg := Color(Kit.DARK, 0.62 * alpha)
	var fg := Color(Kit.TEXT, alpha)
	if id == "act":
		var ready: bool = game.hint_label.visible and game.hint_label.text.begins_with("[E]")
		bg = Color(Kit.ACCENT if ready else Kit.DARK, (0.95 if ready else 0.6) * alpha)
	if id in ["talk", "whisper"] and down:
		bg = Color(Kit.RED, 0.95 * alpha)
	elif down:
		bg = Color(Kit.ACCENT_LO, 0.95 * alpha)
	draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.22 * alpha), true, -1.0, true)
	draw_circle(c, r, bg, true, -1.0, true)
	draw_arc(c, r - 1, 0, TAU, 40, Color(1, 1, 1, 0.22 * alpha), 2.0, true)
	var labelled: bool = b.label != "" or id == "act"
	var ic := c - Vector2(0, r * 0.16 if labelled else 0.0)
	var icon_s := r * (0.36 if id == "act" else (0.34 if labelled else 0.46))
	if id == "use" and game.me and game.me.held != 0:
		ItemIcons.draw(self, game.me.held, Rect2(ic - Vector2(r, r) * 0.5, Vector2(r, r) * 1.0))
	else:
		Kit.draw_icon(self, b.icon, ic, icon_s, fg, 2.2)
	var f := Kit.font_bold()
	var text: String = "E" if id == "act" else b.label
	if labelled:
		var fs := maxi(11, int(r * (0.3 if id == "act" else 0.34)))
		draw_string(f, c + Vector2(-r - 20, r * 0.62), text, HORIZONTAL_ALIGNMENT_CENTER, r * 2 + 40, fs, Color(fg, 0.9))
