class_name WaveData
extends Resource
## One wave. Edit these in data/levels/<level>_waves.tres.

## Enemy ID -> how many to spawn this wave, e.g. { "tourist_shambler": 8, "lifeguard_runner": 3 }.
@export var spawns: Dictionary = {}
## Seconds between spawn pulses.
@export var spawn_interval := 2.0
## Enemies released per pulse.
@export var burst := 1
## No new spawns while this many are alive.
@export var max_alive := 8
## Multiplies enemy move speed for this wave.
@export var speed_scale := 1.0
## Fraction of the wave (0-1) that must have spawned before the second listed
## enemy type starts appearing. Lets a wave open with shamblers, then add runners.
@export_range(0.0, 1.0) var late_types_after := 0.0
## Optional banner text, e.g. "FINAL WAVE".
@export var banner := ""


func total_enemies() -> int:
	var total := 0
	for k in spawns:
		total += int(spawns[k])
	return total
