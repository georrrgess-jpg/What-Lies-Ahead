class_name MasteryCurve
extends Resource
## The shared weapon mastery curve: lifetime XP per rank and the tiers the
## ranks are grouped into. Every weapon uses it (including weapons added
## later), so a new weapon needs no mastery data of its own.
## Lives in data/progression/mastery_curve.tres.

## Lifetime XP needed to reach rank 1, 2, 3...  (cumulative, ascending).
@export var rank_xp: PackedInt32Array = PackedInt32Array()
## Ascending by first_rank.
@export var tiers: Array[MasteryTier] = []

@export_group("Kill bonuses")
## Extra mastery XP for a headshot finishing blow, as a fraction of the enemy's XP.
@export var headshot_bonus := 0.5
## Extra mastery XP for each kill after the first in a multi-kill chain
## (scaled by its position: 2nd kill x1, 3rd x2...).
@export var multi_kill_bonus := 12
## Extra mastery XP for a longshot kill.
@export var longshot_bonus := 10


func max_rank() -> int:
	return rank_xp.size()


func rank_for_xp(xp: int) -> int:
	var rank := 0
	for threshold in rank_xp:
		if xp >= threshold:
			rank += 1
	return rank


## XP at which `rank` begins (0 for rank 0).
func xp_floor(rank: int) -> int:
	if rank <= 0 or rank_xp.is_empty():
		return 0
	return rank_xp[mini(rank, rank_xp.size()) - 1]


## XP needed for the rank after `rank`, or -1 at max rank.
func xp_ceiling(rank: int) -> int:
	if rank >= rank_xp.size():
		return -1
	return rank_xp[maxi(0, rank)]


## The tier `rank` belongs to (null for rank 0).
func tier_for_rank(rank: int) -> MasteryTier:
	var found: MasteryTier = null
	for t in tiers:
		if rank >= t.first_rank:
			found = t
	return found


## Ranks covered by `tier`: [first, last].
func tier_span(tier: MasteryTier) -> Vector2i:
	var i := tiers.find(tier)
	var last := max_rank()
	if i >= 0 and i + 1 < tiers.size():
		last = tiers[i + 1].first_rank - 1
	return Vector2i(tier.first_rank, last)
