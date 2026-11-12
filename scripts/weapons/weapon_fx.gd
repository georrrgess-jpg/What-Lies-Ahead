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
static var _ring: TorusMesh
static var _ring_mats := {}


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


## A flat shockwave ring expanding along the ground.
static func shockwave(parent: Node, at: Vector3, color: Color, radius: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if _ring == null:
		_ring = TorusMesh.new()
		_ring.inner_radius = 0.82
		_ring.outer_radius = 1.0
		_ring.rings = 32
		_ring.ring_segments = 6
	var key := color.to_html()
	if not _ring_mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = color.lerp(Color.WHITE, 0.25)
		_ring_mats[key] = m
	var r := MeshInstance3D.new()
	r.mesh = _ring
	r.material_override = _ring_mats[key]
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(r)
	r.global_position = at + Vector3.UP * 0.12
	r.scale = Vector3(0.3, 0.6, 0.3)
	var tw := r.create_tween().set_parallel(true)
	tw.tween_property(r, "scale", Vector3(radius, 0.25, radius), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "transparency", 1.0, 0.32).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(r.queue_free)


## A splash weapon's detonation: flash, shockwave, sparks and confetti.
static func explosion(parent: Node, at: Vector3, color: Color, radius: float) -> void:
	flash(parent, at, color, radius * 0.75, 0.22)
	shockwave(parent, Vector3(at.x, at.y - 0.3, at.z), color, radius)
	burst(parent, at, Vector3.UP, [color, Color.WHITE, Color(1.0, 0.85, 0.3)], 34, 9.0, 0.5, 0.09, 180.0, Vector3(0, -12.0, 0))
	burst(parent, at, Vector3.UP, [Color(1.0, 0.35, 0.75), Color(0.3, 0.95, 1.0), Color(1.0, 0.85, 0.25), Color(0.6, 1.0, 0.45)],
		40, 6.5, 1.1, 0.13, 70.0, Vector3(0, -6.0, 0))


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
