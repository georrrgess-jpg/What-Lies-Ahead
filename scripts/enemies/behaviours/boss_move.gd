class_name BossMove
extends Resource
## One signature move of a finale alpha, listed in AlphaBossBehaviour.moves and
## configured in the alpha's data. The alpha picks the next move that is off
## cooldown, in range and unlocked for its phase, runs it until tick() returns
## false, then waits its move gap. Subclasses: BossStrikeZones, BossShockwave,
## BossCharge, BossBeam, BossSummon, BossBurrow.
##
## Every move is telegraphed: a wind-up with a clip and a sound, and a marker
## on the floor or in the air that shows where it will hit.

## Name in the balance log and the key of its first-use callout.
@export var move_name: StringName = &"move"
## The move is used from this phase on (0 = from the start).
@export var min_phase := 0
@export var cooldown := 10.0
## Seconds after the alpha arrives before the first use.
@export var first_delay := 5.0
@export var min_range := 0.0
@export var max_range := 30.0
@export var needs_sight := false
## HUD line shown the first time the move is used ("" = none), so a player
## learns the tell: "BIG BRUNO HURLS A PRIZE BOOTH — WATCH THE FLOOR".
@export var callout := ""
@export var windup := 1.0
@export var windup_clip: StringName = &"Roar"
@export var windup_sound: StringName = &"boss_windup"

## Seconds until it can be used again.
var cool := 0.0
## The alpha behaviour running this move.
var boss: AlphaBossBehaviour


func reset(owner: AlphaBossBehaviour) -> void:
	boss = owner
	cool = first_delay


## True when the move can start now.
func can_start(z: Zombie, distance: float) -> bool:
	if cool > 0.0 or boss.phase() < min_phase or distance < min_range or distance > max_range:
		return false
	return not needs_sight or z.has_line_of_sight()


## Starts the move (the caller has checked can_start).
func begin(z: Zombie) -> void:
	cool = cooldown * z.special_scale
	z.play_animation(windup_clip, 0.12)
	Sfx.play_at(windup_sound, z.global_position + Vector3.UP * 1.6, 1.0, randf_range(0.95, 1.05), 16.0)


## Runs the move for a frame; false once it has finished and the alpha may
## walk again (strikes it placed can still be landing).
func tick(_z: Zombie, _delta: float) -> bool:
	return false


## Stops the move at once (death, or a stagger during the wind-up).
func cancel(_z: Zombie) -> void:
	pass


## Multiplies damage the alpha takes while the move runs (0 while it is
## underground or out of reach, a guard from the front...).
func filter_hit(_z: Zombie, amount: float, _at: Vector3, _headshot: bool) -> float:
	return amount


## True while its telegraph has not released yet (for the HUD threat ring).
func is_winding_up() -> bool:
	return false


## A direction out of this move's danger for a player standing at `point`
## (zero when safe). Used by the playtest bot.
func escape_from(_z: Zombie, _point: Vector3) -> Vector3:
	return Vector3.ZERO


## True when a player at `point` should jump now to clear this move.
func wants_jump(_z: Zombie, _point: Vector3) -> bool:
	return false


## The point on walkable floor nearest to `p` (strikes never hang in the air).
static func floor_point(z: Zombie, p: Vector3) -> Vector3:
	var map := z.get_world_3d().navigation_map
	var q := NavigationServer3D.map_get_closest_point(map, p)
	return q if q.distance_to(p) < 6.0 else p


## Flat direction from the alpha to the player.
static func flat_to_target(z: Zombie) -> Vector3:
	var to := z.target.global_position - z.global_position
	to.y = 0.0
	return to.normalized() if to.length() > 0.05 else z.global_basis.z
