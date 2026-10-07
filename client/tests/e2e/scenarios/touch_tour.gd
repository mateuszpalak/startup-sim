## Dev (not in run.py): screenshots of the touch UI in the game for
## docs/media/ios/touch. Server: --start-employed --allow-guests --no-save
## --start-time 10:00; client (not headless): --nick=Ola --autoconnect
## --touch=phone --scenario=touch_tour --shots=/dir [--fake-keyboard=0.42]
extends "res://tests/e2e/scenario.gd"

const Item = preload("res://game/item_art.gd")

var dir := ""


func shot(name: String) -> void:
	await wait(0.8)
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	log_step("shot " + name)


func touch(index: int, at: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = at
	ev.pressed = down
	main.get_viewport().push_input(ev, true)


func drag(index: int, at: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = at
	main.get_viewport().push_input(ev, true)


func run() -> void:
	dir = str(main.args.get("shots", "/tmp"))
	if not await until(in_world, 30.0, "in the office"):
		return
	await wait(4.0)
	var g = game()
	g.notices.push(1, "Nowy mail od Kuba: Kawa o 11?")
	await shot("hud")
	# The thumb on the joystick.
	var home: Vector2 = g.touch._joy_home
	touch(3, home + Vector2(-10, 6), true)
	drag(3, home + Vector2(36, -30))
	await shot("hud_joystick")
	touch(3, home, false)

	g.action_menu.open(g._actions_here())
	await shot("actions")
	g.action_menu.close()

	g.dialog.on_dialog({"id": 251, "npc": 0, "text": "Dzień dobry! W czym mogę pomóc? Umowa, urlop, a może zgubiona karta?",
		"options": ["Chcę wziąć urlop", "Zgubiłem kartę", "Rezygnuję z pracy", "Nic, dziękuję"]})
	await shot("dialog")
	g.dialog.on_dialog({"id": 0})

	g.container.set_inventory([{"kind": Item.LAPTOP, "id": 1, "label": "IT"}, {"kind": 0, "label": ""},
		{"kind": 0, "label": ""}, {"kind": 0, "label": ""}])
	g._container_at = Movement.to_px(g.pred.pos)
	g.container.show_container({"which": Protocol.CONTAINER_FRIDGE, "milk": 6, "capacity": 12,
		"slots": [{"kind": Item.COFFEE, "count": 2, "label": ""}]})
	await shot("fridge")
	g.container.close()

	g._shelf_at = Movement.to_px(g.pred.pos)
	g.shelf_window.show_shelf({"shelf": 1, "title": "Napoje", "goods": [
		{"kind": Item.COFFEE, "name": "Kawa w puszce", "price": 650}, {"kind": Item.COFFEE, "name": "Cola", "price": 450},
		{"kind": Item.COFFEE, "name": "Woda", "price": 250}, {"kind": Item.COFFEE, "name": "Sok pomarańczowy", "price": 550}]})
	await shot("shop_shelf")
	g.shelf_window.close()

	g._coffee_at = Movement.to_px(g.pred.pos)
	g.coffee.show_machine({"machine": 1, "water": 5, "max": 8, "grounds": 2, "busy": 0})
	await shot("coffee")
	g.coffee.close()

	g.gadget.open({"id": 253, "npc": 1, "text": "", "options": ["TVN", "Polsat", "Sport", "Bajki", "Wyłącz"]})
	await shot("tv_remote")
	g.gadget.close()
	g.gadget.open({"id": 254, "npc": 1, "text": "", "options": ["Disco polo", "Rock", "Jazz", "Wyłącz"]})
	await shot("boombox")
	g.gadget.close()
	g.gadget.lift_floor = 4
	g.gadget.open({"id": 300, "npc": 0, "text": "Które piętro?", "options": ["Parter", "Piętro 1", "Piętro 2", "Piętro 3", "Piętro 4", "Przyłóż kartę"]})
	await shot("elevator_panel")
	g.gadget.close()

	g.roll_game.start()
	await shot("roll_game")
	g.roll_game.visible = false
	g.brush_game.start()
	await shot("brush_game")
	g.brush_game.visible = false

	g.door_plaque.open(g.room_id if g.room_id != 0 else 1, "Produkt / IT")
	await shot("door_plaque")
	g.door_plaque.close()

	var chat = g.chat_box
	chat.open()
	chat._submit("Cześć wszystkim! Kto idzie na kawę?")
	await wait(0.6)
	chat.open()
	await shot("chat_keyboard")
	chat.close()

	g.log_history.add("[10:02] • Laptop na biurku.")
	g.log_history.toggle()
	await shot("journal")
	g.log_history.toggle()

	main.pause.open()
	await shot("pause")
	main.pause._show(main.pause._settings)
	await wait(0.3)
	main.pause._settings._scroll.scroll_vertical = 10000
	await shot("settings")
	main.pause.close()
	done()
