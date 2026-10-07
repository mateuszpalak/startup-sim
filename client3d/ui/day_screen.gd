## Full-screen day cards (game time from the server's Clock packet):
## - at home for the night: "Koniec dnia" with the hours worked and the pay,
## - on the way to work: "Dzień N" with the arrival time,
## - a short "Dzień N" card whenever the personal day number goes up.
extends Control

const Kit = preload("res://ui/ui_kit.gd")
const Touch = preload("res://touch/touch.gd")

const Protocol = preload("res://net/protocol.gd")

const CARD_SEC := 3.5
## How to get to work (server/src/commute.rs): id -> [name, minutes, grosze].
const MODES := {1: ["Pieszo", 45, 0], 2: ["Rower", 25, 0], 3: ["Samochód", 20, 1200], 4: ["Taksówka", 15, 3500], 5: ["Tramwaj", 30, 440]}
const MODE_NOTES := {1: "zmęczy, ale odpręży", 2: "szybko, ale spocisz się", 3: "+ korki do 20 min", 4: "wygodnie", 5: "tłok, stres"}

signal choose_commute(mode: int)
## "Pomiń czekanie" (SkipWait): starts a vote of everybody playing.
signal skip_wait
## The answer to someone else's vote (0 = yes, 1 = no).
signal vote(choice: int)

var clock := {}           # last Clock packet
var _day := 0             # personal day already announced
var _card_until := 0.0    # transient card visible until (seconds, engine time)
var _bg := ColorRect.new()
var _title := Label.new()
var _sub := Label.new()
var _info := Label.new()
var _sky := Control.new()
var _modes := HFlowContainer.new()  # wraps on a narrow (upright) phone
var _mode_buttons := {}   # mode -> Button
var _skip := Kit.button("Pomiń czekanie  »", true)
var _vote := PanelContainer.new()
var _vote_text := Label.new()
var _vote_row := HBoxContainer.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	get_viewport().size_changed.connect(_fit)
	add_child(_bg)
	_sky.draw.connect(_draw_sky)
	add_child(_sky)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	for l in [_title, _sub, _info]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_constant_override("shadow_offset_y", 3)
		l.add_theme_constant_override("shadow_outline_size", 6)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
		if Touch.active:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
	_title.add_theme_font_override("font", Kit.font_bold())
	_sub.add_theme_font_override("font", Kit.font_bold())
	_title.add_theme_font_size_override("font_size", 64)
	_sub.add_theme_font_size_override("font_size", 24)
	_info.add_theme_font_size_override("font_size", 20)
	_info.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_modes.alignment = FlowContainer.ALIGNMENT_CENTER
	_modes.add_theme_constant_override("h_separation", 10)
	_modes.add_theme_constant_override("v_separation", 10)
	col.add_child(_modes)
	for id in MODES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 84)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 16)
		var m: int = id
		b.pressed.connect(func(): choose_commute.emit(m))
		_modes.add_child(b)
		_mode_buttons[id] = b
	_modes.visible = false
	var skip_row := CenterContainer.new()
	col.add_child(skip_row)
	_skip.custom_minimum_size = Vector2(260, 48)
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.pressed.connect(func(): skip_wait.emit())
	skip_row.add_child(_skip)
	_skip.visible = false
	# Someone else's "skip the waiting": a vote.
	var vote_row := CenterContainer.new()
	col.add_child(vote_row)
	_vote.add_theme_stylebox_override("panel", Kit.box("paper"))
	_vote.custom_minimum_size = Vector2(560, 0)
	vote_row.add_child(_vote)
	var vcol := VBoxContainer.new()
	vcol.add_theme_constant_override("separation", 10)
	_vote.add_child(vcol)
	Kit.style_label(_vote_text, 18, Kit.TEXT_INK)
	_vote_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vote_text.custom_minimum_size = Vector2(520, 0)
	vcol.add_child(_vote_text)
	_vote_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_vote_row.add_theme_constant_override("separation", 12)
	vcol.add_child(_vote_row)
	_vote.visible = false
	_fit()


## A vote from the server (Dialog 249), or 0: it's over / answered.
func on_vote(p: Dictionary) -> void:
	if p.id != Protocol.DIALOG_VOTE:
		_vote.visible = false
		return
	_vote_text.text = p.text
	for c in _vote_row.get_children():
		c.queue_free()
	for i in p.options.size():
		var b := Kit.button(p.options[i], i == 0)
		b.focus_mode = Control.FOCUS_NONE
		var choice: int = i
		b.pressed.connect(func(): vote.emit(choice); _vote.visible = false)
		_vote_row.add_child(b)
	_vote.visible = true


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_bg.size = size
	_sky.size = size
	if Touch.active:  # an upright phone: the vote card fits the width
		var w := minf(560.0, size.x - 32.0)
		_vote.custom_minimum_size.x = w
		_vote_text.custom_minimum_size.x = w - 40.0
		_title.add_theme_font_size_override("font_size", 48 if size.x < 700 else 64)


static func hhmm(m: int) -> String:
	return "%02d:%02d" % [(m / 60) % 24, m % 60]


static func duration(minutes: int) -> String:
	return "%d h %02d min" % [minutes / 60, minutes % 60]


## True while the player can't play (at home / commuting): block input.
func blocking() -> bool:
	return visible and clock.get("place", 0) in [Protocol.PLACE_HOME, Protocol.PLACE_COMMUTING]


func on_clock(p: Dictionary) -> void:
	clock = p
	if p.day > _day:
		# A new personal day: show its card for a moment (unless a full-screen
		# home / commuting card shows the day anyway).
		_day = p.day
		_card_until = Time.get_ticks_msec() / 1000.0 + CARD_SEC
	_render()


func _process(_d: float) -> void:
	if visible and _card_until > 0.0 and Time.get_ticks_msec() / 1000.0 > _card_until:
		_card_until = 0.0
		_render()
	if visible:
		_sky.queue_redraw()


func _render_modes() -> void:
	for id in _mode_buttons:
		var m: Array = MODES[id]
		var b: Button = _mode_buttons[id]
		var cost := "za darmo" if m[2] == 0 else "%d,%02d zł" % [m[2] / 100, m[2] % 100]
		b.text = "%s\n%d min · %s\n%s" % [m[0], m[1], cost, MODE_NOTES[id]]
		b.disabled = m[2] > clock.money
		var chosen: bool = id == clock.mode
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, Kit.button_box(st, chosen) if chosen else (Kit.box("glass_hover") if st == "hover" else Kit.box("glass_card")))
		var fc := Color.WHITE
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(k, fc)
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))


func _render() -> void:
	if clock.is_empty():
		return
	_modes.visible = clock.place == Protocol.PLACE_COMMUTING and clock.arrive == Protocol.NO_TIME
	# Skip the waiting (home / before leaving / on the way): once everybody
	# at home asked, time flies.
	_skip.visible = clock.place in [Protocol.PLACE_HOME, Protocol.PLACE_COMMUTING]
	var skip: int = clock.get("skip", 0)
	_skip.disabled = skip != 0
	_skip.text = ["Pomiń czekanie  »", "Głosowanie trwa…", "Czas leci…  »»"][clampi(skip, 0, 2)]
	var place: int = clock.place
	var now := Time.get_ticks_msec() / 1000.0
	match place:
		Protocol.PLACE_HOME:
			visible = true
			_bg.color = Color("#0d1330") if clock.night else Color("#5b7fa8")
			_title.text = "Koniec dnia" if clock.pay_minutes > 0 else "Noc"
			if clock.pay_minutes > 0:
				_sub.text = "Przepracowane: %s · wypłata %d,%02d zł" % [duration(clock.pay_minutes), clock.pay / 100, clock.pay % 100]
			else:
				_sub.text = "Biuro zamknięte do rana."
			if clock.night:
				_info.text = "Noc… Teraz %s — nowy dzień zaczyna się o 06:00." % hhmm(clock.minute)
			elif clock.get("leave", false):
				# A day off (the HR app): at home until tomorrow morning.
				_title.text = "Urlop 🌴"
				_sub.text = "Dzień wolny — odpoczywasz w domu (na umowie o pracę płatny)."
				_info.text = "Teraz %s. Do biura jutro rano." % hhmm(clock.minute)
			else:
				# Home early: the day goes on for the others (fast if nobody works).
				_title.text = "W domu"
				_info.text = "Teraz %s. Do biura znowu rano — gdy wszyscy są w domu, czas leci szybciej." % hhmm(clock.minute)
		Protocol.PLACE_COMMUTING:
			visible = true
			_bg.color = Color("#d8906c")
			_title.text = "Dzień %d" % clock.day
			var name: String = MODES.get(clock.mode, ["?"])[0]
			if clock.arrive == Protocol.NO_TIME:
				# Still at home: choose how to get there.
				_sub.text = "Jak dziś dojeżdżasz? Wyjazd o %s" % hhmm(clock.depart)
				_info.text = "Teraz %s · pogoda: %s · w portfelu %d,%02d zł · wybrano: %s" % [hhmm(clock.minute), Protocol.WEATHER_NAMES.get(clock.weather, "?"), clock.money / 100, clock.money % 100, name.to_lower()]
				_render_modes()
			else:
				_sub.text = "W drodze (%s)… przyjazd o %s" % [name.to_lower(), hhmm(clock.arrive)]
				_info.text = "Teraz %s" % hhmm(clock.minute)
		_:
			# A short day card over the world / the portal.
			visible = _card_until > now
			_bg.color = Color(0.05, 0.06, 0.1, 0.85)
			_title.text = "Dzień %d" % clock.day
			if place == Protocol.PLACE_PORTAL:
				_sub.text = "Szukasz pracy — przejrzyj ogłoszenia w przeglądarce."
			elif clock.day <= 2:
				_sub.text = "Pierwszy dzień w pracy!"
			else:
				_sub.text = "Kolejny dzień w pracy."
			_info.text = hhmm(clock.minute)


## The sky over the whole card: a smooth gradient from the base colour,
## the sun with a soft glow (moon and stars at night) and low-poly hills
## along the bottom (as in the 3D world); not over the short day card.
func _draw_sky() -> void:
	var place: int = clock.get("place", -1)
	if place not in [Protocol.PLACE_HOME, Protocol.PLACE_COMMUTING]:
		return
	var w := size.x
	var h := size.y
	var base := _bg.color
	var night: bool = place == Protocol.PLACE_HOME and clock.get("night", true)
	var top := base.darkened(0.25)
	var horizon := base.lightened(0.35) if not night else base.lightened(0.12)
	_sky.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.75), Vector2(0, h * 0.75)]),
		PackedColorArray([top, top, horizon, horizon]))
	_sky.draw_rect(Rect2(0, h * 0.75 - 1, w, h * 0.25 + 1), horizon)
	var c := Vector2(w * 0.74, h * 0.24 + (40.0 if place == Protocol.PLACE_COMMUTING else 0.0))
	if night:
		for i in 40:
			var sp := Vector2(fmod(i * 197.0 + 31, w), fmod(i * 83.0 + 17, h * 0.55))
			_sky.draw_circle(sp, 1.0 + fmod(i * 0.37, 1.0), Color(1, 1, 1, 0.3 + 0.5 * fmod(i * 0.37, 1.0)), true, -1.0, true)
		for k in 4:
			_sky.draw_circle(c, 36.0 + k * 14.0, Color(1, 1, 0.9, 0.05), true, -1.0, true)
		Kit.draw_disc(_sky, c, 36, Color("#f4f1c9"))
		Kit.draw_disc(_sky, c + Vector2(14, -8), 32, top.lerp(base, 0.3))
	else:
		for k in 5:
			_sky.draw_circle(c, 44.0 + k * 22.0, Color(1, 0.92, 0.7, 0.07), true, -1.0, true)
		Kit.draw_disc(_sky, c, 44, Color("#ffd98a"))
	# Hills: three faceted ridges, nearer = darker and greener.
	var cols := [base.lerp(Color("#9c8fc4"), 0.5), base.lerp(Color("#6f9fb0"), 0.55), base.lerp(Color("#5d9a7a"), 0.65)]
	if night:
		cols = cols.map(func(col): return col.darkened(0.45))
	for layer in 3:
		var pts := PackedVector2Array([Vector2(0, h)])
		var x := 0.0
		var k := 0
		while x < w + 80:
			var y := h * (0.72 + layer * 0.08) + sin(k * 1.7 + layer * 2.1) * 22.0 + cos(k * 0.9 + layer) * 14.0
			pts.append(Vector2(x, y))
			x += 90.0 + fmod(k * 37.0 + layer * 11.0, 60.0)
			k += 1
		pts.append(Vector2(w + 80, h))
		_sky.draw_colored_polygon(pts, cols[layer])
