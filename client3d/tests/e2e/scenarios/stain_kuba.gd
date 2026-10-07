## "Człowiek smuga" (with stain_ola): Kuba goes to the same toilet a bit
## later, finds the skid mark ("Znowu człowiek smuga zaatakował!") and
## scrubs it with the brush.
extends "res://tests/e2e/scenario.gd"

const Item = preload("res://game/item_art.gd")


func run() -> void:
	if not await until(in_world, 30.0, "at the desk"):
		return
	await until(func(): return holding(Item.LAPTOP), 5.0, "the laptop in hands")
	await item(Protocol.ITEM_DROP)
	await wait(20.0)  # Ola first
	if not await walk(4, 36, 16, 60.0):
		return
	if not await hear("Znowu człowiek smuga zaatakował!", 5.0):
		return
	if not await until(func(): return game().stain_here, 5.0, "the skid mark on the toilet"):
		return
	log_step("found it")
	game().brush_game.start()
	game().brush_game.finish()
	if not await hear("Umyte. Ktoś musiał…", 5.0):
		return
	if not await until(func(): return not game().stain_here, 5.0, "clean again"):
		return
	log_step("scrubbed")
