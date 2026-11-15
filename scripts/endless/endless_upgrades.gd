class_name EndlessUpgrades
extends RefCounted
## The weapon side of an Endless run: the Upgrade Bench's tiers of every
## weapon (Mk I: damage; Mk II: a bigger magazine and a faster reload; Mk III:
## more damage and a coloured glow on the weapon) and Rapid Fire, the timed
## power-up. Both last for the run only and never stack past their tier.
##
## Weapon stats live on the shared WeaponData resources, so the magazine,
## reload and fire rate are changed in place for the run and every weapon
## touched is put back by restore() (the director calls it when the run is
## left). Damage goes through WeaponController.damage_multiplier
## (RunDirector.refresh_damage() asks damage_scale()).

const MAX_TIER := 3
const NAMES: Array[String] = ["", "MK I", "MK II", "MK III"]
## Mk II and up: magazine x, reload time x.
const MAG_SCALE := 1.5
const RELOAD_SCALE := 0.7
## While Rapid Fire runs: time between shots x, reload time x.
const RAPID_FIRE := 0.6
const RAPID_RELOAD := 0.6
## The Mk III glow, and each tier's colour on the bench and in the HUD.
const TIER_COLORS: Array[Color] = [Color(0.7, 0.7, 0.75), Color(0.45, 1.0, 0.55), Color(0.35, 0.8, 1.0), Color(0.85, 0.45, 1.0)]

var rules: EndlessRules
## Upgrades bought this run (all weapons, all tiers).
var bought := 0
var rapid := false

var _tiers := {}   # weapon id -> tier (1..MAX_TIER)
var _base := {}    # weapon id -> [magazine_size, reload_time, fire_interval, burst_interval]


func _init(endless_rules: EndlessRules) -> void:
	rules = endless_rules


func tier(weapon_id: StringName) -> int:
	return int(_tiers.get(weapon_id, 0))


## Tickets for the next tier of `weapon_id` (0 when it is at Mk III).
func next_price(weapon_id: StringName) -> int:
	var t := tier(weapon_id)
	return rules.bench_prices[t] if t < MAX_TIER and t < rules.bench_prices.size() else 0


## The damage multiplier of `weapon_id`'s tier.
func damage_scale(weapon_id: StringName) -> float:
	var t := tier(weapon_id)
	return rules.bench_damage[t - 1] if t > 0 and t <= rules.bench_damage.size() else 1.0


## What the next tier of `w` gives, for the bench's prompt.
func next_perk(w: WeaponData) -> String:
	match tier(w.id):
		0:
			return "+%d%% damage" % int(round((rules.bench_damage[0] - 1.0) * 100.0))
		1:
			return "magazine %d → %d, faster reload" % [_stat(w, 0), int(round(_stat(w, 0) * MAG_SCALE))]
		2:
			return "+%d%% damage and the glow" % int(round((rules.bench_damage[2] - 1.0) * 100.0))
	return "fully upgraded"


## Raises `w` one tier (the director has taken the tickets).
func upgrade(w: WeaponData) -> void:
	if tier(w.id) >= MAX_TIER:
		return
	_remember(w)
	_tiers[w.id] = tier(w.id) + 1
	bought += 1
	_apply(w)


## Rapid Fire on or off for every weapon.
func set_rapid(on: bool) -> void:
	if on == rapid:
		return
	rapid = on
	for w in GameData.weapons():
		_remember(w)
		_apply(w)


## Puts every weapon's stats back as they were before the run.
func restore() -> void:
	for id in _base:
		var w := GameData.weapon(id)
		var b: Array = _base[id]
		if w:
			w.magazine_size = b[0]
			w.reload_time = b[1]
			w.fire_interval = b[2]
			w.burst_interval = b[3]
	_base.clear()
	_tiers.clear()
	rapid = false


func _remember(w: WeaponData) -> void:
	if not _base.has(w.id):
		_base[w.id] = [w.magazine_size, w.reload_time, w.fire_interval, w.burst_interval]


func _stat(w: WeaponData, index: int) -> int:
	return int((_base[w.id] as Array)[index]) if _base.has(w.id) else w.magazine_size


func _apply(w: WeaponData) -> void:
	var b: Array = _base[w.id]
	var mk2 := tier(w.id) >= 2
	w.magazine_size = int(round(b[0] * MAG_SCALE)) if mk2 else b[0]
	w.reload_time = float(b[1]) * (RELOAD_SCALE if mk2 else 1.0) * (RAPID_RELOAD if rapid else 1.0)
	w.fire_interval = float(b[2]) * (RAPID_FIRE if rapid else 1.0)
	w.burst_interval = float(b[3]) * (RAPID_FIRE if rapid else 1.0)
