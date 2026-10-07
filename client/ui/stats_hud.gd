## Character needs (top right): a dark glass bar with the wallet and one
## ring gauge per need - the ring fills with the need's colour as it is
## fine and drains as it gets worse, a line icon in the middle; the number
## shows on hover (and when critical the gauge pulses and shows it anyway).
## Warnings (dirty hands, upset stomach) on a chip below. From the server's
## Stats.
extends Control

const Kit = preload("res://ui/ui_kit.gd")
const Touch = preload("res://touch/touch.gd")

## [name, true if high = bad, colour, icon (Kit.draw_icon)]
const ROWS := [
	["Głód", true, Color("#f08a4b"), "food"],
	["Energia", false, Color("#f4c542"), "energy"],
	["Stres", true, Color("#a985e6"), "brain"],
	["Toaleta", true, Color("#58a8ee"), "water"],
	["Higiena", false, Color("#4fc3b0"), "hygiene"],
	["Upojenie", true, Color("#f0b445"), "beer"],
	["Jelita", true, Color("#c08a62"), "toilet"],
	["Zdrowie", false, Color("#ef5d5d"), "health"],
]
const CRITICAL := 80
const SIZE := 48.0
const GAP := 8.0

var values := [0, 100, 0, 0, 100, 0, 0, 100]
var dirty_hands := false
var money := 0
var have := false
var _badges: Array[Control] = []
var _shown: Array[float] = []   # animated level of each ring
var _hover := -1
var _coin := Control.new()
var _note := Label.new()
var _bar := PanelContainer.new()
var _row := HBoxContainer.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_theme_stylebox_override("panel", Kit.box("hud"))
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	_row.add_theme_constant_override("separation", int(GAP))
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_row)
	_coin.custom_minimum_size = Vector2(118, SIZE)
	_coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin.draw.connect(_draw_coin)
	_row.add_child(_coin)
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(6, SIZE)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.draw.connect(func(): sep.draw_line(Vector2(3, 8), Vector2(3, SIZE - 8), Color(1, 1, 1, 0.14), 1.0))
	_row.add_child(sep)
	for i in ROWS.size():
		var b := Control.new()
		b.custom_minimum_size = Vector2(SIZE, SIZE)
		b.pivot_offset = Vector2(SIZE / 2, SIZE / 2)
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.tooltip_text = ROWS[i][0]
		var idx := i
		b.draw.connect(func(): _draw_badge(b, idx))
		b.mouse_entered.connect(func(): _set_hover(idx))
		b.mouse_exited.connect(func():
				if _hover == idx:
					_set_hover(-1))
		_row.add_child(b)
		_badges.append(b)
		_shown.append(-1.0)
	_note.add_theme_stylebox_override("normal", Kit.box("hud"))
	Kit.style_label(_note, 15, Kit.TEXT)
	_note.visible = false
	add_child(_note)
	visible = false
	get_viewport().size_changed.connect(_place)
	_bar.resized.connect(_place)
	_place.call_deferred()


func _place() -> void:
	var vs := get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	_bar.reset_size()
	var sr := Touch.safe_rect(get_viewport())
	_bar.position = Vector2(sr.end.x - _bar.size.x - 16, sr.position.y + 14)
	_bar.scale = Vector2.ONE
	if Touch.narrow(get_viewport()):  # portrait: a row of its own under the clock
		var k := minf(1.0, (sr.size.x - 24) / _bar.size.x)
		_bar.scale = Vector2(k, k)
		_bar.position = Vector2(sr.end.x - _bar.size.x * k - 12, sr.position.y + 66)
	_note.reset_size()
	_note.position = Vector2(sr.end.x - _note.size.x - 16, _bar.position.y + _bar.size.y * _bar.scale.y + 8)


func update_stats(p: Dictionary) -> void:
	values = [p.hunger, p.energy, p.stress, p.bladder, p.hygiene, p.alcohol, p.bowels, p.health]
	money = p.money
	dirty_hands = (p.stats_flags & 1) != 0
	var upset: bool = (p.stats_flags & 2) != 0
	var warn := ""
	if upset:
		warn = "Rozstrój żołądka — szybko do toalety!"
	elif dirty_hands:
		warn = "Brudne ręce — umyj je (umywalka / płyn)"
	if warn != "" and (_note.text != warn or not _note.visible):
		_note.text = warn
		_note.visible = true
		Kit.fade_in(_note)
	_note.text = warn
	_note.add_theme_color_override("font_color", Color("#ff9b8f") if upset else Kit.TEXT)
	_note.visible = warn != ""
	have = true
	visible = true
	_coin.queue_redraw()
	for b in _badges:
		b.queue_redraw()
	_place()


## 0 = fine .. 100 = terrible.
func badness(i: int) -> int:
	return values[i] if ROWS[i][1] else 100 - values[i]


func _set_hover(i: int) -> void:
	_hover = i
	for b in _badges:
		b.queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	var t := Time.get_ticks_msec() / 1000.0
	for i in _badges.size():
		var crit := badness(i) >= CRITICAL
		var pulse := 1.0 + (0.07 * sin(t * 7.0) if crit else 0.0)
		_badges[i].scale = Vector2(pulse, pulse)
		var want := clampf(1.0 - badness(i) / 100.0, 0.0, 1.0)
		if _shown[i] < 0:
			_shown[i] = want
		if absf(_shown[i] - want) > 0.002 or crit:
			_shown[i] = move_toward(_shown[i], want, delta * 0.8)
			_badges[i].queue_redraw()


func _draw_coin() -> void:
	var c := _coin
	var r := 15.0
	var center := Vector2(r + 2, SIZE / 2)
	c.draw_circle(center, r, Kit.GOLD, true, -1.0, true)
	c.draw_circle(center + Vector2(0, -1.5), r - 3, Kit.GOLD.lightened(0.2), true, -1.0, true)
	var f := Kit.font_bold()
	c.draw_string(f, center + Vector2(-8, 5), "zł", HORIZONTAL_ALIGNMENT_CENTER, 16, 13, Color("#8a5a10"))
	var txt := "%d,%02d" % [money / 100, money % 100]
	c.draw_string(f, Vector2(center.x + r + 8, center.y + 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Kit.TEXT)


## The ring gauge, the icon, and the number on hover / when critical.
func _draw_badge(b: Control, i: int) -> void:
	var c := Vector2(SIZE / 2, SIZE / 2)
	var col: Color = ROWS[i][2]
	var bad := badness(i)
	var crit := bad >= CRITICAL
	if crit:
		col = col.lerp(Kit.RED, 0.5 + 0.4 * sin(Time.get_ticks_msec() / 1000.0 * 7.0))
	var level: float = _shown[i] if _shown[i] >= 0 else 1.0 - bad / 100.0
	b.draw_circle(c, SIZE / 2 - 1, Color(0, 0, 0, 0.25), true, -1.0, true)
	if _hover == i:
		b.draw_circle(c, SIZE / 2 - 1, Color(col, 0.18), true, -1.0, true)
	Kit.draw_ring(b, c, SIZE / 2 - 4, 4.5, level, col, Color(1, 1, 1, 0.12))
	if _hover == i or crit:
		var f := Kit.font_bold()
		var txt := str(values[i])
		b.draw_string(f, Vector2(0, c.y + 6), txt, HORIZONTAL_ALIGNMENT_CENTER, SIZE, 17, Kit.TEXT)
	else:
		Kit.draw_icon(b, ROWS[i][3], c, 10.5, Color(Kit.TEXT, 0.95), 2.2)
