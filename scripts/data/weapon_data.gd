class_name WeaponData
extends Resource
## Tuning + presentation for one weapon. Every weapon runs through the same
## combat code (scripts/player/weapon_controller.gd and scripts/weapons/);
## only this data differs. Fire modes (charge, burst, beam, projectile, splash,
## pierce, chain, status effects, heat) are switched on by their fields below.

## Stable ID used by saves, mastery and unlocks. Never rename once shipped.
@export var id: StringName
@export var display_name := ""
@export_multiline var role := ""
## Position in menus and the loadout list (lower first).
@export var sort_order := 0
## Short class tag shown in menus, e.g. "Pistol", "Carbine", "Shotgun".
@export var category := ""
## Unlock condition (null = available from the start).
@export var unlock: Requirement

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

@export_group("Aiming")
## Field of view multiplier when aimed down sights (lower = more zoom).
@export var ads_fov_scale := 0.78
## Seconds to raise the sights.
@export var ads_time := 0.16
## Spread multiplier when fully aimed.
@export var ads_spread_scale := 0.3
## How far in front of the eye the sight sits when aimed (metres).
@export var ads_depth := 0.34
## First shot after a pause is perfectly accurate (precision weapons).
@export var first_shot_accurate := true
## Reticle drawn for this weapon: "cross", "dot", "circle", "chevron" or "bracket".
## Charge, chain and burst weapons get extra reticle marks from WeaponHud.
@export var reticle_style := "cross"

@export_group("Feel")
## Camera pitch kick per shot, in degrees.
@export var recoil_kick := 1.0
## Sideways kick per shot (degrees). Alternates with a little randomness so
## sustained fire walks in a learnable zig-zag rather than random noise.
@export var recoil_yaw := 0.0
## How far the viewmodel punches back per shot (metres, viewmodel space).
@export var view_kick := 0.05
@export_range(0.0, 1.0) var shake := 0.15
@export var tracer_color := Color(0.3, 0.95, 1.0)
@export var tracer_width := 0.035

@export_group("Presentation")
@export var viewmodel: PackedScene
## Where the viewmodel sits relative to the camera (metres, before the view scale).
@export var view_position := Vector3(0.26, -0.3, -0.6)
## Keep X and Y at 0 so the barrel points at the crosshair; Z (cant) is free.
@export var view_rotation_degrees := Vector3(0.0, 0.0, -2.5)
## Which reload animation the viewmodel plays: "cell_drop", "side_swap" or "break_open".
@export var reload_style: StringName = &"cell_drop"
## Optional custom reload: a script with `func play(view: WeaponView, duration: float)`
## (see WeaponView's public reload API). Overrides reload_style when set.
@export var reload_script: Script
@export var fire_sound: StringName
@export var reload_sound: StringName
@export var empty_sound: StringName
@export var fire_pitch_variance := 0.05

@export_group("Mastery")
## Lifetime XP needed to reach rank 1, 2, 3...
@export var rank_xp: PackedInt32Array = PackedInt32Array([450, 1100, 2300, 4000, 6200])

# --- fire modes (all optional; defaults give a plain hitscan weapon) ----------
# See scripts/weapons/ for the systems these drive.

@export_group("Handling")
## Player move speed multiplier while this weapon is held.
@export var move_speed_scale := 1.0
## Seconds to raise this weapon after switching to it (nothing fires until then).
@export var equip_time := 0.32
## Sound played when this weapon is switched in (empty = the shared switch sound).
@export var equip_sound: StringName

@export_group("Charge")
## > 0: hold fire to charge for this many seconds, release to fire.
@export var charge_time := 0.0
## Release below this fraction of a full charge and the shot fizzles.
@export_range(0.0, 1.0) var charge_min_fraction := 0.2
## Damage multiplier of the weakest allowed charge (a full charge is x1).
@export var charge_min_damage_scale := 0.2
## Move speed multiplier while charging.
@export var charge_move_scale := 0.75
@export var charge_sound: StringName
## Played once when the charge is full.
@export var charge_ready_sound: StringName

@export_group("Burst")
## Shots fired per trigger pull (1 = no burst).
@export var burst_count := 1
## Seconds between the shots of one burst (fire_interval is the pause after it).
@export var burst_interval := 0.07

@export_group("Beam")
## Continuous beam: holding fire deals one damage tick every fire_interval and
## draws a beam from the muzzle to the target.
@export var beam := false
## Looping sound while the beam is on.
@export var beam_loop_sound: StringName

@export_group("Projectile")
## > 0: shots launch a physical projectile at this speed (m/s) instead of a hitscan ray.
@export var projectile_speed := 0.0
## Downward acceleration (m/s²) so the shot arcs.
@export var projectile_gravity := 0.0
## Extra upward launch speed (m/s), so a lob clears a low obstacle.
@export var projectile_loft := 0.0
## Times the projectile can bounce off scenery before it detonates.
@export var projectile_bounces := 0
## Velocity kept after a bounce.
@export var projectile_bounciness := 0.55
## Seconds before it detonates on its own.
@export var projectile_fuse := 2.0
## Visual radius of the projectile (m).
@export var projectile_size := 0.12
@export var bounce_sound: StringName

@export_group("Splash")
## > 0: hits deal `damage` at the centre of a blast of this radius (m).
@export var splash_radius := 0.0
## Damage multiplier at the edge of the blast.
@export var splash_edge_scale := 0.35
## Outward knockback at the centre of the blast (m/s).
@export var splash_push := 4.0
## Extra damage to a zombie struck directly by the projectile.
@export var direct_hit_bonus := 0.0
@export var explosion_sound: StringName

@export_group("Pierce & Chain")
## Extra zombies a shot passes through after the first.
@export var pierce := 0
## Damage multiplier for each zombie a shot has already passed through.
@export var pierce_falloff := 0.85
## Extra zombies a hit arcs to (chain lightning).
@export var chain_count := 0
## Max distance of one chain jump (m).
@export var chain_range := 6.0
## Damage multiplier per jump.
@export var chain_falloff := 0.75
## Shots that miss lock onto the zombie closest to the crosshair inside this
## cone (degrees), within max_range and line of sight. 0 = off.
@export var seek_cone_degrees := 0.0
@export var chain_sound: StringName

@export_group("Status")
## Effect applied on hit: "" (none), "chill" (slows, then freezes) or "shock" (brief slow).
@export var status_effect: StringName
## Status build-up per hit (chill: 1.0 = frozen).
@export var status_amount := 0.0
## Seconds a frozen zombie stays frozen / a shocked zombie stays shocked.
@export var status_duration := 1.5
## Damage multiplier frozen zombies take from every weapon.
@export var frozen_damage_scale := 1.0
## Killing a frozen zombie shatters it: damage to zombies within 2.5 m.
@export var shatter_damage := 0.0
@export var status_sound: StringName

@export_group("Heat")
## > 0: the magazine is a heat capacity that cools (refills from reserve) at
## this many rounds per second once the trigger has been released for
## regen_delay seconds. Running dry overheats it (the reload is the vent).
@export var regen_rate := 0.0
@export var regen_delay := 0.4

@export_group("Effects")
## Shot streak: "bolt" (default tracer), "rail", "lightning", "beam" or "none".
@export var tracer_style: StringName = &"bolt"
## Impact on scenery: "spark", "frost", "arc" or "rail".
@export var impact_style: StringName = &"spark"


func max_rank() -> int:
	return rank_xp.size()


## Damage one trigger pull deals to a single target (full charge, every pellet
## and every shot of a burst, body hits at close range).
func burst_damage() -> float:
	return damage * pellets * burst_count + direct_hit_bonus


## Seconds from one trigger pull to the next while holding or clicking fast.
func cycle_time() -> float:
	return fire_interval + charge_time + (burst_count - 1) * burst_interval


## Sustained single-target damage per second while the magazine lasts.
func damage_per_second() -> float:
	return burst_damage() / maxf(0.05, cycle_time())


## Distance (m) at which the weapon still does most of its work.
func effective_range() -> float:
	if projectile_speed > 0.0:
		return minf(max_range, projectile_speed * projectile_fuse * 0.6)
	return minf(max_range, falloff_start + (falloff_end - falloff_start) * 0.35)


## True for weapons whose magazine is a cooling heat capacity.
func uses_heat() -> bool:
	return regen_rate > 0.0


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
