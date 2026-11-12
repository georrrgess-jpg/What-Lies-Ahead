class_name SparkField
extends MultiMeshInstance3D
## The Sparks that fly out of popped zombies: small glowing stars that burst
## up and out, then home to the player and are "picked up". Purely a show:
## the Sparks are banked by the SparkLedger the moment the zombie pops, and
## each star carries the amount it stands for so the HUD counter can tick up
## as it arrives (signal `collected`).
##
## One MultiMesh of camera-facing quads (scripts/economy/spark_pickup.gdshader)
## holds every star and its short trail, so a crowd dying at once costs one
## draw call and no allocations: stars live in packed arrays and free slots
## are reused.

## A star reached the player; it stood for `amount` Sparks.
signal collected(amount: int)

const SHADER := "res://scripts/economy/spark_pickup.gdshader"
const CAPACITY := 72
const MAX_STARS_PER_DROP := 5
## Seconds of free flight before a star turns towards the player.
const BURST_TIME := 0.34
const GRAVITY := 7.0
const HOME_SPEED := 9.0
const HOME_ACCEL := 34.0
const PICKUP_RADIUS := 0.55
## A star that somehow never arrives is collected anyway.
const MAX_AGE := 3.0
const SIZE := 0.23
## Quads per star: the star itself and two fading echoes behind it.
const QUADS := 3
const TRAIL_SECONDS := 0.03
## Drawn after the kill popups (their labels use priority 10).
const RENDER_PRIORITY := 20
## Stars keep at least this size on screen (metres per metre of distance), so
## a far-off kill still visibly pays out.
const MIN_ANGULAR_SIZE := 0.012

## Who the stars fly to.
var target: Player

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _age := PackedFloat32Array()
var _value := PackedInt32Array()
var _size := PackedFloat32Array()
var _live := 0
var _warm := 0.6


func _init() -> void:
	_pos.resize(CAPACITY)
	_vel.resize(CAPACITY)
	_age.resize(CAPACITY)
	_value.resize(CAPACITY)
	_size.resize(CAPACITY)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var material := ShaderMaterial.new()
	material.shader = load(SHADER)
	material.set_shader_parameter("core_color", Wallet.COLOR)
	material.set_shader_parameter("glow_color", Wallet.COLOR_GLOW)
	material.render_priority = RENDER_PRIORITY
	quad.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = CAPACITY * QUADS
	# One hidden star is drawn for the first moments (behind the level's
	# fade-in) so the shader is compiled before the first kill.
	multimesh.visible_instance_count = 1
	multimesh.set_instance_transform(0, Transform3D.IDENTITY)
	multimesh.set_instance_custom_data(0, Color(0.0, 0.0, 0.0, 0.0))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3.ONE * -500.0, Vector3.ONE * 1000.0)
	top_level = true


## Stars still on their way.
func in_flight() -> int:
	return _live


## Bursts `amount` Sparks out of `at` (world space): one star per Spark up to
## MAX_STARS_PER_DROP, bigger stars standing for the rest.
func drop(at: Vector3, amount: int) -> void:
	var stars := clampi(amount, 1, MAX_STARS_PER_DROP)
	var each := amount / stars
	var extra := amount - each * stars
	for i in stars:
		if _live >= CAPACITY:
			# Full: the oldest star is collected early to make room.
			_collect(0)
		var value := each + (1 if i < extra else 0)
		var angle := randf() * TAU
		var out := randf_range(1.2, 2.8)
		_pos[_live] = at + Vector3(cos(angle), 0.0, sin(angle)) * 0.15
		_vel[_live] = Vector3(cos(angle) * out, randf_range(3.2, 5.2), sin(angle) * out)
		_age[_live] = -0.03 * i
		_value[_live] = value
		_size[_live] = SIZE * (1.0 + 0.22 * minf(float(maxi(value, 1) - 1), 4.0))
		_live += 1


func _process(delta: float) -> void:
	if _warm > 0.0:
		_warm -= delta
		if _live == 0:
			if _warm <= 0.0:
				multimesh.visible_instance_count = 0
			return
	if _live == 0:
		return
	var goal := _goal()
	var eye := get_viewport().get_camera_3d()
	var eye_pos := eye.global_position if eye else goal
	var i := 0
	while i < _live:
		_age[i] += delta
		var age := _age[i]
		var p := _pos[i]
		var v := _vel[i]
		if age < BURST_TIME:
			v.y -= GRAVITY * delta
			v *= 1.0 - 1.6 * delta
		else:
			var to_goal := goal - p
			var distance := to_goal.length()
			if distance <= PICKUP_RADIUS or age >= MAX_AGE:
				_collect(i)
				continue
			var speed := HOME_SPEED + HOME_ACCEL * (age - BURST_TIME)
			v = v.lerp(to_goal / distance * speed, minf(1.0, 9.0 * delta))
			# Never overshoot the player.
			if speed * delta >= distance:
				_collect(i)
				continue
		p += v * delta
		_pos[i] = p
		_vel[i] = v
		var grow := clampf((age + 0.06) / 0.12, 0.0, 1.0)
		var size := maxf(_size[i], p.distance_to(eye_pos) * MIN_ANGULAR_SIZE) * grow
		var spin := age * 5.0 + float(i)
		var back := v * TRAIL_SECONDS
		var quad := i * QUADS
		multimesh.set_instance_transform(quad, Transform3D(Basis.IDENTITY, p))
		multimesh.set_instance_custom_data(quad, Color(size, spin, 1.0, 0.0))
		multimesh.set_instance_transform(quad + 1, Transform3D(Basis.IDENTITY, p - back))
		multimesh.set_instance_custom_data(quad + 1, Color(size * 0.72, spin, 0.5, 0.0))
		multimesh.set_instance_transform(quad + 2, Transform3D(Basis.IDENTITY, p - back * 2.0))
		multimesh.set_instance_custom_data(quad + 2, Color(size * 0.5, spin, 0.28, 0.0))
		i += 1
	multimesh.visible_instance_count = _live * QUADS


## Where stars fly to: the player's chest, a little in front of the camera.
func _goal() -> Vector3:
	if not is_instance_valid(target):
		return global_position
	var cam := target.camera
	if cam == null:
		return target.global_position + Vector3.UP
	return cam.global_position - cam.global_transform.basis.y * 0.42 - cam.global_transform.basis.z * 0.25


## Hands star `index` to the player and frees its slot (the last live star
## moves into it).
func _collect(index: int) -> void:
	var value := _value[index]
	_live -= 1
	if index != _live:
		_pos[index] = _pos[_live]
		_vel[index] = _vel[_live]
		_age[index] = _age[_live]
		_value[index] = _value[_live]
		_size[index] = _size[_live]
	collected.emit(value)
