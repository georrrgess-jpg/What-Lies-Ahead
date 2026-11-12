extends Node
## Per-weapon lifetime mastery: XP, rank, kill counter and cosmetic rewards.
## Unlocks are derived from rank, never stored, so they cannot be granted twice.

signal xp_changed(weapon_id: StringName)
signal rank_up(weapon: WeaponData, rank: int)
signal reward_unlocked(weapon: WeaponData, reward: MasteryReward)

const SLOTS := ["decal", "cell", "finish"]


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


## Adds XP (and optionally kills) to a weapon. Changes are in memory until the
## run director commits the profile at a wave boundary, defeat or extraction.
## Returns the rewards this grant unlocked.
func grant(weapon_id: StringName, amount: int, kill_count := 0) -> Array[MasteryReward]:
	var unlocked: Array[MasteryReward] = []
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
		for reward in w.rewards:
			if reward.rank_required > old_rank and reward.rank_required <= new_rank:
				unlocked.append(reward)
				reward_unlocked.emit(w, reward)
	return unlocked


func is_unlocked(weapon_id: StringName, reward: MasteryReward) -> bool:
	return rank(weapon_id) >= reward.rank_required


func equipped_id(weapon_id: StringName, slot: String) -> StringName:
	var e: Dictionary = Profile.data["equipped"].get(String(weapon_id), {})
	return StringName(String(e.get(slot, "")))


## Equips a reward in its slot, or clears the slot when reward is null.
func equip(weapon_id: StringName, slot: String, reward: MasteryReward) -> bool:
	if reward != null and not is_unlocked(weapon_id, reward):
		return false
	var eq: Dictionary = Profile.data["equipped"]
	var key := String(weapon_id)
	if not eq.has(key):
		eq[key] = {"decal": "", "cell": "", "finish": ""}
	eq[key][slot] = String(reward.id) if reward else ""
	Profile.save_profile()
	return true


## The equipped (and still valid) reward per slot: { "decal": MasteryReward|null, ... }.
func cosmetics(weapon_id: StringName) -> Dictionary:
	var out := {}
	var w := GameData.weapon(weapon_id)
	for slot in SLOTS:
		var reward: MasteryReward = null
		if w:
			reward = w.reward_by_id(equipped_id(weapon_id, slot))
			if reward and (reward.slot() != slot or not is_unlocked(weapon_id, reward)):
				reward = null
		out[slot] = reward
	return out
