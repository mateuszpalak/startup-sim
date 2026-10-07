## A container opened with E - the fridge, the kitchen cupboard, the
## dishwasher, the first-aid cabinet, the storeroom, the bar: its slots next
## to the player's own things (hands, pockets). Drag a thing from one to the
## other (or click it) to take it out / put it in; Esc or walking away
## closes it.
extends Control

const Ink = preload("res://ui/ink_ui.gd")
const Touch = preload("res://touch/touch.gd")
const ItemArt = preload("res://game/item_art.gd")
const Protocol = preload("res://net/protocol.gd")

## ContainerAction to send (take: `arg` = slot, `kind`; put: `arg` =
## inventory slot, 0 = hands).
signal action(which: int, action: int, arg: int, kind: int)
signal closed

const TITLES := {
	Protocol.CONTAINER_FRIDGE: "Lodówka", Protocol.CONTAINER_CUPBOARD: "Szafka kuchenna",
	Protocol.CONTAINER_DISHWASHER: "Zmywarka", Protocol.CONTAINER_CABINET: "Apteczka",
	Protocol.CONTAINER_STOREROOM: "Magazynek", Protocol.CONTAINER_BAR: "Barek", Protocol.CONTAINER_BIN: "Kosz na śmieci"}
const SLOT := Vector2(72, 72)
const COLUMNS := 6

var which := 0
var state := {}            # the last Container packet
var inventory: Array = []  # [{kind, id, label}]: hands first, then pockets
var _panel := PanelContainer.new()
var _title := Label.new()
var _info := Label.new()
var _grid := GridContainer.new()
var _inv := HBoxContainer.new()
var _buttons := HBoxContainer.new()
var _caption := Label.new()
var _sig := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel.add_theme_stylebox_override("panel", Ink.box("paper"))
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)
	Ink.style_label(_title, 24, Ink.TEXT_INK)
	col.add_child(_title)
	Ink.style_label(_info, 15, Ink.TEXT_MUTED)
	col.add_child(_info)
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	col.add_child(_drop_area(_grid, "inv"))
	col.add_child(Ink.label("Twoje rzeczy", 16, Ink.TEXT_INK))
	_inv.add_theme_constant_override("separation", 6)
	col.add_child(_drop_area(_inv, "box"))
	Ink.style_label(_caption, 15, Ink.TEXT_INK)
	_caption.custom_minimum_size = Vector2(0, 22)
	col.add_child(_caption)
	_buttons.add_theme_constant_override("separation", 8)
	col.add_child(_buttons)
	col.add_child(Ink.label(Touch.say("Przeciągnij myszką (albo kliknij), żeby wyjąć lub włożyć · Esc zamknij", "Stuknij albo przeciągnij palcem, żeby wyjąć lub włożyć"), 14, Ink.TEXT_MUTED))
	_panel.resized.connect(_place)
	get_viewport().size_changed.connect(_place)


func _place() -> void:
	var vs := get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	_panel.reset_size()
	_panel.position = ((vs - _panel.size) / 2).floor()
	Touch.place_center(_panel, get_viewport())


## `inner` taking drops of things dragged from `from` ("box" / "inv").
func _drop_area(inner: Control, from: String) -> Control:
	var area := PanelContainer.new()
	area.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	area.add_child(inner)
	area.set_drag_forwarding(Callable(), func(_at, data): return data is Dictionary and data.get("from") == from, _drop)
	return area


func show_container(p: Dictionary) -> void:
	which = p.which
	state = p
	_title.text = TITLES.get(which, "Szafka")
	_info.text = _info_text()
	_fill()
	visible = true
	_place.call_deferred()


## Hands / pockets changed (the window shows them too).
func set_inventory(slots: Array) -> void:
	inventory = slots
	if visible:
		_fill()


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func _info_text() -> String:
	match which:
		Protocol.CONTAINER_FRIDGE:
			return "Mleko do kawy: %d porcji · firmowa woda i sok co rano nowe" % state.milk
		Protocol.CONTAINER_CUPBOARD:
			return "Czyste kubki i noże — odkłada się tu czyste"
		Protocol.CONTAINER_BIN:
			return "Wyrzuć, co niepotrzebne (fusy, resztki…) · opróżniany przy sprzątaniu"
		Protocol.CONTAINER_DISHWASHER:
			if state.minutes > 0:
				return "Myje… jeszcze %d min" % state.minutes
			return "Brudne kubki do środka, potem „Włącz”"
	return "Uzupełniane co rano"


func _count(kind: int) -> int:
	for s in state.get("slots", []):
		if s.kind == kind:
			return s.count
	return 0


func _fill() -> void:
	# Refreshed every second: rebuilt only when something changed (a drag
	# in progress keeps its slot).
	var sig := JSON.stringify([which, state, inventory])
	if sig == _sig:
		return
	_sig = sig
	for c in _grid.get_children() + _inv.get_children() + _buttons.get_children():
		c.queue_free()
	var slots: Array = state.get("slots", [])
	for i in maxi(slots.size(), state.get("capacity", 0)):
		var s: Dictionary = slots[i] if i < slots.size() else {"kind": 0, "count": 0, "label": ""}
		_grid.add_child(_slot(s.kind, s.count, s.label, "box", i))
	for i in 4:
		var s: Dictionary = inventory[i] if i < inventory.size() else {"kind": 0, "label": ""}
		var label: String = ("%s — %s" % [ItemArt.item_name(s.kind), s.label]) if s.label != "" else ItemArt.item_name(s.kind)
		_inv.add_child(_slot(s.kind, 1, label if s.kind != 0 else ("Ręce — puste" if i == 0 else "Kieszeń %d — pusta" % i), "inv", i))
	var held: int = inventory[0].kind if not inventory.is_empty() else 0
	match which:
		Protocol.CONTAINER_FRIDGE:
			_button("Dolej mleka do kawy", Protocol.CONTAINER_MILK, state.milk > 0 and held == ItemArt.COFFEE)
		Protocol.CONTAINER_DISHWASHER:
			var idle: bool = state.minutes == 0
			_button("Włącz", Protocol.CONTAINER_START, idle and _count(ItemArt.EMPTY_CUP) > 0 and _count(ItemArt.CUP) == 0)
			_button("Rozładuj do szafki", Protocol.CONTAINER_UNLOAD, idle and _count(ItemArt.CUP) > 0)
	var close_b := Ink.button("Zamknij")
	close_b.focus_mode = Control.FOCUS_NONE
	close_b.pressed.connect(close)
	_buttons.add_child(close_b)


func _button(text: String, act: int, enabled: bool) -> void:
	var b := Ink.button(text, true)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not enabled
	b.pressed.connect(func(): action.emit(which, act, 0, 0))
	_buttons.add_child(b)


## One slot: a thing (with how many), draggable to the other side; a click
## moves it too.
func _slot(kind: int, count: int, label: String, from: String, index: int) -> Control:
	var box := Control.new()
	box.custom_minimum_size = SLOT
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.tooltip_text = label
	box.draw.connect(func(): _draw_slot(box, kind, count, from, index))
	box.mouse_entered.connect(func():
		box.set_meta("hover", true)
		_caption.text = label if kind != 0 else ""
		box.queue_redraw())
	box.mouse_exited.connect(func():
		box.set_meta("hover", false)
		box.queue_redraw())
	var data := {"from": from, "index": index, "kind": kind}
	var movable := kind != 0 and count > 0
	box.set_drag_forwarding(func(_at):
		if not movable:
			return null
		set_drag_preview(_preview(kind))
		return data,
		func(_at, d): return d is Dictionary and d.get("from") != from,
		_drop)
	box.gui_input.connect(func(ev):
		if movable and ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			_move(data))
	return box


func _draw_slot(box: Control, kind: int, count: int, from: String, index: int) -> void:
	var hover: bool = box.get_meta("hover", false) and kind != 0
	Ink.box("slot_active" if hover else "slot").draw(box.get_canvas_item(), Rect2(Vector2.ZERO, box.size))
	if kind != 0:
		ItemArt.draw(box, kind, Vector2(10, 8), (box.size.x - 20) / 16.0)
		if count == 0:  # none left: a faded picture
			box.draw_rect(Rect2(Vector2(4, 4), box.size - Vector2(8, 8)), Color(Ink.PAPER_HI, 0.65))
	var f := Ink.font()
	if from == "inv":
		var cap := "ręce" if index == 0 else str(index)
		box.draw_string_outline(f, Vector2(6, box.size.y - 6), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Ink.INK)
		box.draw_string(f, Vector2(6, box.size.y - 6), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Ink.GOLD)
	elif kind != 0 and (count != 1 or which not in [Protocol.CONTAINER_FRIDGE, Protocol.CONTAINER_BIN]):
		var n := "×%d" % count
		var at := Vector2(box.size.x - 8 - f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, box.size.y - 6)
		box.draw_string_outline(f, at, n, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Ink.INK)
		box.draw_string(f, at, n, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Ink.GOLD)


func _preview(kind: int) -> Control:
	var c := Control.new()
	c.size = SLOT
	c.draw.connect(func(): ItemArt.draw(c, kind, Vector2(-SLOT.x / 2 + 10, -SLOT.y / 2 + 8), (SLOT.x - 20) / 16.0))
	return c


func _drop(_at: Vector2, data: Variant) -> void:
	_move(data)


## A thing dragged (or clicked) out of where it is: from the container into
## the pockets / hands, or the other way.
func _move(data: Dictionary) -> void:
	if data.from == "box":
		action.emit(which, Protocol.CONTAINER_TAKE, data.index, data.kind)
	else:
		action.emit(which, Protocol.CONTAINER_PUT, data.index, 0)


## Take slot `i` (tests / keys): like a click on it.
func take(i: int) -> void:
	var slots: Array = state.get("slots", [])
	if i < slots.size():
		_move({"from": "box", "index": i, "kind": slots[i].kind})


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
