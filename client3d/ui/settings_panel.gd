## The settings (title screen and the Esc menu): full screen, battery
## saving, crash reports, the camera zoom, the 3D resolution, sound volumes, the microphone,
## the gamepad.
## Changes apply and save at once. The options scroll when the window is
## short; "Wróć" stays visible under them.
extends VBoxContainer

const Kit = preload("res://ui/ui_kit.gd")
const Settings = preload("res://ui/settings.gd")
const Touch = preload("res://touch/touch.gd")
const Platform = preload("res://platform/platform.gd")

signal changed
signal back

var _full := CheckButton.new()
var _battery := CheckButton.new()
var _crashes := CheckButton.new()
var _zoom := HSlider.new()
var _zoom_label := Label.new()
var _scroll := ScrollContainer.new()
var _content := VBoxContainer.new()


func _ready() -> void:
	Settings.load_once()
	add_theme_constant_override("separation", 10)
	add_child(Kit.label("Ustawienia", 28, Kit.TEXT_INK))
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_content.add_theme_constant_override("separation", 10)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	for pair in [[_full, "Pełny ekran"], [_battery, "Oszczędzanie baterii (30 klatek/s)"],
			[_crashes, "Wysyłaj raporty awarii bez pytania"]]:
		var cb: CheckButton = pair[0]
		cb.text = pair[1]
		_style_check(cb)
		_content.add_child(cb)
	_full.visible = not Platform.is_mobile()  # always full screen there
	_full.button_pressed = Settings.fullscreen
	_battery.button_pressed = Settings.battery
	_crashes.button_pressed = Settings.crash_reports_always
	_crashes.toggled.connect(func(on: bool):
		Settings.crash_reports_always = on
		_save())
	_battery.toggled.connect(func(on: bool):
		Settings.battery = on
		Settings.apply_fps()
		_save())
	_full.toggled.connect(func(on: bool):
		Settings.fullscreen = on
		Settings.apply_window()
		_save())
	var zr := HBoxContainer.new()
	zr.add_theme_constant_override("separation", 12)
	Kit.style_label(_zoom_label, 18, Kit.TEXT_INK)
	_zoom_label.custom_minimum_size = Vector2(210, 0)
	zr.add_child(_zoom_label)
	_zoom.min_value = 0.6
	_zoom.max_value = 2.0
	_zoom.step = 0.1
	_zoom.value = Settings.zoom
	_size_slider(_zoom)
	_zoom.value_changed.connect(func(v: float):
		Settings.zoom = v
		_update_zoom_label()
		_save())
	zr.add_child(_zoom)
	_content.add_child(zr)
	_update_zoom_label()
	_content.add_child(Kit.label("W grze: rozsuń / zsuń dwa palce — przybliżenie na chwilę, obróć dwoma palcami — kamera." if Touch.active
		else "W grze: kółko myszy albo + / - zmienia przybliżenie na chwilę.", 16, Kit.TEXT_MUTED, true))
	if Touch.active:
		_touch_rows()
	_render_row()
	_volume("Efekty", Settings.vol_sfx, func(v: float): Settings.vol_sfx = v)
	_volume("Otoczenie", Settings.vol_ambient, func(v: float): Settings.vol_ambient = v)
	_volume("Muzyka", Settings.vol_music, func(v: float): Settings.vol_music = v)
	_volume("Głosy graczy", Settings.vol_voice, func(v: float): Settings.vol_voice = v)
	var mr := HBoxContainer.new()
	mr.add_theme_constant_override("separation", 12)
	var ml := Kit.label("Mikrofon:", 18, Kit.TEXT_INK)
	ml.custom_minimum_size = Vector2(210, 0)
	mr.add_child(ml)
	var mic := OptionButton.new()
	mic.custom_minimum_size = Vector2(220, 48 if Touch.active else 0)
	mic.clip_text = true
	for d in AudioServer.get_input_device_list():
		mic.add_item("Domyślny systemu" if d == "Default" else d)
		mic.set_item_metadata(mic.item_count - 1, d)
		if d == Settings.mic_device:
			mic.select(mic.item_count - 1)
	mic.item_selected.connect(func(i: int):
		Settings.mic_device = mic.get_item_metadata(i)
		Settings.apply_audio()
		_save())
	mr.add_child(mic)
	_content.add_child(mr)
	_content.add_child(Kit.label("Czat głosowy: trzymaj „Mów” (stuknięcie włącza na stałe), „Szept” — do osoby obok." if Touch.active
		else "Czat głosowy: trzymaj V — mówisz do pomieszczenia, B — szept do osoby obok.", 16, Kit.TEXT_MUTED, true))
	_pad_rows()
	if Touch.active:
		for c in _content.get_children():
			if c is Label:
				c.custom_minimum_size.x = 420
	var b := Kit.button("Wróć")
	if Touch.active:
		b.custom_minimum_size.y = Touch.TARGET
	b.pressed.connect(func(): back.emit())
	add_child(b)
	get_viewport().size_changed.connect(_fit_height)
	visibility_changed.connect(_fit_height)
	_fit_height.call_deferred()


## The options as tall as they are - or as fits the window (then they
## scroll); the title above and "Wróć" below always show.
func _fit_height() -> void:
	var want := _content.get_combined_minimum_size()
	var room := get_viewport_rect().size.y - fixed_height
	_scroll.custom_minimum_size = Vector2(want.x, clampf(want.y, 120.0, maxf(room, 120.0)))
	reset_size()


## Height around the options: the title screen's logo, the card's margins,
## "Ustawienia" and "Wróć".
var fixed_height := 400.0


## Touch controls: joystick side, button size and opacity.
func _touch_rows() -> void:
	_content.add_child(Kit.label("Sterowanie dotykiem", 20, Kit.TEXT_INK))
	var side := CheckButton.new()
	side.text = "Joystick po prawej (akcje po lewej)"
	_style_check(side)
	side.button_pressed = not Settings.touch_left
	side.toggled.connect(func(on: bool):
		Settings.touch_left = not on
		_save())
	_content.add_child(side)
	_slider_row("Wielkość przycisków", Settings.touch_size, 0.8, 1.4, func(v: float): Settings.touch_size = v)
	_slider_row("Widoczność przycisków", Settings.touch_opacity, 0.3, 1.0, func(v: float): Settings.touch_opacity = v)


## Gamepad: invert the zoom stick, stick speed, rumble.
func _pad_rows() -> void:
	_content.add_child(Kit.label("Pad", 20, Kit.TEXT_INK))
	for row in [["Odwróć oś Y prawej gałki (przybliżenie)", Settings.pad_invert_y, func(on: bool): Settings.pad_invert_y = on],
			["Wibracje", Settings.pad_vibration, func(on: bool): Settings.pad_vibration = on]]:
		var cb := CheckButton.new()
		cb.text = row[0]
		_style_check(cb)
		cb.button_pressed = row[1]
		var set_it: Callable = row[2]
		cb.toggled.connect(func(on: bool):
			set_it.call(on)
			_save())
		_content.add_child(cb)
	_slider_row("Czułość gałki", Settings.pad_sensitivity, 0.4, 2.0, func(v: float): Settings.pad_sensitivity = v)


func _style_check(cb: CheckButton) -> void:
	cb.add_theme_font_override("font", Kit.font())
	cb.add_theme_font_size_override("font_size", 20)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		cb.add_theme_color_override(k, Kit.TEXT_INK)
	if Touch.active:
		cb.custom_minimum_size.y = 48


## A percent slider row.
func _slider_row(title: String, value: float, lo: float, hi: float, set_value: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := Kit.label("", 18, Kit.TEXT_INK)
	l.custom_minimum_size = Vector2(210, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	_size_slider(s)
	var show := func(v: float): l.text = "%s: %d%%" % [title, roundi(v * 100)]
	show.call(value)
	s.value_changed.connect(func(v: float):
		set_value.call(v)
		show.call(v)
		_save())
	row.add_child(s)
	_content.add_child(row)


## Sliders: a finger-sized hit area on touch screens.
static func _size_slider(s: HSlider) -> void:
	s.custom_minimum_size = Vector2(220, 48 if Touch.active else 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## A volume slider row (0..100 %).
func _volume(title: String, value: float, set_value: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := Kit.label("", 18, Kit.TEXT_INK)
	l.custom_minimum_size = Vector2(210, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	_size_slider(s)
	var show := func(v: float): l.text = "%s: %d%%" % [title, roundi(v * 100)]
	show.call(value)
	s.value_changed.connect(func(v: float):
		set_value.call(v)
		show.call(v)
		Settings.apply_audio()
		_save())
	row.add_child(s)
	_content.add_child(row)


## 3D quality: "Auto" (left end) or 50..100 % of the screen's resolution.
func _render_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := Kit.label("", 18, Kit.TEXT_INK)
	l.custom_minimum_size = Vector2(210, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.45  # = auto
	s.max_value = 1.0
	s.step = 0.05
	s.value = Settings.render_scale if Settings.render_scale > 0.0 else 0.45
	_size_slider(s)
	var show := func(v: float):
		if v < 0.49:
			l.text = "Rozdzielczość 3D: auto (%d%%)" % roundi(Settings.effective_render_scale() * 100)
		else:
			l.text = "Rozdzielczość 3D: %d%%" % roundi(v * 100)
	show.call(s.value)
	s.value_changed.connect(func(v: float):
		Settings.render_scale = 0.0 if v < 0.49 else v
		show.call(v)
		Settings.apply_render(get_viewport())
		_save())
	row.add_child(s)
	_content.add_child(row)
	var upscaler := "FSR" if Platform.supports_fsr() else "skalowanie"
	_content.add_child(Kit.label("Niższa = płynniej (obraz skalowany przez %s, napisy zostają ostre)." % upscaler, 16, Kit.TEXT_MUTED))


func _update_zoom_label() -> void:
	_zoom_label.text = "Przybliżenie kamery: %.1f×" % Settings.zoom


func _save() -> void:
	Settings.save()
	changed.emit()
