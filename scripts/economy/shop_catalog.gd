class_name ShopCatalog
extends RefCounted
## What the Sparks shop sells, for the Shop page to read. Everything is
## derived from the cosmetics data: an item is in the shop when it has a
## `price`. Buying goes through Cosmetics.buy(item, weapon_id), which charges
## price(item).
##
##   sections()   the shop by category, in display order
##   featured()   today's featured items, sold at a discount; the selection is
##                the same for the whole day and changes at local midnight
##   price() / base_price() / discount()   what an item costs right now
##   can_buy() / buy() / lock_text()       buying without weapon bookkeeping
##   is_new() / mark_seen()                NEW flags
##
## State lives in Profile.section("shop"): the day's featured ids and the ids
## the player has already looked at.

## Shop sections by cosmetic slot, in display order.
const SECTIONS := [
	{"slot": &"weapon_finish", "title": "Weapon Finishes"},
	{"slot": &"weapon_sight", "title": "Sights"},
	{"slot": &"weapon_cell", "title": "Energy Cells"},
	{"slot": &"gloves", "title": "Gloves"},
	{"slot": &"weapon_charm", "title": "Charms"},
	{"slot": &"kill_effect", "title": "Kill Effects"},
	{"slot": &"tracer", "title": "Tracers"},
	{"slot": &"weapon_decal", "title": "Decals"},
	{"slot": &"banner", "title": "Banners"},
	{"slot": &"title", "title": "Titles"},
	{"slot": &"avatar", "title": "Operators"},
]
const SECONDS_PER_DAY := 86400


## Every item with a price (owned or not), cheapest rarity first. `slot`
## narrows it to one section.
static func items(slot: StringName = &"") -> Array[CosmeticItem]:
	var out: Array[CosmeticItem] = []
	for it in GameData.cosmetics():
		if it.price > 0 and (slot == &"" or it.slot == slot):
			out.append(it)
	out.sort_custom(func(a, b): return a.price < b.price if a.price != b.price else a.sort_order < b.sort_order)
	return out


## The shop by category: [{ "slot", "title", "items" }], empty sections left out.
static func sections() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var listed := {}
	for section in SECTIONS:
		listed[section["slot"]] = true
		_add_section(out, section["slot"], section["title"])
	# Slots added later still get a section.
	for it in items():
		if not listed.has(it.slot):
			listed[it.slot] = true
			_add_section(out, it.slot, it.slot_label() + "s")
	return out


static func _add_section(out: Array[Dictionary], slot: StringName, title: String) -> void:
	var found := items(slot)
	if not found.is_empty():
		out.append({"slot": slot, "title": title, "items": found})


## Items the player does not own yet.
static func for_sale(slot: StringName = &"") -> Array[CosmeticItem]:
	return items(slot).filter(func(it): return Cosmetics.is_for_sale(it))


## [owned, total] items of the shop (or of one section).
static func progress(slot: StringName = &"") -> Vector2i:
	var all := items(slot)
	return Vector2i(all.size() - for_sale(slot).size(), all.size())


## Sparks it would take to buy everything still for sale, at full price.
static func remaining_cost() -> int:
	var total := 0
	for it in for_sale():
		total += it.price
	return total


# --- featured ------------------------------------------------------------------

## The local day number; the featured selection changes when it does.
static func day() -> int:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return int(floor((Time.get_unix_time_from_system() + bias) / SECONDS_PER_DAY))


## Seconds until the featured selection changes.
static func seconds_to_rotation() -> int:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var now := int(Time.get_unix_time_from_system()) + bias
	return SECONDS_PER_DAY - posmod(now, SECONDS_PER_DAY)


## Today's featured items (some may be owned by now: they stay listed, so
## buying one does not pull another into the discount).
static func featured() -> Array[CosmeticItem]:
	var sec := _sec()
	var today := day()
	if int(sec.get("day", -1)) != today:
		sec["day"] = today
		sec["featured"] = pick_featured(today).map(func(it): return String(it.id))
	var out: Array[CosmeticItem] = []
	for id in sec["featured"]:
		var it := Cosmetics.item(StringName(String(id)))
		if it and it.price > 0:
			out.append(it)
	return out


## The selection for `day_number`: deterministic for a day and a set of owned
## items. One item per rarity from the top down (so there is always a
## showpiece and something cheap), then the rest by the day's shuffle; items
## the player could not buy yet (locked by a requirement) are left out.
static func pick_featured(day_number: int) -> Array[CosmeticItem]:
	var pool: Array[CosmeticItem] = for_sale().filter(func(it): return is_open(it))
	pool.sort_custom(func(a, b): return _shuffle_key(day_number, a) < _shuffle_key(day_number, b))
	var count := mini(Wallet.rules.featured_count, pool.size())
	var out: Array[CosmeticItem] = []
	for rarity in [CosmeticItem.Rarity.LEGENDARY, CosmeticItem.Rarity.EPIC, CosmeticItem.Rarity.RARE, CosmeticItem.Rarity.COMMON]:
		for it in pool:
			if it.rarity == rarity and out.size() < count:
				out.append(it)
				break
	for it in pool:
		if out.size() >= count:
			break
		if not out.has(it):
			out.append(it)
	return out


static func is_featured(it: CosmeticItem) -> bool:
	return it != null and featured().has(it)


## The discount on `it` right now, 0-1 (0 unless it is featured today).
static func discount(it: CosmeticItem) -> float:
	return Wallet.rules.featured_discount if is_featured(it) else 0.0


## The full price.
static func base_price(it: CosmeticItem) -> int:
	return it.price if it else 0


## What `it` costs right now (discounted prices are rounded to 5 Sparks).
static func price(it: CosmeticItem) -> int:
	if it == null:
		return 0
	var off := discount(it)
	if off <= 0.0:
		return it.price
	return maxi(5, int(round(it.price * (1.0 - off) / 5.0)) * 5)


static func _shuffle_key(day_number: int, it: CosmeticItem) -> int:
	return hash("%d:%s" % [day_number, it.id])


# --- NEW flags -----------------------------------------------------------------

## For sale, open for purchase and not looked at yet: a new arrival (slots in
## EconomyRules.new_slots) or an item whose requirement was just met.
static func is_new(it: CosmeticItem) -> bool:
	if not Cosmetics.is_for_sale(it) or (_sec()["seen"] as Array).has(String(it.id)):
		return false
	return is_open(it) and (it.requirement != null or Wallet.rules.new_slots.has(it.slot))


## Marks an item as looked at. Call Profile.save_profile() when done browsing.
static func mark_seen(it: CosmeticItem) -> void:
	var seen: Array = _sec()["seen"]
	if it and not seen.has(String(it.id)):
		seen.append(String(it.id))


## New items in one section, or in the whole shop when `slot` is empty.
static func new_count(slot: StringName = &"") -> int:
	return for_sale(slot).filter(func(it): return is_new(it)).size()


## True when the item's requirement (if any) lets the player buy it. An item
## that fits every weapon and asks for a mastery rank opens with the first
## weapon to reach that rank.
static func is_open(it: CosmeticItem) -> bool:
	if it == null or it.requirement == null:
		return it != null
	if it.is_weapon_slot() and it.weapon_id == &"":
		return GameData.weapons().any(func(w): return Cosmetics.can_unlock_purchase(it, w.id))
	return Cosmetics.can_unlock_purchase(it, it.weapon_id)


## The weapon to buy `it` for: its own weapon, or for an item that fits every
## weapon and asks for a mastery rank, the first weapon with that rank.
static func buy_context(it: CosmeticItem) -> StringName:
	if it == null or it.weapon_id != &"" or it.requirement == null or not it.is_weapon_slot():
		return it.weapon_id if it else &""
	for w in GameData.weapons():
		if Cosmetics.can_unlock_purchase(it, w.id):
			return w.id
	return &""


## For sale, open and affordable right now.
static func can_buy(it: CosmeticItem) -> bool:
	return Cosmetics.can_buy(it, buy_context(it))


## Buys `it` at price(it) (Cosmetics.buy with the right weapon context).
## Returns false, changing nothing, if it cannot be bought.
static func buy(it: CosmeticItem) -> bool:
	return Cosmetics.buy(it, buy_context(it))


## Why `it` cannot be bought yet ("Ion Carbine mastery rank 5"), or "" if it is open.
static func lock_text(it: CosmeticItem) -> String:
	return "" if is_open(it) else it.requirement.describe()


## Items the player could buy right now.
static func affordable() -> Array[CosmeticItem]:
	return for_sale().filter(func(it): return can_buy(it))


static func _sec() -> Dictionary:
	var s := Profile.section("shop")
	if typeof(s.get("seen")) != TYPE_ARRAY:
		s["seen"] = []
	if typeof(s.get("featured")) != TYPE_ARRAY:
		s["featured"] = []
	return s
