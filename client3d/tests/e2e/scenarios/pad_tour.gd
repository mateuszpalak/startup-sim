## Dev (not in run.py): screenshots of the gamepad prompts and the focus
## ring for docs/media/3d/pad. Server: --start-employed --allow-guests
## --no-save --start-time 10:00; client (not headless): --nick=Ola
## --autoconnect --scenario=pad_tour --shots=/dir
extends "res://tests/e2e/scenario.gd"

const Pad = preload("res://pad/pad.gd")

var dir := ""


func shot(name: String) -> void:
	await wait(0.8)
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	log_step("shot " + name)


func push(b: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = b
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait(0.1)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await wait(0.4)


func next_input(delta: float) -> int:
	var g = game()
	if not g.goto_legs.is_empty() or not g._goto_path.is_empty():
		return g._goto_input(delta)
	return g.player_bits()


func run() -> void:
	dir = str(main.args.get("shots", "/tmp"))
	if not await until(in_world, 30.0, "in the office"):
		return
	await wait(4.0)
	var g = game()
	var pad = main.pad
	await push(JOY_BUTTON_LEFT_STICK)  # (journal)
	await push(JOY_BUTTON_B)
	await until(func(): return g.hint_text.begins_with("[E]"), 10.0, "an [E] hint")
	await shot("hint_xbox")
	Pad.style = "ps"
	await shot("hint_ps")
	await push(JOY_BUTTON_Y)
	await push(JOY_BUTTON_DPAD_RIGHT)
	await shot("action_menu_ps")
	await push(JOY_BUTTON_B)
	Pad.style = "xbox"
	await push(JOY_BUTTON_A)
	await wait(0.8)
	await push(JOY_BUTTON_A)
	await until(func(): return g.screen.visible, 6.0, "the computer")
	await wait(1.0)
	for i in 3:
		await push(JOY_BUTTON_DPAD_DOWN)
	await shot("computer_focus")
	await push(JOY_BUTTON_B)
	await until(func(): return not g.screen.visible, 6.0, "stood up")
	await wait(0.5)
	await push(JOY_BUTTON_BACK)
	for b in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT]:
		await push(b)
	await shot("keyboard")
	await push(JOY_BUTTON_B)
	await push(JOY_BUTTON_B)
	g.dialog.on_dialog({"id": 251, "npc": 0, "text": "Dzień dobry! W czym mogę pomóc? Umowa, urlop, a może zgubiona karta?",
		"options": ["Chcę wziąć urlop", "Zgubiłem kartę", "Rezygnuję z pracy", "Nic, dziękuję"]})
	await wait(0.3)
	Pad.style = "nintendo"
	await push(JOY_BUTTON_DPAD_DOWN)
	await shot("dialog_switch")
	g.dialog.visible = false
	Pad.style = "xbox"
	await push(JOY_BUTTON_START)
	await wait(0.3)
	var settings: Control = null
	for c in pad.cursor.candidates():
		if c is Button and c.text.begins_with("Ustawienia"):
			settings = c
	if settings:
		pad.cursor.target = settings
		await push(JOY_BUTTON_A)
		await wait(0.3)
		for c in pad.cursor.candidates():
			if c is CheckButton and c.text.begins_with("Wibracje"):
				pad.cursor._focus(c)
		await shot("settings_pad")
	done()
