## On-screen controls for touch screens (in the game): a floating joystick
## under the left thumb (right with the setting), the round action button
## (E: what the hint above the inventory says), buttons around it for the
## held item (F use, Q drop, G give), Tab (what can be done here), voice
## (V: hold to talk, a quick tap latches it on / off; B: whisper), and the
## menu, chat and journal at the top. A window open (dialog, computer,
## mini-game): only a close button (Esc).
##
## On the world itself: a tap walks there (on a person or a piece of
## furniture: walks up and presses E), two fingers pinch to zoom.
##
## Drawn in the game's ink style (dark wood discs, ink rings, paper icons).
##
## Buttons press the same keys the keyboard does (touch.gd `press`), so the
## game keeps one input path. Movement: `move_dir()`, read by game.gd.
extends Control

const Ink = preload("res://ui/ink_ui.gd")
const Touch = preload("res://touch/touch.gd")
const Settings = preload("res://ui/settings.gd")
const ItemArt = preload("res://game/item_art.gd")

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
var _gesture := false
var _talk_latched := false
var _talk_down_ms := 0
var _busy := false
var _flash := Vector2.ZERO
var _last_bar := Rect2()
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
	# Narrow screens (portrait): the inventory bar takes the bottom, so
	# the thumbs go above it.
	var bar: Rect2 = game.hud.panel_rect() if game else Rect2()
	var floor_y := sr.end.y
	if bar.size.x > 0 and bar.position.x < sr.position.x + m + 2 * (ra + rb + 12) + 10:
		floor_y = minf(floor_y, bar.position.y - 30)
	var cx := sr.end.x - m - ra - 8 if left else sr.position.x + m + ra + 8
	var cy := floor_y - m - ra - 4
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
	var top := sr.position.y + (124 if Touch.narrow(get_viewport()) else 62)
	var x := sr.position.x + m + rs
	for id in ["pause", "chat", "log"]:
		buttons[id].r = rs
		buttons[id].at = Vector2(x, top + rs)
		x += rs * 2 + 12
	buttons.close.r = rs
	buttons.close.at = Vector2(sr.end.x - m - rs, top + rs)
	_joy_home = Vector2(sr.position.x + m + _joy_r + 24, floor_y - m - _joy_r - 20) if left \
		else Vector2(sr.end.x - m - _joy_r - 24, floor_y - m - _joy_r - 20)
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
	var bar: Rect2 = game.hud.panel_rect()
	if bar != _last_bar:
		_last_bar = bar
		layout()
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
	return game.input_blocked or game.window_open()


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
## taps walk, two fingers zoom.
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
			if _world.is_empty():
				_gesture = false
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


func _pinch_move() -> void:
	var p := _two()
	var d: float = maxf(p[0].distance_to(p[1]), 1.0)
	game.set_zoom_level(game.zoom_level * d / _pinch_d)
	_pinch_d = d


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if game == null:
		return
	var alpha := Settings.touch_opacity
	var ft := (Time.get_ticks_msec() - _flash_ms) / 450.0
	if ft < 1.0:
		draw_arc(_flash, 10.0 + 22.0 * ft, 0, TAU, 32, Color(Ink.PAPER_HI, 0.9 * (1.0 - ft)), 3.0)
	# Joystick: the ring where the thumb landed (or a faint hint at home).
	if buttons.act.shown:
		if _joy_index >= 0:
			_draw_joy(_joy_origin, _joy_pos, alpha)
		else:
			draw_circle(_joy_home, _joy_r, Color(Ink.DARK_LO, 0.22 * alpha))
			draw_arc(_joy_home, _joy_r, 0, TAU, 48, Color(Ink.PAPER, 0.3 * alpha), 2.0)
			draw_circle(_joy_home, _joy_r * 0.42, Color(Ink.PAPER, 0.18 * alpha))
	for id in buttons:
		var b: Dictionary = buttons[id]
		if b.shown:
			_draw_button(id, b, alpha)


func _draw_joy(o: Vector2, p: Vector2, alpha: float) -> void:
	draw_circle(o, _joy_r, Color(Ink.DARK_LO, 0.4 * alpha))
	draw_arc(o, _joy_r, 0, TAU, 48, Color(Ink.PAPER, 0.5 * alpha), 2.5)
	var k := o + (p - o).limit_length(_joy_r)
	draw_circle(k + Vector2(0, 3), _joy_r * 0.44, Color(0, 0, 0, 0.3 * alpha))
	draw_circle(k, _joy_r * 0.44, Color(Ink.PAPER, 0.92 * alpha))
	draw_arc(k, _joy_r * 0.44, 0, TAU, 32, Color(Ink.INK, 0.9 * alpha), 3.0)


func _draw_button(id: String, b: Dictionary, alpha: float) -> void:
	var c: Vector2 = b.at
	var r: float = b.r
	var down: bool = b.down >= 0 or (id == "talk" and _talk_latched)
	var bg := Color(Ink.DARK, 0.78 * alpha)
	var fg := Color(Ink.TEXT, alpha)
	if id == "act":
		var ready: bool = game.hint_label.visible and game.hint_text.begins_with("[E]")
		bg = Color(Ink.ACCENT if ready else Ink.DARK, (0.95 if ready else 0.75) * alpha)
	if id in ["talk", "whisper"] and down:
		bg = Color(Ink.RED, 0.95 * alpha)
	elif down:
		bg = Color(Ink.ACCENT_LO, 0.95 * alpha)
	draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.3 * alpha))
	draw_circle(c, r, bg)
	draw_arc(c, r - 1, 0, TAU, 40, Color(Ink.INK, 0.95 * alpha), float(Ink.LINE) + 1.0)
	draw_arc(c, r - 4, PI * 1.1, PI * 1.6, 12, Color(Ink.DARK_HI if not down else Ink.ACCENT_HI, alpha), 2.0)
	var labelled: bool = b.label != "" or id == "act"
	var ic := c - Vector2(0, r * 0.16 if labelled else 0.0)
	var icon_s := r * (0.36 if id == "act" else (0.34 if labelled else 0.46))
	if id == "use" and game.me and game.me.held != 0:
		var box := r * 0.9
		ItemArt.draw(self, game.me.held, ic - Vector2(box, box) / 2, box / 16.0)
	else:
		draw_icon(self, b.icon, ic, icon_s, fg, 2.2)
	var text: String = "E" if id == "act" else b.label
	if labelled:
		var fs := maxi(12, int(r * (0.32 if id == "act" else 0.36)))
		draw_string_outline(Ink.font(), c + Vector2(-r - 20, r * 0.66), text, HORIZONTAL_ALIGNMENT_CENTER, r * 2 + 40, fs, 4, Color(Ink.INK, alpha))
		draw_string(Ink.font(), c + Vector2(-r - 20, r * 0.66), text, HORIZONTAL_ALIGNMENT_CENTER, r * 2 + 40, fs, fg)


## Line icons for the buttons, centred on `c`, `s` = half their size / 10.
static func draw_icon(ci: CanvasItem, name: String, c: Vector2, s: float, col: Color, w := 2.0) -> void:
	var k := s / 10.0
	var line := func(pts: Array) -> void:
		var out := PackedVector2Array()
		for v in pts:
			out.append(c + v * k)
		ci.draw_polyline(out, col, w)
	var ring := func(at: Vector2, rr: float, a0 := 0.0, a1 := TAU) -> void:
		ci.draw_arc(c + at * k, rr * k, a0, a1, maxi(8, int(rr * 3)), col, w)
	match name:
		"chat":
			line.call([Vector2(-4, 5), Vector2(-6, 9), Vector2(0, 5), Vector2(9, 5), Vector2(9, -7), Vector2(-9, -7), Vector2(-9, 5), Vector2(-4, 5)])
		"close":
			line.call([Vector2(-6, -6), Vector2(6, 6)])
			line.call([Vector2(6, -6), Vector2(-6, 6)])
		"book":
			line.call([Vector2(0, -6), Vector2(0, 8)])
			line.call([Vector2(0, -6), Vector2(-4, -8), Vector2(-9, -8), Vector2(-9, 6), Vector2(-4, 6), Vector2(0, 8),
				Vector2(4, 6), Vector2(9, 6), Vector2(9, -8), Vector2(4, -8), Vector2(0, -6)])
		"hand":
			line.call([Vector2(-5, 9), Vector2(-8, 1), Vector2(-7, -1), Vector2(-4, 2), Vector2(-4, -8), Vector2(-2, -9), Vector2(0, -8), Vector2(0, -1)])
			line.call([Vector2(0, -6), Vector2(2, -7), Vector2(4, -6), Vector2(4, -1)])
			line.call([Vector2(4, -4), Vector2(6, -5), Vector2(8, -4), Vector2(8, 4), Vector2(5, 9)])
		"mic":
			line.call([Vector2(-3, -5), Vector2(-3, 1)])
			line.call([Vector2(3, -5), Vector2(3, 1)])
			ring.call(Vector2(0, -5), 3, PI, TAU)
			ring.call(Vector2(0, 1), 3, 0, PI)
			ring.call(Vector2(0, 0), 7, 0.15, PI - 0.15)
			line.call([Vector2(0, 7), Vector2(0, 10)])
		"whisper":
			line.call([Vector2(-6, -4), Vector2(-6, 0)])
			line.call([Vector2(-2, -4), Vector2(-2, 0)])
			ring.call(Vector2(-4, -4), 2, PI, TAU)
			ring.call(Vector2(-4, 0), 2, 0, PI)
			ring.call(Vector2(-4, 0), 5, 0.2, PI - 0.2)
			ring.call(Vector2(3, -2), 3, -0.9, 0.9)
			ring.call(Vector2(3, -2), 6, -0.9, 0.9)
		"dots":
			for x in [-6, 0, 6]:
				ci.draw_circle(c + Vector2(x, 0) * k, 1.8 * k, col)
		"menu":
			for y in [-6, 0, 6]:
				line.call([Vector2(-8, y), Vector2(8, y)])
		"drop":
			line.call([Vector2(0, -9), Vector2(0, 3)])
			line.call([Vector2(-5, -2), Vector2(0, 3), Vector2(5, -2)])
			line.call([Vector2(-8, 8), Vector2(8, 8)])
		"give":
			line.call([Vector2(-9, 5), Vector2(-3, 5), Vector2(2, 2), Vector2(8, 2)])
			line.call([Vector2(-9, 9), Vector2(6, 9), Vector2(9, 6)])
			line.call([Vector2(-2, -8), Vector2(6, -8)])
			line.call([Vector2(3, -11), Vector2(6, -8), Vector2(3, -5)])
		"use":
			ring.call(Vector2.ZERO, 8, -PI * 0.35, PI * 1.35)
			line.call([Vector2(0, -10), Vector2(0, -2)])
		_:
			ci.draw_circle(c, 3 * k, col)
