extends Node
## Per-weapon lifetime mastery: XP, rank, kill counter and cosmetic rewards.
## Unlocks are derived from rank, never stored, so they cannot be granted twice.
##
## Every weapon shares one curve (data/progression/mastery_curve.tres): ten
## ranks grouped into tiers (Bronze, Silver, Gold, Diamond, Prismatic). New
## weapons need no mastery data. At startup the curve is copied into each
## WeaponData.rank_xp so code that asks the weapon directly (max_rank(),
## xp_ceiling()) agrees with this autoload.

signal xp_changed(weapon_id: StringName)
signal rank_up(weapon: WeaponData, rank: int)
signal reward_unlocked(weapon: WeaponData, reward: CosmeticItem)

const CURVE_PATH := "res://data/progression/mastery_curve.tres"

var curve: MasteryCurve


func _ready() -> void:
	curve = load(CURVE_PATH)
	for w in GameData.weapons():
		w.rank_xp = curve.rank_xp


func _entry(weapon_id: StringName) -> Dictionary:
	var m: Dictionary = Profile.data["mastery"]
	var key := String(weapon_id)
	if not m.has(key):
		m[key] = {"xp": 0, "kills": 0}
	return m[key]


func xp(weapon_id: StringName) -> int:
	return int(_entry(weapon_id)["xp"])


func kills(weapon_id: StringName) -> int:
	return int(_entry(weapon_id)["kills"])


## Lifetime kills across every weapon.
func total_kills() -> int:
	var total := 0
	for key in Profile.data["mastery"]:
		total += int(Profile.data["mastery"][key].get("kills", 0))
	return total


func max_rank() -> int:
	return curve.max_rank()


func rank(weapon_id: StringName) -> int:
	return curve.rank_for_xp(xp(weapon_id)) if GameData.weapon(weapon_id) else 0


## Progress through the current rank, 0-1 (1 at max rank).
func rank_progress(weapon_id: StringName) -> float:
	if GameData.weapon(weapon_id) == null:
		return 0.0
	var current := xp(weapon_id)
	var r := curve.rank_for_xp(current)
	var ceiling := curve.xp_ceiling(r)
	if ceiling < 0:
		return 1.0
	var floor_xp := curve.xp_floor(r)
	return clampf(float(current - floor_xp) / float(maxi(1, ceiling - floor_xp)), 0.0, 1.0)


## XP at which `rank` begins.
func rank_floor(rank_number: int) -> int:
	return curve.xp_floor(rank_number)


## XP needed for the rank after `rank_number`, or -1 at max rank.
func rank_ceiling(rank_number: int) -> int:
	return curve.xp_ceiling(rank_number)


## The tier a rank belongs to (null for rank 0).
func tier(rank_number: int) -> MasteryTier:
	return curve.tier_for_rank(rank_number)


## "RANK 4 · SILVER", "UNRANKED", "PRISMATIC · MASTERED".
func rank_label(rank_number: int) -> String:
	var t := tier(rank_number)
	if t == null:
		return "UNRANKED"
	if rank_number >= max_rank():
		return "%s · MASTERED" % t.display_name.to_upper()
	return "RANK %d · %s" % [rank_number, t.display_name.to_upper()]


## Mastery reward items made for this weapon (cosmetics gated on its rank).
func rewards(weapon_id: StringName) -> Array[CosmeticItem]:
	return _rank_items(weapon_id, false)


## Everything a weapon unlocks by rank: its own rewards plus the
## weapon-agnostic mastery camos (WEAPON_RANK with an empty target).
func rank_track(weapon_id: StringName) -> Array[CosmeticItem]:
	return _rank_items(weapon_id, true)


## Rewards that unlock exactly at `rank_number` on this weapon.
func rewards_at(weapon_id: StringName, rank_number: int) -> Array[CosmeticItem]:
	return rank_track(weapon_id).filter(func(it): return it.requirement.amount == rank_number)


func _rank_items(weapon_id: StringName, include_shared: bool) -> Array[CosmeticItem]:
	var out: Array[CosmeticItem] = []
	for it in GameData.cosmetics():
		var req := it.requirement
		if req == null or req.kind != Requirement.Kind.WEAPON_RANK:
			continue
		if req.target == weapon_id or include_shared and req.target == &"" and it.fits_weapon(weapon_id):
			out.append(it)
	out.sort_custom(func(a, b): return a.requirement.amount < b.requirement.amount if a.requirement.amount != b.requirement.amount else a.sort_order < b.sort_order)
	return out


## Adds XP (and optionally kills) to a weapon. Changes are in memory until the
## run director commits the profile at a wave boundary, defeat or extraction.
## Returns the cosmetics this grant unlocked.
func grant(weapon_id: StringName, amount: int, kill_count := 0) -> Array[CosmeticItem]:
	var unlocked: Array[CosmeticItem] = []
	var w := GameData.weapon(weapon_id)
	if w == null or (amount <= 0 and kill_count <= 0):
		return unlocked
	var entry := _entry(weapon_id)
	var old_rank := curve.rank_for_xp(int(entry["xp"]))
	entry["xp"] = int(entry["xp"]) + maxi(0, amount)
	entry["kills"] = int(entry["kills"]) + maxi(0, kill_count)
	var new_rank := curve.rank_for_xp(int(entry["xp"]))
	xp_changed.emit(weapon_id)
	for r in range(old_rank + 1, new_rank + 1):
		rank_up.emit(w, r)
	# Rank rewards are reported as soon as the rank is reached; other unlocks
	# (total kills, ...) are account rewards, collected by Progression at wave
	# clears and the end of the run (or here, if a rank-up noticed them first).
	if new_rank <= old_rank:
		return unlocked
	for it in Cosmetics.check_new_unlocks():
		if _is_rank_reward_for(it, weapon_id):
			unlocked.append(it)
			reward_unlocked.emit(w, it)
		else:
			Progression.credit_account_reward(it)
	return unlocked


static func _is_rank_reward_for(it: CosmeticItem, weapon_id: StringName) -> bool:
	var req := it.requirement
	return req != null and req.kind == Requirement.Kind.WEAPON_RANK and (req.target == &"" or req.target == weapon_id)
