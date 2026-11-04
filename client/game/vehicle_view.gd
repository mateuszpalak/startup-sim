## A vehicle outside (entity kind VEHICLE): car, bike, taxi, tram or patrol car, drawn
## top-down; follows the server's positions smoothly.
extends Node2D

const CAR := 1
const BIKE := 2
const TAXI := 3
const TRAM := 4
const POLICE := 5
const FIRE_ENGINE := 6
const CAR_COLORS := [Color("#c0392b"), Color("#2e5fa8"), Color("#ecf0f1"), Color("#2c2f36"), Color("#27ae60"), Color("#8e44ad")]

var kind := CAR
var color := Color("#c0392b")
var facing := 2
var target := Vector2.ZERO
var last_seen_tick := 0
var _placed := false


func setup(p_kind: int, id: int) -> void:
	if p_kind != kind:
		kind = p_kind
		queue_redraw()
	color = CAR_COLORS[id % CAR_COLORS.size()]


func push(pos: Vector2, flags: int) -> void:
	target = pos
	if not _placed:
		position = pos
		_placed = true
	if (flags & 3) != facing:
		facing = flags & 3
		queue_redraw()


func _process(delta: float) -> void:
	position = position.lerp(target, minf(1.0, delta * 12.0))
	if kind == POLICE or kind == FIRE_ENGINE:
		queue_redraw()  # flashing lights


## A rounded box: the fill, a darker rim of its own colour, a light line
## along the top.
func _rbox(r: Rect2, fill: Color, rad := 3.0) -> void:
	var k := minf(rad, minf(r.size.x, r.size.y) * 0.45)
	var p := r.position
	var e := r.end
	var pts := PackedVector2Array([Vector2(p.x + k, p.y), Vector2(e.x - k, p.y), Vector2(e.x, p.y + k), Vector2(e.x, e.y - k),
		Vector2(e.x - k, e.y), Vector2(p.x + k, e.y), Vector2(p.x, e.y - k), Vector2(p.x, p.y + k)])
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, fill.darkened(0.5), 1.0, true)
	draw_line(Vector2(p.x + k, p.y + 1.2), Vector2(e.x - k, p.y + 1.2), Color(1, 1, 1, 0.3), 1.0)


## A soft shadow under a vehicle.
func _shade(r: Rect2) -> void:
	for g in [3.0, 1.5, 0.0]:
		draw_rect(Rect2(r.position + Vector2(2, 4), r.size).grow(g), Color(0.03, 0.05, 0.1, 0.09))


## Glass: dark blue with the sky in it.
func _glass(r: Rect2) -> void:
	_rbox(r, Color("#3d5a78"), 1.5)
	draw_line(r.position + Vector2(1.5, 2.0), r.position + Vector2(r.size.x - 1.5, 4.0), Color(0.75, 0.9, 1.0, 0.55), 1.0)


func _draw() -> void:
	var flip := facing == 3  # facing right: mirror
	match kind:
		CAR, TAXI, POLICE:
			var body := color if kind == CAR else (Color("#f4c20d") if kind == TAXI else Color("#eef1f4"))
			var r := Rect2(-22, -11, 44, 20)
			_shade(r)
			for wx in [-16, 10]:
				_rbox(Rect2(wx, -12.5, 7, 3), Color("#22252b"), 1.0)
				_rbox(Rect2(wx, 8.5, 7, 3), Color("#22252b"), 1.0)
			_rbox(r, body, 6.0)
			# Windscreen at the front (the side it drives to), rear window.
			var front := 10.0 if flip else -18.0
			var back := -16.0 if flip else 12.0
			_glass(Rect2(front, -8, 8, 14))
			_glass(Rect2(back, -7, 5, 12))
			_rbox(Rect2(-8, -9, 16, 16), body.lightened(0.12), 3.0)  # roof
			# Lights: headlamps at the front, tail lights at the back.
			var hx := 20.5 if flip else -21.5
			var tx := -21.5 if flip else 20.5
			for ly in [-8.0, 6.0]:
				draw_circle(Vector2(hx + 0.5, ly + 0.5), 1.4, Color("#fff1b0"))
				draw_circle(Vector2(tx + 0.5, ly + 0.5), 1.2, Color("#e0503e"))
			if kind == TAXI:
				_rbox(Rect2(-5, -4, 10, 5), Color("#22252b"), 1.0)
				draw_rect(Rect2(-4, -3, 8, 3), Color("#ffe066"))
			if kind == POLICE:
				draw_rect(Rect2(-21, -2, 42, 3), Color("#2f56b0"))  # stripe
				var blink := (Time.get_ticks_msec() / 250) % 2 == 0
				_light(Vector2(-3, -3), Color("#4f8bff"), blink)
				_light(Vector2(3, -3), Color("#ff5a4f"), not blink)
		FIRE_ENGINE:
			var r := Rect2(-34, -13, 68, 24)
			_shade(r)
			_rbox(r, Color("#d6453a"), 5.0)
			var cab := 20.0 if flip else -32.0
			_rbox(Rect2(cab, -10, 12, 18), Color("#bd3328"), 3.0)
			_glass(Rect2(cab + (8.0 if flip else 0.0), -8, 4, 14))  # windscreen
			# Ladder on the roof.
			var lx := -24.0 if not flip else -14.0
			draw_rect(Rect2(lx, -6, 38, 2), Color("#dfe4ea"))
			draw_rect(Rect2(lx, 2, 38, 2), Color("#dfe4ea"))
			for i in 7:
				draw_rect(Rect2(lx + i * 6, -6, 1, 10), Color("#dfe4ea"))
			draw_rect(Rect2(-33, 6, 66, 2), Color("#f4e36a"))  # stripe
			var blink := (Time.get_ticks_msec() / 200) % 2 == 0
			_light(Vector2(cab + 4, -11.5), Color("#4f8bff"), blink)
			_light(Vector2(cab + 9, -11.5), Color("#4f8bff"), not blink)
		TRAM:
			var r := Rect2(-48, -12, 96, 22)
			_shade(r)
			_rbox(r, Color("#d64a3a"), 6.0)
			_rbox(Rect2(-47, -6, 94, 8), Color("#f6ecd4"), 2.0)
			for i in 8:
				_glass(Rect2(-44 + i * 11, -5, 8, 6))
			draw_rect(Rect2(-2, -12, 4, 22), Color("#8e2a20"))  # articulation
			draw_line(Vector2(-30, -12), Vector2(-10, -16), Color("#59636b"), 1.0)  # pantograph
			draw_line(Vector2(-10, -16), Vector2(10, -16), Color("#59636b"), 1.0)
		BIKE:
			var d := -1.0 if flip else 1.0
			draw_circle(Vector2(1, 6), 6.0, Color(0.03, 0.05, 0.1, 0.15))
			for wx in [-4.0, 4.0]:
				draw_arc(Vector2(wx, 3), 3.0, 0, TAU, 16, Color("#22252b"), 1.2, true)
				draw_arc(Vector2(wx, 3), 2.2, PI * 1.1, PI * 1.5, 6, Color(1, 1, 1, 0.4), 0.5, true)
			draw_line(Vector2(-4, 3), Vector2(0, -1), color, 1.5, true)
			draw_line(Vector2(0, -1), Vector2(4, 3), color, 1.5, true)
			draw_line(Vector2(0, -1), Vector2(3 * d, -3), color, 1.5, true)
			_rbox(Rect2(-2, -3.5, 3.5, 1.6), Color("#5a3d27"), 0.6)  # saddle


## A flashing roof light: bright with a glow when on, dim when off.
func _light(c: Vector2, col: Color, on: bool) -> void:
	if on:
		draw_circle(c, 5.0, Color(col, 0.25))
	draw_circle(c, 2.2, col if on else col.darkened(0.6))
