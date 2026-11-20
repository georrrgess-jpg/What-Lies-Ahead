class_name ArsenalStats
extends RefCounted
## What the Arsenal says about a weapon, worked out from its WeaponData: the
## six stats of the details panel (as text), the
## short tags for how it fires, and the line that says what unlocks it.

## The stats, in panel order: [caption, id for stat()].
const STATS := [
	["DPS", &"dps"],
	["BURST", &"burst"],
	["RANGE", &"range"],
	["HANDLING", &"handling"],
	["MOBILITY", &"mobility"],
	["MAGAZINE", &"magazine"],
]
## A melee weapon's captions for the same six tiles: light-swing DPS, the
## full heavy's damage, its reach, its light swing's length, mobility, ammo.
const MELEE_CAPTIONS := ["DPS", "HEAVY", "REACH", "SWING", "MOBILITY", "AMMO"]
## Tags for weapon mode scripts that do not declare `const TRAIT`, by a word in the file name.
const MODE_TRAITS := {"whirligig": "SPIN-UP", "riptide": "REELS IN", "saw": "CHAINSAW", "drum_popper": "BANK SHOTS"}


## The caption of stat tile `index` for `w` (melee weapons name theirs differently).
static func caption(w: WeaponData, index: int) -> String:
	return MELEE_CAPTIONS[index] if w != null and w.is_melee() else String(STATS[index][0])


## The text of stat `id` (one of STATS) for `w`.
static func stat(w: WeaponData, id: StringName) -> String:
	if w.is_melee():
		return _melee_stat(w, id)
	match id:
		&"dps":
			return "%d" % roundi(_dps(w))
		&"burst":
			return "%d" % roundi(w.burst_damage())
		&"range":
			return "%d m" % roundi(w.effective_range())
		&"handling":
			return "%d" % roundi(_handling(w) * 100.0)
		&"mobility":
			return "%d%%" % roundi(w.move_speed_scale * 100.0)
		_:
			return _magazine(w)


## A melee weapon's tiles (see MELEE_CAPTIONS).
static func _melee_stat(w: WeaponData, id: StringName) -> String:
	match id:
		&"dps":
			return "%d" % roundi(_dps(w))
		&"burst":
			return "%d" % roundi(w.melee_heavy_damage)
		&"range":
			return "%.1f m" % w.max_range
		&"handling":
			return "%.2fs" % w.fire_interval
		&"mobility":
			return "%d%%" % roundi(w.move_speed_scale * 100.0)
	return "NONE"


## Sustained single-target damage per second at the real fire rate, reloads
## (or overheat vents) included, so a big magazine and a fast reload count.
static func _dps(w: WeaponData) -> float:
	var dps := w.damage_per_second()
	if w.status_effect == &"fizz":
		# A sprayed target carries about three quarters of the full fizz burn.
		dps += w.status_amount * FizzBurn.MAX_STACKS * 0.75
	if w.mode_script != null:
		var mode: WeaponMode = w.mode_script.new()
		mode.data = w
		dps = mode.arsenal_dps(dps)
	return dps


## Aiming, reloading and switching speed, 0-1.
static func _handling(w: WeaponData) -> float:
	var ads := inverse_lerp(0.26, 0.1, w.ads_time)
	var reload := inverse_lerp(2.6, 1.1, w.reload_time)
	var equip := inverse_lerp(0.5, 0.2, w.equip_time)
	return clampf((ads + reload + equip) / 3.0, 0.0, 1.0)


## Rounds in the magazine; heat weapons show seconds of fire instead.
static func _magazine(w: WeaponData) -> String:
	if w.uses_heat():
		return "%.0fs" % (w.magazine_size * w.fire_interval)
	return "%d" % w.magazine_size


## Short tags for how the weapon fires and what its shots do.
static func tags(w: WeaponData) -> Array[String]:
	var out: Array[String] = []
	if w.is_melee():
		return _melee_tags(w)
	var own: Dictionary = w.mode_script.get_script_constant_map() if w.mode_script else {}
	if own.has("FIRE_TAG"):
		# A mode that fires its own way says so (the Sarsaparilla Six's FAN FIRE).
		out.append(String(own["FIRE_TAG"]))
	elif w.charge_time <= 0.0:
		out.append("AUTO" if w.automatic or w.beam else "SEMI")
	if w.burst_count > 1:
		out.append("BURST ×%d" % w.burst_count)
	if w.charge_time > 0.0:
		out.append("CHARGE %.1fs" % w.charge_time)
	if w.beam:
		out.append("BEAM")
	if w.pellets > 1:
		out.append("%d PELLETS" % w.pellets)
	if w.pierce > 0:
		out.append("PIERCES %d" % w.pierce)
	if w.chain_count > 0:
		out.append("CHAINS ×%d" % w.chain_count)
	if w.seek_cone_degrees > 0.0:
		out.append("SEEKING")
	if w.splash_radius > 0.0:
		out.append("BLAST %.1f m" % w.splash_radius)
	if w.projectile_speed > 0.0 and w.projectile_gravity > 0.0:
		out.append("LOBBED")
	_append_effects(w, out)
	var special := mode_trait(w)
	if special != "":
		out.insert(mini(1, out.size()), special)
	if w.uses_heat():
		out.append("HEAT")
	return out


## A melee weapon's tags: what it is, its mobility, its heavy and its trick.
static func _melee_tags(w: WeaponData) -> Array[String]:
	var out: Array[String] = ["MELEE"]
	if w.move_speed_scale > 1.0:
		out.append("+%d%% SPEED" % roundi((w.move_speed_scale - 1.0) * 100.0))
	out.append("HEAVY %.1fs" % w.melee_charge_time)
	if w.melee_backstab_scale > 1.0:
		out.append("BACKSTAB ×%d" % roundi(w.melee_backstab_scale))
	var special := mode_trait(w)
	if special != "":
		out.append(special)
	return out


static func _append_effects(w: WeaponData, out: Array[String]) -> void:
	if w.ricochet_count > 0:
		out.append("RICOCHET ×%d" % w.ricochet_count)
	elif w.projectile_bounces > 0 and w.projectile_gravity <= 0.0:
		out.append("BOUNCES ×%d" % w.projectile_bounces)
	match w.status_effect:
		&"chill":
			out.append("FREEZES")
		&"shock":
			out.append("SHOCKS")
		&"fizz":
			out.append("FIZZ BURN")


## The mechanic a weapon's mode script adds, as a tag: the script's own
## `const TRAIT := "..."` if it has one, else known modes by file name.
static func mode_trait(w: WeaponData) -> String:
	if w.mode_script == null:
		return ""
	var own: Dictionary = w.mode_script.get_script_constant_map()
	if own.has("TRAIT"):
		return String(own["TRAIT"])
	var file := w.mode_script.resource_path.get_file()
	for key in MODE_TRAITS:
		if file.contains(key):
			return MODE_TRAITS[key]
	return ""


## What unlocks a locked weapon, in full ("Reach level 12").
static func unlock_text(w: WeaponData) -> String:
	if w.unlock and w.unlock.kind == Requirement.Kind.MELEE_KILLS and w.unlock.all_of.is_empty():
		return "%s  ·  %s so far" % [w.unlock.describe(), Wallet.format(Progression.melee_kills())]
	return w.unlock.describe() if w.unlock else "Locked"


## "312 / 500 melee kills" for a MELEE_KILLS requirement.
static func melee_progress(r: Requirement) -> String:
	return "%s / %s melee kills" % [Wallet.format(mini(Progression.melee_kills(), r.amount)), Wallet.format(r.amount)]


## The same, short, for a card: "Lv 5", "Wave 10", else the full text.
static func short_unlock(w: WeaponData) -> String:
	if w.unlock == null:
		return "Locked"
	if w.unlock.kind == Requirement.Kind.PLAYER_LEVEL and w.unlock.all_of.is_empty():
		return "Lv %d" % w.unlock.amount
	if w.unlock.kind == Requirement.Kind.ENDLESS_WAVE and w.unlock.all_of.is_empty():
		return "Wave %d" % w.unlock.amount
	if w.unlock.kind == Requirement.Kind.MELEE_KILLS and w.unlock.all_of.is_empty():
		return melee_progress(w.unlock)
	return w.unlock.describe()
