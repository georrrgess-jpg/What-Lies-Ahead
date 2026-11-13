class_name LockerCatalog
extends RefCounted
## What the Locker and the Shop need to know about cosmetics: the categories
## (one tab per slot), an item's state for the player (equipped, owned, for
## sale, locked), the order and filters of the grid, and the text shown for
## requirements and progress towards them.
## An item may override its lock text with params.unlock_text.

## How the player stands with an item.
enum State {
	## Owned and worn in its slot (or the slot's default while nothing is equipped).
	EQUIPPED,
	OWNED,
	## Sold for Sparks and not bought yet (its requirement may still gate it).
	FOR_SALE,
	## Earned by a requirement that is not met yet.
	LOCKED,
}
## Which items a grid shows.
enum Filter { ALL, OWNED, FOR_SALE }

const CATEGORIES := [
	{"slot": &"avatar", "label": "Operators", "tab": "OPERATORS", "noun": "Operator", "sound": &"cos_equip_operator"},
	{"slot": &"weapon_finish", "label": "Weapon skins", "tab": "SKINS", "noun": "Weapon skin", "sound": &"cos_equip_finish"},
	{"slot": &"weapon_sight", "label": "Sights", "tab": "SIGHTS", "noun": "Sight", "sound": &"cos_equip_decal"},
	{"slot": &"weapon_charm", "label": "Charms", "tab": "CHARMS", "noun": "Charm", "sound": &"cos_equip_charm"},
	{"slot": &"weapon_cell", "label": "Cells", "tab": "CELLS", "noun": "Energy cell", "sound": &"cos_equip_cell"},
	{"slot": &"weapon_decal", "label": "Decals", "tab": "DECALS", "noun": "Decal", "sound": &"cos_equip_decal"},
	{"slot": &"gloves", "label": "Gloves", "tab": "GLOVES", "noun": "Gloves", "sound": &"cos_equip_gloves"},
	{"slot": &"kill_effect", "label": "Kill effects", "tab": "KILL FX", "noun": "Kill effect", "sound": &"cos_equip_effect"},
	{"slot": &"tracer", "label": "Tracers", "tab": "TRACERS", "noun": "Tracer", "sound": &"cos_equip_tracer"},
	{"slot": &"banner", "label": "Banners", "tab": "BANNERS", "noun": "Banner", "sound": &"cos_equip_banner"},
	{"slot": &"title", "label": "Titles", "tab": "TITLES", "noun": "Title", "sound": &"cos_equip_title"},
]
## Global slots whose preview still shows a weapon (so the weapon picker stays).
const SHOWN_ON_WEAPON: Array[StringName] = [&"gloves", &"tracer"]


static func category(slot: StringName) -> Dictionary:
	for c in CATEGORIES:
		if c["slot"] == slot:
			return c
	var text := String(slot).capitalize()
	return {"slot": slot, "label": text, "tab": text.to_upper(), "noun": text, "sound": &"cos_equip_finish"}


## "Weapon skin", "Operator"... for an item.
static func category_label(it: CosmeticItem) -> String:
	return String(category(it.slot)["noun"])


## True for slots equipped per weapon ("weapon_finish", "weapon_sight"...).
static func is_weapon_slot(slot: StringName) -> bool:
	return String(slot).begins_with("weapon_")


## True when the weapon picker matters for `slot`: per-weapon slots, and the
## global ones that are previewed on a weapon.
static func uses_weapon(slot: StringName) -> bool:
	return is_weapon_slot(slot) or slot in SHOWN_ON_WEAPON


## The weapon context of `slot`: `weapon_id` for per-weapon slots, else none.
static func context(slot: StringName, weapon_id: StringName) -> StringName:
	return weapon_id if is_weapon_slot(slot) else &""


## Slots that always show something (a default item) and so cannot be emptied.
static func has_default(slot: StringName) -> bool:
	return Cosmetics.default_item(slot) != null


## How the player stands with `it` (on `weapon_id` for weapon slots).
static func state(it: CosmeticItem, weapon_id: StringName = &"") -> State:
	var ctx := context(it.slot, weapon_id)
	if Cosmetics.is_owned(it, ctx):
		return State.EQUIPPED if Cosmetics.equipped_or_default(it.slot, ctx) == it else State.OWNED
	return State.FOR_SALE if Cosmetics.is_for_sale(it) else State.LOCKED


## Items of a slot for a grid: what is worn first, then the rest of what is
## owned, then what can be bought now (cheapest first), then what is still
## locked (closest to unlocking first). Data order breaks ties.
static func items(slot: StringName, weapon_id: StringName, filter := Filter.ALL) -> Array[CosmeticItem]:
	var ctx := context(slot, weapon_id)
	var rows: Array = []
	var index := 0
	for it in Cosmetics.items_for(slot, ctx):
		var st := state(it, weapon_id)
		if filter == Filter.OWNED and st > State.OWNED or filter == Filter.FOR_SALE and st != State.FOR_SALE:
			continue
		rows.append([_group(it, st, ctx), _rank_in_group(it, st, ctx), index, it])
		index += 1
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		for k in 3:
			if a[k] != b[k]:
				return a[k] < b[k]
		return false)
	var out: Array[CosmeticItem] = []
	for row in rows:
		out.append(row[3])
	return out


static func _group(it: CosmeticItem, st: State, ctx: StringName) -> int:
	if st == State.FOR_SALE and not Cosmetics.can_unlock_purchase(it, ctx):
		return 3
	return int(st) + (1 if st == State.LOCKED else 0)


static func _rank_in_group(it: CosmeticItem, st: State, ctx: StringName) -> float:
	match st:
		State.FOR_SALE:
			return float(Cosmetics.price_of(it))
		State.LOCKED:
			return 1.0 - maxf(0.0, progress(it, ctx))
	return 0.0


## Items owned (for any weapon) and items in total: one slot, or everything.
static func collection(slot: StringName = &"") -> Vector2i:
	var owned := 0
	var total := 0
	for it in GameData.cosmetics():
		if slot != &"" and it.slot != slot:
			continue
		total += 1
		if Cosmetics.is_owned_anywhere(it):
			owned += 1
	return Vector2i(owned, total)


# --- requirement text ---------------------------------------------------------------

## The full requirement, e.g. "Reach player level 5".
static func unlock_text(it: CosmeticItem) -> String:
	if it.params.has("unlock_text"):
		return String(it.params["unlock_text"])
	if Cosmetics.is_for_sale(it):
		var price := "In the shop for %s %s" % [Wallet.format(Cosmetics.price_of(it)), Wallet.CURRENCY]
		return price if it.requirement == null else "%s. %s" % [it.requirement.describe(), price]
	if it.requirement == null:
		return "Yours from the start"
	return it.requirement.describe()


## The requirement in a few characters for an item card: "Lv 5", "Rank 3".
static func unlock_short(it: CosmeticItem) -> String:
	var r := it.requirement
	if r == null:
		return ""
	match r.kind:
		Requirement.Kind.PLAYER_LEVEL:
			return "Lv %d" % r.amount
		Requirement.Kind.WEAPON_RANK:
			return "Rank %d" % r.amount
		Requirement.Kind.TOTAL_KILLS:
			return "%s kills" % compact(r.amount)
		Requirement.Kind.BEST_SCORE:
			return "Score %s" % compact(r.amount)
		Requirement.Kind.LEVEL_CLEARED:
			var level := GameData.level(r.target)
			return level.display_name if level else "Clear a level"
		Requirement.Kind.CHALLENGE:
			return "Challenge"
	return "Special"


## 0-1 progress towards unlocking `it`, or -1 when it has no measurable goal.
## `weapon_id` gives context for "rank on this weapon" requirements.
static func progress(it: CosmeticItem, weapon_id: StringName = &"") -> float:
	var r := it.requirement
	if r == null or not r.all_of.is_empty():
		return -1.0
	var goal := maxf(1.0, r.amount)
	match r.kind:
		Requirement.Kind.PLAYER_LEVEL:
			return clampf(float(Progression.level()) / goal, 0.0, 1.0)
		Requirement.Kind.TOTAL_KILLS:
			return clampf(float(Mastery.total_kills()) / goal, 0.0, 1.0)
		Requirement.Kind.BEST_SCORE:
			return clampf(float(Profile.best_score(r.target)) / goal, 0.0, 1.0)
		Requirement.Kind.WEAPON_RANK:
			var wid := r.target if r.target != &"" else weapon_id
			return clampf(float(Mastery.rank(wid)) / goal, 0.0, 1.0) if wid != &"" else -1.0
		Requirement.Kind.CHALLENGE:
			var ch := ChallengeBook.find(r.target)
			if ch and (ch.scope == Challenge.Scope.ACCOUNT or weapon_id != &""):
				return ChallengeBook.fraction(ch, weapon_id)
	return -1.0


## "Level 7 / 20", "412 / 1,000 kills"... matching progress().
static func progress_text(it: CosmeticItem, weapon_id: StringName = &"") -> String:
	var r := it.requirement
	if r == null or not r.all_of.is_empty():
		return ""
	match r.kind:
		Requirement.Kind.PLAYER_LEVEL:
			return "Level %d / %d" % [Progression.level(), r.amount]
		Requirement.Kind.TOTAL_KILLS:
			return "%s / %s kills" % [Wallet.format(Mastery.total_kills()), Wallet.format(r.amount)]
		Requirement.Kind.BEST_SCORE:
			return "Best %s / %s" % [Wallet.format(Profile.best_score(r.target)), Wallet.format(r.amount)]
		Requirement.Kind.WEAPON_RANK:
			var wid := r.target if r.target != &"" else weapon_id
			return "Rank %d / %d" % [Mastery.rank(wid), r.amount] if wid != &"" else ""
		Requirement.Kind.CHALLENGE:
			var ch := ChallengeBook.find(r.target)
			if ch and (ch.scope == Challenge.Scope.ACCOUNT or weapon_id != &""):
				return "%s / %s" % [Wallet.format(ChallengeBook.progress(ch, weapon_id)), Wallet.format(ch.goal)]
	return ""


## 1500 -> "1,500", 25000 -> "25k": amounts that must fit on a card.
static func compact(amount: int) -> String:
	if amount >= 10000 and amount % 1000 == 0:
		return "%dk" % (amount / 1000)
	return Wallet.format(amount)
