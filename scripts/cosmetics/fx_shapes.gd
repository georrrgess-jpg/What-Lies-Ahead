class_name FxShapes
extends RefCounted
## Shared meshes and materials for cosmetic effects (kill effects, tracers).
## Everything is built once in code and cached, so every effect draws with
## the same few materials (and FxWarmup can compile them up front).

const BUBBLE_SHADER := "res://art/shaders/skin_bubble.gdshader"

static var _meshes := {}
static var _mats := {}
static var _star_tex: ImageTexture


## Unshaded material that takes its colour from vertex / instance colour.
static func glow_material() -> StandardMaterial3D:
	if not _mats.has("glow"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats["glow"] = m
	return _mats["glow"]


## Lit, shiny material coloured by instance colour (coins).
static func shiny_material() -> StandardMaterial3D:
	if not _mats.has("shiny"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.metallic = 0.75
		m.roughness = 0.25
		m.emission_enabled = true
		m.emission = Color(0.35, 0.25, 0.05)
		_mats["shiny"] = m
	return _mats["shiny"]


## Additive glow for flashes, rings and beams; fade it with
## GeometryInstance3D.transparency.
static func additive_material(color: Color) -> StandardMaterial3D:
	var key := "add|" + color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.vertex_color_use_as_albedo = true
		m.albedo_color = color
		_mats[key] = m
	return _mats[key]


## Additive billboard showing a soft six-pointed star (big flashes).
static func star_flash_material(color: Color) -> StandardMaterial3D:
	var key := "starflash|" + color.to_html()
	if not _mats.has(key):
		var m := additive_material(color).duplicate() as StandardMaterial3D
		m.albedo_texture = star_texture()
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_mats[key] = m
	return _mats[key]


static func bubble_material() -> ShaderMaterial:
	if not _mats.has("bubble"):
		var m := ShaderMaterial.new()
		m.shader = load(BUBBLE_SHADER)
		_mats["bubble"] = m
	return _mats["bubble"]


static func _cached(key: String, mesh: Mesh, material: Material) -> Mesh:
	mesh.surface_set_material(0, material)
	_meshes[key] = mesh
	return mesh


static func cube() -> Mesh:
	if _meshes.has("cube"):
		return _meshes["cube"]
	var b := BoxMesh.new()
	b.size = Vector3.ONE
	return _cached("cube", _to_array(b), glow_material())


static func ball() -> Mesh:
	if _meshes.has("ball"):
		return _meshes["ball"]
	return _cached("ball", _sphere(10, 6), glow_material())


static func bubble() -> Mesh:
	if _meshes.has("bubble"):
		return _meshes["bubble"]
	return _cached("bubble", _sphere(16, 10), bubble_material())


## A coin: a flat cylinder standing in the XY plane (flips about X).
static func coin() -> Mesh:
	if _meshes.has("coin"):
		return _meshes["coin"]
	var c := CylinderMesh.new()
	c.top_radius = 0.5
	c.bottom_radius = 0.5
	c.height = 0.16
	c.radial_segments = 16
	c.rings = 1
	return _cached("coin", _rotated(_to_array(c), Basis(Vector3.RIGHT, PI * 0.5)), shiny_material())


static func star() -> Mesh:
	if _meshes.has("star"):
		return _meshes["star"]
	var pts := PackedVector2Array()
	for i in 10:
		var r := 0.5 if i % 2 == 0 else 0.22
		var a := PI * 0.5 + PI * i / 5.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	return _cached("star", extrude(pts, 0.16), glow_material())


static func heart() -> Mesh:
	if _meshes.has("heart"):
		return _meshes["heart"]
	var pts := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(Vector2(x, y) / 34.0)
	return _cached("heart", extrude(pts, 0.18), glow_material())


## A flat six-armed snowflake.
static func snowflake() -> Mesh:
	if _meshes.has("snowflake"):
		return _meshes["snowflake"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 6:
		var b := Basis(Vector3.BACK, TAU * k / 6.0)
		_quad(st, b, Vector2(0.0, 0.0), Vector2(0.0, 0.5), 0.07)
		for side in [-1.0, 1.0]:
			var root := Vector2(0.0, 0.3)
			_quad(st, b, root, root + Vector2(side * 0.13, 0.13), 0.05)
	st.generate_normals()
	return _cached("snowflake", st.commit(), glow_material())


## A thin ring in the XY plane (shockwaves).
static func ring() -> Mesh:
	if _meshes.has("ring"):
		return _meshes["ring"]
	var t := TorusMesh.new()
	t.inner_radius = 0.46
	t.outer_radius = 0.5
	t.rings = 40
	t.ring_segments = 6
	return _cached("ring", _rotated(_to_array(t), Basis(Vector3.RIGHT, PI * 0.5)), additive_material(Color.WHITE))


static func _sphere(segments: int, rings: int) -> ArrayMesh:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = segments
	s.rings = rings
	return _to_array(s)


static func quad() -> Mesh:
	if not _meshes.has("quad"):
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		_meshes["quad"] = q
	return _meshes["quad"]


## Extrudes a closed 2D outline (XY) into a prism along Z, centred.
static func extrude(pts: PackedVector2Array, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_extrude_into(st, pts, depth, Color.WHITE, Color.WHITE, 0.0)
	st.generate_normals()
	return st.commit()


## Adds an extruded outline to `st`: faces in `face`, sides in `side`, moved
## `z` along Z.
static func _extrude_into(st: SurfaceTool, pts: PackedVector2Array, depth: float, face: Color, side: Color, z: float) -> void:
	var tris := Geometry2D.triangulate_polygon(pts)
	var h := depth * 0.5
	st.set_color(face)
	for i in range(0, tris.size(), 3):
		for k in [0, 1, 2]:
			var p := pts[tris[i + k]]
			st.add_vertex(Vector3(p.x, p.y, z + h))
		for k in [2, 1, 0]:
			var p2 := pts[tris[i + k]]
			st.add_vertex(Vector3(p2.x, p2.y, z - h))
	st.set_color(side)
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		for v in [Vector3(a.x, a.y, z + h), Vector3(b.x, b.y, z + h), Vector3(b.x, b.y, z - h), Vector3(a.x, a.y, z + h), Vector3(b.x, b.y, z - h), Vector3(a.x, a.y, z - h)]:
			st.add_vertex(v)


static func _quad(st: SurfaceTool, b: Basis, a: Vector2, c: Vector2, width: float) -> void:
	var d := (c - a).normalized()
	var n := Vector2(-d.y, d.x) * width * 0.5
	var corners := [a - n, c - n, c + n, a + n]
	for idx in [0, 1, 2, 0, 2, 3]:
		var p: Vector2 = corners[idx]
		st.add_vertex(b * Vector3(p.x, p.y, 0.0))


static func _to_array(prim: PrimitiveMesh) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, prim.get_mesh_arrays())
	return mesh


static func _rotated(mesh: ArrayMesh, b: Basis) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in verts.size():
		verts[i] = b * verts[i]
		normals[i] = b * normals[i]
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## Six-pointed star with a hot centre, drawn once.
static func star_texture() -> ImageTexture:
	if _star_tex:
		return _star_tex
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := (Vector2(x, y) + Vector2(0.5, 0.5)) / n * 2.0 - Vector2.ONE
			var r := p.length()
			var a := atan2(p.y, p.x)
			var rays := pow(absf(cos(a * 3.0)), 8.0) * 0.6
			var shape := clampf(1.0 - r / (0.3 + rays), 0.0, 1.0)
			var core := clampf(1.0 - r / 0.25, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(shape * shape + core, 0.0, 1.0)))
	_star_tex = ImageTexture.create_from_image(img)
	return _star_tex


# --- Props for the newer kill effects ------------------------------------------
# Built from primitives with the light baked into vertex colours, so they draw
# with the shared unshaded glow material and tint by instance colour.

const _LIGHT := Vector3(-0.35, 0.8, 0.5)


## Additive sphere for flashes (fade it with FxSwarm's "fade").
static func glow_ball() -> Mesh:
	if _meshes.has("glow_ball"):
		return _meshes["glow_ball"]
	return _cached("glow_ball", _sphere(12, 8), additive_material(Color.WHITE))


## Additive soft six-pointed star on a quad facing +Z (big flashes; FxSwarm
## "face" turns it to the camera).
static func star_quad() -> Mesh:
	if _meshes.has("star_quad"):
		return _meshes["star_quad"]
	if not _mats.has("starglow"):
		var m := additive_material(Color.WHITE).duplicate() as StandardMaterial3D
		m.albedo_texture = star_texture()
		_mats["starglow"] = m
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	return _cached("star_quad", _to_array(q), _mats["starglow"])


## A twisted balloon poodle in profile (XY plane, nose towards +X).
static func balloon_dog() -> Mesh:
	if _meshes.has("balloon_dog"):
		return _meshes["balloon_dog"]
	var st := _colored_tool()
	var w := Color.WHITE
	var parts := [
		[Vector3(-0.27, 0.0, 0), Vector3(0.17, 0.0, 0), 0.115], [Vector3(0.21, 0.03, 0), Vector3(0.29, 0.3, 0), 0.09],
		[Vector3(0.29, 0.35, 0), Vector3(0.52, 0.31, 0), 0.09], [Vector3(0.15, -0.03, 0.08), Vector3(0.19, -0.37, 0.09), 0.07],
		[Vector3(0.15, -0.03, -0.08), Vector3(0.19, -0.37, -0.09), 0.07], [Vector3(-0.25, -0.03, 0.08), Vector3(-0.3, -0.37, 0.09), 0.07],
		[Vector3(-0.25, -0.03, -0.08), Vector3(-0.3, -0.37, -0.09), 0.07], [Vector3(-0.31, 0.05, 0), Vector3(-0.41, 0.25, 0), 0.06],
		[Vector3(0.26, 0.37, 0.07), Vector3(0.2, 0.2, 0.13), 0.055], [Vector3(0.26, 0.37, -0.07), Vector3(0.2, 0.2, -0.13), 0.055],
	]
	for part in parts:
		var a: Vector3 = part[0]
		var b: Vector3 = part[1]
		var r: float = part[2]
		_part(st, _capsule(r, a.distance_to(b) + r * 2.0), _along(a, b), w)
	_part(st, _ball_prim(0.09), Transform3D(Basis(), Vector3(-0.43, 0.3, 0)), w)
	_part(st, _ball_prim(0.03), Transform3D(Basis(), Vector3(0.62, 0.31, 0)), w.darkened(0.2))
	return _cached("balloon_dog", st.commit(), glow_material())


## A faceted mirror ball with a hanger: silver tiles with a few coloured glints.
static func mirror_ball() -> Mesh:
	if _meshes.has("mirror_ball"):
		return _meshes["mirror_ball"]
	var st := _colored_tool()
	var segs := 16
	var rings := 10
	for r in rings:
		for s in segs:
			var h := fposmod(sin(r * 12.9898 + s * 78.233) * 43758.5453, 1.0)
			var c := Color(0.55, 0.58, 0.68).lerp(Color.WHITE, h)
			if h > 0.9:
				c = [Color(1.0, 0.5, 0.85), Color(0.5, 0.95, 1.0), Color(1.0, 0.92, 0.5)][s % 3]
			var corners := [_sph(r, s, rings, segs), _sph(r + 1, s, rings, segs), _sph(r + 1, s + 1, rings, segs), _sph(r, s + 1, rings, segs)]
			var n: Vector3 = (corners[0] + corners[2]).normalized()
			st.set_color(_lit(c, n))
			st.set_normal(n)
			for idx in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(corners[idx] * 0.97 + n * 0.015)
	_part(st, _cylinder_prim(0.05, 0.05, 0.12), Transform3D(Basis(), Vector3(0, 0.53, 0)), Color(0.35, 0.33, 0.4))
	return _cached("mirror_ball", st.commit(), glow_material())


static func _sph(r: int, s: int, rings: int, segs: int) -> Vector3:
	var phi := PI * r / rings
	var th := TAU * s / segs
	return Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th)) * 0.5


## A spotlight beam from the origin, tilted down, fading to its tip (additive).
static func beam() -> Mesh:
	if _meshes.has("beam"):
		return _meshes["beam"]
	var st := _colored_tool()
	var tilt := Basis(Vector3.RIGHT, -0.55)
	for side in [Vector3.RIGHT, Vector3.UP]:
		var a: Vector3 = tilt * side
		var tip := tilt * Vector3.FORWARD
		var quad := [-a * 0.015, tip - a * 0.11, tip + a * 0.11, a * 0.015]
		var alpha := [0.9, 0.0, 0.0, 0.9]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color(1, 1, 1, alpha[idx]))
			st.add_vertex(quad[idx])
	return _cached("beam", st.commit(), additive_material(Color.WHITE))


## A flat square mirror tile (lit and shiny, like the coins).
static func tile() -> Mesh:
	if _meshes.has("tile"):
		return _meshes["tile"]
	var b := BoxMesh.new()
	b.size = Vector3(1.0, 1.0, 0.18)
	return _cached("tile", _to_array(b), shiny_material())


## A lucky red 7 with a gold rim, facing +Z.
static func lucky_seven() -> Mesh:
	if _meshes.has("lucky_seven"):
		return _meshes["lucky_seven"]
	var pts := PackedVector2Array([Vector2(-0.34, 0.5), Vector2(0.36, 0.5), Vector2(0.36, 0.35), Vector2(-0.02, -0.5),
		Vector2(-0.26, -0.5), Vector2(0.1, 0.3), Vector2(-0.34, 0.3)])
	var st := _colored_tool()
	_extrude_into(st, pts, 0.16, Color(0.95, 0.12, 0.2), Color(0.7, 0.05, 0.12), 0.02)
	var rim: PackedVector2Array = Geometry2D.offset_polygon(pts, 0.07, Geometry2D.JOIN_ROUND)[0]
	_extrude_into(st, rim, 0.12, Color(1.0, 0.8, 0.25), Color(0.85, 0.55, 0.1), -0.04)
	return _cached("lucky_seven", st.commit(), glow_material())


## A little bedsheet ghost facing +Z: wavy hem, big eyes, rosy cheeks, arm nubs.
static func ghost() -> Mesh:
	if _meshes.has("ghost"):
		return _meshes["ghost"]
	var st := _colored_tool()
	var body := Color(0.96, 0.95, 1.0)
	var segs := 22
	var rows := 12
	for j in rows:
		for s in segs:
			var corners := [_ghost_point(j, s, rows, segs), _ghost_point(j + 1, s, rows, segs),
				_ghost_point(j + 1, s + 1, rows, segs), _ghost_point(j, s + 1, rows, segs)]
			for idx in [0, 1, 2, 0, 2, 3]:
				var v: Vector3 = corners[idx]
				var n := Vector3(v.x, maxf(v.y - 0.08, -0.1) * 1.4, v.z).normalized()
				st.set_color(_lit(body, n))
				st.set_normal(n)
				st.add_vertex(v)
	var ink := Color(0.1, 0.07, 0.18)
	for x in [-0.14, 0.14]:
		_part(st, _ball_prim(0.075), Transform3D(Basis.from_scale(Vector3(0.9, 1.3, 0.5)), Vector3(x, 0.14, 0.4)), ink)
		_part(st, _ball_prim(0.022), Transform3D(Basis(), Vector3(x + 0.025, 0.19, 0.44)), Color.WHITE)
		_part(st, _ball_prim(0.06), Transform3D(Basis.from_scale(Vector3(1.3, 0.7, 0.4)), Vector3(x * 1.75, 0.02, 0.37)), Color(1.0, 0.55, 0.7))
		_part(st, _ball_prim(0.1), Transform3D(Basis(), Vector3(x * 3.2, -0.1, 0.05)), body)
	_part(st, _ball_prim(0.045), Transform3D(Basis.from_scale(Vector3(1.0, 1.2, 0.5)), Vector3(0, 0.0, 0.43)), ink)
	return _cached("ghost", st.commit(), glow_material())


## A point on the ghost: a dome over a slightly flared skirt with a wavy hem.
static func _ghost_point(j: int, s: int, rows: int, segs: int) -> Vector3:
	var th := TAU * s / segs
	var u := float(j) / rows
	var y: float
	var r: float
	if u < 0.5:
		var phi := u / 0.5 * PI * 0.5
		y = 0.08 + 0.42 * cos(phi)
		r = 0.42 * sin(phi)
	else:
		var v := (u - 0.5) / 0.5
		y = lerpf(0.08, -0.45 + 0.06 * sin(th * 6.0), v)
		r = 0.42 + 0.08 * v
	return Vector3(sin(th) * r, y, cos(th) * r)


## A snow globe's gold base with a red band and a little pine tree inside;
## the globe itself (radius 0.5) is a bubble at the origin.
static func globe_base() -> Mesh:
	if _meshes.has("globe_base"):
		return _meshes["globe_base"]
	var st := _colored_tool()
	_part(st, _cylinder_prim(0.36, 0.44, 0.2), Transform3D(Basis(), Vector3(0, -0.56, 0)), Color(1.0, 0.75, 0.3))
	_part(st, _cylinder_prim(0.45, 0.45, 0.05), Transform3D(Basis(), Vector3(0, -0.6, 0)), Color(0.9, 0.2, 0.32))
	_part(st, _cylinder_prim(0.34, 0.34, 0.03), Transform3D(Basis(), Vector3(0, -0.45, 0)), Color(0.95, 0.97, 1.0))
	_part(st, _cylinder_prim(0.0, 0.17, 0.26), Transform3D(Basis(), Vector3(0, -0.2, 0)), Color(0.2, 0.75, 0.45))
	_part(st, _cylinder_prim(0.0, 0.21, 0.24), Transform3D(Basis(), Vector3(0, -0.32, 0)), Color(0.15, 0.62, 0.38))
	_part(st, _cylinder_prim(0.035, 0.035, 0.08), Transform3D(Basis(), Vector3(0, -0.45, 0)), Color(0.55, 0.35, 0.2))
	_part(st, _ball_prim(0.035), Transform3D(Basis(), Vector3(0, -0.06, 0)), Color(1.0, 0.9, 0.35))
	return _cached("globe_base", st.commit(), glow_material())


## A carnival prize ticket: notched ends, a printed frame and a star.
static func ticket() -> Mesh:
	if _meshes.has("ticket"):
		return _meshes["ticket"]
	var pts := PackedVector2Array([Vector2(-0.5, -0.25), Vector2(0.5, -0.25)])
	for i in 7:
		var a := -PI * 0.5 + PI * i / 6.0
		pts.append(Vector2(0.5 - 0.09 * cos(a), 0.09 * sin(a)))
	pts.append_array([Vector2(0.5, 0.25), Vector2(-0.5, 0.25)])
	for i in 7:
		var a := -PI * 0.5 + PI * i / 6.0
		pts.append(Vector2(-0.5 + 0.09 * cos(a), -0.09 * sin(a)))
	var st := _colored_tool()
	_extrude_into(st, pts, 0.03, Color.WHITE, Color(0.8, 0.8, 0.8), 0.0)
	var panel := PackedVector2Array([Vector2(-0.34, -0.15), Vector2(0.34, -0.15), Vector2(0.34, 0.15), Vector2(-0.34, 0.15)])
	_extrude_into(st, panel, 0.036, Color(0.68, 0.68, 0.68), Color(0.68, 0.68, 0.68), 0.0)
	var star_pts := PackedVector2Array()
	for i in 10:
		var a2 := PI * 0.5 + PI * i / 5.0
		star_pts.append(Vector2(cos(a2), sin(a2)) * (0.11 if i % 2 == 0 else 0.05))
	_extrude_into(st, star_pts, 0.042, Color.WHITE, Color.WHITE, 0.0)
	return _cached("ticket", st.commit(), glow_material())


## A wrapped sweet: a round candy with flared twist ends along X.
static func candy() -> Mesh:
	if _meshes.has("candy"):
		return _meshes["candy"]
	var st := _colored_tool()
	_part(st, _ball_prim(0.27), Transform3D(Basis.from_scale(Vector3(1.15, 0.9, 0.9)), Vector3.ZERO), Color(0.9, 0.9, 0.9))
	for side in [-1.0, 1.0]:
		var b := Basis(Vector3.BACK, -side * PI * 0.5)
		_part(st, _cylinder_prim(0.17, 0.02, 0.22), Transform3D(b, Vector3(side * 0.4, 0, 0)), Color.WHITE)
	return _cached("candy", st.commit(), glow_material())


static func _colored_tool() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Adds a primitive's triangles to `st`, moved by `xf`, coloured `col` with
## the light baked in.
static func _part(st: SurfaceTool, prim: PrimitiveMesh, xf: Transform3D, col: Color) -> void:
	var arrays := prim.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in idx:
		var n := (xf.basis * normals[i]).normalized()
		st.set_color(_lit(col, n))
		st.set_normal(n)
		st.add_vertex(xf * verts[i])


## Soft key light and a small highlight, baked into a vertex colour.
static func _lit(col: Color, n: Vector3) -> Color:
	var d := maxf(0.0, n.dot(_LIGHT.normalized()))
	var c := col * (0.62 + 0.38 * d)
	return Color(c.lerp(Color.WHITE, pow(d, 24.0) * 0.6), 1.0)


## A transform that stands a Y-axis primitive between `a` and `b`.
static func _along(a: Vector3, b: Vector3) -> Transform3D:
	var y := (b - a).normalized()
	var x := y.cross(Vector3.BACK if absf(y.z) < 0.9 else Vector3.UP).normalized()
	return Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c


static func _ball_prim(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


static func _cylinder_prim(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 16
	c.rings = 1
	return c
