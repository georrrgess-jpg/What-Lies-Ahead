extends Node
## Cosmetics: what the player owns and has equipped, and applying it.
##
## Items are CosmeticItem resources found under data/cosmetics/. An item is
## owned when its requirement is met (or it has none); an item with a price is
## owned once it has been bought with Sparks (buy(); the shop's sections,
## featured selection and discounts are in ShopCatalog). Equipped items are
## stored per slot in Profile.section("cosmetics")["equipped"], keyed
## "slot" for global slots or "slot@weapon_id" for weapon slots.
##
## A slot may have a default item (params.default = true, no requirement),
## used when nothing is equipped there: equipped_or_default(). Items the
## player has unlocked but not looked at yet in the Locker are "new"
## (is_new / mark_seen / new_count).

## A newly owned item (detected by check_new_unlocks()).
signal unlocked(item: CosmeticItem)
signal equipped_changed(slot: StringName, weapon_id: StringName)
## The player bought `item` with Sparks.
signal purchased(item: CosmeticItem)

var _by_id := {}
var _owned_at_run_start := {}


func _ready() -> void:
	Events.run_started.connect(func(_director): _owned_at_run_start = _owned_snapshot())
	# A save from before the Sparks economy keeps everything it owned.
	LegacyGrant.apply_if_pending()
	# Items already owned when the game starts are not news: only unlocks
	# earned from here on are reported by check_new_unlocks() (HUD toasts).
	check_new_unlocks()


func _sec() -> Dictionary:
	var s := Profile.section("cosmetics")
	if not s.has("equipped"):
		s["equipped"] = {}
	if not s.has("seen"):
		s["seen"] = []
	if not s.has("viewed"):
		s["viewed"] = []
	return s


func items() -> Array[CosmeticItem]:
	return GameData.cosmetics()


func item(id: StringName) -> CosmeticItem:
	if _by_id.is_empty():
		for it in GameData.cosmetics():
			_by_id[it.id] = it
	return _by_id.get(id)


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
	# Items for sale are owned only once bought (or granted).
	if it.price > 0:
		return false
	return it.requirement == null or it.requirement.is_met(weapon_id)


## True for an item sold for Sparks that the player does not own yet.
func is_for_sale(it: CosmeticItem) -> bool:
	return it != null and it.price > 0 and not Unlocks.is_granted(StringName("cosmetic:" + String(it.id)))


## True when the item's requirement (if any) allows buying it. `weapon_id`
## gives context for "mastery rank on this weapon" requirements.
func can_unlock_purchase(it: CosmeticItem, weapon_id: StringName = &"") -> bool:
	return it != null and (it.requirement == null or it.requirement.is_met(weapon_id))


## What `it` costs right now: its price, less today's featured discount.
func price_of(it: CosmeticItem) -> int:
	return ShopCatalog.price(it)


## For sale, unlocked for purchase and affordable right now.
func can_buy(it: CosmeticItem, weapon_id: StringName = &"") -> bool:
	return is_for_sale(it) and can_unlock_purchase(it, weapon_id) and Wallet.can_afford(price_of(it))


## Buys `it` with Sparks (at price_of(it)). Returns false (changing nothing)
## if it is not for sale, still locked or too expensive.
func buy(it: CosmeticItem, weapon_id: StringName = &"") -> bool:
	if not can_buy(it, weapon_id) or not Wallet.spend(price_of(it), it.id):
		return false
	grant(it)
	Profile.save_profile()
	purchased.emit(it)
	return true


## Owned for at least one weapon (for weapon-agnostic mastery items) or globally.
func is_owned_anywhere(it: CosmeticItem) -> bool:
	if is_owned(it):
		return true
	if it != null and it.is_weapon_slot():
		for w in GameData.weapons():
			if it.fits_weapon(w.id) and is_owned(it, w.id):
				return true
	return false


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


## The slot's default item (params.default), or null.
func default_item(slot: StringName) -> CosmeticItem:
	for it in GameData.cosmetics():
		if it.slot == slot and bool(it.params.get("default", false)):
			return it
	return null


## What the player is wearing in a slot: the equipped item or the slot default.
func equipped_or_default(slot: StringName, weapon_id: StringName = &"") -> CosmeticItem:
	var it := equipped(slot, weapon_id)
	return it if it else default_item(slot)


## Weapon cosmetics in the shape WeaponCosmetics.apply expects. "arms" is the
## first-person arm look: the gloves skin, else the operator's arm scheme.
func weapon_loadout(weapon_id: StringName) -> Dictionary:
	var arms := equipped(&"gloves")
	return {
		"finish": equipped(&"weapon_finish", weapon_id),
		"cell": equipped(&"weapon_cell", weapon_id),
		"decal": equipped(&"weapon_decal", weapon_id),
		"charm": equipped(&"weapon_charm", weapon_id),
		"sight": equipped(&"weapon_sight", weapon_id),
		"arms": arms if arms else equipped_or_default(&"avatar"),
	}


## Returns items that became owned since the last call (and remembers them),
## emitting `unlocked` for each. Safe to call as often as you like.
func check_new_unlocks() -> Array[CosmeticItem]:
	var seen: Array = _sec()["seen"]
	var fresh: Array[CosmeticItem] = []
	for it in GameData.cosmetics():
		# Items for sale are bought, not unlocked: meeting their requirement
		# only opens them in the shop (ShopCatalog.is_new).
		if it.requirement == null or it.price > 0:
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


# --- "new" badges ---------------------------------------------------------------

## Owned, earned (not a starting item) and not yet looked at in the Locker.
func is_new(it: CosmeticItem) -> bool:
	if it == null or it.requirement == null or not is_owned_anywhere(it):
		return false
	return not (_sec()["viewed"] as Array).has(String(it.id))


## Marks an item as looked at. Call Profile.save_profile() when done browsing.
func mark_seen(it: CosmeticItem) -> void:
	var viewed: Array = _sec()["viewed"]
	if it and not viewed.has(String(it.id)):
		viewed.append(String(it.id))


## New items in one slot, or in every slot when `slot` is empty.
func new_count(slot: StringName = &"") -> int:
	var n := 0
	for it in GameData.cosmetics():
		if (slot == &"" or it.slot == slot) and is_new(it):
			n += 1
	return n


# --- run unlocks ------------------------------------------------------------------

func _owned_snapshot() -> Dictionary:
	var out := {}
	for it in GameData.cosmetics():
		if is_owned_anywhere(it):
			out[it.id] = true
	return out


## Items that became owned during the current (or just finished) run.
func unlocked_this_run() -> Array[CosmeticItem]:
	var out: Array[CosmeticItem] = []
	if _owned_at_run_start.is_empty():
		return out
	for it in GameData.cosmetics():
		if not _owned_at_run_start.has(it.id) and is_owned_anywhere(it):
			out.append(it)
	return out
