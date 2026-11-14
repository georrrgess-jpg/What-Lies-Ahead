class_name PrintRoll
extends RefCounted
## The dice of Prize Prints: pure functions of a RandomNumberGenerator and a
## PrintSeries, so tools/print_probe.gd can roll them thousands of times.
##
##   rarity()      a capsule's rarity, with the luck meter (pity) applied
##   finish()      a finish of that rarity from the series
##   attributes()  a print's rolls: pattern seed, shine, rare print

const COMMON := 0
const RARE := 1
const EPIC := 2
const LEGENDARY := 3
## Rare prints, as saved in the profile ("" is a standard print).
const GLITTER := "glitter"
const HOLO := "holo"
const MISPRINT := "misprint"
## Pattern seeds run 0..SEEDS-1 (shown as "Pattern 417").
const SEEDS := 10000


## The rarity of the next capsule. `since_epic` / `since_legendary` are the
## capsules opened since the last Epic-or-better / Legendary: the capsule that
## would make either gap reach its pity is upgraded.
static func rarity(rng: RandomNumberGenerator, series: PrintSeries, since_epic: int, since_legendary: int) -> int:
	if since_legendary + 1 >= series.legendary_pity:
		return LEGENDARY
	var r := _pick(rng.randf(), series.odds)
	if r < EPIC and since_epic + 1 >= series.epic_pity:
		# The guaranteed Epic keeps Legendary's share of the top two rarities.
		var top := series.odds[EPIC] + series.odds[LEGENDARY]
		r = LEGENDARY if rng.randf() * top < series.odds[LEGENDARY] else EPIC
	return r


## Index of the bucket `x` (0-1) falls in, by cumulative `weights`.
static func _pick(x: float, weights: PackedFloat32Array) -> int:
	var acc := 0.0
	for i in weights.size():
		acc += weights[i]
		if x < acc:
			return i
	return weights.size() - 1


## A finish of `r` from `by_rarity` (rarity -> Array of finish ids).
static func finish(rng: RandomNumberGenerator, by_rarity: Dictionary, r: int) -> StringName:
	var pool: Array = by_rarity.get(r, [])
	if pool.is_empty():
		return &""
	return pool[rng.randi_range(0, pool.size() - 1)]


## A print's own rolls: { "seed": int, "shine": float (3 decimals), "var": String }.
static func attributes(rng: RandomNumberGenerator, series: PrintSeries) -> Dictionary:
	return {
		"seed": rng.randi_range(0, SEEDS - 1),
		"shine": snappedf(rng.randf(), 0.001),
		"var": variant(rng.randf(), series),
	}


## The rare print a roll `x` (0-1) gives: the rarest first.
static func variant(x: float, series: PrintSeries) -> String:
	if x < series.misprint_chance:
		return MISPRINT
	if x < series.misprint_chance + series.holo_chance:
		return HOLO
	if x < series.misprint_chance + series.holo_chance + series.glitter_chance:
		return GLITTER
	return ""


## 0 Factory, 1 Polished, 2 Mint.
static func grade(shine: float, series: PrintSeries) -> int:
	if shine >= series.mint_at:
		return 2
	return 1 if shine >= series.polished_at else 0
