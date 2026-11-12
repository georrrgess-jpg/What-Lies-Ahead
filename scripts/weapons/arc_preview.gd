class_name ArcPreview
extends Node3D
## Dotted flight path and landing ring for lobbed projectiles, shown while
## aiming. Simulates the same launch, gravity and first contact as
## WeaponProjectile, so the ring marks where the shot will go off (or bounce).

const DOTS := 26
const STEP := 0.045
const MASK := 5

var color := Color(1.0, 0.4, 0.85)
var _dots: MultiMeshInstance3D
var _ring: MeshInstance3D
var _shown := 0.0


func _ready() -> void:
	top_level = true
	var dot := SphereMesh.new()
	dot.radius = 1.0
	dot.height = 2.0
	dot.radial_segments = 8
	dot.rings = 4
	_dots = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = dot
	mm.instance_count = DOTS
	_dots.multimesh = mm
	_dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dots)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.93
	ring.outer_radius = 1.0
	ring.rings = 36
	ring.ring_segments = 4
	_ring = MeshInstance3D.new()
	_ring.mesh = ring
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	# Dots draw through scenery so the arc reads; the blast ring sits in the world.
	_dots.material_override = _glow_material(true)
	_ring.material_override = _glow_material(false)
	visible = false


func _glow_material(on_top: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = on_top
	m.albedo_color = color
	return m


## Redraws the path for a launch from `from` with `vel`. `strength` 0-1 fades it.
func show_path(w: WeaponData, from: Vector3, vel: Vector3, strength: float, exclude: Array[RID]) -> void:
	_shown = strength
	visible = strength > 0.02
	if not visible:
		return
	(_dots.material_override as StandardMaterial3D).albedo_color = Color(w.tracer_color, 0.75 * strength)
	(_ring.material_override as StandardMaterial3D).albedo_color = Color(w.tracer_color, 0.5 * strength)
	var space := get_world_3d().direct_space_state
	var p := from
	var v := vel
	var t := 0.0
	var landed := false
	var normal := Vector3.UP
	var mm := _dots.multimesh
	var dot_every := maxf(0.02, w.projectile_fuse / DOTS)
	var next_dot := 0.0
	var count := 0
	while t < w.projectile_fuse and count < DOTS and not landed:
		var nv := v + Vector3.DOWN * w.projectile_gravity * STEP
		var np := p + nv * STEP
		var q := PhysicsRayQueryParameters3D.create(p, np, MASK)
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			np = hit["position"]
			normal = hit["normal"]
			landed = true
		if t >= next_dot or landed:
			var s := 0.06 if count > 1 else 0.0
			mm.set_instance_transform(count, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), np))
			count += 1
			next_dot += dot_every
		p = np
		v = nv
		t += STEP
	for i in range(count, DOTS):
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), p))
	_ring.visible = true
	var up := normal if normal.length() > 0.1 else Vector3.UP
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var r := maxf(0.4, w.splash_radius)
	_ring.global_transform = Transform3D(Basis(side * r, up * 0.3, side.cross(up) * r), p + up * 0.06)
