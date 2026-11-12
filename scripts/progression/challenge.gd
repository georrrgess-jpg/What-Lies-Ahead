class_name Challenge
extends Resource
## A goal tracked across runs: "25 headshots with this weapon", "reach a
## 20-kill combo", "clear a level without dropping below 25% health".
## Drop a .tres in data/progression/challenges/ to add one.
##
## WEAPON challenges exist once per weapon (every weapon, including ones added
## later); ACCOUNT challenges once per profile. Progress lives in
## Profile.section("progression") (see ChallengeBook).
##
## Stats recorded by the run tracker (scripts/progression/run_tracker.gd):
##   kills, headshots, multi_kills, longshots, close_calls   (per kill; weapon + account)
##   flawless_waves, waves                                  (per wave)
##   clears, healthy_clears                                 (per cleared level)
##   best_combo, run_score                                  (best value in one run)
## Computed from mastery (refreshed on rank-ups):
##   max_rank          highest mastery rank on any weapon
##   weapons_at_rank   weapons at rank >= `param`

enum Scope { ACCOUNT, WEAPON }
enum Mode {
	TOTAL,       ## progress adds up across runs
	BEST,        ## progress is the best single value seen (combo, score, rank)
}

## Stable ID saved in profiles. Never rename once shipped.
@export var id: StringName
@export var display_name := ""
## Player-facing goal; "%s" is replaced by the goal amount.
@export var description := ""
@export var scope: Scope = Scope.ACCOUNT
@export var stat: StringName
@export var mode: Mode = Mode.TOTAL
@export var goal := 1
## Extra parameter for computed stats (e.g. the rank for weapons_at_rank).
@export var param := 0
## Account XP on completion.
@export var xp := 500
## Mastery XP on completion (weapon challenges, to that weapon).
@export var mastery_xp := 0
@export var sort_order := 0


## Profile key: the id, plus "@weapon" for weapon challenges.
func key(weapon_id: StringName = &"") -> String:
	return String(id) + ("@" + String(weapon_id) if scope == Scope.WEAPON else "")


func describe() -> String:
	var amount := _fmt(goal)
	return description % amount if description.contains("%s") else description


static func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
