## The coffee machine's panel (E at it), in the middle of the screen: the
## machine drawn with its water tank and grounds drawer, and its buttons -
## brew (into the clean mug in your hands), top the water up, empty the
## grounds (into your hands - then into the kitchen bin). 1-3 or a click;
## Esc or walking away closes it.
extends Control

const Kit = preload("res://ui/ui_kit.gd")
const ItemArt = preload("res://game/item_art.gd")
const Protocol = preload("res://net/protocol.gd")

## CoffeeAction to send (machine, action).
signal action(machine: int, action: int)
signal closed

var state := {}  # the last CoffeeMachine packet
var held := 0    # what's in our hands (ItemArt kind)
var _panel := PanelContainer.new()
var _art := Control.new()
var _status := Label.new()
var _hint := Label.new()
var _brew: Button
var _water: Button
var _empty: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel.add_theme_stylebox_override("panel", Kit.box("paper"))
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_panel.add_child(row)
	_art.custom_minimum_size = Vector2(190, 250)
	_art.draw.connect(_draw_machine)
	row.add_child(_art)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(270, 0)
	row.add_child(col)
	col.add_child(Kit.label("Ekspres do kawy", 24, Kit.TEXT_INK))
	Kit.style_label(_status, 17, Kit.TEXT_INK)
	col.add_child(_status)
	Kit.style_label(_hint, 15, Kit.TEXT_MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(270, 0)
	col.add_child(_hint)
	_brew = _button(col, "1   Zaparz kawę", Protocol.COFFEE_BREW, true)
	_water = _button(col, "2   Dolej wody", Protocol.COFFEE_WATER)
	_empty = _button(col, "3   Wyrzuć fusy", Protocol.COFFEE_EMPTY_GROUNDS)
	var close_b := Kit.button("Zamknij (Esc)")
	close_b.focus_mode = Control.FOCUS_NONE
	close_b.pressed.connect(close)
	col.add_child(close_b)
	_panel.resized.connect(_place)
	get_viewport().size_changed.connect(_place)


func _button(col: Control, text: String, act: int, primary := false) -> Button:
	var b := Kit.button(text, primary)
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func(): _press(act))
	col.add_child(b)
	return b


func _place() -> void:
	var vs := get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	_panel.reset_size()
	_panel.position = ((vs - _panel.size) / 2).floor()


func show_machine(p: Dictionary) -> void:
	state = p
	_refresh()
	visible = true
	_place.call_deferred()


## What's in hands changed (the brew button depends on the mug).
func set_held(k: int) -> void:
	held = k
	if visible:
		_refresh()


func _refresh() -> void:
	var mx: int = maxi(state.get("max", 8), 1)
	var water: int = state.get("water", 0)
	var grounds: int = state.get("grounds", 0)
	var busy: int = state.get("busy", 0)
	_status.text = "Woda: %d/%d kaw  ·  fusy: %d/%d" % [water, mx, grounds, mx]
	if busy > 0:
		_hint.text = "Parzy się… jeszcze %d s." % busy
	elif water == 0:
		_hint.text = "Zbiornik pusty — dolej wody."
	elif grounds >= mx:
		_hint.text = "Pojemnik na fusy pełny — wyrzuć fusy (do kosza w kuchni)."
	elif held == ItemArt.CUP:
		_hint.text = "Czysty kubek w rękach — można parzyć."
	elif held == ItemArt.EMPTY_CUP:
		_hint.text = "Ten kubek jest brudny — umyj go albo weź czysty z szafki."
	else:
		_hint.text = "Najpierw czysty kubek z szafki obok."
	_brew.disabled = busy > 0
	_water.disabled = water >= mx
	_empty.disabled = grounds == 0
	_art.queue_redraw()


func _press(act: int) -> void:
	if visible and not state.is_empty():
		action.emit(state.machine, act)


func close() -> void:
	if visible:
		visible = false
		closed.emit()


## The machine: body, the water tank (left, see-through, its level), the
## spout with a mug under it while it brews, the grounds drawer below.
func _draw_machine() -> void:
	var c := _art
	var mx := float(maxi(state.get("max", 8), 1))
	var water := float(state.get("water", 0)) / mx
	var grounds := float(state.get("grounds", 0)) / mx
	var busy: int = state.get("busy", 0)
	var body := Rect2(18, 10, 154, 230)
	c.draw_rect(body.grow(3), Kit.INK)
	c.draw_rect(body, Color("#2f2f36"))
	c.draw_rect(Rect2(body.position + Vector2(8, 8), Vector2(body.size.x - 16, 26)), Color("#45454f"))
	# A little display.
	c.draw_rect(Rect2(98, 22, 60, 14), Color("#9fb98c"))
	c.draw_string(Kit.font(), Vector2(102, 34), ("%d s" % busy) if busy > 0 else "OK", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#1f2a17"))
	# The water tank.
	var tank := Rect2(28, 48, 40, 120)
	c.draw_rect(tank.grow(2), Kit.INK)
	c.draw_rect(tank, Color("#cfe4ef", 0.5))
	var h := tank.size.y * water
	c.draw_rect(Rect2(tank.position.x, tank.end.y - h, tank.size.x, h), Color("#4f8fc0"))
	for k in 3:
		c.draw_line(Vector2(tank.end.x - 8, tank.position.y + 30 * (k + 1)), Vector2(tank.end.x, tank.position.y + 30 * (k + 1)), Kit.INK, 1.5)
	# The spout and the drip tray.
	c.draw_rect(Rect2(108, 52, 34, 16), Color("#8b8f98"))
	c.draw_rect(Rect2(118, 68, 14, 12), Color("#5d6068"))
	c.draw_rect(Rect2(86, 168, 78, 8), Color("#5d6068"))
	if busy > 0:
		ItemArt.draw(c, ItemArt.COFFEE, Vector2(101, 108), 3.0)
		for k in 3:  # steam
			var x := 110.0 + k * 9.0
			var t := Time.get_ticks_msec() / 200.0 + k
			c.draw_line(Vector2(x + sin(t) * 2, 104), Vector2(x + sin(t + 1) * 2, 88), Color(1, 1, 1, 0.6), 2.0, true)
		c.draw_line(Vector2(125, 80), Vector2(125, 110), Color("#6b3d1f"), 3.0)
	# The grounds drawer.
	var drawer := Rect2(28, 188, 136, 40)
	c.draw_rect(drawer.grow(2), Kit.INK)
	c.draw_rect(drawer, Color("#45454f"))
	var gw := (drawer.size.x - 8) * grounds
	c.draw_rect(Rect2(drawer.position + Vector2(4, 14), Vector2(gw, drawer.size.y - 18)), Color("#5e4130"))
	c.draw_rect(Rect2(drawer.position.x + drawer.size.x / 2 - 14, drawer.position.y + 4, 28, 6), Color("#8b8f98"))


func _process(_delta: float) -> void:
	if visible and state.get("busy", 0) > 0:
		_art.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE:
			close()
		KEY_1:
			_press(Protocol.COFFEE_BREW)
		KEY_2:
			_press(Protocol.COFFEE_WATER)
		KEY_3:
			_press(Protocol.COFFEE_EMPTY_GROUNDS)
		_:
			return
	get_viewport().set_input_as_handled()
