class_name EndlessRewards
extends RefCounted
## What Endless unlocks, read from the catalog (never hard-coded): every
## cosmetic and weapon whose requirement is ENDLESS_WAVE or ENDLESS_DISTRICT.
## The Play page shows them as a reward track and the results screen lists
## the ones a run just earned.
##
## An entry: {"item": CosmeticItem or WeaponData, "name", "kind" ("Weapon",
## "Camo", ...), "color" (rarity), "wave" (0 for a district reward),
## "district" (id, &"" for a wave reward), "goal" ("WAVE 10", "OPEN METRO
## LINE"), "met" (bool)}.


## Every Endless reward of `rules`: wave rewards by wave, then district
## rewards in the rules' order.
static func track(rules: EndlessRules) -> Array:
	var waves: Array = []
	var districts: Array = []
	for w in GameData.weapons():
		_add(w, w.unlock, w.display_name, "Weapon", CosmeticItem.rarity_color(CosmeticItem.Rarity.LEGENDARY), rules, waves, districts)
	for it in GameData.cosmetics():
		var kind := "%s %s" % [CosmeticItem.rarity_name(it.rarity), _slot_name(it)]
		_add(it, it.requirement, it.display_name, kind, CosmeticItem.rarity_color(it.rarity), rules, waves, districts)
	waves.sort_custom(func(a, b): return int(a["wave"]) < int(b["wave"]))
	var order := rules.districts.map(func(d: EndlessDistrict) -> StringName: return d.id)
	districts.sort_custom(func(a, b): return order.find(a["district"]) < order.find(b["district"]))
	return waves + districts


## The rewards a run earned: wave rewards past `best_before` up to
## `best_now`, and those of the districts in `first_opened`.
static func earned(rules: EndlessRules, best_before: int, best_now: int, first_opened: Array) -> Array:
	var out: Array = []
	for e in track(rules):
		var wave := int(e["wave"])
		if (wave > best_before and wave <= best_now) or (e["district"] != &"" and String(e["district"]) in first_opened):
			out.append(e)
	return out


## The first reward not yet earned, or {}.
static func next_goal(rules: EndlessRules) -> Dictionary:
	for e in track(rules):
		if not e["met"] and int(e["wave"]) > 0:
			return e
	return {}


static func _add(item: Resource, req: Requirement, display: String, kind: String, color: Color, rules: EndlessRules, waves: Array, districts: Array) -> void:
	if req == null or not req.kind in [Requirement.Kind.ENDLESS_WAVE, Requirement.Kind.ENDLESS_DISTRICT]:
		return
	var entry := {"item": item, "name": display, "kind": kind, "color": color, "met": req.is_met(),
		"wave": req.amount if req.kind == Requirement.Kind.ENDLESS_WAVE else 0,
		"district": req.target if req.kind == Requirement.Kind.ENDLESS_DISTRICT else &""}
	if req.kind == Requirement.Kind.ENDLESS_WAVE:
		entry["goal"] = "WAVE %d" % req.amount
		waves.append(entry)
	else:
		var d := rules.district(req.target)
		entry["goal"] = "OPEN %s" % (d.display_name.to_upper() if d else String(req.target).to_upper())
		districts.append(entry)


static func _slot_name(it: CosmeticItem) -> String:
	return "Camo" if it.slot == &"weapon_finish" else it.slot_label()
