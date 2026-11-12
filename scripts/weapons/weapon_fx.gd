class_name WeaponFx
extends RefCounted
## Effects for the weapon fire modes: shot streaks per tracer style, impacts
## per impact style, explosions, frost and shatter bursts, and the ribbon
## builder the beam, lightning and rail effects share. Non-gory and short-lived,
## like scripts/fx/fx.gd.

const RIBBON_SHADER := "res://art/shaders/weapon_ribbon.gdshader"
const ICE_COLORS := [Color(0.75, 0.95, 1.0), Color(1, 1, 1), Color(0.45, 0.8, 1.0), Color(0.85, 0.9, 1.0)]

static var _ribbon_mats := {}
static var _verts := 0
static var _cube: BoxMesh
static var _flash: SphereMesh
static var _ring: PlaneMesh
static var _ring_mats := {}
static var _smoke_mesh: QuadMesh
static var _smoke_texture: ImageTexture
static var _star: ArrayMesh


# --- ribbons --------------------------------------------------------------------

## Additive ribbon material (cached per scroll / band setting).
static func ribbon_material(scroll := 0.0, bands := 0.0) -> ShaderMaterial:
	var key := "%.1f|%.1f" % [scroll, bands]
	if not _ribbon_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = load(RIBBON_SHADER)
		m.set_shader_parameter("scroll_speed", scroll)
		m.set_shader_parameter("band_scale", bands)
		_ribbon_mats[key] = m
	return _ribbon_mats[key]


## Starts a ribbon surface on `im` (call add_ribbon, then end_ribbons).
static func begin_ribbons(im: ImmediateMesh, material: Material) -> void:
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	_verts = 0


## Closes the surface (with an invisible triangle if every ribbon had faded).
static func end_ribbons(im: ImmediateMesh) -> void:
	if _verts == 0:
		for i in 3:
			im.surface_set_color(Color(0, 0, 0, 0))
			im.surface_set_uv(Vector2.ZERO)
			im.surface_add_vertex(Vector3.ZERO)
	im.surface_end()


## Appends a camera-facing strip through `points` (world space) between
## begin_ribbons and end_ribbons.
static func add_ribbon(im: ImmediateMesh, points: PackedVector3Array, width: float, color: Color, eye: Vector3) -> void:
	if points.size() < 2 or width <= 0.0 or color.a <= 0.003:
		return
	var along := 0.0
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_u := 0.0
	for i in points.size():
		var p := points[i]
		var tangent := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var side := tangent.cross(eye - p).normalized() * width * 0.5
		var l := p - side
		var r := p + side
		if i > 0:
			along += p.distance_to(points[i - 1])
			_quad(im, prev_l, prev_r, l, r, prev_u, along, color)
		prev_l = l
		prev_r = r
		prev_u = along


static func _quad(im: ImmediateMesh, a_l: Vector3, a_r: Vector3, b_l: Vector3, b_r: Vector3, u0: float, u1: float, color: Color) -> void:
	# Written out (no temporary arrays): beams and trails call this hundreds of
	# times a frame.
	_vert(im, a_l, u0, 0.0, color)
	_vert(im, a_r, u0, 1.0, color)
	_vert(im, b_r, u1, 1.0, color)
	_vert(im, a_l, u0, 0.0, color)
	_vert(im, b_r, u1, 1.0, color)
	_vert(im, b_l, u1, 0.0, color)
	_verts += 6


static func _vert(im: ImmediateMesh, at: Vector3, u: float, v: float, color: Color) -> void:
	im.surface_set_color(color)
	im.surface_set_uv(Vector2(u, v))
	im.surface_add_vertex(at)


# --- shots ----------------------------------------------------------------------

## The visible streak of one shot, in the weapon's tracer style.
static func shot(parent: Node, from: Vector3, to: Vector3, w: WeaponData, power := 1.0) -> void:
	match w.tracer_style:
		&"rail":
			RailTrail.spawn(parent, from, to, w.tracer_color, w.tracer_width, power)
		&"lightning":
			LightningBolt.spawn(parent, from, to, w.tracer_color, w.tracer_width, 0.14, 0.3)
		&"none", &"beam":
			pass
		_:
			Fx.tracer(parent, from, to, w.tracer_color, w.tracer_width)


## Where a shot meets scenery, in the weapon's impact style.
static func impact(parent: Node, at: Vector3, normal: Vector3, w: WeaponData) -> void:
	match w.impact_style:
		&"frost":
			burst(parent, at, normal, ICE_COLORS, 5, 1.6, 0.45, 0.05, 70.0, Vector3(0, 0.6, 0))
		&"arc":
			burst(parent, at, normal, [w.tracer_color, Color.WHITE, Color(1, 1, 0.6)], 9, 5.0, 0.22, 0.035, 80.0)
		&"rail":
			burst(parent, at, normal, [w.tracer_color, Color.WHITE], 16, 6.5, 0.4, 0.05, 55.0)
			flash(parent, at, w.tracer_color, 0.6)
		_:
			Fx.impact(parent, at, normal, w.tracer_color)


## Script-driven particle burst (see FxBurst).
static func burst(parent: Node, at: Vector3, direction: Vector3, colors: Array, amount: int, speed: float,
		lifetime: float, size: float, spread := 65.0, gravity := Vector3(0, -9.0, 0)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if _cube == null:
		_cube = BoxMesh.new()
		_cube.size = Vector3.ONE
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cube.material = m
	var b := FxBurst.new()
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(b)
	b.setup(at, direction, colors, amount, speed, lifetime, size, spread, gravity, _cube)


## A quick additive glow sphere.
static func flash(parent: Node, at: Vector3, color: Color, radius: float, life := 0.16) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if _flash == null:
		_flash = SphereMesh.new()
		_flash.radius = 0.5
		_flash.height = 1.0
		_flash.radial_segments = 12
		_flash.rings = 6
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.lerp(Color.WHITE, 0.3), 0.9 * Settings.flash_scale())
	var f := MeshInstance3D.new()
	f.mesh = _flash
	f.material_override = m
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(f)
	f.global_position = at
	f.scale = Vector3.ONE * radius * 0.4
	var tw := f.create_tween().set_parallel(true)
	tw.tween_property(f, "scale", Vector3.ONE * radius * 2.0, life).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(f.queue_free)


## A ring racing out along the floor under `at`. It lies on the ground (found
## with a ray), so it reads as a ring from any angle instead of a band across
## the screen; an airburst with no floor close below has no ring.
static func shockwave(parent: Node, at: Vector3, color: Color, radius: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var space := (parent as Node3D).get_world_3d().direct_space_state if parent is Node3D else parent.get_viewport().world_3d.direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * maxf(2.5, radius), 1))
	if hit.is_empty():
		return
	var normal: Vector3 = hit["normal"]
	var r := MeshInstance3D.new()
	r.mesh = _ring_mesh()
	r.material_override = _ring_material(color)
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(r)
	var basis := Basis.IDENTITY
	if normal.dot(Vector3.UP) < 0.999:
		basis = Basis(Quaternion(Vector3.UP, normal.normalized()))
	r.global_transform = Transform3D(basis, Vector3(hit["position"]) + normal * 0.04)
	r.scale = Vector3.ONE * radius * 0.25
	var tw := r.create_tween().set_parallel(true)
	tw.tween_property(r, "scale", Vector3.ONE * radius * 1.1, 0.36).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "transparency", 1.0, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(r.queue_free)


## Unit plane (2 m across, so scale = ring radius) for the ground ring.
static func _ring_mesh() -> PlaneMesh:
	if _ring == null:
		_ring = PlaneMesh.new()
		_ring.size = Vector2(2.0, 2.0)
	return _ring


## Additive ring material per colour: a bright rim with a soft inner glow.
static func _ring_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _ring_mats.has(key):
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.62, 0.86, 0.93, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.9), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 128
		tex.height = 128
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_texture = tex
		m.albedo_color = color.lerp(Color.WHITE, 0.3)
		_ring_mats[key] = m
	return _ring_mats[key]


## Soft cartoon smoke balls billowing up and out of a blast (0.6 s).
static func smoke(parent: Node, at: Vector3, color: Color, radius: float, count := 8) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mesh := _smoke_quad()
	var material := _smoke_material(color)
	for i in count:
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.15, 1.0), randf_range(-1.0, 1.0)).normalized()
		var puff := MeshInstance3D.new()
		puff.mesh = mesh
		puff.material_override = material
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(puff)
		puff.global_position = at + dir * radius * 0.15
		var size := radius * randf_range(0.7, 1.1)
		puff.scale = Vector3.ONE * size * 0.4
		puff.transparency = 0.1
		var life := randf_range(0.5, 0.65)
		var tw := puff.create_tween().set_parallel(true)
		tw.tween_property(puff, "global_position", at + dir * radius * randf_range(0.45, 0.7) + Vector3.UP * radius * 0.35, life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(puff, "scale", Vector3.ONE * size, life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(puff, "transparency", 1.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(puff.queue_free)


static func _smoke_quad() -> QuadMesh:
	if _smoke_mesh == null:
		_smoke_mesh = QuadMesh.new()
		_smoke_mesh.size = Vector2.ONE
	return _smoke_mesh


## Camera-facing smoke ball per blast colour: a disc lit from the upper left
## with a soft edge, a lilac grey leaning towards the blast colour.
static func _smoke_material(color: Color) -> StandardMaterial3D:
	var key := "smoke" + color.to_html()
	if _ring_mats.has(key):
		return _ring_mats[key]
	if _smoke_texture == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var p := (Vector2(x, y) + Vector2(0.5, 0.5)) / n * 2.0 - Vector2.ONE
				var a := clampf((1.0 - p.length()) / 0.25, 0.0, 1.0)
				var light := clampf(0.82 - 0.3 * (p.x * 0.55 + p.y * 0.8), 0.5, 1.0)
				img.set_pixel(x, y, Color(light, light, light, a * a * (3.0 - 2.0 * a)))
		_smoke_texture = ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = _smoke_texture
	m.albedo_color = Color(Color(0.62, 0.57, 0.7).lerp(color, 0.25), 0.9)
	_ring_mats[key] = m
	return m


## A few chunky stars tumbling out of a blast.
static func debris_stars(parent: Node, at: Vector3, color: Color, count := 5) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var b := FxBurst.new()
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(b)
	b.setup(at, Vector3.UP, [color, Color(1.0, 0.85, 0.3), Color.WHITE], count, 8.0, 0.9, 0.34, 60.0, Vector3(0, -15.0, 0), _star_mesh())


## Five-pointed star, flat in XY with some depth (FxBurst flattens Z further).
static func _star_mesh() -> ArrayMesh:
	if _star:
		return _star
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim: Array[Vector3] = []
	for i in 10:
		var a := PI * 0.5 + i * TAU / 10.0
		var r := 0.5 if i % 2 == 0 else 0.22
		rim.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
	for side in [1.0, -1.0]:
		var centre := Vector3(0, 0, 0.25 * side)
		for i in 10:
			var p0: Vector3 = rim[i]
			var p1: Vector3 = rim[(i + 1) % 10]
			if side > 0.0:
				st.add_vertex(centre)
				st.add_vertex(p1)
				st.add_vertex(p0)
			else:
				st.add_vertex(centre)
				st.add_vertex(p0)
				st.add_vertex(p1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(m)
	_star = st.commit()
	return _star


## A splash weapon's detonation: a small hot flash, a ring racing out along the
## floor, smoke balls, tumbling stars, sparks and confetti.
static func explosion(parent: Node, at: Vector3, color: Color, radius: float) -> void:
	flash(parent, at, color, radius * 0.5, 0.12)
	shockwave(parent, at, color, radius)
	smoke(parent, at, color, radius)
	debris_stars(parent, at, color)
	burst(parent, at, Vector3.UP, [color, Color.WHITE, Color(1.0, 0.85, 0.3)], 30, 9.0, 0.45, 0.08, 180.0, Vector3(0, -12.0, 0))
	burst(parent, at, Vector3.UP, [Color(1.0, 0.35, 0.75), Color(0.3, 0.95, 1.0), Color(1.0, 0.85, 0.25), Color(0.6, 1.0, 0.45)],
		32, 6.5, 1.1, 0.13, 70.0, Vector3(0, -6.0, 0))


## A cloud of frost (freezing, thawing, beam impacts).
static func frost_puff(parent: Node, at: Vector3, scale := 1.0) -> void:
	burst(parent, at, Vector3.UP, ICE_COLORS, int(14 * scale), 2.2 * scale, 0.7, 0.07 * scale, 160.0, Vector3(0, 0.5, 0))


## One glint drifting off a chilled zombie.
static func frost_sparkle(parent: Node, at: Vector3) -> void:
	burst(parent, at, Vector3.UP, ICE_COLORS, 3, 0.6, 0.5, 0.035, 180.0, Vector3(0, 0.3, 0))


## A frozen zombie breaking apart.
static func shatter(parent: Node, at: Vector3) -> void:
	flash(parent, at, Color(0.7, 0.95, 1.0), 1.6, 0.2)
	burst(parent, at, Vector3.UP, ICE_COLORS, 46, 7.5, 0.8, 0.12, 180.0, Vector3(0, -14.0, 0))
	burst(parent, at, Vector3.UP, ICE_COLORS, 18, 2.0, 1.0, 0.05, 180.0, Vector3(0, 0.4, 0))


## Little arcs crawling over a shocked zombie.
static func shock_crackle(z: Zombie) -> void:
	var parent := z.get_parent()
	var base := z.global_position
	var h := 1.6 * z.data.body_scale
	for i in 2:
		var a := base + Vector3(randf_range(-0.35, 0.35), randf_range(0.2, h), randf_range(-0.35, 0.35))
		var b := base + Vector3(randf_range(-0.35, 0.35), randf_range(0.2, h), randf_range(-0.35, 0.35))
		LightningBolt.spawn(parent, a, b, Color(0.85, 1.0, 0.4), 0.025, 0.12, 0.12)


## Draws each new effect once at level start (behind the fade-in) so its
## shaders are compiled before the first shot. Everything hangs off one
## temporary node that is freed a few frames later.
static func warm_up(parent: Node3D, at: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = "WeaponFxWarmup"
	parent.add_child(holder)
	var w := WeaponData.new()
	w.tracer_color = Color(0.7, 0.9, 1.0)
	for style in [&"rail", &"lightning"]:
		w.tracer_style = style
		shot(holder, at + Vector3.LEFT, at + Vector3.RIGHT, w)
	for style in [&"frost", &"arc", &"rail"]:
		w.impact_style = style
		impact(holder, at, Vector3.UP, w)
	explosion(holder, at, Color(1.0, 0.4, 0.8), 1.0)
	shatter(holder, at)
	var beam := BeamVisual.new()
	holder.add_child(beam)
	beam.aim(at + Vector3.LEFT, at + Vector3.RIGHT, true)
	var frost := MeshInstance3D.new()
	frost.mesh = BoxMesh.new()
	var sm := ShaderMaterial.new()
	sm.shader = load(StatusEffects.FROST_SHADER)
	frost.material_override = sm
	holder.add_child(frost)
	frost.global_position = at
	for i in 4:
		await holder.get_tree().process_frame
	holder.queue_free()
