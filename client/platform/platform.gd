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


## The part of the screen nothing covers (notch / Dynamic Island, rounded
## corners, home indicator), in the root viewport's coordinates (after the
## canvas_items stretch) - put touch buttons and HUD edges inside it. On
## desktops: the whole viewport.
static func safe_area(vp: Viewport) -> Rect2:
	var visible := vp.get_visible_rect()
	if not is_mobile():
		return visible
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if safe.size.x <= 0 or screen.x <= 0:
		return visible
	# Window pixels -> viewport units (the stretch scales uniformly).
	var k := visible.size.x / float(screen.x)
	return Rect2(visible.position + Vector2(safe.position) * k, Vector2(safe.size) * k)


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


## Microphone: Android needs a runtime permission (RECORD_AUDIO); iOS asks
## by itself the first time AudioStreamMicrophone starts (text from
## NSMicrophoneUsageDescription) and macOS likewise. True = go ahead.
static func request_microphone() -> bool:
	if OS.has_feature("android"):
		if not OS.get_granted_permissions().has("android.permission.RECORD_AUDIO"):
			OS.request_permission("android.permission.RECORD_AUDIO")
			return false
	return true
