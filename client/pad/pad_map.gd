## Gamepad bindings (2D client): one table for the whole game (the place to remap, or
## to swap for a console's own layout). Each game action has the keyboard
## key the game already handles and the pad buttons / axes that stand for
## it; `register()` puts them into Godot's InputMap as "pad_<action>"
## actions. pad.gd turns a pad press into that key, as touch/touch.gd does
## for the on-screen buttons: the game keeps one input path, the movement
## bits (and so the prediction) stay exactly what the keyboard sends.
##
## Buttons follow SDL's positional names (JOY_BUTTON_A = the bottom face
## button: A on Xbox / Steam Deck, Cross on PlayStation, B on Switch).
extends RefCounted

## The radial dead zone of the sticks and when a trigger counts as held.
const DEADZONE := 0.35
const TRIGGER := 0.5

## action -> {key, buttons, axis: [axis, sign] or []}.
const ACTIONS := {
	"move_up": {"key": KEY_W, "buttons": [JOY_BUTTON_DPAD_UP], "axis": [JOY_AXIS_LEFT_Y, -1]},
	"move_down": {"key": KEY_S, "buttons": [JOY_BUTTON_DPAD_DOWN], "axis": [JOY_AXIS_LEFT_Y, 1]},
	"move_left": {"key": KEY_A, "buttons": [JOY_BUTTON_DPAD_LEFT], "axis": [JOY_AXIS_LEFT_X, -1]},
	"move_right": {"key": KEY_D, "buttons": [JOY_BUTTON_DPAD_RIGHT], "axis": [JOY_AXIS_LEFT_X, 1]},
	"interact": {"key": KEY_E, "buttons": [JOY_BUTTON_A], "axis": []},
	"back": {"key": KEY_ESCAPE, "buttons": [JOY_BUTTON_B], "axis": []},
	"use": {"key": KEY_F, "buttons": [JOY_BUTTON_X], "axis": []},
	"actions": {"key": KEY_TAB, "buttons": [JOY_BUTTON_Y], "axis": []},
	"pocket_prev": {"key": KEY_NONE, "buttons": [JOY_BUTTON_LEFT_SHOULDER], "axis": []},
	"pocket_next": {"key": KEY_NONE, "buttons": [JOY_BUTTON_RIGHT_SHOULDER], "axis": []},
	"whisper": {"key": KEY_B, "buttons": [], "axis": [JOY_AXIS_TRIGGER_LEFT, 1]},
	"talk": {"key": KEY_V, "buttons": [], "axis": [JOY_AXIS_TRIGGER_RIGHT, 1]},
	"menu": {"key": KEY_ESCAPE, "buttons": [JOY_BUTTON_START], "axis": []},
	"chat": {"key": KEY_ENTER, "buttons": [JOY_BUTTON_BACK], "axis": []},
	"journal": {"key": KEY_H, "buttons": [JOY_BUTTON_LEFT_STICK], "axis": []},
	"zoom_reset": {"key": KEY_NONE, "buttons": [JOY_BUTTON_RIGHT_STICK], "axis": []},
}

## Key names in the game's hints ("[E] Usiądź", action menu key caps) ->
## the pad button shown instead (-1: no button, the hint is left out).
const HINT_KEYS := {
	"E": JOY_BUTTON_A, "Esc": JOY_BUTTON_B, "F": JOY_BUTTON_X, "Tab": JOY_BUTTON_Y,
	"1": JOY_BUTTON_RIGHT_SHOULDER, "2": JOY_BUTTON_RIGHT_SHOULDER, "3": JOY_BUTTON_RIGHT_SHOULDER,
	"1–3": JOY_BUTTON_RIGHT_SHOULDER, "Enter": JOY_BUTTON_BACK, "H": JOY_BUTTON_LEFT_STICK,
	"V": JOY_BUTTON_SDL_MAX + JOY_AXIS_TRIGGER_RIGHT, "B": JOY_BUTTON_SDL_MAX + JOY_AXIS_TRIGGER_LEFT,
	"Spacja": JOY_BUTTON_A, "Space": JOY_BUTTON_A,
}
## Triggers are axes; as glyphs they get these ids (past the buttons).
const LT := JOY_BUTTON_SDL_MAX + JOY_AXIS_TRIGGER_LEFT
const RT := JOY_BUTTON_SDL_MAX + JOY_AXIS_TRIGGER_RIGHT


static func register() -> void:
	for action in ACTIONS:
		var name: String = "pad_" + action
		if InputMap.has_action(name):
			continue
		InputMap.add_action(name, DEADZONE)
		var a: Dictionary = ACTIONS[action]
		if a.key != KEY_NONE:
			var k := InputEventKey.new()
			k.physical_keycode = a.key
			InputMap.action_add_event(name, k)
		for b in a.buttons:
			var e := InputEventJoypadButton.new()
			e.button_index = b
			e.device = -1
			InputMap.action_add_event(name, e)
		if not a.axis.is_empty():
			var m := InputEventJoypadMotion.new()
			m.axis = a.axis[0]
			m.axis_value = a.axis[1]
			m.device = -1
			InputMap.action_add_event(name, m)


## The game action a pad button stands for ("" = none).
static func action_of_button(button: int) -> String:
	for action in ACTIONS:
		if button in ACTIONS[action].buttons:
			return action
	return ""


static func key_of(action: String) -> Key:
	return ACTIONS[action].key if ACTIONS.has(action) else KEY_NONE


## A stick (x right, y down) -> eight directions, as the keys give them:
## inside the dead zone nothing; a diagonal only within 22.5 degrees of it.
static func stick_dir(v: Vector2, deadzone := DEADZONE) -> Vector2i:
	if v.length() < deadzone:
		return Vector2i.ZERO
	var n := v.normalized()
	return Vector2i(_unit(n.x), _unit(n.y))


static func _unit(x: float) -> int:
	# sin(22.5 deg): beyond it the axis counts.
	return 1 if x > 0.3827 else (-1 if x < -0.3827 else 0)


## A stick past the dead zone, rescaled to 0..1 from its edge.
static func stick_value(v: Vector2, deadzone := DEADZONE) -> Vector2:
	var l := v.length()
	if l < deadzone:
		return Vector2.ZERO
	return v / l * minf(1.0, (l - deadzone) / (1.0 - deadzone))


## The glyph family for a controller's name (SDL's): "ps" (Cross, Circle...),
## "nintendo" (B A Y X by position) or "xbox" (A B X Y: Xbox, Steam Deck,
## anything else).
static func style_for(joy_name: String) -> String:
	var n := joy_name.to_lower()
	for w in ["playstation", "dualsense", "dualshock", "ps3", "ps4", "ps5", "sony"]:
		if w in n:
			return "ps"
	for w in ["nintendo", "switch", "joy-con", "pro controller"]:
		if w in n:
			return "nintendo"
	return "xbox"


## The label on a button for a glyph family ("" for the face buttons on
## PlayStation: they are drawn as shapes).
static func button_label(button: int, style: String) -> String:
	match button:
		JOY_BUTTON_A:
			return {"xbox": "A", "ps": "", "nintendo": "B"}[style]
		JOY_BUTTON_B:
			return {"xbox": "B", "ps": "", "nintendo": "A"}[style]
		JOY_BUTTON_X:
			return {"xbox": "X", "ps": "", "nintendo": "Y"}[style]
		JOY_BUTTON_Y:
			return {"xbox": "Y", "ps": "", "nintendo": "X"}[style]
		JOY_BUTTON_LEFT_SHOULDER:
			return {"xbox": "LB", "ps": "L1", "nintendo": "L"}[style]
		JOY_BUTTON_RIGHT_SHOULDER:
			return {"xbox": "RB", "ps": "R1", "nintendo": "R"}[style]
		LT:
			return {"xbox": "LT", "ps": "L2", "nintendo": "ZL"}[style]
		RT:
			return {"xbox": "RT", "ps": "R2", "nintendo": "ZR"}[style]
		JOY_BUTTON_START:
			return {"xbox": "Menu", "ps": "Options", "nintendo": "+"}[style]
		JOY_BUTTON_BACK:
			return {"xbox": "View", "ps": "Share", "nintendo": "−"}[style]
		JOY_BUTTON_LEFT_STICK:
			return {"xbox": "LS", "ps": "L3", "nintendo": "LS"}[style]
		JOY_BUTTON_RIGHT_STICK:
			return {"xbox": "RS", "ps": "R3", "nintendo": "RS"}[style]
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
			return "+"
	return "?"


## The face buttons' shape on PlayStation ("cross", "circle"...), else "".
static func ps_shape(button: int) -> String:
	return {JOY_BUTTON_A: "cross", JOY_BUTTON_B: "circle", JOY_BUTTON_X: "square", JOY_BUTTON_Y: "triangle"}.get(button, "")


## A hint's key name -> its pad button (-1: no pad button for it).
static func hint_button(key: String) -> int:
	return HINT_KEYS.get(key, -1)


## "[E] Usiądź  ·  [E] tabliczka" -> the first key ("E") and the text with
## every "[K] " for a pad button rewritten to "(A) " / dropped when the pad
## has none: [button, text].
static func pad_hint(text: String, style: String) -> Array:
	var re := RegEx.create_from_string("\\[([^\\]]{1,6})\\] ")
	var first := -1
	var out := text
	var m := re.search(text)
	if m and m.get_start() == 0:
		first = hint_button(m.get_string(1))
		out = text.substr(m.get_end()) if first >= 0 else text
	for mm in re.search_all(out):
		var b := hint_button(mm.get_string(1))
		var label := ""
		if b >= 0:
			label = button_label(b, style)
			if label == "":
				label = {"cross": "Krzyżyk", "circle": "Kółko", "square": "Kwadrat", "triangle": "Trójkąt"}[ps_shape(b)]
			label = "(%s) " % label
		out = out.replace(mm.get_string(), label)
	return [first, out]
