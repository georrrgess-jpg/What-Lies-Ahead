class_name EconomyRules
extends Resource
## Every number of the Sparks economy: what play pays, what progress pays and
## what the shop charges. Lives in data/progression/economy.tres; the model in
## tools/economy_model.py reads the same file.
##
## Sparks earned inside a run (kills, waves, clear, tickets) are multiplied by
## Difficulty.reward_scale(); level, mastery, contract and milestone payouts
## are fixed amounts.

@export_group("Kills")
## A zombie carries its ticket value times this in Sparks (rounded, at least 1):
## 1 for the common ones, 2 for specials, 4-5 for heavies.
@export var sparks_per_kill_ticket := 0.1
## Extra Sparks for a headshot finishing blow.
@export var headshot_sparks := 1
## Every `combo_every`-th kill of a combo pays `combo_sparks` on top.
@export var combo_every := 10
@export var combo_sparks := 5

@export_group("Run")
@export var wave_sparks := 15
## Extra for a wave cleared without taking damage.
@export var flawless_wave_sparks := 15
## Reaching the portal: clear_sparks, plus clear_sparks_per_world for each
## world after the first.
@export var clear_sparks := 150
@export var clear_sparks_per_world := 25
## Once per level, the first time it is cleared.
@export var first_clear_sparks := 150
## Tickets left at the portal are cashed at this many Sparks each (on top of
## the score they pay). Nothing is cashed on a defeat.
@export var sparks_per_ticket := 0.05

@export_group("Progress")
## Player level L pays base + per_level * L, plus the milestone bonus on every
## `milestone_every`-th level.
@export var level_sparks_base := 50
@export var level_sparks_per_level := 5
@export var milestone_every := 5
@export var milestone_sparks := 100
## Mastery rank R pays base + per_rank * R.
@export var rank_sparks_base := 10
@export var rank_sparks_per_rank := 10

@export_group("Shop")
## Price ladder by CosmeticItem.Rarity (COMMON, RARE, EPIC, LEGENDARY, MASTERY).
## Items carry their own `price`; the ladder is what new items should use.
@export var prices: PackedInt32Array = PackedInt32Array([250, 650, 1500, 3000, 0])
## The showpiece price by rarity: the two or three best items of each shop
## section cost this instead of the ladder price (0 = no showpiece tier).
@export var premium_prices: PackedInt32Array = PackedInt32Array([0, 1250, 2800, 5600, 0])
## Items in the daily featured selection, and their discount (0-1).
@export var featured_count := 4
@export var featured_discount := 0.25
## Slots whose shop items are flagged NEW until the player has looked at them.
@export var new_slots: Array[StringName] = [&"weapon_sight"]


## Sparks a zombie worth `tickets` drops (before headshot and combo extras).
func kill_sparks(tickets: int) -> int:
	return maxi(1, int(floor(tickets * sparks_per_kill_ticket + 0.5)))


func is_milestone(level: int) -> bool:
	return milestone_every > 0 and level % milestone_every == 0


func level_sparks(level: int) -> int:
	return level_sparks_base + level_sparks_per_level * level + (milestone_sparks if is_milestone(level) else 0)


func rank_sparks(rank: int) -> int:
	return rank_sparks_base + rank_sparks_per_rank * rank


## Level-clear Sparks for the world at `world_index` (0 = the first world).
func clear_sparks_for(world_index: int) -> int:
	return clear_sparks + clear_sparks_per_world * maxi(0, world_index)


func ticket_sparks(tickets: int) -> int:
	return int(floor(maxi(0, tickets) * sparks_per_ticket))


## The ladder price for a rarity.
func price_for(rarity: CosmeticItem.Rarity) -> int:
	return prices[int(rarity)] if int(rarity) < prices.size() else 0


## The showpiece price for a rarity (0 if the rarity has none).
func premium_for(rarity: CosmeticItem.Rarity) -> int:
	return premium_prices[int(rarity)] if int(rarity) < premium_prices.size() else 0
