class_name Zombie
extends CharacterBody3D
## Shared behaviour for every zombie variant. EnemyData supplies the stats,
## outfit and sounds; the RunDirector spawns and tracks instances.
##
## Zombies steer along the navmesh toward the player and use RVO avoidance to
## slip past each other. They do not physically collide with one another, so a
## crowd can never plug a lane.
##
## Animation: the gait plays at the rate that matches how fast the zombie
## really moves (each clip's ground speed comes from the model's clip table,
## written by art/blender/zombie_anim.py), switching between Idle, Walk and
## Run; light hits are an additive layer (ZombieHitReact), heavy ones play
## Stagger; deaths pick a variant from the killing blow.

signal died(zombie: Zombie, weapon_id: StringName)

## Set when the finishing blow lands; read by the score keeper.
var killed_by_headshot := false
var kill_distance := 0.0
## Emitted when the zombie has made no progress for a while (or left the map).
signal stalled(zombie: Zombie)

enum State { CHASE, WINDUP, RECOVER, DEAD, EMERGE }

const MODEL_PATH := "res://art/models/zombie.glb"
## The material of every opaque zombie surface (tinted per zombie, see _apply_tints).
const BODY_MATERIAL: ShaderMaterial = preload("res://art/materials/zombie_body.tres")
const GRAVITY := 22.0
const REPATH_INTERVAL := 0.3
const STALL_WINDOW := 5.0
const STALL_DISTANCE := 0.7
## A zombie that stays this far from the player, untouched, for LOST_SECONDS is
## treated as lost and handed back to the director.
const LOST_DISTANCE := 16.0
const LOST_SECONDS := 75.0
## Fraction of the Attack clip at which the swipe lands.
const ATTACK_STRIKE_FRACTION := 0.55
## Knockback this strong (m/s, summed over a volley) staggers a zombie out of its windup.
const STAGGER_PUSH := 3.2
const KNOCK_MAX := 7.0
## Below this ground speed (m/s) a zombie stands in its Idle; it starts
## walking again above IDLE_EXIT.
const IDLE_ENTER := 0.25
const IDLE_EXIT := 0.45
## Blend time (s) between locomotion clips.
const GAIT_BLEND := 0.25
## A gait clip plays between these rates; outside them the other gait fits better.
const GAIT_RATE_MIN := 0.35
const GAIT_RATE_MAX := 2.2
## Seconds a corpse stays down after its death clip before it pops.
const CORPSE_HOLD := 0.3
## Extra reach (m) around the head volume for a hit to count.
const HEAD_SLOP := 0.03
## Per-instance size variety (fractions): overall scale and extra width.
const SIZE_JITTER := 0.06
const GIRTH_JITTER := 0.03

var data: EnemyData
var target: Player
var health := 100.0
var speed := 1.8
var state: State = State.CHASE
var last_hit_weapon: StringName

var _state_time := 0.0
var _repath := 0.0
var _voice_timer := 3.0
var _slow := 0.0
var _struck := false
var _stall_anchor := Vector3.ZERO
var _stall_timer := 0.0
var _lost_timer := 0.0
var _clear_line := false
## Flanking: each zombie approaches from its own side (radians, relative to
## the line from the player to the zombie), so groups spread around the
## player instead of queueing single file. Chosen once at spawn.
var _flank := 0.0
## Seconds of "enraged" speed boost left (after a nearby ally dies).
var _enrage := 0.0
## Charge (Bruiser): cooldown, telegraph time left, and charge time left.
var _charge_cooldown := 2.5
var _charge_telegraph := 0.0
var _charge_left := 0.0
var _flash_left := 0.0
## Knockback velocity from hits; decays quickly.
var _knock := Vector3.ZERO
var _punch_tween: Tween
var _meshes: Array[MeshInstance3D] = []
var _anim: AnimationPlayer
var _model: Node3D

# --- animation state ---
## Clip table of this model: clip name -> {length, speed, strike, impact, pop...}.
var _clips: Dictionary = {}
## Per-zombie playback tempo for idles, staggers and deaths (crowd variety).
var _tempo := 1.0
## Resolved names of this enemy's idle, move and run clips.
var _idle_clip: StringName
var _move_clip: StringName
var _run_clip: StringName
## The locomotion clip this script is driving ("" while another clip plays).
var _loco_clip: StringName
## Smoothed real horizontal speed (m/s).
var _ground_speed := 0.0
var _stagger_left := 0.0
var _emerge_pending := false
var _hit_react: ZombieHitReact

# --- head hitbox ---
var _skeleton: Skeleton3D
var _head_bone := -1
## Head volume in head-bone space: a capsule from _head_a to _head_b.
var _head_a := Vector3.ZERO
var _head_b := Vector3.ZERO
var _head_radius := 0.0
var _head_shape: CollisionShape3D
var _guard: MeshInstance3D
var _guard_bone := -1
## Top edge of the guard in its bone's space.
var _guard_top := Vector3.ZERO

static var _flash_material: StandardMaterial3D
## Clip tables by model path, and head/guard bounds by mesh, shared by all zombies.
static var _clip_tables := {}
static var _bounds_cache := {}

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var shape: CollisionShape3D = $CollisionShape3D
@onready var model_root: Node3D = $Model


## Call before adding the zombie to the tree.
func setup(enemy: EnemyData, chase_target: Player, speed_scale := 1.0) -> void:
	data = enemy
	behaviours.clear()
	for b in enemy.behaviours:
		if b:
			behaviours.append(b.duplicate(true))
	target = chase_target
	health = enemy.max_health
	speed = enemy.move_speed * speed_scale * (1.0 + randf_range(-enemy.speed_variance, enemy.speed_variance))


## True for the invisible-to-gameplay copy drawn once at level start so its
## materials compile early (see FxWarmup). It never joins the "zombies" group.
var warmup_only := false
## This zombie's own copies of its EnemyData.behaviours.
var behaviours: Array[EnemyBehaviour] = []
## Multiplies chase speed this frame (behaviours set it; reset every frame).
var speed_multiplier := 1.0


func _ready() -> void:
	if warmup_only:
		collision_layer = 0
		collision_mask = 0
		nav.avoidance_enabled = false
	else:
		add_to_group("zombies")
	if data == null:
		data = EnemyData.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = data.capsule_radius * data.body_scale
	capsule.height = data.capsule_height * data.body_scale
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	nav.radius = data.avoidance_radius
	nav.max_speed = speed * maxf(1.2, data.charge_speed_mult * 1.1)
	nav.velocity_computed.connect(_on_velocity_computed)
	_repath = randf() * REPATH_INTERVAL
	_flank = randf_range(-1.0, 1.0) * deg_to_rad(data.flank_degrees)
	_voice_timer = randf_range(0.5, data.voice_interval.y)
	_stall_anchor = global_position
	_tempo = randf_range(0.92, 1.08)
	_build_model()
	_setup_animation()
	_setup_head()
	_play_locomotion(0.0)
	# Spawns climb in (Emerge) once the first physics tick confirms this is a
	# live zombie (dev tools that pose a zombie set its speed to 0 first).
	_emerge_pending = not warmup_only and _has_clip(&"Emerge")
	if _emerge_pending:
		model_root.visible = false
	if not warmup_only:
		for b in behaviours:
			b.on_ready(self)


## True while winding up an attack that has not landed yet (for threat indicators).
func is_winding_up() -> bool:
	if (state == State.WINDUP and not _struck) or _charge_telegraph > 0.0:
		return true
	# Behaviours with their own telegraphs (ranged windups etc.) count too.
	for b in behaviours:
		if b.has_method("is_winding_up") and b.is_winding_up():
			return true
	return false


## True while rushing at the player (or about to).
func is_charging() -> bool:
	return _charge_left > 0.0 or _charge_telegraph > 0.0


func is_dead() -> bool:
	return state == State.DEAD


## True if a shot that struck this zombie at `world_position` hit its head.
## The head is a capsule that follows the Head bone (crouches, tucks, lunges)
## sized from the head mesh. A shot that struck the body capsule first counts
## if its line, followed into the body, passes through the head. The shot
## comes from `from` when given, else from the player's view. A visible guard
## (the riot shield) blocks frontal shots entering the head below its top edge.
func is_head_hit(world_position: Vector3, from := Vector3.INF) -> bool:
	if _head_bone < 0 or _skeleton == null:
		return world_position.y - global_position.y >= data.head_height * data.body_scale
	var head := _skeleton.global_transform * _skeleton.get_bone_global_pose(_head_bone)
	var a := head * _head_a
	var b := head * _head_b
	var r := _head_radius * _skeleton.global_basis.get_scale().y
	if from == Vector3.INF:
		from = world_position + _radial(world_position)
		if is_instance_valid(target) and target.camera:
			from = target.camera.global_position
	var dir := (world_position - from).normalized()
	var entry := world_position
	if Geometry3D.get_closest_point_to_segment(world_position, a, b).distance_to(world_position) > r + HEAD_SLOP:
		var depth := 2.2 * data.capsule_radius * data.body_scale
		var pair := Geometry3D.get_closest_points_between_segments(world_position, world_position + dir * depth, a, b)
		if pair[0].distance_to(pair[1]) > r + HEAD_SLOP:
			return false
		entry = pair[0]
	return not _guarded(entry, dir)


## Applies damage. Returns true if this hit was the finishing blow.
## `push` is a knockback impulse in m/s along `direction`.
## `head_part` >= 0 marks a blast that hit both head and body: that much of
## `amount` hit the head (at `hit_position`) and the rest the body (at
## `body_position`), and behaviours such as armour see each part separately.
func take_hit(amount: float, hit_position: Vector3, direction: Vector3, weapon_id: StringName, headshot: bool, push := 0.0, head_part := -1.0, body_position := Vector3.ZERO) -> bool:
	if state == State.DEAD:
		return false
	if head_part >= 0.0:
		amount = _filter_hit(amount - head_part, body_position, false) + _filter_hit(head_part, hit_position, true)
	else:
		amount = _filter_hit(amount, hit_position, headshot)
	health -= amount
	last_hit_weapon = weapon_id
	_lost_timer = 0.0
	_slow = 0.3
	var flat := Vector3(direction.x, 0.0, direction.z).normalized()
	_knock = (_knock + flat * push / maxf(0.2, data.mass)).limit_length(KNOCK_MAX)
	_flash(0.07)
	_punch(0.12 if headshot else 0.08)
	Fx.hit_pop(get_parent(), hit_position, direction, headshot)
	Sfx.play_at(&"hit_head" if headshot else &"hit_body", hit_position, -5.0, randf_range(0.92, 1.1))
	if health <= 0.0:
		killed_by_headshot = headshot
		if is_instance_valid(target):
			kill_distance = target.global_position.distance_to(global_position)
		_die(weapon_id, hit_position, direction)
		return true
	_react(amount, hit_position, direction, headshot)
	# A heavy hit knocks a zombie out of its windup: the swipe never lands.
	if _knock.length() >= STAGGER_PUSH:
		if is_winding_up():
			interrupt()
		elif state == State.CHASE and _stagger_left <= 0.0:
			_stagger()
	return false


## Runs a hit through the behaviours (armour, shields...) and returns the
## damage actually taken.
func _filter_hit(amount: float, at: Vector3, head: bool) -> float:
	for b in behaviours:
		amount = b.on_hit(self, amount, at, head)
	return amount


## Knocks the zombie out of any windup that has not landed yet (its melee
## swipe, its charge roar and its behaviours' telegraphed attacks) and
## staggers it.
func interrupt() -> void:
	if state == State.DEAD or state == State.EMERGE:
		return
	if state == State.WINDUP and not _struck:
		_set_state(State.RECOVER)
	if _charge_telegraph > 0.0:
		_charge_telegraph = 0.0
	for b in behaviours:
		b.interrupt(self)
	_stagger()


## Plays the Stagger clip; a staggering zombie stops chasing until it ends.
func _stagger() -> void:
	var clip := &"Stagger_Heavy" if data.heavy and _has_clip(&"Stagger_Heavy") else &"Stagger"
	if not _has_clip(clip):
		return
	_play(clip, 0.06, _tempo)
	_stagger_left = _clip_length(clip) / _tempo
	if state == State.CHASE:
		velocity.x = 0.0
		velocity.z = 0.0


## Light-hit flinch on the additive layer, scaled by the share of health lost.
func _react(amount: float, at: Vector3, direction: Vector3, headshot: bool) -> void:
	if _hit_react == null:
		return
	var to_local := global_transform.affine_inverse()
	var point := to_local * at
	var dir := to_local.basis * direction
	var strength := amount / maxf(1.0, data.max_health) * 3.0 / sqrt(maxf(0.5, data.mass))
	_hit_react.kick(point / maxf(0.1, data.body_scale), dir, headshot, strength)


## Used by the director to remove a hopelessly stuck zombie without rewards.
func despawn() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	queue_free()


func _physics_process(delta: float) -> void:
	_state_time += delta
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_set_overlay(null)
	_knock = _knock.move_toward(Vector3.ZERO, 11.0 * delta)
	if _emerge_pending:
		_emerge_pending = false
		model_root.visible = true
		if speed > 0.0:
			_begin_emerge()
	if state == State.DEAD:
		# Slide back with the killing blow while the death clip plays.
		if _knock.length() > 0.05:
			velocity.x = _knock.x
			velocity.z = _knock.z
			_apply_gravity_and_move()
		return
	if _head_shape:
		_head_shape.transform = global_transform.affine_inverse() * _head_world()
	if not is_instance_valid(target):
		return
	if state == State.EMERGE:
		_idle_move(delta)
		if _state_time >= _clip_length(&"Emerge") / _tempo:
			_set_state(State.CHASE)
			_play_locomotion(0.15)
		return
	var skip := false
	for b in behaviours:
		if b.on_physics(self, delta):
			skip = true
	if skip:
		_voice(delta)
		return

	_slow = maxf(0.0, _slow - delta)
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()

	match state:
		State.CHASE:
			if _stagger_left > 0.0:
				_stagger_left -= delta
				_idle_move(delta)
				if _stagger_left <= 0.0:
					_play_locomotion(0.2)
			else:
				_chase(delta, to_target, distance)
		State.WINDUP:
			_face(to_target, delta, 0.6)
			_idle_move(delta)
			if not _struck and _state_time >= data.attack_windup:
				_struck = true
				Sfx.play_at(data.attack_sound, global_position + Vector3.UP, -2.0, data.voice_pitch)
				# The swipe lunges forward and only connects in front of the zombie,
				# so circling behind a windup is a real dodge.
				var forward := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
				# Lunge to close the gap, but never far enough to shove the player.
				_knock += forward * data.lunge_speed * clampf((distance - 1.1) / 1.2, 0.0, 1.0)
				var facing := forward.dot(to_target.normalized()) if distance > 0.01 else 1.0
				var landed := target.alive and distance <= data.attack_reach and facing >= 0.3
				if landed:
					target.take_damage(data.damage, global_position)
				for b in behaviours:
					b.on_attack(self, landed)
				_set_state(State.RECOVER)
		State.RECOVER:
			_idle_move(delta)
			if _state_time >= data.attack_recover:
				_set_state(State.CHASE)
				_stagger_left = 0.0
				_play_locomotion(0.2)

	_drive_locomotion(delta)
	_voice(delta)
	_check_stall(delta, distance)


func _chase(delta: float, to_target: Vector3, distance: float) -> void:
	if target.alive and distance <= data.attack_range:
		_charge_left = 0.0
		_begin_attack()
		return
	if _update_charge(delta, to_target, distance):
		return
	_repath -= delta
	if _repath <= 0.0:
		_repath = REPATH_INTERVAL
		nav.target_position = _approach_point(distance)
		_clear_line = (distance <= 3.5 or data.charge_speed_mult > 1.0) and _has_clear_line()
	var dir := to_target.normalized()
	# Close in directly for the last few metres when nothing is in the way;
	# otherwise follow the navmesh (e.g. around a planter).
	if (distance > 3.0 or not _clear_line) and not nav.is_navigation_finished():
		var next := nav.get_next_path_position()
		var step := next - global_position
		step.y = 0.0
		if step.length() > 0.05:
			dir = step.normalized()
	# A hit makes a zombie flinch to 45% speed; above mass 1.5 less so (not at all at 4).
	var move_speed := speed * (lerpf(1.0, 0.45, clampf(1.6 - 0.4 * data.mass, 0.0, 1.0)) if _slow > 0.0 else 1.0)
	if _enrage > 0.0:
		_enrage -= delta
		move_speed *= 1.18
	move_speed *= speed_multiplier
	speed_multiplier = 1.0
	if _charge_left > 0.0:
		move_speed = speed * data.charge_speed_mult
	# Bounding gaits move slowly while the feet are planted, fast in the air.
	move_speed *= _gait_profile()
	# Stop at arm's length instead of walking into (and shoving) the player.
	# Knockback is added after avoidance (in _on_velocity_computed), because the
	# avoidance agent clamps its output to max_speed and would swallow it.
	var desired := dir * move_speed if distance > 1.15 else Vector3.ZERO
	_face(dir, delta, 1.0)
	if nav.avoidance_enabled:
		nav.velocity = desired
	else:
		_on_velocity_computed(desired)


## Where to path to: far away, a point beside the player on this zombie's
## flank side; closer in, straight at the player.
func _approach_point(distance: float) -> Vector3:
	var p := target.global_position
	if distance < 6.0 or absf(_flank) < 0.01:
		return p
	var away := global_position - p
	away.y = 0.0
	away = away.normalized().rotated(Vector3.UP, _flank)
	var radius := clampf((distance - 6.0) * 0.5, 0.0, 4.5)
	return p + away * radius


## A nearby ally just died: speed up and roar for a few seconds.
func enrage(seconds: float) -> void:
	if state == State.DEAD or warmup_only:
		return
	var was := _enrage > 0.0
	_enrage = maxf(_enrage, seconds)
	if not was:
		_voice_timer = 0.0
		_flash(0.06)


## Charging enemies (the Bruiser): at mid range with a clear line, stop, roar
## and face the player (telegraph), then rush for a short burst. Returns true
## while the telegraph holds the zombie in place.
func _update_charge(delta: float, to_target: Vector3, distance: float) -> bool:
	if data.charge_speed_mult <= 1.0:
		return false
	_charge_cooldown -= delta
	if _charge_left > 0.0:
		_charge_left -= delta
		return false
	if _charge_telegraph > 0.0:
		_charge_telegraph -= delta
		_face(to_target, delta, 1.5)
		_idle_move(delta)
		if _charge_telegraph <= 0.0:
			_charge_left = data.charge_duration
			_play_locomotion(0.1)
		return true
	if _charge_cooldown <= 0.0 and distance >= data.charge_range.x and distance <= data.charge_range.y and _clear_line:
		_charge_cooldown = data.charge_cooldown
		_charge_telegraph = data.charge_telegraph
		velocity = Vector3.ZERO
		Sfx.play_at(&"bruiser_roar_1", global_position + Vector3.UP * 1.6, 3.0, 0.9)
		_play(&"Roar", 0.1, _clip_length(&"Roar") / maxf(0.1, data.charge_telegraph))
		return true
	return false


## True if nothing solid stands between this zombie and its target at knee height.
func _has_clear_line() -> bool:
	var from := global_position + Vector3.UP * 0.5
	var to := target.global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if state != State.CHASE or _stagger_left > 0.0:
		return
	velocity.x = safe_velocity.x + _knock.x
	velocity.z = safe_velocity.z + _knock.z
	_apply_gravity_and_move()


func _idle_move(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 0.5) if _knock.length() < 0.05 else _knock.x
	velocity.z = move_toward(velocity.z, 0.0, 0.5) if _knock.length() < 0.05 else _knock.z
	_apply_gravity_and_move()


func _apply_gravity_and_move() -> void:
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * get_physics_process_delta_time()
	# The head volume is for shots only: it must not snag on doorways and
	# overhangs the body capsule fits under.
	if _head_shape:
		_head_shape.disabled = true
	move_and_slide()
	if _head_shape:
		_head_shape.disabled = false


func _face(direction: Vector3, delta: float, rate: float) -> void:
	if direction.length() < 0.01:
		return
	var want := atan2(direction.x, direction.z)   # model front is +Z
	rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-data.turn_speed * rate * delta))


func _begin_attack() -> void:
	_set_state(State.WINDUP)
	_struck = false
	velocity.x = 0.0
	velocity.z = 0.0
	var clip := _anim_name(&"Attack")
	if _has_clip(clip):
		var info := _clip_info(clip)
		var strike := float(info.get("strike", _clip_length(clip) * ATTACK_STRIKE_FRACTION))
		_play(clip, 0.1, strike / maxf(0.05, data.attack_windup))
	Sfx.play_at(&"zombie_windup", global_position + Vector3.UP, -3.0, data.voice_pitch)


func _begin_emerge() -> void:
	_set_state(State.EMERGE)
	_play(&"Emerge", 0.0, _tempo)


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0


func _die(weapon_id: StringName, hit_position := Vector3.ZERO, direction := Vector3.ZERO) -> void:
	_set_state(State.DEAD)
	collision_layer = 0
	collision_mask = 1
	nav.avoidance_enabled = false
	velocity = Vector3.ZERO
	_knock = _knock.limit_length(KNOCK_MAX) * 1.4 + _knock.normalized() * 1.5
	for b in behaviours:
		b.on_death(self)
	died.emit(self, weapon_id)
	var chest := global_position + Vector3.UP * 1.1 * data.body_scale
	Fx.kill_effect(get_parent(), hit_position if hit_position != Vector3.ZERO else chest)
	Sfx.play_at(&"zombie_pop", global_position + Vector3.UP, -1.0, randf_range(0.9, 1.1) * data.voice_pitch)
	var clip := _death_clip(direction)
	var events: Array = []
	var end := 0.55
	if clip != &"":
		_play(clip, 0.06, _tempo)
		var info := _clip_info(clip)
		if info.has("pop"):
			events.append([float(info["pop"]) / _tempo, _pop_head])
		if info.has("thud"):
			events.append([float(info["thud"]) / _tempo, _land.bind(0.5)])
		if info.has("impact"):
			events.append([float(info["impact"]) / _tempo, _land.bind(1.0)])
		end = _clip_length(clip) / _tempo + CORPSE_HOLD
	events.sort_custom(func(x, y): return x[0] < y[0])
	var tw := create_tween()
	var t := 0.0
	for e in events:
		tw.tween_interval(maxf(0.0, e[0] - t))
		tw.tween_callback(e[1])
		t = e[0]
	tw.tween_interval(maxf(0.0, end - t))
	tw.tween_callback(func(): Fx.confetti(get_parent(), global_position + Vector3.UP * 0.4))
	tw.tween_property(model_root, "scale", Vector3(1.25, 0.15, 1.25), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


## The death variant for a killing blow travelling along `direction`: the
## head pop for headshots, Die_Heavy for big enemies, otherwise by where the
## shot came from (front: mostly falls back, behind: faceplants, side: spins).
func _death_clip(direction: Vector3) -> StringName:
	if killed_by_headshot and _has_clip(&"Die_HeadPop"):
		return &"Die_HeadPop"
	if data.heavy and _has_clip(&"Die_Heavy"):
		return &"Die_Heavy"
	var flat := Vector3(direction.x, 0.0, direction.z)
	var from_front := 1.0
	if flat.length() > 0.01:
		from_front = -flat.normalized().dot(global_basis.z.normalized())
	var pick := &"Die_Back"
	if from_front < -0.4:
		pick = &"Die_Front"
	elif from_front < 0.4:
		pick = &"Die_Spin"
	else:
		var roll := randf()
		pick = &"Die_Back" if roll < 0.55 else (&"Die_Spin" if roll < 0.78 else &"Die_Front")
	if _has_clip(pick):
		return pick
	return &"Die_Back" if _has_clip(&"Die_Back") else (&"Die" if _has_clip(&"Die") else &"")


## The body hits the ground: a squash and a puff of dust.
func _land(weight: float) -> void:
	var k := 0.16 * weight
	model_root.scale = Vector3(1.0 + k, 1.0 - k * 1.2, 1.0 + k)
	var tw := create_tween()
	tw.tween_property(model_root, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.impact(get_parent(), global_position + Vector3.UP * 0.1, Vector3.UP, Color(0.92, 0.86, 0.74))


## Headshot kill: the swollen head bursts into confetti.
func _pop_head() -> void:
	var at := global_position + Vector3.UP * 1.6 * data.body_scale
	if _skeleton and _head_bone >= 0:
		at = _head_world() * ((_head_a + _head_b) * 0.5)
	Fx.confetti(get_parent(), at)
	Fx.kill_burst(get_parent(), at)
	Sfx.play_at(&"zombie_pop", at, 0.0, 1.35 * data.voice_pitch)


func _voice(delta: float) -> void:
	_voice_timer -= delta
	if _voice_timer > 0.0 or data.voice_sounds.is_empty():
		return
	_voice_timer = randf_range(data.voice_interval.x, data.voice_interval.y)
	var sound: StringName = data.voice_sounds[randi() % data.voice_sounds.size()]
	Sfx.play_at(sound, global_position + Vector3.UP * 1.4, 0.0, data.voice_pitch * randf_range(0.92, 1.08), 11.0)


func _check_stall(delta: float, distance: float) -> void:
	if global_position.y < -8.0:
		stalled.emit(self)
		return
	_lost_timer = 0.0 if distance < LOST_DISTANCE else _lost_timer + delta
	if _lost_timer > LOST_SECONDS:
		_lost_timer = 0.0
		stalled.emit(self)
		return
	_stall_timer += delta
	if _stall_timer < STALL_WINDOW:
		return
	_stall_timer = 0.0
	var moved := global_position.distance_to(_stall_anchor)
	_stall_anchor = global_position
	if state == State.CHASE and moved < STALL_DISTANCE and distance > data.attack_reach + 1.0:
		stalled.emit(self)


## Called by the director after it relocates a stalled zombie: it climbs in
## again from the entrance.
func reset_stall() -> void:
	_stall_timer = 0.0
	_lost_timer = 0.0
	_stall_anchor = global_position
	_repath = 0.0
	velocity = Vector3.ZERO
	if state == State.CHASE and speed > 0.0 and _has_clip(&"Emerge"):
		_begin_emerge()


# --- locomotion ------------------------------------------------------------------

func _setup_animation() -> void:
	if _anim == null:
		return
	var path := String(data.model_scene.resource_path) if data.model_scene else MODEL_PATH
	_clips = _clip_table(path)
	_idle_clip = _anim_name(&"Idle")
	_move_clip = _anim_name(data.move_animation)
	_run_clip = _anim_name(&"Run")
	if _skeleton:
		_hit_react = ZombieHitReact.new()
		_skeleton.add_child(_hit_react)
		_hit_react.setup(_skeleton)


## The clip table written next to a model by zombie_anim.py (cached).
static func _clip_table(model_path: String) -> Dictionary:
	if _clip_tables.has(model_path):
		return _clip_tables[model_path]
	var table := {}
	var path := model_path.get_basename() + "_clips.tres"
	if ResourceLoader.exists(path):
		var res := load(path)
		if res and res.has_meta(&"clips"):
			table = res.get_meta(&"clips")
	_clip_tables[model_path] = table
	return table


## Keeps the gait in step with how fast the zombie really moves: Idle when it
## stands still (blocked, or waiting at arm's length), otherwise the walk or
## run clip whose ground speed fits, played at the rate that keeps the planted
## feet from sliding.
func _drive_locomotion(delta: float) -> void:
	if _anim == null or speed <= 0.0 or state != State.CHASE or _stagger_left > 0.0:
		return
	if _loco_clip == &"" or _anim.current_animation != String(_loco_clip):
		return
	var v := get_real_velocity() - _knock
	var actual := Vector2(v.x, v.z).length()
	# A bounding gait moves at its base speed times its profile: undo the
	# profile so the rate follows the base speed.
	actual /= maxf(0.3, _gait_profile())
	_ground_speed = lerpf(_ground_speed, actual, 1.0 - exp(-10.0 * delta))
	var want := _gait_for(_ground_speed)
	if want != _loco_clip:
		_switch_loco(want, GAIT_BLEND)
	var ref := _clip_speed(_loco_clip)
	_anim.speed_scale = clampf(_ground_speed / ref, GAIT_RATE_MIN, GAIT_RATE_MAX) if ref > 0.0 else _tempo


## The locomotion clip for a ground speed (with hysteresis around Idle and
## between the move clip and the other gait).
func _gait_for(ground_speed: float) -> StringName:
	if _charge_left > 0.0 and _has_clip(_run_clip):
		return _run_clip
	var idle := _loco_clip == _idle_clip
	if _has_clip(_idle_clip) and ground_speed < (IDLE_EXIT if idle else IDLE_ENTER):
		return _idle_clip
	var other := _run_clip if _move_clip != _run_clip else _anim_name(&"Walk")
	if other == _move_clip or not _has_clip(other) or _clip_speed(other) <= 0.0 or _clip_speed(_move_clip) <= 0.0:
		return _move_clip
	var current := _loco_clip if _loco_clip == other else _move_clip
	var alt := other if current == _move_clip else _move_clip
	var fit_now := absf(log(maxf(0.05, ground_speed) / _clip_speed(current)))
	var fit_alt := absf(log(maxf(0.05, ground_speed) / _clip_speed(alt)))
	return alt if fit_alt + 0.25 < fit_now else current


## Starts the move clip (the run while charging); _drive_locomotion then
## settles on whichever gait fits the zombie's real speed.
func _play_locomotion(blend: float) -> void:
	if _anim == null:
		return
	_loco_clip = &""
	_switch_loco(_run_clip if _charge_left > 0.0 and _has_clip(_run_clip) else _move_clip, blend)


func _switch_loco(clip: StringName, blend: float) -> void:
	if not _has_clip(clip):
		return
	var phase := -1.0
	if _loco_clip != &"" and _clip_speed(_loco_clip) > 0.0 and _clip_speed(clip) > 0.0:
		phase = _anim.current_animation_position / maxf(0.01, _anim.current_animation_length)
	_anim.play(clip, blend)
	var length := _anim.get_animation(clip).length
	# Keep the feet in step between gaits; otherwise start anywhere in the
	# cycle so crowds don't march in sync.
	_anim.seek(phase * length if phase >= 0.0 else randf() * length, true)
	_anim.speed_scale = _tempo
	_loco_clip = clip


## Speed factor of a bounding gait at its current phase (1 for other gaits).
func _gait_profile() -> float:
	if _anim == null or _loco_clip == &"" or _anim.current_animation != String(_loco_clip):
		return 1.0
	var profile = _clip_info(_loco_clip).get("profile")
	if profile == null or profile.is_empty():
		return 1.0
	var f := _anim.current_animation_position / maxf(0.01, _anim.current_animation_length)
	return float(profile[int(f * profile.size()) % profile.size()])


## Ground speed (m/s) of a gait clip at 1x for this zombie's size (0 if none).
func _clip_speed(clip: StringName) -> float:
	var info := _clip_info(clip)
	var size := _model.scale.z if _model else data.body_scale
	if info.has("speed"):
		return float(info["speed"]) * size
	if clip == _move_clip:
		return data.animation_reference_speed
	return 0.0


func _clip_info(clip: StringName) -> Dictionary:
	return _clips.get(String(clip), {})


func _clip_length(clip: StringName) -> float:
	var resolved := _anim_name(clip)
	if _anim and _anim.has_animation(resolved):
		return _anim.get_animation(resolved).length
	return 0.0


func _has_clip(clip: StringName) -> bool:
	return _anim != null and _anim.has_animation(_anim_name(clip))


# --- head hitbox -----------------------------------------------------------------

## Builds the head volume from the head mesh (outfit and face; head accessories
## only raise its top) and a collision shape that follows the Head
## bone, so a head that leans or ducks out of the body capsule can still be hit.
func _setup_head() -> void:
	if _skeleton == null:
		return
	_head_bone = _skeleton.find_bone("Head")
	if _head_bone < 0:
		return
	var box := AABB()
	var top := -INF
	var has_box := false
	for mi in _meshes:
		if not mi.visible or mi.skin == null or mi.mesh == null:
			continue
		var b := _bone_bounds(mi, _head_bone)
		if b.size == Vector3.ZERO:
			continue
		# The body and its face make the head; accessories (hats, hair) only
		# raise its top.
		if String(mi.name).begins_with("Outfit_") or String(mi.name).begins_with("Face_"):
			box = b if not has_box else box.merge(b)
			has_box = true
		else:
			top = maxf(top, b.end.y)
	if not has_box:
		_head_bone = -1
		return
	if top > box.end.y:
		box.size.y = top - box.position.y
	# A capsule a touch wider than the head box and reaching a little past its
	# top and bottom, so the rounded corners (ears, brows) still count.
	var r := 0.5 * maxf(box.size.x, box.size.z) * data.head_hit_scale
	var c := box.get_center()
	var half := maxf(0.0, box.size.y * 0.5 * data.head_hit_scale - 0.9 * r)
	# Rest skeleton space -> head bone space.
	var to_bone := _skeleton.get_bone_global_rest(_head_bone).affine_inverse()
	_head_a = to_bone * (c - Vector3.UP * half)
	_head_b = to_bone * (c + Vector3.UP * half)
	_head_radius = r
	if not warmup_only:
		var capsule := CapsuleShape3D.new()
		var s := _skeleton.global_basis.get_scale().y
		capsule.radius = r * s
		capsule.height = (2.0 * half + 2.0 * r) * s
		_head_shape = CollisionShape3D.new()
		_head_shape.name = "HeadShape"
		_head_shape.shape = capsule
		add_child(_head_shape)
		_head_shape.transform = global_transform.affine_inverse() * _head_world()
	_setup_guard()


## World transform of the head volume (centre at the capsule's middle, axis Y).
func _head_world() -> Transform3D:
	var head := _skeleton.global_transform * _skeleton.get_bone_global_pose(_head_bone)
	var a := head * _head_a
	var b := head * _head_b
	var up := (b - a).normalized() if a.distance_to(b) > 0.001 else head.basis.y.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	return Transform3D(Basis(side, up, side.cross(up)).orthonormalized(), (a + b) * 0.5)


func _setup_guard() -> void:
	if data.head_guard_mesh == "":
		return
	for mi in _meshes:
		if String(mi.name) == data.head_guard_mesh and mi.skin and mi.mesh:
			var bone := _skeleton.find_bone("Spine")
			var b := _bone_bounds(mi, bone)
			if b.size == Vector3.ZERO:
				return
			_guard = mi
			_guard_bone = bone
			_guard_top = _skeleton.get_bone_global_rest(bone).affine_inverse() * Vector3(b.get_center().x, b.end.y, b.end.z)
			return


## True if a visible guard covers `entry` from a shot travelling along `dir`.
func _guarded(entry: Vector3, dir: Vector3) -> bool:
	if _guard == null or not _guard.visible or _guard_bone < 0:
		return false
	var forward := global_basis.z.normalized()
	if forward.dot(-dir) < 0.25:
		return false
	var top := _skeleton.global_transform * _skeleton.get_bone_global_pose(_guard_bone) * _guard_top
	return entry.y < top.y


## Bounds (rest skeleton space) of the vertices of `mi` skinned to `bone`.
static func _bone_bounds(mi: MeshInstance3D, bone: int) -> AABB:
	var binds := mi.skin
	var skeleton := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	var bind := -1
	for i in binds.get_bind_count():
		var b := binds.get_bind_bone(i)
		if b < 0 and skeleton:
			b = skeleton.find_bone(binds.get_bind_name(i))
		if b == bone:
			bind = i
			break
	if bind < 0:
		return AABB()
	var key := "%d:%d" % [mi.mesh.get_instance_id(), bind]
	if _bounds_cache.has(key):
		return _bounds_cache[key]
	var to_rest := binds.get_bind_pose(bind)
	if skeleton:
		to_rest = skeleton.get_bone_global_rest(bone) * to_rest
	var box := AABB()
	var first := true
	for s in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null or verts.is_empty():
			continue
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var stride := bones.size() / verts.size()
		for v in verts.size():
			if bones[v * stride] != bind or weights[v * stride] < 0.5:
				continue
			var p := to_rest * verts[v]
			if first:
				box = AABB(p, Vector3.ZERO)
				first = false
			else:
				box = box.expand(p)
	_bounds_cache[key] = box
	return box


## A step outward from the body axis through `p` (for shots of unknown origin).
func _radial(p: Vector3) -> Vector3:
	var out := p - global_position
	out.y = 0.0
	return out.normalized() if out.length() > 0.01 else global_basis.z


# --- visuals ------------------------------------------------------------------

func _build_model() -> void:
	model_root.scale = Vector3.ONE
	data = data.for_world(_world_id())
	var model_scene: PackedScene = data.model_scene
	if model_scene == null and ResourceLoader.exists(MODEL_PATH):
		model_scene = load(MODEL_PATH)
	if model_scene:
		_model = model_scene.instantiate()
		model_root.add_child(_model)
		_model.scale = Vector3.ONE * data.body_scale
		_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var skeletons := _model.find_children("*", "Skeleton3D", true, false)
		_skeleton = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
		_collect_meshes(_model)
		# One rig, several outfits: keep only this variant's body, then roll
		# one option per accessory slot (e.g. cap / bucket hat / curly hair).
		var chosen := {}
		for slot in data.accessory_slots:
			var options := String(slot).split("|")
			for mesh_name in options[randi() % options.size()].split("+"):
				if mesh_name != "":
					chosen[mesh_name] = true
		for mi in _meshes:
			var mesh_name := String(mi.name)
			if mesh_name.begins_with("Outfit_"):
				mi.visible = mesh_name == "Outfit_" + String(data.outfit)
			elif mesh_name.begins_with("Acc_"):
				mi.visible = chosen.has(mesh_name)
		_vary_look()
		_apply_tints()
	else:
		_build_placeholder()


## The current level's world, for EnemyData.world_outfits (none in the menus).
static func _world_id() -> StringName:
	var level: LevelData = Game.level
	return level.world.id if level and level.world else &""


## Per-instance variety: shows one of the outfit's faces (meshes named
## Face_<outfit>_<preset>) and jitters the body size, so a crowd never looks cloned.
func _vary_look() -> void:
	var prefix := "Face_" + String(data.outfit) + "_"
	var faces: Array[MeshInstance3D] = []
	for mi in _meshes:
		var mesh_name := String(mi.name)
		if mesh_name.begins_with("Face_"):
			mi.visible = false
			if mesh_name.begins_with(prefix):
				faces.append(mi)
	if not faces.is_empty():
		faces[randi() % faces.size()].visible = true
	var girth := randf_range(1.0 - GIRTH_JITTER, 1.0 + GIRTH_JITTER)
	_model.scale = Vector3(girth, 1.0, girth) * data.body_scale * randf_range(1.0 - SIZE_JITTER, 1.0 + SIZE_JITTER)


## A slightly different shade of the chosen skin colour for every zombie.
func _vary_skin(skin: Color) -> Color:
	return Color.from_hsv(wrapf(skin.h + randf_range(-0.025, 0.025), 0.0, 1.0), clampf(skin.s * randf_range(0.88, 1.08), 0.0, 1.0),
			clampf(skin.v * randf_range(0.92, 1.06), 0.0, 1.0))


func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_meshes.append(node)
	for child in node.get_children():
		_collect_meshes(child)


## Every opaque part of a zombie mesh shares one material whose colours live in
## the vertices (art/shaders/zombie_body.gdshader). A zombie with shirt or skin
## colours gets its own copy with those tints, shared by all its meshes.
func _apply_tints() -> void:
	if data.shirt_colors.is_empty() and data.skin_colors.is_empty():
		return
	var look: ShaderMaterial = BODY_MATERIAL.duplicate()
	if not data.shirt_colors.is_empty():
		look.set_shader_parameter(&"shirt_tint", data.shirt_colors[randi() % data.shirt_colors.size()])
	if not data.skin_colors.is_empty():
		var skin: Color = _vary_skin(data.skin_colors[randi() % data.skin_colors.size()])
		look.set_shader_parameter(&"skin_tint", skin)
		look.set_shader_parameter(&"skin_dark_tint", skin.darkened(0.3))
	for mi in _meshes:
		if not mi.visible or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_material(i) == BODY_MATERIAL:
				mi.set_surface_override_material(i, look)


func _build_placeholder() -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = data.capsule_radius * data.body_scale
	capsule.height = data.capsule_height * data.body_scale
	body.mesh = capsule
	body.position.y = capsule.height * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.8, 0.35) if data.outfit == &"Tourist" else Color(0.9, 0.3, 0.3)
	body.material_override = mat
	model_root.add_child(body)
	_meshes.append(body)


## The model's name for a clip: the enemy's style variant first (Walk_Heavy),
## then the base clip, each with or without the "-loop" suffix.
func _anim_name(base: StringName) -> StringName:
	if _anim == null:
		return base
	var names: Array[String] = []
	if data.clip_style != &"":
		names.append(String(base) + "_" + String(data.clip_style))
	names.append(String(base))
	for n in names:
		if _anim.has_animation(n):
			return StringName(n)
		if _anim.has_animation(n + "-loop"):
			return StringName(n + "-loop")
	return base


## Plays a one-off clip (behaviour moves, attacks, deaths) at `rate`.
func _play(animation: StringName, blend: float, rate := 1.0) -> void:
	if _anim == null:
		return
	var clip := _anim_name(animation)
	if _anim.has_animation(clip):
		_loco_clip = &""
		_anim.play(clip, blend)
		_anim.speed_scale = rate


func _flash(duration: float) -> void:
	if _flash_material == null:
		# Additive pink-white tint: the zombie brightens but keeps its colours.
		_flash_material = StandardMaterial3D.new()
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flash_material.albedo_color = Color(0.6, 0.38, 0.5)
	var k := lerpf(0.35, 1.0, Settings.flash_scale())
	_flash_material.albedo_color = Color(0.6, 0.38, 0.5) * k
	_flash_left = duration
	_set_overlay(_flash_material)


# --- public helpers for EnemyBehaviour components ---------------------------

func distance_to_target() -> float:
	return global_position.distance_to(target.global_position) if is_instance_valid(target) else INF


func has_line_of_sight() -> bool:
	if not is_instance_valid(target):
		return false
	var from := global_position + Vector3.UP * 1.4 * data.body_scale
	var to := target.global_position + Vector3.UP * 1.2
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func face_toward(direction: Vector3, delta: float) -> void:
	_face(direction, delta, 1.0)


## Plays a clip for a behaviour. Asking for the enemy's move animation hands
## the legs back to the locomotion driver (Idle, Walk or Run as fits).
func play_animation(clip: StringName, blend := 0.1) -> void:
	if clip == data.move_animation:
		_play_locomotion(blend)
	else:
		_play(clip, blend)


func knockback(impulse: Vector3) -> void:
	_knock = (_knock + impulse).limit_length(KNOCK_MAX)


## Moves with gravity using the given horizontal velocity (for behaviours
## that take over movement).
func move_with(horizontal: Vector3) -> void:
	velocity.x = horizontal.x + _knock.x
	velocity.z = horizontal.z + _knock.z
	_apply_gravity_and_move()


## Shows the hit tint immediately (used by the warm-up pass).
func flash_now() -> void:
	_flash(1.0)


## Quick squash-and-stretch so every hit visibly lands.
func _punch(amount: float) -> void:
	if state == State.DEAD:
		return
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	model_root.scale = Vector3(1.0 + amount, 1.0 - amount, 1.0 + amount)
	_punch_tween = create_tween()
	_punch_tween.tween_property(model_root, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_overlay(material: Material) -> void:
	for mi in _meshes:
		if is_instance_valid(mi):
			mi.material_overlay = material
