class_name ProgressionRules
extends Resource
## Account level tuning: the level curve and how runs pay out XP. Lives in
## data/progression/rules.tres (what levels pay in Sparks is in economy.tres).
##
## XP needed to go from level L to L+1:
##   level_base_xp + level_step_xp * (L-1) + level_curve_xp * (L-1)^2
## (rounded to 50). The curve is linear: the first session brings several
## levels, every weapon is unlocked within the first half-dozen clears, and
## the cap (level 40) takes a typical player about 48 clears. Check changes
## with tools/economy_model.py.

@export_group("Level curve")
@export var level_base_xp := 1800
@export var level_step_xp := 400
@export var level_curve_xp := 0.0

@export_group("Run payout")
## Account XP per point of score.
@export var score_xp_rate := 0.06
## Wave clear: base + per_wave * wave number.
@export var wave_xp_base := 75
@export var wave_xp_per_wave := 25
## Reaching the portal: clear_xp, plus clear_xp_per_world for each world
## after the first (later worlds pay more).
@export var clear_xp := 1000
@export var clear_xp_per_world := 250
## Extra, once per level, the first time it is cleared.
@export var first_clear_xp := 1500

@export_group("Reward track")
## Optional flavour for a level that gives neither a weapon nor a cosmetic:
## "Name|description" per level (index = level; empty = nothing to show).
@export var stamps: PackedStringArray = PackedStringArray()


## XP to go from `lvl` to `lvl + 1`.
func level_cost(lvl: int) -> int:
	var k := float(maxi(0, lvl - 1))
	var raw := level_base_xp + level_step_xp * k + level_curve_xp * k * k
	return int(round(raw / 50.0)) * 50


## Level-clear XP for a level in the world at `world_index` (0 = the first world).
func clear_xp_for(world_index: int) -> int:
	return clear_xp + clear_xp_per_world * maxi(0, world_index)


func wave_xp(wave_number: int) -> int:
	return wave_xp_base + wave_xp_per_wave * wave_number


## [name, description] of the Pier Pass stamp for `lvl`, or [] if none.
func stamp(lvl: int) -> PackedStringArray:
	if lvl < 0 or lvl >= stamps.size() or stamps[lvl] == "":
		return PackedStringArray()
	var parts := stamps[lvl].split("|")
	if parts.size() < 2:
		parts.append("")
	return parts
