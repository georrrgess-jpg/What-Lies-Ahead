class_name WeaponData
extends Resource
## Tuning + presentation for one weapon. All three weapons run through the same
## combat code in scripts/player/weapon_controller.gd; only this data differs.

## Stable ID used by saves, mastery and unlocks. Never rename once shipped.
@export var id: StringName
@export var display_name := ""
@export_multiline var role := ""

@export_group("Ammo")
@export var magazine_size := 12
@export var reserve_start := 60
@export var reserve_max := 96
@export var reload_time := 1.3
## With no energy left at all, the cell trickles back one round per this many
## seconds (up to half a magazine) so the player is never completely helpless.
@export var emergency_recharge_interval := 1.0

@export_group("Fire")
## true = hold to fire, false = one shot per click.
@export var automatic := false
@export var fire_interval := 0.22
## Damage per pellet at close range.
@export var damage := 34.0
@export var pellets := 1
## Cone half-angle of the first shot.
@export var spread_degrees := 0.3
## Extra spread added per shot (recovers quickly when not firing).
@export var spread_bloom := 0.0
@export var spread_bloom_max := 0.0
@export var max_range := 70.0
@export var falloff_start := 30.0
@export var falloff_end := 70.0
## Damage multiplier at and beyond falloff_end.
@export var falloff_min_scale := 0.6
@export var headshot_multiplier := 1.6
## Knockback per pellet that hits, in m/s. Big pushes stagger zombies out of their windup.
@export var knockback := 0.6

@export_group("Feel")
## Camera pitch kick per shot, in degrees.
@export var recoil_kick := 1.0
## How far the viewmodel punches back per shot (metres, viewmodel space).
@export var view_kick := 0.05
@export_range(0.0, 1.0) var shake := 0.15
@export var tracer_color := Color(0.3, 0.95, 1.0)
@export var tracer_width := 0.035

@export_group("Presentation")
@export var viewmodel: PackedScene
## Where the viewmodel sits relative to the camera (metres, before the view scale).
@export var view_position := Vector3(0.26, -0.3, -0.6)
@export var view_rotation_degrees := Vector3(2.0, 6.0, 0.0)
## Which reload animation the viewmodel plays: "cell_drop", "side_swap" or "break_open".
@export var reload_style: StringName = &"cell_drop"
@export var fire_sound: StringName
@export var reload_sound: StringName
@export var empty_sound: StringName
@export var fire_pitch_variance := 0.05

@export_group("Mastery")
## Lifetime XP needed to reach rank 1, 2, 3...
@export var rank_xp: PackedInt32Array = PackedInt32Array([450, 1100, 2300, 4000, 6200])
@export var rewards: Array[MasteryReward] = []


func max_rank() -> int:
	return rank_xp.size()


func rank_for_xp(xp: int) -> int:
	var rank := 0
	for threshold in rank_xp:
		if xp >= threshold:
			rank += 1
	return rank


## XP at which `rank` begins (0 for rank 0).
func xp_floor(rank: int) -> int:
	if rank <= 0:
		return 0
	return rank_xp[mini(rank, rank_xp.size()) - 1]


## XP needed for the rank after `rank`, or -1 at max rank.
func xp_ceiling(rank: int) -> int:
	if rank >= rank_xp.size():
		return -1
	return rank_xp[rank]


func reward_by_id(reward_id: StringName) -> MasteryReward:
	for r in rewards:
		if r.id == reward_id:
			return r
	return null
