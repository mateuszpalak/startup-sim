## A door plaque read up close (E by a door): the name of the room behind it,
## big in the middle of the screen. Goes away with E / Esc or on walking off.
extends Control

const Ink = preload("res://ui/ink_ui.gd")

const PLATE := Color("#d9c27a")
const PLATE_LO := Color("#a88f4a")

var text := ""
var _plate := PanelContainer.new()
var _label := Label.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var box := StyleBoxFlat.new()
	box.bg_color = PLATE
	box.border_color = Ink.INK
	box.set_border_width_all(3)
	box.set_corner_radius_all(6)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 8
	box.shadow_offset = Vector2(3, 4)
	box.content_margin_left = 48
	box.content_margin_right = 48
	box.content_margin_top = 22
	box.content_margin_bottom = 22
	_plate.add_theme_stylebox_override("panel", box)
	_plate.custom_minimum_size = Vector2(360, 0)
	add_child(_plate)
	Ink.style_label(_label, 40, Ink.TEXT_INK)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate.add_child(_label)
	_plate.draw.connect(_screws)
	get_viewport().size_changed.connect(_place)


func open(room_name: String) -> void:
	text = room_name
	_label.text = room_name
	visible = true
	_place.call_deferred()


func close() -> void:
	visible = false
	text = ""


func _place() -> void:
	var vs := get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	_plate.reset_size()
	_plate.position = (vs - _plate.size) / 2


## Four screws in the corners and an engraved line.
func _screws() -> void:
	var s := _plate.size
	for c in [Vector2(14, 14), Vector2(s.x - 14, 14), Vector2(14, s.y - 14), Vector2(s.x - 14, s.y - 14)]:
		_plate.draw_circle(c, 4.0, PLATE_LO)
		_plate.draw_arc(c, 4.0, 0, TAU, 12, Ink.INK, 1.2, true)
		_plate.draw_line(c - Vector2(2.5, 2.5), c + Vector2(2.5, 2.5), Ink.INK, 1.0)
	_plate.draw_rect(Rect2(Vector2(8, 8), s - Vector2(16, 16)), Color(PLATE_LO, 0.8), false, 1.5)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
