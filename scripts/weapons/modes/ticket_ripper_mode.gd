class_name TicketRipperMode
extends WeaponMode
## Ticket Ripper "Winner!": every shot that hits a zombie ticks the streak on
## the drum's counter; a shot that hits nothing (scenery, the sky) resets it.
## Every STREAK hits in a row prints a golden WINNER ticket: the next round
## fired flies as a gold streak that pierces WINNER_PIERCE more zombies at
## WINNER_SCALE damage and pops a ticket burst (TicketRipperBurst) round the
## first zombie it strikes. The winner itself neither ticks nor breaks the
## streak. The drum, counter and ribbon move in
## scripts/weapons/views/ticket_ripper_view.gd, which reads `streak`,
## `winner_ready` and the `since_*` timers.

## Hits in a row that print a winner.
const STREAK := 15
## The winner: damage multiplier, extra zombies it passes through.
const WINNER_SCALE := 3.0
const WINNER_PIERCE := 3
const WINNER_GOLD := Color(1.0, 0.82, 0.22)
const READY_SOUND := &"tkr_ready"
const WINNER_SOUND := &"tkr_winner"
const BREAK_SOUND := &"tkr_break"
## Streaks shorter than this break silently (a stray first shot is no news).
const BREAK_SOUND_MIN := 5

## Hits in a row so far (counting on past each winner).
var streak := 0
## True once a winner is printed and waiting to be fired.
var winner_ready := false
## Seconds since the last hit, the last streak break and the last winner shot.
var since_hit := 10.0
var since_break := 10.0
var since_winner := 10.0
var _fired_winner := false
var _gold: WeaponData


## The counter's figure: hits towards the next winner (STREAK once printed).
func count() -> int:
	return STREAK if winner_ready else streak % STREAK


func trigger(_spinning: bool, delta: float) -> bool:
	since_hit += delta
	since_break += delta
	since_winner += delta
	return true


func launch(from: Vector3, dir: Vector3, scale: float) -> bool:
	if not winner_ready:
		return false
	winner_ready = false
	_fired_winner = true
	since_winner = 0.0
	_fire_winner(from, dir, scale)
	return true


func shape_hits(hits: Dictionary, _from: Vector3, _end: Vector3, _power: float) -> void:
	if _fired_winner:
		_fired_winner = false
		return
	if hits.is_empty():
		if streak >= BREAK_SOUND_MIN and not winner_ready:
			Sfx.play(BREAK_SOUND, -6.0)
		if not winner_ready:
			since_break = 0.0 if streak > 0 else since_break
			streak = 0
		return
	streak += 1
	since_hit = 0.0
	if streak % STREAK == 0 and not winner_ready:
		winner_ready = true
		Sfx.play(READY_SOUND, -3.0)


func gauge() -> float:
	return float(count()) / STREAK


## A lone target under perfect tracking: STREAK plain hits, then the winner.
func arsenal_dps(base: float) -> float:
	return base * (STREAK + WINNER_SCALE) / (STREAK + 1.0)


## The winner: a pierced trace from the eye along `dir`, a gold streak from
## the muzzle to where it stops, and the ticket burst round its first zombie.
func _fire_winner(from: Vector3, dir: Vector3, scale: float) -> void:
	var player := controller.player
	var origin := player.aim_transform().origin
	var space := player.get_world_3d().direct_space_state
	var exclude: Array[RID] = [player.get_rid()]
	var far := origin + dir * data.max_range
	var end := far
	var first: Zombie = null
	var first_at := Vector3.ZERO
	var struck: Array[Zombie] = []
	while struck.size() <= WINNER_PIERCE:
		var query := PhysicsRayQueryParameters3D.create(origin, far, WeaponController.MASK_WORLD | WeaponController.MASK_ENEMIES)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		end = hit["position"]
		var z := hit["collider"] as Zombie
		if z == null or z.is_dead():
			break
		if first == null:
			first = z
			first_at = end
		struck.append(z)
		exclude.append(z.get_rid())
		controller.strike(data, z, end, dir, origin.distance_to(end), scale * WINNER_SCALE)
	var level := player.get_parent()
	WeaponFx.shot(level, from, end, _gold_data())
	Sfx.play(WINNER_SOUND, -2.0, randf_range(0.97, 1.03))
	if first:
		TicketRipperBurst.pop(controller, data, first_at, struck)
	else:
		WeaponFx.burst(level, end, -dir, TicketRipperBurst.TICKETS, 10, 3.0, 0.6, 0.05, 120.0, Vector3(0, -5.0, 0))


## A copy of the weapon's data with the winner's gold, wider streak.
func _gold_data() -> WeaponData:
	if _gold == null:
		_gold = data.duplicate()
		_gold.tracer_color = WINNER_GOLD
		_gold.tracer_width = data.tracer_width * 2.6
	return _gold
