extends WeaponMode
## Gumball Drum Popper: every shot is a bouncy gumball (RicochetRound) aimed
## from the muzzle at the point under the crosshair, so it lands where the
## player aims. On the viewmodel the drum turns one chamber per shot and the
## fore-pump kicks back (the support hand rides it).

## Chambers per turn of the drum.
const CHAMBERS := 8
## How fast the shown drum catches up with the next chamber (1/s).
const TURN_RATE := 26.0
## Pump kick per shot (metres, toward the player) and how fast it returns (1/s).
const PUMP_KICK := 0.016
const PUMP_RETURN := 10.0

var _shots := 0
var _angle := 0.0
var _pump := 0.0
var _model_id := 0
var _rotor: Array = []
var _pump_part: Array = []


func launch(from: Vector3, dir: Vector3, scale: float) -> bool:
	var eye := controller.player.aim_transform().origin
	var query := PhysicsRayQueryParameters3D.create(eye, eye + dir * data.max_range, WeaponController.MASK_WORLD | WeaponController.MASK_ENEMIES)
	query.exclude = [controller.player.get_rid()]
	var hit := controller.player.get_world_3d().direct_space_state.intersect_ray(query)
	var aim_at: Vector3 = hit["position"] if not hit.is_empty() else eye + dir * data.max_range
	var to := aim_at - from
	RicochetRound.launch(controller, from, to.normalized() if to.length() > 0.5 else dir, data, scale)
	_shots += 1
	_pump = 1.0
	return true


func animate(model: Node3D, delta: float) -> void:
	if model.get_instance_id() != _model_id:
		_model_id = model.get_instance_id()
		_rotor = find_part(model, "Drum")
		_pump_part = find_part(model, "Pump")
	if controller.is_reloading():
		# The reload swaps in a fresh drum and leaves both parts at rest.
		_shots = 0
		_angle = 0.0
		_pump = 0.0
		return
	_angle = lerpf(_angle, _shots * TAU / CHAMBERS, 1.0 - exp(-TURN_RATE * delta))
	_pump = maxf(0.0, _pump - PUMP_RETURN * delta)
	if not _rotor.is_empty():
		var rest: Transform3D = _rotor[1]
		_rotor[0].transform = Transform3D(rest.basis * Basis(Vector3.RIGHT, -_angle), rest.origin)
	if not _pump_part.is_empty():
		var rest: Transform3D = _pump_part[1]
		var k := sin(_pump * PI) * PUMP_KICK
		_pump_part[0].transform = Transform3D(rest.basis, rest.origin + Vector3(0.0, 0.0, k))
