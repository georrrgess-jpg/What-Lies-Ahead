class_name BossBeam
extends BossMove
## A sweeping beam: the Idol Keeper's idol laser, the Night Manager's
## flashlight. During the wind-up a thin aiming line points at the player;
## then the full beam swings through an arc centred on them, sweeping the
## floor at `height`. It hurts while it is on the player, unless the player is
## behind cover (scenery or a standing BossZone pillar) or, for a low beam,
## jumps it.

@export var sweep_degrees := 110.0
@export var sweep_time := 2.2
@export var beam_range := 26.0
## Height of the beam over the alpha's feet.
@export var height := 0.6
## Half-width of the beam (metres at the player).
@export var half_width := 0.6
## True: a player in the air clears the beam (it is a low, skipping-rope beam).
@export var jumpable := true
@export var dps := 22.0
@export var color := Color(0.3, 1, 0.6)
@export var beam_sound: StringName = &"rounds_boss_beam"
## A spotlight cone rides the beam (the flashlight).
@export var light := false

const TICK := 0.25

var _wind := 0.0
var _sweep := 0.0
var _from_angle := 0.0
var _side := 1.0
var _tick := 0.0
var _beam: MeshInstance3D
var _mat: StandardMaterial3D
var _spot: SpotLight3D

static var _box: BoxMesh


func begin(z: Zombie) -> void:
	super.begin(z)
	_wind = windup
	_sweep = 0.0
	_side = 1.0 if randf() < 0.5 else -1.0
	_make_beam(z)


func tick(z: Zombie, delta: float) -> bool:
	z.move_with(Vector3.ZERO)
	var to := flat_to_target(z)
	if _wind > 0.0:
		_wind -= delta
		z.face_toward(to, delta * 2.0)
		_from_angle = atan2(to.x, to.z) - _side * deg_to_rad(sweep_degrees) * 0.5
		_place(z, atan2(to.x, to.z), 0.08 + 0.04 * sin(_wind * 30.0), 0.5)
		if _wind <= 0.0:
			Sfx.play_at(beam_sound, z.global_position + Vector3.UP * 1.5, 3.0, 1.0, 18.0)
		return true
	_sweep += delta
	var k := clampf(_sweep / sweep_time, 0.0, 1.0)
	var angle := _from_angle + _side * deg_to_rad(sweep_degrees) * k
	z.face_toward(Vector3(sin(angle), 0.0, cos(angle)), delta * 8.0)
	_place(z, angle, half_width, 0.9)
	_burn(z, angle, delta)
	if k >= 1.0:
		_drop()
		z.play_animation(z.data.move_animation, 0.25)
		return false
	return true


func cancel(_z: Zombie) -> void:
	_wind = 0.0
	_sweep = sweep_time
	_drop()


func is_winding_up() -> bool:
	return _wind > 0.0


func wants_jump(z: Zombie, point: Vector3) -> bool:
	return jumpable and _wind <= 0.0 and _sweep < sweep_time and _on_beam(z, _current_angle(), point, 1.0)


func _current_angle() -> float:
	return _from_angle + _side * deg_to_rad(sweep_degrees) * clampf(_sweep / sweep_time, 0.0, 1.0)


## True when `point` (feet) is within the beam at `angle` (widened by `margin`).
func _on_beam(z: Zombie, angle: float, point: Vector3, margin := 0.0) -> bool:
	var dir := Vector3(sin(angle), 0.0, cos(angle))
	var rel := point - z.global_position
	rel.y = 0.0
	var along := rel.dot(dir)
	if along < 0.5 or along > beam_range:
		return false
	return absf(rel.dot(Vector3(dir.z, 0.0, -dir.x))) <= half_width + 0.35 + margin


func _burn(z: Zombie, angle: float, delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	var player := z.target
	if not player.alive or not _on_beam(z, angle, player.global_position):
		return
	if jumpable and player.global_position.y - z.global_position.y > height - 0.1:
		return
	var from := z.global_position + Vector3.UP * maxf(height, 0.9)
	var to := player.global_position + Vector3.UP * maxf(height, 0.9)
	for zone in BossZone.live:
		if zone.blocks(from, to):
			return
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [z.get_rid()]
	if not z.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return
	_tick = TICK
	player.take_damage(dps * TICK * z.damage_scale, z.global_position)


func _make_beam(z: Zombie) -> void:
	_drop()
	if _box == null:
		_box = BoxMesh.new()
		_box.size = Vector3.ONE
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam = MeshInstance3D.new()
	_beam.mesh = _box
	_beam.material_override = _mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	z.get_parent().add_child(_beam)
	if light:
		_spot = SpotLight3D.new()
		_spot.light_color = color
		_spot.light_energy = 6.0
		_spot.spot_range = beam_range
		_spot.spot_angle = rad_to_deg(atan2(half_width * 2.0, 6.0))
		_spot.shadow_enabled = false
		z.get_parent().add_child(_spot)


## The beam runs flat at `height` from just in front of the alpha out along
## `angle` (the wind-up's aiming line is thinner and fainter).
func _place(z: Zombie, angle: float, w: float, alpha: float) -> void:
	if not is_instance_valid(_beam):
		return
	var dir := Vector3(sin(angle), 0.0, cos(angle))
	var from := z.global_position + Vector3.UP * height + dir * 0.8
	var to := z.global_position + dir * beam_range + Vector3.UP * height
	var axis := to - from
	var b := Basis.looking_at(axis.normalized(), Vector3.UP)
	b = Basis(b.x * w * 2.0, b.y * minf(w * 2.0, 0.5), b.z * axis.length())
	_beam.global_transform = Transform3D(b, from + axis * 0.5)
	_mat.albedo_color = Color(color, alpha * 0.55)
	if is_instance_valid(_spot):
		_spot.global_transform = Transform3D(Basis.looking_at(axis.normalized(), Vector3.UP), from)


func _drop() -> void:
	if is_instance_valid(_beam):
		_beam.queue_free()
	_beam = null
	if is_instance_valid(_spot):
		_spot.queue_free()
	_spot = null
