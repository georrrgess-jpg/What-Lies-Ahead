class_name Soak
extends Node3D
## The Dunk Tank's "soak" on one zombie, added as a child the first time it
## is hit (Soak.of(zombie)). A soaked zombie drips and squelches, walks
## SLOW slower (heavies resist: the slow shrinks with sqrt(mass)) and takes
## DAMAGE_BONUS more damage from every hit, whatever weapon it comes from
## (through the DamageStack, so armour still sees the hit first). The soak lasts SOAK_TIME after the last hit,
## then dries off. tools/balance_report.py reads these constants.

const NODE_NAME := "Soak"
const SOAK_TIME := 3.0
## Chase speed multiplier on a 1-mass zombie while soaked.
const SLOW := 0.72
## Damage multiplier of every hit a soaked zombie takes.
const DAMAGE_BONUS := 1.25
const DRIP := [Color(0.55, 0.85, 1.0), Color(0.85, 0.97, 1.0), Color(0.3, 0.65, 1.0)]
const WET_SHADER := "res://art/shaders/weapon_frost.gdshader"

var zombie: Zombie
var _left := 0.0
var _drip := 0.0
var _meshes: Array[MeshInstance3D] = []

static var _sheen: ShaderMaterial


## The soak on `z`, created on first use.
static func of(z: Zombie) -> Soak:
	var existing := z.get_node_or_null(NODE_NAME) as Soak
	if existing:
		return existing
	var s := Soak.new()
	s.name = NODE_NAME
	s.zombie = z
	z.add_child(s)
	return s


## Damage multiplier for hits that bypass take_hit's filters (burns, whirls).
static func damage_scale(z: Zombie) -> float:
	var s := z.get_node_or_null(NODE_NAME) as Soak
	return DAMAGE_BONUS if s and s.is_wet() else 1.0


func _ready() -> void:
	# Drips on while a frozen zombie's own processing is off.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for mi in zombie.model_root.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).visible:
			_meshes.append(mi)
	zombie.died.connect(func(_z: Zombie, _w: StringName) -> void: _dry())
	set_physics_process(false)


func is_wet() -> bool:
	return _left > 0.0


## A hit from the hose: soaked (again) for SOAK_TIME.
func soak() -> void:
	if zombie.is_dead():
		return
	if not is_wet():
		DamageStack.ensure(zombie)
		_drip = 0.0
		_set_sheen(true)
		set_physics_process(true)
	_left = SOAK_TIME


func _physics_process(delta: float) -> void:
	if zombie == null or zombie.is_dead():
		_dry()
		return
	_left -= delta
	if _left <= 0.0:
		_dry()
		return
	var mass := maxf(1.0, zombie.data.mass)
	zombie.speed_multiplier *= lerpf(1.0, SLOW, 1.0 / sqrt(mass))
	_drip -= delta
	if _drip <= 0.0:
		_drip = 0.09
		_set_sheen(true)
		var s := zombie.data.body_scale
		var at := zombie.global_position + Vector3(randf_range(-0.3, 0.3) * s, randf_range(0.3, 1.7) * s, randf_range(-0.3, 0.3) * s)
		WeaponFx.burst(zombie.get_parent(), at, Vector3.DOWN, DRIP, 2, 0.6, 0.45, 0.035, 25.0, Vector3(0, -9.0, 0))


func _dry() -> void:
	_left = 0.0
	set_physics_process(false)
	_set_sheen(false)


## A wet sheen over the zombie (the frost overlay shader, light and tinted
## toward water), put back after hit flashes, unless another status already
## shows its own overlay.
func _set_sheen(on: bool) -> void:
	if _sheen == null:
		_sheen = ShaderMaterial.new()
		_sheen.shader = load(WET_SHADER)
		_sheen.set_shader_parameter("amount", 0.42)
		_sheen.set_shader_parameter("ice_color", Color(0.22, 0.55, 1.0))
		_sheen.set_shader_parameter("rim_color", Color(0.7, 0.92, 1.0))
	for m in _meshes:
		if not is_instance_valid(m):
			continue
		if on and m.material_overlay == null:
			m.material_overlay = _sheen
		elif not on and m.material_overlay == _sheen:
			m.material_overlay = null
