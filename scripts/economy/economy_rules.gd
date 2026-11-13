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
## Price ladder by CosmeticItem.Rarity (COMMON, RARE, EPIC, LEGENDARY, MASTERY):
## the least an item of that rarity costs. Items carry their own `price`; the
## ladder is what an ordinary item of the rarity uses, a showpiece costs more
## (up to the best items of the shop, each on its own price).
@export var prices: PackedInt32Array = PackedInt32Array([250, 750, 1500, 3000, 0])
## Every shop price is a multiple of this.
@export var price_step := 250
## Items in the daily featured selection, and their discount (0-1). With
## prices on the 250 step, 20% always lands on a round number (200, 600,
## 1,200, 2,400 ...).
@export var featured_count := 4
@export var featured_discount := 0.2
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


## Whether `price` is on the price rule (a positive multiple of price_step).
func is_clean_price(price: int) -> bool:
	return price > 0 and price % price_step == 0


## `price` less `off` (0-1), rounded to 50 Sparks below 1,000 and to 100 from
## 1,000, so a discounted price reads as cleanly as a full one.
func discounted(price: int, off: float) -> int:
	var raw := price * (1.0 - off)
	var step := 50.0 if raw < 1000.0 else 100.0
	return maxi(int(step), int(round(raw / step) * step))
