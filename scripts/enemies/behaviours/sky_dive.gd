class_name SkyDiveBehaviour
extends DuneLeapBehaviour
## Sky Diver (and Captain Cumulus): at mid range it crouches and a ring lights
## up on the deck where it will come down (the telegraph: the Crouch clip, a
## whistle, the threat ring on the HUD and the marker). It vaults high, pops a
## striped canopy at the top of the arc and floats down onto the marker; the
## landing hurts anyone still inside the ring. The marker is fixed when the
## crouch starts, so stepping out of the ring is the dodge. A headshot during
## the crouch cancels the dive.

## Share of the flight spent rising (the rest is the slow canopy descent).
@export var rise_share := 0.32
## Canopy radius (metres, before the zombie's body scale).
@export var canopy_radius := 1.1
@export var marker_color := Color(1.0, 0.36, 0.42)
@export var canopy_colors: Array[Color] = [Color(0.91, 0.22, 0.31), Color(1.0, 0.95, 0.88)]
@export var chute_sound: StringName = &"sky_chute_pop"
## How much of the player's motion the landing leads (0 = where they stood).
@export var lead := 0.55

var _marker: MeshInstance3D
var _canopy: MeshInstance3D
var _popped := false
var _size := 1.0

static var _ring_mesh: TorusMesh
static var _disc_mesh: CylinderMesh
static var _canopy_meshes := {}


## Seconds before the first dive (a random pick in this range): divers come
## in hot, so they dive before they close to melee range.
@export var first_dive := Vector2(0.4, 1.6)


func on_ready(z: Zombie) -> void:
	super.on_ready(z)
	_cool = randf_range(first_dive.x, first_dive.y)


## Dives at a player in range: always when they stand higher or out of sight
## (the dive clears railings and stalls), otherwise when they are in view.
func _wants_leap(z: Zombie) -> bool:
	var d := z.distance_to_target()
	if d < min_range or d > max_range:
		return false
	var higher := z.target.global_position.y - z.global_position.y > 1.2
	return higher or z.has_line_of_sight() or d > max_range * 0.6


## Aims where the player is heading (part of their motion over the crouch and
## the flight), fixed when the crouch begins.
func _landing_goal(z: Zombie) -> Vector3:
	var p := z.target.global_position + z.target.velocity * Vector3(1, 0, 1) * (windup + flight_time) * lead
	var back := z.global_position - p
	back.y = 0.0
	return p + back.normalized() * land_offset


## A fast climb to the apex, then the long, eased canopy descent.
func _arc_point(t: float) -> Vector3:
	var flat := _from.lerp(_to, t)
	var lift := 0.0
	if t < rise_share:
		lift = sin(t / rise_share * PI * 0.5)
	else:
		lift = cos((t - rise_share) / (1.0 - rise_share) * PI * 0.5)
	return flat + Vector3.UP * apex * lift


func interrupt(z: Zombie) -> void:
	super.interrupt(z)
	if _wind <= 0.0 and _flight < 0.0:
		_clear()


func on_hit(z: Zombie, amount: float, _hit_position: Vector3, headshot: bool) -> float:
	if headshot and _wind > 0.0:
		interrupt(z)
	return amount


func on_physics(z: Zombie, delta: float) -> bool:
	var was_idle := _wind <= 0.0 and _flight < 0.0
	var busy := super.on_physics(z, delta)
	if was_idle and _wind > 0.0:
		_show_marker(z)
	if is_instance_valid(_marker):
		var k := 1.0
		if _wind > 0.0:
			k = 1.0 - _wind / maxf(windup, 0.01)
		var r := landing_radius * lerpf(0.35, 1.0, minf(k * 1.5, 1.0))
		_marker.scale = Vector3(r, 1.0, r)
	return busy


func on_death(_z: Zombie) -> void:
	_clear()


func _on_flight_tick(z: Zombie, _delta: float, t: float) -> void:
	if not _popped and t >= rise_share:
		_popped = true
		_open_canopy(z)
	if is_instance_valid(_canopy):
		var open := clampf((t - rise_share) / 0.12, 0.0, 1.0)
		_canopy.scale = Vector3(open, lerpf(0.3, 1.0, open), open) * _size
		_canopy.rotation.y += 0.02


func _on_landed(_z: Zombie) -> void:
	_clear()


func _show_marker(z: Zombie) -> void:
	_make_meshes()
	_clear()
	_popped = false
	_marker = MeshInstance3D.new()
	_marker.mesh = _ring_mesh
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disc := MeshInstance3D.new()
	disc.mesh = _disc_mesh
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position.y = -0.02
	_marker.add_child(disc)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = marker_color
	_marker.material_override = m
	z.get_parent().add_child(_marker)
	_marker.global_position = _to + Vector3.UP * 0.06


func _open_canopy(z: Zombie) -> void:
	_canopy = MeshInstance3D.new()
	_canopy.mesh = _canopy_mesh(canopy_colors)
	_canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	z.add_child(_canopy)
	_size = z.data.body_scale
	_canopy.position = Vector3(0, 2.75 * _size, 0)
	_canopy.scale = Vector3(0.05, 0.3, 0.05) * _size
	Sfx.play_at(chute_sound, z.global_position + Vector3.UP * 3.0, 0.0, randf_range(0.92, 1.08))


func _clear() -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()
	if is_instance_valid(_canopy):
		_canopy.queue_free()
	_marker = null
	_canopy = null


static func _make_meshes() -> void:
	if _ring_mesh:
		return
	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.9
	_ring_mesh.outer_radius = 1.0
	_ring_mesh.rings = 40
	_ring_mesh.ring_segments = 4
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(1.0, 0.35, 0.4, 0.35)
	_disc_mesh = CylinderMesh.new()
	_disc_mesh.top_radius = 1.0
	_disc_mesh.bottom_radius = 1.0
	_disc_mesh.height = 0.02
	_disc_mesh.radial_segments = 32
	_disc_mesh.material = glow


## A striped parachute dome (gores alternate the colours) with its lines,
## radius 1 at the hem; built once per colour set.
func _canopy_mesh(colors: Array[Color]) -> ArrayMesh:
	var key := str(colors) + str(canopy_radius)
	if _canopy_meshes.has(key):
		return _canopy_meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var gores := 12
	var rings := 4
	var r := canopy_radius
	for g in gores:
		var c := colors[g % colors.size()]
		for k in rings:
			var a0 := TAU * g / gores
			var a1 := TAU * (g + 1) / gores
			var p0 := PI * 0.5 * k / rings
			var p1 := PI * 0.5 * (k + 1) / rings
			var q := [_dome(a0, p0, r), _dome(a1, p0, r), _dome(a1, p1, r), _dome(a0, p1, r)]
			for i in [0, 2, 1, 0, 3, 2]:
				st.set_color(c)
				st.set_normal((q[i] as Vector3).normalized())
				st.add_vertex(q[i])
	# Lines from the hem down to the harness.
	var harness := Vector3(0, -1.35, 0)
	for g in range(0, gores, 3):
		var a := TAU * g / gores
		var hem := Vector3(cos(a) * r, 0, sin(a) * r)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.015
		for v in [hem - side, hem + side, harness]:
			st.set_color(Color(0.2, 0.2, 0.3))
			st.set_normal(Vector3(cos(a), 0, sin(a)))
			st.add_vertex(v)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.6
	st.set_material(m)
	var mesh := st.commit()
	_canopy_meshes[key] = mesh
	return mesh


static func _dome(a: float, p: float, r: float) -> Vector3:
	return Vector3(cos(a) * cos(p) * r, sin(p) * r * 0.62, sin(a) * cos(p) * r)
