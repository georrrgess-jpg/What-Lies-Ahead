class_name DuneJetpackHopBehaviour
extends DuneLeapBehaviour
## Ground-crew mechanic: when the player is far, behind cover or up on a
## platform, its jetpack sputters (telegraph), then it boosts over in a high arc
## and lands near the player with a stomp. Flame jets burn under the tanks and
## sparks trail the whole flight.

## Also hop when the player stands at least this much higher (the launch deck).
@export var climb_trigger := 1.2
@export var flame_color := Color(1.0, 0.6, 0.18)

## Nozzle positions on the dune_zombies.glb mechanic (model space, before body_scale).
const NOZZLES := [Vector3(-0.15, 0.7, -0.42), Vector3(0.15, 0.7, -0.42)]
const JET_LENGTH := 0.7

var _flame_t := 0.0
var _jets: Array[Node3D] = []

static var _jet_mesh: CylinderMesh


## Jumps to reach a player on a platform, cuts corners when the view is blocked,
## and closes long gaps.
func _wants_leap(z: Zombie) -> bool:
	var d := z.distance_to_target()
	if d < min_range or d > max_range:
		return false
	var higher := z.target.global_position.y - z.global_position.y > climb_trigger
	return higher or d > max_range * 0.45 or not z.has_line_of_sight()


func _on_windup_tick(z: Zombie, delta: float) -> void:
	# Sputtering: short, uneven bursts.
	_burn(z, randf_range(0.15, 0.6) if randf() < 0.7 else 0.0)
	_sparks(z, delta, 0.12)


func _on_flight_tick(z: Zombie, delta: float, _t: float) -> void:
	_burn(z, randf_range(0.9, 1.25))
	_sparks(z, delta, 0.04)


func _on_landed(z: Zombie) -> void:
	_burn(z, 0.0)


func on_death(z: Zombie) -> void:
	_burn(z, 0.0)


## Shows the two flame jets at `power` (0 hides them).
func _burn(z: Zombie, power: float) -> void:
	if _jets.is_empty():
		if power <= 0.0:
			return
		_build_jets(z)
	for jet in _jets:
		if not is_instance_valid(jet):
			continue
		jet.visible = power > 0.0
		if power > 0.0:
			jet.scale = Vector3(randf_range(0.8, 1.1), power, randf_range(0.8, 1.1)) * z.data.body_scale


func _build_jets(z: Zombie) -> void:
	if _jet_mesh == null:
		_jet_mesh = CylinderMesh.new()
		_jet_mesh.top_radius = 0.1
		_jet_mesh.bottom_radius = 0.0
		_jet_mesh.height = JET_LENGTH
		_jet_mesh.radial_segments = 10
		_jet_mesh.rings = 1
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(1.0, 0.72, 0.3, 0.9)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_jet_mesh.material = m
	for nozzle: Vector3 in NOZZLES:
		# The pivot sits on the nozzle; the cone hangs below it and stretches with power.
		var pivot := Node3D.new()
		pivot.position = nozzle * z.data.body_scale
		z.model_root.add_child(pivot)
		var jet := MeshInstance3D.new()
		jet.mesh = _jet_mesh
		jet.position = Vector3(0, -JET_LENGTH * 0.5, 0)
		jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(jet)
		pivot.visible = false
		_jets.append(pivot)


func _sparks(z: Zombie, delta: float, interval: float) -> void:
	_flame_t -= delta
	if _flame_t > 0.0:
		return
	_flame_t = interval
	var back := -Vector3(sin(z.rotation.y), 0.0, cos(z.rotation.y)) * 0.42 * z.data.body_scale
	for side: float in [-0.15, 0.15]:
		var right := Vector3(cos(z.rotation.y), 0.0, -sin(z.rotation.y)) * side * z.data.body_scale
		var nozzle := z.global_position + back + right + Vector3.UP * 0.4 * z.data.body_scale
		Fx.impact(z.get_parent(), nozzle, Vector3.DOWN, flame_color)
