class_name WaveSet
extends Resource
## The wave list plus the intermission economy for one level.

@export var waves: Array[WaveData] = []

@export_group("Pacing")
## Countdown before wave 1 (the player can start early).
@export var prep_seconds := 12.0
## Length of the break between waves (the player can start early).
@export var break_seconds := 25.0
## Losing the run on this wave or later lets the player continue from it
## (0 = no checkpoint). See RunDirector and docs/ROUNDS.md.
@export var checkpoint_wave := 0
## Tickets a continued run starts with at the checkpoint.
@export var checkpoint_tickets := 350

@export_group("Kiosk")
## Free reserve ammo granted to the held weapon each break, as a fraction of its reserve_max.
@export_range(0.0, 1.0) var break_refill_fraction := 0.35
@export var ammo_topup_price := 100
@export var heal_price := 150
## Health restored by the kiosk heal.
@export var heal_amount := 60.0
## How many heals can be bought per break.
@export var heals_per_break := 1
## Tickets the player starts the run with, so the first station visit can buy something.
@export var starting_tickets := 100
## Overshield: an extra health layer that absorbs damage first and lasts until
## it is depleted or the run ends. Buying it again refills it.
@export var overshield_price := 300
@export var overshield_amount := 50.0
## Damage boost: multiplies the player's damage for the whole next wave.
@export var damage_boost_price := 400
@export var damage_boost_scale := 1.2
## Score per ticket still unspent when the player steps through the portal.
@export var ticket_score_rate := 5
## Tickets paid at a wave clear for the wave grade, best grade first (S, A, B, C).
@export var grade_tickets := PackedInt32Array([60, 40, 20, 0])

@export_group("Mastery")
## Wave-clear XP for each weapon that scored a kill that wave: base + per_wave * wave number.
@export var wave_bonus_base := 20
@export var wave_bonus_per_wave := 5
