## Procedural meshes and shared materials for the 3D characters and the
## things they hold. Everything is cached: a mesh by a key, a material by
## colour (+ flags), so a crowd of avatars shares a handful of resources.
##
## Winding: Godot treats clockwise triangles (seen from the normal side) as
## front faces; `_tri` orders every triangle from its intended normal, so the
## generators below never have to think about it.
extends RefCounted

const INK := Color("#1d1712")

static var _meshes := {}
static var _mats := {}


## A cached mesh: `maker` runs once per key.
static func cached(key: String, maker: Callable) -> Mesh:
	var m: Mesh = _meshes.get(key)
	if m == null:
		m = maker.call()
		_meshes[key] = m
	return m


# ------------------------------------------------------------------ materials

## Matte (toy-like) material of a colour. `outline` adds a thin ink hull
## (the 2D game's ink line), `alpha` < 1 makes it see-through, `glow` > 0
## makes it emissive (cigarette tips, screens).
static func mat(col: Color, outline := false, rough := 0.78, glow := 0.0) -> Material:
	var key := "%s|%d|%.2f|%.2f" % [col.to_html(), int(outline), rough, glow]
	var m: StandardMaterial3D = _mats.get(key)
	if m != null:
		return m
	m = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if col.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.shadow_mode = 0
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	if outline:
		m.next_pass = _outline()
	_mats[key] = m
	return m


## Unshaded, see-through (effects: smoke, smell, bubbles).
static func fx_mat(col: Color) -> Material:
	var key := "fx|" + col.to_html()
	var m: StandardMaterial3D = _mats.get(key)
	if m != null:
		return m
	m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


static func _outline() -> Material:
	var m: StandardMaterial3D = _mats.get("outline")
	if m != null:
		return m
	m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(INK, 1.0).lightened(0.05)
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.grow = true
	m.grow_amount = 0.011
	_mats["outline"] = m
	return m


# ----------------------------------------------------------------- primitives

static func sphere(r: float, segs := 16, rings := 10) -> Mesh:
	return cached("sph%.3f/%d/%d" % [r, segs, rings], func():
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = segs
		s.rings = rings
		return s)


static func capsule(r: float, h: float, segs := 10) -> Mesh:
	return cached("cap%.3f/%.3f/%d" % [r, h, segs], func():
		var c := CapsuleMesh.new()
		c.radius = r
		c.height = maxf(h, r * 2.0)
		c.radial_segments = segs
		c.rings = 4
		return c)


## A cylinder / cone / frustum standing on its centre.
static func cyl(top: float, bottom: float, h: float, segs := 12) -> Mesh:
	return cached("cyl%.3f/%.3f/%.3f/%d" % [top, bottom, h, segs], func():
		var c := CylinderMesh.new()
		c.top_radius = top
		c.bottom_radius = bottom
		c.height = h
		c.radial_segments = segs
		c.rings = 1
		return c)


static func box(size: Vector3) -> Mesh:
	return cached("box%s" % size, func():
		var b := BoxMesh.new()
		b.size = size
		return b)


## A ring lying in the XZ plane.
static func torus(inner: float, outer: float, segs := 20) -> Mesh:
	return cached("tor%.3f/%.3f/%d" % [inner, outer, segs], func():
		var t := TorusMesh.new()
		t.inner_radius = inner
		t.outer_radius = outer
		t.rings = segs
		t.ring_segments = 6
		return t)


# ------------------------------------------------------------ custom shapes

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var n := na + nb + nc
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_normal(nc)
	st.add_vertex(c)


## A grid of points (rows x cols) with normals -> triangles. `wrap` closes
## the columns into a ring.
static func _grid(st: SurfaceTool, pts: Array, nrm: Array, wrap: bool) -> void:
	var rows := pts.size()
	for i in rows - 1:
		var row: Array = pts[i]
		var cols := row.size()
		var last := cols if wrap else cols - 1
		for j in last:
			var j2 := (j + 1) % cols
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][j2]
			var c: Vector3 = pts[i + 1][j]
			var d: Vector3 = pts[i + 1][j2]
			var na: Vector3 = nrm[i][j]
			var nb: Vector3 = nrm[i][j2]
			var nc: Vector3 = nrm[i + 1][j]
			var nd: Vector3 = nrm[i + 1][j2]
			if a.distance_squared_to(b) > 1e-12:
				_tri(st, a, b, c, na, nb, nc)
			if c.distance_squared_to(d) > 1e-12:
				_tri(st, b, d, c, nb, nd, nc)


## Surface of revolution around +y. `profile` = [(radius, y)...] bottom to
## top; `a0..a1` the swept angle (0 = +z, the front) for partial panels.
static func lathe(profile: PackedVector2Array, segs := 18, a0 := 0.0, a1 := TAU) -> ArrayMesh:
	var full := is_equal_approx(a1 - a0, TAU)
	var cols := segs if full else segs + 1
	var pts := []
	var nrm := []
	for i in profile.size():
		var p := profile[i]
		# profile tangent -> normal in the (r, y) plane
		var prev := profile[maxi(i - 1, 0)]
		var next := profile[mini(i + 1, profile.size() - 1)]
		var t := (next - prev).normalized()
		var n2 := Vector2(t.y, -t.x)  # outward for a bottom-to-top profile
		var row := []
		var nrow := []
		for j in cols:
			var a := a0 + (a1 - a0) * float(j) / segs
			var dir := Vector3(sin(a), 0, cos(a))
			row.append(dir * p.x + Vector3(0, p.y, 0))
			var n := dir * n2.x + Vector3(0, n2.y, 0)
			nrow.append(n.normalized() if n.length() > 0.001 else Vector3.UP)
		pts.append(row)
		nrm.append(nrow)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_grid(st, pts, nrm, full)
	return st.commit()


## A tube along a polyline (mouths, brows, glasses, handles, letters).
static func tube(path: PackedVector3Array, r: float, sides := 6, closed := false) -> ArrayMesh:
	var n := path.size()
	var pts := []
	var nrm := []
	var normal := Vector3.ZERO
	for i in n:
		var prev := path[(i - 1 + n) % n] if closed else path[maxi(i - 1, 0)]
		var next := path[(i + 1) % n] if closed else path[mini(i + 1, n - 1)]
		var t := (next - prev).normalized()
		if normal == Vector3.ZERO:
			normal = t.cross(Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT).normalized()
		normal = (normal - t * normal.dot(t)).normalized()  # parallel transport
		var bin := t.cross(normal)
		var row := []
		var nrow := []
		for k in sides:
			var a := TAU * k / sides
			var d := normal * cos(a) + bin * sin(a)
			row.append(path[i] + d * r)
			nrow.append(d)
		pts.append(row)
		nrm.append(nrow)
	if closed:
		pts.append(pts[0])
		nrm.append(nrm[0])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_grid(st, pts, nrm, true)
	if not closed:  # flat end caps
		for e in [0, n - 1]:
			var c: Vector3 = path[e]
			var tn: Vector3 = (path[mini(e + 1, n - 1)] - path[maxi(e - 1, 0)]).normalized() * (-1.0 if e == 0 else 1.0)
			for k in sides:
				_tri(st, c, pts[e][k], pts[e][(k + 1) % sides], tn, tn, tn)
	return st.commit()


## Points of an arc in the XY plane (centre c, radius r, angles a0..a1).
static func arc(c: Vector3, r: float, a0: float, a1: float, n := 8) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in n + 1:
		var a := lerpf(a0, a1, float(k) / n)
		out.append(c + Vector3(cos(a), sin(a), 0) * r)
	return out


## A hair cap: part of a sphere whose hairline drops from the forehead
## (`front` deg from the top) over the temples (`side`) to the nape (`back`).
## `flare` widens it towards the hairline (volume).
static func hair_cap(r: float, front: float, side: float, back: float, flare := 0.0, segs := 22, rings := 9) -> ArrayMesh:
	var pts := []
	var nrm := []
	for i in rings + 1:
		var t := float(i) / rings
		var row := []
		var nrow := []
		for j in segs:
			var phi := TAU * j / segs  # 0 = front
			var c := cos(phi)
			# hairline: front .. side .. back, smoothly
			var lim: float = lerpf(side, front, c * c) if c > 0.0 else lerpf(side, back, c * c)
			var th := deg_to_rad(lim) * t
			var d := Vector3(sin(th) * sin(phi), cos(th), sin(th) * cos(phi))
			row.append(d * r * (1.0 + flare * t * t))
			nrow.append(d)
		pts.append(row)
		nrm.append(nrow)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_grid(st, pts, nrm, true)
	# the inside too (the cap is seen from below when lying / bent)
	var inner := []
	for row in pts:
		var ir := []
		for p in row:
			ir.append(p * 0.985)
		inner.append(ir)
	var inrm := []
	for row in nrm:
		var nr := []
		for d in row:
			nr.append(-d)
		inrm.append(nr)
	_grid(st, inner, inrm, true)
	return st.commit()


## A flat star (knockout stars) in the XY plane, a bit of thickness.
static func star(r: float, depth := 0.02) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := []
	for k in 10:
		var rr := r if k % 2 == 0 else r * 0.45
		var a := PI / 2 + k * PI / 5.0
		ring.append(Vector3(cos(a) * rr, sin(a) * rr, 0))
	for side in [1.0, -1.0]:
		var dz := Vector3(0, 0, depth * side)
		var n := Vector3(0, 0, side)
		for k in 10:
			_tri(st, dz, ring[k] + dz, ring[(k + 1) % 10] + dz, n, n, n)
	for k in 10:
		var a: Vector3 = ring[k]
		var b: Vector3 = ring[(k + 1) % 10]
		var n := (a + b).normalized()
		var dz := Vector3(0, 0, depth)
		_tri(st, a - dz, b - dz, a + dz, n, n, n)
		_tri(st, b - dz, b + dz, a + dz, n, n, n)
	return st.commit()
