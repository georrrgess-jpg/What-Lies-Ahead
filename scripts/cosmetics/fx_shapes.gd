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


## Lit, shiny material coloured by instance colour (coins, gems).
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


static func cube(lit := false) -> Mesh:
	var key := "cube%s" % lit
	if _meshes.has(key):
		return _meshes[key]
	var b := BoxMesh.new()
	b.size = Vector3.ONE
	return _cached(key, _to_array(b), shiny_material() if lit else glow_material())


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


static func star(lit := false) -> Mesh:
	var key := "star%s" % lit
	if _meshes.has(key):
		return _meshes[key]
	var pts := PackedVector2Array()
	for i in 10:
		var r := 0.5 if i % 2 == 0 else 0.22
		var a := PI * 0.5 + PI * i / 5.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	return _cached(key, extrude(pts, 0.16), shiny_material() if lit else glow_material())


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
	var tris := Geometry2D.triangulate_polygon(pts)
	var h := depth * 0.5
	for i in range(0, tris.size(), 3):
		for k in [0, 1, 2]:
			var p := pts[tris[i + k]]
			st.add_vertex(Vector3(p.x, p.y, h))
		for k in [2, 1, 0]:
			var p2 := pts[tris[i + k]]
			st.add_vertex(Vector3(p2.x, p2.y, -h))
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		for v in [Vector3(a.x, a.y, h), Vector3(b.x, b.y, h), Vector3(b.x, b.y, -h), Vector3(a.x, a.y, h), Vector3(b.x, b.y, -h), Vector3(a.x, a.y, -h)]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


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
