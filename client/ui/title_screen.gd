## The title screen: the game's name over an evening city with the office
## building, drifting clouds and windows lighting up; Graj / Ustawienia /
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
var _t := 0.0
# The backdrop in layers drawn once (again on resize): the sky, three groups
# of stars (twinkling = fading the group), five clouds (drifting = moving
# them), the city (its windows redrawn twice a second — they light up
# slowly). Re-recording draw calls every frame costs far more than moving.
var _sky := Control.new()
var _stars: Array[Control] = []
var _clouds: Array[Control] = []
var _city := Control.new()
var _city_t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var layers := [[_sky, _draw_sky]]
	for i in 3:
		var c := Control.new()
		_stars.append(c)
		layers.append([c, _draw_stars.bind(i)])
	for i in 5:
		var c := Control.new()
		_clouds.append(c)
		layers.append([c, _draw_cloud.bind(i)])
	layers.append([_city, _draw_city])
	for layer in layers:
		var c: Control = layer[0]
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.draw.connect(layer[1])
		add_child(c)
	_animate()
	get_viewport().size_changed.connect(_fit)
	_fit()
	var title := Kit.label("Startup Sim", 72, Kit.PAPER_HI)
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_outline_color", Kit.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-400, 60)
	title.size = Vector2(800, 110)
	add_child(title)
	var sub := Kit.label("symulator pracy w startupie IT", 24, Kit.GOLD)
	sub.add_theme_constant_override("outline_size", 8)
	sub.add_theme_color_override("font_outline_color", Kit.INK)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.position = Vector2(-400, 165)
	sub.size = Vector2(800, 40)
	add_child(sub)
	_card.add_theme_stylebox_override("panel", Kit.box("paper"))
	_card.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_card)
	var box := VBoxContainer.new()
	_card.add_child(box)
	_menu.add_theme_constant_override("separation", 12)
	box.add_child(_menu)
	for entry in [["Graj", func(): play.emit(), true], ["Ustawienia", func(): _show(_settings), false],
			["O grze", func(): _show(_about), false], ["Wyjdź", func(): quit.emit(), false]]:
		var b := Kit.button(entry[0], entry[2])
		b.custom_minimum_size = Vector2(320, 48)
		b.add_theme_font_size_override("font_size", 26)
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
			"Czcionka: Patrick Hand (Patrick Wagesreiter), licencja SIL OFL.", "Grafika i kod narysowane w kodzie — bez gotowych assetów.",
			"Kod źródłowy (licencja AGPL-3.0): github.com/mateuszpalak/startup-sim"]:
		var l := Kit.label(line, 18, Kit.TEXT_INK, true)
		l.custom_minimum_size = Vector2(520, 0)
		_about.add_child(l)
	var back := Kit.button("Wróć")
	back.pressed.connect(func(): _show(_menu))
	_about.add_child(back)
	box.add_child(_about)
	# The installed version, bottom right.
	var version := Kit.label("wersja %s" % Updates.current(), 16, Kit.PAPER_HI)
	version.add_theme_constant_override("outline_size", 6)
	version.add_theme_color_override("font_outline_color", Kit.INK)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.position -= Vector2(16, 12)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(version)
	_center_card.call_deferred()


func _show(what: Control) -> void:
	for c in [_menu, _settings, _about]:
		c.visible = c == what
	_card.reset_size()
	_center_card.call_deferred()


func _center_card() -> void:
	_card.reset_size()
	var vs := get_viewport_rect().size
	_card.position = Vector2((vs.x - _card.size.x) / 2, maxf(230.0, (vs.y - _card.size.y) / 2 + 60))


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	for c in [_sky, _city] + _stars + _clouds:
		c.queue_redraw()
	_center_card()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_animate()
		_city_t += delta
		if _city_t >= 0.5:
			_city_t = 0.0
			_city.queue_redraw()


## Evening sky.
func _draw_sky() -> void:
	var w := size.x
	var h := size.y
	var steps := 24
	for i in steps:
		var t := float(i) / steps
		var c := Color("#1f1a2e").lerp(Color("#5a3a4e"), t).lerp(Color("#b8735f"), maxf(0.0, t - 0.55) * 1.6)
		_sky.draw_rect(Rect2(0, h * t, w, h / steps + 1), c)


func _animate() -> void:
	for i in 3:
		_stars[i].modulate.a = 0.5 + 0.5 * sin(_t * 1.5 + i * TAU / 3.0)
	for k in 5:
		var cx := fmod(_t * (8.0 + k * 3.0) + k * 330.0, size.x + 400.0) - 200.0
		_clouds[k].position.x = cx


## Stars of one group (every third), at their brightest.
func _draw_stars(group: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 70:
		var sp := Vector2(rng.randf() * size.x, rng.randf() * size.y * 0.45)
		var r := rng.randf_range(0.8, 1.8)
		if k % 3 == group:
			_stars[group].draw_circle(sp, r, Color(1, 0.95, 0.85, 0.7))


## One cloud, drawn at x = 0 (moved by _animate).
func _draw_cloud(k: int) -> void:
	var cy := size.y * (0.18 + k * 0.07)
	for j in 4:
		_clouds[k].draw_circle(Vector2(j * 34.0, cy + sin(j) * 6.0), 30.0 + j % 2 * 10.0, Color(0.35, 0.28, 0.38, 0.35))


## The city, windows lighting up.
func _draw_city() -> void:
	var w := size.x
	var h := size.y
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 70:  # the stars' draws: the same buildings as before
		rng.randf()
		rng.randf()
		rng.randf()
	var x := 0.0
	var ground := h * 0.9
	while x < w:
		var bw := rng.randf_range(50, 120)
		var bh := rng.randf_range(120, 330)
		var r := Rect2(x, ground - bh, bw, bh + h)
		_city.draw_rect(r.grow(2), Kit.INK)
		_city.draw_rect(r, Color("#1c1622").lightened(rng.randf() * 0.05))
		var wy := r.position.y + 12
		while wy < ground - 10:
			var wx := r.position.x + 8
			while wx < r.end.x - 12:
				var seed_on := sin(wx * 12.9898 + wy * 78.233) * 43758.5453
				if fmod(absf(seed_on), 1.0) < 0.3 + 0.1 * sin(_t * 0.2 + wx):
					_city.draw_rect(Rect2(wx, wy, 7, 10), Color("#e8b85a", 0.9))
				wx += 16
			wy += 20
		x += bw + rng.randf_range(4, 20)
	_city.draw_rect(Rect2(0, ground, w, h - ground), Kit.INK)
