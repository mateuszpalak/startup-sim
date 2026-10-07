## F3 debug overlay.
extends CanvasLayer

const Kit = preload("res://ui/ui_kit.gd")

var game
var label := Label.new()
var _timer := 0.0


func _ready() -> void:
	layer = 10
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Kit.box("hud"))
	panel.position = Vector2(16, 76)  # below the game clock
	add_child(panel)
	Kit.style_label(label, 13, Kit.TEXT)
	panel.add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		visible = not visible


func _process(delta: float) -> void:
	_timer -= delta
	if visible and game and _timer <= 0.0:
		label.text = game.debug_text()
		_timer = 0.1
