class_name CityWreckingSwing
extends BossMove
## The Wrecker's wrecking-ball sweep. The wind-up: it whirls the ball round
## over its head while a fan glows on the floor in front of it, filling in
## (the arc the ball will cover, centred on the player). Then it lets the
## chain out and scythes the ball through the fan at waist height: anyone
## inside is hit hard and thrown. The safe spots are out of reach past the
## fan's edge, behind it, or right up close under the chain (the inner ring
## stays dark). With `sweeps` > 1 it winds back and sweeps again. The ball
## always travels from its right to its left, as the Swing clip does.

@export var reach := 7.5
## Too close for the chain: inside this radius the ball passes overhead.
@export var inner := 2.2
@export var arc_degrees := 220.0
@export var sweep_time := 0.4
@export var sweeps := 1
## Seconds between sweeps, and planted after the last one.
@export var recover := 0.7
@export var damage := 28.0
@export var shove := 11.0
@export var color := Color(1.0, 0.72, 0.18)
@export var ball_mesh := "Acc_Wrecker_Ball"
@export var sweep_sound: StringName = &"cz_wrecker_swing"
@export var hit_sound: StringName = &"cz_wrecker_impact"

const SEGMENTS := 28
const BALL_RADIUS := 0.55
## Seconds into the Swing clip where the arm winds back for the sweep.
const REPEAT_FROM := 26.0 / 24.0

var _wind := 0.0
var _sweep := 0.0
var _rest := 0.0
var _left := 0
var _centre := 0.0
var _hit := false
var _fan: MeshInstance3D
var _fan_mat: StandardMaterial3D
var _ball: MeshInstance3D
var _chain: MeshInstance3D
var _model_ball: Node3D

static var _fan_meshes := {}
static var _ball_sphere: SphereMesh
static var _chain_box: BoxMesh


func begin(z: Zombie) -> void:
	super.begin(z)
	_wind = windup
	_sweep = 0.0
	_rest = 0.0
	_left = sweeps
	_centre = _angle_of(BossMove.flat_to_target(z))
	if _model_ball == null:
		_model_ball = z.model_root.find_child(ball_mesh, true, false) as Node3D
	_make_fan(z)


func tick(z: Zombie, delta: float) -> bool:
	z.move_with(Vector3.ZERO)
	if _wind > 0.0:
		_wind -= delta
		var k := clampf(1.0 - _wind / windup, 0.0, 1.0)
		# The fan follows the player for the first half, then locks.
		if k < 0.5:
			_centre = _angle_of(BossMove.flat_to_target(z))
		z.face_toward(_dir(_centre), delta * 2.0)
		_place_fan(z, k)
		if _wind <= 0.0:
			_start_sweep(z)
		return true
	if _sweep > 0.0:
		_sweep -= delta
		var u := 1.0 - clampf(_sweep / sweep_time, 0.0, 1.0)
		var a := _centre + deg_to_rad(arc_degrees) * 0.5 * (2.0 * u - 1.0)
		_place_ball(z, a)
		_contact(z, a)
		if _sweep <= 0.0:
			_left -= 1
			_rest = recover
			if _left <= 0:
				_drop_visuals()
		return true
	if _rest > 0.0:
		_rest -= delta
		if _rest <= 0.0 and _left > 0:
			_start_sweep(z, true)
		return _rest > 0.0 or _left > 0
	return false


func cancel(_z: Zombie) -> void:
	_wind = 0.0
	_sweep = 0.0
	_rest = 0.0
	_left = 0
	_drop_visuals()


func is_winding_up() -> bool:
	return _wind > 0.0


func escape_from(z: Zombie, point: Vector3) -> Vector3:
	if _wind <= 0.0 and _sweep <= 0.0:
		return Vector3.ZERO
	var rel := point - z.global_position
	rel.y = 0.0
	var d := rel.length()
	if d < inner or d > reach + 1.0 or not _in_arc(_angle_of(rel)):
		return Vector3.ZERO
	return rel.normalized()


## Starts a sweep. The wind-up clip reaches its sweep as the wind-up ends;
## a repeat sweep replays the clip from its wind-back.
func _start_sweep(z: Zombie, repeat := false) -> void:
	_sweep = sweep_time
	_hit = false
	if repeat:
		z.play_animation(windup_clip, 0.08)
		var anim := z.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim and anim.current_animation == String(windup_clip):
			anim.seek(REPEAT_FROM, true)
	if is_instance_valid(_model_ball):
		_model_ball.visible = false
	Sfx.play_at(sweep_sound, z.global_position + Vector3.UP * 1.5, 4.0, randf_range(0.95, 1.05), 18.0)
	if is_instance_valid(_fan_mat):
		_fan_mat.albedo_color = Color(color.lightened(0.3), 0.75)


func _contact(z: Zombie, a: float) -> void:
	var player := z.target
	if _hit or not player.alive:
		return
	var rel := player.global_position - z.global_position
	rel.y = 0.0
	var d := rel.length()
	if d < inner or d > reach + 0.4:
		return
	# Hit once the ball has passed the player's bearing.
	var pa := _angle_of(rel)
	var swept := wrapf(a - pa, -PI, PI)
	if swept < 0.0 or swept > 0.6 or not _in_arc(pa):
		return
	_hit = true
	player.take_damage(damage * z.damage_scale, z.global_position)
	var push := rel.normalized() + _tangent(pa) * 0.6
	player.velocity += push.normalized() * shove + Vector3.UP * 4.0
	player.add_shake(0.45)
	Sfx.play_at(hit_sound, player.global_position + Vector3.UP, 3.0, randf_range(0.95, 1.05))
	Fx.impact(z.get_parent(), player.global_position + Vector3.UP, -rel.normalized(), color)


func _in_arc(angle: float) -> bool:
	return absf(wrapf(angle - _centre, -PI, PI)) <= deg_to_rad(arc_degrees) * 0.5


func _tangent(angle: float) -> Vector3:
	return Vector3(cos(angle), 0.0, -sin(angle))


func _angle_of(v: Vector3) -> float:
	return atan2(v.x, v.z)


func _dir(angle: float) -> Vector3:
	return Vector3(sin(angle), 0.0, cos(angle))


# --- visuals -----------------------------------------------------------------

func _make_fan(z: Zombie) -> void:
	_drop_visuals()
	_fan_mat = StandardMaterial3D.new()
	_fan_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fan_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fan_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_fan_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fan = MeshInstance3D.new()
	_fan.mesh = _fan_mesh(arc_degrees, inner / reach)
	_fan.material_override = _fan_mat
	_fan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	z.get_parent().add_child(_fan)
	_place_fan(z, 0.0)


func _place_fan(z: Zombie, k: float) -> void:
	if not is_instance_valid(_fan):
		return
	var grown := reach * (0.35 + 0.65 * ease(k, 0.4))
	_fan.global_transform = Transform3D(Basis(Vector3.UP, _centre).scaled(Vector3(grown, 1.0, grown)), z.global_position + Vector3.UP * 0.08)
	var pulse := 0.5 + 0.5 * sin(k * lerpf(10.0, 40.0, k))
	_fan_mat.albedo_color = Color(color.lightened(0.2 * pulse), 0.18 + 0.4 * k)


func _place_ball(z: Zombie, a: float) -> void:
	if _ball == null:
		if _ball_sphere == null:
			_ball_sphere = SphereMesh.new()
			_ball_sphere.radius = BALL_RADIUS
			_ball_sphere.height = BALL_RADIUS * 2.0
			_ball_sphere.radial_segments = 16
			_ball_sphere.rings = 8
			var iron := StandardMaterial3D.new()
			iron.albedo_color = Color(0.2, 0.19, 0.23)
			iron.metallic = 0.6
			iron.roughness = 0.4
			_ball_sphere.material = iron
			_chain_box = BoxMesh.new()
			_chain_box.size = Vector3(0.09, 0.09, 1.0)
			var steel := StandardMaterial3D.new()
			steel.albedo_color = Color(0.62, 0.62, 0.68)
			steel.metallic = 0.7
			steel.roughness = 0.35
			_chain_box.material = steel
		_ball = MeshInstance3D.new()
		_ball.mesh = _ball_sphere
		z.get_parent().add_child(_ball)
		_chain = MeshInstance3D.new()
		_chain.mesh = _chain_box
		_chain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		z.get_parent().add_child(_chain)
	var hand := z.global_position + Vector3.UP * 1.9 * z.data.body_scale * 0.75
	var at := z.global_position + _dir(a) * (reach - 0.6) + Vector3.UP * 1.0
	_ball.global_position = at
	var span := at - hand
	_chain.global_transform = Transform3D(Basis.looking_at(span.normalized(), Vector3.UP).scaled(Vector3(1, 1, span.length())), hand + span * 0.5)
	if randf() < 0.5:
		Fx.impact(z.get_parent(), at + Vector3.DOWN * 0.4, Vector3.UP, color)


func _drop_visuals() -> void:
	for node in [_fan, _ball, _chain]:
		if is_instance_valid(node):
			node.queue_free()
	_fan = null
	_ball = null
	_chain = null
	if is_instance_valid(_model_ball):
		_model_ball.visible = true


## A flat fan (annulus sector) of unit radius on the floor, centred on +Z.
static func _fan_mesh(degrees: float, inner_k: float) -> ArrayMesh:
	var key := Vector2(degrees, inner_k)
	if _fan_meshes.has(key):
		return _fan_meshes[key]
	var verts := PackedVector3Array()
	var half := deg_to_rad(degrees) * 0.5
	for i in SEGMENTS:
		var a0 := -half + 2.0 * half * i / SEGMENTS
		var a1 := -half + 2.0 * half * (i + 1) / SEGMENTS
		var o0 := Vector3(sin(a0), 0.0, cos(a0))
		var o1 := Vector3(sin(a1), 0.0, cos(a1))
		verts.append_array([o0 * inner_k, o0, o1, o0 * inner_k, o1, o1 * inner_k])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_fan_meshes[key] = mesh
	return mesh
