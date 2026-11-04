## The in-game computer's own look ("StartOS"): a cheerful early-2000s
## desktop - glossy blue title bars and taskbar, a green start button, beige
## window bodies, white inputs with thin blue-grey borders, raised buttons
## with an orange glow on hover and a red close button, a plain system font.
## Same API as ui/ink_ui.gd (the parts the computer uses), so the desktop,
## the windows and the apps switch by preloading this instead.
extends RefCounted

const LINE := 1

const INK := Color("#003c74")           # borders of buttons, dark blue
const DARK := Color("#245edb")          # the taskbar's blue
const DARK_HI := Color("#3d86f0")
const DARK_LO := Color("#1941a5")
const PAPER := Color("#ece9d8")         # window bodies
const PAPER_HI := Color("#ffffff")
const PAPER_LO := Color("#d6d2c2")
const CARD := Color("#ffffff")
const CARD_LO := Color("#e8eef8")
const ACCENT := Color("#2f6fd6")        # primary actions, highlights
const ACCENT_HI := Color("#4f8ce8")
const ACCENT_LO := Color("#1c4fae")
const GOLD := Color("#f2b33d")
const RED := Color("#d9442a")
const GREEN := Color("#3a9a3a")
const TEXT := Color("#ffffff")          # text on blue
const TEXT_DIM := Color("#d8e4fb")
const TEXT_INK := Color("#1b1b1b")      # text on beige / white
const TEXT_MUTED := Color("#6d6d6d")

static var _font: SystemFont
static var _bold: SystemFont
static var _start: SystemFont
static var _theme: Theme
static var _boxes := {}


## A plain, readable system font (Tahoma first, like desktops of that era).
static func font() -> Font:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Tahoma", "Verdana", "Segoe UI", "DejaVu Sans", "Roboto", "Arial", "sans-serif"])
		_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font.hinting = TextServer.HINTING_LIGHT
	return _font


## The same font, bold (window titles).
static func bold() -> Font:
	if _bold == null:
		_bold = font().duplicate()
		_bold.font_weight = 700
	return _bold


## Bold italic, for the word on the start button.
static func start_font() -> Font:
	if _start == null:
		_start = font().duplicate()
		_start.font_weight = 700
		_start.font_italic = true
	return _start


## Sizes come from the hand-drawn kit (bigger letters); a system font reads
## smaller sizes fine.
static func fs(n: int) -> int:
	return maxi(13, int(round(n * 0.9)))


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 16
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(st, "Button", button_box(st, false))
		t.set_stylebox(st, "OptionButton", button_box(st, false))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		for c in ["Button", "OptionButton", "CheckBox", "CheckButton"]:
			t.set_color(k, c, TEXT_INK)
	t.set_color("font_disabled_color", "Button", TEXT_MUTED)
	for c in ["CheckBox", "CheckButton"]:
		for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
			t.set_stylebox(st, c, StyleBoxEmpty.new())
	for st in ["normal", "read_only"]:
		t.set_stylebox(st, "LineEdit", box("input"))
		t.set_stylebox(st, "TextEdit", box("input"))
	t.set_stylebox("focus", "LineEdit", box("input_focus"))
	t.set_stylebox("focus", "TextEdit", box("input_focus"))
	for c in ["LineEdit", "TextEdit", "SpinBox"]:
		t.set_color("font_color", c, TEXT_INK)
		t.set_color("font_placeholder_color", c, TEXT_MUTED)
		t.set_color("font_uneditable_color", c, Color(TEXT_INK, 0.7))
		t.set_color("caret_color", c, TEXT_INK)
		t.set_color("selection_color", c, Color("#316ac5", 0.45))
	t.set_stylebox("panel", "PanelContainer", box("paper"))
	t.set_stylebox("panel", "PopupMenu", box("menu"))
	t.set_color("font_color", "PopupMenu", TEXT_INK)
	t.set_color("font_hover_color", "PopupMenu", TEXT)
	t.set_stylebox("hover", "PopupMenu", box("menu_hover"))
	t.set_font("font", "PopupMenu", font())
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, box("scroll"))
		t.set_stylebox("grabber", bar, box("grabber"))
		t.set_stylebox("grabber_highlight", bar, box("grabber_hover"))
		t.set_stylebox("grabber_pressed", bar, box("grabber_hover"))
	t.set_color("font_color", "Label", TEXT_INK)
	for c in ["Label", "Button", "LineEdit", "TextEdit", "PopupMenu"]:
		t.set_font_size("font_size", c, 16)
	_theme = t
	return t


# ------------------------------------------------------------------ frames

## Named frames, the same names as the hand-drawn kit: paper (a window),
## title (its blue bar), hud (the taskbar), card / card_hover (white boxes in
## an app), input / input_focus, screen (the monitor), scroll / grabber, menu
## / menu_hover (the start menu); plus start (the green button) and task (a
## window's button on the taskbar), tray (the clock's corner) and balloon
## (a pale yellow notification).
static func box(kind: String) -> StyleBox:
	if _boxes.has(kind):
		return _boxes[kind]
	var sb: StyleBox
	match kind:
		"title":
			sb = _gradient([[0.0, "#3d95ff"], [0.12, "#0a5fe8"], [0.5, "#0054e3"], [0.85, "#0a66f2"], [1.0, "#0045cc"]],
				Color("#0831a8"), 1, 8, 0, 10, 5)
		"hud":
			sb = _gradient([[0.0, "#3c81f3"], [0.08, "#5a9bf5"], [0.2, "#2463dc"], [0.85, "#245edb"], [1.0, "#1941a5"]],
				Color(0, 0, 0, 0), 0, 0, 0, 4, 3)
		"start":
			sb = _gradient([[0.0, "#5fbf5a"], [0.15, "#3c9a3c"], [0.7, "#2f8a2f"], [1.0, "#226d22"]],
				Color("#1b5a1b"), 1, 4, 4, 12, 3, 14)
		"start_hover":
			sb = _gradient([[0.0, "#7ad375"], [0.15, "#4caa4c"], [0.7, "#38983a"], [1.0, "#2a7a2a"]],
				Color("#1b5a1b"), 1, 4, 4, 12, 3, 14)
		"task":
			sb = _gradient([[0.0, "#6aa7f8"], [0.5, "#3c81f3"], [1.0, "#2a66d6"]], Color("#1a4bb4"), 1, 3, 3, 10, 3)
		"task_hover":
			sb = _gradient([[0.0, "#8cbcfa"], [0.5, "#5a98f6"], [1.0, "#3a77e2"]], Color("#1a4bb4"), 1, 3, 3, 10, 3)
		"tray":
			sb = _gradient([[0.0, "#2fa8f5"], [0.1, "#1a93ec"], [0.9, "#0d8ae6"], [1.0, "#0b6fc4"]],
				Color("#0a5fb8"), 1, 0, 0, 10, 3)
		"balloon":
			sb = _flat(Color("#ffffe1"), Color("#1b1b1b"), 1, 8, 8, 12, 8)
		"paper":
			sb = _flat(PAPER, Color("#0a43d6"), 3, 9, 2, 0, 0)
		"card":
			sb = _flat(CARD, Color("#a5b8d6"), 1, 3, 3, 12, 10)
		"card_hover":
			sb = _flat(Color("#eef4fe"), Color("#7da2ce"), 1, 3, 3, 12, 10)
		"input":
			sb = _flat(PAPER_HI, Color("#7f9db9"), 1, 0, 0, 6, 3)
		"input_focus":
			sb = _flat(PAPER_HI, Color("#316ac5"), 1, 0, 0, 6, 3)
		"screen":
			sb = _flat(Color("#3a3f47"), Color("#22252b"), 4, 16, 16, 14, 14)
		"menu":
			sb = _flat(PAPER_HI, Color("#0a43d6"), 2, 4, 4, 6, 6)
		"menu_hover":
			sb = _flat(Color("#316ac5"), Color("#316ac5"), 0, 0, 0, 6, 2)
		"scroll":
			sb = _flat(Color("#f3f1ec"), Color("#e2dfd6"), 1, 0, 0, 2, 2)
		"grabber":
			sb = _flat(Color("#c8d6f5"), Color("#8fa9e0"), 1, 3, 3, 2, 2)
		"grabber_hover":
			sb = _flat(Color("#dde7fb"), Color("#6f8fd8"), 1, 3, 3, 2, 2)
		_:
			sb = box("paper")
	_boxes[kind] = sb
	return sb


static func button_box(state: String, primary: bool, danger := false) -> StyleBox:
	var key := "btn_%s_%s_%s" % [state, primary, danger]
	if _boxes.has(key):
		return _boxes[key]
	var sb: StyleBox
	if danger:  # the red close button
		var stops := [[0.0, "#f6a98f"], [0.35, "#e2603e"], [1.0, "#c13a1e"]]
		if state == "hover":
			stops = [[0.0, "#fbc1ad"], [0.35, "#ec7552"], [1.0, "#d04628"]]
		elif state == "pressed":
			stops = [[0.0, "#b8351b"], [1.0, "#e2603e"]]
		sb = _gradient(stops, Color("#ffffff", 0.9), 1, 3, 3, 8, 2)
	else:
		var stops := [[0.0, "#ffffff"], [0.6, "#f4f3ee"], [1.0, "#e3e0d0"]]
		var border := Color("#003c74")
		match state:
			"hover":
				border = Color("#e59a2b")  # the warm glow round a hovered button
			"pressed":
				stops = [[0.0, "#e3e0d0"], [1.0, "#f4f3ee"]]
			"disabled":
				stops = [[0.0, "#f4f3ee"], [1.0, "#f4f3ee"]]
				border = Color("#c9c7ba")
		if primary and state != "disabled" and state != "hover":
			border = Color("#2a62c9")
		sb = _gradient(stops, border, 2 if (primary or state == "hover") else 1, 3, 3, 12, 4)
	_boxes[key] = sb
	return sb


## A flat box: fill, border, corner radii (top, bottom), content padding.
static func _flat(fill: Color, border: Color, bw: int, rtop: int, rbot: int, pad: int, pad_v: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.corner_radius_top_left = rtop
	sb.corner_radius_top_right = rtop
	sb.corner_radius_bottom_left = rbot
	sb.corner_radius_bottom_right = rbot
	sb.anti_aliasing = true
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


## A box with a vertical gradient (stops: [offset, "#colour"]), a border,
## rounded top / bottom corners (the right ones `rright` if given: the start
## button's pill end) and content padding. Drawn into a small texture and
## stretched (the gradient scales with the height).
static func _gradient(stops: Array, border: Color, bw: int, rtop: int, rbot: int, pad: int, pad_v: int, rright := -1) -> StyleBoxTexture:
	var w := 48
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	g.colors = PackedColorArray(stops.map(func(s): return Color(s[1])))
	var rr: int = rright if rright >= 0 else maxi(rtop, rbot)
	for y in h:
		var c := g.sample(float(y) / (h - 1))
		var left_r := float(rtop if y < h / 2 else rbot)
		var right_r := float(rright) if rright >= 0 else left_r
		for x in w:
			var r := right_r if x >= w / 2 else left_r
			# Distance inside the rounded rect (negative = outside).
			var dx := minf(x + 0.5, w - x - 0.5)
			var dy := minf(y + 0.5, h - y - 0.5)
			var d := minf(dx, dy)
			if dx < r and dy < r:
				d = r - Vector2(r - dx, r - dy).length()
			if d < 0.0:
				continue
			var px := c
			if bw > 0 and d < bw:
				px = border
			px.a *= clampf(d + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, px)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	var m: int = maxi(maxi(rtop, rbot), maxi(rr, bw)) + 1
	sb.set_texture_margin(SIDE_LEFT, m)
	sb.set_texture_margin(SIDE_RIGHT, m)
	sb.set_texture_margin(SIDE_TOP, maxi(rtop, bw) + 1)
	sb.set_texture_margin(SIDE_BOTTOM, maxi(rbot, bw) + 1)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


# ----------------------------------------------------------------- widgets

static func button(text: String, primary := false, danger := false) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", 16)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, button_box(st, primary, danger))
	var fc := TEXT if danger else TEXT_INK
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fc)
	b.add_theme_color_override("font_disabled_color", Color(fc, 0.5))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func label(text: String, size := 16, color := TEXT_INK, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	style_label(l, size, color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func style_label(l: Label, size: int, color: Color) -> void:
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)


static func panel(kind := "paper") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(kind))
	return p


## The green start button: bold italic white "start" on a pill.
static func start_button(text := "start") -> Button:
	var b := Button.new()
	b.text = text
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, box("start_hover" if st == "hover" else "start"))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_font_override("font", start_font())
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	b.add_theme_constant_override("shadow_offset_x", 1)
	b.add_theme_constant_override("shadow_offset_y", 1)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


## A window's button on the taskbar: lighter blue, white text.
static func task_button(text: String) -> Button:
	var b := button(text)
	b.add_theme_font_size_override("font_size", 14)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, box("task_hover" if st == "hover" else "task"))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	return b


## The tray at the right end of the taskbar; put the clock etc. in its row.
static func tray() -> PanelContainer:
	var t := panel("tray")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	t.add_child(row)
	return t


## A window's title on its blue bar: bold white with a dark blue shadow.
static func style_title(l: Label) -> void:
	style_label(l, 16, Color.WHITE)
	l.add_theme_font_override("font", bold())
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.1, 0.35, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)


## The red square close button at the right end of a title bar.
static func close_button() -> Button:
	var x := button("✕", false, true)
	x.focus_mode = Control.FOCUS_NONE
	x.custom_minimum_size = Vector2(26, 24)
	return x
