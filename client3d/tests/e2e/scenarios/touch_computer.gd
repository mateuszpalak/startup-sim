## Dev (not in run.py): every computer app, for touch-layout screenshots.
## Server: --start-employed --allow-guests --no-save; client: --nick=Ola
## --autoconnect --scenario=touch_computer --shots=/dir [--touch=phone]
extends "res://tests/e2e/scenario.gd"

var dir := ""


func shot(name: String) -> void:
	await wait(0.8)
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	log_step("shot " + name)


func run() -> void:
	dir = str(main.args.get("shots", "/tmp"))
	if not await until(in_world, 30.0, "in the office"):
		return
	await wait(3.0)
	await press_e()
	await wait(0.5)
	await press_e()
	var screen = game().screen
	if not await until(func(): return screen.visible, 8.0, "the computer screen"):
		return
	await shot("computer_desktop")
	await pc("mail:Ola:Kawa o 11?")
	await pc("win:mail")
	await pc("read:0")
	await shot("computer_mail")
	for w in ["tasks", "lunch", "chat", "calendar", "hr", "terminal", "company", "trash"]:
		await pc("win:" + w)
		await shot("computer_" + w)
	screen._start.show_popup()
	await shot("computer_start")
	await pc("close")
