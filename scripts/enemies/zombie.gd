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
var _flash_left := 0.0
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
	nav.max_speed = speed * 1.2
	nav.velocity_computed.connect(_on_velocity_computed)
	_repath = randf() * REPATH_INTERVAL
	_voice_timer = randf_range(0.5, data.voice_interval.y)
	_stall_anchor = global_position
	_build_model()
	_play(data.move_animation, 0.0)
	# Pop in rather than appearing fully formed.
	model_root.scale = Vector3.ONE * 0.6
	create_tween().tween_property(model_root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_dead() -> bool:
	return state == State.DEAD


func is_head_hit(world_position: Vector3) -> bool:
	return world_position.y - global_position.y >= data.head_height * data.body_scale


## Applies damage. Returns true if this hit was the finishing blow.
func take_hit(amount: float, hit_position: Vector3, direction: Vector3, weapon_id: StringName, headshot: bool) -> bool:
	if state == State.DEAD:
		return false
	health -= amount
	last_hit_weapon = weapon_id
	_lost_timer = 0.0
	_slow = 0.3
	_flash(0.09)
	Fx.hit_pop(get_parent(), hit_position, direction, headshot)
	Sfx.play_at(&"hit_head" if headshot else &"hit_body", hit_position, -5.0, randf_range(0.92, 1.1))
	if health <= 0.0:
		_die(weapon_id)
		return true
	if state == State.CHASE and _anim and _anim.has_animation("Hit") and randf() < 0.5:
		_anim.play("Hit", 0.05)
		_anim.queue(_anim_name(data.move_animation))
	return false


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
	if state == State.DEAD:
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
				if target.alive and distance <= data.attack_reach:
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
		_begin_attack()
		return
	_repath -= delta
	if _repath <= 0.0:
		_repath = REPATH_INTERVAL
		nav.target_position = target.global_position
	var dir := to_target.normalized()
	# Close in directly for the last few metres; otherwise follow the navmesh.
	if distance > 3.0 and not nav.is_navigation_finished():
		var next := nav.get_next_path_position()
		var step := next - global_position
		step.y = 0.0
		if step.length() > 0.05:
			dir = step.normalized()
	var move_speed := speed * (0.45 if _slow > 0.0 else 1.0)
	var desired := dir * move_speed
	_face(dir, delta, 1.0)
	if nav.avoidance_enabled:
		nav.velocity = desired
	else:
		_on_velocity_computed(desired)
	if _anim:
		_anim.speed_scale = clampf(move_speed / maxf(0.1, data.animation_reference_speed), 0.5, 1.8)


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if state != State.CHASE:
		return
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	_apply_gravity_and_move()


func _idle_move(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 0.5)
	velocity.z = move_toward(velocity.z, 0.0, 0.5)
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


func _die(weapon_id: StringName) -> void:
	_set_state(State.DEAD)
	collision_layer = 0
	collision_mask = 1
	nav.avoidance_enabled = false
	velocity = Vector3.ZERO
	died.emit(self, weapon_id)
	Sfx.play_at(&"zombie_pop", global_position + Vector3.UP, -1.0, randf_range(0.9, 1.1) * data.voice_pitch)
	if _anim and _anim.has_animation("Die"):
		_anim.speed_scale = 1.0
		_anim.play("Die", 0.05)
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_callback(func(): Fx.confetti(get_parent(), global_position + Vector3.UP * 0.6))
	tw.tween_property(model_root, "scale", Vector3.ONE * 0.05, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
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
		# One rig, two outfits: keep only the meshes for this variant.
		for mi in _meshes:
			var mesh_name := String(mi.name)
			if mesh_name.begins_with("Outfit_"):
				mi.visible = mesh_name == "Outfit_" + String(data.outfit)
		if not data.shirt_colors.is_empty():
			_tint("Shirt", data.shirt_colors[randi() % data.shirt_colors.size()])
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
		_flash_material = StandardMaterial3D.new()
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_material.albedo_color = Color(1, 1, 1, 0.6)
	_flash_material.albedo_color.a = lerpf(0.2, 0.6, Settings.flash_scale())
	_flash_left = duration
	_set_overlay(_flash_material)


func _set_overlay(material: Material) -> void:
	for mi in _meshes:
		if is_instance_valid(mi):
			mi.material_overlay = material
