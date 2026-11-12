class_name BoostGlow
extends Node
## Hot rim glow on the held weapon while the station's damage boost is loaded
## (dim, waiting for the next wave) or running (bright and pulsing). The
## viewmodel is rebuilt on every weapon switch, so the glow follows the model.

const SHADER := "res://art/shaders/boost_rim.gdshader"
const READY_STRENGTH := 0.35

var player: Player
## 0 = off, READY_STRENGTH = loaded, 1 = running.
var strength := 0.0

var _material: ShaderMaterial
var _model: Node3D
var _time := 0.0


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER)


## Follows the run's damage boost state.
func set_boost(boost: RunDirector.Boost) -> void:
	match boost:
		RunDirector.Boost.ACTIVE:
			strength = 1.0
		RunDirector.Boost.READY:
			strength = READY_STRENGTH
		_:
			strength = 0.0


func _process(delta: float) -> void:
	if player == null or player.view == null:
		return
	var model := player.view.model if strength > 0.0 else null
	if model != _model:
		if is_instance_valid(_model):
			_apply(_model, null)
		_model = model
		if _model:
			_apply(_model, _material)
	if _model == null:
		return
	_time += delta
	var pulse := 0.8 + 0.2 * sin(_time * 7.0) if strength >= 1.0 else 1.0
	_material.set_shader_parameter("strength", strength * pulse)
	_material.set_shader_parameter("time_scroll", _time)


## Sets (or clears) the overlay on the weapon's meshes; the arms stay as they are.
func _apply(node: Node, material: Material) -> void:
	if String(node.name).begins_with("Arm"):
		return
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if material != null or mi.material_overlay == _material:
			mi.material_overlay = material
	for child in node.get_children():
		_apply(child, material)
