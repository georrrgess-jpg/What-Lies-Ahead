class_name PopcornButter
extends Node3D
## The Popcorn Popper's butter on one zombie, added as a child the first time
## a hot burst splashes it (PopcornButter.of(zombie)). A buttered zombie
## shines gold, drips and slips: it walks SLOW slower (heavies resist: the
## slow shrinks with sqrt(mass)) for BUTTER_TIME after the last splash.
## tools/balance_report.py reads these constants.

const NODE_NAME := "PopcornButter"
const BUTTER_TIME := 1.6
## Chase speed multiplier on a 1-mass zombie while buttered.
const SLOW := 0.72
const DRIP := [Color(1.0, 0.86, 0.3), Color(1.0, 0.95, 0.6), Color(1.0, 0.7, 0.18)]
const SHEEN_SHADER := "res://art/shaders/weapon_frost.gdshader"

var zombie: Zombie
var _left := 0.0
var _drip := 0.0
var _meshes: Array[MeshInstance3D] = []

static var _sheen: ShaderMaterial


## The butter on `z`, created on first use.
static func of(z: Zombie) -> PopcornButter:
	var existing := z.get_node_or_null(NODE_NAME) as PopcornButter
	if existing:
		return existing
	var b := PopcornButter.new()
	b.name = NODE_NAME
	b.zombie = z
	z.add_child(b)
	return b


func _ready() -> void:
	# Keeps dripping while a frozen zombie's own processing is off.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for mi in zombie.model_root.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).visible:
			_meshes.append(mi)
	zombie.died.connect(func(_z: Zombie, _w: StringName) -> void: _clear())
	set_physics_process(false)


func is_buttered() -> bool:
	return _left > 0.0


## A hot burst splashed it: buttered (again) for BUTTER_TIME.
func butter() -> void:
	if zombie.is_dead():
		return
	if not is_buttered():
		_drip = 0.0
		set_physics_process(true)
	_set_sheen(true)
	_left = BUTTER_TIME


func _physics_process(delta: float) -> void:
	if zombie == null or zombie.is_dead():
		_clear()
		return
	_left -= delta
	if _left <= 0.0:
		_clear()
		return
	zombie.speed_multiplier *= lerpf(1.0, SLOW, 1.0 / sqrt(maxf(1.0, zombie.data.mass)))
	_drip -= delta
	if _drip <= 0.0:
		_drip = 0.14
		_set_sheen(true)
		var s := zombie.data.body_scale
		var at := zombie.global_position + Vector3(randf_range(-0.28, 0.28) * s, randf_range(0.5, 1.7) * s, randf_range(-0.28, 0.28) * s)
		WeaponFx.burst(zombie.get_parent(), at, Vector3.DOWN, DRIP, 2, 0.5, 0.4, 0.03, 25.0, Vector3(0, -9.0, 0))


func _clear() -> void:
	_left = 0.0
	set_physics_process(false)
	_set_sheen(false)


## A buttery sheen over the zombie (the frost overlay shader, light and
## tinted gold), put back after hit flashes, unless another status already
## shows its own overlay.
func _set_sheen(on: bool) -> void:
	if _sheen == null:
		_sheen = ShaderMaterial.new()
		_sheen.shader = load(SHEEN_SHADER)
		_sheen.set_shader_parameter("amount", 0.38)
		_sheen.set_shader_parameter("ice_color", Color(1.0, 0.72, 0.12))
		_sheen.set_shader_parameter("rim_color", Color(1.0, 0.95, 0.55))
	for m in _meshes:
		if not is_instance_valid(m):
			continue
		if on and m.material_overlay == null:
			m.material_overlay = _sheen
		elif not on and m.material_overlay == _sheen:
			m.material_overlay = null
