## Saving a new character (with portal_day2): a new account creates its
## character and leaves from the job portal at once.
extends "res://tests/e2e/scenario.gd"


func run() -> void:
	if not await until(func(): return main.portal_layer.visible, 60.0, "the job portal"):
		return
	log_step("on the portal as %s" % main.profile.email)
	await wait(1.0)
