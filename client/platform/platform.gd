## What differs between the desktop and the phone: platform checks, the
## screen's safe area (notch, Dynamic Island, home indicator), the on-screen
## keyboard and the microphone permission. Static only; everything else asks
## here instead of calling OS.get_name() itself.
extends RefCounted

static func is_ios() -> bool:
	return OS.has_feature("ios")


static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android")


## Can the game offer a file to download and install (a .dmg, zip or
## Android apk)? Not on iOS (only the App Store / TestFlight install apps
## there).
static func can_self_update() -> bool:
	return not is_ios()


## Pretended screen insets (left, top, right, bottom in window pixels) from
## `--safe-area=l,t,r,b`: previews a notch on a desktop.
static var dev_insets := Rect2()


## The part of the screen nothing covers (notch / Dynamic Island, rounded
## corners, home indicator), in the viewport's coordinates (after the
## canvas_items stretch) - put touch buttons and HUD edges inside it. On
## desktops: the whole viewport (unless --safe-area pretends a notch).
static func safe_area(vp: Viewport) -> Rect2:
	var vis := vp.get_visible_rect()
	var win := vp.get_window() if vp is not Window else vp as Window
	var wsize := Vector2(win.size) if win else vis.size
	var px_per := wsize.x / vis.size.x if vis.size.x > 0 else 1.0
	var ins := dev_insets
	if ins == Rect2() and is_mobile():
		var safe := Rect2(DisplayServer.get_display_safe_area())
		var full := Rect2(Vector2(DisplayServer.window_get_position()), wsize)
		if safe.size.x > 0 and safe.size.y > 0:
			ins = Rect2(maxf(safe.position.x - full.position.x, 0), maxf(safe.position.y - full.position.y, 0),
				maxf(full.end.x - safe.end.x, 0), maxf(full.end.y - safe.end.y, 0))
	var l := ins.position.x / px_per
	var t := ins.position.y / px_per
	var r := ins.size.x / px_per
	var b := ins.size.y / px_per
	return Rect2(vis.position + Vector2(l, t), vis.size - Vector2(l + r, t + b))


## Margins of the safe area from each edge (left, top, right, bottom).
static func safe_margins(vp: Viewport) -> Dictionary:
	var v := vp.get_visible_rect()
	var s := safe_area(vp)
	return {"left": s.position.x - v.position.x, "top": s.position.y - v.position.y,
		"right": v.end.x - s.end.x, "bottom": v.end.y - s.end.y}


## Phones: show the system keyboard for a text field that got focus (Godot
## does it for LineEdit/TextEdit with virtual_keyboard_enabled; this is for
## custom fields). No-op where there is no virtual keyboard.
static func show_keyboard(text := "", multiline := false) -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		var kind := DisplayServer.KEYBOARD_TYPE_MULTILINE if multiline else DisplayServer.KEYBOARD_TYPE_DEFAULT
		DisplayServer.virtual_keyboard_show(text, Rect2(), kind)


static func hide_keyboard() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()


## Height of the on-screen keyboard in viewport units (0 when hidden): move
## a focused text field above it.
static func keyboard_height(vp: Viewport) -> float:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return 0.0
	var h := DisplayServer.virtual_keyboard_get_height()
	var screen := DisplayServer.screen_get_size()
	if h <= 0 or screen.y <= 0:
		return 0.0
	return h * vp.get_visible_rect().size.y / float(screen.y)


## Microphone: Android needs a runtime permission (RECORD_AUDIO, asked
## here; the next push-to-talk opens it); iOS and macOS ask by themselves the
## first time AudioStreamMicrophone starts. True = go ahead.
static func request_microphone() -> bool:
	return AndroidPlatform.microphone_allowed()


## Android and iOS: no "quit" button (iOS guidelines; Android leaves apps
## with Home / Back).
static func can_quit() -> bool:
	return not (OS.has_feature("ios") or OS.has_feature("android"))
