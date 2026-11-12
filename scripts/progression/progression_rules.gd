class_name ProgressionRules
extends Resource
## Account level tuning: the level curve, how runs pay out XP, and the flavour
## reward for levels that have no cosmetic. Lives in data/progression/rules.tres.
##
## XP needed to go from level L to L+1:
##   level_base_xp + level_step_xp * (L-1) + level_curve_xp * (L-1)^2
## (rounded to 50). With the defaults a full Prize Pier clear (~40k score)
## is worth about two levels at first; past level 25 a level takes a few runs.

@export_group("Level curve")
@export var level_base_xp := 3500
@export var level_step_xp := 380
@export var level_curve_xp := 2.0

@export_group("Run payout")
## Account XP per point of score.
@export var score_xp_rate := 0.06
## Wave clear: base + per_wave * wave number.
@export var wave_xp_base := 75
@export var wave_xp_per_wave := 25
## Reaching the portal.
@export var clear_xp := 1000
## Extra, once per level, the first time it is cleared.
@export var first_clear_xp := 1500

@export_group("Reward track")
## Shown for levels that unlock no cosmetic: "Name|description" per level
## (index = level; empty = nothing to show).
@export var stamps: PackedStringArray = PackedStringArray()


## XP to go from `lvl` to `lvl + 1`.
func level_cost(lvl: int) -> int:
	var k := float(maxi(0, lvl - 1))
	var raw := level_base_xp + level_step_xp * k + level_curve_xp * k * k
	return int(round(raw / 50.0)) * 50


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
