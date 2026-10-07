## Touch controls (client run with --touch): the on-screen buttons press
## the game's keys, the joystick walks, a tap on the floor walks there,
## two fingers zoom, the close button stands up from the computer.
## Server: --start-employed (a laptop in hands, next to the desk).
extends "res://tests/e2e/scenario.gd"

const Item = preload("res://game/item_art.gd")
const Touch = preload("res://touch/touch.gd")
const Coords = preload("res://world3d/coords.gd")


## The scenario drives through the touch controls: whatever they press.
func next_input(delta: float) -> int:
	var g = game()
	if not g.goto_legs.is_empty() or not g._goto_path.is_empty():
		return g._goto_input(delta)
	return g.player_bits()


func touch(index: int, at: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = at
	ev.pressed = down
	main.get_viewport().push_input(ev, true)


func drag(index: int, at: Vector2, rel: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = at
	ev.relative = rel
	main.get_viewport().push_input(ev, true)


func tap(at: Vector2) -> void:
	touch(0, at, true)
	await wait(0.05)
	touch(0, at, false)
	await wait(0.2)


func button(id: String) -> Vector2:
	return game().touch.buttons[id].at


func run() -> void:
	if not await until(in_world, 30.0, "in the office"):
		return
	await wait(2.0)
	var g = game()
	if not check(Touch.active and g.touch != null, "touch controls are on"):
		return
	var tc = g.touch
	if not check(tc.buttons.act.shown and tc.buttons.use.shown, "action and item buttons shown"):
		return

	# The action button = E: the laptop goes on the desk, then sit down.
	if not await until(func(): return g.hint_label.text.begins_with("[E]"), 10.0, "an [E] hint by the desk"):
		return
	await tap(button("act"))
	if not await until(func(): return not holding(Item.LAPTOP), 5.0, "laptop put on the desk by the action button"):
		return
	await wait(0.6)
	await tap(button("act"))
	if not await until(func(): return g.screen.visible, 6.0, "sat down at the computer"):
		return
	if not await until(func(): return tc.buttons.close.shown and not tc.buttons.act.shown, 2.0, "only the close button over the computer"):
		return
	await tap(button("close"))
	if not await until(func(): return not g.screen.visible, 6.0, "stood up with the close button"):
		return
	await wait(0.5)
	log_step("action and close buttons")

	# Tab: the action menu; the close button (Esc) shuts it.
	await tap(button("menu"))
	if not await until(func(): return g.action_menu.visible, 2.0, "action menu from its button"):
		return
	await tap(button("close"))
	if not await until(func(): return not g.action_menu.visible, 2.0, "action menu closed"):
		return

	# Voice: held while the finger is down.
	touch(1, button("talk"), true)
	await wait(0.4)
	var held := Input.is_key_pressed(KEY_V)
	touch(1, button("talk"), false)
	await wait(0.2)
	if not check(held and not Input.is_key_pressed(KEY_V), "talk button holds V"):
		return

	# Two fingers apart: zoom in.
	var z0: float = g.zoom_level
	var c: Vector2 = main.get_viewport().get_visible_rect().size / 2
	touch(0, c - Vector2(40, 0), true)
	touch(1, c + Vector2(40, 0), true)
	for i in 6:
		await wait(0.03)
		drag(1, c + Vector2(40 + 15 * (i + 1), 0), Vector2(15, 0))
	touch(1, c + Vector2(130, 0), false)
	touch(0, c - Vector2(40, 0), false)
	await wait(0.2)
	if not check(g.zoom_level > z0 * 1.3, "pinch zoomed in (%.2f -> %.2f)" % [z0, g.zoom_level]):
		return
	g.set_zoom_level(z0)
	log_step("talk and pinch")

	# The joystick: walk away from the desk, whichever way is free.
	var start := tile_now()
	var home: Vector2 = tc._joy_home
	for d in [Vector2(0, 60), Vector2(-60, 0), Vector2(60, 0), Vector2(0, -60)]:
		touch(2, home, true)
		drag(2, home + d, d)
		await wait(0.1)
		var want := Vector2i(d.normalized().round())
		if not check(tc.move_dir() == want, "joystick %s -> %s (got %s)" % [d, want, tc.move_dir()]):
			return
		await wait(0.8)
		touch(2, home + d, false)
		await wait(0.2)
		if tile_now() != start:
			break
	if not check(tile_now() != start and tc.move_dir() == Vector2i.ZERO, "walked with the joystick"):
		return
	log_step("joystick walked %s -> %s" % [start, tile_now()])

	# A tap on the floor a few tiles away: walk there.
	var m = g.building.get_floor(g.pred.floor)
	var here := tile_now()
	var goal := Vector2i(-1, -1)
	for t in [here + Vector2i(3, 0), here + Vector2i(-3, 0), here + Vector2i(0, 2), here + Vector2i(0, -2), here + Vector2i(2, 2)]:
		if not m.is_blocked(t.x, t.y) and not g._plan_path("%d,%d" % [t.x, t.y]).is_empty():
			goal = t
			break
	if not check(goal.x >= 0, "a free tile to tap near %s" % here):
		return
	var cam: Camera3D = g.world_view.rig.camera
	var sp := cam.unproject_position(Vector3(goal.x + 0.5, Coords.floor_y(g.pred.floor), goal.y + 0.5))
	await tap(sp)
	if not await until(func(): return tile_now() == goal, 8.0, "tap-walked to %s" % goal):
		return
	log_step("tap walked to %s" % goal)
	done()
