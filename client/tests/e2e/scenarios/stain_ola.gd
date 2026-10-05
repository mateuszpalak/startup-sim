## "Człowiek smuga" (with stain_kuba; server --stain-chance 100): Ola uses
## the toilet and leaves a skid mark (only she's told), walks off without
## the brush - and hears about it from the whole office once Kuba finds it.
extends "res://tests/e2e/scenario.gd"

const Item = preload("res://game/item_art.gd")


func run() -> void:
	if not await until(in_world, 30.0, "at the desk"):
		return
	await until(func(): return holding(Item.LAPTOP), 5.0, "the laptop in hands")
	await item(Protocol.ITEM_DROP)
	if not await walk(4, 36, 16, 60.0):  # in the stall, at the toilet
		return
	await press_e()  # sits down
	await wait(1.5)
	if not await walk(4, 36, 19, 20.0):  # out of the stall: got up
		return
	if not await hear("Ups… na sedesie została smuga", 5.0):
		return
	log_step("left a skid mark")
	if not await until(func(): return notices.any(func(n): return n.contains("człowiek smuga")), 60.0, "the office talking about it"):
		return
	log_step("the office knows (not who)")
