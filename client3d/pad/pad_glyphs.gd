## Pad button glyphs drawn like the ui_kit key caps (no image assets): face
## buttons as round caps (letters for Xbox / Switch, the four shapes for
## PlayStation), shoulders / triggers / Start as rounded caps with a label,
## the d-pad as a cross.
extends RefCounted

const Kit = preload("res://ui/ui_kit.gd")
const PadMap = preload("res://pad/pad_map.gd")

const XBOX_COLORS := {JOY_BUTTON_A: Color("#5bb36a"), JOY_BUTTON_B: Color("#e0524f"),
	JOY_BUTTON_X: Color("#4a9be0"), JOY_BUTTON_Y: Color("#f4b740")}
const PS_COLORS := {JOY_BUTTON_A: Color("#7fa8e8"), JOY_BUTTON_B: Color("#e8707a"),
	JOY_BUTTON_X: Color("#d68ad0"), JOY_BUTTON_Y: Color("#4fc0a8")}
const FACE := [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]


## The width of a glyph of height `h`.
static func width(button: int, style: String, h: float) -> float:
	if button in FACE or button in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		return h
	var fsize := int(h * 0.5)
	var tw := Kit.font_bold().get_string_size(PadMap.button_label(button, style), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	return maxf(h * 1.3, tw + h * 0.6)


## Draws a glyph with its top-left at `at`, height `h`; returns its width.
static func draw(ci: CanvasItem, at: Vector2, button: int, style: String, h := 24.0) -> float:
	var w := width(button, style, h)
	var c := at + Vector2(w, h) / 2
	if button in FACE:
		var r := h / 2
		ci.draw_circle(c + Vector2(0, 2), r, Color(0, 0, 0, 0.28), true, -1.0, true)
		ci.draw_circle(c, r, Kit.DARK, true, -1.0, true)
		var col: Color = (PS_COLORS if style == "ps" else XBOX_COLORS)[button]
		if style == "nintendo":
			col = Kit.TEXT
		ci.draw_circle(c, r - 1.0, Color(col, 0.9), false, 2.0, true)
		if style == "ps":
			_shape(ci, c, r * 0.48, PadMap.ps_shape(button), col)
		else:
			var fsize := int(h * 0.58)
			var f := Kit.font_bold()
			ci.draw_string(f, Vector2(at.x, c.y + fsize * 0.36), PadMap.button_label(button, style),
				HORIZONTAL_ALIGNMENT_CENTER, w, fsize, col)
		return w
	if button in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		var t := h * 0.3
		Kit.draw_rrect(ci, Rect2(c - Vector2(t / 2, h / 2), Vector2(t, h)), Kit.DARK, 3)
		Kit.draw_rrect(ci, Rect2(c - Vector2(h / 2, t / 2), Vector2(h, t)), Kit.DARK, 3)
		var d: Vector2 = {JOY_BUTTON_DPAD_UP: Vector2.UP, JOY_BUTTON_DPAD_DOWN: Vector2.DOWN,
			JOY_BUTTON_DPAD_LEFT: Vector2.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2.RIGHT}[button]
		ci.draw_circle(c + d * h * 0.32, t * 0.32, Kit.ACCENT, true, -1.0, true)
		return w
	# Shoulders, triggers, Start / Select, stick clicks: a cap with a label;
	# triggers rounder on top.
	var rect := Rect2(at, Vector2(w, h))
	var rad := h * 0.5 if button in [PadMap.LT, PadMap.RT] else h * 0.28
	Kit.draw_rrect(ci, Rect2(rect.position + Vector2(0, 2), rect.size), Color(0, 0, 0, 0.28), rad)
	Kit.draw_rrect(ci, rect, Kit.DARK, rad, Color(Kit.TEXT, 0.55), 2)
	var fs := int(h * 0.5)
	ci.draw_string(Kit.font_bold(), Vector2(at.x, c.y + fs * 0.36), PadMap.button_label(button, style),
		HORIZONTAL_ALIGNMENT_CENTER, w, fs, Kit.TEXT)
	return w


static func _shape(ci: CanvasItem, c: Vector2, s: float, shape: String, col: Color) -> void:
	match shape:
		"cross":
			ci.draw_line(c - Vector2(s, s), c + Vector2(s, s), col, 2.5, true)
			ci.draw_line(c + Vector2(-s, s), c + Vector2(s, -s), col, 2.5, true)
		"circle":
			ci.draw_arc(c, s, 0, TAU, 24, col, 2.5, true)
		"square":
			ci.draw_rect(Rect2(c - Vector2(s, s) * 0.85, Vector2(s, s) * 1.7), col, false, 2.5)
		"triangle":
			var p := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.95, s * 0.7), c + Vector2(-s * 0.95, s * 0.7), c + Vector2(0, -s)])
			ci.draw_polyline(p, col, 2.5, true)
