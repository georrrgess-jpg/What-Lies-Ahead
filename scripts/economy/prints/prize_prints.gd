class_name PrizePrints
extends RefCounted
## Prize Prints: numbered, rolled copies of weapon finishes that drop from
## Prize Capsules (docs/ECONOMY.md, "Prize Prints").
##
## A print is a Dictionary saved in the profile:
##   { "id": "p12", "f": finish id, "w": weapon fit ("" = any weapon),
##     "seed": 0-9999, "shine": 0-1, "var": "" | glitter | holo | misprint,
##     "serial": int, "minted": unix seconds, "fav": bool, "new": bool,
##     "src": capsule | tradeup | counter }
## A print is its own collectible: it neither grants nor removes the plain
## finish. Equipping one (per weapon) makes it the weapon's finish wherever
## Cosmetics.weapon_loadout() is read; equipping a plain finish takes it off.
##
## State lives in Profile.section("prints") (schema SCHEMA, see _migrate).
## Changes emit Cosmetics.prints_changed; call sites need not save, every
## change here saves the profile.

const SCHEMA := 1
const SERIES_PATH := "res://data/prints/series_1.tres"

static var rng := RandomNumberGenerator.new()
static var _series: PrintSeries
static var _by_rarity := {}
## True while this class itself announces an equip change (see _announce).
static var _equipping := false
## The run being settled: reasons capsules were earned during it.
static var _run_lines: Array = []
static var _run_settled := false


static func series() -> PrintSeries:
	if _series == null:
		_series = load(SERIES_PATH) as PrintSeries
		rng.randomize()
	return _series


## Finish ids of the series by rarity: { rarity: [ids] }.
static func by_rarity() -> Dictionary:
	if _by_rarity.is_empty():
		for fid in series().finishes:
			var it := Cosmetics.item(fid)
			if it:
				var r := mini(int(it.rarity), PrintRoll.LEGENDARY)
				if not _by_rarity.has(r):
					_by_rarity[r] = []
				(_by_rarity[r] as Array).append(fid)
	return _by_rarity


static func in_series(finish_id: StringName) -> bool:
	return finish_id in series().finishes


# --- state ------------------------------------------------------------------------

static func _sec() -> Dictionary:
	var s := Profile.section("prints")
	if int(s.get("v", 0)) < SCHEMA:
		_migrate(s)
	return s


## Brings a section up to SCHEMA. A save from before prints has none: it
## starts empty (no prints, no capsules). Unknown keys are kept.
static func _migrate(s: Dictionary) -> void:
	var blank := {
		"next_id": 1, "serials": {}, "list": [], "equipped": {}, "capsules": 0, "tokens": 0,
		"since_epic": 0, "since_legendary": 0, "opened": 0, "minted": 0, "contracts": 0,
		"daily": -1, "auto_recycle": true, "counter": {}, "earned": 0,
	}
	for k in blank:
		if not s.has(k):
			s[k] = blank[k]
	s["v"] = SCHEMA


static func _changed() -> void:
	Profile.save_profile()
	Cosmetics.prints_changed.emit()


static func capsules() -> int:
	return int(_sec()["capsules"])


static func tokens() -> int:
	return int(_sec()["tokens"])


static func auto_recycle() -> bool:
	return bool(_sec()["auto_recycle"])


static func set_auto_recycle(on: bool) -> void:
	_sec()["auto_recycle"] = on
	_changed()


## Capsules opened ever.
static func opened() -> int:
	return int(_sec()["opened"])


## Capsules left until the luck meter guarantees: Vector2i(epic, legendary).
static func luck() -> Vector2i:
	var s := _sec()
	return Vector2i(series().epic_pity - int(s["since_epic"]), series().legendary_pity - int(s["since_legendary"]))


## Gives `n` capsules (a reward). Saves.
static func add_capsules(n: int) -> void:
	if n <= 0:
		return
	var s := _sec()
	s["capsules"] = capsules() + n
	s["earned"] = int(s["earned"]) + n
	_changed()


static func can_buy_capsule() -> bool:
	return Wallet.can_afford(series().capsule_price)


## Buys one capsule with Sparks. False (nothing changed) if too expensive.
static func buy_capsule() -> bool:
	if not Wallet.spend(series().capsule_price, &"prize_capsule"):
		return false
	_sec()["capsules"] = capsules() + 1
	_changed()
	return true


# --- prints -----------------------------------------------------------------------

## Every print held, oldest first.
static func held() -> Array:
	return _sec()["list"]


static func get_print(id: String) -> Dictionary:
	for p in held():
		if String(p["id"]) == id:
			return p
	return {}


## The prints held of one finish.
static func prints_of(finish_id: StringName) -> Array:
	return held().filter(func(p): return StringName(String(p["f"])) == finish_id)


## True when a print of the finish is held.
static func holds(finish_id: StringName) -> bool:
	for p in held():
		if StringName(String(p["f"])) == finish_id:
			return true
	return false


static func finish_of(p: Dictionary) -> CosmeticItem:
	return Cosmetics.item(StringName(String(p.get("f", "")))) if not p.is_empty() else null


static func rarity(p: Dictionary) -> int:
	var fin := finish_of(p)
	return mini(int(fin.rarity), PrintRoll.LEGENDARY) if fin else 0


static func grade(p: Dictionary) -> int:
	return PrintRoll.grade(float(p.get("shine", 0.0)), series())


## Worth keeping even as a repeat: Mint, a rare print, or a low serial.
static func is_notable(p: Dictionary) -> bool:
	return grade(p) == 2 or String(p.get("var", "")) != "" or PrintLook.serial_tag(int(p.get("serial", 0))) != ""


static func fits(p: Dictionary, weapon_id: StringName) -> bool:
	var w := String(p.get("w", ""))
	return w == "" or StringName(w) == weapon_id


## Prints not looked at yet.
static func new_count() -> int:
	return held().filter(func(p): return bool(p.get("new", false))).size()


static func mark_seen(p: Dictionary) -> void:
	if bool(p.get("new", false)):
		p["new"] = false
		_changed()


static func set_favourite(p: Dictionary, on: bool) -> void:
	p["fav"] = on
	_changed()


# --- equipping --------------------------------------------------------------------

## The print worn on a weapon, or {}.
static func equipped(weapon_id: StringName) -> Dictionary:
	var id := String(_sec()["equipped"].get(String(weapon_id), ""))
	return get_print(id) if id != "" else {}


## The weapons a print is worn on.
static func worn_on(p: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var eq: Dictionary = _sec()["equipped"]
	for w in eq:
		if String(eq[w]) == String(p.get("id", "")):
			out.append(StringName(w))
	return out


## Wears `p` on a weapon (its finish becomes the print). Saves.
static func equip(p: Dictionary, weapon_id: StringName) -> bool:
	if p.is_empty() or not fits(p, weapon_id) or GameData.weapon(weapon_id) == null:
		return false
	_sec()["equipped"][String(weapon_id)] = String(p["id"])
	_changed()
	_announce(weapon_id)
	return true


## Takes the print off a weapon (its plain finish shows again). Saves.
static func take_off(weapon_id: StringName) -> void:
	var eq: Dictionary = _sec()["equipped"]
	if not eq.has(String(weapon_id)):
		return
	eq.erase(String(weapon_id))
	_changed()
	_announce(weapon_id)


## Tells weapon previews to refresh without taking the print back off
## (on_finish_equipped listens to the same signal).
static func _announce(weapon_id: StringName) -> void:
	_equipping = true
	Cosmetics.equipped_changed.emit(&"weapon_finish", weapon_id)
	_equipping = false


## Cosmetics.equipped_changed: a plain finish equipped on a weapon replaces its print.
static func on_finish_equipped(slot: StringName, weapon_id: StringName) -> void:
	if not _equipping and slot == &"weapon_finish" and weapon_id != &"":
		take_off(weapon_id)


# --- capsules, minting ------------------------------------------------------------

## Opens a capsule. Returns {} without a capsule, else
## { "print", "repeat", "recycled", "tokens", "rarity", "lucky" } (see _mint;
## "lucky": the luck meter forced this rarity).
static func open_capsule() -> Dictionary:
	if capsules() <= 0:
		return {}
	var s := _sec()
	s["capsules"] = capsules() - 1
	var result := roll_capsule()
	_changed()
	return result


## The roll of one capsule (no capsule taken; the probe calls this directly).
static func roll_capsule() -> Dictionary:
	var s := _sec()
	var since_epic := int(s["since_epic"])
	var since_legendary := int(s["since_legendary"])
	var r := PrintRoll.rarity(rng, series(), since_epic, since_legendary)
	var lucky := (r == PrintRoll.LEGENDARY and since_legendary + 1 >= series().legendary_pity) or (r >= PrintRoll.EPIC and since_epic + 1 >= series().epic_pity)
	s["since_epic"] = 0 if r >= PrintRoll.EPIC else since_epic + 1
	s["since_legendary"] = 0 if r == PrintRoll.LEGENDARY else since_legendary + 1
	s["opened"] = opened() + 1
	var result := _mint(PrintRoll.finish(rng, by_rarity(), r), "capsule")
	result["lucky"] = lucky
	return result


## Makes a new print of `finish_id` with fresh rolls and the next serial.
## A plain repeat from a capsule becomes Capsule Credits ("tokens" in code and
## saves) when auto-recycle is on.
## Returns { "print", "repeat", "recycled", "tokens", "rarity" }.
static func _mint(finish_id: StringName, src: String) -> Dictionary:
	var s := _sec()
	var serials: Dictionary = s["serials"]
	var serial := int(serials.get(String(finish_id), 0)) + 1
	serials[String(finish_id)] = serial
	var fin := Cosmetics.item(finish_id)
	var p := {
		"id": "p%d" % int(s["next_id"]), "f": String(finish_id), "w": String(fin.weapon_id) if fin else "",
		"serial": serial, "minted": int(Time.get_unix_time_from_system()), "fav": false, "new": true, "src": src,
	}
	p.merge(PrintRoll.attributes(rng, series()))
	s["next_id"] = int(s["next_id"]) + 1
	s["minted"] = int(s["minted"]) + 1
	var repeat := holds(finish_id)
	var result := {"print": p, "repeat": repeat, "recycled": false, "tokens": 0, "rarity": rarity(p)}
	if repeat and src == "capsule" and auto_recycle() and not is_notable(p):
		result["recycled"] = true
		result["tokens"] = token_value(p)
		s["tokens"] = tokens() + int(result["tokens"])
	else:
		(s["list"] as Array).append(p)
	return result


static func token_value(p: Dictionary) -> int:
	return series().token_value[rarity(p)]


static func can_recycle(p: Dictionary) -> bool:
	return not p.is_empty() and not bool(p.get("fav", false)) and worn_on(p).is_empty()


## Turns a print into Capsule Credits. Returns the tokens (0 if it may not go).
static func recycle(p: Dictionary) -> int:
	if not can_recycle(p) or not held().has(p):
		return 0
	var value := token_value(p)
	held().erase(p)
	_sec()["tokens"] = tokens() + value
	_changed()
	return value


# --- trade-up ---------------------------------------------------------------------

## Why these prints cannot be traded up, or "" when they can.
static func trade_up_problem(picked: Array) -> String:
	if picked.size() != series().trade_up_count:
		return "Pick %d prints of one rarity." % series().trade_up_count
	var r := rarity(picked[0])
	var ids := {}
	for p in picked:
		ids[String(p.get("id", ""))] = true
	if ids.size() != picked.size():
		return "Pick five different prints."
	for p in picked:
		if rarity(p) != r:
			return "All five must be the same rarity."
		if bool(p.get("fav", false)):
			return "Favourites are protected."
		if not worn_on(p).is_empty():
			return "Take the print off its weapon first."
		if not held().has(p):
			return "That print is gone."
	if r >= PrintRoll.LEGENDARY:
		return "Legendary is the top rarity."
	return ""


## Five prints of one rarity in, one fresh print of the next rarity out.
## Returns the _mint result, or {} if trade_up_problem() objects.
static func trade_up(picked: Array) -> Dictionary:
	if trade_up_problem(picked) != "":
		return {}
	var r := rarity(picked[0]) + 1
	for p in picked:
		held().erase(p)
	var result := _mint(PrintRoll.finish(rng, by_rarity(), r), "tradeup")
	_changed()
	return result


## Prints that may go into a trade-up of rarity `r`.
static func trade_up_candidates(r: int) -> Array:
	return held().filter(func(p): return rarity(p) == r and can_recycle(p))


# --- the Token Counter --------------------------------------------------------------

## Today's shelf: one finish per rarity, the same all day.
static func counter_shelf() -> Array[StringName]:
	var out: Array[StringName] = []
	var pick := RandomNumberGenerator.new()
	pick.seed = ShopCatalog.day() * 2654435761 + series().number
	for r in range(PrintRoll.COMMON, PrintRoll.LEGENDARY + 1):
		var fid := PrintRoll.finish(pick, by_rarity(), r)
		if fid != &"":
			out.append(fid)
	return out


static func counter_price(finish_id: StringName) -> int:
	var fin := Cosmetics.item(finish_id)
	return series().counter_price[mini(int(fin.rarity), PrintRoll.LEGENDARY)] if fin else 0


## Bought from today's shelf already (each once a day).
static func counter_sold(finish_id: StringName) -> bool:
	var c: Dictionary = _sec()["counter"]
	return int(c.get("day", -1)) == ShopCatalog.day() and (c.get("sold", []) as Array).has(String(finish_id))


static func can_buy_at_counter(finish_id: StringName) -> bool:
	return finish_id in counter_shelf() and not counter_sold(finish_id) and tokens() >= counter_price(finish_id)


## A fresh print of a shelf finish for Capsule Credits. Returns the _mint result or {}.
static func buy_at_counter(finish_id: StringName) -> Dictionary:
	if not can_buy_at_counter(finish_id):
		return {}
	var s := _sec()
	s["tokens"] = tokens() - counter_price(finish_id)
	var c: Dictionary = s["counter"]
	if int(c.get("day", -1)) != ShopCatalog.day():
		c["day"] = ShopCatalog.day()
		c["sold"] = []
	(c["sold"] as Array).append(String(finish_id))
	var result := _mint(finish_id, "counter")
	_changed()
	return result


# --- earning ------------------------------------------------------------------------

## Hooked up by Cosmetics: capsules for contracts and milestones as they happen,
## and for the run (alphas, bounties, the day's first clear) when it ends.
static func connect_hooks() -> void:
	Events.run_started.connect(func(_director): _begin_run())
	Events.run_finished.connect(settle)
	Progression.contract_completed.connect(_on_contract)
	Progression.challenge_completed.connect(_on_challenge)
	Cosmetics.equipped_changed.connect(on_finish_equipped)


static func _begin_run() -> void:
	_run_lines = []
	_run_settled = false


static func _on_contract(_entry: Dictionary) -> void:
	var s := _sec()
	s["contracts"] = int(s["contracts"]) + 1
	if int(s["contracts"]) % series().contracts_per_capsule == 0:
		_run_lines.append(["Contracts", 1])
		add_capsules(1)


static func _on_challenge(ch: Challenge, _weapon_id: StringName) -> void:
	if ch.scope == Challenge.Scope.ACCOUNT:
		_run_lines.append(["Milestone", series().capsules_per_milestone])
		add_capsules(series().capsules_per_milestone)


## Pays the run's capsules once (Events.run_finished, or the results screen if
## it asks first). Returns { "total", "lines": [[label, n]], "capsules" }.
static func settle(result: Dictionary) -> Dictionary:
	if not _run_settled:
		_run_settled = true
		var s := series()
		var alphas := int(result.get("bosses_defeated", 0)) * s.capsules_per_alpha
		var bounties := int(result.get("bounties_claimed", 0)) * s.capsules_per_bounty
		var lines: Array = []
		if alphas > 0:
			lines.append(["Alpha defeated", alphas])
		if bounties > 0:
			lines.append(["Bounties claimed", bounties])
		var sec := _sec()
		if bool(result.get("victory", false)) and int(sec["daily"]) != ShopCatalog.day() and s.capsules_daily_clear > 0:
			sec["daily"] = ShopCatalog.day()
			lines.append(["First clear today", s.capsules_daily_clear])
		var paid := 0
		for line in lines:
			paid += int(line[1])
		_run_lines.append_array(lines)
		add_capsules(paid)
	var total := 0
	for line in _run_lines:
		total += int(line[1])
	return {"total": total, "lines": _run_lines.duplicate(), "capsules": capsules()}
