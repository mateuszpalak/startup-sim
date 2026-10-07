## Saving the founder (with founder_day2): founds the company, works at the
## board table, then takes the laptop along and quits.
extends "res://tests/e2e/scenario.gd"

const Item = preload("res://game/item_art.gd")


func run() -> void:
	if not await until(in_world, 60.0, "the company founded, in the board room"):
		return
	await until(func(): return holding(Item.LAPTOP), 5.0, "the laptop in hands")
	if not await sit_at_desk():
		return
	var screen = game().screen
	if not await until(func(): return not screen.state.get("convs", []).is_empty(), 5.0, "the messenger channels"):
		return
	if not await until(func(): return not screen.company_offers.is_empty(), 10.0, "the company panel"):
		return
	log_step("at %s, channels: %s" % [tile_now(), screen.state.convs.map(func(c): return c.title)])
	await pc("take")
	if not await until(func(): return holding(Item.LAPTOP), 5.0, "the laptop taken along"):
		return
	await wait(1.0)
