class_name CandyTaffyYankBehaviour
extends EnemyBehaviour
## Taffy Puller: at mid range with a clear line it plants its feet and whirls
## a rope of taffy overhead (the telegraph: the Whirl clip, a rising stretchy
## whine, the threat ring and a pink line on the floor that tracks the player,
## then locks partway through). Then it lashes along the locked line: a player
## still standing on the line is yanked toward the puller (small damage).
## Stepping off the line or breaking line of sight is the dodge; a headshot
## during the whirl snaps the taffy and cancels the lash.

@export var min_range := 5.0
@export var max_range := 15.0
@export var cooldown := 7.5
## Seconds of whirling before the lash; the line locks after lock_fraction.
@export var windup := 1.15
@export_range(0.0, 1.0) var lock_fraction := 0.55
## Half-width of the lash line: a player this close to it is caught.
@export var corridor := 0.9
@export var damage := 6.0
## Speed (m/s) the yank gives the player toward the puller, plus a little lift.
@export var pull_speed := 9.0
@export var pull_lift := 2.2
@export var line_color := Color(1.0, 0.42, 0.72)
@export var whirl_sound: StringName = &"candy_taffy_whirl"
@export var lash_sound: StringName = &"candy_taffy_snap"

const STRAND_SECONDS := 0.28

var _cool := 3.0
var _winding := 0.0
var _dir := Vector3.FORWARD
var _length := 10.0
var _marker: MeshInstance3D
var _marker_mat: StandardMaterial3D
var _strand: MeshInstance3D
var _strand_left := 0.0
var _strand_end := Vector3.ZERO

static var _unit_box: BoxMesh
static var _strand_mesh: CylinderMesh


func on_ready(_z: Zombie) -> void:
	_cool = randf_range(2.0, cooldown)


func on_physics(z: Zombie, delta: float) -> bool:
	_cool -= delta
	_tick_strand(z, delta)
	if _winding > 0.0:
		_whirl(z, delta)
		return true
	if _cool <= 0.0 and z.state == Zombie.State.CHASE and z.target.alive and not z.is_winding_up():
		var d := z.distance_to_target()
		if d >= min_range and d <= max_range and z.has_line_of_sight():
			_begin(z)
			return true
	return false


func on_hit(z: Zombie, amount: float, _hit_position: Vector3, headshot: bool) -> float:
	if headshot:
		interrupt(z)
	return amount


func interrupt(z: Zombie) -> void:
	if _winding <= 0.0:
		return
	_winding = 0.0
	_cool = cooldown * 0.6
	_clear_marker()
	z.play_animation(&"Stagger", 0.05)
	Sfx.play_at(lash_sound, z.global_position + Vector3.UP * 2.0, -6.0, 1.5)


func on_death(_z: Zombie) -> void:
	_clear_marker()
	_clear_strand()


func is_winding_up() -> bool:
	return _winding > 0.0


func _begin(z: Zombie) -> void:
	_cool = cooldown
	_winding = windup
	_aim(z)
	z.play_animation(&"Whirl", 0.12)
	Sfx.play_at(whirl_sound, z.global_position + Vector3.UP * 2.0, 0.0, randf_range(0.95, 1.05))
	_make_marker(z)


func _whirl(z: Zombie, delta: float) -> void:
	_winding -= delta
	if _winding > windup * (1.0 - lock_fraction):
		_aim(z)
	z.face_toward(_dir, delta * 3.0)
	z.move_with(Vector3.ZERO)
	_place_marker(z, 1.0 - _winding / windup)
	if _winding <= 0.0:
		_lash(z)


## Tracks the player: the lash direction and how far it reaches.
func _aim(z: Zombie) -> void:
	var to := z.target.global_position - z.global_position
	to.y = 0.0
	if to.length() > 0.1:
		_dir = to.normalized()
	_length = clampf(to.length() + 2.5, min_range, max_range + 2.0)


func _lash(z: Zombie) -> void:
	_clear_marker()
	z.play_animation(&"Yank", 0.05)
	var from := z.global_position + Vector3.UP * 1.5 * z.data.body_scale
	var to_player := z.target.global_position - z.global_position
	to_player.y = 0.0
	var along := to_player.dot(_dir)
	var off := (to_player - _dir * along).length()
	var caught := z.target.alive and along > 0.5 and along <= _length + 0.5 and off <= corridor and z.has_line_of_sight()
	if caught:
		_strand_end = z.target.global_position + Vector3.UP * 1.0
		z.target.take_damage(damage, z.global_position)
		var pull := -to_player.normalized()
		z.target.velocity += pull * pull_speed + Vector3.UP * pull_lift
		Sfx.play_at(lash_sound, _strand_end, 2.0, randf_range(0.9, 1.0))
	else:
		_strand_end = z.global_position + _dir * _length + Vector3.UP * 0.6
		Sfx.play_at(lash_sound, from, -2.0, randf_range(1.1, 1.25))
	_make_strand(z)


# --- the floor line ----------------------------------------------------------

func _make_marker(z: Zombie) -> void:
	_clear_marker()
	if _unit_box == null:
		_unit_box = BoxMesh.new()
		_unit_box.size = Vector3.ONE
	_marker_mat = StandardMaterial3D.new()
	_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_marker_mat.albedo_color = Color(line_color, 0.0)
	_marker = MeshInstance3D.new()
	_marker.mesh = _unit_box
	_marker.material_override = _marker_mat
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	z.get_parent().add_child(_marker)


## Lays the line along the aim, brightening as the lash nears (k: 0..1).
func _place_marker(z: Zombie, k: float) -> void:
	if not is_instance_valid(_marker):
		return
	var start := z.global_position + _dir * 0.6
	var mid := start + _dir * (_length - 0.6) * 0.5 + Vector3.UP * 0.06
	var locked := k >= lock_fraction
	var width := corridor * 2.0 * (1.0 if locked else 0.6)
	var b := Basis.looking_at(_dir, Vector3.UP)
	_marker.global_transform = Transform3D(Basis(b.x * width, b.y * 0.04, b.z * (_length - 0.6)), mid)
	var pulse := 0.5 + 0.5 * sin(k * 30.0) if locked else 0.0
	_marker_mat.albedo_color = Color(line_color, lerpf(0.12, 0.5, k) + 0.25 * pulse)


func _clear_marker() -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null


# --- the taffy strand ---------------------------------------------------------

func _make_strand(z: Zombie) -> void:
	_clear_strand()
	if _strand_mesh == null:
		_strand_mesh = CylinderMesh.new()
		_strand_mesh.top_radius = 0.07
		_strand_mesh.bottom_radius = 0.05
		_strand_mesh.height = 1.0
		_strand_mesh.radial_segments = 8
		_strand_mesh.rings = 1
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.62, 0.82)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.45, 0.72)
		m.emission_energy_multiplier = 0.6
		m.roughness = 0.3
		_strand_mesh.material = m
	_strand = MeshInstance3D.new()
	_strand.mesh = _strand_mesh
	_strand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	z.get_parent().add_child(_strand)
	_strand_left = STRAND_SECONDS
	_tick_strand(z, 0.0)


## The strand stretches from the puller's fist to its end, thinning as it snaps back.
func _tick_strand(z: Zombie, delta: float) -> void:
	if not is_instance_valid(_strand):
		return
	_strand_left -= delta
	if _strand_left <= 0.0:
		_clear_strand()
		return
	var hand := z.global_position + Vector3.UP * 1.6 * z.data.body_scale + _dir * 0.4
	var k := _strand_left / STRAND_SECONDS
	var end := hand.lerp(_strand_end, k)
	var span := end - hand
	if span.length() < 0.05:
		return
	var up := span.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up)
	var thick := lerpf(0.4, 1.0, k)
	_strand.global_transform = Transform3D(Basis(side * thick, up * span.length(), fwd * thick), (hand + end) * 0.5)


func _clear_strand() -> void:
	if is_instance_valid(_strand):
		_strand.queue_free()
	_strand = null
