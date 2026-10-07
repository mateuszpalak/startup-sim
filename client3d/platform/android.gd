class_name AndroidPlatform
## Android-only glue, kept apart from the shared code (every entry point is a
## no-op elsewhere): the back button, the microphone permission and the emulator's
## host server (quality: platform.gd, pausing: main.gd).

const MIC_PERMISSION := "android.permission.RECORD_AUDIO"
## The machine running the emulator, as seen from inside it.
const EMULATOR_HOST_SERVER := {"name": "Serwer lokalny (emulator)", "address": "10.0.2.2:7777"}


static func active() -> bool:
	return OS.get_name() == "Android"


## Back button / gesture: behave like Esc (closes the open window, opens or
## closes the game menu) instead of quitting.
static func handle_back(what: int) -> bool:
	if not active() or what != Node.NOTIFICATION_WM_GO_BACK_REQUEST:
		return false
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_ESCAPE
		e.physical_keycode = KEY_ESCAPE
		e.pressed = pressed
		Input.parse_input_event(e)
	return true


## Asks for RECORD_AUDIO (once the player first uses voice chat). True when
## the microphone may be opened now; otherwise the system dialog is shown and
## the next push-to-talk opens it.
static func microphone_allowed() -> bool:
	if not active():
		return true
	if MIC_PERMISSION in OS.get_granted_permissions():
		return true
	OS.request_permission(MIC_PERMISSION)
	return false


## Extra servers offered on Android: the dev machine through the emulator.
static func extra_servers() -> Array:
	if active() and OS.is_debug_build():
		return [EMULATOR_HOST_SERVER]
	return []
