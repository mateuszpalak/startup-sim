## The Esc menu during the game (and the StartOS button on the home
## computer): back to the game, settings, leave to the title screen, quit.
## The game keeps running on the server meanwhile.
extends Control

const Kit = preload("res://ui/ui_kit.gd")
const SettingsPanel = preload("res://ui/settings_panel.gd")
const Updates = preload("res://net/updates.gd")
const Touch = preload("res://touch/touch.gd")

signal to_menu
signal quit
## "Wyloguj": forget the remembered login and go back to the login screen.
signal logout
signal settings_changed

var _dim := ColorRect.new()
var _card := PanelContainer.new()
var _menu := VBoxContainer.new()
var _settings := SettingsPanel.new()


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_fit)
	_dim.color = Color(0.08, 0.06, 0.12, 0.5)
	add_child(_dim)
	_card.add_theme_stylebox_override("panel", Kit.box("paper"))
	add_child(_card)
	var box := VBoxContainer.new()
	_card.add_child(box)
	_menu.add_theme_constant_override("separation", 12)
	box.add_child(_menu)
	_menu.add_child(Kit.label("Przerwa", 30, Kit.TEXT_INK))
	_menu.add_child(Kit.label("Gra toczy się dalej — inni pracują.", 16, Kit.TEXT_MUTED))
	for entry in [["Wróć do gry", func(): close(), true], ["Ustawienia", func(): _show(_settings), false],
			["Wyjdź do menu", func(): close(); to_menu.emit(), false], ["Wyloguj", func(): close(); logout.emit(), false],
			["Wyjdź z gry", func(): quit.emit(), false]]:
		if entry[0] == "Wyjdź z gry" and not preload("res://platform/platform.gd").can_quit():
			continue  # iOS guidelines / Android: the system closes apps
		var b := Kit.button(entry[0], entry[2])
		b.custom_minimum_size = Vector2(300, Touch.TARGET if Touch.active else 44.0)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(entry[1])
		_menu.add_child(b)
	var version := Kit.label("Startup Sim %s" % Updates.current(), 14, Kit.TEXT_MUTED)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(version)
	_settings.visible = false
	_settings.fixed_height = 190.0  # just the card's margins, the title and "Wróć"
	_settings.back.connect(func(): _show(_menu))
	_settings.changed.connect(func(): settings_changed.emit())
	box.add_child(_settings)
	_fit()


func _show(what: Control) -> void:
	_menu.visible = what == _menu
	_settings.visible = what == _settings
	_fit.call_deferred()


func open() -> void:
	_show(_menu)
	visible = true
	_dim.modulate.a = 0.0
	create_tween().tween_property(_dim, "modulate:a", 1.0, 0.2)
	(func(): _fit(); Kit.pop_in(_card)).call_deferred()


func close() -> void:
	visible = false


func _fit() -> void:
	var vs := get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	_dim.size = vs
	_card.reset_size()
	_card.position = (vs - _card.size) / 2
	Touch.place_center(_card, get_viewport())


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _settings.visible:
			_show(_menu)
		else:
			close()
		get_viewport().set_input_as_handled()
