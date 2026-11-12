extends Node
## Player account level. XP is stored in Profile.section("progression").
## This is the minimal core (level curve + add_xp); the progression system
## builds on it.

signal xp_changed(xp: int)
signal level_up(new_level: int)

const MAX_LEVEL := 50


func xp() -> int:
	return int(Profile.section("progression").get("xp", 0))


## Total XP needed to reach `lvl` (level 1 = 0 XP).
func xp_for_level(lvl: int) -> int:
	if lvl <= 1:
		return 0
	var total := 0
	for l in range(1, lvl):
		total += 1000 + (l - 1) * 350
	return total


func level() -> int:
	var x := xp()
	var lvl := 1
	while lvl < MAX_LEVEL and x >= xp_for_level(lvl + 1):
		lvl += 1
	return lvl


## 0-1 progress through the current level.
func level_progress() -> float:
	var lvl := level()
	if lvl >= MAX_LEVEL:
		return 1.0
	var a := xp_for_level(lvl)
	var b := xp_for_level(lvl + 1)
	return clampf(float(xp() - a) / float(maxi(1, b - a)), 0.0, 1.0)


## Adds XP; emits level_up for every level gained. Caller saves the profile.
func add_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := level()
	Profile.section("progression")["xp"] = xp() + amount
	xp_changed.emit(xp())
	var after := level()
	for l in range(before + 1, after + 1):
		level_up.emit(l)
	return after - before
