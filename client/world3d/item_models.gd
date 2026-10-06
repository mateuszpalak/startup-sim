## Small 3D models of the inventory items (kinds of game/item_art.gd /
## server/src/inventory.rs), built from MeshBatch primitives once per kind
## and cached. Models are roughly real-size, standing on y = 0, centred on
## x/z = 0; the views scale them up a bit so they read from the camera.
extends RefCounted

const MeshBatch = preload("res://world3d/mesh_batch.gd")
const Materials = preload("res://world3d/materials.gd")
const A = preload("res://game/item_art.gd")

const INK := Color("#2a2118")
const WHITE := Color("#f1eee8")
const BREAD := Color("#d9a35f")
const CRUST := Color("#a8692f")
const GLASS_GREEN := Color(0.25, 0.5, 0.3, 0.85)
const GLASS_BROWN := Color(0.45, 0.25, 0.1, 0.85)
const GLASS_CLEAR := Color(0.85, 0.9, 0.95, 0.55)

static var _cache := {}


## The mesh of item `kind` (shared; don't modify).
static func mesh(kind: int) -> ArrayMesh:
	if _cache.has(kind):
		return _cache[kind]
	var b := MeshBatch.new()
	build(b, kind)
	var m := b.commit(Materials.get_all())
	_cache[kind] = m
	return m


## Put a primitive at `pos`, turned by `basis` (resets after the call).
static func _at(b: MeshBatch, pos: Vector3, basis := Basis.IDENTITY) -> void:
	b.xf = Transform3D(basis, pos)


## A cylinder lying along x, centred on `c`.
static func _cyl_x(b: MeshBatch, c: Vector3, r: float, length: float, mat: String, col: Color, segs := 10) -> void:
	_at(b, c, Basis(Vector3.BACK, -PI / 2))
	b.cylinder(Vector3(0, -length / 2, 0), r, r, length, mat, col, segs)
	b.xf = Transform3D.IDENTITY


## A bottle standing up: body, shoulder, neck, cap.
static func _bottle(b: MeshBatch, r: float, h: float, mat: String, col: Color, cap: Color, label := Color(0, 0, 0, 0)) -> void:
	b.cylinder(Vector3.ZERO, r, r, h * 0.62, mat, col, 10)
	b.cylinder(Vector3(0, h * 0.62, 0), r, r * 0.38, h * 0.14, mat, col, 10, false)
	b.cylinder(Vector3(0, h * 0.76, 0), r * 0.36, r * 0.36, h * 0.18, mat, col, 8)
	b.cylinder(Vector3(0, h * 0.94, 0), r * 0.42, r * 0.42, h * 0.06, "matte", cap, 8)
	if label.a > 0.0:
		b.cylinder(Vector3(0, h * 0.2, 0), r * 1.03, r * 1.03, h * 0.28, "matte", label, 10, false)


## A can: body, top rim.
static func _can(b: MeshBatch, col: Color, band := Color(0, 0, 0, 0)) -> void:
	b.cylinder(Vector3.ZERO, 0.033, 0.033, 0.115, "metal", col, 12)
	b.cylinder(Vector3(0, 0.115, 0), 0.033, 0.028, 0.008, "metal", Color("#c9ced3"), 12)
	if band.a > 0.0:
		b.cylinder(Vector3(0, 0.045, 0), 0.034, 0.034, 0.03, "matte", band, 12, false)


## A plate with food on it is built by the caller; this is the plate.
static func _plate(b: MeshBatch, r := 0.12) -> void:
	b.cylinder(Vector3.ZERO, r * 0.7, r, 0.015, "matte", WHITE, 14)


## A box (packet) lying flat.
static func _packet(b: MeshBatch, sx: float, sy: float, sz: float, col: Color, top := Color(0, 0, 0, 0)) -> void:
	b.block(0, 0, sx, sz, 0, sy, "matte", col, top)


static func build(b: MeshBatch, kind: int) -> void:
	match kind:
		A.GUEST_PASS, A.EMPLOYEE_CARD:
			var col := Color("#f0c24a") if kind == A.GUEST_PASS else Color("#3b82c4")
			b.block(0, 0, 0.09, 0.055, 0, 0.004, "matte", WHITE, WHITE)
			b.block(0, -0.012, 0.09, 0.02, 0.004, 0.001, "matte", col)
			b.block(-0.025, 0.012, 0.022, 0.024, 0.004, 0.001, "matte", Color("#8a7a6a"))
			# lanyard loop
			for i in 6:
				var a := PI * (i / 5.0)
				b.block(cos(a) * 0.06, -0.06 - sin(a) * 0.05, 0.012, 0.012, 0, 0.004, "fabric", col)
		A.LAPTOP:
			b.block(0, 0, 0.32, 0.22, 0, 0.018, "metal", Color("#8a939c"), Color("#b4bcc3"))
			b.block(0, 0, 0.06, 0.04, 0.018, 0.001, "matte", Color("#dfe4e8"))
		A.COFFEE, A.EMPTY_CUP, A.CUP, A.LATTE:
			var cup := WHITE if kind != A.CUP else Color("#e85d4a")
			b.cylinder(Vector3.ZERO, 0.034, 0.042, 0.09, "matte", cup, 12)
			var fill: Color = {A.COFFEE: Color("#4a2c17"), A.LATTE: Color("#c8a27a"), A.EMPTY_CUP: Color("#6b4a33"), A.CUP: Color("#e85d4a")}[kind]
			b.cylinder(Vector3(0, 0.083, 0), 0.037, 0.037, 0.002, "matte", fill, 12)
			# handle
			_cyl_x(b, Vector3(0.05, 0.045, 0), 0.008, 0.03, "matte", cup, 6)
			if kind == A.COFFEE or kind == A.LATTE:  # a paper sleeve
				b.cylinder(Vector3(0, 0.03, 0), 0.039, 0.04, 0.03, "matte", Color("#b98a57"), 12, false)
		A.MILK:
			_packet(b, 0.07, 0.17, 0.07, WHITE)
			b.block(0, 0, 0.071, 0.071, 0.05, 0.05, "matte", Color("#3b82c4"))
			b.box(Vector3(-0.035, 0.17, -0.02), Vector3(0.035, 0.2, 0.02), "matte", WHITE)
		A.FRUIT:
			b.sphere(Vector3(0, 0.04, 0), 0.042, "matte", Color("#c8322a"), Vector3(1, 0.92, 1))
			b.cylinder(Vector3(0, 0.075, 0), 0.004, 0.003, 0.02, "wood", Color("#5a3a26"), 5)
			b.sphere(Vector3(0.015, 0.088, 0), 0.012, "leaf", Color("#4f9a3f"), Vector3(1.4, 0.35, 0.8), 3, 5)
		A.SANDWICH_CHEESE, A.SANDWICH_HAM:
			var mid := Color("#f2c94c") if kind == A.SANDWICH_CHEESE else Color("#e89a9a")
			b.block(0, 0, 0.12, 0.1, 0, 0.018, "matte", BREAD, Color("#e8c48f"))
			b.block(0, 0, 0.125, 0.105, 0.018, 0.01, "matte", mid)
			b.block(0, 0, 0.13, 0.11, 0.022, 0.004, "leaf", Color("#6fb04a"))
			b.block(0, 0, 0.12, 0.1, 0.028, 0.018, "matte", BREAD, Color("#e8c48f"))
		A.WRAP:
			_cyl_x(b, Vector3(0, 0.035, 0), 0.035, 0.16, "matte", Color("#e8cf9a"))
			_cyl_x(b, Vector3(0.081, 0.035, 0), 0.03, 0.004, "leaf", Color("#6fb04a"))
		A.KEBAB:
			_cyl_x(b, Vector3(0, 0.04, 0), 0.04, 0.17, "matte", Color("#e8cf9a"))
			_cyl_x(b, Vector3(0.05, 0.04, 0), 0.042, 0.07, "matte", Color("#d8d4cc"))  # paper
			_cyl_x(b, Vector3(-0.086, 0.04, 0), 0.034, 0.004, "matte", Color("#8a4a2a"))
		A.BURGER:
			b.cylinder(Vector3.ZERO, 0.055, 0.055, 0.018, "matte", BREAD)
			b.cylinder(Vector3(0, 0.018, 0), 0.058, 0.058, 0.02, "matte", Color("#6b3a1f"))
			b.cylinder(Vector3(0, 0.038, 0), 0.06, 0.06, 0.005, "leaf", Color("#6fb04a"))
			b.cylinder(Vector3(0, 0.043, 0), 0.057, 0.057, 0.005, "matte", Color("#f2c94c"))
			b.sphere(Vector3(0, 0.048, 0), 0.056, "matte", BREAD, Vector3(1, 0.55, 1), 4, 10)
		A.FRIES:
			b.cylinder(Vector3.ZERO, 0.035, 0.05, 0.09, "matte", Color("#d63a2f"), 8)
			for i in 9:
				var a := TAU * i / 9.0
				var r := 0.022 if i % 2 == 0 else 0.01
				b.block(cos(a) * r, sin(a) * r, 0.01, 0.01, 0.07, 0.05 + (i % 3) * 0.012, "matte", Color("#f2c94c"))
		A.BUN:
			b.sphere(Vector3(0, 0.02, 0), 0.06, "matte", Color("#d9a35f"), Vector3(1, 0.5, 1), 4, 10)
			b.sphere(Vector3(0, 0.04, 0), 0.025, "matte", Color("#f4ecd8"), Vector3(1, 0.4, 1), 3, 8)
		A.BAR:
			_packet(b, 0.13, 0.016, 0.04, Color("#5a2d82"), Color("#6c3a96"))
			b.block(0, 0, 0.05, 0.041, 0.016, 0.001, "matte", Color("#f2c94c"))
		A.CHIPS:
			b.sphere(Vector3(0, 0.03, 0), 0.08, "matte", Color("#e0a020"), Vector3(0.8, 0.35, 1.1), 4, 8)
			b.block(0, -0.075, 0.12, 0.02, 0.02, 0.02, "matte", Color("#c0392b"))
		A.WATER:
			_bottle(b, 0.03, 0.2, "glass", Color(0.6, 0.8, 0.95, 0.6), Color("#3b82c4"), Color("#3b82c4"))
		A.JUICE:
			_packet(b, 0.06, 0.12, 0.04, Color("#f39c12"), Color("#f4ecd8"))
			b.cylinder(Vector3(0.015, 0.12, 0), 0.004, 0.004, 0.03, "matte", WHITE, 5)
		A.ENERGY_DRINK:
			_can(b, Color("#2c3e50"), Color("#7ee03a"))
		A.BEER:
			_bottle(b, 0.03, 0.22, "glass", GLASS_BROWN, Color("#c9a227"), Color("#f2e3b0"))
		A.COLA:
			_can(b, Color("#d01f26"), WHITE)
		A.WINE:
			_bottle(b, 0.035, 0.3, "glass", Color(0.35, 0.05, 0.12, 0.9), Color("#5a1020"), Color("#efe6d2"))
		A.MALPKA:
			_bottle(b, 0.022, 0.12, "glass", GLASS_CLEAR, Color("#c0392b"), Color("#e9e2c8"))
		A.WHISKY:
			b.block(0, 0, 0.08, 0.05, 0, 0.14, "glass", Color(0.75, 0.42, 0.12, 0.85))
			b.block(0, 0, 0.081, 0.051, 0.04, 0.05, "matte", Color("#1e1e1e"))
			b.cylinder(Vector3(0, 0.14, 0), 0.014, 0.014, 0.04, "glass", Color(0.75, 0.42, 0.12, 0.85), 6)
			b.cylinder(Vector3(0, 0.18, 0), 0.017, 0.017, 0.02, "wood", Color("#3a2416"), 6)
		A.COGNAC:
			b.sphere(Vector3(0, 0.07, 0), 0.06, "glass", Color(0.6, 0.3, 0.08, 0.85), Vector3(1, 1.1, 0.6))
			b.cylinder(Vector3(0, 0.13, 0), 0.014, 0.014, 0.05, "glass", Color(0.6, 0.3, 0.08, 0.85), 6)
			b.cylinder(Vector3(0, 0.18, 0), 0.018, 0.018, 0.02, "metal", Color("#c9a227"), 6)
		A.VODKA:
			_bottle(b, 0.03, 0.26, "glass", GLASS_CLEAR, Color("#c0392b"), Color("#dfe7ef"))
		A.CIGARETTES:
			_packet(b, 0.055, 0.085, 0.022, WHITE, Color("#c0392b"))
			b.block(0, 0, 0.056, 0.023, 0.055, 0.03, "matte", Color("#c0392b"))
			for i in 3:
				b.cylinder(Vector3(-0.015 + i * 0.015, 0.085, 0), 0.004, 0.004, 0.012, "matte", Color("#d9a35f"), 5)
		A.TOBACCO:
			b.block(0, 0, 0.11, 0.08, 0, 0.022, "matte", Color("#3d5a2f"), Color("#4f7340"))
			b.sphere(Vector3(0, 0.023, 0), 0.018, "leaf", Color("#c9a227"), Vector3(1.6, 0.2, 1))
		A.ROLLED:
			_cyl_x(b, Vector3(0, 0.006, 0), 0.006, 0.08, "matte", WHITE, 6)
			_cyl_x(b, Vector3(-0.042, 0.006, 0), 0.0062, 0.006, "matte", Color("#e07020"), 6)
		A.UMBRELLA:
			_cyl_x(b, Vector3(0, 0.025, 0), 0.025, 0.42, "fabric", Color("#2e5fa8"), 8)
			_at(b, Vector3(0.21, 0.025, 0), Basis(Vector3.BACK, -PI / 2))
			b.cylinder(Vector3.ZERO, 0.025, 0.004, 0.06, "fabric", Color("#2e5fa8"), 8)
			b.xf = Transform3D.IDENTITY
			_cyl_x(b, Vector3(-0.25, 0.025, 0), 0.006, 0.08, "metal", Color("#9aa3ab"), 6)
			_cyl_x(b, Vector3(-0.3, 0.025, 0.02), 0.012, 0.05, "wood", Color("#5a3a26"), 6)
		A.DONUT:
			for i in 10:
				var a := TAU * i / 10.0
				b.sphere(Vector3(cos(a) * 0.04, 0.02, sin(a) * 0.04), 0.024, "matte", Color("#c8843f"), Vector3.ONE, 3, 6)
				b.sphere(Vector3(cos(a) * 0.04, 0.03, sin(a) * 0.04), 0.022, "matte", Color("#e8739a"), Vector3(1, 0.5, 1), 3, 6)
		A.COOKIE:
			b.cylinder(Vector3.ZERO, 0.045, 0.043, 0.012, "matte", Color("#c8843f"), 12)
			for i in 5:
				var a := TAU * i / 5.0 + 0.4
				b.block(cos(a) * 0.024, sin(a) * 0.024, 0.01, 0.01, 0.012, 0.004, "matte", Color("#3a2416"))
		A.STORE_COOKIES:
			_packet(b, 0.16, 0.04, 0.07, Color("#2e5fa8"), Color("#3b72c0"))
			b.cylinder(Vector3(0, 0.04, 0), 0.022, 0.022, 0.001, "matte", Color("#c8843f"), 10)
		A.CHEESECAKE:
			_plate(b, 0.08)
			var tri := [Vector3(-0.05, 0, -0.04), Vector3(0.06, 0, 0), Vector3(-0.05, 0, 0.04)]
			_at(b, Vector3(0, 0.015, 0))
			for k in 3:
				var p0: Vector3 = tri[k]
				var p1: Vector3 = tri[(k + 1) % 3]
				var n := (p1 - p0).cross(Vector3.UP).normalized()
				b.quad(p0, p1, p1 + Vector3(0, 0.05, 0), p0 + Vector3(0, 0.05, 0), n, "matte", Color("#f4e6b8") if k != 2 else Color("#c8843f"))
			b.quad(tri[0] + Vector3(0, 0.05, 0), tri[1] + Vector3(0, 0.05, 0), tri[2] + Vector3(0, 0.05, 0), tri[2] + Vector3(0, 0.05, 0), Vector3.UP, "matte", Color("#e8c46a"))
			b.xf = Transform3D.IDENTITY
		A.PIEROGI:
			_plate(b)
			for i in 5:
				var a := TAU * i / 5.0
				_at(b, Vector3(cos(a) * 0.05, 0.015, sin(a) * 0.05), Basis(Vector3.UP, -a))
				b.sphere(Vector3.ZERO, 0.03, "matte", Color("#f2e3c0"), Vector3(0.6, 0.45, 1), 3, 8)
			b.xf = Transform3D.IDENTITY
			b.sphere(Vector3(0, 0.02, 0), 0.015, "matte", Color("#c8843f"), Vector3(1, 0.4, 1), 3, 6)
		A.PIZZA:
			b.cylinder(Vector3.ZERO, 0.13, 0.13, 0.012, "matte", Color("#d9a35f"), 16)
			b.cylinder(Vector3(0, 0.012, 0), 0.115, 0.115, 0.003, "matte", Color("#c8322a"), 16)
			for i in 7:
				var a := TAU * i / 7.0
				b.cylinder(Vector3(cos(a) * 0.065, 0.015, sin(a) * 0.065), 0.022, 0.022, 0.002, "matte", Color("#f4ecd8"), 8)
				b.sphere(Vector3(cos(a + 0.4) * 0.035, 0.017, sin(a + 0.4) * 0.035), 0.008, "leaf", Color("#3f8a3a"), Vector3(1, 0.3, 1), 2, 5)
		A.SUSHI:
			b.block(0, 0, 0.2, 0.08, 0, 0.01, "wood", Color("#6e4c31"))
			for i in 4:
				var x := -0.07 + i * 0.046
				if i % 2 == 0:
					b.cylinder(Vector3(x, 0.01, 0), 0.02, 0.02, 0.03, "matte", Color("#1f2a1f"), 10)
					b.cylinder(Vector3(x, 0.04, 0), 0.016, 0.016, 0.001, "matte", Color("#f1eee8"), 10)
					b.cylinder(Vector3(x, 0.041, 0), 0.007, 0.007, 0.002, "matte", Color("#f0743a"), 6)
				else:
					b.block(x, 0, 0.04, 0.025, 0.01, 0.02, "matte", WHITE)
					b.block(x, 0, 0.045, 0.028, 0.03, 0.008, "matte", Color("#f0743a"))
		A.SCHNITZEL:
			_plate(b, 0.14)
			b.sphere(Vector3(-0.03, 0.016, 0), 0.08, "matte", Color("#c8843f"), Vector3(1, 0.12, 0.7), 3, 10)
			for i in 3:
				b.sphere(Vector3(0.06, 0.025, -0.04 + i * 0.04), 0.022, "matte", Color("#f2d77a"), Vector3.ONE, 3, 7)
			b.sphere(Vector3(0.04, 0.02, 0.07), 0.02, "leaf", Color("#6fb04a"), Vector3(1.5, 0.3, 1), 2, 6)
		A.SALAD:
			b.cylinder(Vector3.ZERO, 0.05, 0.085, 0.05, "matte", WHITE, 14, false)
			for i in 9:
				var a := TAU * i / 9.0
				var col: Color = [Color("#6fb04a"), Color("#4f8a3a"), Color("#e8c46a"), Color("#c8322a")][i % 4]
				b.sphere(Vector3(cos(a) * 0.045, 0.05, sin(a) * 0.045), 0.026, "leaf", col, Vector3(1, 0.5, 1), 3, 6)
			b.sphere(Vector3(0, 0.055, 0), 0.03, "leaf", Color("#8acb5a"), Vector3(1, 0.5, 1), 3, 6)
		A.BREATHALYSER:
			b.block(0, 0, 0.05, 0.12, 0, 0.022, "matte", Color("#e9ecef"), Color("#f4f6f8"))
			b.block(0, -0.02, 0.034, 0.03, 0.022, 0.001, "screen", Color("#7fe0a0"))
			b.block(0, 0.075, 0.016, 0.03, 0.006, 0.01, "matte", Color("#3b82c4"))
		A.KNIFE:
			b.block(0.045, 0, 0.13, 0.025, 0, 0.004, "metal", Color("#cfd5da"))
			b.block(-0.06, 0, 0.09, 0.022, 0, 0.016, "wood", Color("#3a2416"))
		A.REMOTE:
			b.block(0, 0, 0.05, 0.16, 0, 0.018, "matte", Color("#22242a"))
			b.block(0, -0.06, 0.012, 0.012, 0.018, 0.003, "matte", Color("#d63a2f"))
			for i in 6:
				b.block(-0.012 + (i % 2) * 0.024, -0.02 + (i / 2) * 0.03, 0.01, 0.01, 0.018, 0.003, "matte", Color("#8a93a3"))
		A.BOOMBOX:
			b.block(0, 0, 0.4, 0.12, 0, 0.2, "matte", Color("#2c2f36"), Color("#3a3d44"))
			for sx in [-1.0, 1.0]:
				_at(b, Vector3(sx * 0.12, 0.1, 0.06), Basis(Vector3.RIGHT, PI / 2))
				b.cylinder(Vector3.ZERO, 0.065, 0.06, 0.008, "metal", Color("#9aa3ab"), 14)
				b.cylinder(Vector3(0, 0.008, 0), 0.03, 0.02, 0.006, "matte", Color("#15171c"), 10)
			b.xf = Transform3D.IDENTITY
			b.block(0, 0.061, 0.08, 0.002, 0.13, 0.04, "screen", Color("#7fc4ef"))
			_cyl_x(b, Vector3(0, 0.25, 0), 0.01, 0.3, "metal", Color("#9aa3ab"), 6)
			for sx in [-0.15, 0.15]:
				b.block(sx, 0, 0.012, 0.012, 0.2, 0.05, "metal", Color("#9aa3ab"))
		A.STORE_KEY, A.BAR_KEY:
			var col := Color("#c9a227") if kind == A.BAR_KEY else Color("#aab2b8")
			var s := 0.7 if kind == A.BAR_KEY else 1.0
			b.cylinder(Vector3(-0.03 * s, 0, 0), 0.022 * s, 0.022 * s, 0.006, "metal", col, 10)
			b.block(0.025 * s, 0, 0.07 * s, 0.01 * s, 0, 0.006, "metal", col)
			b.block(0.045 * s, 0.009 * s, 0.008 * s, 0.012 * s, 0, 0.006, "metal", col)
			b.block(0.055 * s, 0.009 * s, 0.008 * s, 0.01 * s, 0, 0.006, "metal", col)
			if kind == A.STORE_KEY:
				b.cylinder(Vector3(-0.07, 0, 0), 0.02, 0.02, 0.012, "matte", Color("#d63a2f"), 8)  # tag
		A.PAINKILLER, A.CHARCOAL, A.VITAMIN:
			var col: Color = {A.PAINKILLER: Color("#e9ecef"), A.CHARCOAL: Color("#2c2f36"), A.VITAMIN: Color("#f39c12")}[kind]
			var stripe: Color = {A.PAINKILLER: Color("#d63a2f"), A.CHARCOAL: Color("#9aa3ab"), A.VITAMIN: Color("#f4ecd8")}[kind]
			if kind == A.VITAMIN:
				b.cylinder(Vector3.ZERO, 0.025, 0.025, 0.08, "matte", col, 10)
				b.cylinder(Vector3(0, 0.08, 0), 0.026, 0.026, 0.015, "matte", stripe, 10)
			else:
				_packet(b, 0.1, 0.022, 0.05, col)
				b.block(0, 0, 0.1, 0.051, 0.008, 0.008, "matte", stripe)
		A.PLASTER:
			b.block(0, 0, 0.08, 0.025, 0, 0.002, "matte", Color("#e8c8a0"))
			b.block(0, 0, 0.025, 0.02, 0.002, 0.001, "matte", Color("#f4ecd8"))
		A.GROUNDS:
			b.cylinder(Vector3.ZERO, 0.04, 0.035, 0.025, "matte", Color("#3a2416"), 10)
		_:
			b.block(0, 0, 0.12, 0.1, 0, 0.08, "fabric", Color("#c9a37a"))
	b.xf = Transform3D.IDENTITY
