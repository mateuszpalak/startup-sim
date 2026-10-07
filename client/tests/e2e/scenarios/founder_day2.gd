## Logging back in as the founder (who left with the laptop): at the board
## table the laptop is still their account - the messenger has its channels
## and the company panel is there.
extends "res://tests/e2e/scenario.gd"

const Item = preload("res://game/item_art.gd")


func run() -> void:
	if not await until(in_world, 60.0, "back in the world"):
		return
	if not await hear("Z powrotem", 15.0):
		return
	# Where founder_day1 sat down (the board table).
	if not await walk(4, 23, 21, 90.0):
		return
	await until(func(): return holding(Item.LAPTOP), 5.0, "the laptop in hands")
	if not await sit_at_desk():
		return
	var screen = game().screen
	if not await until(func(): return not screen.state.get("convs", []).is_empty(), 5.0, "the messenger channels"):
		return
	log_step("channels: %s" % [screen.state.convs.map(func(c): return c.title)])
	if not await until(func(): return not screen.company_offers.is_empty(), 10.0, "the company panel"):
		return
	log_step("the company panel")
	if main.args.has("shots"):  # dev: a screenshot of the panel (--shots=/dir)
		screen.dev_command("win:company")
		await wait(1.5)
		await RenderingServer.frame_post_draw
		main.get_viewport().get_texture().get_image().save_png("%s/computer_company.png" % main.args["shots"])
