## Scrubbing a toilet with the brush (E at a toilet with a skid mark): the
## bowl seen from above with brown smears; hold the left mouse button and
## scrub them away. Clean = the server is told (`Action` SCRUB); Esc gives up.
extends Control

const Kit = preload("res://ui/ui_kit.gd")

signal scrubbed

const AREA := Vector2(380, 300)
## How far the brush reaches (px) and how much rubbing a smear takes.
const BRUSH := 26.0
const RUB_PER_PX := 0.0045

var _panel := PanelContainer.new()
var _area := Control.new()
var _info := Label.new()
var _smears: Array = []  # [{pos: Vector2, r: float, dirt: float}]
var _mouse := Vector2(-100, -100)
var _done_at := -1.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel.add_theme_stylebox_override("panel", Kit.box("paper"))
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)
	col.add_child(Kit.label("Szorowanie sedesu", 24, Kit.TEXT_INK))
	col.add_child(Kit.label("Trzymaj lewy przycisk myszy i szoruj smugi szczotką · Esc — odpuść", 15, Kit.TEXT_MUTED))
	_area.custom_minimum_size = AREA
	_area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_area.draw.connect(_draw_bowl)
	_area.gui_input.connect(_on_input)
	_area.mouse_exited.connect(func():
		_mouse = Vector2(-100, -100)
		_area.queue_redraw())
	col.add_child(_area)
	Kit.style_label(_info, 17, Kit.TEXT_INK)
	col.add_child(_info)
	get_viewport().size_changed.connect(_place)


func _place() -> void:
	var vs := get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	_panel.reset_size()
	_panel.position = ((vs - _panel.size) / 2).floor()


func start() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_smears.clear()
	var c := AREA / 2
	for i in 6:
		# On the bowl's slope: between the water and the rim.
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.62, 0.85)
		_smears.append({"pos": c + Vector2(cos(a) * 120 * d, sin(a) * 95 * d), "r": rng.randf_range(9, 15), "dirt": 1.0})
	_done_at = -1.0
	visible = true
	_update_info()
	_place.call_deferred()


## Every smear gone (tests; the same as scrubbing it all).
func finish() -> void:
	for s in _smears:
		s.dirt = 0.0
	_check_done()


func _on_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var from := _mouse
		_mouse = ev.position
		if ev.button_mask & MOUSE_BUTTON_MASK_LEFT and _done_at < 0.0 and from.x >= 0:
			var rubbed := from.distance_to(_mouse)
			for s in _smears:
				if s.dirt > 0.0 and s.pos.distance_to(_mouse) <= BRUSH + s.r:
					s.dirt = maxf(0.0, s.dirt - rubbed * RUB_PER_PX * (BRUSH / (BRUSH + s.r)) * 3.0)
			_check_done()
		_area.queue_redraw()


func _check_done() -> void:
	_update_info()
	_area.queue_redraw()
	if _done_at < 0.0 and _smears.all(func(s): return s.dirt <= 0.0):
		_done_at = _t


func _update_info() -> void:
	var total := 0.0
	for s in _smears:
		total += s.dirt
	var clean := 100 - int(round(100.0 * total / maxf(_smears.size(), 1)))
	_info.text = "Czyściutko!" if _done_at >= 0.0 or clean >= 100 else "Czysto w %d%%" % clean


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _done_at >= 0.0 and _t - _done_at > 0.7:
		visible = false
		scrubbed.emit()


## The bowl from above: the seat, the slope, a bit of water; the smears;
## the brush where the mouse is.
func _draw_bowl() -> void:
	var c := AREA / 2
	_oval(c + Vector2(0, 10), Vector2(160, 128), Color(0, 0, 0, 0.1))
	_oval(c, Vector2(158, 126), Color("#d8dde2"))
	_oval(c + Vector2(0, -2), Vector2(155, 122), Color("#ffffff"))
	_oval(c, Vector2(128, 100), Color("#c9d1d8"))
	_oval(c + Vector2(0, 3), Vector2(125, 96), Color("#eef2f4"))
	_oval(c + Vector2(0, 12), Vector2(62, 44), Color("#a9cbd8"))
	for s in _smears:
		if s.dirt <= 0.0:
			continue
		var col := Color("#6b4423", 0.25 + 0.75 * s.dirt)
		_area.draw_circle(s.pos, s.r * (0.5 + 0.5 * s.dirt), col)
		_area.draw_line(s.pos - Vector2(s.r, 2), s.pos + Vector2(s.r * 0.8, 4), col, 4.0 * s.dirt + 1.0, true)
	if _mouse.x >= 0:
		# The brush: a handle and the bristles.
		var head := _mouse
		_area.draw_line(head + Vector2(10, -10), head + Vector2(46, -58), Kit.ACCENT_LO, 7.0, true)
		_area.draw_line(head + Vector2(10, -10), head + Vector2(46, -58), Kit.ACCENT, 4.0, true)
		_area.draw_circle(head + Vector2(0, 3), 15.0, Color(0, 0, 0, 0.15), true, -1.0, true)
		_area.draw_circle(head, 14.0, Kit.TEAL, true, -1.0, true)
		for k in 8:
			var a := TAU * k / 8.0
			_area.draw_line(head + Vector2.from_angle(a) * 6, head + Vector2.from_angle(a) * 16, Color("#2b7d71"), 2.0, true)


func _oval(at: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 48:
		var a := TAU * k / 48.0
		pts.append(at + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	_area.draw_colored_polygon(pts, color)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		visible = false
		get_viewport().set_input_as_handled()
