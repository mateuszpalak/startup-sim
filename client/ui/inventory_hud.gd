## Inventory bar (bottom centre, Don't Starve style): a dark wooden strip
## with the hands slot (bigger) and three pockets, keys 1-3 above the
## pockets, the name of what you hold above the bar.
## Keys: 1-3 take out / put back, Q drop, G give, F use (handled in game.gd).
extends Control

const ItemArt = preload("res://game/item_art.gd")
const Kit = preload("res://ui/ui_kit.gd")
const ItemIcons = preload("res://ui/item_icons.gd")

signal slot_clicked(pocket: int)

var slots: Array = []       # [{kind, id, label}] hands first, then pockets
var _boxes: Array[Control] = []
var _caption := Label.new()
var _keys := Label.new()
var _panel := PanelContainer.new()
var _hints := Control.new()
const HINTS := [["1–3", "wyjmij / schowaj"], ["Q", "upuść"], ["G", "podaj"], ["F", "użyj"]]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", Kit.box("hud"))
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(row)
	for i in 4:
		var box := Control.new()
		var hands := i == 0
		box.custom_minimum_size = Vector2(76, 76) if hands else Vector2(62, 62)
		box.size_flags_vertical = Control.SIZE_SHRINK_END
		var idx := i
		box.draw.connect(func(): _draw_slot(box, idx))
		box.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and idx > 0:
				slot_clicked.emit(idx - 1))
		row.add_child(box)
		_boxes.append(box)
		if hands:
			var sep := Control.new()
			sep.custom_minimum_size = Vector2(8, 0)
			sep.draw.connect(func(): sep.draw_line(Vector2(4, 10), Vector2(4, sep.size.y - 10), Color(Kit.DARK_HI, 0.9), 2.0, true))
			row.add_child(sep)
	# Caption above (a glass chip), key caps below the bar.
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_stylebox_override("normal", Kit.box("hud"))
	Kit.style_label(_caption, 16, Kit.TEXT)
	add_child(_caption)
	_keys.text = "1–3 wyjmij / schowaj  ·  Q upuść  ·  G podaj  ·  F użyj"
	_keys.visible = false  # the text (for tests); drawn as key caps
	add_child(_keys)
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints.draw.connect(func():
		var w := Kit.draw_key_hints(_hints, Vector2.ZERO, HINTS, 13, Kit.TEXT, true)
		var x := (_hints.size.x - w) / 2
		Kit.draw_rrect(_hints, Rect2(x - 10, -4, w + 20, 30), Color(Kit.DARK, 0.55), 15)
		Kit.draw_key_hints(_hints, Vector2(x, 0), HINTS, 13, Kit.TEXT))
	add_child(_hints)
	_panel.resized.connect(_place)
	get_viewport().size_changed.connect(_place)
	update_slots([])
	_place.call_deferred()


## Bottom centre of the viewport (the parent is a CanvasLayer).
func _place() -> void:
	var vs := get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	_panel.reset_size()
	_panel.position = Vector2((vs.x - _panel.size.x) / 2, vs.y - _panel.size.y - 30)
	_panel.position.y = vs.y - _panel.size.y - 40
	_hints.size = Vector2(vs.x, 24)
	_hints.position = Vector2(0, vs.y - 30)
	_hints.queue_redraw()
	_caption.reset_size()
	_caption.position = Vector2((vs.x - _caption.size.x) / 2, _panel.position.y - _caption.size.y - 8)


## Top of the bar (for placing hints above it).
func top() -> float:
	return _caption.position.y if _caption.visible else _panel.position.y


func update_slots(p_slots: Array) -> void:
	slots = p_slots
	for i in _boxes.size():
		var s := _slot(i)
		var name: String = ItemArt.item_name(s.kind)
		_boxes[i].tooltip_text = ("%s\n%s" % [name, s.label]) if s.kind != 0 else ("Ręce — puste" if i == 0 else "Kieszeń %d — pusta" % i)
		_boxes[i].queue_redraw()
	var held := _slot(0)
	if held.kind != 0:
		_caption.text = "W rękach: %s%s" % [ItemArt.item_name(held.kind), (" — " + held.label) if held.label != "" else ""]
	else:
		_caption.text = ""
	_caption.visible = _caption.text != ""
	_place()


func _slot(i: int) -> Dictionary:
	return slots[i] if i < slots.size() else {"kind": 0, "id": 0, "label": ""}


func _draw_slot(box: Control, i: int) -> void:
	var r := Rect2(Vector2.ZERO, box.size)
	var s := _slot(i)
	var active: bool = i == 0 and s.kind != 0
	Kit.draw_rrect(box, r, Color(1, 1, 1, 0.1) if s.kind != 0 else Color(0, 0, 0, 0.22), Kit.R_MD,
		Kit.GOLD if active else Color(1, 1, 1, 0.12), 3 if active else 1)
	if s.kind != 0:
		ItemIcons.draw(box, s.kind, r.grow(-6))
	var f := Kit.font_bold()
	var caption := "ręce" if i == 0 else str(i)
	if i == 0:
		box.draw_string(f, Vector2(0, box.size.y - 6), caption, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 12, Color(Kit.TEXT, 0.7))
	else:
		Kit.draw_rrect(box, Rect2(4, 4, 18, 18), Color(Kit.DARK, 0.8), 9)
		box.draw_string(f, Vector2(4, 18), caption, HORIZONTAL_ALIGNMENT_CENTER, 18, 12, Kit.GOLD)
