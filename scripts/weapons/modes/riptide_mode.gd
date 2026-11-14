extends WeaponMode
## Riptide Harpoon: every zombie the harpoon skewers is reeled toward the
## player. The pull grows with the zombie's weight (REEL_PULL x sqrt(mass)
## on its knockback), so a Bruiser is yanked out of its charge and staggers
## too, while an alpha only budges; zombies already close are barely pulled,
## so nothing is dragged into the player's face. Heavies take HEAVY_BONUS
## damage. Draws the harpoon on its line (HarpoonLine); on the viewmodel the
## spear leaves the barrel, the spool reels in and a new spear slides home.

## Pull on a 1-mass zombie at full charge (m/s of knockback toward the player).
const REEL_PULL := 7.0
## No pull inside MIN_GAP metres, full pull from MIN_GAP + PULL_RAMP on.
const MIN_GAP := 3.5
const PULL_RAMP := 4.0
const HEAVY_BONUS := 1.3
## Seconds the spear is out after a shot, then how long it takes to slide home.
const SPEAR_OUT := 0.42
const SPEAR_LOAD := 0.16
## How far the spear draws back into the barrel at full charge (m).
const DRAW := 0.035
## Spool turns per second while reeling, and per second of charge.
const REEL_TURNS := 2.6
const CHARGE_TURNS := -0.35
const REEL_SOUND := &"weap_rip_reel"

var _since_shot := 10.0
var _reel := 0.0
var _model_id := 0
var _spear: Array = []
var _spool: Array = []


func shape_hits(hits: Dictionary, from: Vector3, end: Vector3, power: float) -> void:
	var eye := controller.player.global_position
	for key in hits:
		var entry: Dictionary = hits[key]
		var z: Zombie = entry["zombie"]
		if not is_instance_valid(z):
			continue
		var gap := Vector2(z.global_position.x - eye.x, z.global_position.z - eye.z).length()
		var reach := clampf((gap - MIN_GAP) / PULL_RAMP, 0.0, 1.0)
		# Pushing against the shot's direction pulls the zombie toward the player.
		entry["push"] = -REEL_PULL * sqrt(maxf(0.2, z.data.mass)) * power * reach
		if z.data.heavy:
			entry["damage"] = float(entry["damage"]) * HEAVY_BONUS
			entry["head_damage"] = float(entry["head_damage"]) * HEAVY_BONUS
	HarpoonLine.spawn(controller.player.get_parent(), controller.player.view, from, end, data.tracer_color, power)
	if not hits.is_empty():
		Sfx.play(REEL_SOUND, -5.0, randf_range(0.96, 1.04))
	_since_shot = 0.0


func animate(model: Node3D, delta: float) -> void:
	if model.get_instance_id() != _model_id:
		_model_id = model.get_instance_id()
		_spear = find_part(model, "Harpoon")
		_spool = find_part(model, "Reel")
	if controller.is_reloading():
		# The reload loads a spear and winds the spool; both end at rest.
		_since_shot = 10.0
		_reel = 0.0
		return
	_since_shot += delta
	var reeling := 1.0 - smoothstep(0.0, SPEAR_OUT, _since_shot)
	_reel = fmod(_reel + (REEL_TURNS * reeling + CHARGE_TURNS * controller.shown_charge()) * TAU * delta, TAU)
	if not _spool.is_empty():
		var rest: Transform3D = _spool[1]
		_spool[0].transform = Transform3D(rest.basis * Basis(Vector3.RIGHT, _reel), rest.origin)
	if _spear.is_empty():
		return
	var spear: Node3D = _spear[0]
	spear.visible = _since_shot >= SPEAR_OUT and controller.magazine() > 0
	# A new spear slides in from the muzzle, then draws back as the shot charges.
	var load := 1.0 - smoothstep(SPEAR_OUT, SPEAR_OUT + SPEAR_LOAD, _since_shot)
	var rest: Transform3D = _spear[1]
	spear.transform = Transform3D(rest.basis, rest.origin + Vector3(0.0, 0.0, -0.12 * load + DRAW * controller.shown_charge()))
