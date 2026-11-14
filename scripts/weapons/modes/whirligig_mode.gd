extends WeaponMode
## Whirligig: holding fire spins the prize wheel and barrels up, and it only
## fires once they are at speed. Let go and they spin down over SPIN_DOWN, so
## a short pause between bursts costs only part of the spin-up again. A
## spinning Whirligig is heavy: the player slows to FIRING_MOVE. The motor's
## whir rises with the spin; the wheels turn with it in
## scripts/weapons/views/whirligig_view.gd (which reads `spin`).

## Seconds from rest to firing speed, and from full speed back to rest.
const SPIN_UP := 0.4
const SPIN_DOWN := 1.0
## Move speed multiplier at full spin.
const FIRING_MOVE := 0.8
const SPIN_SOUND := &"weap_whirl_spin"
const WINDUP_SOUND := &"weap_whirl_windup"

## 0 at rest, 1 at firing speed.
var spin := 0.0
var _hum: AudioStreamPlayer


func trigger(spinning: bool, delta: float) -> bool:
	if spinning and spin <= 0.0:
		Sfx.play(WINDUP_SOUND, -4.0)
	spin = clampf(spin + (delta / SPIN_UP if spinning else -delta / SPIN_DOWN), 0.0, 1.0)
	_update_hum()
	return spin >= 1.0


func end_trigger() -> void:
	spin = 0.0
	_update_hum()


func move_scale() -> float:
	return lerpf(1.0, FIRING_MOVE, spin)


func dispose() -> void:
	if is_instance_valid(_hum):
		_hum.queue_free()


## The motor's whir follows the spin (pitch and level).
func _update_hum() -> void:
	if spin <= 0.0:
		if is_instance_valid(_hum) and _hum.playing:
			_hum.stop()
		return
	if not is_instance_valid(_hum):
		var stream := Sfx.stream(SPIN_SOUND)
		if stream == null:
			return
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
		_hum = AudioStreamPlayer.new()
		_hum.bus = &"SFX"
		_hum.stream = stream
		controller.add_child(_hum)
	_hum.pitch_scale = lerpf(0.55, 1.1, spin)
	_hum.volume_db = lerpf(-20.0, -7.0, sqrt(spin)) + Sfx.mix_db(SPIN_SOUND)
	if not _hum.playing:
		_hum.play()
