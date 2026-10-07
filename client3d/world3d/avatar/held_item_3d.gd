## Small 3D models of the things a character holds (ItemArt kinds), built
## from primitives with the 2D icon colours. `build(kind)` returns a fresh
## Node3D whose origin is the grip (inside the fist): cups and bottles stand
## on it, cards and snacks sit in it. Slightly oversized so they read from
## the high game camera.
extends RefCounted

const M = preload("res://world3d/avatar/avatar_mesh.gd")
const ItemArt = preload("res://game/item_art.gd")

## Kinds carried in both hands at the chest (the rest: one hand).
const TWO_HANDED := [ItemArt.LAPTOP, ItemArt.BOOMBOX, ItemArt.PIEROGI, ItemArt.SCHNITZEL,
	ItemArt.SALAD, ItemArt.PIZZA, ItemArt.SUSHI]
## Kinds with steam rising from them.
const HOT := [ItemArt.COFFEE, ItemArt.LATTE]


static func _p(root: Node3D, mesh: Mesh, col: Color, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, outline := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = M.mat(col, outline)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	root.add_child(mi)
	return mi


static func build(kind: int) -> Node3D:
	var n := Node3D.new()
	n.name = "Held%d" % kind
	match kind:
		ItemArt.GUEST_PASS, ItemArt.EMPLOYEE_CARD:
			var guest := kind == ItemArt.GUEST_PASS
			_p(n, M.box(Vector3(0.095, 0.065, 0.006)), Color("#f1d15a") if guest else Color("#f2eee4"), Vector3(0, 0.04, 0.02), Vector3(-0.5, 0, 0))
			_p(n, M.box(Vector3(0.096, 0.016, 0.008)), Color("#d98a3e") if guest else Color("#4f7fb0"), Vector3(0, 0.063, 0.008), Vector3(-0.5, 0, 0))
			if not guest:
				_p(n, M.box(Vector3(0.026, 0.03, 0.008)), Color("#c9a37a"), Vector3(-0.025, 0.035, 0.024), Vector3(-0.5, 0, 0))
		ItemArt.LAPTOP:
			# closed, held flat against the chest
			_p(n, M.box(Vector3(0.36, 0.25, 0.028)), Color("#9aa1a6"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, true)
			_p(n, M.box(Vector3(0.06, 0.06, 0.03)), Color("#d8dde2"), Vector3(0, 0.02, 0.002))
		ItemArt.COFFEE, ItemArt.EMPTY_CUP, ItemArt.CUP, ItemArt.LATTE:
			_mug(n, kind)
		ItemArt.MILK, ItemArt.JUICE:
			var body := Color("#f4f4ee") if kind == ItemArt.MILK else Color("#f0a13a")
			_p(n, M.box(Vector3(0.075, 0.13, 0.075)), body, Vector3(0, 0.06, 0), Vector3.ZERO, Vector3.ONE, true)
			_p(n, M.cyl(0.0, 0.055, 0.04, 4), body, Vector3(0, 0.145, 0), Vector3(0, PI / 4, 0), Vector3(1, 1, 0.98))
			_p(n, M.box(Vector3(0.078, 0.045, 0.078)), Color("#4f86c0") if kind == ItemArt.MILK else Color("#f6c65a"), Vector3(0, 0.05, 0))
		ItemArt.FRUIT:
			_p(n, M.sphere(0.05), Color("#c9463a"), Vector3(0, 0.035, 0.02), Vector3.ZERO, Vector3(1, 0.92, 1), true)
			_p(n, M.cyl(0.005, 0.006, 0.03, 4), Color("#6b4a2e"), Vector3(0, 0.085, 0.02))
			_p(n, M.sphere(0.018, 6, 4), Color("#6f9a45"), Vector3(0.018, 0.088, 0.02), Vector3.ZERO, Vector3(1.4, 0.4, 0.8))
		ItemArt.SANDWICH_CHEESE, ItemArt.SANDWICH_HAM:
			var fill := Color("#e8c24e") if kind == ItemArt.SANDWICH_CHEESE else Color("#e59a9a")
			var tri := M.cyl(0.07, 0.07, 0.02, 3)
			_p(n, tri, Color("#e7d3a6"), Vector3(0, 0.03, 0.02), Vector3(PI / 2, 0, 0), Vector3.ONE, true)
			_p(n, tri, fill, Vector3(0, 0.03, 0.035), Vector3(PI / 2, 0, 0), Vector3(1.04, 0.6, 1.04))
			_p(n, tri, Color("#7da04f"), Vector3(0, 0.03, 0.045), Vector3(PI / 2, 0, 0), Vector3(1.06, 0.4, 1.06))
			_p(n, tri, Color("#e7d3a6"), Vector3(0, 0.03, 0.058), Vector3(PI / 2, 0, 0))
		ItemArt.WRAP, ItemArt.KEBAB:
			_p(n, M.cyl(0.04, 0.03, 0.15, 10), Color("#e9d7a4"), Vector3(0, 0.05, 0.01), Vector3.ZERO, Vector3.ONE, true)
			_p(n, M.sphere(0.036, 8, 5), Color("#9a5a32") if kind == ItemArt.KEBAB else Color("#7da04f"), Vector3(0, 0.125, 0.01), Vector3.ZERO, Vector3(1, 0.5, 1))
			_p(n, M.sphere(0.012, 6, 4), Color("#c9463a"), Vector3(0.015, 0.135, 0.02))
		ItemArt.BURGER:
			_p(n, M.sphere(0.065, 12, 6), Color("#d99a4e"), Vector3(0, 0.07, 0.02), Vector3.ZERO, Vector3(1, 0.55, 1), true)
			_p(n, M.cyl(0.07, 0.07, 0.012, 12), Color("#7da04f"), Vector3(0, 0.045, 0.02))
			_p(n, M.cyl(0.064, 0.064, 0.022, 12), Color("#6b3f25"), Vector3(0, 0.03, 0.02))
			_p(n, M.cyl(0.062, 0.058, 0.022, 12), Color("#d99a4e"), Vector3(0, 0.01, 0.02), Vector3.ZERO, Vector3.ONE, true)
		ItemArt.FRIES:
			_p(n, M.cyl(0.05, 0.038, 0.09, 4), Color("#c9463a"), Vector3(0, 0.045, 0), Vector3(0, PI / 4, 0), Vector3(1, 1, 0.6), true)
			for k in 6:
				_p(n, M.box(Vector3(0.012, 0.08, 0.012)), Color("#f0cf5c"), Vector3(-0.03 + k * 0.012, 0.1 + (k % 2) * 0.012, (k % 3 - 1) * 0.01), Vector3(0, 0, (k - 2.5) * 0.08))
		ItemArt.BUN, ItemArt.COOKIE, ItemArt.DONUT:
			if kind == ItemArt.DONUT:
				_p(n, M.torus(0.022, 0.06, 14), Color("#d9a15a"), Vector3(0, 0.04, 0.03), Vector3(PI / 2, 0, 0), Vector3.ONE, true)
				_p(n, M.torus(0.026, 0.056, 14), Color("#e889a8"), Vector3(0, 0.04, 0.036), Vector3(PI / 2, 0, 0), Vector3(1, 0.6, 1))
			elif kind == ItemArt.COOKIE:
				_p(n, M.cyl(0.055, 0.055, 0.016, 14), Color("#c9914e"), Vector3(0, 0.04, 0.03), Vector3(PI / 2, 0, 0), Vector3.ONE, true)
				for q in [Vector2(-0.02, 0.01), Vector2(0.02, 0.02), Vector2(0.0, -0.02), Vector2(0.025, -0.012)]:
					_p(n, M.sphere(0.008, 6, 3), Color("#4a2e1e"), Vector3(q.x, 0.04 + q.y, 0.04))
			else:
				_p(n, M.sphere(0.06, 12, 6), Color("#d6a45e"), Vector3(0, 0.04, 0.02), Vector3.ZERO, Vector3(1, 0.7, 1), true)
				_p(n, M.torus(0.02, 0.03, 10), Color("#f4ead0"), Vector3(0, 0.068, 0.02), Vector3.ZERO, Vector3(1, 0.4, 1))
		ItemArt.BAR, ItemArt.CHIPS, ItemArt.STORE_COOKIES, ItemArt.TOBACCO, ItemArt.CIGARETTES:
			match kind:
				ItemArt.BAR:
					_p(n, M.box(Vector3(0.13, 0.035, 0.022)), Color("#8e4a2e"), Vector3(0, 0.03, 0.02), Vector3(0, 0, 0.5), Vector3.ONE, true)
					_p(n, M.box(Vector3(0.05, 0.037, 0.024)), Color("#e0b84a"), Vector3(0, 0.03, 0.02), Vector3(0, 0, 0.5))
				ItemArt.CHIPS:
					_p(n, M.box(Vector3(0.11, 0.15, 0.04)), Color("#d9443a"), Vector3(0, 0.07, 0.01), Vector3.ZERO, Vector3.ONE, true)
					_p(n, M.cyl(0.03, 0.03, 0.044, 10), Color("#f0cf5c"), Vector3(0, 0.07, 0.01), Vector3(PI / 2, 0, 0))
				ItemArt.STORE_COOKIES:
					_p(n, M.box(Vector3(0.14, 0.09, 0.05)), Color("#e8c46a"), Vector3(0, 0.04, 0.01), Vector3.ZERO, Vector3.ONE, true)
				ItemArt.TOBACCO:
					_p(n, M.box(Vector3(0.1, 0.085, 0.03)), Color("#3f6b3a"), Vector3(0, 0.04, 0.01), Vector3.ZERO, Vector3.ONE, true)
					_p(n, M.box(Vector3(0.03, 0.03, 0.032)), Color("#c9a24a"), Vector3(0, 0.035, 0.01), Vector3(0, 0, PI / 4))
				_:
					_p(n, M.box(Vector3(0.06, 0.09, 0.025)), Color("#f1ece2"), Vector3(0, 0.04, 0.01), Vector3.ZERO, Vector3.ONE, true)
					_p(n, M.box(Vector3(0.062, 0.03, 0.027)), Color("#c9463a"), Vector3(0, 0.065, 0.01))
					for k in 3:
						_p(n, M.cyl(0.006, 0.006, 0.02, 6), Color("#e0b86a"), Vector3(-0.015 + k * 0.015, 0.09, 0.01))
		ItemArt.WATER, ItemArt.BEER, ItemArt.WINE, ItemArt.WHISKY, ItemArt.COGNAC, ItemArt.VODKA, ItemArt.COLA, ItemArt.MALPKA:
			var c: Array = {
				ItemArt.WATER: [Color("#a9d4e8"), Color("#4f86c0"), Color("#3f6fa8")],
				ItemArt.BEER: [Color("#8a5a2a"), Color("#efe0b0"), Color("#d4b870")],
				ItemArt.WINE: [Color("#5a1f2a"), Color("#efe6d2"), Color("#8e2a3a")],
				ItemArt.WHISKY: [Color("#b8742a"), Color("#efe0b0"), Color("#2d3036")],
				ItemArt.COGNAC: [Color("#7a3a1a"), Color("#e8c46a"), Color("#c9a24a")],
				ItemArt.VODKA: [Color("#dfe8ee"), Color("#f4f6f8"), Color("#c0392b")],
				ItemArt.COLA: [Color("#3a1f14"), Color("#d9443a"), Color("#c0392b")],
				ItemArt.MALPKA: [Color("#b3a447"), Color("#1f5a3a"), Color("#d4b04a")],
			}[kind]
			var small := kind == ItemArt.MALPKA
			var h := 0.1 if small else 0.17
			var r := 0.03 if small else 0.034
			_p(n, M.cyl(r, r, h, 10), c[0], Vector3(0, h / 2 - 0.02, 0), Vector3.ZERO, Vector3(1, 1, 0.7 if small else 1.0), true)
			_p(n, M.cyl(0.012, r, 0.04, 10), c[0], Vector3(0, h - 0.0, 0), Vector3.ZERO, Vector3(1, 1, 0.7 if small else 1.0))
			_p(n, M.cyl(0.012, 0.012, 0.04, 8), c[0], Vector3(0, h + 0.035, 0))
			_p(n, M.cyl(r + 0.002, r + 0.002, h * 0.35, 10), c[1], Vector3(0, h * 0.4 - 0.02, 0), Vector3.ZERO, Vector3(1, 1, 0.7 if small else 1.0))
			_p(n, M.cyl(0.014, 0.014, 0.018, 8), c[2], Vector3(0, h + 0.06, 0))
		ItemArt.ENERGY_DRINK:
			_p(n, M.cyl(0.03, 0.03, 0.12, 12), Color("#2c3a4a"), Vector3(0, 0.04, 0), Vector3.ZERO, Vector3.ONE, true)
			_p(n, M.box(Vector3(0.02, 0.06, 0.01)), Color("#8fd04a"), Vector3(0, 0.045, 0.03), Vector3(0, 0, 0.4))
			_p(n, M.cyl(0.026, 0.03, 0.01, 12), Color("#c9c9c9"), Vector3(0, 0.105, 0))
		ItemArt.UMBRELLA:  # closed, carried like a cane
			_p(n, M.cyl(0.035, 0.008, 0.5, 8), Color("#3a5f9e"), Vector3(0, -0.28, 0.02), Vector3.ZERO, Vector3.ONE, true)
			_p(n, M.cyl(0.008, 0.008, 0.62, 6), Color("#5c6570"), Vector3(0, -0.25, 0.02))
			_p(n, M.tube(M.arc(Vector3(0.03, 0.06, 0), 0.03, 0.0, PI, 6), 0.009, 5), Color("#3a2a20"), Vector3(0, 0, 0.02))
		ItemArt.CHEESECAKE:
			_p(n, M.cyl(0.07, 0.07, 0.05, 3), Color("#f3e3b4"), Vector3(0, 0.05, 0.02), Vector3(0, 0, 0), Vector3(1, 1, 0.7), true)
			_p(n, M.cyl(0.071, 0.071, 0.014, 3), Color("#b88a4e"), Vector3(0, 0.02, 0.02), Vector3.ZERO, Vector3(1, 1, 0.7))
			_p(n, M.cyl(0.071, 0.071, 0.008, 3), Color("#c9463a"), Vector3(0, 0.078, 0.02), Vector3.ZERO, Vector3(1, 1, 0.7))
		ItemArt.PIEROGI, ItemArt.SCHNITZEL, ItemArt.SALAD, ItemArt.PIZZA, ItemArt.SUSHI:
			_plate(n, kind)
		ItemArt.BREATHALYSER, ItemArt.REMOTE:
			var body := Color("#5c6670") if kind == ItemArt.BREATHALYSER else Color("#2d3036")
			_p(n, M.box(Vector3(0.05, 0.14, 0.025)), body, Vector3(0, 0.05, 0.01), Vector3.ZERO, Vector3.ONE, true)
			if kind == ItemArt.BREATHALYSER:
				_p(n, M.box(Vector3(0.036, 0.03, 0.004)), Color("#9fd46a"), Vector3(0, 0.08, 0.024))
				_p(n, M.cyl(0.012, 0.012, 0.04, 8), Color("#f4efe4"), Vector3(0, 0.14, 0.01))
			else:
				_p(n, M.sphere(0.008, 6, 3), Color("#e74c3c"), Vector3(0, 0.1, 0.022))
		ItemArt.BOOMBOX:
			_p(n, M.box(Vector3(0.34, 0.18, 0.1)), Color("#b8bec4"), Vector3(0, 0, 0), Vector3.ZERO, Vector3.ONE, true)
			for x in [-0.1, 0.1]:
				_p(n, M.cyl(0.055, 0.055, 0.012, 14), Color("#2d3036"), Vector3(x, -0.01, 0.052), Vector3(PI / 2, 0, 0))
				_p(n, M.cyl(0.02, 0.02, 0.016, 10), Color("#6b6f75"), Vector3(x, -0.01, 0.055), Vector3(PI / 2, 0, 0))
			_p(n, M.box(Vector3(0.05, 0.035, 0.012)), Color("#9fd46a"), Vector3(0, 0.05, 0.05))
			_p(n, M.tube(PackedVector3Array([Vector3(-0.14, 0.09, 0), Vector3(-0.1, 0.15, 0), Vector3(0.1, 0.15, 0), Vector3(0.14, 0.09, 0)]), 0.008), Color("#2d3036"), Vector3.ZERO)
		ItemArt.KNIFE:
			_p(n, M.box(Vector3(0.022, 0.09, 0.024)), Color("#2a2a2e"), Vector3(0, 0.0, 0.0))
			_p(n, M.box(Vector3(0.03, 0.16, 0.006)), Color("#d8dde2"), Vector3(0, 0.125, 0.0), Vector3.ZERO, Vector3.ONE, true)
		ItemArt.STORE_KEY, ItemArt.BAR_KEY:
			var col := Color("#d4b870") if kind == ItemArt.STORE_KEY else Color("#c9a24a")
			_p(n, M.torus(0.012, 0.024, 12), col, Vector3(0, 0.03, 0.02), Vector3(PI / 2, 0, 0))
			_p(n, M.box(Vector3(0.012, 0.07, 0.006)), col, Vector3(0, 0.085, 0.02))
			_p(n, M.box(Vector3(0.02, 0.01, 0.006)), col, Vector3(0.01, 0.11, 0.02))
		ItemArt.ROLLED:
			_p(n, M.cyl(0.006, 0.007, 0.08, 6), Color("#f4ead0"), Vector3(0, 0.03, 0.02), Vector3(0, 0, 0.9))
		ItemArt.PAINKILLER, ItemArt.CHARCOAL, ItemArt.VITAMIN:
			var col: Color = {ItemArt.PAINKILLER: Color("#f4f6f8"), ItemArt.CHARCOAL: Color("#2d3036"), ItemArt.VITAMIN: Color("#f39c12")}[kind]
			_p(n, M.box(Vector3(0.09, 0.06, 0.012)), Color("#dfe6ea"), Vector3(0, 0.04, 0.02), Vector3(-0.4, 0, 0), Vector3.ONE, true)
			for x in [-0.02, 0.02]:
				_p(n, M.sphere(0.012, 6, 4), col, Vector3(x, 0.042, 0.03), Vector3.ZERO, Vector3(1, 1, 0.5))
		ItemArt.PLASTER:
			_p(n, M.box(Vector3(0.1, 0.03, 0.004)), Color("#e8c09a"), Vector3(0, 0.04, 0.02), Vector3(0, 0, 0.6))
			_p(n, M.box(Vector3(0.03, 0.025, 0.006)), Color("#f4ead0"), Vector3(0, 0.04, 0.02), Vector3(0, 0, 0.6))
		ItemArt.GROUNDS:
			_p(n, M.cyl(0.045, 0.04, 0.04, 10), Color("#5e4130"), Vector3(0, 0.03, 0.02), Vector3.ZERO, Vector3.ONE, true)
		_:
			_p(n, M.box(Vector3(0.09, 0.09, 0.09)), Color("#cfc6b2"), Vector3(0, 0.04, 0.02), Vector3.ZERO, Vector3.ONE, true)
	return n


## A mug with a handle; coffee / latte inside, dregs in the dirty one.
static func _mug(n: Node3D, kind: int) -> void:
	var white := Color("#f1ece2")
	_p(n, M.cyl(0.042, 0.036, 0.095, 14), white, Vector3(0, 0.035, 0.03), Vector3.ZERO, Vector3.ONE, true)
	_p(n, M.tube(M.arc(Vector3(0.045, 0.04, 0), 0.025, -PI / 2, PI / 2, 8), 0.007, 5), white, Vector3(0, 0, 0.03))
	var top := Color("#6b4a2e") if kind == ItemArt.COFFEE else (Color("#c49a6c") if kind == ItemArt.LATTE else Color("#9c7b5b"))
	if kind != ItemArt.CUP:
		_p(n, M.cyl(0.038, 0.038, 0.004, 14), top, Vector3(0, 0.074 if kind != ItemArt.EMPTY_CUP else 0.0, 0.03))


## A plate of food (carried in both hands).
static func _plate(n: Node3D, kind: int) -> void:
	if kind == ItemArt.PIZZA:
		_p(n, M.box(Vector3(0.3, 0.035, 0.3)), Color("#e8dcc0"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, true)
		_p(n, M.box(Vector3(0.1, 0.004, 0.06)), Color("#c9463a"), Vector3(0, 0.019, 0.05))
		return
	if kind == ItemArt.SUSHI:
		_p(n, M.box(Vector3(0.26, 0.025, 0.1)), Color("#b88a4e"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, true)
		for k in 3:
			_p(n, M.cyl(0.03, 0.03, 0.035, 10), Color("#262a2e"), Vector3(-0.08 + k * 0.08, 0.03, 0))
			_p(n, M.cyl(0.022, 0.022, 0.037, 10), Color("#f4efe4"), Vector3(-0.08 + k * 0.08, 0.03, 0))
			_p(n, M.cyl(0.01, 0.01, 0.039, 6), Color("#e07a5a"), Vector3(-0.08 + k * 0.08, 0.03, 0))
		return
	if kind == ItemArt.SALAD:
		_p(n, M.cyl(0.11, 0.06, 0.07, 16), Color("#e9e4d6"), Vector3(0, 0.02, 0), Vector3.ZERO, Vector3.ONE, true)
		for q in [Vector2(-0.04, 0), Vector2(0.04, 0.02), Vector2(0, -0.04), Vector2(0.02, 0.04), Vector2(-0.03, -0.03)]:
			_p(n, M.sphere(0.035, 8, 5), Color("#7da04f"), Vector3(q.x, 0.055, q.y), Vector3.ZERO, Vector3(1, 0.6, 1))
		_p(n, M.sphere(0.018, 6, 4), Color("#c9463a"), Vector3(0.01, 0.075, 0.0))
		return
	_p(n, M.cyl(0.13, 0.1, 0.018, 18), Color("#efe9dc"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, true)
	if kind == ItemArt.PIEROGI:
		for k in 3:
			_p(n, M.sphere(0.035, 10, 5), Color("#f0e0b6"), Vector3(-0.05 + k * 0.05, 0.02, (k % 2) * 0.03 - 0.01), Vector3(0, k * 0.7, 0), Vector3(1.2, 0.5, 0.7))
	else:
		_p(n, M.sphere(0.07, 10, 5), Color("#d49a4a"), Vector3(-0.02, 0.018, 0), Vector3.ZERO, Vector3(1, 0.18, 0.8))
		for q in [Vector2(0.07, 0.02), Vector2(0.06, -0.04)]:
			_p(n, M.sphere(0.022, 8, 5), Color("#f0dc9a"), Vector3(q.x, 0.025, q.y))
