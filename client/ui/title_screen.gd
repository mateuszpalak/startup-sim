## The title screen: the logo and the menu over the live 3D building
## (ui/title_backdrop_3d.gd, created by main.gd); Graj / Ustawienia /
## O grze (wersja, autorzy) / Wyjdź; the installed version in the corner.
extends Control

const Kit = preload("res://ui/ui_kit.gd")
const SettingsPanel = preload("res://ui/settings_panel.gd")
const Updates = preload("res://net/updates.gd")

signal play
signal quit

var _menu := VBoxContainer.new()
var _card := PanelContainer.new()
var _settings := SettingsPanel.new()
var _about := VBoxContainer.new()
var _shade := Control.new()
var _logo := VBoxContainer.new()
var _shown := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Over the live 3D backdrop (main.gd): a soft shade on the left, where
	# the logo and the menu are.
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.draw.connect(func():
		var w := _shade.size.x
		var steps := 32
		for k in steps:
			var t := float(k) / steps
			_shade.draw_rect(Rect2(w * 0.6 * t, 0, w * 0.6 / steps + 1, _shade.size.y), Color(0.09, 0.07, 0.13, 0.62 * pow(1.0 - t, 1.6))))
	add_child(_shade)
	get_viewport().size_changed.connect(_fit)
	_logo.add_theme_constant_override("separation", 0)
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)
	var title := Kit.label("Startup Sim", 72, Kit.TEXT)
	title.add_theme_font_size_override("font_size", Kit.FS_HERO + 12)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_constant_override("shadow_outline_size", 10)
	title.add_theme_color_override("font_shadow_color", Color(0.1, 0.05, 0.15, 0.35))
	_logo.add_child(title)
	var sub := Kit.label("symulator pracy w startupie IT", 22, Kit.GOLD)
	sub.add_theme_constant_override("shadow_offset_y", 2)
	sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	_logo.add_child(sub)
	_card.add_theme_stylebox_override("panel", Kit.box("paper"))
	add_child(_card)
	var box := VBoxContainer.new()
	_card.add_child(box)
	_menu.add_theme_constant_override("separation", 12)
	box.add_child(_menu)
	for entry in [["Graj", func(): play.emit(), true], ["Ustawienia", func(): _show(_settings), false],
			["O grze", func(): _show(_about), false], ["Wyjdź", func(): quit.emit(), false]]:
		var b := Kit.button(entry[0], entry[2])
		b.custom_minimum_size = Vector2(300, 50)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(entry[1])
		_menu.add_child(b)
	_settings.visible = false
	_settings.back.connect(func(): _show(_menu))
	box.add_child(_settings)
	_about.visible = false
	_about.add_theme_constant_override("separation", 8)
	_about.add_child(Kit.label("O grze", 28, Kit.TEXT_INK))
	_about.add_child(Kit.label("Wersja %s" % Updates.current(), 20, Kit.TEXT_INK))
	for line in ["Startup Sim — prototyp gry o pracy w startupie IT.", "Serwer: Rust · klient: Godot 4 · własny protokół UDP.",
			"Czcionka: Nunito (The Nunito Project Authors), licencja SIL OFL.", "Grafika i kod narysowane w kodzie — bez gotowych assetów.",
			"Kod źródłowy (licencja AGPL-3.0): github.com/mateuszpalak/startup-sim"]:
		var l := Kit.label(line, 18, Kit.TEXT_INK, true)
		l.custom_minimum_size = Vector2(520, 0)
		_about.add_child(l)
	var back := Kit.button("Wróć")
	back.pressed.connect(func(): _show(_menu))
	_about.add_child(back)
	box.add_child(_about)
	# The installed version, bottom right.
	var version := Kit.label("wersja %s" % Updates.current(), 14, Color(Kit.TEXT, 0.8))
	version.add_theme_stylebox_override("normal", Kit.box("hud"))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.position -= Vector2(16, 12)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(version)
	_fit.call_deferred()


func _show(what: Control) -> void:
	for c in [_menu, _settings, _about]:
		c.visible = c == what
	_card.reset_size()
	_fit.call_deferred()


func _center_card() -> void:
	_card.reset_size()
	_logo.reset_size()
	var vs := get_viewport_rect().size
	var left := clampf(vs.x * 0.07, 24.0, 120.0)
	var top := clampf(vs.y * 0.1, 20.0, 110.0)
	_logo.position = Vector2(left, top)
	_card.position = Vector2(left, maxf(_logo.position.y + _logo.size.y + 24, (vs.y - _card.size.y) / 2 + 50))
	if _card.position.y + _card.size.y > vs.y - 12:
		_card.position.y = maxf(8.0, vs.y - _card.size.y - 12)
	if not _shown and is_visible_in_tree():
		_shown = true
		Kit.pop_in(_card, 0.96, 0.3)
		Kit.fade_in(_logo, 0.6)


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_shade.queue_redraw()
	_center_card()
