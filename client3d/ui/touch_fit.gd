## Menus on touch screens: a centred form goes into a scroll view kept
## inside the safe area, so a tall form scrolls (finger drag) instead of
## falling off a phone screen. Off touch screens: nothing changes.
extends RefCounted

const Touch = preload("res://touch/touch.gd")


## `center` (a full-rect CenterContainer already added to `owner`) is moved
## into a ScrollContainer that fills the safe area.
static func scroll_center(owner: Control, center: Control) -> void:
	if not Touch.active:
		return
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center.get_parent().remove_child(center)
	owner.add_child(sc)
	sc.add_child(center)
	center.set_anchors_preset(Control.PRESET_TOP_LEFT)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fit := func():
		var r := Touch.safe_rect(owner.get_viewport())
		sc.position = r.position - owner.global_position
		sc.size = r.size
		center.custom_minimum_size = Vector2(0, r.size.y)
	owner.get_viewport().size_changed.connect(fit)
	fit.call()
