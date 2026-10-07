## Keeps the text field being typed in above the on-screen keyboard: while
## a LineEdit / TextEdit has focus and the keyboard is up, the CanvasLayer
## holding that field slides up just enough (back down when it closes).
## `--fake-keyboard=0.4` (dev, desktop): pretend a keyboard that covers
## this part of the window, to see the layouts.
extends Node

const Touch = preload("res://touch/touch.gd")

var fake := 0.0
var _layer: CanvasLayer = null
var _lift := 0.0


func _process(delta: float) -> void:
	var vp := get_viewport()
	var focus := vp.gui_get_focus_owner()
	var typing := focus is LineEdit or focus is TextEdit
	var kb_px := float(DisplayServer.virtual_keyboard_get_height())
	if fake > 0.0 and typing:
		kb_px = vp.get_window().size.y * fake
	var want := 0.0
	var layer: CanvasLayer = null
	if typing and kb_px > 0.0:
		layer = _layer_of(focus)
		var vis := vp.get_visible_rect().size
		var units := kb_px * vis.y / float(vp.get_window().size.y)
		var kb_top := vis.y - units
		var r: Rect2 = focus.get_global_rect()
		var bottom := r.end.y - _lift + 10.0  # where it'd be unlifted
		want = maxf(0.0, bottom - kb_top)
		want = minf(want, maxf(r.position.y - _lift - 8.0, 0.0))  # its top stays on screen
	if layer != _layer and _layer != null:
		_layer.offset.y = 0.0
		_lift = 0.0
	_layer = layer
	_lift = lerpf(_lift, want, 1.0 - exp(-18.0 * delta))
	if absf(_lift - want) < 0.5:
		_lift = want
	if _layer:
		_layer.offset.y = -_lift


static func _layer_of(n: Node) -> CanvasLayer:
	var p := n.get_parent()
	while p and p is not CanvasLayer:
		p = p.get_parent()
	return p as CanvasLayer
