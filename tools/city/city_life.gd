extends RefCounted
## Ashfall City's moving life, placed by the generator
## (tools/build_endless_city.gd calls build() from _build_ambience()).
##
## Everything here is a handful of MultiMeshes animated in their vertex and
## fragment shaders (art/shaders/city_cloth, city_blink, city_flock,
## city_drift, city_screen, city_tracer): no script runs per frame except the
## pigeons' (scripts/props/city_birds.gd: a distance check a few times a
## second until a flock is flushed). Above-ground pieces sit under "CityLife"
## (group "city_surface": hidden in the Metro), the Metro's under
## "CityLifeMetro".
##  - cloth in the wind: torn flags on roof poles, banners down the facades,
##    laundry on lines over the alleys;
##  - lamps still running: the square's traffic signals cycling, crossing
##    hands blinking, hazard lights of the abandoned cars;
##  - crows wheeling over the districts, pigeons that flush when you come near;
##  - paper blowing down the streets with the ash (the same wind);
##  - video screens looping the emergency alert, ads, colour bars, static;
##  - the war beyond the city: tracer fire into the smoke, flares sinking;
##  - the square's hydrant, knocked open, spraying across the road;
##  - rats darting along the Metro's walls.

const SHADERS := "res://art/shaders/"
## The ash's base wind (scripts/props/city_ashfall.gd), world XZ.
const WIND := Vector2(0.8, 0.3)
const METRO_Y := -6.0
## District centres the roof flags stand toward (XZ).
const DISTRICTS: Array[Vector2] = [Vector2(0, 0), Vector2(-54, 0), Vector2(62, 0), Vector2(70, -47)]

static var _rng := RandomNumberGenerator.new()


## Adds every piece to the builder `b` (its fx node, roofs and helpers).
static func build(b: Object) -> void:
	_rng.seed = 1414
	var root := Node3D.new()
	root.name = "CityLife"
	root.add_to_group("city_surface", true)
	b.fx.add_child(root)
	var metro := Node3D.new()
	metro.name = "CityLifeMetro"
	b.fx.add_child(metro)
	_cloth(b, root)
	_lamps(b, root)
	_crows(root)
	_pigeons(b, root)
	_paper(root)
	_screens(b, root)
	_war(root)
	_hydrant(b, root)
	_rats(metro)


# --- helpers -------------------------------------------------------------------

## A MultiMesh of `mesh` drawn with `material` at `xforms`, with instance
## colours and custom data (an empty array leaves that off).
static func _mm(mm_name: String, mesh: Mesh, material: Material, xforms: Array[Transform3D], colors: Array[Color], custom: Array[Color]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.use_custom_data = not custom.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
		if mm.use_colors:
			mm.set_instance_color(k, colors[k])
		if mm.use_custom_data:
			mm.set_instance_custom_data(k, custom[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = mm_name
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


static func _shader(file: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + file)
	return m


## The yaw (radians) that turns local +X toward the world XZ direction `d`.
static func _yaw_to(d: Vector2) -> float:
	return atan2(-d.y, d.x)


# --- cloth ---------------------------------------------------------------------

## Flags, banners and laundry: one MultiMesh of cloth, one of flag poles.
static func _cloth(b: Object, root: Node3D) -> void:
	var xf: Array[Transform3D] = []
	var col: Array[Color] = []
	var cus: Array[Color] = []
	var poles: Array[Transform3D] = []
	_roof_flags(b, xf, col, cus, poles)
	_banners(xf, col, cus)
	_laundry(b, xf, col, cus)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.center_offset = Vector3(0.5, -0.5, 0.0)
	quad.subdivide_width = 8
	quad.subdivide_depth = 8
	root.add_child(_mm("Cloth", quad, _shader("city_cloth.gdshader"), xf, col, cus))
	var pole := CylinderMesh.new()
	pole.top_radius = 0.045
	pole.bottom_radius = 0.06
	pole.height = 1.0
	pole.radial_segments = 6
	pole.rings = 1
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.2, 0.2, 0.22)
	steel.roughness = 0.5
	steel.metallic = 0.4
	root.add_child(_mm("FlagPoles", pole, steel, poles, [], []))


## A flag on a pole near the roof edge that faces its district, flying downwind.
static func _roof_flags(b: Object, xf: Array[Transform3D], col: Array[Color], cus: Array[Color], poles: Array[Transform3D]) -> void:
	var looks := [[Color(0.75, 0.1, 0.08), 1.0], [Color(0.1, 0.12, 0.35), 1.0], [Color(0.95, 0.5, 0.06), 2.0],
		[Color(0.9, 0.88, 0.84), 3.0], [Color(0.08, 0.08, 0.08), 0.0], [Color(0.2, 0.45, 0.25), 1.0]]
	var k := 0
	for roof in b._roofs:
		var r: Rect2 = roof[0]
		var h: float = roof[1]
		k += 1
		if k % 2 == 1 or h < 12.0 or r.get_center().y < -88.0:
			continue
		var target := DISTRICTS[0]
		for d in DISTRICTS:
			if d.distance_to(r.get_center()) < target.distance_to(r.get_center()):
				target = d
		var inner := r.grow(-1.2)
		var at := Vector2(clampf(target.x, inner.position.x, inner.end.x), clampf(target.y, inner.position.y, inner.end.y))
		# Along that edge, off toward a corner.
		at += (at - r.get_center()).normalized().orthogonal() * minf(inner.size.x, inner.size.y) * 0.3 * (1.0 if k % 4 == 0 else -1.0)
		at = Vector2(clampf(at.x, inner.position.x, inner.end.x), clampf(at.y, inner.position.y, inner.end.y))
		var height := _rng.randf_range(3.5, 5.5)
		var base := Vector3(at.x, h + 0.65, at.y)
		poles.append(Transform3D(Basis().scaled_local(Vector3(1, height, 1)), base + Vector3(0, height * 0.5, 0)))
		var width := _rng.randf_range(1.8, 2.6)
		var yaw := _yaw_to(WIND) + _rng.randf_range(-0.35, 0.35)
		var look: Array = looks[k % looks.size()]
		xf.append(Transform3D(Basis(Vector3.UP, yaw).scaled_local(Vector3(width, width * 0.62, 1.0)), base + Vector3(0, height - 0.05, 0)))
		col.append(look[0])
		cus.append(Color(_rng.randf(), 0.0, 0.32, look[1]))


## Long banners hung from the parapets down the facades the districts see.
static func _banners(xf: Array[Transform3D], col: Array[Color], cus: Array[Color]) -> void:
	# [top centre, facing (world XZ normal), width, length, colour, pattern]
	var banners := [
		[Vector3(-21.6, 13.4, -14.0), Vector2(1, 0), 2.8, 7.0, Color(0.7, 0.08, 0.07), 1.0],
		[Vector3(21.6, 15.4, -16.0), Vector2(-1, 0), 2.8, 8.0, Color(0.1, 0.14, 0.4), 1.0],
		[Vector3(-9.0, 11.4, 21.6), Vector2(0, -1), 2.6, 6.0, Color(0.95, 0.5, 0.06), 2.0],
		[Vector3(-73.6, 15.4, -18.0), Vector2(1, 0), 3.0, 9.0, Color(0.1, 0.14, 0.4), 1.0],
		[Vector3(-73.6, 15.4, 18.0), Vector2(1, 0), 3.0, 9.0, Color(0.1, 0.14, 0.4), 1.0],
		[Vector3(-45.0, 17.4, -23.6), Vector2(0, 1), 3.2, 8.0, Color(0.9, 0.88, 0.84), 3.0],
		[Vector3(93.6, 15.4, -66.0), Vector2(-1, 0), 3.2, 10.0, Color(0.7, 0.08, 0.07), 1.0],
		[Vector3(45.6, 17.4, -45.0), Vector2(1, 0), 3.2, 9.0, Color(0.95, 0.5, 0.06), 2.0],
		[Vector3(70.0, 15.4, 7.6), Vector2(0, -1), 1.6, 5.0, Color(0.85, 0.15, 0.5), 0.0],
	]
	for t in banners:
		var n: Vector2 = t[1]
		var top: Vector3 = t[0]
		var w: float = t[2]
		# Local +Z out of the wall; the cloth runs along the wall, down from its top.
		var basis := Basis(Vector3.UP, atan2(n.x, n.y))
		var start := top - basis * Vector3(w * 0.5, 0, 0) + Vector3(n.x, 0, n.y) * 0.35
		xf.append(Transform3D(basis.scaled_local(Vector3(w, t[3], 1.0)), start))
		col.append(t[4])
		cus.append(Color(_rng.randf(), 1.0, 0.35, t[5]))


## Washing lines across the side alleys (high over the zombies' way in) and
## the clothes left on them.
static func _laundry(b: Object, xf: Array[Transform3D], col: Array[Color], cus: Array[Color]) -> void:
	var lines := [[Vector3(-18.0, 7.5, -28.0), Vector3(-13.0, 7.0, -27.0)], [Vector3(13.0, 8.0, -29.0), Vector3(18.0, 7.4, -28.0)],
		[Vector3(-18.0, 6.8, 28.0), Vector3(-13.0, 7.2, 29.5)], [Vector3(40.0, 7.0, -14.0), Vector3(44.0, 6.6, -13.0)],
		[Vector3(54.0, 6.6, 13.0), Vector3(58.0, 7.0, 14.5)], [Vector3(-18.0, 9.0, -31.0), Vector3(-13.0, 9.3, -32.0)],
		[Vector3(62.0, 8.5, -16.0), Vector3(70.0, 8.0, -17.0)]]
	var shades := [Color(0.85, 0.82, 0.75), Color(0.3, 0.45, 0.7), Color(0.75, 0.25, 0.22), Color(0.9, 0.75, 0.3),
		Color(0.4, 0.6, 0.4), Color(0.6, 0.55, 0.62)]
	var sag := 0.45
	for line in lines:
		var a: Vector3 = line[0]
		var e: Vector3 = line[1]
		b._cable(a, e, sag, 10)
		var along := e - a
		var basis := Basis(Vector3.UP, _yaw_to(Vector2(along.x, along.z)))
		var t := 0.12
		while t < 0.88:
			var w := _rng.randf_range(0.45, 0.9)
			var p := a.lerp(e, t) - Vector3(0, sag * sin(PI * t), 0)
			xf.append(Transform3D(basis.scaled_local(Vector3(w, _rng.randf_range(0.55, 1.1), 1.0)), p))
			col.append(shades[_rng.randi() % shades.size()])
			cus.append(Color(_rng.randf(), 1.0, 0.18, 0.0))
			t += (w + _rng.randf_range(0.15, 0.4)) / along.length()


# --- lamps ---------------------------------------------------------------------

## Traffic signals still cycling, crossing hands blinking, hazard lights on
## the cars left in the street.
static func _lamps(b: Object, root: Node3D) -> void:
	var xf: Array[Transform3D] = []
	var col: Array[Color] = []
	var cus: Array[Color] = []
	# The square's traffic lights (art/blender/build_city_street.py: lenses
	# at x 3.6, heights 4.24 / 4.62 / 5.0 facing +Z, a halo on the red: the
	# covers sit in the visors' mouths; the crossing hand on the
	# pole 2.7 up).
	var signals := [[Vector3(-20.0, 0, -20.0), 45.0, 0.0], [Vector3(20.0, 0, 20.0), 225.0, 0.5]]
	var lens_colors := [Color(0.25, 1.0, 0.45), Color(1.0, 0.6, 0.05), Color(1.0, 0.12, 0.08)]
	for s in signals:
		var basis := Basis(Vector3.UP, deg_to_rad(s[1]))
		for slot in 3:
			var p: Vector3 = s[0] + basis * Vector3(3.6, 4.24 + slot * 0.38, 0.335)
			xf.append(Transform3D(basis.scaled_local(Vector3(0.3, 0.3, 0.03)), p))
			col.append(lens_colors[slot])
			cus.append(Color(14.0, s[2], float(slot), 1.0))
		xf.append(Transform3D(basis.scaled_local(Vector3(0.24, 0.2, 0.03)), s[0] + basis * Vector3(0, 2.7, 0.39)))
		col.append(Color(1.0, 0.42, 0.1))
		cus.append(Color(1.1, s[2], 0.5, 0.0))
	# Hazards: [model, position, yaw] of cars that were not burnt out.
	var cars := [["city_taxi_wreck", Vector3(-16.8, 0, 7.0), 168.0], ["city_taxi_wreck", Vector3(86.0, 0, -62.0), 200.0],
		["city_car_burnt_b", Vector3(-40.0, 0, -20.0), 10.0], ["city_car_burnt_b", Vector3(16.4, 0, -9.5), -10.0]]
	var amber := Color(1.0, 0.55, 0.08)
	var i := 0
	for c in cars:
		var box: AABB = b._model_aabb(c[0])
		var basis := Basis(Vector3.UP, deg_to_rad(c[2]))
		var y := box.position.y + box.size.y * 0.42
		var half := box.size.z * 0.5 - 0.28
		for end in [box.position.x + 0.02, box.end.x - 0.02]:
			for side in [-half, half]:
				var p: Vector3 = c[1] + basis * Vector3(end, y, box.get_center().z + side)
				xf.append(Transform3D(basis.scaled_local(Vector3(0.07, 0.14, 0.36)), p))
				col.append(amber)
				cus.append(Color(0.9, i * 0.23, 0.5, 0.0))
		i += 1
	var lamp := BoxMesh.new()
	lamp.size = Vector3.ONE
	root.add_child(_mm("SignalLamps", lamp, _shader("city_blink.gdshader"), xf, col, cus))


# --- birds ---------------------------------------------------------------------

## A small bird facing -Z: a plump body with a head, two wings spread
## along X (the shader folds them when it is perched).
static func _bird_mesh(size: float) -> ArrayMesh:
	var nose := Vector3(0, 0.03, -0.2)
	var tail := Vector3(0, 0.02, 0.26)
	var left := Vector3(-0.075, 0.0, -0.02)
	var right := Vector3(0.075, 0.0, -0.02)
	var top := Vector3(0, 0.085, -0.03)
	var belly := Vector3(0, -0.055, -0.02)
	var head := Vector3(0, 0.12, -0.17)
	var tris := [
		[nose, top, left], [nose, right, top], [nose, left, belly], [nose, belly, right],
		[tail, left, top], [tail, top, right], [tail, belly, left], [tail, right, belly],
		[head, nose + Vector3(-0.04, 0, 0.04), nose + Vector3(0.04, 0, 0.04)], [head, top, nose],
		[Vector3(-0.06, 0.03, -0.08), Vector3(-0.5, 0.04, 0.06), Vector3(-0.06, 0.03, 0.1)],
		[Vector3(0.06, 0.03, -0.08), Vector3(0.06, 0.03, 0.1), Vector3(0.5, 0.04, 0.06)],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in tris:
		var n: Vector3 = (tri[2] - tri[0]).cross(tri[1] - tri[0]).normalized()
		for v in tri:
			st.set_normal(n)
			st.add_vertex(v * size)
	return st.commit()


## Crows circling over the districts and high over the skyline.
static func _crows(root: Node3D) -> void:
	var xf: Array[Transform3D] = []
	var col: Array[Color] = []
	var cus: Array[Color] = []
	# [centre, birds, radius range, speed (rad/s)]
	var flocks := [[Vector3(-2.0, 30.0, -4.0), 7, Vector2(10, 20), 0.32], [Vector3(72.0, 42.0, -58.0), 8, Vector2(12, 26), -0.26],
		[Vector3(-56.0, 26.0, 2.0), 5, Vector2(8, 16), 0.35], [Vector3(62.0, 24.0, 0.0), 4, Vector2(8, 14), -0.38],
		[Vector3(-80.0, 50.0, -130.0), 9, Vector2(20, 40), 0.18], [Vector3(140.0, 46.0, 40.0), 7, Vector2(16, 32), -0.2]]
	for f in flocks:
		var radius: Vector2 = f[2]
		for k in f[1]:
			var c: Vector3 = f[0] + Vector3(0, _rng.randf_range(-3.0, 3.0), 0)
			xf.append(Transform3D(Basis().scaled_local(Vector3.ONE * _rng.randf_range(1.6, 2.1)), c))
			col.append(Color(0.05, 0.045, 0.05))
			cus.append(Color(_rng.randf(), _rng.randf_range(radius.x, radius.y), f[3] * _rng.randf_range(0.85, 1.15), 1.0))
	var mmi := _mm("Crows", _bird_mesh(1.0), _shader("city_flock.gdshader"), xf, col, cus)
	mmi.extra_cull_margin = 45.0
	root.add_child(mmi)


## Pigeons on the pavements, flushed by whoever comes near
## (scripts/props/city_birds.gd), one MultiMesh per flock.
static func _pigeons(b: Object, root: Node3D) -> void:
	var flocks := [Vector3(-5.5, 0, 13.3), Vector3(-19.0, 0, -2.0), Vector3(38.0, 0, 5.6), Vector3(-70.5, 0, 1.5),
		Vector3(78.0, 0, -38.0), Vector3(-30.0, 0, 21.0)]
	var m := _shader("city_flock.gdshader")
	var mesh := _bird_mesh(0.95)
	var i := 0
	for centre in flocks:
		var xf: Array[Transform3D] = []
		var col: Array[Color] = []
		var cus: Array[Color] = []
		for k in 7:
			var off := Vector3(_rng.randf_range(-1.4, 1.4), 0.07, _rng.randf_range(-1.0, 1.0))
			xf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), off))
			var g := _rng.randf_range(0.55, 0.75)
			col.append(Color(g, g, g * 1.06) if k % 3 else Color(0.4, 0.38, 0.44))
			cus.append(Color(_rng.randf(), 0.0, 0.0, 0.0))
		var mmi := _mm("Pigeons%d" % i, mesh, m, xf, col, cus)
		mmi.position = centre
		root.add_child(mmi)
		b._late(mmi, "res://scripts/props/city_birds.gd", {})
		i += 1


# --- paper ---------------------------------------------------------------------

## Sheets of paper running downwind over the open ground of every district.
static func _paper(root: Node3D) -> void:
	var xf: Array[Transform3D] = []
	var col: Array[Color] = []
	var cus: Array[Color] = []
	# [start, end, sheets, spread across]
	var lanes := [[Vector3(-20.0, 0, 12.6), Vector3(20.0, 0, 13.5), 8, 1.2], [Vector3(-12.0, 0, -12.0), Vector3(12.0, 0, -11.0), 6, 1.5],
		[Vector3(-11.0, 0, 3.0), Vector3(11.0, 0, 5.0), 5, 1.0], [Vector3(-21.0, 0, -19.5), Vector3(21.0, 0, -19.0), 6, 1.0],
		[Vector3(36.0, 0, -5.0), Vector3(88.0, 0, -4.6), 12, 0.8], [Vector3(36.0, 0, 5.0), Vector3(88.0, 0, 5.4), 12, 0.8],
		[Vector3(-72.0, 0, -1.5), Vector3(-36.0, 0, 0.0), 9, 1.6], [Vector3(-34.0, 0, 0.0), Vector3(-22.0, 0, 0.6), 3, 0.8],
		[Vector3(48.0, 0, -40.0), Vector3(92.0, 0, -38.0), 10, 2.0], [Vector3(48.0, 0, -66.0), Vector3(66.0, 0, -62.0), 4, 1.5]]
	var tints := [Color(0.92, 0.9, 0.82), Color(0.8, 0.78, 0.72), Color(0.95, 0.75, 0.8), Color(0.75, 0.86, 0.95), Color(0.98, 0.92, 0.6)]
	for lane in lanes:
		var a: Vector3 = lane[0]
		var along: Vector3 = lane[1] - a
		var basis := Basis(Vector3.UP, _yaw_to(Vector2(along.x, along.z)))
		var side := basis * Vector3(0, 0, 1)
		for k in lane[2]:
			xf.append(Transform3D(basis, a + side * _rng.randf_range(-lane[3], lane[3]) + Vector3(0, 0.04, 0)))
			col.append(tints[_rng.randi() % tints.size()])
			cus.append(Color(_rng.randf(), along.length(), _rng.randf_range(1.6, 3.2), _rng.randf_range(0.4, 1.1)))
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(0.34, 0.25)
	var mmi := _mm("BlowingPaper", sheet, _shader("city_drift.gdshader"), xf, col, cus)
	mmi.extra_cull_margin = 55.0
	root.add_child(mmi)


# --- screens -------------------------------------------------------------------

## Video walls still looping the broadcast: quads in one MultiMesh, their
## housings in another.
static func _screens(b: Object, root: Node3D) -> void:
	# [centre, facing (world XZ), size]
	var screens := [[Vector3(5.5, 12.5, -21.3), Vector2(0, 1), Vector2(8.0, 4.5)],
		[Vector3(50.0, 7.4, -7.5), Vector2(0, 1), Vector2(3.2, 1.8)], [Vector3(66.0, 7.6, 7.5), Vector2(0, -1), Vector2(3.2, 1.8)],
		[Vector3(-73.5, 9.0, 10.0), Vector2(1, 0), Vector2(3.4, 1.9)], [Vector3(93.5, 9.5, -60.0), Vector2(-1, 0), Vector2(5.4, 3.0)],
		[Vector3(21.5, 8.5, 18.0), Vector2(-1, 0), Vector2(2.8, 1.6)]]
	var xf: Array[Transform3D] = []
	var cus: Array[Color] = []
	var frames: Array[Transform3D] = []
	var k := 0
	for s in screens:
		var n: Vector2 = s[1]
		var size: Vector2 = s[2]
		var centre: Vector3 = s[0]
		var basis := Basis(Vector3.UP, atan2(n.x, n.y))
		xf.append(Transform3D(basis.scaled_local(Vector3(size.x, size.y, 1.0)), centre + Vector3(n.x, 0, n.y) * 0.13))
		cus.append(Color(float(k) * 0.37 + 0.1, 0, 0, 0))
		frames.append(Transform3D(basis.scaled_local(Vector3(size.x + 0.35, size.y + 0.35, 0.24)), centre))
		k += 1
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := _shader("city_screen.gdshader")
	m.set_shader_parameter("ads", load("res://art/textures/neon_ads.png"))
	root.add_child(_mm("Screens", quad, m, xf, [], cus))
	var housing := BoxMesh.new()
	housing.size = Vector3.ONE
	root.add_child(_mm("ScreenHousings", housing, b._mat("screen_housing", Color(0.07, 0.07, 0.08), 0.5), frames, [], []))


# --- the war beyond the city ---------------------------------------------------

## Tracer fire and flares out past the skyline (round the skyline ring's
## centre, 160-240 m out), above the far blocks' roofs.
static func _war(root: Node3D) -> void:
	var xf: Array[Transform3D] = []
	var col: Array[Color] = []
	var cus: Array[Color] = []
	var centre := Vector3(10.0, 0, -24.0)
	var tracer_colors := [Color(1.0, 0.45, 0.12), Color(1.0, 0.3, 0.1), Color(0.45, 1.0, 0.35)]
	for k in 12:
		var a := TAU * (k + _rng.randf_range(-0.3, 0.3)) / 12.0
		var r := _rng.randf_range(170.0, 230.0)
		var base := centre + Vector3(cos(a) * r, _rng.randf_range(45.0, 75.0), sin(a) * r)
		var period := _rng.randf_range(5.0, 11.0)
		var phase := _rng.randf()
		var c: Color = tracer_colors[k % tracer_colors.size()]
		# A gun's stream: two crossed quads, leaning off vertical.
		var lean := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(0.25, 0.6))
		var length := _rng.randf_range(130.0, 190.0)
		for cross in 2:
			xf.append(Transform3D((lean * Basis(Vector3.UP, cross * PI * 0.5)).scaled_local(Vector3(3.0, length, 1.0)), base))
			col.append(c)
			cus.append(Color(phase, period, 0.0, 0.0))
	for k in 9:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(160.0, 240.0)
		var top := centre + Vector3(cos(a) * r, _rng.randf_range(150.0, 200.0), sin(a) * r)
		var flare := Color(1.0, 0.3, 0.15) if k % 3 else Color(1.0, 0.85, 0.6)
		var life := _rng.randf_range(18.0, 30.0)
		for cross in 2:
			xf.append(Transform3D(Basis(Vector3.UP, cross * PI * 0.5 + a).scaled_local(Vector3.ONE * 9.0), top))
			col.append(flare)
			cus.append(Color(float(k) / 9.0, life, 1.0, 70.0))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.center_offset = Vector3(0, 0.5, 0)
	var mmi := _mm("FarWar", quad, _shader("city_tracer.gdshader"), xf, col, cus)
	mmi.extra_cull_margin = 80.0
	root.add_child(mmi)


# --- the burst hydrant ---------------------------------------------------------

## The square's hydrant (12, 0, -20.2), its side cap gone: a jet arcing out
## along the kerb (crossed ribbons along the arc, art/shaders/city_spray) and
## mist where it lands.
static func _hydrant(b: Object, root: Node3D) -> void:
	var nozzle := Vector3(12.0, 0.52, -19.95)
	var reach := 3.4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 12
	for ribbon in 2:
		var across := Vector3.RIGHT if ribbon == 0 else Vector3.UP
		for i in steps:
			var quad: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for k in [i, i + 1]:
				var t := float(k) / steps
				var centre := Vector3(0, 0.9 * t - 1.42 * t * t, reach * t)
				var half := 0.07 + 0.42 * t
				quad.append(centre - across * half)
				quad.append(centre + across * half)
				uvs.append(Vector2(0, t))
				uvs.append(Vector2(1, t))
			for v in [0, 1, 3, 0, 3, 2]:
				st.set_uv(uvs[v])
				st.add_vertex(quad[v])
	var jet := MeshInstance3D.new()
	jet.name = "HydrantJet"
	jet.mesh = st.commit()
	jet.material_override = _shader("city_spray.gdshader")
	jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	jet.position = nozzle
	# Along the kerb, east (the ribbons run along local +Z).
	jet.rotation.y = PI * 0.5
	root.add_child(jet)
	b._steam(nozzle + Vector3(reach, -0.52, 0), Color(0.8, 0.85, 0.9), 0.22)


# --- rats ----------------------------------------------------------------------

## Rats darting along the foot of the Metro's south wall, the platform edge
## and the track bed.
static func _rats(metro: Node3D) -> void:
	var xf: Array[Transform3D] = []
	var col: Array[Color] = []
	var cus: Array[Color] = []
	var runs := [[Vector3(-17.0, METRO_Y, -28.35), Vector3(-6.0, METRO_Y, -28.35)], [Vector3(26.0, METRO_Y, -28.35), Vector3(12.0, METRO_Y, -28.35)],
		[Vector3(-16.0, METRO_Y, -37.7), Vector3(4.0, METRO_Y, -37.7)], [Vector3(36.0, METRO_Y, -37.7), Vector3(18.0, METRO_Y, -37.7)],
		[Vector3(-12.0, METRO_Y - 1.2, -40.5), Vector3(30.0, METRO_Y - 1.2, -40.0)]]
	for run in runs:
		var a: Vector3 = run[0]
		var along: Vector3 = run[1] - a
		for k in 3:
			xf.append(Transform3D(Basis(Vector3.UP, _yaw_to(Vector2(along.x, along.z))).scaled_local(Vector3.ONE * 1.3), a))
			col.append(Color(0.16, 0.13, 0.12))
			cus.append(Color(_rng.randf(), along.length(), _rng.randf_range(1.2, 2.0), 0.0))
	var body := BoxMesh.new()
	body.size = Vector3(0.24, 0.09, 0.1)
	var head := BoxMesh.new()
	head.size = Vector3(0.08, 0.06, 0.07)
	var tail := BoxMesh.new()
	tail.size = Vector3(0.22, 0.015, 0.015)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(body, 0, Transform3D(Basis(), Vector3(0, 0.045, 0)))
	st.append_from(head, 0, Transform3D(Basis(), Vector3(0.15, 0.035, 0)))
	st.append_from(tail, 0, Transform3D(Basis(), Vector3(-0.22, 0.02, 0)))
	var m := _shader("city_drift.gdshader")
	m.set_shader_parameter("scurry", true)
	metro.add_child(_mm("Rats", st.commit(), m, xf, col, cus))
