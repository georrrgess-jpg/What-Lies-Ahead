extends WeaponMode
## Dunk Tank: every zombie the jet touches is soaked (Soak: slower, and it
## takes more damage from every weapon for a few seconds), and the jet is
## drawn as one stream of water (WaterStream). Pierce, falloff and the push
## are plain WeaponData. The tank, pump and pressure needle on the viewmodel
## move in scripts/weapons/views/dunk_tank_view.gd.

const TRAIT := "SOAKS"

var _stream: WaterStream


func shape_hits(hits: Dictionary, from: Vector3, end: Vector3, _power: float) -> void:
	for key in hits:
		var z: Zombie = hits[key]["zombie"]
		if is_instance_valid(z) and not z.is_dead():
			Soak.of(z).soak()
	if not is_instance_valid(_stream):
		var level := controller.player.get_parent()
		if level == null:
			return
		_stream = WaterStream.new()
		_stream.view = controller.player.view
		level.add_child(_stream)
	_stream.spray(from, end, not hits.is_empty())


func dispose() -> void:
	if is_instance_valid(_stream):
		_stream.queue_free()
