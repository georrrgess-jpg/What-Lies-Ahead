class_name Requirement
extends Resource
## An unlock condition shared by levels, worlds, weapons and cosmetics.
## Use one Requirement per condition; `all_of` lets you chain several.

enum Kind {
	NONE,            ## always met
	PLAYER_LEVEL,    ## Progression.level() >= amount
	LEVEL_CLEARED,   ## level `target` cleared at least once
	WEAPON_RANK,     ## Mastery.rank(target) >= amount; empty target = the weapon in context
	TOTAL_KILLS,     ## lifetime kills across all weapons >= amount
	BEST_SCORE,      ## best score on level `target` >= amount
	GRANTED,         ## explicitly granted by code (Unlocks.grant(target))
	## Challenge `target` completed (weapon challenges: on the weapon in context,
	## or on any weapon without context). Fixed value: saved in .tres files.
	CHALLENGE = 20,
}

@export var kind: Kind = Kind.NONE
## Level id, weapon id or grant id, depending on kind.
@export var target: StringName
@export var amount := 0
## Extra conditions that must also be met.
@export var all_of: Array[Requirement] = []


## `weapon_ctx`: the weapon being asked about (for weapon cosmetics), used by
## WEAPON_RANK requirements with an empty target ("rank N on this weapon").
func is_met(weapon_ctx: StringName = &"") -> bool:
	for r in all_of:
		if r and not r.is_met(weapon_ctx):
			return false
	match kind:
		Kind.PLAYER_LEVEL:
			return Progression.level() >= amount
		Kind.LEVEL_CLEARED:
			return Profile.is_level_completed(target)
		Kind.WEAPON_RANK:
			var wid := target if target != &"" else weapon_ctx
			return wid != &"" and Mastery.rank(wid) >= amount
		Kind.TOTAL_KILLS:
			return Mastery.total_kills() >= amount
		Kind.BEST_SCORE:
			return Profile.best_score(target) >= amount
		Kind.GRANTED:
			return Unlocks.is_granted(target)
		Kind.CHALLENGE:
			return Progression.is_challenge_complete(target, weapon_ctx)
	return true


## Short player-facing text, e.g. "Reach player level 5".
func describe() -> String:
	var text := ""
	match kind:
		Kind.PLAYER_LEVEL:
			text = "Reach player level %d" % amount
		Kind.LEVEL_CLEARED:
			var l := GameData.level(target)
			text = "Clear %s" % (l.display_name if l else String(target))
		Kind.WEAPON_RANK:
			var w := GameData.weapon(target)
			text = "%s mastery rank %d" % [w.display_name, amount] if w else "Weapon mastery rank %d" % amount
		Kind.TOTAL_KILLS:
			text = "%d total kills" % amount
		Kind.BEST_SCORE:
			var l2 := GameData.level(target)
			text = "Score %d on %s" % [amount, l2.display_name if l2 else String(target)]
		Kind.GRANTED:
			text = "Special unlock"
		Kind.CHALLENGE:
			text = "Complete the challenge %s" % Progression.challenge_name(target)
	for r in all_of:
		if r and not r.is_met():
			text = (text + " and " if text != "" else "") + r.describe()
	return text


static func player_level(level: int) -> Requirement:
	var r := Requirement.new()
	r.kind = Kind.PLAYER_LEVEL
	r.amount = level
	return r


static func weapon_rank(weapon_id: StringName, rank: int) -> Requirement:
	var r := Requirement.new()
	r.kind = Kind.WEAPON_RANK
	r.target = weapon_id
	r.amount = rank
	return r
