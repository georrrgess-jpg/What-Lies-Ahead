class_name StatusEffects
extends Node3D
## Weapon status effects on one zombie, added as a child the first time a
## status lands (StatusEffects.of(zombie)). Kept on the weapon side so
## enemies need no changes:
##
##   chill   builds up per hit and slows the zombie (down to CHILL_MIN_SPEED);
##           at 1.0 it freezes solid: no movement, animation or attacks for the
##           weapon's status_duration. Frozen zombies take extra damage, and a
##           kill while frozen shatters them into shards that hurt neighbours.
##   shock   a short jolt that slows the zombie for a moment.
##
## Slows go through Zombie.speed_multiplier (set every frame). Freezing
## disables the zombie's processing; this node keeps running (PAUSABLE) to
## thaw it again.

const NODE_NAME := "WeaponStatus"
const CHILL_MIN_SPEED := 0.3
const CHILL_DECAY := 0.45
const CHILL_HOLD := 0.5
const SHOCK_SPEED := 0.55
const SHATTER_RADIUS := 2.6
const FROST_SHADER := "res://art/shaders/weapon_frost.gdshader"

var zombie: Zombie
var chill := 0.0
var frozen_left := 0.0
var shock_left := 0.0
## Damage multiplier while frozen (from the weapon that froze it).
var frozen_damage_scale := 1.0
var shatter_damage := 0.0
var _chill_hold := 0.0
var _weapon_id: StringName
var _meshes: Array[MeshInstance3D] = []
var _overlay: ShaderMaterial
var _crystals: MeshInstance3D
var _sparkle_timer := 0.0

static var _crystal_mesh: ArrayMesh
static var _crystal_material: StandardMaterial3D


## The status node of `z`, created on first use.
static func of(z: Zombie) -> StatusEffects:
	var existing := z.get_node_or_null(NODE_NAME) as StatusEffects
	if existing:
		return existing
	var s := StatusEffects.new()
	s.name = NODE_NAME
	s.zombie = z
	z.add_child(s)
	return s


## Extra damage multiplier for a hit on `z` (frozen zombies take more).
static func damage_scale(z: Zombie) -> float:
	var s := z.get_node_or_null(NODE_NAME) as StatusEffects
	return s.frozen_damage_scale if s and s.is_frozen() else 1.0


func _ready() -> void:
	# Keeps ticking while the frozen zombie's own processing is switched off.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for mi in zombie.model_root.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).visible:
			_meshes.append(mi)
	zombie.died.connect(_on_died)


func is_frozen() -> bool:
	return frozen_left > 0.0


## Applies one weapon hit's status. `amount` is chill build-up (1 = freeze).
func apply(weapon: WeaponData, amount: float) -> void:
	if zombie.is_dead():
		return
	_weapon_id = weapon.id
	match weapon.status_effect:
		&"chill":
			if is_frozen():
				return
			# Heavy zombies resist the cold.
			chill = minf(1.0, chill + amount / sqrt(maxf(0.5, zombie.data.mass)))
			_chill_hold = CHILL_HOLD
			if chill >= 1.0:
				_freeze(weapon)
		&"shock":
			shock_left = maxf(shock_left, weapon.status_duration)
			WeaponFx.shock_crackle(zombie)


func _freeze(weapon: WeaponData) -> void:
	frozen_left = weapon.status_duration
	frozen_damage_scale = weapon.frozen_damage_scale
	shatter_damage = weapon.shatter_damage
	zombie.interrupt()
	zombie.process_mode = Node.PROCESS_MODE_DISABLED
	_show_crystals(true)
	WeaponFx.frost_puff(zombie.get_parent(), zombie.global_position + Vector3.UP * 1.0, 1.6)
	Sfx.play_at(weapon.status_sound, zombie.global_position + Vector3.UP, -2.0, randf_range(0.95, 1.05))


func _thaw() -> void:
	frozen_left = 0.0
	chill = 0.55
	_chill_hold = CHILL_HOLD
	if is_instance_valid(zombie):
		zombie.process_mode = Node.PROCESS_MODE_INHERIT
	_show_crystals(false)
	WeaponFx.frost_puff(zombie.get_parent(), zombie.global_position + Vector3.UP * 1.0, 0.8)


func _physics_process(delta: float) -> void:
	if zombie == null or zombie.is_dead():
		return
	if frozen_left > 0.0:
		frozen_left -= delta
		if frozen_left <= 0.0:
			_thaw()
	else:
		_chill_hold -= delta
		if _chill_hold <= 0.0:
			chill = maxf(0.0, chill - CHILL_DECAY * delta)
	shock_left = maxf(0.0, shock_left - delta)
	var mult := lerpf(1.0, CHILL_MIN_SPEED, chill)
	if shock_left > 0.0:
		mult *= SHOCK_SPEED
	zombie.speed_multiplier *= mult
	_update_visuals(delta)
	if chill <= 0.0 and shock_left <= 0.0 and frozen_left <= 0.0:
		_clear_overlay()


func _update_visuals(delta: float) -> void:
	var frost := 1.0 if is_frozen() else chill * 0.7
	if frost <= 0.01:
		return
	if _overlay == null:
		_overlay = ShaderMaterial.new()
		_overlay.shader = load(FROST_SHADER)
	_overlay.set_shader_parameter("amount", frost)
	for mi in _meshes:
		if not is_instance_valid(mi):
			continue
		# Frozen: always iced over. Chilled: leave the hit flash alone.
		if is_frozen() or mi.material_overlay == null:
			mi.material_overlay = _overlay
	_sparkle_timer -= delta
	if _sparkle_timer <= 0.0 and not is_frozen():
		_sparkle_timer = lerpf(0.5, 0.15, chill)
		WeaponFx.frost_sparkle(zombie.get_parent(), zombie.global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.4, 1.7), randf_range(-0.3, 0.3)))


func _clear_overlay() -> void:
	for mi in _meshes:
		if is_instance_valid(mi) and mi.material_overlay == _overlay:
			mi.material_overlay = null


func _on_died(_z: Zombie, _weapon: StringName) -> void:
	var was_frozen := is_frozen()
	frozen_left = 0.0
	zombie.process_mode = Node.PROCESS_MODE_INHERIT
	_show_crystals(false)
	_clear_overlay()
	if was_frozen:
		_shatter()


## A frozen zombie breaks into ice shards that hurt and chill its neighbours.
func _shatter() -> void:
	var centre := zombie.global_position + Vector3.UP * 1.0
	WeaponFx.shatter(zombie.get_parent(), centre)
	Sfx.play_at(&"weap_cryo_shatter", centre, 0.0, randf_range(0.95, 1.08))
	if shatter_damage <= 0.0:
		return
	var weapon := GameData.weapon(_weapon_id)
	for node in zombie.get_tree().get_nodes_in_group("zombies"):
		var other := node as Zombie
		if other == null or other == zombie or other.is_dead():
			continue
		var d := other.global_position.distance_to(zombie.global_position)
		if d > SHATTER_RADIUS:
			continue
		var dir := (other.global_position - zombie.global_position).normalized()
		other.take_hit(shatter_damage, other.global_position + Vector3.UP, dir, _weapon_id, false, 2.0)
		if weapon and not other.is_dead():
			StatusEffects.of(other).apply(weapon, 0.35)


# --- frozen crystals -----------------------------------------------------------

func _show_crystals(on: bool) -> void:
	if on and _crystals == null:
		_crystals = MeshInstance3D.new()
		_crystals.mesh = _crystal_shell()
		_crystals.material_override = _crystal_mat()
		_crystals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_crystals)
		var s := zombie.data.body_scale
		_crystals.scale = Vector3(s, s, s)
		_crystals.rotation.y = randf() * TAU
	if _crystals:
		_crystals.visible = on
		if on:
			_crystals.scale = Vector3.ONE * zombie.data.body_scale * 0.6
			var tw := _crystals.create_tween()
			tw.tween_property(_crystals, "scale", Vector3.ONE * zombie.data.body_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Chunky ice spikes jutting out around a standing zombie (built once, shared).
static func _crystal_shell() -> ArrayMesh:
	if _crystal_mesh:
		return _crystal_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 13:
		var a := TAU * i / 13.0 + rng.randf_range(-0.2, 0.2)
		var h := rng.randf_range(0.15, 1.75)
		var base := Vector3(cos(a) * 0.32, h, sin(a) * 0.32)
		var dir := Vector3(cos(a), rng.randf_range(-0.2, 0.9), sin(a)).normalized()
		_add_spike(st, base, dir, rng.randf_range(0.28, 0.55), rng.randf_range(0.07, 0.12))
	# A few bigger spikes at the feet so the block reads at a distance.
	for i in 5:
		var a := TAU * i / 5.0 + 0.4
		_add_spike(st, Vector3(cos(a) * 0.3, 0.05, sin(a) * 0.3), Vector3(cos(a) * 0.5, 1.0, sin(a) * 0.5).normalized(), 0.6, 0.13)
	st.generate_normals()
	_crystal_mesh = st.commit()
	return _crystal_mesh


static func _add_spike(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, radius: float) -> void:
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(dir).normalized()
	var tip := base + dir * length
	var ring: Array[Vector3] = []
	for k in 4:
		var ang := TAU * k / 4.0
		ring.append(base + (side * cos(ang) + up * sin(ang)) * radius)
	for k in 4:
		var a := ring[k]
		var b := ring[(k + 1) % 4]
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(tip)
		st.add_vertex(b)
		st.add_vertex(a)
		st.add_vertex(base - dir * radius)


static func _crystal_mat() -> StandardMaterial3D:
	if _crystal_material == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.72, 0.93, 1.0, 0.72)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = Color(0.45, 0.85, 1.0)
		m.emission_energy_multiplier = 0.8
		m.roughness = 0.12
		m.metallic_specular = 0.9
		m.rim_enabled = true
		m.rim = 0.8
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_crystal_material = m
	return _crystal_material
