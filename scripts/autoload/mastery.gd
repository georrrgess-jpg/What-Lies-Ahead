extends Node
## Per-weapon lifetime mastery: XP, rank, kill counter and cosmetic rewards.
## Unlocks are derived from rank, never stored, so they cannot be granted twice.

signal xp_changed(weapon_id: StringName)
signal rank_up(weapon: WeaponData, rank: int)
signal reward_unlocked(weapon: WeaponData, reward: CosmeticItem)


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


func rank(weapon_id: StringName) -> int:
	var w := GameData.weapon(weapon_id)
	return w.rank_for_xp(xp(weapon_id)) if w else 0


## Progress through the current rank, 0-1 (1 at max rank).
func rank_progress(weapon_id: StringName) -> float:
	var w := GameData.weapon(weapon_id)
	if w == null:
		return 0.0
	var current := xp(weapon_id)
	var r := w.rank_for_xp(current)
	var ceiling := w.xp_ceiling(r)
	if ceiling < 0:
		return 1.0
	var floor_xp := w.xp_floor(r)
	return clampf(float(current - floor_xp) / float(maxi(1, ceiling - floor_xp)), 0.0, 1.0)


## Mastery reward items for a weapon (cosmetics gated on its rank).
func rewards(weapon_id: StringName) -> Array[CosmeticItem]:
	var out: Array[CosmeticItem] = []
	for it in GameData.cosmetics():
		if it.requirement and it.requirement.kind == Requirement.Kind.WEAPON_RANK and it.requirement.target == weapon_id:
			out.append(it)
	out.sort_custom(func(a, b): return a.requirement.amount < b.requirement.amount)
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
	var old_rank := w.rank_for_xp(int(entry["xp"]))
	entry["xp"] = int(entry["xp"]) + maxi(0, amount)
	entry["kills"] = int(entry["kills"]) + maxi(0, kill_count)
	var new_rank := w.rank_for_xp(int(entry["xp"]))
	xp_changed.emit(weapon_id)
	if new_rank > old_rank:
		rank_up.emit(w, new_rank)
	# Any cosmetic whose requirement just became true (rank, kills, ...).
	for it in Cosmetics.check_new_unlocks():
		unlocked.append(it)
		reward_unlocked.emit(w, it)
	return unlocked
