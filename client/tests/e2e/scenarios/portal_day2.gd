## Logging back in right away (the old session not even timed out): the
## character is saved already - straight to the job portal, with its own
## e-mail, not to the creation screen.
extends "res://tests/e2e/scenario.gd"


func run() -> void:
	# (Without the save the creation screen waits for the player here.)
	if not await until(func(): return main.portal_layer.visible, 30.0, "the job portal, not the character creation"):
		return
	await until(func(): return main.profile.email == "nowa@poczta.pl", 10.0, "own e-mail back (%s)" % main.profile.email)
	log_step("back on the portal as %s" % main.profile.email)
