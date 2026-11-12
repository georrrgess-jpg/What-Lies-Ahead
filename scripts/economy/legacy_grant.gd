class_name LegacyGrant
extends RefCounted
## One-time carry-over for a save from before the Sparks economy (profile
## version 2 or older; Profile marks it "legacy_pending"). The update put
## prices on some cosmetics and moved others to new levels and milestones, so:
##
##   1. every cosmetic the save owned under its old rule (LegacyUnlocks) is
##      granted outright and stays owned,
##   2. account XP is kept (the new curve is cheaper at every level, so the
##      level only goes up) and topped up where needed so no weapon is lost,
##   3. the Sparks the new rules pay for the levels, mastery ranks and first
##      clears the save already has are paid as back pay.
##
## Mastery XP is kept as it is: the new rank thresholds are all lower.

## The account level curve before the update (ProgressionRules.level_cost).
const OLD_MAX_LEVEL := 50
const OLD_LEVEL_BASE := 3500.0
const OLD_LEVEL_STEP := 300.0
const OLD_LEVEL_CURVE := 1.0
## The player level each weapon unlocked at before the update.
const OLD_WEAPON_LEVELS := {
	&"comet_cannon": 2, &"arc_coil": 3, &"bumper_lobber": 5, &"cryo_beam": 7, &"rail_lancer": 9,
}


## Runs apply() once for a profile that was flagged by the save migration.
static func apply_if_pending() -> void:
	var sec := Profile.section("economy")
	if not bool(sec.get("legacy_pending", false)):
		return
	sec.erase("legacy_pending")
	sec["legacy"] = apply()
	Profile.save_profile()


## Carries the save over. Returns what it did: { "items", "sparks", "old_level" }.
static func apply() -> Dictionary:
	var old_level := old_level_for(Progression.xp())
	var kept := 0
	for id in LegacyUnlocks.RULES:
		if _held(LegacyUnlocks.RULES[id], old_level):
			Unlocks.grant(StringName("cosmetic:" + String(id)))
			kept += 1
	_keep_weapons(old_level)
	var sparks := _back_pay()
	Wallet.earn(sparks, &"welcome")
	return {"items": kept, "sparks": sparks, "old_level": old_level}


## The player level `xp` was worth under the old curve.
static func old_level_for(xp: int) -> int:
	var lvl := 1
	var total := 0
	while lvl < OLD_MAX_LEVEL:
		var k := float(lvl - 1)
		total += int(round((OLD_LEVEL_BASE + OLD_LEVEL_STEP * k + OLD_LEVEL_CURVE * k * k) / 50.0)) * 50
		if xp < total:
			break
		lvl += 1
	return lvl


## True if every old condition ([Requirement.Kind, target, amount]) held.
static func _held(conditions: Array, old_level: int) -> bool:
	for c in conditions:
		var target: StringName = c[1]
		var amount: int = c[2]
		var met := false
		match int(c[0]):
			Requirement.Kind.PLAYER_LEVEL:
				met = old_level >= amount
			Requirement.Kind.LEVEL_CLEARED:
				met = Profile.is_level_completed(target)
			Requirement.Kind.TOTAL_KILLS:
				met = Mastery.total_kills() >= amount
			Requirement.Kind.BEST_SCORE:
				met = Profile.best_score(target) >= amount
			Requirement.Kind.GRANTED:
				met = Unlocks.is_granted(target)
			Requirement.Kind.CHALLENGE:
				met = Progression.is_challenge_complete(target)
		if not met:
			return false
	return true


## Raises account XP to the level of every weapon the save could already use.
static func _keep_weapons(old_level: int) -> void:
	var needed := 0
	for weapon_id in OLD_WEAPON_LEVELS:
		var w := GameData.weapon(weapon_id)
		if w and w.unlock and w.unlock.kind == Requirement.Kind.PLAYER_LEVEL and old_level >= int(OLD_WEAPON_LEVELS[weapon_id]):
			needed = maxi(needed, Progression.xp_for_level(w.unlock.amount))
	if Progression.xp() < needed:
		Profile.section("progression")["xp"] = needed


## Sparks for progress made before Sparks existed.
static func _back_pay() -> int:
	var rules := Wallet.rules
	var sparks := 0
	for lvl in range(2, Progression.level() + 1):
		sparks += rules.level_sparks(lvl)
	for w in GameData.weapons():
		for rank in range(1, Mastery.rank(w.id) + 1):
			sparks += rules.rank_sparks(rank)
	for world in GameData.worlds():
		for level in world.levels:
			if level and Profile.is_level_completed(level.id) and Wallet.claim_first_clear(level.id):
				sparks += rules.first_clear_sparks
	return sparks
