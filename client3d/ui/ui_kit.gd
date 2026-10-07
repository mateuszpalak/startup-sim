## The game's UI kit: one set of design tokens (colours, radii, font sizes,
## spacing) and the widgets built from them, so the menus, the HUD, the
## computer and the dialogs share one look - a cozy, modern game UI that
## matches the low-poly 3D world: rounded panels with soft shadows, light
## frosted "glass" windows, dark translucent HUD chips, Nunito (OFL,
## fonts/OFL-Nunito.txt) with full Polish glyphs, vector icons drawn in
## code and short tweened animations.
extends RefCounted

# ------------------------------------------------------------------ tokens

## Line width of vector icons / outlines (screen pixels).
const LINE := 2

# Radii and spacing.
const R_SM := 8
const R_MD := 12
const R_LG := 18
const R_XL := 24
const GAP_SM := 6
const GAP := 10
const GAP_LG := 16

# Palette. Light surfaces (windows), dark glass (HUD), warm accents taken
# from the 3D world (terracotta, honey, sage, sky).
const INK := Color("#2b2633")           # darkest: icon outlines, text outline
const DARK := Color("#26222e")          # HUD glass
const DARK_HI := Color("#3a3444")
const DARK_LO := Color("#1b1821")
const PAPER := Color("#fbf6ef")         # windows (frosted cream)
const PAPER_HI := Color("#ffffff")
const PAPER_LO := Color("#ece4d8")
const CARD := Color("#ffffff")
const CARD_LO := Color("#f1ebe2")
const ACCENT := Color("#e8744f")        # primary buttons, highlights
const ACCENT_HI := Color("#f28c69")
const ACCENT_LO := Color("#c95a37")
const GOLD := Color("#f4b740")
const RED := Color("#e0524f")
const GREEN := Color("#5bb36a")
const BLUE := Color("#4a9be0")
const TEAL := Color("#3fae9e")
const PURPLE := Color("#9a78d8")
const TEXT := Color("#fbf7f2")          # text on dark
const TEXT_DIM := Color("#c9c0cf")
const TEXT_INK := Color("#2e2a36")      # text on light
const TEXT_MUTED := Color("#857c8c")
const SHADOW := Color(0.08, 0.05, 0.12, 0.28)

# Font sizes (logical pixels).
const FS_SMALL := 14
const FS_BODY := 17
const FS_LABEL := 19
const FS_TITLE := 24
const FS_HERO := 64

static var _font: Font
static var _font_bold: Font
static var _theme: Theme
static var _boxes := {}


static func _base_font() -> FontFile:
	var path := "res://fonts/Nunito.ttf"
	var f: FontFile
	if ResourceLoader.exists(path):
		f = (load(path) as FontFile).duplicate()
	else:
		f = FontFile.new()
		f.load_dynamic_font(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f


static func _weight(w: int) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = _base_font()
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): w}
	return v


## The UI font (Nunito SemiBold).
static func font() -> Font:
	if _font == null:
		_font = _weight(600)
	return _font


## Headings and buttons (Nunito ExtraBold).
static func font_bold() -> Font:
	if _font_bold == null:
		_font_bold = _weight(800)
	return _font_bold


## A size from the old scale (kept so callers keep their proportions).
static func fs(n: int) -> int:
	return maxi(14, int(round(n * 1.05)))


## A Theme for the whole window.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = FS_BODY
	for c in ["Button", "OptionButton", "MenuButton"]:
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			t.set_stylebox(st, c, button_box(st, false))
		t.set_font(&"font", c, font_bold())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		for c in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
			t.set_color(k, c, TEXT_INK)
	t.set_color("font_disabled_color", "Button", TEXT_MUTED)
	for c in ["CheckBox", "CheckButton"]:
		for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
			t.set_stylebox(st, c, StyleBoxEmpty.new())
	t.set_icon("checked", "CheckBox", _check_icon(true))
	t.set_icon("unchecked", "CheckBox", _check_icon(false))
	t.set_icon("radio_checked", "CheckBox", _radio_icon(true))
	t.set_icon("radio_unchecked", "CheckBox", _radio_icon(false))
	for st in ["normal", "read_only"]:
		t.set_stylebox(st, "LineEdit", box("input"))
		t.set_stylebox(st, "TextEdit", box("input"))
	t.set_stylebox("focus", "LineEdit", box("input_focus"))
	t.set_stylebox("focus", "TextEdit", box("input_focus"))
	for c in ["LineEdit", "TextEdit", "SpinBox"]:
		t.set_color("font_color", c, TEXT_INK)
		t.set_color("font_placeholder_color", c, TEXT_MUTED)
		t.set_color("font_uneditable_color", c, Color(TEXT_INK, 0.7))
		t.set_color("caret_color", c, ACCENT)
		t.set_color("selection_color", c, Color(ACCENT, 0.3))
	t.set_stylebox("panel", "PanelContainer", box("paper"))
	t.set_stylebox("panel", "PopupMenu", box("popup"))
	t.set_stylebox("panel", "TooltipPanel", box("tooltip"))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", FS_SMALL)
	t.set_color("font_color", "PopupMenu", TEXT_INK)
	t.set_color("font_hover_color", "PopupMenu", TEXT_INK)
	t.set_stylebox("hover", "PopupMenu", box("card_hover"))
	t.set_constant("v_separation", "PopupMenu", 8)
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, box("scroll"))
		t.set_stylebox("grabber", bar, box("grabber"))
		t.set_stylebox("grabber_highlight", bar, box("grabber_hi"))
		t.set_stylebox("grabber_pressed", bar, box("grabber_hi"))
	for sl in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", sl, box("track"))
		t.set_stylebox("grabber_area", sl, box("track_fill"))
		t.set_stylebox("grabber_area_highlight", sl, box("track_fill"))
		t.set_icon("grabber", sl, _knob(false))
		t.set_icon("grabber_highlight", sl, _knob(true))
	t.set_stylebox("background", "ProgressBar", box("track"))
	t.set_stylebox("fill", "ProgressBar", box("track_fill"))
	t.set_stylebox("panel", "TabContainer", box("card"))
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", FS_LABEL)
	for c in ["Button", "OptionButton", "LineEdit", "TextEdit", "CheckBox", "CheckButton"]:
		t.set_font_size("font_size", c, FS_LABEL)
	t.set_constant("separation", "HSeparator", 12)
	var sep := StyleBoxLine.new()
	sep.color = Color(TEXT_INK, 0.1)
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	_theme = t
	return t


# ------------------------------------------------------------------ frames

static func _flat(fill: Color, radius: int, pad := 16, pad_v := 12, border := Color(0, 0, 0, 0),
		bw := 0, shadow := 0, shadow_off := Vector2(0, 4)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 10
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 0.8
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	if shadow > 0:
		sb.shadow_color = SHADOW
		sb.shadow_size = shadow
		sb.shadow_offset = shadow_off
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


## Named frames: hud (dark glass chip), paper (window), card, card_hover,
## title (accent band), input, input_focus, screen (monitor bezel), scroll,
## grabber, slot, slot_active, bubble, mine (own chat message), popup,
## tooltip, track, track_fill.
static func box(kind: String) -> StyleBox:
	if _boxes.has(kind):
		return _boxes[kind]
	var sb: StyleBoxFlat
	match kind:
		"hud":
			sb = _flat(Color(DARK, 0.78), R_LG, 16, 10, Color(1, 1, 1, 0.08), 1, 10)
		"glass":
			sb = _flat(Color(DARK, 0.84), R_XL, 22, 18, Color(1, 1, 1, 0.1), 1, 24, Vector2(0, 8))
		"alarm":
			sb = _flat(Color(RED, 0.9), R_LG, 20, 10, Color(1, 1, 1, 0.3), 1, 12)
		"glass_card":
			sb = _flat(Color(DARK, 0.72), R_LG, 16, 10, Color(1, 1, 1, 0.12), 1, 12)
		"glass_hover":
			sb = _flat(Color(DARK_HI, 0.85), R_LG, 16, 10, Color(ACCENT, 0.8), 2, 12)
		"paper":
			sb = _flat(PAPER, R_XL, 22, 18, Color(1, 1, 1, 0.9), 1, 24, Vector2(0, 8))
		"window":
			sb = _flat(PAPER, R_XL, 0, 0, Color(1, 1, 1, 0.9), 1, 24, Vector2(0, 8))
		"card":
			sb = _flat(CARD, R_MD, 14, 12, Color(TEXT_INK, 0.07), 1)
		"card_hover":
			sb = _flat(Color("#fff3ec"), R_MD, 14, 12, Color(ACCENT, 0.45), 1)
		"title":
			sb = _flat(ACCENT, R_MD, 14, 8)
		"window_bar":
			sb = _flat(Color(PAPER_LO, 0.55), R_XL, 18, 8)
			sb.corner_radius_bottom_left = 0
			sb.corner_radius_bottom_right = 0
		"input":
			sb = _flat(CARD, R_MD, 12, 8, Color(TEXT_INK, 0.14), 2)
		"input_focus":
			sb = _flat(CARD, R_MD, 12, 8, ACCENT, 2)
		"screen":
			sb = _flat(Color("#1d1b22"), R_XL, 14, 14, Color("#3b3744"), 2, 30, Vector2(0, 10))
		"scroll":
			sb = _flat(Color(TEXT_INK, 0.05), 6, 3, 3)
		"grabber":
			sb = _flat(Color(TEXT_INK, 0.25), 6, 3, 3)
		"grabber_hi":
			sb = _flat(Color(ACCENT, 0.8), 6, 3, 3)
		"slot":
			sb = _flat(Color(DARK_HI, 0.85), R_MD, 4, 4, Color(1, 1, 1, 0.1), 2)
		"slot_active":
			sb = _flat(Color("#4a3f4f"), R_MD, 4, 4, GOLD, 3)
		"bubble":
			sb = _flat(Color(CARD, 0.96), R_LG, 14, 8, Color(0, 0, 0, 0), 0, 10)
		"mine":
			sb = _flat(Color("#ffe6da"), R_MD, 12, 7)
		"popup":
			sb = _flat(CARD, R_MD, 10, 8, Color(TEXT_INK, 0.08), 1, 12)
		"tooltip":
			sb = _flat(Color(DARK, 0.94), R_SM, 10, 6)
		"track":
			sb = _flat(Color(TEXT_INK, 0.12), 6, 0, 3)
		"track_fill":
			sb = _flat(ACCENT, 6, 0, 3)
		_:
			return box("paper")
	_boxes[kind] = sb
	return sb


static func button_box(state: String, primary: bool, danger := false) -> StyleBox:
	var key := "btn_%s_%s_%s" % [state, primary, danger]
	if _boxes.has(key):
		return _boxes[key]
	var solid := primary or danger
	var base: Color = RED if danger else (ACCENT if primary else CARD)
	var border := Color(0, 0, 0, 0) if solid else Color(TEXT_INK, 0.12)
	match state:
		"hover", "focus":
			if solid:
				base = base.lightened(0.08)
			else:
				base = Color("#fff1e9")
				border = Color(ACCENT, 0.55)
		"pressed":
			base = base.darkened(0.1)
		"disabled":
			base = base.lerp(Color("#d9d3cc"), 0.6)
	var sb := _flat(base, R_MD, 16, 7, border, 0 if solid else 1,
		0 if state in ["pressed", "disabled"] else 4, Vector2(0, 2))
	if solid:
		sb.shadow_color = Color(base.darkened(0.45), 0.35)
	if state == "pressed":
		sb.content_margin_top += 1
		sb.content_margin_bottom -= 1
	_boxes[key] = sb
	return sb


# ------------------------------------------------------------- theme icons

static func _icon_image(size: int, draw: Callable) -> ImageTexture:
	var s := 2  # supersampled
	var img := Image.create(size * s, size * s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in size * s:
		for x in size * s:
			var c: Color = draw.call(Vector2(x + 0.5, y + 0.5) / s, size)
			if c.a > 0:
				img.set_pixel(x, y, c)
	img.resize(size, size, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(img)


static func _rrect_d(p: Vector2, half: Vector2, r: float) -> float:
	var q := (p.abs() - half + Vector2(r, r))
	return Vector2(maxf(q.x, 0), maxf(q.y, 0)).length() + minf(maxf(q.x, q.y), 0.0) - r


static func _seg_d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0, 1)
	return p.distance_to(a + ab * t)


static func _check_icon(on: bool) -> ImageTexture:
	return _icon_image(22, func(p: Vector2, n: int) -> Color:
		var d := _rrect_d(p - Vector2(n, n) / 2.0, Vector2(9, 9), 6)
		if d > 0.5:
			return Color(0, 0, 0, 0)
		var a := clampf(0.5 - d, 0, 1)
		if on:
			var t := minf(_seg_d(p, Vector2(6, 11.5), Vector2(9.5, 15)), _seg_d(p, Vector2(9.5, 15), Vector2(16, 7.5)))
			return Color(Color.WHITE if t < 1.6 else ACCENT, a)
		return Color(CARD if d < -2.0 else Color(TEXT_INK, 0.3), a))


static func _radio_icon(on: bool) -> ImageTexture:
	return _icon_image(22, func(p: Vector2, n: int) -> Color:
		var d := p.distance_to(Vector2(n, n) / 2.0) - 9.0
		if d > 0.5:
			return Color(0, 0, 0, 0)
		var a := clampf(0.5 - d, 0, 1)
		if on:
			return Color(Color.WHITE if d < -6 else ACCENT, a)
		return Color(CARD if d < -2 else Color(TEXT_INK, 0.3), a))


static func _knob(hi: bool) -> ImageTexture:
	return _icon_image(22, func(p: Vector2, n: int) -> Color:
		var d := p.distance_to(Vector2(n, n) / 2.0) - (9.0 if hi else 8.0)
		if d > 0.5:
			return Color(0, 0, 0, 0)
		return Color(ACCENT if d > -2.5 else Color.WHITE, clampf(0.5 - d, 0, 1)))


# ----------------------------------------------------------------- widgets

static func button(text: String, primary := false, danger := false) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font_bold())
	b.add_theme_font_size_override("font_size", FS_LABEL)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, button_box(st, primary, danger))
	var fc := TEXT if (primary or danger) else TEXT_INK
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, fc)
	b.add_theme_color_override("font_disabled_color", Color(fc, 0.5))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hover_lift(b)
	return b


static func label(text: String, size := 16, color := TEXT_INK, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	style_label(l, size, color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func style_label(l: Label, size: int, color: Color) -> void:
	l.add_theme_font_override("font", font_bold() if size >= 22 else font())
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)


## A panel with one of the frames.
static func panel(kind := "paper") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(kind))
	return p


## A rounded bar into `c` at `r`: `value` 0..1.
static func draw_bar(c: CanvasItem, r: Rect2, value: float, color: Color) -> void:
	var rad := r.size.y / 2.0
	draw_rrect(c, r, Color(0, 0, 0, 0.28), rad)
	var w := r.size.x * clampf(value, 0.0, 1.0)
	if w > 1:
		draw_rrect(c, Rect2(r.position, Vector2(maxf(w, r.size.y), r.size.y)), color, rad)
		draw_rrect(c, Rect2(r.position + Vector2(rad * 0.6, 1.5), Vector2(maxf(w - rad * 1.2, 0), r.size.y * 0.3)), Color(1, 1, 1, 0.25), r.size.y * 0.15)


## A rounded rectangle (anti-aliased).
static func draw_rrect(c: CanvasItem, r: Rect2, col: Color, rad: float, border := Color(0, 0, 0, 0), bw := 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(rad))
	sb.corner_detail = 8
	sb.anti_aliasing = true
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	sb.draw(c.get_canvas_item(), r)


## A filled circle (sun, moon...).
static func draw_disc(c: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	c.draw_circle(center, radius, color, true, -1.0, true)


## A ring gauge: track + arc from 12 o'clock clockwise.
static func draw_ring(c: CanvasItem, center: Vector2, radius: float, width: float, value: float, color: Color, track := Color(1, 1, 1, 0.14)) -> void:
	c.draw_arc(center, radius, 0, TAU, 64, track, width, true)
	var v := clampf(value, 0.0, 1.0)
	if v > 0.005:
		c.draw_arc(center, radius, -PI / 2, -PI / 2 + TAU * v, maxi(8, int(64 * v)), color, width, true)


# -------------------------------------------------------------- animation

## Buttons grow a little on hover and dip when pressed.
static func hover_lift(b: Control) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size / 2)
	b.mouse_entered.connect(func(): _tween_scale(b, 1.03))
	b.mouse_exited.connect(func(): _tween_scale(b, 1.0))
	if b is BaseButton:
		(b as BaseButton).button_down.connect(func(): _tween_scale(b, 0.97))
		(b as BaseButton).button_up.connect(func(): _tween_scale(b, 1.0))


static func _tween_scale(n: Control, s: float) -> void:
	if not n.is_inside_tree():
		return
	var t := n.create_tween()
	t.tween_property(n, "scale", Vector2(s, s), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Fade + slight scale in (a window opening). Call after it is placed.
static func pop_in(n: CanvasItem, from_scale := 0.94, time := 0.18) -> void:
	if not n.is_inside_tree():
		return
	if n is Control:
		(n as Control).pivot_offset = (n as Control).size / 2
	var end: float = n.get_meta("fit_scale", 1.0)  # shrunk to fit a small screen (touch.gd)
	n.modulate.a = 0.0
	n.scale = Vector2(from_scale, from_scale) * end
	var t := n.create_tween().set_parallel()
	t.tween_property(n, "modulate:a", 1.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(n, "scale", Vector2.ONE * end, time * 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Fade in (a toast, a hint).
static func fade_in(n: CanvasItem, time := 0.22) -> void:
	if not n.is_inside_tree():
		return
	n.modulate.a = 0.0
	n.create_tween().tween_property(n, "modulate:a", 1.0, time)


# ------------------------------------------------------------ vector icons

## A line icon (rounded strokes, one style everywhere) of `name` centred at
## `c` with half-size `s`: clock, coin, food, energy, brain, water, social,
## fun, hygiene, health, mail, chat, calendar, briefcase, terminal, globe,
## trash, user, gear, sun, moon, cloud, rain, close, check, bell, cart, beer,
## toilet.
static func draw_icon(ci: CanvasItem, name: String, c: Vector2, s: float, col: Color, w := 2.0) -> void:
	var k := s / 10.0
	var pt := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * k
	var line := func(pts: Array) -> void:
		var out := PackedVector2Array()
		for v in pts:
			out.append(c + v * k)
		ci.draw_polyline(out, col, w, true)
	var ring := func(at: Vector2, r: float, a0 := 0.0, a1 := TAU) -> void:
		ci.draw_arc(c + at * k, r * k, a0, a1, maxi(8, int(r * 3)), col, w, true)
	var box := func(x: float, y: float, bw: float, bh: float) -> void:
		line.call([Vector2(x, y), Vector2(x + bw, y), Vector2(x + bw, y + bh), Vector2(x, y + bh), Vector2(x, y)])
	match name:
		"clock":
			ring.call(Vector2.ZERO, 9)
			line.call([Vector2(0, -5), Vector2(0, 0), Vector2(4, 2)])
		"coin":
			ring.call(Vector2.ZERO, 9)
			ring.call(Vector2.ZERO, 5.5)
		"food":
			ring.call(Vector2(-1, -2), 6)
			line.call([Vector2(3, 2.5), Vector2(8, 8)])
			line.call([Vector2(6, 9.5), Vector2(9.5, 6)])
		"energy":
			line.call([Vector2(2, -9), Vector2(-5, 1), Vector2(0, 1), Vector2(-2, 9), Vector2(5, -1), Vector2(0, -1), Vector2(2, -9)])
		"brain":
			ring.call(Vector2(-3, -1), 5.5, PI * 0.5, PI * 1.9)
			ring.call(Vector2(3, -1), 5.5, -PI * 0.9, PI * 0.5)
			line.call([Vector2(0, -6), Vector2(0, 7)])
		"water":
			line.call([Vector2(-5.6, 1), Vector2(0, -9), Vector2(5.6, 1)])
			ring.call(Vector2(0, 2.5), 6, -0.15, PI + 0.15)
		"social":
			ring.call(Vector2(-3.5, -3), 3)
			ring.call(Vector2(4, -2), 2.5)
			ring.call(Vector2(-3.5, 8.5), 6, PI * 1.05, PI * 1.95)
			ring.call(Vector2(4, 8), 4.5, PI * 1.1, PI * 1.95)
		"fun":
			ring.call(Vector2.ZERO, 9)
			ring.call(Vector2(0, 1), 5, 0.2, PI - 0.2)
			ci.draw_circle(pt.call(-3.5, -3), 1.3 * k, col)
			ci.draw_circle(pt.call(3.5, -3), 1.3 * k, col)
		"hygiene":
			ring.call(Vector2(-2, 2), 5)
			ring.call(Vector2(5, -5), 2.5)
			ring.call(Vector2(6, 5), 1.8)
		"health":
			var pts: Array = []
			for i in 33:
				var t := i / 32.0 * TAU
				pts.append(Vector2(16 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))) * 0.55 + Vector2(0, -0.5))
			line.call(pts)
		"mail":
			box.call(-9, -6.5, 18, 13)
			line.call([Vector2(-9, -6.5), Vector2(0, 1), Vector2(9, -6.5)])
		"chat":
			line.call([Vector2(-4, 5), Vector2(-6, 9), Vector2(0, 5), Vector2(9, 5), Vector2(9, -7), Vector2(-9, -7), Vector2(-9, 5), Vector2(-4, 5)])
		"calendar":
			box.call(-8.5, -6.5, 17, 15)
			line.call([Vector2(-8.5, -2), Vector2(8.5, -2)])
			line.call([Vector2(-4, -9), Vector2(-4, -5)])
			line.call([Vector2(4, -9), Vector2(4, -5)])
		"briefcase":
			box.call(-9, -4, 18, 12)
			box.call(-3.5, -8, 7, 4)
			line.call([Vector2(-9, 1), Vector2(9, 1)])
		"terminal":
			box.call(-9, -7, 18, 14)
			line.call([Vector2(-5, -2), Vector2(-2, 1), Vector2(-5, 4)])
			line.call([Vector2(0, 4), Vector2(5, 4)])
		"globe":
			ring.call(Vector2.ZERO, 9)
			line.call([Vector2(-9, 0), Vector2(9, 0)])
			var m1: Array = []
			for i in 17:
				var t := -PI / 2 + PI * i / 16.0
				m1.append(Vector2(cos(t) * 4, sin(t) * 9))
			line.call(m1)
			line.call(m1.map(func(v): return Vector2(-v.x, v.y)))
		"trash":
			line.call([Vector2(-8, -5), Vector2(8, -5)])
			line.call([Vector2(-6, -5), Vector2(-5, 9), Vector2(5, 9), Vector2(6, -5)])
			line.call([Vector2(-2.5, -5), Vector2(-2.5, -8), Vector2(2.5, -8), Vector2(2.5, -5)])
		"user":
			ring.call(Vector2(0, -3.5), 4.5)
			ring.call(Vector2(0, 11), 8.5, PI * 1.1, PI * 1.9)
		"gear":
			ring.call(Vector2.ZERO, 3)
			ring.call(Vector2.ZERO, 7)
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * 7 * k, c + Vector2(cos(a), sin(a)) * 9.5 * k, col, w + 1, true)
		"sun":
			ring.call(Vector2.ZERO, 4.5)
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * 7 * k, c + Vector2(cos(a), sin(a)) * 9.5 * k, col, w, true)
		"moon":
			ring.call(Vector2.ZERO, 8, PI * 0.3, PI * 1.7)
			ring.call(Vector2(4.5, -1), 6.3, PI * 0.62, PI * 1.45)
		"cloud", "rain", "fog":
			var y := -2.0 if name != "cloud" else 0.0
			ring.call(Vector2(-3.5, y + 1), 3.5, PI * 0.5, PI * 1.5)
			ring.call(Vector2(1, y - 1.5), 5, PI * 1.05, TAU * 1.0)
			ring.call(Vector2(5, y + 1.5), 3, -PI * 0.5, PI * 0.5)
			line.call([Vector2(-3.5, y + 4.5), Vector2(5, y + 4.5)])
			if name == "rain":
				for x in [-4, 0, 4]:
					line.call([Vector2(x, 6.5), Vector2(x - 1.5, 9.5)])
			elif name == "fog":
				line.call([Vector2(-7, 7), Vector2(6, 7)])
				line.call([Vector2(-4, 9.5), Vector2(8, 9.5)])
		"close":
			line.call([Vector2(-6, -6), Vector2(6, 6)])
			line.call([Vector2(6, -6), Vector2(-6, 6)])
		"check":
			line.call([Vector2(-7, 0), Vector2(-2, 5), Vector2(7, -5)])
		"bell":
			ring.call(Vector2(0, -1), 6, PI, TAU)
			line.call([Vector2(-6, -1), Vector2(-7, 5), Vector2(7, 5), Vector2(6, -1)])
			ring.call(Vector2(0, 7), 2, 0, PI)
		"cart":
			line.call([Vector2(-9, -7), Vector2(-6, -7), Vector2(-4, 4), Vector2(7, 4), Vector2(8.5, -4), Vector2(-5, -4)])
			ci.draw_circle(pt.call(-3, 7.5), 1.6 * k, col)
			ci.draw_circle(pt.call(6, 7.5), 1.6 * k, col)
		"beer":
			box.call(-6, -6, 10, 15)
			ring.call(Vector2(5, 1.5), 3.5, -PI / 2, PI / 2)
			ring.call(Vector2(-3, -7), 2.8, PI, TAU)
			ring.call(Vector2(2, -7.5), 3, PI, TAU)
		"toilet":
			line.call([Vector2(-6, -9), Vector2(-6, 1)])
			line.call([Vector2(-8, 1), Vector2(8, 1)])
			ring.call(Vector2(0, 1), 8, 0, PI)
			line.call([Vector2(-3, 8.5), Vector2(-4, 10), Vector2(4, 10), Vector2(3, 8.5)])
		"star":
			var sp: Array = []
			for i in 11:
				var a := -PI / 2 + TAU * i / 10.0
				sp.append(Vector2(cos(a), sin(a)) * (9.0 if i % 2 == 0 else 4.0))
			line.call(sp)
		"lock":
			box.call(-7, -2, 14, 11)
			ring.call(Vector2(0, -2), 4.5, PI, TAU)
			line.call([Vector2(0, 2.5), Vector2(0, 5)])
		"book":
			line.call([Vector2(0, -6), Vector2(0, 8)])
			line.call([Vector2(0, -6), Vector2(-4, -8), Vector2(-9, -8), Vector2(-9, 6), Vector2(-4, 6), Vector2(0, 8), Vector2(4, 6), Vector2(9, 6), Vector2(9, -8), Vector2(4, -8), Vector2(0, -6)])
		"arrow":
			line.call([Vector2(-8, 0), Vector2(8, 0)])
			line.call([Vector2(3, -5), Vector2(8, 0), Vector2(3, 5)])
		"down":
			line.call([Vector2(0, -8), Vector2(0, 7)])
			line.call([Vector2(-5, 2), Vector2(0, 7), Vector2(5, 2)])
		"hand":
			line.call([Vector2(-5, 9), Vector2(-8, 1), Vector2(-7, -1), Vector2(-4, 2), Vector2(-4, -8), Vector2(-2, -9), Vector2(0, -8), Vector2(0, -1)])
			line.call([Vector2(0, -6), Vector2(2, -7), Vector2(4, -6), Vector2(4, -1)])
			line.call([Vector2(4, -4), Vector2(6, -5), Vector2(8, -4), Vector2(8, 4), Vector2(5, 9)])
		"cig":
			line.call([Vector2(-9, 3), Vector2(7, 3), Vector2(7, 7), Vector2(-9, 7), Vector2(-9, 3)])
			line.call([Vector2(2, 3), Vector2(2, 7)])
			ring.call(Vector2(7, -3), 2.5, PI * 0.5, PI * 1.6)
			ring.call(Vector2(4, -6), 2.5, -PI * 0.4, PI * 0.6)
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
				ci.draw_circle(pt.call(x, 0), 1.8 * k, col)
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


# ---------------------------------------------------------------- key caps

## The pad's glyphs for key caps (set by pad/pad.gd): (ci, at, key, fsize,
## draw) -> width, -1 = draw the key, -2 = the pad has no button for it.
static var key_glyph := Callable()


## A key cap ("E", "1–3", "Esc") with its top-left at `at`; returns its width.
## When the pad is in use, its button instead (nothing when it has none).
static func draw_keycap(ci: CanvasItem, at: Vector2, key: String, fsize := 14, light := true) -> float:
	if key_glyph.is_valid():
		var gw: float = key_glyph.call(ci, at, key, fsize, true)
		if gw > -1.5:
			if gw >= 0.0:
				return gw
		else:
			return 0.0
	var f := font_bold()
	var tw := f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var h := fsize + 10.0
	var w := maxf(h, tw + 12)
	var r := Rect2(at, Vector2(w, h))
	draw_rrect(ci, Rect2(r.position + Vector2(0, 2), r.size), Color(0, 0, 0, 0.25), 6)
	draw_rrect(ci, r, Color(CARD, 0.95) if light else DARK_HI, 6)
	ci.draw_string(f, Vector2(at.x, at.y + h / 2 + fsize * 0.36), key, HORIZONTAL_ALIGNMENT_CENTER, w, fsize, TEXT_INK if light else TEXT)
	return w


## Key caps with captions in a row: [[key, text], ...]; returns the width
## (draws nothing with `measure`).
static func draw_key_hints(ci: CanvasItem, at: Vector2, hints: Array, fsize := 14, col := TEXT, measure := false) -> float:
	var f := font()
	var x := at.x
	for i in hints.size():
		var key: String = hints[i][0]
		var text: String = hints[i][1]
		var kw := f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x + 12
		kw = maxf(kw, fsize + 10.0)
		if key_glyph.is_valid():
			var gw: float = key_glyph.call(ci, at, key, fsize, false)
			if gw < -1.5:
				continue  # no pad button for it
			if gw >= 0.0:
				kw = gw
		if not measure:
			draw_keycap(ci, Vector2(x, at.y), key, fsize)
		x += kw + 6
		if not measure:
			ci.draw_string(f, Vector2(x, at.y + (fsize + 10) / 2.0 + fsize * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
		x += f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x + (18 if i < hints.size() - 1 else 0)
	return x - at.x


## A round icon-only button (close, back...): `icon` from draw_icon.
static func icon_button(icon: String, tip := "", danger := false, d := 30.0) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(d, d)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.draw.connect(func():
		var c := b.size / 2
		var hot := b.is_hovered()
		var bg := (RED if danger else ACCENT) if hot else Color(TEXT_INK, 0.08)
		b.draw_circle(c, d / 2, bg, true, -1.0, true)
		draw_icon(b, icon, c, d * 0.24, Color.WHITE if hot else TEXT_INK, 2.0))
	b.mouse_entered.connect(b.queue_redraw)
	b.mouse_exited.connect(b.queue_redraw)
	return b
