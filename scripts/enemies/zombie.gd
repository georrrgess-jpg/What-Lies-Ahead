class_name Zombie
extends CharacterBody3D
## Shared behaviour for every zombie variant. EnemyData supplies the stats,
## outfit and sounds; the RunDirector spawns and tracks instances.
##
## Zombies steer along the navmesh toward the player and use RVO avoidance to
## slip past each other. They do not physically collide with one another, so a
## crowd can never plug a lane.

signal died(zombie: Zombie, weapon_id: StringName)
## Emitted when the zombie has made no progress for a while (or left the map).
signal stalled(zombie: Zombie)

enum State { CHASE, WINDUP, RECOVER, DEAD }

const MODEL_PATH := "res://art/models/zombie.glb"
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

static var _flash_material: StandardMaterial3D

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var shape: CollisionShape3D = $CollisionShape3D
@onready var model_root: Node3D = $Model


## Call before adding the zombie to the tree.
func setup(enemy: EnemyData, chase_target: Player, speed_scale := 1.0) -> void:
	data = enemy
	target = chase_target
	health = enemy.max_health
	speed = enemy.move_speed * speed_scale * (1.0 + randf_range(-enemy.speed_variance, enemy.speed_variance))


func _ready() -> void:
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
	_voice_timer = randf_range(0.5, data.voice_interval.y)
	_stall_anchor = global_position
	_build_model()
	_play(data.move_animation, 0.0)
	# Pop in rather than appearing fully formed.
	model_root.scale = Vector3.ONE * 0.6
	_punch_tween = create_tween()
	_punch_tween.tween_property(model_root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## True while winding up an attack that has not landed yet (for threat indicators).
func is_winding_up() -> bool:
	return (state == State.WINDUP and not _struck) or _charge_telegraph > 0.0


## True while rushing at the player (or about to).
func is_charging() -> bool:
	return _charge_left > 0.0 or _charge_telegraph > 0.0


func is_dead() -> bool:
	return state == State.DEAD


func is_head_hit(world_position: Vector3) -> bool:
	return world_position.y - global_position.y >= data.head_height * data.body_scale


## Applies damage. Returns true if this hit was the finishing blow.
## `push` is a knockback impulse in m/s along `direction`.
func take_hit(amount: float, hit_position: Vector3, direction: Vector3, weapon_id: StringName, headshot: bool, push := 0.0) -> bool:
	if state == State.DEAD:
		return false
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
		_die(weapon_id, hit_position)
		return true
	# A heavy hit knocks a zombie out of its windup: the swipe never lands.
	if state == State.WINDUP and _knock.length() >= STAGGER_PUSH and not _struck:
		_set_state(State.RECOVER)
		_play_hit_reaction()
	elif state == State.CHASE and (_knock.length() >= STAGGER_PUSH or randf() < 0.4):
		_play_hit_reaction()
	return false


func _play_hit_reaction() -> void:
	if _anim and _anim.has_animation("Hit"):
		_anim.speed_scale = 1.0
		_anim.play("Hit", 0.04)
		_anim.queue(_anim_name(data.move_animation))


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
	if state == State.DEAD:
		# Slide back with the killing blow while the death clip plays.
		if _knock.length() > 0.05:
			velocity.x = _knock.x
			velocity.z = _knock.z
			_apply_gravity_and_move()
		return
	if not is_instance_valid(target):
		return

	_slow = maxf(0.0, _slow - delta)
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()

	match state:
		State.CHASE:
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
				if target.alive and distance <= data.attack_reach and facing >= 0.3:
					target.take_damage(data.damage, global_position)
				_set_state(State.RECOVER)
		State.RECOVER:
			_idle_move(delta)
			if _state_time >= data.attack_recover:
				_set_state(State.CHASE)
				_play(data.move_animation, 0.15)

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
		nav.target_position = target.global_position
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
	var move_speed := speed * (0.45 if _slow > 0.0 else 1.0)
	if _charge_left > 0.0:
		move_speed = speed * data.charge_speed_mult
	# Stop at arm's length instead of walking into (and shoving) the player.
	# Knockback is added after avoidance (in _on_velocity_computed), because the
	# avoidance agent clamps its output to max_speed and would swallow it.
	var desired := dir * move_speed if distance > 1.15 else Vector3.ZERO
	_face(dir, delta, 1.0)
	if nav.avoidance_enabled:
		nav.velocity = desired
	else:
		_on_velocity_computed(desired)
	if _anim:
		_anim.speed_scale = clampf(move_speed / maxf(0.1, data.animation_reference_speed), 0.5, 1.8)


## Charging enemies (the Bruiser): at mid range with a clear line, stop, roar
## and face the player (telegraph), then rush for a short burst. Returns true
## while the telegraph holds the zombie in place.
func _update_charge(delta: float, to_target: Vector3, distance: float) -> bool:
	if data.charge_speed_mult <= 1.0:
		return false
	_charge_cooldown -= delta
	if _charge_left > 0.0:
		_charge_left -= delta
		if _charge_left <= 0.0:
			_play(data.move_animation, 0.2)
		return false
	if _charge_telegraph > 0.0:
		_charge_telegraph -= delta
		_face(to_target, delta, 1.5)
		_idle_move(delta)
		if _charge_telegraph <= 0.0:
			_charge_left = data.charge_duration
			_play(&"Run", 0.1)
		return true
	if _charge_cooldown <= 0.0 and distance >= data.charge_range.x and distance <= data.charge_range.y and _clear_line:
		_charge_cooldown = data.charge_cooldown
		_charge_telegraph = data.charge_telegraph
		velocity = Vector3.ZERO
		Sfx.play_at(&"bruiser_roar_1", global_position + Vector3.UP * 1.6, 3.0, 0.9)
		if _anim and _anim.has_animation("Hit"):
			_anim.play("Hit", 0.1)
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
	if state != State.CHASE:
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
	move_and_slide()


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
	if _anim and _anim.has_animation("Attack"):
		var clip := _anim.get_animation("Attack")
		_anim.speed_scale = (clip.length * ATTACK_STRIKE_FRACTION) / maxf(0.05, data.attack_windup)
		_anim.play("Attack", 0.1)
	Sfx.play_at(&"zombie_windup", global_position + Vector3.UP, -3.0, data.voice_pitch)


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0


func _die(weapon_id: StringName, hit_position := Vector3.ZERO) -> void:
	_set_state(State.DEAD)
	collision_layer = 0
	collision_mask = 1
	nav.avoidance_enabled = false
	velocity = Vector3.ZERO
	_knock = _knock.limit_length(KNOCK_MAX) * 1.4 + _knock.normalized() * 1.5
	died.emit(self, weapon_id)
	var chest := global_position + Vector3.UP * 1.1 * data.body_scale
	Fx.kill_burst(get_parent(), hit_position if hit_position != Vector3.ZERO else chest)
	Fx.ticket_popup(get_parent(), chest + Vector3.UP * 0.9, data.tickets)
	Sfx.play_at(&"zombie_pop", global_position + Vector3.UP, -1.0, randf_range(0.9, 1.1) * data.voice_pitch)
	if _anim and _anim.has_animation("Die"):
		_anim.speed_scale = 1.15
		_anim.play("Die", 0.04)
	var tw := create_tween()
	tw.tween_interval(0.55)
	tw.tween_callback(func(): Fx.confetti(get_parent(), global_position + Vector3.UP * 0.5))
	tw.tween_property(model_root, "scale", Vector3(1.25, 0.15, 1.25), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


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


## Called by the director after it relocates a stalled zombie.
func reset_stall() -> void:
	_stall_timer = 0.0
	_lost_timer = 0.0
	_stall_anchor = global_position
	_repath = 0.0
	velocity = Vector3.ZERO


# --- visuals ------------------------------------------------------------------

func _build_model() -> void:
	model_root.scale = Vector3.ONE
	if ResourceLoader.exists(MODEL_PATH):
		_model = (load(MODEL_PATH) as PackedScene).instantiate()
		model_root.add_child(_model)
		_model.scale = Vector3.ONE * data.body_scale
		_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
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
		if not data.shirt_colors.is_empty():
			_tint("Shirt", data.shirt_colors[randi() % data.shirt_colors.size()])
		if not data.skin_colors.is_empty():
			var skin: Color = data.skin_colors[randi() % data.skin_colors.size()]
			_tint("Skin", skin)
			_tint("SkinDark", skin.darkened(0.3))
	else:
		_build_placeholder()


func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_meshes.append(node)
	for child in node.get_children():
		_collect_meshes(child)


func _tint(material_name: String, color: Color) -> void:
	for mi in _meshes:
		if not mi.visible or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if base and String(base.resource_name) == material_name:
				var m: StandardMaterial3D = base.duplicate()
				m.albedo_color = color
				mi.set_surface_override_material(i, m)


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


func _anim_name(base: StringName) -> StringName:
	if _anim == null:
		return base
	if _anim.has_animation(base):
		return base
	return StringName(String(base) + "-loop") if _anim.has_animation(String(base) + "-loop") else base


func _play(animation: StringName, blend: float) -> void:
	if _anim == null:
		return
	var clip := _anim_name(animation)
	if _anim.has_animation(clip):
		_anim.play(clip, blend)
		if blend <= 0.0:
			_anim.seek(randf() * _anim.get_animation(clip).length, true)


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
