## The pad's focus ring: works over any window without it being written
## for a pad. It finds what can be pressed in the window (`root`): buttons,
## text fields, sliders, choice lists and controls that take clicks;
## the d-pad / stick moves to the nearest one that way, A presses it (the
## button's own signals, a click for click-only controls, the on-screen
## keyboard for a text field), left / right change a slider or a choice.
## A control with the meta "pad_default" gets the ring first, "pad_press"
## (a Callable) runs instead of a press, "pad_skip" is never focused.
extends Control

const Kit = preload("res://ui/ui_kit.gd")

var pad: Node = null  # pad.gd
var root: Node = null
var target: Control = null
var _last_center := Vector2(-1, -1)
var _remember := {}  # root instance id -> its last target (back to it on return)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func set_root(r: Node) -> void:
	if r != root:
		if root and is_instance_valid(root) and _valid(target):
			_remember[root.get_instance_id()] = target
		root = r
		target = null
		if r:
			var t = _remember.get(r.get_instance_id())
			if t and is_instance_valid(t) and _valid(t) and _in_root(t):
				target = t
	if root and not _valid(target):
		_pick_default()


func has_candidates(r: Node) -> bool:
	var out: Array = []
	_collect(r, out, true)
	return not out.is_empty()


func candidates() -> Array:
	var out: Array = []
	if root and is_instance_valid(root):
		_collect(root, out, false)
	return out


## Walks the tree (children first: a control that only takes clicks counts
## only when nothing inside it does).
func _collect(n: Node, out: Array, first_only: bool) -> bool:
	if n is Window:
		return false
	if (n is CanvasItem and not n.visible) or (n is CanvasLayer and not n.visible):
		return false
	if n.has_meta("pad_skip"):
		return false
	var added := false
	for ch in n.get_children():
		if _collect(ch, out, first_only):
			added = true
			if first_only:
				return true
	if n is Control and _interactive(n, added) and _on_screen(n):
		out.append(n)
		added = true
	return added


static func _interactive(c: Control, has_inner: bool) -> bool:
	if c.has_meta("pad_press") or c.has_meta("pad_focus"):
		return true
	if c is BaseButton:
		return not c.disabled and c.mouse_filter != Control.MOUSE_FILTER_IGNORE
	if c is LineEdit:
		return c.editable and not (c.get_parent() is SpinBox)
	if c is TextEdit:
		return c.editable
	if c is Slider or c is SpinBox:
		return c.editable
	if has_inner or c.mouse_filter != Control.MOUSE_FILTER_STOP:
		return false
	return not c.gui_input.get_connections().is_empty()


func _on_screen(c: Control) -> bool:
	var r := vrect(c)
	if r.size.x < 2 or r.size.y < 2:
		return false
	if _scroll_of(c):
		return true
	return get_viewport_rect().intersects(r)


## A control's rectangle on the screen (canvas units, with its layer).
static func vrect(c: Control) -> Rect2:
	var xf := c.get_global_transform_with_canvas()
	return Rect2(xf.origin, c.size * xf.get_scale())


func _valid(c) -> bool:
	if c == null or not is_instance_valid(c) or not c.is_inside_tree() or not c.is_visible_in_tree():
		return false
	return _interactive(c, false)


func _in_root(c: Node) -> bool:
	return root != null and is_instance_valid(root) and (root == c or root.is_ancestor_of(c))


func _pick_default() -> void:
	var cands := candidates()
	target = null
	if cands.is_empty():
		return
	for c in cands:
		if c.has_meta("pad_default"):
			_focus(c)
			return
	var fo := get_viewport().gui_get_focus_owner()
	if fo in cands:
		_focus(fo)
		return
	if _last_center.x >= 0:
		_focus(_nearest(cands, _last_center))
		return
	cands.sort_custom(func(a, b):
		var ra := vrect(a)
		var rb := vrect(b)
		return ra.position.y < rb.position.y - 4 or (absf(ra.position.y - rb.position.y) <= 4 and ra.position.x < rb.position.x))
	_focus(cands[0])


func _nearest(cands: Array, p: Vector2) -> Control:
	var best: Control = cands[0]
	var bd := INF
	for c in cands:
		var d := vrect(c).get_center().distance_squared_to(p)
		if d < bd:
			bd = d
			best = c
	return best


func _focus(c: Control) -> void:
	target = c
	if c == null:
		return
	_last_center = vrect(c).get_center()
	var p := c.get_parent()
	while p:
		if p is ScrollContainer:
			p.ensure_control_visible(c)
		p = p.get_parent()


## One step of the d-pad / stick: the nearest control that way (none:
## scroll that way).
func move(dir: Vector2) -> void:
	if not _valid(target):
		_pick_default()
		return
	var from := vrect(target)
	var fc := from.get_center()
	var best: Control = null
	var best_score := INF
	for c in candidates():
		if c == target:
			continue
		var r := vrect(c)
		var delta := r.get_center() - fc
		var along := delta.dot(dir)
		if along <= 2.0:
			continue
		var perp := absf(delta.dot(Vector2(-dir.y, dir.x)))
		# Side by side (overlapping across the move): no sideways penalty.
		if dir.x == 0 and r.position.x < from.end.x and r.end.x > from.position.x:
			perp = 0.0
		if dir.y == 0 and r.position.y < from.end.y and r.end.y > from.position.y:
			perp = 0.0
		var score := along + perp * 2.5
		if score < best_score:
			best_score = score
			best = c
	if best:
		_focus(best)
	elif dir.y != 0:
		scroll(dir.y * 120.0)


## Left / right on a slider or a choice list: change it (true = done).
func adjust(sign: int) -> bool:
	if not _valid(target):
		return false
	if target is OptionButton:
		_cycle(target, sign)
		return true
	if target is Slider or target is SpinBox:
		var r: Range = target
		var step := maxf(r.step, (r.max_value - r.min_value) / 20.0)
		if target is SpinBox:
			step = maxf(r.step, 1.0)
		r.value = clampf(r.value + sign * step, r.min_value, r.max_value)
		return true
	return false


static func _cycle(o: OptionButton, sign: int) -> void:
	if o.item_count == 0:
		return
	var i := posmod(o.selected + sign, o.item_count)
	o.select(i)
	o.item_selected.emit(i)


## A: press the focused control.
func activate() -> void:
	if not _valid(target):
		_pick_default()
		return
	var c := target
	if c.has_meta("pad_press"):
		(c.get_meta("pad_press") as Callable).call()
	elif c is OptionButton:
		_cycle(c, 1)
	elif c is BaseButton:
		var b: BaseButton = c
		if b.toggle_mode:
			if not (b.button_pressed and b.button_group):
				b.button_pressed = not b.button_pressed
		b.button_down.emit()
		b.pressed.emit()
		b.button_up.emit()
	elif c is LineEdit or c is TextEdit:
		c.grab_focus()
		pad.keyboard.open_for(c)
	elif not (c is Range):
		for down in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = down
			ev.position = c.size / 2
			ev.global_position = vrect(c).get_center()
			ev.device = 7777
			c.gui_input.emit(ev)
	queue_redraw()


## The right stick: scroll the list the ring is in (or the window's first).
func scroll(px: float) -> void:
	var sc: ScrollContainer = _scroll_of(target) if _valid(target) else null
	if sc == null and root and is_instance_valid(root):
		sc = _find_scroll(root)
	if sc:
		sc.scroll_vertical += int(px)


## LB / RB: a page up / down.
func page(sign: int) -> void:
	scroll(sign * 360.0)


static func _scroll_of(c: Node) -> ScrollContainer:
	var p := c.get_parent() if c else null
	while p:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null


static func _find_scroll(n: Node) -> ScrollContainer:
	if n is CanvasItem and not n.visible:
		return null
	if n is ScrollContainer:
		return n
	for ch in n.get_children():
		var s := _find_scroll(ch)
		if s:
			return s
	return null


func _process(_d: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if not _valid(target):
		return
	var r := vrect(target).grow(4)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 0.8)
	Kit.draw_rrect(self, r.grow(3), Color(0, 0, 0, 0), 14, Color(Kit.ACCENT, 0.25 + 0.2 * pulse), 3)
	Kit.draw_rrect(self, r, Color(0, 0, 0, 0), 11, Kit.ACCENT, 3)
