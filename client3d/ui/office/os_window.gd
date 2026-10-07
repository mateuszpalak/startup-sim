## A window on the office computer's desktop: a title bar (drag it, X to
## close) and a body that holds one app.
extends PanelContainer

const Kit = preload("res://ui/ui_kit.gd")
const Touch = preload("res://touch/touch.gd")

signal closed
signal focused

var content := MarginContainer.new()
var draggable := true
var _title := Label.new()


func setup(title: String, body: Control, pad := 12) -> void:
	add_theme_stylebox_override("panel", Kit.box("window"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", Kit.box("window_bar"))
	col.add_child(bar)
	var row := HBoxContainer.new()
	bar.add_child(row)
	Kit.style_label(_title, 16, Kit.TEXT_INK)
	_title.add_theme_font_override("font", Kit.font_bold())
	_title.text = title
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = Touch.active
	row.add_child(_title)
	var x := Kit.icon_button("close", "Zamknij", true, 46.0 if Touch.active else 28.0)
	x.pressed.connect(func(): closed.emit())
	row.add_child(x)
	bar.gui_input.connect(_drag)
	gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed:
				focused.emit())
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		content.add_theme_constant_override("margin_" + side, pad)
	col.add_child(content)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Touch.active:
		# Small screens: an app wider / taller than the window scrolls
		# instead of pushing the window (and the monitor) off the screen.
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		sc.custom_minimum_size = Vector2(160, 120)
		content.add_child(sc)
		sc.add_child(body)
	else:
		content.add_child(body)


func set_title(t: String) -> void:
	_title.text = t


func _drag(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and ev.button_mask & MOUSE_BUTTON_MASK_LEFT and draggable:
		var p := get_parent() as Control
		position += ev.relative
		if p:  # keep the title bar on the screen
			position.x = clampf(position.x, -size.x + 80, p.size.x - 80)
			position.y = clampf(position.y, 0, p.size.y - 40)
	elif ev is InputEventMouseButton and ev.pressed:
		focused.emit()
