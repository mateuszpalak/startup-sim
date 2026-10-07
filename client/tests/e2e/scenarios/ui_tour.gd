## Dev (not in run.py): screenshots of the in-game UI for docs/media/3d/ui.
## Server: --start-employed --allow-guests --no-save --start-time 10:00;
## client (not headless): --nick=Ola --autoconnect --scenario=ui_tour --shots=/dir
extends "res://tests/e2e/scenario.gd"

const Item = preload("res://game/item_art.gd")

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
	await wait(4.0)
	var g = game()
	g.notices.push(1, "Nowy mail od Kuba: Kawa o 11?")
	g.notices.push(2, "Zadanie przypisane: Poprawić logowanie")
	await shot("hud_office")

	# A container next to own things (the "inventory").
	g.container.set_inventory([{"kind": Item.LAPTOP, "id": 1, "label": "IT"}, {"kind": 0, "label": ""},
		{"kind": 0, "label": ""}, {"kind": 0, "label": ""}])
	g._container_at = Movement.to_px(g.pred.pos)
	g.container.show_container({"which": Protocol.CONTAINER_FRIDGE, "milk": 6, "capacity": 12,
		"slots": [{"kind": Item.COFFEE, "count": 2, "label": ""}]})
	await shot("inventory")
	g.container.close()

	# An NPC conversation.
	g.dialog.on_dialog({"id": 251, "npc": 0, "text": "Dzień dobry! W czym mogę pomóc? Umowa, urlop, a może zgubiona karta?",
		"options": ["Chcę wziąć urlop", "Zgubiłem kartę", "Rezygnuję z pracy", "Nic, dziękuję"]})
	await shot("dialog")
	g.dialog.on_dialog({"id": 0})

	# Chat.
	var chat = g.chat_box
	chat.open()
	chat._submit("Cześć wszystkim! Kto idzie na kawę?")
	await wait(1.0)
	chat.open()
	chat._submit("/s psst, mam ciastka")
	await wait(0.6)
	chat.open()
	await shot("chat")
	chat.close()

	# The computer.
	await press_e()
	await wait(0.5)
	await press_e()
	var screen = g.screen
	if not await until(func(): return screen.visible, 8.0, "the computer screen"):
		return
	await pc("mail:Ola:Kawa o 11?")
	await pc("win:mail")
	await pc("read:0")
	await shot("computer_mail")
	await pc("task:Poprawić logowanie")
	await pc("win:tasks")
	await shot("computer_tasks")
	await pc("close")
	await wait(1.0)

	g.log_history.toggle()
	await shot("journal")
	g.log_history.toggle()
	g.overlay.visible = true
	g.action_menu.open([{"key": "E", "text": "Usiądź przy biurku", "icon": "hand", "run": func(): pass}, {"key": "Q", "text": "Upuść laptop", "icon": Item.LAPTOP, "run": func(): pass},
		{"key": "G", "text": "Podaj komuś", "icon": "give", "run": func(): pass}, {"key": "H", "text": "Dziennik dnia", "icon": "log", "run": func(): pass},
		{"key": "Enter", "text": "Napisz na czacie", "icon": "chat", "run": func(): pass}])
	await shot("actions_debug")
	g.action_menu.close()
	g.overlay.visible = false

	main.pause.open()
	await shot("pause")
	main.pause._show(main.pause._settings)
	await shot("settings")
	main.pause.close()
	done()
