## Dev (not in run.py): screenshots of the menus before the game on a touch
## screen (title, settings, login, character). No server needed; client
## (not headless): --touch=phone --scenario=touch_menus --shots=/dir
## [--fake-keyboard=0.42]
extends "res://tests/e2e/scenario.gd"

var dir := ""


func shot(name: String) -> void:
	await wait(0.8)
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	log_step("shot " + name)


func run() -> void:
	dir = str(main.args.get("shots", "/tmp"))
	await wait(1.5)
	await shot("title")
	main.title._show(main.title._settings)
	await shot("title_settings")
	main.title._show(main.title._menu)
	main._show_login("")
	await shot("login")
	main.login.nick_edit.grab_focus()
	await shot("login_keyboard")
	main.login.nick_edit.release_focus()
	main.login_layer.visible = false
	main.start.get_parent().visible = true
	await shot("character")
	done()
