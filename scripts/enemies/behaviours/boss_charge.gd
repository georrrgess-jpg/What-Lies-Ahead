class_name BossCharge
extends BossMove
## A telegraphed charge down a lane: a glowing strip grows from the alpha
## through the player (it follows them for the first part of the wind-up,
## then locks), then the alpha rushes along it. Anyone it runs into is hit and
## thrown aside. Step off the lane. Options make it each alpha's own:
##
##   guard        while it charges, shots from the front do only this share of
##                damage (a riot shield up front: shoot it from the side)
##   trail        it leaves a patch behind every few metres (rocket boots
##                leave fire, the Confectioner leaves sticky syrup)
##   repeats      it charges again straight away, re-aiming each time
##   dazed        after the last charge it stands dazed this long, its weak
##                spot glowing (AlphaBossBehaviour.expose): the reward for
##                baiting the charge

@export var speed := 13.0
## Lane length past the player.
@export var overshoot := 4.0
@export var width := 2.4
@export var damage := 16.0
@export var shove := 9.0
@export_range(0.0, 1.0) var lock_fraction := 0.6
@export var color := Color(1, 0.4, 0.3)
@export var dash_clip: StringName = &"Run"
@export var dash_sound: StringName = &"rounds_boss_charge"
@export_range(0.0, 1.0) var guard := 1.0
@export var repeats := 1
## Wind-up of the repeat charges (the first uses `windup`).
@export var repeat_windup := 0.6
@export var dazed := 0.0

@export_group("Trail")
@export var trail_every := 0.0
@export var trail_radius := 1.3
@export var trail_seconds := 4.0
@export var trail_dps := 8.0
@export_range(0.1, 1.0) var trail_slow := 1.0
@export var trail_color := Color(1, 0.45, 0.1)

var _wind := 0.0
var _wind_total := 1.0
var _dash := 0.0
var _left := 0
var _dir := Vector3.FORWARD
var _length := 10.0
var _hit := false
var _trail_at := Vector3.ZERO
var _lane: MeshInstance3D
var _lane_mat: StandardMaterial3D

static var _strip: BoxMesh


func begin(z: Zombie) -> void:
	super.begin(z)
	_left = repeats
	_start_windup(z, windup)


func tick(z: Zombie, delta: float) -> bool:
	if _wind > 0.0:
		_wind -= delta
		var k := clampf(1.0 - _wind / _wind_total, 0.0, 1.0)
		if k < lock_fraction:
			_aim(z)
		z.face_toward(_dir, delta * 3.0)
		z.move_with(Vector3.ZERO)
		_place_lane(z, k)
		if _wind <= 0.0:
			_start_dash(z)
		return true
	if _dash > 0.0:
		_dash -= delta
		var before := z.global_position
		z.move_with(_dir * speed)
		_contact(z)
		_drop_trail(z)
		if _dash <= 0.0 or (before.distance_to(z.global_position) < speed * delta * 0.25 and _dash < _length / speed - 0.2):
			_end_dash(z)
		return _left > 0 or _dash > 0.0 or _wind > 0.0
	return false


func cancel(_z: Zombie) -> void:
	_wind = 0.0
	_dash = 0.0
	_left = 0
	_drop_lane()


func is_winding_up() -> bool:
	return _wind > 0.0


func filter_hit(z: Zombie, amount: float, at: Vector3, _headshot: bool) -> float:
	if guard >= 1.0 or (_wind <= 0.0 and _dash <= 0.0):
		return amount
	var to_hit := at - z.global_position
	to_hit.y = 0.0
	if to_hit.normalized().dot(z.global_basis.z) > 0.3:
		return amount * guard
	return amount


func escape_from(z: Zombie, point: Vector3) -> Vector3:
	if _wind <= 0.0 and _dash <= 0.0:
		return Vector3.ZERO
	var rel := point - z.global_position
	rel.y = 0.0
	var along := rel.dot(_dir)
	var side := Vector3(-_dir.z, 0.0, _dir.x)
	var across := rel.dot(side)
	if along < -1.0 or along > _length + 1.0 or absf(across) > width * 0.5 + 1.0:
		return Vector3.ZERO
	return side * (1.0 if across >= 0.0 else -1.0)


func _start_windup(z: Zombie, seconds: float) -> void:
	_wind = seconds
	_wind_total = seconds
	_hit = false
	_aim(z)
	if _lane == null:
		if _strip == null:
			_strip = BoxMesh.new()
			_strip.size = Vector3(1.0, 0.04, 1.0)
		_lane_mat = StandardMaterial3D.new()
		_lane_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_lane_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_lane_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_lane = MeshInstance3D.new()
		_lane.mesh = _strip
		_lane.material_override = _lane_mat
		_lane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		z.get_parent().add_child(_lane)
	_place_lane(z, 0.0)


func _aim(z: Zombie) -> void:
	_dir = flat_to_target(z)
	var d := z.distance_to_target()
	_length = clampf(d + overshoot, 6.0, 24.0)


func _place_lane(z: Zombie, k: float) -> void:
	if not is_instance_valid(_lane):
		return
	var start := z.global_position
	var b := Basis.looking_at(_dir, Vector3.UP)
	var grown := maxf(0.5, _length * ease(k, 0.5))
	b = Basis(b.x * width, b.y, b.z * grown)
	_lane.global_transform = Transform3D(b, start + _dir * grown * 0.5 + Vector3.UP * 0.07)
	_lane_mat.albedo_color = Color(color, 0.25 + 0.5 * k + 0.2 * sin(k * 28.0))


func _start_dash(z: Zombie) -> void:
	_left -= 1
	_dash = _length / speed
	_trail_at = z.global_position
	z.play_animation(dash_clip, 0.05)
	Sfx.play_at(dash_sound, z.global_position + Vector3.UP, 3.0, randf_range(0.95, 1.05), 16.0)


func _contact(z: Zombie) -> void:
	var player := z.target
	if _hit or not player.alive:
		return
	var rel := player.global_position - z.global_position
	rel.y = 0.0
	if rel.length() <= width * 0.5 + 0.7:
		_hit = true
		player.take_damage(damage * z.damage_scale, z.global_position)
		var side := Vector3(-_dir.z, 0.0, _dir.x)
		var away := (side * signf(rel.dot(side) + 0.01) + _dir).normalized()
		player.velocity += away * shove + Vector3.UP * 3.0


func _drop_trail(z: Zombie) -> void:
	if trail_every <= 0.0 or z.global_position.distance_to(_trail_at) < trail_every:
		return
	_trail_at = z.global_position
	var zone := BossZone.new()
	zone.radius = trail_radius
	zone.telegraph = 0.05
	zone.damage = 0.0
	zone.color = trail_color
	zone.prop = BossZone.Prop.NONE
	zone.linger = trail_seconds
	zone.linger_dps = trail_dps * z.damage_scale
	zone.linger_slow = trail_slow
	zone.warn_sound = &""
	zone.hit_sound = &""
	zone.source = z
	z.get_parent().add_child(zone)
	zone.global_position = floor_point(z, z.global_position)


func _end_dash(z: Zombie) -> void:
	_dash = 0.0
	z.target.add_shake(0.2)
	if _left > 0:
		_start_windup(z, repeat_windup)
		return
	_drop_lane()
	z.play_animation(z.data.move_animation, 0.25)
	if dazed > 0.0:
		boss.expose(z, dazed)


func _drop_lane() -> void:
	if is_instance_valid(_lane):
		_lane.queue_free()
	_lane = null
