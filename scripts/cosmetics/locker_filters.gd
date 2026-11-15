class_name LockerFilters
extends RefCounted
## How the Locker groups, sorts and filters what it shows: the four groups of
## categories (CHARACTER, WEAPON, EFFECTS, PROFILE; the WEAPON group also has
## the player's Prize Prints), where an item comes from (shop, prints, level,
## mastery, world, milestone, Endless, starter), and one filter state per tab (sort,
## what to show, source, search text) that the page keeps while it is open.

## The tab id of the Prize Prints list (not a cosmetic slot).
const PRINTS := &"prints"

## Top-level groups: the categories under each, in tab order.
const GROUPS := [
	{"id": &"character", "label": "CHARACTER", "slots": [&"avatar", &"gloves"]},
	{"id": &"weapon", "label": "WEAPON", "slots": [&"weapon_finish", PRINTS, &"weapon_sight", &"weapon_cell", &"weapon_charm", &"weapon_decal"]},
	{"id": &"effects", "label": "EFFECTS", "slots": [&"kill_effect", &"tracer"]},
	{"id": &"profile", "label": "PROFILE", "slots": [&"banner", &"title"]},
]

enum Sort { FEATURED, RARITY_DESC, RARITY_ASC, NAME, NEWEST }
const SORT_NAMES := ["FEATURED", "RARITY ▼", "RARITY ▲", "NAME A-Z", "NEWEST"]
const SORT_HINTS := [
	"What you wear first, then what you own, what is for sale and what is closest to unlocking.",
	"Rarest first.", "Most common first.", "Alphabetical.", "New to you first, then the latest additions.",
]

enum Show { ALL, OWNED, LOCKED, FOR_SALE }
const SHOW_NAMES := ["ALL", "OWNED", "LOCKED", "FOR SALE"]
## The Prints tab's own "show" choices.
enum PrintShow { ALL, FITS, WORN, KEPT }
const PRINT_SHOW_NAMES := ["ALL", "FITS THIS GUN", "WORN", "KEPT ♥"]

enum Source { ANY, SHOP, PRINTS, LEVEL, MASTERY, WORLD, MILESTONE, STARTER, ENDLESS }
const SOURCE_NAMES := ["ANY", "SHOP", "PRINTS", "LEVEL", "MASTERY", "WORLD", "MILESTONE", "STARTER", "ENDLESS"]
## How an item of each source is obtained, for the details panel.
const SOURCE_TEXT := ["", "Shop", "Prize Prints", "Level reward", "Mastery reward", "World reward", "Milestone", "Starter", "Endless reward"]


## One tab's filter choices.
class State:
	var sort := Sort.FEATURED
	var show := 0
	var source := Source.ANY
	var search := ""

	## True when anything narrows the list (the sort does not).
	func narrows() -> bool:
		return show != 0 or source != Source.ANY or search.strip_edges() != ""

	func clear() -> void:
		show = 0
		source = Source.ANY
		search = ""


static func group_of(slot: StringName) -> Dictionary:
	for g in GROUPS:
		if slot in g["slots"]:
			return g
	return GROUPS[0]


## Every tab id in order, across the groups (A / D walk this list).
static func all_tabs() -> Array[StringName]:
	var out: Array[StringName] = []
	for g in GROUPS:
		for slot in g["slots"]:
			out.append(slot)
	return out


static func tab_label(slot: StringName) -> String:
	return "PRINTS" if slot == PRINTS else String(LockerCatalog.category(slot)["tab"])


## Where an item comes from.
static func source_of(it: CosmeticItem) -> Source:
	if it.slot == &"weapon_finish" and PrizePrints.in_series(it.id):
		return Source.PRINTS
	if it.price > 0:
		return Source.SHOP
	var r := it.requirement
	if r == null:
		return Source.STARTER
	match r.kind:
		Requirement.Kind.PLAYER_LEVEL:
			return Source.LEVEL
		Requirement.Kind.WEAPON_RANK:
			return Source.MASTERY
		Requirement.Kind.LEVEL_CLEARED, Requirement.Kind.BEST_SCORE:
			return Source.WORLD
		Requirement.Kind.NONE:
			return Source.STARTER
		Requirement.Kind.ENDLESS_WAVE, Requirement.Kind.ENDLESS_DISTRICT:
			return Source.ENDLESS
	return Source.MILESTONE


static func source_text(it: CosmeticItem) -> String:
	return SOURCE_TEXT[source_of(it)]


## The items of a slot as `state` asks: filtered, then sorted.
static func items(slot: StringName, weapon_id: StringName, state: State) -> Array[CosmeticItem]:
	var base := LockerCatalog.items(slot, weapon_id)
	var order := {}
	for i in base.size():
		order[base[i]] = i
	var needle := state.search.strip_edges().to_lower()
	var out: Array[CosmeticItem] = []
	for it in base:
		var st := LockerCatalog.state(it, weapon_id)
		match state.show:
			Show.OWNED:
				if st > LockerCatalog.State.OWNED:
					continue
			Show.LOCKED:
				if st != LockerCatalog.State.LOCKED:
					continue
			Show.FOR_SALE:
				if st != LockerCatalog.State.FOR_SALE:
					continue
		if state.source != Source.ANY and source_of(it) != state.source:
			continue
		if needle != "" and not it.display_name.to_lower().contains(needle):
			continue
		out.append(it)
	var catalogue := GameData.cosmetics()
	match state.sort:
		Sort.RARITY_DESC, Sort.RARITY_ASC:
			var sign := -1 if state.sort == Sort.RARITY_DESC else 1
			out.sort_custom(func(a: CosmeticItem, b: CosmeticItem) -> bool:
				return a.rarity * sign < b.rarity * sign if a.rarity != b.rarity else order[a] < order[b])
		Sort.NAME:
			out.sort_custom(func(a: CosmeticItem, b: CosmeticItem) -> bool: return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
		Sort.NEWEST:
			out.sort_custom(func(a: CosmeticItem, b: CosmeticItem) -> bool:
				var na := Cosmetics.is_new(a)
				if na != Cosmetics.is_new(b):
					return na
				return catalogue.find(a) > catalogue.find(b))
	return out


## The prints held, as `state` asks (`weapon_id` is the weapon being customised).
static func prints(weapon_id: StringName, state: State) -> Array:
	var needle := state.search.strip_edges().to_lower()
	var out: Array = []
	for p in PrizePrints.held():
		match state.show:
			PrintShow.FITS:
				if not PrizePrints.fits(p, weapon_id):
					continue
			PrintShow.WORN:
				if PrizePrints.worn_on(p).is_empty():
					continue
			PrintShow.KEPT:
				if not bool(p.get("fav", false)):
					continue
		if needle != "" and not (PrintLook.title(p).to_lower().contains(needle) or PrintLook.serial_text(int(p.get("serial", 0))).contains(needle)):
			continue
		out.append(p)
	var worn := PrizePrints.equipped(weapon_id)
	match state.sort:
		Sort.FEATURED:
			out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				if (a == worn) != (b == worn):
					return a == worn
				return PrintLook.score(a) > PrintLook.score(b))
		Sort.RARITY_DESC, Sort.RARITY_ASC:
			var sign := -1 if state.sort == Sort.RARITY_DESC else 1
			out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var ra := PrizePrints.rarity(a)
				var rb := PrizePrints.rarity(b)
				return ra * sign < rb * sign if ra != rb else PrintLook.score(a) > PrintLook.score(b))
		Sort.NAME:
			out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var c := PrintLook.title(a).naturalnocasecmp_to(PrintLook.title(b))
				return c < 0 if c != 0 else int(a.get("serial", 0)) < int(b.get("serial", 0)))
		Sort.NEWEST:
			out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("minted", 0)) > int(b.get("minted", 0)))
	return out
