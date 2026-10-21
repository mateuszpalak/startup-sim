## Daily duties, solo: the list arrives, Ola walks to two of them, plays the
## minigames (hold and choice) and gets paid; the list shows them done.
extends "res://tests/e2e/scenario.gd"

const Item = preload("res://game/item_art.gd")


func run() -> void:
	if not await until(in_world, 30.0, "in the world"):
		return
	if not await until(func(): return not game().duty_list.duties.is_empty(), 15.0, "today's duties"):
		return
	log_step("%d duties" % game().duty_list.duties.size())
	await until(func(): return holding(Item.LAPTOP), 5.0, "the laptop in hands")
	await item(Protocol.ITEM_DROP)  # duties want free hands
	if not await until(func(): return not holding(Item.LAPTOP), 5.0, "free hands"):
		return
	var done := 0
	for i in game().duty_list.duties.size():
		if done == 2:
			break
		var d: Dictionary = game().duty_list.duties[i]
		var stand := _next_to(d)
		if stand.is_empty():
			continue
		if not await walk(d.floor, stand[0].x, stand[0].y, 90.0):
			return
		if not check(game().hint_text.begins_with("[E] %s" % d.title), "hint '%s' for %s" % [game().hint_text, d.title]):
			return
		var before := money()
		await press_e()
		if not await until(func(): return game().duty_game.visible, 5.0, "the minigame of %s" % d.title):
			return
		if game().duty_game.kind == Protocol.DUTY_HOLD:
			game().duty_game._holding = true
		else:
			game().duty_game.auto_finish(0)
		if not await until(func(): return game().duty_list.duties[i].state != Protocol.DUTY_TODO, 20.0, "%s done" % d.title):
			return
		game().duty_game._holding = false
		var paid_at_least: int = d.reward if game().duty_list.duties[i].state == Protocol.DUTY_DONE else 0
		if not await until(func(): return money() - before >= paid_at_least, 8.0, "paid for %s" % d.title):
			return
		log_step("%s: +%d gr" % [d.title, money() - before])
		done += 1
	check(done == 2, "two duties done (%d)" % done)


## A free tile next to the duty's place that can be walked to.
func _next_to(d: Dictionary) -> Array:
	var m = game().building.get_floor(d.floor)
	for off in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var t: Vector2i = Vector2i(d.x, d.y) + off
		if m.is_blocked(t.x, t.y):
			continue
		if not find_path([floor_now(), tile_now()], [d.floor, t], access()).is_empty():
			return [t]
	return []
