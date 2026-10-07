## Pad button glyphs in the 2D ink look (no image assets): hard-edged caps
## with an ink outline, like the action menu's key caps. Face buttons are
## octagonal "round" caps (letters for Xbox / Switch, the four shapes for
## PlayStation), shoulders / triggers / Start are wide caps with a label,
## the d-pad a cross.
extends RefCounted

const Ink = preload("res://ui/ink_ui.gd")
const PadMap = preload("res://pad/pad_map.gd")

const XBOX_COLORS := {JOY_BUTTON_A: Color("#7fae4a"), JOY_BUTTON_B: Color("#c8553f"),
	JOY_BUTTON_X: Color("#5b86b8"), JOY_BUTTON_Y: Color("#d4a94a")}
const PS_COLORS := {JOY_BUTTON_A: Color("#7f9fd0"), JOY_BUTTON_B: Color("#d06a6a"),
	JOY_BUTTON_X: Color("#c08ac0"), JOY_BUTTON_Y: Color("#5fb09a")}
const FACE := [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]
const DPAD := [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]
const CAP := Color("#3b3026")


## The width of a glyph of height `h`.
static func width(button: int, style: String, h: float) -> float:
	if button in FACE or button in DPAD:
		return h
	var fsize := int(h * 0.55)
	var tw := Ink.font().get_string_size(PadMap.button_label(button, style), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	return maxf(h * 1.3, tw + h * 0.6)


## Draws a glyph with its top-left at `at`, height `h`; returns its width.
static func draw(ci: CanvasItem, at: Vector2, button: int, style: String, h := 24.0) -> float:
	var w := width(button, style, h)
	var c := at + Vector2(w, h) / 2
	at = at.floor()
	if button in FACE:
		var col: Color = (PS_COLORS if style == "ps" else XBOX_COLORS)[button]
		if style == "nintendo":
			col = Ink.PAPER_HI
		var oct := _octagon(Rect2(at, Vector2(w, h)))
		ci.draw_colored_polygon(oct, Ink.INK)
		ci.draw_colored_polygon(_octagon(Rect2(at, Vector2(w, h)).grow(-2)), CAP)
		var ring := _octagon(Rect2(at, Vector2(w, h)).grow(-3.5))
		ring.append(ring[0])
		ci.draw_polyline(ring, col, 1.5)
		if style == "ps":
			_shape(ci, c, h * 0.22, PadMap.ps_shape(button), col)
		else:
			_label(ci, Rect2(at, Vector2(w, h)), PadMap.button_label(button, style), int(h * 0.6), col)
		return w
	if button in DPAD:
		var t := floorf(h * 0.36)
		var v := Rect2(Vector2(c.x - t / 2, at.y), Vector2(t, h)).abs()
		var hz := Rect2(Vector2(at.x, c.y - t / 2), Vector2(w, t))
		ci.draw_rect(v, Ink.INK)
		ci.draw_rect(hz, Ink.INK)
		ci.draw_rect(v.grow(-2), CAP)
		ci.draw_rect(hz.grow(-2), CAP)
		var d: Vector2 = {JOY_BUTTON_DPAD_UP: Vector2.UP, JOY_BUTTON_DPAD_DOWN: Vector2.DOWN,
			JOY_BUTTON_DPAD_LEFT: Vector2.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2.RIGHT}[button]
		var s := floorf(t * 0.5)
		ci.draw_rect(Rect2((c + d * h * 0.32 - Vector2(s, s) / 2).floor(), Vector2(s, s)), Ink.GOLD)
		return w
	# Shoulders, triggers, Start / Select, stick clicks: a cap with a label;
	# triggers with clipped top corners.
	var rect := Rect2(at, Vector2(w, h))
	if button in [PadMap.LT, PadMap.RT]:
		ci.draw_colored_polygon(_octagon(rect, h * 0.35), Ink.INK)
		ci.draw_colored_polygon(_octagon(rect.grow(-2), h * 0.3), CAP)
	else:
		ci.draw_rect(rect, Ink.INK)
		ci.draw_rect(rect.grow(-2), CAP)
	_label(ci, rect, PadMap.button_label(button, style), int(h * 0.55), Ink.PAPER_HI)
	return w


static func _label(ci: CanvasItem, r: Rect2, text: String, fsize: int, col: Color) -> void:
	var f := Ink.font()
	var base := r.position.y + r.size.y / 2 + fsize * 0.36
	ci.draw_string(f, Vector2(r.position.x, roundf(base)), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fsize, col)


## A rectangle with its corners cut (the pixel look's "round").
static func _octagon(r: Rect2, cut := -1.0) -> PackedVector2Array:
	var k := r.size.y * 0.3 if cut < 0.0 else cut
	var p := r.position
	var e := r.end
	return PackedVector2Array([Vector2(p.x + k, p.y), Vector2(e.x - k, p.y), Vector2(e.x, p.y + k), Vector2(e.x, e.y - k),
		Vector2(e.x - k, e.y), Vector2(p.x + k, e.y), Vector2(p.x, e.y - k), Vector2(p.x, p.y + k)])


static func _shape(ci: CanvasItem, c: Vector2, s: float, shape: String, col: Color) -> void:
	match shape:
		"cross":
			ci.draw_line(c - Vector2(s, s), c + Vector2(s, s), col, 2.0)
			ci.draw_line(c + Vector2(-s, s), c + Vector2(s, -s), col, 2.0)
		"circle":
			ci.draw_arc(c, s, 0, TAU, 12, col, 2.0)
		"square":
			ci.draw_rect(Rect2(c - Vector2(s, s) * 0.85, Vector2(s, s) * 1.7), col, false, 2.0)
		"triangle":
			var p := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.95, s * 0.7), c + Vector2(-s * 0.95, s * 0.7), c + Vector2(0, -s)])
			ci.draw_polyline(p, col, 2.0)
