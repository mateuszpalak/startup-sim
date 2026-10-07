## Soft low-poly primitives on top of MeshBatch: chamfered boxes, lathed
## (turned) shapes, tubes between two points, discs, two-sided leaves.
## All take local coordinates and respect the batch's `xf` like MeshBatch.
extends RefCounted

const MeshBatch = preload("res://world3d/mesh_batch.gd")

const AX := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]


## One triangle in local space.
static func tri(b: MeshBatch, p: Vector3, q: Vector3, r: Vector3, n: Vector3, mat: String, col: Color) -> void:
	var st: SurfaceTool = b._st_at(mat, b.xf * p)
	b._tri(st, b.xf * p, b.xf * q, b.xf * r, (b.xf.basis * n).normalized(), col, Vector2.ZERO)


## A box with all edges chamfered by `r` (flat bevels catch the light).
## `top_col` (alpha > 0) paints the top face. The bottom face is skipped
## unless `bottom`.
static func rbox(b: MeshBatch, lo: Vector3, hi: Vector3, r: float, mat: String, col: Color, top_col := Color(0, 0, 0, 0), bottom := false) -> void:
	var c := (lo + hi) * 0.5
	var h := (hi - lo) * 0.5
	r = minf(r, minf(h.x, minf(h.y, h.z)) * 0.95)
	if r <= 0.001:
		b.box(lo, hi, mat, col, 63 if bottom else 63 & ~8, top_col)
		return
	var tc := top_col if top_col.a > 0.0 else col
	var hr := h - Vector3(r, r, r)
	# vertex: corner signs s, pushed out along axis a
	var V := func(s: Vector3, a: int) -> Vector3:
		var p := c + s * hr
		p[a] += s[a] * r
		return p
	# faces
	for a in 3:
		for sg in [-1.0, 1.0]:
			if a == 1 and sg < 0 and not bottom:
				continue
			var u := (a + 1) % 3
			var v := (a + 2) % 3
			var pts := []
			for k in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
				var s := Vector3.ZERO
				s[a] = sg
				s[u] = k[0]
				s[v] = k[1]
				pts.append(V.call(s, a))
			b.quad(pts[0], pts[1], pts[2], pts[3], AX[a] * sg, mat, tc if (a == 1 and sg > 0) else col)
	# edges
	for a in 3:
		for bb in range(a + 1, 3):
			var cc := 3 - a - bb
			for sa in [-1.0, 1.0]:
				for sb in [-1.0, 1.0]:
					var s0 := Vector3.ZERO
					s0[a] = sa
					s0[bb] = sb
					s0[cc] = -1.0
					var s1 := s0
					s1[cc] = 1.0
					var n: Vector3 = (AX[a] * sa + AX[bb] * sb).normalized()
					b.quad(V.call(s0, a), V.call(s1, a), V.call(s1, bb), V.call(s0, bb), n, mat, col)
	# corners
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var s := Vector3(sx, sy, sz)
				tri(b, V.call(s, 0), V.call(s, 1), V.call(s, 2), s.normalized(), mat, col)


## rbox by base centre and size, standing on y0.
static func rblock(b: MeshBatch, cx: float, cz: float, sx: float, sz: float, y0: float, h: float, r: float, mat: String, col: Color, top_col := Color(0, 0, 0, 0)) -> void:
	rbox(b, Vector3(cx - sx / 2, y0, cz - sz / 2), Vector3(cx + sx / 2, y0 + h, cz + sz / 2), r, mat, col, top_col)


## A turned shape around the vertical axis at `base`: `prof` is an Array of
## Vector2(radius, height) from bottom to top. A radius-0 end closes it.
## `top_cap` closes the last ring with a flat disc (with `cap_col`).
static func lathe(b: MeshBatch, base: Vector3, prof: Array, mat: String, col: Color, segs := 12, top_cap := true, cap_col := Color(0, 0, 0, 0)) -> void:
	for j in prof.size() - 1:
		var p0: Vector2 = prof[j]
		var p1: Vector2 = prof[j + 1]
		var dr := p1.x - p0.x
		var dy := p1.y - p0.y
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var dm := (d0 + d1).normalized()
			var n := (dm * dy - Vector3.UP * dr).normalized()
			if n.length_squared() < 0.5:
				n = dm
			var q0 := base + d0 * p0.x + Vector3(0, p0.y, 0)
			var q1 := base + d1 * p0.x + Vector3(0, p0.y, 0)
			var q2 := base + d1 * p1.x + Vector3(0, p1.y, 0)
			var q3 := base + d0 * p1.x + Vector3(0, p1.y, 0)
			if p0.x < 0.0005:
				tri(b, q0, q2, q3, n, mat, col)
			elif p1.x < 0.0005:
				tri(b, q0, q1, q2, n, mat, col)
			else:
				b.quad(q0, q1, q2, q3, n, mat, col)
	var last: Vector2 = prof[prof.size() - 1]
	if top_cap and last.x > 0.0005:
		disc(b, base + Vector3(0, last.y, 0), last.x, mat, cap_col if cap_col.a > 0.0 else col, segs)


## Horizontal disc facing up (or down with `down`).
static func disc(b: MeshBatch, c: Vector3, r: float, mat: String, col: Color, segs := 12, down := false) -> void:
	var n := Vector3.DOWN if down else Vector3.UP
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		tri(b, c, c + Vector3(cos(a0), 0, sin(a0)) * r, c + Vector3(cos(a1), 0, sin(a1)) * r, n, mat, col)


## A round bar from `p` to `q` (radius r).
static func tube(b: MeshBatch, p: Vector3, q: Vector3, r: float, mat: String, col: Color, segs := 6, caps := false) -> void:
	var d := q - p
	var L := d.length()
	if L < 0.0001:
		return
	var y := d / L
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var keep := b.xf
	b.xf = keep * Transform3D(Basis(x, y, z), p)
	b.cylinder(Vector3.ZERO, r, r, L, mat, col, segs, caps)
	b.xf = keep


## A flat leaf / blade, visible from both sides: a diamond from `p` towards
## `tip`, `w` wide, bent by `droop` (metres down at the tip).
static func leaf(b: MeshBatch, p: Vector3, tip: Vector3, w: float, mat: String, col: Color, droop := 0.0) -> void:
	var d := tip - p
	var side := d.cross(Vector3.UP)
	if side.length_squared() < 1e-6:
		side = Vector3.RIGHT
	side = side.normalized() * w * 0.5
	var mid := p + d * 0.45 + Vector3(0, droop * 0.25, 0)
	var t := tip - Vector3(0, droop, 0)
	var n := side.cross(t - p).normalized()
	if n.y < 0:
		n = -n
	var c2 := col.lightened(0.08)
	for sg in [1.0, -1.0]:
		tri(b, p, mid + side, mid - side, n * sg, mat, col)
		tri(b, mid + side, t, mid - side, n * sg, mat, c2)


## Small deterministic colour jitter (hue-preserving lightness / tint).
static func vary(col: Color, seed: int, amt := 0.06) -> Color:
	var h := absi(hash(seed))
	var l := (float(h % 1000) / 1000.0 - 0.5) * 2.0 * amt
	var t := (float((h / 1000) % 1000) / 1000.0 - 0.5) * amt
	var c := col.lightened(l) if l > 0 else col.darkened(-l)
	return Color(clampf(c.r + t, 0, 1), c.g, clampf(c.b - t, 0, 1), c.a)
