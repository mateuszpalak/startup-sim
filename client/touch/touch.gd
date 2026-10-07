## Touch mode: on by itself on phones and tablets (a touch screen, iOS,
## Android), forced on a desktop with `--touch` (the mouse then also acts as
## a finger). `--touch=phone` / `--touch=tablet` pretend the screen class;
## `--safe-area=l,t,r,b` pretends a notch (insets in window pixels).
##
## What it does here: the UI scale for small screens (`fit_ui`), the safe
## area in UI units (`safe_rect`), the minimum touch target and synthetic
## key presses for the on-screen buttons (`press` / `tap`): the game keeps
## its keyboard handling, a button just presses the same key.
extends RefCounted

static var active := false
## A phone-sized screen (the UI is scaled up, layouts go compact).
static var phone := false
static var _held := {}
## `--safe-area=l,t,r,b`: pretended insets (window pixels) on a desktop.
static var dev_insets := Rect2()

## Logical UI size of the screen's short side: phones get bigger UI.
const SHORT_PHONE := 520.0
const SHORT_TABLET := 720.0
## The smallest thing a finger should have to hit (~44 pt on a phone).
const TARGET := 58.0


static func setup(args: Dictionary) -> void:
	var forced := str(args.get("touch", "")) if args.has("touch") else ""
	active = args.has("touch") or OS.has_feature("ios") or OS.has_feature("android") \
		or (DisplayServer.is_touchscreen_available() and not OS.has_feature("editor") and _mobile_os())
	if not active:
		return
	if forced in ["phone", "tablet"]:
		phone = forced == "phone"
	else:
		phone = _screen_inches_short() < 4.2
	if args.has("safe-area"):
		var p: PackedStringArray = str(args["safe-area"]).split(",")
		if p.size() == 4:
			dev_insets = Rect2(float(p[0]), float(p[1]), float(p[2]), float(p[3]))
	if args.has("touch") and not _mobile_os():
		Input.emulate_touch_from_mouse = true


## (Same as client/platform/platform.gd is_mobile / can_quit on 2d-platforms;
## switch the callers to Platform.* once both branches are merged.)
static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android")


## iOS guidelines / Android: the system closes apps, no "Quit" button.
static func can_quit() -> bool:
	return not (OS.has_feature("ios") or OS.has_feature("android"))


static func _mobile_os() -> bool:
	return OS.get_name() in ["iOS", "Android"]


## Physical size of the screen's short side, in inches (a guess on desktops).
static func _screen_inches_short() -> float:
	var s := DisplayServer.screen_get_size()
	var dpi := DisplayServer.screen_get_dpi()
	if dpi <= 0:
		dpi = 160
	return minf(s.x, s.y) / float(dpi)


## Scale the UI so text and buttons have a finger's size: the short side of
## the window is SHORT_PHONE / SHORT_TABLET UI units. Call on every resize.
static func fit_ui(win: Window) -> void:
	if not active or win == null:
		return
	var size := Vector2(win.size)
	if size.x < 2 or size.y < 2:
		return
	var base := win.content_scale_size
	if base.x <= 0 or base.y <= 0:
		base = Vector2i(1280, 720)
	var base_scale := minf(size.x / base.x, size.y / base.y)
	var want := minf(size.x, size.y) / (SHORT_PHONE if phone else SHORT_TABLET)
	win.content_scale_factor = want / base_scale


## The part of the visible UI area not under a notch, rounded corners or
## the home indicator, in UI units (CanvasLayer coordinates).
static func safe_rect(vp: Viewport) -> Rect2:
	return safe_area(vp) if active else vp.get_visible_rect()


## The part of the screen nothing covers (notch / Dynamic Island, rounded
## corners, home indicator) in the viewport's coordinates. (A copy of
## client3d/platform/platform.gd `safe_area`; to share with client/platform
## once the 2D client has one.)
static func safe_area(vp: Viewport) -> Rect2:
	var vis := vp.get_visible_rect()
	var win := vp.get_window() if vp is not Window else vp as Window
	var wsize := Vector2(win.size) if win else vis.size
	var px_per := wsize.x / vis.size.x if vis.size.x > 0 else 1.0
	var ins := dev_insets
	if ins == Rect2() and _mobile_os():
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


## Press / release a key as if on a keyboard (both key codes, so
## `is_key_pressed` and `is_physical_key_pressed` both see it).
static func press(code: Key, down: bool) -> void:
	if down == _held.get(code, false):
		return
	_held[code] = down
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


## A short key press (down now, up a few frames later, so polling code
## that samples on physics ticks sees it too).
static func tap(code: Key, hold := 0.12) -> void:
	press(code, true)
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		tree.create_timer(hold).timeout.connect(func(): press(code, false))
	else:
		press(code, false)


static func is_held(code: Key) -> bool:
	return _held.get(code, false)


## Touch screens: centre a window in the safe area, shrunk to fit when it's
## taller / wider than the screen (no-op elsewhere).
static func place_center(c: Control, vp: Viewport) -> void:
	if not active:
		return
	var sr := safe_rect(vp).grow(-4)
	var sz := c.size.max(c.get_combined_minimum_size())
	if sz.x <= 0 or sz.y <= 0:
		return
	var s := minf(1.0, minf(sr.size.x / sz.x, sr.size.y / sz.y))
	c.pivot_offset = sz / 2  # (as Kit.pop_in has it)
	c.scale = Vector2(s, s)
	c.set_meta("fit_scale", s)
	c.position = (sr.get_center() - sz / 2).floor()


## Touch: the same words for the key or the finger.
static func say(keys: String, finger: String) -> String:
	return finger if active else keys


## Touch, a narrow (portrait) screen: the HUD stacks its top rows.
static func narrow(vp: Viewport) -> bool:
	return active and safe_rect(vp).size.x < 1000
