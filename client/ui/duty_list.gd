## Today's duties (top left, under the clock): what is left, where, and the
## week's goal. A click folds it to the header.
extends PanelContainer

const Ink = preload("res://ui/ink_ui.gd")
const Movement = preload("res://sim/movement.gd")
const Protocol = preload("res://net/protocol.gd")
const Touch = preload("res://touch/touch.gd")

const REACH_PX := 24.0
const SNOOZE_MS := 10000

var duties: Array = []
var week_done := 0
var week_goal := 0
var floor_now := 0
var floor_name: Callable = func(f: int) -> String: return "piętro %d" % f
var room_of: Callable = func(_f: int, _x: int, _y: int) -> String: return ""
var below: Control
var folded := false
var _snoozed := {}  # "floor:x:y" -> until (ms)
var _rows := VBoxContainer.new()
var _head := Label.new()


func _ready() -> void:
	add_theme_stylebox_override("panel", Ink.box("hud"))
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_rows.add_theme_constant_override("separation", 2)
	add_child(_rows)
	Ink.style_label(_head, 17, Ink.GOLD)
	gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			folded = not folded
			_render())


func _process(_delta: float) -> void:
	if below and visible:
		var touch_row := 64.0 if Touch.active else 0.0  # the menu / chat / log buttons sit under the clock
		position = Vector2(below.position.x, below.position.y + below.size.y + 8 + touch_row)


func on_duties(p: Dictionary) -> void:
	duties = p.duties
	week_done = p.week_done
	week_goal = p.week_goal
	visible = not duties.is_empty()
	_render()


func set_floor(f: int) -> void:
	if f != floor_now:
		floor_now = f
		_render()


func left() -> int:
	return duties.filter(func(d): return d.state == Protocol.DUTY_TODO).size()


## Put off (Esc in its minigame): no hint there for a while, like the server.
func snooze_near(floor_id: int, pos: Vector2i) -> void:
	var d := _nearest(floor_id, pos)
	if not d.is_empty():
		_snoozed["%d:%d:%d" % [d.floor, d.x, d.y]] = Time.get_ticks_msec() + SNOOZE_MS


## "[E] <title>" when an open duty's place is in reach, else "".
func hint_at(floor_id: int, pos: Vector2i) -> String:
	var d := _nearest(floor_id, pos)
	return "" if d.is_empty() else "[E] %s" % d.title


func _nearest(floor_id: int, pos: Vector2i) -> Dictionary:
	var me := Movement.to_px(pos)
	var now := Time.get_ticks_msec()
	var best := {}
	var best_d := REACH_PX
	for d in duties:
		if d.state != Protocol.DUTY_TODO or d.floor != floor_id or _snoozed.get("%d:%d:%d" % [d.floor, d.x, d.y], 0) > now:
			continue
		var dist := Movement.to_px(Movement.tile_center(d.x, d.y)).distance_to(me)
		if dist <= best_d:
			best_d = dist
			best = d
	return best


func _render() -> void:
	for c in _rows.get_children():
		if c != _head:
			_rows.remove_child(c)
			c.queue_free()
	if _head.get_parent() == null:
		_rows.add_child(_head)
	_head.text = "Obowiązki dnia: %d/%d %s" % [duties.size() - left(), duties.size(), "▸" if folded else "▾"]
	if folded:
		reset_size()
		return
	for d in duties:
		var mark := "○"
		var color := Ink.TEXT
		if d.state == Protocol.DUTY_DONE:
			mark = "✓"
			color = Ink.TEXT_DIM
		elif d.state == Protocol.DUTY_BOTCHED:
			mark = "✗"
			color = Ink.TEXT_DIM
		var where := ""
		if d.state == Protocol.DUTY_TODO:
			var room: String = room_of.call(d.floor, d.x, d.y)
			where = " — %s" % room if room != "" else ""
			if d.floor != floor_now:
				where += " (%s)" % floor_name.call(d.floor)
		_rows.add_child(Ink.label("%s %s%s" % [mark, d.title, where], 15, color))
	if week_goal > 0:
		_rows.add_child(Ink.label("Tydzień: %d/%d" % [mini(week_done, week_goal), week_goal], 14, Ink.TEXT_DIM))
	size = Vector2.ZERO
	reset_size()
