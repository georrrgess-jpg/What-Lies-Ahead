class_name CapRaise
extends RefCounted
## One-time carry-over for a save from before the level cap went from 40 to
## 50 (update 12). Runs once per profile, when the game data is loaded:
##
##   1. XP is kept, and XP banked past the old cap counts: the curve for
##      levels 1-40 is unchanged, so a save at 40 stays at 40 or moves up into
##      41-50 by the XP it kept earning there. The Sparks of every level it
##      moves up are paid now (source "level_up"), once; the cosmetics of
##      those levels unlock through their own requirements.
##   2. The Teacup Twister moved from level 12 to 43: a save that had it
##      keeps it (granted "weapon:teacup_twister", see GameData.is_weapon_unlocked).
##
## "level_cap" in the progression section marks a save as carried over; new
## profiles get it on their first load without paying or granting anything.

const OLD_MAX_LEVEL := 40
## Weapons that moved to a later level in this update, and their old level.
const MOVED_WEAPONS := {&"teacup_twister": 12}


## Runs apply() once for a save that has not seen the current cap yet.
static func apply_if_pending() -> void:
	var sec := Profile.section("progression")
	if int(sec.get("level_cap", 0)) >= Progression.MAX_LEVEL:
		return
	var legacy := Profile.section("economy").has("legacy_pending")
	sec["level_cap"] = Progression.MAX_LEVEL
	# A pre-economy save is carried over by LegacyGrant, whose back pay
	# already covers every level the save holds.
	if not legacy:
		sec["cap_raise"] = apply()
	Profile.save_profile()


## Carries the save over. Returns what it did: { "levels", "sparks", "kept" }.
static func apply() -> Dictionary:
	var kept: Array[String] = []
	for id in MOVED_WEAPONS:
		if Progression.xp() >= Progression.xp_for_level(int(MOVED_WEAPONS[id])):
			Unlocks.grant(StringName("weapon:" + String(id)))
			kept.append(String(id))
	var sparks := 0
	var lvl := Progression.level()
	for l in range(OLD_MAX_LEVEL + 1, lvl + 1):
		sparks += Wallet.rules.level_sparks(l)
	Wallet.earn(sparks, &"level_up")
	return {"levels": maxi(0, lvl - OLD_MAX_LEVEL), "sparks": sparks, "kept": kept}
