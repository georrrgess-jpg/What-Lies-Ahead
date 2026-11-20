extends MeleeMode
## Jester's Jinglestar (jinglestar): ENCORE. Every swing that connects
## within ENCORE_WINDOW of the last one that did adds a step to the encore
## (up to ENCORE_STEPS); each step makes the next swings PACE_STEP quicker.
## At a full encore every swing that connects also rings the bell: a jingle
## shockwave round the player (RING_RADIUS) that knocks the rank and file
## back and deals RING_DAMAGE (heavies and alphas take
## melee_heavy_target_scale of it). A swing that misses, or a pause longer
## than ENCORE_WINDOW, ends the encore. The HUD gauge shows it; the view
## reads `encore` (the ribbons and the bell glow with it) and `rings`.

const TRAIT := "Encore"
const ENCORE_STEPS := 4
const ENCORE_WINDOW := 1.6
## Share of a swing's length each encore step takes off (light; the heavy half as much).
const PACE_STEP := 0.07
const RING_RADIUS := 3.0
const RING_DAMAGE := 24.0
const RING_PUSH := 3.0
const RING_COLORS := [Color(1.0, 0.82, 0.27), Color(0.55, 0.24, 0.94), Color(0.1, 0.77, 0.54), Color(1, 1, 1)]

## Encore steps (0..ENCORE_STEPS).
var encore := 0
## Counts the jingle shockwaves (the view rings on a change).
var rings := 0
var _since := 0.0
## The pace of the swing in progress (its length = the data's x this).
var _pace := 1.0
var _hits_at_start := 0
var _in_swing := false


func swing_input(fire: bool, aim: bool, ready: bool, delta: float) -> bool:
	var was_phase := phase
	var was_index := swing_index
	var used := super.swing_input(fire, aim, ready, delta)
	_since += delta
	var ended := was_phase in [Phase.LIGHT, Phase.HEAVY] and (phase == Phase.IDLE or swing_index != was_index)
	if ended and _in_swing:
		_settle(hits > _hits_at_start)
		_in_swing = false
	if swing_index != was_index and phase in [Phase.LIGHT, Phase.HEAVY]:
		_in_swing = true
		_hits_at_start = hits
		_pace = 1.0 - PACE_STEP * encore * (0.5 if phase == Phase.HEAVY else 1.0)
	if phase == Phase.WINDUP and was_phase == Phase.IDLE:
		Sfx.play(&"jingle_whirl", -6.0, randf_range(0.97, 1.03))
	if encore > 0 and not _in_swing and phase != Phase.WINDUP and _since > ENCORE_WINDOW:
		_drop()
	return used


func swing_time() -> float:
	return super.swing_time() * _pace


## 0-1 encore for the HUD gauge.
func gauge() -> float:
	return float(encore) / ENCORE_STEPS


func end_trigger() -> void:
	super.end_trigger()
	encore = 0
	_in_swing = false


func _strike(heavy: bool) -> void:
	var before := hits
	super._strike(heavy)
	if heavy:
		Sfx.play_at(&"jingle_slam", controller.player.global_position + _flat_forward() * 1.5, -1.0, randf_range(0.96, 1.04))
	if encore >= ENCORE_STEPS and hits > before:
		_ring()


## A swing ended: one that connected adds a step, one that missed ends the encore.
func _settle(connected: bool) -> void:
	if not connected:
		_drop()
		return
	_since = 0.0
	if encore < ENCORE_STEPS:
		encore += 1
		Sfx.play(&"jingle_step", -8.0 + encore, 0.9 + 0.08 * encore)


func _drop() -> void:
	if encore >= 2:
		Sfx.play(&"jingle_fizzle", -10.0, randf_range(0.95, 1.05))
	encore = 0


## The full encore's jingle shockwave round the player.
func _ring() -> void:
	rings += 1
	var player := controller.player
	var at := player.global_position + Vector3.UP * 0.4
	var level := _level()
	Sfx.play_at(&"jingle_encore", at, -3.0, randf_range(0.98, 1.03))
	WeaponFx.shockwave(level, at, RING_COLORS[0], RING_RADIUS, 0.8)
	WeaponFx.burst(level, at + _flat_forward() * 0.8 + Vector3.UP * 0.6, Vector3.UP, RING_COLORS, 22, 4.5, 0.8, 0.04, 85.0)
	for node in player.get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var to := z.global_position - player.global_position
		to.y = 0.0
		if to.length() - z.data.capsule_radius * z.data.body_scale > RING_RADIUS:
			continue
		var tough := z.data.heavy or z.rank == Zombie.RANK_BOSS or z.data.mass >= ALPHA_MASS
		if not tough:
			z.interrupt()
		var dir := to.normalized() if to.length() > 0.05 else _flat_forward()
		controller.melee_hit(data, z, z.global_position + Vector3.UP, dir, RING_DAMAGE * (data.melee_heavy_target_scale if tough else 1.0), RING_PUSH)
