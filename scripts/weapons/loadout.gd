class_name Loadout
extends RefCounted
## The two weapons the player carries into a run: a primary and a secondary.
## Each slot only takes its own class of weapon (WeaponData.slot_class):
## rifles, shotguns, launchers and beams go in the primary slot, pistols and
## other sidearms in the secondary. Chosen on the Arsenal page and saved in
## Profile.section("loadout") as {"primary": id, "secondary": id}.
##
## Reading the loadout repairs it: a locked or missing weapon, or one saved in
## the other class's slot by an older version, moves to its own slot if that
## is free, else gives way to a starter (STARTERS) or the first available
## weapon of the class. A saved loadout can never break a run.
##
## Also registers the loadout-station keys (cycle the active slot's weapon),
## which are added to the InputMap at runtime if the project does not define them.

const SECTION := "loadout"
const PRIMARY := 0
const SECONDARY := 1
const SLOT_KEYS := ["primary", "secondary"]
const SLOT_NAMES := ["Primary", "Secondary"]
## WeaponData.slot_class of each slot.
const SLOT_CLASSES := ["primary", "secondary"]
## What a new profile carries (if unlocked; else the first weapon of the class).
const STARTERS: Array[StringName] = [&"ion_carbine", &"pulse_pistol"]

## Loadout-station keys: action -> physical keycodes.
const KIOSK_ACTIONS := {
	&"kiosk_prev": [KEY_Z, KEY_LEFT],
	&"kiosk_next": [KEY_X, KEY_RIGHT],
}


## Every weapon the player can use right now, in menu order. With a slot
## index, only the weapons that slot takes.
static func available(slot_index := -1) -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for w in weapons_for(slot_index):
		if GameData.is_weapon_unlocked(w):
			out.append(w)
	return out


## Every weapon (locked ones too) that `slot_index` takes, in menu order;
## -1 for all of them.
static func weapons_for(slot_index: int) -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for w in GameData.weapons():
		if slot_index < 0 or slot_for(w) == slot_index:
			out.append(w)
	return out


## The slot a weapon belongs in: PRIMARY or SECONDARY (PRIMARY for null).
static func slot_for(w: WeaponData) -> int:
	return SECONDARY if w != null and w.slot_class == SLOT_CLASSES[SECONDARY] else PRIMARY


static func primary() -> StringName:
	return slot(PRIMARY)


static func secondary() -> StringName:
	return slot(SECONDARY)


## The weapon in `slot_index` (always one of that slot's class when the game has one).
static func slot(slot_index: int) -> StringName:
	return slots()[slot_index]


## The saved [primary, secondary], repaired (see the class notes). A repair is
## written back into the profile's memory, so the next save keeps it.
static func slots() -> Array[StringName]:
	var section := Profile.section(SECTION)
	var saved: Array[StringName] = [_saved_id(section, PRIMARY), _saved_id(section, SECONDARY)]
	var out := resolve(saved, StringName(String(Profile.data.get("last_weapon", ""))))
	for i in 2:
		if out[i] != saved[i] and out[i] != &"":
			section[SLOT_KEYS[i]] = String(out[i])
	return out


## A valid [primary, secondary] from saved ids. Ids already in their own
## class's slot stay; a misplaced one moves to its own slot if that is still
## empty; `fallback` (the starter weapon of saves from before the two-slot
## loadout) fills its slot next; then the starters and the first available
## weapon of each class.
static func resolve(saved: Array[StringName], fallback: StringName = &"") -> Array[StringName]:
	var out: Array[StringName] = [&"", &""]
	for i in 2:
		if _usable(saved[i]) and slot_for(GameData.weapon(saved[i])) == i:
			out[i] = saved[i]
	for id: StringName in [saved[0], saved[1], fallback]:
		var own := slot_for(GameData.weapon(id))
		if _usable(id) and out[own] == &"":
			out[own] = id
	for i in 2:
		if out[i] == &"":
			out[i] = _default(i)
	return out


## Puts `weapon_id` in its own class's slot (`slot_index`) and saves the
## profile. Returns false for locked or unknown weapons and for a weapon of
## the other class.
static func set_slot(slot_index: int, weapon_id: StringName) -> bool:
	if slot_index < PRIMARY or slot_index > SECONDARY or not _usable(weapon_id):
		return false
	if slot_for(GameData.weapon(weapon_id)) != slot_index:
		return false
	var current := slots()
	current[slot_index] = weapon_id
	var section := Profile.section(SECTION)
	for i in 2:
		section[SLOT_KEYS[i]] = String(current[i])
	Profile.save_profile()
	return true


## Puts `weapon_id` in the slot of its class (see set_slot).
static func equip(weapon_id: StringName) -> bool:
	return set_slot(slot_for(GameData.weapon(weapon_id)), weapon_id)


## Which slot holds `weapon_id` (-1 if neither).
static func slot_of(weapon_id: StringName) -> int:
	return slots().find(weapon_id)


## The [primary, secondary] for a run. `override` (from the dev tools or the
## screenshot staging; locked weapons allowed) replaces the saved weapon of
## its own class's slot.
static func run_slots(override: StringName = &"") -> Array[StringName]:
	var out := slots()
	var w := GameData.weapon(override)
	if w != null:
		out[slot_for(w)] = override
	return out


## Adds the loadout-station actions to the InputMap unless the project has them.
static func ensure_input_actions() -> void:
	for action in KIOSK_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in KIOSK_ACTIONS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event(action, e)


## Short key names for an action ("Z / Left"), for prompts.
static func key_hint(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	var names: Array[String] = []
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var code: Key = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
			names.append(OS.get_keycode_string(code))
	return " / ".join(names)


static func _saved_id(section: Dictionary, slot_index: int) -> StringName:
	return StringName(String(section.get(SLOT_KEYS[slot_index], "")))


static func _usable(weapon_id: StringName) -> bool:
	return weapon_id != &"" and GameData.is_weapon_unlocked(GameData.weapon(weapon_id))


## The starter of a slot, else its first available weapon, else (a game
## without such a weapon) the first weapon at all.
static func _default(slot_index: int) -> StringName:
	if _usable(STARTERS[slot_index]) and slot_for(GameData.weapon(STARTERS[slot_index])) == slot_index:
		return STARTERS[slot_index]
	var options := available(slot_index)
	if not options.is_empty():
		return options[0].id
	return GameData.default_weapon_id()
