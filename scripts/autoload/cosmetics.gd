extends Node
## Cosmetics: what the player owns and has equipped, and applying it.
##
## Items are CosmeticItem resources found under data/cosmetics/. An item is
## owned when its requirement is met (or it has none). Equipped items are
## stored per slot in Profile.section("cosmetics")["equipped"], keyed
## "slot" for global slots or "slot@weapon_id" for weapon slots.

## A newly owned item (detected by check_new_unlocks()).
signal unlocked(item: CosmeticItem)
signal equipped_changed(slot: StringName, weapon_id: StringName)


func _sec() -> Dictionary:
	var s := Profile.section("cosmetics")
	if not s.has("equipped"):
		s["equipped"] = {}
	if not s.has("seen"):
		s["seen"] = []
	return s


func items() -> Array[CosmeticItem]:
	return GameData.cosmetics()


func item(id: StringName) -> CosmeticItem:
	for it in GameData.cosmetics():
		if it.id == id:
			return it
	return null


## Items for one slot (and, for weapon slots, one weapon).
func items_for(slot: StringName, weapon_id: StringName = &"") -> Array[CosmeticItem]:
	var out: Array[CosmeticItem] = []
	for it in GameData.cosmetics():
		if it.slot == slot and (weapon_id == &"" or it.fits_weapon(weapon_id)):
			out.append(it)
	return out


## `weapon_id` gives context for weapon cosmetics whose requirement is
## "mastery rank N on the weapon it is equipped on".
func is_owned(it: CosmeticItem, weapon_id: StringName = &"") -> bool:
	if it == null:
		return false
	if Unlocks.is_granted(StringName("cosmetic:" + String(it.id))):
		return true
	return it.requirement == null or it.requirement.is_met(weapon_id)


## Grants an item outright (e.g. a reward), regardless of its requirement.
func grant(it: CosmeticItem) -> void:
	Unlocks.grant(StringName("cosmetic:" + String(it.id)))


static func _key(slot: StringName, weapon_id: StringName) -> String:
	return String(slot) + ("@" + String(weapon_id) if weapon_id != &"" else "")


## Equip `it` in its slot (null clears the slot). Saves the profile.
func equip(slot: StringName, it: CosmeticItem, weapon_id: StringName = &"") -> bool:
	if it != null and (not is_owned(it, weapon_id) or it.slot != slot or not it.fits_weapon(weapon_id) and weapon_id != &""):
		return false
	var key := _key(slot, weapon_id if slot.begins_with("weapon_") else &"")
	var eq: Dictionary = _sec()["equipped"]
	if it == null:
		eq.erase(key)
	else:
		eq[key] = String(it.id)
	Profile.save_profile()
	equipped_changed.emit(slot, weapon_id)
	return true


func equipped(slot: StringName, weapon_id: StringName = &"") -> CosmeticItem:
	var key := _key(slot, weapon_id if String(slot).begins_with("weapon_") else &"")
	var id := StringName(String(_sec()["equipped"].get(key, "")))
	if id == &"":
		return null
	var it := item(id)
	return it if is_owned(it, weapon_id) else null


## Weapon cosmetics in the shape WeaponCosmetics.apply expects.
func weapon_loadout(weapon_id: StringName) -> Dictionary:
	return {
		"finish": equipped(&"weapon_finish", weapon_id),
		"cell": equipped(&"weapon_cell", weapon_id),
		"decal": equipped(&"weapon_decal", weapon_id),
		"charm": equipped(&"weapon_charm", weapon_id),
	}


## Returns items that became owned since the last call (and remembers them),
## emitting `unlocked` for each. Safe to call as often as you like.
func check_new_unlocks() -> Array[CosmeticItem]:
	var seen: Array = _sec()["seen"]
	var fresh: Array[CosmeticItem] = []
	for it in GameData.cosmetics():
		if it.requirement == null:
			continue
		# Weapon-agnostic mastery items unlock separately for every weapon.
		var per_weapon := it.requirement.kind == Requirement.Kind.WEAPON_RANK and it.requirement.target == &""
		var contexts: Array = [&""]
		if per_weapon:
			contexts = GameData.weapons().map(func(w): return w.id)
		for ctx in contexts:
			var key := String(it.id) + ("@" + String(ctx) if per_weapon else "")
			if seen.has(key):
				continue
			if it.requirement.is_met(ctx):
				seen.append(key)
				fresh.append(it)
				unlocked.emit(it)
	return fresh
