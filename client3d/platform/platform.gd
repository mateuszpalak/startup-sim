## What differs between the desktop and the phone: platform checks, the
## graphics quality profile (desktop / mobile), the screen's safe area (notch,
## Dynamic Island, home indicator), the on-screen keyboard and the
## microphone permission. Static only; everything else asks here instead of
## calling OS.get_name() itself.
extends RefCounted

## Quality profile: what the 3D world may cost. "mobile" on phones and
## tablets (the iOS export also carries the "mobile_quality" feature), else
## "desktop". --quality=mobile forces it on a desktop (to preview it).
static var forced_profile := ""


static func is_ios() -> bool:
	return OS.has_feature("ios")


static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android")


## Can the game offer a file to download and install (a .dmg)? Not on iOS
## (only the App Store / TestFlight install apps there).
static func can_self_update() -> bool:
	return not is_mobile()


static func profile() -> String:
	if forced_profile != "":
		return forced_profile
	return "mobile" if is_mobile() or OS.has_feature("mobile_quality") else "desktop"


static func low_end() -> bool:
	return profile() == "mobile"


## Quality knobs read by the 3D world (lighting_3d, weather_3d, smoke_3d,
## Settings.effective_render_scale).
static func quality() -> Dictionary:
	if low_end():
		return {
			"render_scale": 0.67,        # of the native resolution, FSR upscaled
			"ssao": false,               # not in the Mobile renderer anyway
			"glow": true,
			"sun_shadow_splits": 1,      # one cascade (orthogonal)
			"sun_shadow_distance": 35.0,
			"rain_max": 1800,
			"splash_max": 300,
			"wisps": 40,
			"smoke_max": 90,
			"radiance_size": Sky.RADIANCE_SIZE_32,
		}
	return {
		"render_scale": 0.0,             # automatic (Settings)
		"ssao": true,
		"glow": true,
		"sun_shadow_splits": 2,
		"sun_shadow_distance": 55.0,
		"rain_max": 5000,
		"splash_max": 900,
		"wisps": 120,
		"smoke_max": 220,
		"radiance_size": Sky.RADIANCE_SIZE_64,
	}


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


## The running renderer: "forward_plus", "mobile" or "gl_compatibility".
static func renderer() -> String:
	return RenderingServer.get_current_rendering_method()


## SSAO exists only in Forward+.
static func supports_ssao() -> bool:
	return renderer() == "forward_plus"


## FSR 1 upscaling: Forward+ and Mobile, not Compatibility (OpenGL).
static func supports_fsr() -> bool:
	return renderer() != "gl_compatibility"


## The mobile profile's viewport and shadow settings (Android and iOS, or
## --quality=mobile on a desktop), before the saved settings take over.
static func apply_quality(vp: Viewport) -> void:
	if not low_end():
		return
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size(2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)


## Android and iOS: no "quit" button (iOS guidelines; Android leaves apps
## with Home / Back).
static func can_quit() -> bool:
	return not (OS.has_feature("ios") or OS.has_feature("android"))
