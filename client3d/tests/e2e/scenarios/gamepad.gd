## A gamepad only (synthetic joypad events, no keys or clicks): the hint
## shows the pad's button, A puts the laptop on the desk and sits down, the
## d-pad walks the focus ring to the HR app and A opens it, B stands up, Y
## opens the action menu (B closes it), Back opens the chat and the pad
## keyboard types and sends a phrase, the stick walks, the right stick
## turns the camera, a key press switches the hints back.
## Server: --start-employed (a laptop in hands, next to the desk).
extends "res://tests/e2e/scenario.gd"

const Item = preload("res://game/item_art.gd")
const Pad = preload("res://pad/pad.gd")
const PadCursor = preload("res://pad/pad_cursor.gd")


## The game's own input (the pad presses its keys), not the script's.
func next_input(delta: float) -> int:
	var g = game()
	if not g.goto_legs.is_empty() or not g._goto_path.is_empty():
		return g._goto_input(delta)
	return g.player_bits()


func button(b: int, down: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = b
	ev.pressed = down
	ev.pressure = 1.0 if down else 0.0
	Input.parse_input_event(ev)


func push(b: int, hold := 0.12) -> void:
	button(b, true)
	await wait(hold)
	button(b, false)
	await wait(0.25)


func axis(a: int, v: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = a
	ev.axis_value = v
	Input.parse_input_event(ev)


## D-pad steps until the focus ring is on `c` (false: it never got there).
func focus_to(c: Control, steps := 30) -> bool:
	var cur = main.pad.cursor
	for i in steps:
		if cur.target == c:
			return true
		if cur.target == null:
			await wait(0.1)
			continue
		var d: Vector2 = PadCursor.vrect(c).get_center() - PadCursor.vrect(cur.target).get_center()
		var b := JOY_BUTTON_DPAD_DOWN
		if absf(d.y) > 8.0:
			b = JOY_BUTTON_DPAD_DOWN if d.y > 0 else JOY_BUTTON_DPAD_UP
		else:
			b = JOY_BUTTON_DPAD_RIGHT if d.x > 0 else JOY_BUTTON_DPAD_LEFT
		await push(b, 0.05)
	return cur.target == c


func run() -> void:
	if not await until(in_world, 30.0, "in the office"):
		return
	await wait(2.0)
	var g = game()
	var pad = main.pad
	if not await until(func(): return g.hint_text.begins_with("[E]"), 10.0, "an [E] hint by the desk"):
		return
	check(not Pad.active, "keyboard hints before any pad input")
	# Any pad input: the hint shows the A button instead of [E].
	await push(JOY_BUTTON_LEFT_STICK)  # (the journal: opens it)
	if not check(Pad.active, "pad input switches to pad hints"):
		return
	await push(JOY_BUTTON_B)  # closes the journal again
	if not await until(func(): return g.pad_modal() == null, 2.0, "journal closed with B"):
		return
	if not await until(func(): return g._hint_button == JOY_BUTTON_A and not g.hint_label.text.contains("[E]"), 3.0, "A glyph in the hint"):
		return
	log_step("pad hint: (A) %s" % g.hint_label.text)

	# A = E: the laptop on the desk, then sit down.
	await push(JOY_BUTTON_A)
	if not await until(func(): return not holding(Item.LAPTOP), 5.0, "laptop put down with A"):
		return
	await wait(0.6)
	await push(JOY_BUTTON_A)
	var screen = g.screen
	if not await until(func(): return screen.visible, 6.0, "sat down at the computer with A"):
		return
	await wait(0.5)
	if not check(pad.context() == "ui" and pad.cursor.root == screen and pad.cursor.target != null, "focus ring on the computer screen"):
		return
	# The d-pad to the HR icon, A opens it.
	var hr_icon: Control = screen._icons["hr"]
	if not check(await focus_to(hr_icon), "d-pad walked to the HR icon (at %s)" % pad.cursor.target):
		return
	await push(JOY_BUTTON_A)
	if not await until(func(): return screen._windows.has("hr") and screen._windows["hr"].visible, 5.0, "HR app opened with A"):
		return
	log_step("StartOS: HR opened with the pad")
	await push(JOY_BUTTON_B)
	if not await until(func(): return not screen.visible, 6.0, "stood up with B"):
		return
	await wait(0.5)

	# Y: the action menu; the ring is on a tile; B closes it.
	await push(JOY_BUTTON_Y)
	if not await until(func(): return g.action_menu.visible, 2.0, "action menu with Y"):
		return
	await wait(0.2)
	if not check(pad.cursor.root == g.action_menu and pad.cursor.target is Button, "ring on an action tile"):
		return
	await push(JOY_BUTTON_B)
	if not await until(func(): return not g.action_menu.visible, 2.0, "action menu closed with B"):
		return

	# Back: the chat; A on the line opens the pad keyboard; a phrase; Start sends.
	await push(JOY_BUTTON_BACK)
	if not await until(func(): return g.chat_box.visible, 2.0, "chat opened with Back"):
		return
	await wait(0.2)
	await push(JOY_BUTTON_A)
	if not await until(func(): return pad.keyboard.visible, 2.0, "pad keyboard over the chat"):
		return
	var phrase: Control = null
	for b in pad.keyboard._phrases.get_children():
		if b.text == "Dzięki!":
			phrase = b
	if not check(phrase != null and await focus_to(phrase), "d-pad to the phrase „Dzięki!”"):
		return
	await push(JOY_BUTTON_A)
	await push(JOY_BUTTON_X)  # backspace: the trailing space
	if not check(g.chat_box._input.text == "Dzięki!", "typed with the pad (got „%s”)" % g.chat_box._input.text):
		return
	await push(JOY_BUTTON_START)
	if not await until(func(): return not g.chat_box.visible and not pad.keyboard.visible, 2.0, "chat sent with Start"):
		return
	if not await until(func(): return says.any(func(t): return t.contains("Dzięki!")), 5.0, "the chat line said in the room"):
		return
	log_step("chat typed on the pad keyboard")

	# The right stick turns the camera (and settles on 45 degrees).
	var rig = g.world_view.rig
	var yaw0: float = rig._yaw_goal
	axis(JOY_AXIS_RIGHT_X, 1.0)
	await wait(0.4)
	axis(JOY_AXIS_RIGHT_X, 0.0)
	await wait(0.2)
	if not check(absf(rig._yaw_goal - yaw0) > 0.3, "right stick turned the camera (%.2f -> %.2f)" % [yaw0, rig._yaw_goal]):
		return
	rig._yaw_goal = yaw0
	await wait(0.5)

	# The left stick walks (whichever way is free); prediction = server.
	var start := tile_now()
	for v in [Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1)]:
		axis(JOY_AXIS_LEFT_X, v.x)
		axis(JOY_AXIS_LEFT_Y, v.y)
		await wait(0.9)
		axis(JOY_AXIS_LEFT_X, 0.0)
		axis(JOY_AXIS_LEFT_Y, 0.0)
		await wait(0.3)
		if tile_now() != start:
			break
	if not check(tile_now() != start, "walked with the left stick"):
		return
	if not check(not Input.is_physical_key_pressed(KEY_W) and not Input.is_physical_key_pressed(KEY_S)
			and not Input.is_physical_key_pressed(KEY_A) and not Input.is_physical_key_pressed(KEY_D), "stick released: no key held"):
		return
	await wait(1.0)
	if not check(g.error_offset.length() < 4.0, "no correction after the walk (%s)" % g.error_offset):
		return
	log_step("stick walked %s -> %s" % [start, tile_now()])

	# A key: back to keyboard hints.
	var ev := InputEventKey.new()
	ev.keycode = KEY_SHIFT
	ev.physical_keycode = KEY_SHIFT
	ev.pressed = true
	Input.parse_input_event(ev)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await wait(0.2)
	check(not Pad.active, "a key press switches back to key hints")
	done()
