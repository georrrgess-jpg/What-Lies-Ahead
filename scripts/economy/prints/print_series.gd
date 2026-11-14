class_name PrintSeries
extends Resource
## One series of Prize Capsules: what can drop, the published odds, the luck
## meter, the rare prints, what capsules cost and pay, and the Token Counter.
## Tune it in data/prints/; check it with tools/print_probe.gd and
## tools/economy_model.py. A finish's print rarity is its CosmeticItem.rarity.

@export var id: StringName = &"series_1"
@export var number := 1
@export var display_name := ""
## Finish ids in the capsules (weapon_finish items with a finish_* shader, so
## every one wears the print layer).
@export var finishes: Array[StringName] = []
## Chance of each rarity per capsule: Common, Rare, Epic, Legendary (sums to 1).
@export var odds := PackedFloat32Array([0.62, 0.27, 0.09, 0.02])
## An Epic or better is guaranteed within this many capsules.
@export var epic_pity := 10
## A Legendary is guaranteed within this many capsules.
@export var legendary_pity := 40
## Rare prints, one roll per print (exclusive).
@export var glitter_chance := 0.05
@export var holo_chance := 0.02
@export var misprint_chance := 0.01
## Shine roll (uniform 0-1) thresholds of the Polished and Mint grades.
@export var polished_at := 0.6
@export var mint_at := 0.9
## Serials up to this are Low Serial (and #001 First Edition).
@export var low_serial := 10
## Sparks for one capsule.
@export var capsule_price := 500
## Prize Tokens a recycled print gives, by rarity.
@export var token_value := PackedInt32Array([1, 3, 8, 25])
## Prize Tokens a fresh print costs at the Token Counter, by rarity.
@export var counter_price := PackedInt32Array([6, 18, 60, 200])
## Prints of one rarity a trade-up takes.
@export var trade_up_count := 5
## Capsules earned.
@export var capsules_per_alpha := 1
@export var capsules_per_bounty := 1
@export var capsules_daily_clear := 1
## One capsule for every this many contracts completed.
@export var contracts_per_capsule := 2
@export var capsules_per_milestone := 2
