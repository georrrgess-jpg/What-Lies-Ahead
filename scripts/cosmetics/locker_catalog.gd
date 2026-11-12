class_name LockerCatalog
extends RefCounted
## Locker categories (one tab per cosmetic slot) and the text the Locker shows
## for items: category names, unlock requirements and progress towards them.
## An item may override its lock text with params.unlock_text.

const CATEGORIES := [
	{"slot": &"avatar", "label": "Operators", "noun": "Operator", "sound": &"cos_equip_operator"},
	{"slot": &"weapon_finish", "label": "Weapon skins", "noun": "Weapon skin", "sound": &"cos_equip_finish"},
	{"slot": &"weapon_sight", "label": "Sights", "noun": "Sight", "sound": &"cos_equip_decal"},
	{"slot": &"weapon_charm", "label": "Charms", "noun": "Charm", "sound": &"cos_equip_charm"},
	{"slot": &"weapon_cell", "label": "Cells", "noun": "Energy cell", "sound": &"cos_equip_cell"},
	{"slot": &"weapon_decal", "label": "Decals", "noun": "Decal", "sound": &"cos_equip_decal"},
	{"slot": &"gloves", "label": "Gloves", "noun": "Gloves", "sound": &"cos_equip_gloves"},
	{"slot": &"kill_effect", "label": "Kill effects", "noun": "Kill effect", "sound": &"cos_equip_effect"},
	{"slot": &"tracer", "label": "Tracers", "noun": "Tracer", "sound": &"cos_equip_tracer"},
	{"slot": &"banner", "label": "Banners", "noun": "Banner", "sound": &"cos_equip_banner"},
	{"slot": &"title", "label": "Titles", "noun": "Title", "sound": &"cos_equip_title"},
]


static func category(slot: StringName) -> Dictionary:
	for c in CATEGORIES:
		if c["slot"] == slot:
			return c
	return {"slot": slot, "label": String(slot).capitalize(), "noun": String(slot).capitalize(), "sound": &"cos_equip_finish"}


## "Weapon skin", "Operator"... for an item.
static func category_label(it: CosmeticItem) -> String:
	return String(category(it.slot)["noun"])


## Slots that always show something (a default item) and so cannot be emptied.
static func has_default(slot: StringName) -> bool:
	return Cosmetics.default_item(slot) != null


## Items of a slot for the Locker grid: owned ones first, each group in data order.
static func items(slot: StringName, weapon_id: StringName) -> Array[CosmeticItem]:
	var owned: Array[CosmeticItem] = []
	var locked: Array[CosmeticItem] = []
	for it in Cosmetics.items_for(slot, weapon_id if String(slot).begins_with("weapon_") else &""):
		if Cosmetics.is_owned(it, weapon_id):
			owned.append(it)
		else:
			locked.append(it)
	return owned + locked


static func unlock_text(it: CosmeticItem) -> String:
	if it.params.has("unlock_text"):
		return String(it.params["unlock_text"])
	if Cosmetics.is_for_sale(it):
		var price := "In the shop for %s %s" % [Wallet.format(Cosmetics.price_of(it)), Wallet.CURRENCY]
		return price if it.requirement == null else "%s. %s" % [it.requirement.describe(), price]
	if it.requirement == null:
		return "Yours from the start"
	return it.requirement.describe()


## 0-1 progress towards unlocking `it`, or -1 when it has no measurable goal.
static func progress(it: CosmeticItem) -> float:
	var r := it.requirement
	if r == null or not r.all_of.is_empty():
		return -1.0
	match r.kind:
		Requirement.Kind.PLAYER_LEVEL:
			return clampf(float(Progression.level()) / maxf(1.0, r.amount), 0.0, 1.0)
		Requirement.Kind.TOTAL_KILLS:
			return clampf(float(Mastery.total_kills()) / maxf(1.0, r.amount), 0.0, 1.0)
		Requirement.Kind.BEST_SCORE:
			return clampf(float(Profile.best_score(r.target)) / maxf(1.0, r.amount), 0.0, 1.0)
	return -1.0


## "Level 7 / 20", "412 / 1,000 kills"... matching progress().
static func progress_text(it: CosmeticItem) -> String:
	var r := it.requirement
	if r == null:
		return ""
	match r.kind:
		Requirement.Kind.PLAYER_LEVEL:
			return "Level %d / %d" % [Progression.level(), r.amount]
		Requirement.Kind.TOTAL_KILLS:
			return "%s / %s kills" % [PlayerCard._thousands(Mastery.total_kills()), PlayerCard._thousands(r.amount)]
		Requirement.Kind.BEST_SCORE:
			return "Best %s / %s" % [PlayerCard._thousands(Profile.best_score(r.target)), PlayerCard._thousands(r.amount)]
	return ""
