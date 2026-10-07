## Notifications in the corner (under the stats): a glass toast per event -
## new mail, treats in the chill room, somebody knocked out next to you...
## Each stays a few seconds; at most a few at once (the oldest go first).
extends VBoxContainer

const Kit = preload("res://ui/ui_kit.gd")
const Touch = preload("res://touch/touch.gd")

const SHOW_SEC := 7.0
const MAX_SHOWN := 4
## Notice.icon -> a symbol (the text log).
const SYMBOLS := {1: "ℹ", 2: "✉", 3: "🍽", 4: "⚠", 5: "★"}
## Notice.icon -> [Kit icon, colour].
const ICONS := {1: ["bell", Color("#4a9be0")], 2: ["mail", Color("#e8744f")], 3: ["food", Color("#f0a04b")],
	4: ["close", Color("#e0524f")], 5: ["star", Color("#f4b740")]}

var history: Array[String] = []  # every notice of the session (tests, the log)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	custom_minimum_size = Vector2(360, 0)
	get_viewport().size_changed.connect(_place)
	_place()


## Top right, under the stats (a CanvasLayer has no anchors to lean on).
func _place() -> void:
	var sr := Touch.safe_rect(get_viewport())
	position = Vector2(sr.end.x - 376, sr.position.y + (150 if Touch.active else 120) + (100 if Touch.narrow(get_viewport()) else 0))


func push(icon: int, text: String) -> void:
	history.append(text)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Kit.box("hud"))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var spec: Array = ICONS.get(icon, ["bell", Kit.BLUE])
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(32, 32)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.draw.connect(func():
		badge.draw_circle(Vector2(16, 16), 16, spec[1], true, -1.0, true)
		Kit.draw_icon(badge, spec[0], Vector2(16, 16), 9.0, Color.WHITE, 2.0))
	row.add_child(badge)
	var l := Label.new()
	Kit.style_label(l, 15, Color("#ffb4a8") if icon == 4 else Kit.TEXT)
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(290, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	add_child(card)
	Kit.fade_in(card, 0.3)
	while get_child_count() > MAX_SHOWN:
		var old := get_child(0)
		remove_child(old)
		old.queue_free()
	get_tree().create_timer(SHOW_SEC).timeout.connect(func():
		if is_instance_valid(card):
			var t := card.create_tween()
			t.tween_property(card, "modulate:a", 0.0, 0.35)
			t.tween_callback(card.queue_free))
