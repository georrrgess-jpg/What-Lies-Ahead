class_name WaveSet
extends Resource
## The wave list plus the intermission economy for one level.

@export var waves: Array[WaveData] = []

@export_group("Pacing")
## Countdown before wave 1 (the player can start early).
@export var prep_seconds := 12.0
## Length of the break between waves (the player can start early).
@export var break_seconds := 25.0

@export_group("Kiosk")
## Free reserve ammo granted to the held weapon each break, as a fraction of its reserve_max.
@export_range(0.0, 1.0) var break_refill_fraction := 0.35
@export var ammo_topup_price := 100
@export var heal_price := 150
## Health restored by the kiosk heal.
@export var heal_amount := 60.0
## How many heals can be bought per break.
@export var heals_per_break := 1

@export_group("Mastery")
## Wave-clear XP for each weapon that scored a kill that wave: base + per_wave * wave number.
@export var wave_bonus_base := 20
@export var wave_bonus_per_wave := 5
