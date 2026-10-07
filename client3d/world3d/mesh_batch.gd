## Collects procedural geometry, grouped by material key, and turns it into
## one ArrayMesh (a surface per material). Everything of a floor goes into a
## few batches, so a floor is a handful of draw calls.
##
## Primitives take local coordinates; `xf` (a Transform3D) is applied to all
## of them - set it to place / turn a whole prop, then reset it.
## Front faces: Godot culls counter-clockwise triangles, so `_tri` orders
## the vertices from the given normal.
extends RefCounted

var xf := Transform3D.IDENTITY
## > 0: split the geometry into square cells of this size (m, on x/z) -
## one mesh per cell (to_chunks). The Mobile renderer lights a mesh with at
## most 8 omni lights, so a whole-floor mesh would lose most room lamps.
var chunk := 0.0
## material key -> SurfaceTool
var _tools := {}
## chunked: material key -> {Vector2i cell: SurfaceTool}
var _cells := {}


func _st(mat: String) -> SurfaceTool:
	var st: SurfaceTool = _tools.get(mat)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[mat] = st
	return st


## The tool for a material at a world point (its cell when chunked).
func _st_at(mat: String, p: Vector3) -> SurfaceTool:
	if chunk <= 0.0:
		return _st(mat)
	var cell := Vector2i(floori(p.x / chunk), floori(p.z / chunk))
	var per: Dictionary = _cells.get_or_add(mat, {})
	var st: SurfaceTool = per.get(cell)
	if st == null:
		st = _st("%s@%d,%d" % [mat, cell.x, cell.y])
		per[cell] = st
	return st


func is_empty() -> bool:
	return _tools.is_empty()


## One triangle in world space (already transformed), normal `n`.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color, uv2: Vector2) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.set_uv(Vector2(v.x + v.y, v.z + v.y))
		st.set_uv2(uv2)
		st.add_vertex(v)


## A quad a-b-c-d (in order around the edge) facing `n` (local space).
## `uv2` is free per-surface data (the ground shader reads the pattern in x).
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, mat: String, col: Color, uv2 := Vector2.ZERO) -> void:
	a = xf * a
	b = xf * b
	c = xf * c
	d = xf * d
	n = (xf.basis * n).normalized()
	var st := _st_at(mat, (a + c) * 0.5)
	_tri(st, a, b, c, n, col, uv2)
	_tri(st, a, c, d, n, col, uv2)


## Horizontal rectangle at height y, facing up.
func quad_up(x0: float, z0: float, x1: float, z1: float, y: float, mat: String, col: Color, uv2 := Vector2.ZERO) -> void:
	quad(Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), Vector3.UP, mat, col, uv2)


## Axis-aligned box between two corners. `faces` is a bitmask of sides to
## emit: 1 +x, 2 -x, 4 +y, 8 -y, 16 +z, 32 -z (default: all but the bottom).
func box(lo: Vector3, hi: Vector3, mat: String, col: Color, faces := 63 & ~8, top_col := Color(0, 0, 0, 0)) -> void:
	var tc := top_col if top_col.a > 0.0 else col
	if faces & 4:
		quad(Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3.UP, mat, tc)
	if faces & 8:
		quad(Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z), Vector3.DOWN, mat, col)
	if faces & 1:
		quad(Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3.RIGHT, mat, col)
	if faces & 2:
		quad(Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, lo.y, hi.z), Vector3.LEFT, mat, col)
	if faces & 16:
		quad(Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3.BACK, mat, col)
	if faces & 32:
		quad(Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3.FORWARD, mat, col)


## Box by centre (x, z of the base) and size; sits on y0.
func block(cx: float, cz: float, sx: float, sz: float, y0: float, h: float, mat: String, col: Color, top_col := Color(0, 0, 0, 0)) -> void:
	box(Vector3(cx - sx / 2, y0, cz - sz / 2), Vector3(cx + sx / 2, y0 + h, cz + sz / 2), mat, col, 63 & ~8, top_col)


## Vertical cylinder (or cone / frustum) standing on `base`.
func cylinder(base: Vector3, r_bottom: float, r_top: float, h: float, mat: String, col: Color, segs := 10, caps := true) -> void:
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var slope := (r_bottom - r_top) / maxf(h, 0.001)
		var n := ((d0 + d1) * 0.5 + Vector3(0, slope, 0)).normalized()
		quad(base + d0 * r_bottom, base + d1 * r_bottom, base + d1 * r_top + Vector3(0, h, 0), base + d0 * r_top + Vector3(0, h, 0), n, mat, col)
		if caps and r_top > 0.0:
			var c := base + Vector3(0, h, 0)
			var st := _st_at(mat, xf * c)
			_tri(st, xf * c, xf * (c + d0 * r_top), xf * (c + d1 * r_top), (xf.basis * Vector3.UP).normalized(), col, Vector2.ZERO)


## Low-poly sphere (an icosphere-ish UV sphere), optionally squashed.
func sphere(c: Vector3, r: float, mat: String, col: Color, scale := Vector3.ONE, rings := 5, segs := 8) -> void:
	for j in rings:
		var t0 := PI * j / rings
		var t1 := PI * (j + 1) / rings
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			var p := func(t: float, a: float) -> Vector3:
				return Vector3(sin(t) * cos(a), cos(t), sin(t) * sin(a))
			var v00: Vector3 = p.call(t0, a0)
			var v01: Vector3 = p.call(t0, a1)
			var v11: Vector3 = p.call(t1, a1)
			var v10: Vector3 = p.call(t1, a0)
			var n := (v00 + v01 + v11 + v10).normalized()
			n = (n / scale).normalized()
			quad(c + v00 * r * scale, c + v01 * r * scale, c + v11 * r * scale, c + v10 * r * scale, n, mat, col)


## Build the mesh. `materials`: key -> Material. Returns null if empty.
func commit(materials: Dictionary) -> ArrayMesh:
	if _tools.is_empty():
		return null
	return _commit(_tools.keys(), materials)


func _commit(keys: Array, materials: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for key in keys:
		var st: SurfaceTool = _tools[key]
		st.commit(mesh)
		var mat: String = key.get_slice("@", 0)
		mesh.surface_set_material(mesh.get_surface_count() - 1, materials.get(mat))
		mesh.surface_set_name(mesh.get_surface_count() - 1, mat)
	return mesh


## Convenience: a MeshInstance3D with the batch's mesh (shadows on).
func to_instance(materials: Dictionary, name := "Batch") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = commit(materials)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


## The batch as nodes: one MeshInstance3D, or (chunk > 0) a Node3D with a
## MeshInstance3D per cell.
func to_node(materials: Dictionary, name := "Batch") -> Node3D:
	if chunk <= 0.0:
		return to_instance(materials, name)
	var cells := {}
	for key in _tools:
		var cell: String = key.get_slice("@", 1)
		if not cells.has(cell):
			cells[cell] = []
		cells[cell].append(key)
	var root := Node3D.new()
	root.name = name
	for cell in cells:
		var mi := MeshInstance3D.new()
		mi.name = cell.replace(",", "_")
		mi.mesh = _commit(cells[cell], materials)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(mi)
	return root
