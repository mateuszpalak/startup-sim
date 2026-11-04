## A toilet stall door: closed panel with a free / occupied sign (green /
## red), drawn open while someone stands in the doorway. Locked doors are
## solid in the simulation (MapData.closed) and always drawn shut.
extends Node2D

var tile := Vector2i.ZERO
## In a wall running left-right (drawn turned a quarter).
var across := false
var locked := false
var open := false


func set_state(p_locked: bool, p_open: bool) -> void:
	p_open = p_open and not p_locked
	if p_locked != locked or p_open != open:
		locked = p_locked
		open = p_open
		queue_redraw()


const INK := Color("#55606a")  # the rim: a deep shade of the panel


func _panel(r: Rect2, fill: Color) -> void:
	draw_rect(r.grow(0.45), INK)
	draw_rect(r, fill)


func _draw() -> void:
	# Local origin = tile center; the door stands in the partition line.
	draw_set_transform(Vector2.ZERO, PI / 2 if across else 0.0, Vector2.ONE)
	if open:
		# Swung open against the partition above: just its edge.
		_panel(Rect2(-8, -8, 2.6, 15), Color("#9fb9b9"))
		return
	_panel(Rect2(-3, -8, 6, 15.5), Color("#a9c4c4"))
	draw_line(Vector2(-2.2, -7), Vector2(2.2, -7), Color(1, 1, 1, 0.45), 0.6, true)
	draw_rect(Rect2(-3, 4.8, 6, 2.7), Color("#8f959b"))
	# The latch sign: a little round window, red "occupied" / green "free".
	draw_circle(Vector2(0, -1.5), 1.6, INK)
	var sign_col := Color("#e0503e") if locked else Color("#6fc04a")
	draw_circle(Vector2(0, -1.5), 2.4, Color(sign_col, 0.25))
	draw_circle(Vector2(0, -1.5), 1.15, sign_col)
	draw_circle(Vector2(-0.35, -1.85), 0.35, Color(1, 1, 1, 0.7))
