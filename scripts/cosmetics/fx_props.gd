class_name FxProps
extends RefCounted
## Props of the update-13 kill effects (party popper, popcorn, scuffle cloud,
## ice block, bowling pins, K.O. letters, balloon bunch, lightning, rainbow,
## flying saucer). Like FxShapes' props they are built once from primitives
## with the light baked into vertex colours and drawn with FxShapes' shared
## materials; flat props face +Z (FxSwarm "face" turns them to the camera).

## Over-bright white for the cloud puffs, so their baked shade stays light (it clamps).
const BRIGHT := Color(1.4, 1.4, 1.45)
## Pixel font for the K.O. letters: rows top to bottom, "#" = a block.
const KO_GLYPHS := [
	["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	[".", ".", ".", ".", ".", ".", "#"],
	[".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	[".", ".", ".", ".", ".", ".", "#"],
	["#", "#", "#", "#", "#", ".", "#"],
]

static var _meshes := {}
static var _glass: StandardMaterial3D


static func _cache(key: String, mesh: Mesh, material: Material) -> Mesh:
	mesh.surface_set_material(0, material)
	_meshes[key] = mesh
	return mesh


## Unshaded, alpha-blended vertex colour (see-through ice that reads on any background).
static func glass_material() -> StandardMaterial3D:
	if _glass == null:
		_glass = StandardMaterial3D.new()
		_glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass.cull_mode = BaseMaterial3D.CULL_BACK
		_glass.vertex_color_use_as_albedo = true
	return _glass


## A party popper: a striped cone opening upwards (+Y) with a gold rim.
static func popper() -> Mesh:
	if _meshes.has("popper"):
		return _meshes["popper"]
	var st := FxShapes._colored_tool()
	var bands := [Color(1.0, 0.3, 0.62), Color(1.0, 0.88, 0.3)]
	for k in 4:
		var y0 := -0.5 + k * 0.25
		var r0 := lerpf(0.05, 0.32, k / 4.0)
		var r1 := lerpf(0.05, 0.32, (k + 1) / 4.0)
		FxShapes._part(st, FxShapes._cylinder_prim(r1, r0, 0.25), Transform3D(Basis(), Vector3(0, y0 + 0.125, 0)), bands[k % 2])
	FxShapes._part(st, _torus(0.3, 0.36), Transform3D(Basis(), Vector3(0, 0.5, 0)), Color(1.0, 0.78, 0.25))
	FxShapes._part(st, FxShapes._ball_prim(0.07), Transform3D(Basis(), Vector3(0, -0.52, 0)), Color(1.0, 0.78, 0.25))
	return _cache("popper", st.commit(), FxShapes.glow_material())


## A popped kernel: four lumpy cream puffs round a butter-yellow hull.
static func popcorn() -> Mesh:
	if _meshes.has("popcorn"):
		return _meshes["popcorn"]
	var st := FxShapes._colored_tool()
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var p := Vector3(cos(a) * 0.17, (0.1 if i % 2 == 0 else -0.08), sin(a) * 0.17)
		FxShapes._part(st, FxShapes._ball_prim(0.24 - i * 0.015), Transform3D(Basis(), p), Color(1.0, 0.97, 0.88))
	FxShapes._part(st, FxShapes._ball_prim(0.13), Transform3D(Basis.from_scale(Vector3(1.0, 0.7, 1.0)), Vector3(0, -0.2, 0)), Color(1.0, 0.8, 0.3))
	return _cache("popcorn", st.commit(), FxShapes.glow_material())


## A cartoon cloud puff: a big ball with three smaller bumps (tinted per instance).
static func puff() -> Mesh:
	if _meshes.has("puff"):
		return _meshes["puff"]
	var st := FxShapes._colored_tool()
	FxShapes._part(st, FxShapes._ball_prim(0.36), Transform3D(), BRIGHT)
	for i in 3:
		var a := TAU * i / 3.0
		FxShapes._part(st, FxShapes._ball_prim(0.22), Transform3D(Basis(), Vector3(cos(a) * 0.28, 0.12, sin(a) * 0.28)), BRIGHT)
	return _cache("puff", st.commit(), FxShapes.glow_material())


## A see-through block of ice (alpha-blended glass): pale faces, bright edges, a frosty
## highlight streak.
static func ice_cube() -> Mesh:
	if _meshes.has("ice_cube"):
		return _meshes["ice_cube"]
	var st := FxShapes._colored_tool()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_flat(st, box, Transform3D(), Color(0.62, 0.88, 1.0, 0.28))
	var bar := BoxMesh.new()
	bar.size = Vector3(1.04, 0.05, 0.05)
	for axis in 3:
		var b := Basis() if axis == 0 else (Basis(Vector3.BACK, PI * 0.5) if axis == 1 else Basis(Vector3.UP, PI * 0.5))
		for u in [-0.5, 0.5]:
			for v in [-0.5, 0.5]:
				var offset := Vector3(0, u, v) if axis == 0 else (Vector3(u, 0, v) if axis == 1 else Vector3(u, v, 0))
				_flat(st, bar, Transform3D(b, offset), Color(0.85, 0.97, 1.0, 0.9))
	var streak := BoxMesh.new()
	streak.size = Vector3(0.08, 0.6, 0.01)
	_flat(st, streak, Transform3D(Basis(Vector3.BACK, -0.6), Vector3(-0.22, 0.1, 0.505)), Color(1.0, 1.0, 1.0, 0.85))
	_flat(st, streak, Transform3D(Basis(Vector3.BACK, -0.6).scaled(Vector3(0.5, 0.5, 1.0)), Vector3(-0.08, 0.02, 0.505)), Color(1.0, 1.0, 1.0, 0.6))
	return _cache("ice_cube", st.commit(), glass_material())


## A four-sided ice crystal along Y (shards of the ice block).
static func shard() -> Mesh:
	if _meshes.has("shard"):
		return _meshes["shard"]
	var st := FxShapes._colored_tool()
	for side in [-1.0, 1.0]:
		var c := CylinderMesh.new()
		c.top_radius = 0.0 if side > 0.0 else 0.2
		c.bottom_radius = 0.2 if side > 0.0 else 0.0
		c.height = 0.5 if side > 0.0 else 0.25
		c.radial_segments = 4
		c.rings = 1
		FxShapes._part(st, c, Transform3D(Basis(), Vector3(0, side * (0.25 if side > 0.0 else 0.125), 0)), Color(0.8, 0.95, 1.0))
	return _cache("shard", st.commit(), FxShapes.glow_material())


## A bowling pin standing on Y (1 tall): white with two red neck stripes.
static func pin() -> Mesh:
	if _meshes.has("pin"):
		return _meshes["pin"]
	var st := FxShapes._colored_tool()
	var white := Color(0.98, 0.97, 0.95)
	var red := Color(0.92, 0.12, 0.2)
	FxShapes._part(st, FxShapes._ball_prim(0.2), Transform3D(Basis.from_scale(Vector3(1.0, 1.45, 1.0)), Vector3(0, -0.2, 0)), white)
	FxShapes._part(st, FxShapes._cylinder_prim(0.075, 0.14, 0.3), Transform3D(Basis(), Vector3(0, 0.12, 0)), white)
	FxShapes._part(st, FxShapes._cylinder_prim(0.086, 0.094, 0.045), Transform3D(Basis(), Vector3(0, 0.13, 0)), red)
	FxShapes._part(st, FxShapes._cylinder_prim(0.079, 0.084, 0.03), Transform3D(Basis(), Vector3(0, 0.21, 0)), red)
	FxShapes._part(st, FxShapes._ball_prim(0.12), Transform3D(Basis.from_scale(Vector3(1.0, 1.15, 1.0)), Vector3(0, 0.36, 0)), white)
	FxShapes._part(st, FxShapes._cylinder_prim(0.14, 0.12, 0.04), Transform3D(Basis(), Vector3(0, -0.48, 0)), white.darkened(0.08))
	return _cache("pin", st.commit(), FxShapes.glow_material())


## "K.O.!" in chunky pixel blocks facing +Z, 1 unit wide: hot yellow to
## orange letters over a dark drop shadow.
static func ko_letters() -> Mesh:
	if _meshes.has("ko_letters"):
		return _meshes["ko_letters"]
	var st := FxShapes._colored_tool()
	var cell := 1.0 / 17.0
	var block := BoxMesh.new()
	block.size = Vector3(cell * 0.94, cell * 0.94, cell * 0.9)
	var x := 0
	for glyph in KO_GLYPHS:
		var width := String(glyph[0]).length()
		for row in 7:
			for col in width:
				if String(glyph[row])[col] != "#":
					continue
				var p := Vector3((x + col + 0.5) * cell - 0.5, (3.0 - row) * cell, 0.0)
				var face := Color(1.0, 0.95, 0.35).lerp(Color(1.0, 0.45, 0.12), row / 6.0)
				_flat(st, block, Transform3D(Basis(), p + Vector3(cell * 0.28, -cell * 0.28, -cell * 0.6)), Color(0.3, 0.06, 0.32))
				FxShapes._part(st, block, Transform3D(Basis(), p), face)
		x += width + 1
	return _cache("ko_letters", st.commit(), FxShapes.glow_material())


## Five balloons on strings lifting a little plush zombie (who holds the
## strings with both arms up), facing +Z. The zombie's middle is the origin.
static func balloon_bunch() -> Mesh:
	if _meshes.has("balloon_bunch"):
		return _meshes["balloon_bunch"]
	var st := FxShapes._colored_tool()
	var hold := Vector3(0, 0.12, 0.02)
	var balloons := [[Vector3(0, 0.82, 0), Color(1.0, 0.35, 0.6)], [Vector3(-0.2, 0.7, -0.05), Color(1.0, 0.85, 0.25)],
		[Vector3(0.21, 0.71, -0.03), Color(0.3, 0.8, 1.0)], [Vector3(-0.1, 0.6, 0.12), Color(0.55, 1.0, 0.4)],
		[Vector3(0.12, 0.58, 0.13), Color(1.0, 0.55, 0.2)]]
	for b in balloons:
		var at: Vector3 = b[0]
		var col: Color = b[1]
		FxShapes._part(st, FxShapes._ball_prim(0.13), Transform3D(Basis.from_scale(Vector3(1.0, 1.2, 1.0)), at), col)
		FxShapes._part(st, FxShapes._ball_prim(0.03), Transform3D(Basis(), at + Vector3(-0.045, 0.06, 0.1)), col.lerp(Color.WHITE, 0.7))
		FxShapes._part(st, FxShapes._cylinder_prim(0.0, 0.025, 0.04), Transform3D(Basis(), at + Vector3(0, -0.165, 0)), col.darkened(0.2))
		FxShapes._part(st, FxShapes._capsule(0.006, hold.distance_to(at) - 0.15), FxShapes._along(hold, at + Vector3(0, -0.18, 0)), Color(0.95, 0.95, 0.95))
	var green := Color(0.5, 0.85, 0.4)
	var shirt := Color(0.55, 0.4, 0.95)
	FxShapes._part(st, FxShapes._ball_prim(0.1), Transform3D(Basis(), Vector3(0, -0.02, 0)), green)
	FxShapes._part(st, FxShapes._capsule(0.075, 0.24), Transform3D(Basis(), Vector3(0, -0.2, 0)), shirt)
	for side in [-1.0, 1.0]:
		FxShapes._part(st, FxShapes._capsule(0.025, 0.2), FxShapes._along(Vector3(side * 0.07, -0.13, 0), hold + Vector3(side * 0.02, 0, 0)), green)
		FxShapes._part(st, FxShapes._capsule(0.03, 0.16), FxShapes._along(Vector3(side * 0.04, -0.3, 0), Vector3(side * 0.06, -0.42, 0.02)), Color(0.25, 0.3, 0.6))
		FxShapes._part(st, FxShapes._ball_prim(0.028), Transform3D(Basis(), Vector3(side * 0.04, 0.0, 0.085)), Color.WHITE)
		FxShapes._part(st, FxShapes._ball_prim(0.014), Transform3D(Basis(), Vector3(side * 0.04, 0.0, 0.11)), Color(0.1, 0.07, 0.18))
	FxShapes._part(st, FxShapes._ball_prim(0.02), Transform3D(Basis.from_scale(Vector3(1.6, 0.6, 0.5)), Vector3(0, -0.06, 0.09)), Color(0.1, 0.07, 0.18))
	return _cache("balloon_bunch", st.commit(), FxShapes.glow_material())


## A jagged lightning bolt from (0, 1) down to the origin in the XY plane,
## white-hot (additive; tint it per instance).
static func bolt() -> Mesh:
	if _meshes.has("bolt"):
		return _meshes["bolt"]
	var st := FxShapes._colored_tool()
	var pts := [Vector2(0.0, 1.0), Vector2(0.09, 0.78), Vector2(-0.05, 0.62), Vector2(0.1, 0.42), Vector2(-0.04, 0.27),
		Vector2(0.06, 0.12), Vector2(0.0, 0.0)]
	for i in pts.size() - 1:
		var w := lerpf(0.07, 0.03, float(i) / pts.size())
		_strip(st, pts[i], pts[i + 1], w * 2.6, Color(0.35, 0.35, 0.35))
		_strip(st, pts[i], pts[i + 1], w, Color.WHITE)
	_strip(st, pts[2], Vector2(-0.16, 0.5), 0.025, Color(0.8, 0.8, 0.8))
	_strip(st, pts[4], Vector2(0.13, 0.18), 0.02, Color(0.8, 0.8, 0.8))
	return _cache("bolt", st.commit(), FxShapes.additive_material(Color.WHITE))


## A rainbow: six bands on a half ring in the XY plane, the origin between
## its feet, 1 unit across.
static func rainbow() -> Mesh:
	if _meshes.has("rainbow"):
		return _meshes["rainbow"]
	var st := FxShapes._colored_tool()
	var bands := [Color(1.0, 0.25, 0.3), Color(1.0, 0.6, 0.15), Color(1.0, 0.92, 0.25), Color(0.4, 0.9, 0.35),
		Color(0.25, 0.65, 1.0), Color(0.6, 0.35, 0.95)]
	var segs := 28
	for k in bands.size():
		var r_out := 0.5 - k * 0.03
		var r_in := r_out - 0.03
		st.set_color(bands[k])
		st.set_normal(Vector3.BACK)
		for s in segs:
			var a0 := PI * s / segs
			var a1 := PI * (s + 1) / segs
			var quad := [Vector3(cos(a0) * r_out, sin(a0) * r_out, 0), Vector3(cos(a0) * r_in, sin(a0) * r_in, 0),
				Vector3(cos(a1) * r_in, sin(a1) * r_in, 0), Vector3(cos(a1) * r_out, sin(a1) * r_out, 0)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(quad[idx])
	return _cache("rainbow", st.commit(), FxShapes.glow_material())


## A flying saucer: a silver disc with a purple rim, coloured lights and a
## glass dome with a little green pilot (spins about Y).
static func saucer() -> Mesh:
	if _meshes.has("saucer"):
		return _meshes["saucer"]
	var st := FxShapes._colored_tool()
	FxShapes._part(st, FxShapes._ball_prim(0.5), Transform3D(Basis.from_scale(Vector3(1.0, 0.24, 1.0)), Vector3.ZERO), Color(0.85, 0.88, 0.95))
	FxShapes._part(st, _torus(0.44, 0.52), Transform3D(Basis(), Vector3(0, -0.01, 0)), Color(0.55, 0.3, 0.95))
	FxShapes._part(st, FxShapes._ball_prim(0.2), Transform3D(Basis.from_scale(Vector3(1.0, 0.45, 1.0)), Vector3(0, -0.1, 0)), Color(0.4, 1.0, 0.6))
	FxShapes._part(st, FxShapes._ball_prim(0.2), Transform3D(Basis.from_scale(Vector3(1.0, 0.9, 1.0)), Vector3(0, 0.1, 0)), Color(0.6, 0.92, 1.0))
	FxShapes._part(st, FxShapes._ball_prim(0.085), Transform3D(Basis(), Vector3(0, 0.14, 0.04)), Color(0.5, 1.0, 0.4))
	for side in [-1.0, 1.0]:
		FxShapes._part(st, FxShapes._ball_prim(0.025), Transform3D(Basis(), Vector3(side * 0.035, 0.16, 0.115)), Color(0.08, 0.05, 0.12))
	var lights := [Color(1.0, 0.35, 0.7), Color(0.3, 1.0, 1.0), Color(1.0, 0.9, 0.3)]
	for i in 12:
		var a := TAU * i / 12.0
		FxShapes._part(st, FxShapes._ball_prim(0.04), Transform3D(Basis(), Vector3(cos(a) * 0.43, 0.035, sin(a) * 0.43)), lights[i % 3])
	return _cache("saucer", st.commit(), FxShapes.glow_material())


## A tractor beam: a cone 1 tall hanging down from the origin, widening to
## the ground (additive; tint it per instance).
static func tractor_beam() -> Mesh:
	if _meshes.has("tractor_beam"):
		return _meshes["tractor_beam"]
	var st := FxShapes._colored_tool()
	var c := FxShapes._cylinder_prim(0.16, 0.5, 1.0)
	c.cap_top = false
	c.cap_bottom = false
	_flat(st, c, Transform3D(Basis(), Vector3(0, -0.5, 0)), Color(0.3, 0.3, 0.3))
	for i in 3:
		_flat(st, _torus(0.2 + i * 0.1, 0.22 + i * 0.1), Transform3D(Basis(), Vector3(0, -0.15 - i * 0.28, 0)), Color(0.6, 0.6, 0.6))
	return _cache("tractor_beam", st.commit(), FxShapes.additive_material(Color.WHITE))


static func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 24
	t.ring_segments = 6
	return t


## Adds a primitive in one flat colour, no light baked (for additive glows).
static func _flat(st: SurfaceTool, prim: PrimitiveMesh, xf: Transform3D, col: Color) -> void:
	var arrays := prim.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	st.set_color(col)
	st.set_normal(Vector3.BACK)
	for i in idx:
		st.add_vertex(xf * verts[i])


## A flat strip from `a` to `b` in the XY plane, `width` wide.
static func _strip(st: SurfaceTool, a: Vector2, b: Vector2, width: float, col: Color) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * width * 0.5
	var corners := [a - n, b - n, b + n, a + n]
	st.set_color(col)
	st.set_normal(Vector3.BACK)
	for i in [0, 1, 2, 0, 2, 3]:
		var p: Vector2 = corners[i]
		st.add_vertex(Vector3(p.x, p.y, 0.0))


# --- update 24 ----------------------------------------------------------------

## A playing card facing +Z: a white card with a red-and-black rim and a big
## red diamond pip on both faces.
static func card() -> Mesh:
	if _meshes.has("card"):
		return _meshes["card"]
	var st := FxShapes._colored_tool()
	var body := BoxMesh.new()
	body.size = Vector3(0.62, 0.88, 0.03)
	FxShapes._part(st, body, Transform3D(), BRIGHT)
	var rim := BoxMesh.new()
	rim.size = Vector3(0.52, 0.78, 0.034)
	FxShapes._part(st, rim, Transform3D(), Color(0.12, 0.08, 0.18))
	var inner := BoxMesh.new()
	inner.size = Vector3(0.48, 0.74, 0.038)
	FxShapes._part(st, inner, Transform3D(), BRIGHT)
	var pip := BoxMesh.new()
	pip.size = Vector3(0.24, 0.24, 0.042)
	FxShapes._part(st, pip, Transform3D(Basis(Vector3.BACK, PI * 0.25).scaled(Vector3(0.85, 1.25, 1.0)), Vector3.ZERO), Color(0.92, 0.12, 0.25))
	return _cache("card", st.commit(), FxShapes.glow_material())


## A magician's top hat, crown up (+Y): black felt, a red band, a wide brim.
static func top_hat() -> Mesh:
	if _meshes.has("top_hat"):
		return _meshes["top_hat"]
	var st := FxShapes._colored_tool()
	var felt := Color(0.16, 0.13, 0.22)
	FxShapes._part(st, FxShapes._cylinder_prim(0.3, 0.3, 0.6), Transform3D(Basis(), Vector3(0, 0.3, 0)), felt)
	FxShapes._part(st, FxShapes._cylinder_prim(0.31, 0.31, 0.12), Transform3D(Basis(), Vector3(0, 0.1, 0)), Color(0.9, 0.15, 0.25))
	FxShapes._part(st, FxShapes._cylinder_prim(0.52, 0.52, 0.05), Transform3D(Basis(), Vector3(0, 0.0, 0)), felt)
	return _cache("top_hat", st.commit(), FxShapes.glow_material())


## A ring-toss hoop (lying flat in XZ), white so each instance takes its colour.
static func hoop() -> Mesh:
	if _meshes.has("hoop"):
		return _meshes["hoop"]
	var st := FxShapes._colored_tool()
	FxShapes._part(st, _torus(0.4, 0.5), Transform3D(), BRIGHT)
	return _cache("hoop", st.commit(), FxShapes.glow_material())
