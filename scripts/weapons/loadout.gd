class_name Loadout
extends RefCounted
## The two weapons the player carries into a run: a primary and a secondary.
## Chosen on the Arsenal page and saved in Profile.section("loadout") as
## {"primary": id, "secondary": id}. Locked or missing weapons fall back to
## the first available ones, so a saved loadout can never break a run.
##
## Also registers the loadout-station keys (cycle the active slot's weapon),
## which are added to the InputMap at runtime if the project does not define them.

const SECTION := "loadout"
const PRIMARY := 0
const SECONDARY := 1
const SLOT_KEYS := ["primary", "secondary"]
const SLOT_NAMES := ["Primary", "Secondary"]

## Loadout-station keys: action -> physical keycodes.
const KIOSK_ACTIONS := {
	&"kiosk_prev": [KEY_Z, KEY_LEFT],
	&"kiosk_next": [KEY_X, KEY_RIGHT],
}


## Every weapon the player can use right now, in menu order.
static func available() -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for w in GameData.weapons():
		if GameData.is_weapon_unlocked(w):
			out.append(w)
	return out


static func primary() -> StringName:
	return slot(PRIMARY)


static func secondary() -> StringName:
	return slot(SECONDARY)


## The weapon saved in `slot_index`, or a sensible available default.
static func slot(slot_index: int) -> StringName:
	var saved := StringName(String(Profile.section(SECTION).get(SLOT_KEYS[slot_index], "")))
	var other := StringName(String(Profile.section(SECTION).get(SLOT_KEYS[1 - slot_index], "")))
	if _usable(saved) and (slot_index == PRIMARY or saved != _resolved_primary()):
		return saved
	if slot_index == PRIMARY:
		return _first_available([])
	return _first_available([_resolved_primary(), other])


## Puts `weapon_id` in a slot. If it is already in the other slot the two
## swap places. Saves the profile. Returns false for locked or unknown weapons.
static func set_slot(slot_index: int, weapon_id: StringName) -> bool:
	if slot_index < PRIMARY or slot_index > SECONDARY or not _usable(weapon_id):
		return false
	var section := Profile.section(SECTION)
	var current := [primary(), secondary()]
	if current[1 - slot_index] == weapon_id:
		section[SLOT_KEYS[1 - slot_index]] = String(current[slot_index])
	section[SLOT_KEYS[slot_index]] = String(weapon_id)
	Profile.save_profile()
	return true


## Which slot holds `weapon_id` (-1 if neither).
static func slot_of(weapon_id: StringName) -> int:
	if weapon_id == primary():
		return PRIMARY
	if weapon_id == secondary():
		return SECONDARY
	return -1


## The [primary, secondary] for a run. `primary_override` (from the Play page
## or the dev bot) replaces the saved primary; the saved primary then becomes
## the secondary if the override was the saved secondary.
static func run_slots(primary_override: StringName = &"") -> Array[StringName]:
	var first := primary()
	var second := secondary()
	if GameData.weapon(primary_override) != null and primary_override != first:
		if primary_override == second:
			second = first
		first = primary_override
	if second == first:
		second = _first_available([first])
	return [first, second] as Array[StringName]


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


static func _usable(weapon_id: StringName) -> bool:
	return GameData.is_weapon_unlocked(GameData.weapon(weapon_id))


static func _resolved_primary() -> StringName:
	return slot(PRIMARY)


static func _first_available(exclude: Array) -> StringName:
	for w in available():
		if not exclude.has(w.id):
			return w.id
	return GameData.default_weapon_id()
