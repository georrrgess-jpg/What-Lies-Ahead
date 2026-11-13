class_name WaveData
extends Resource
## One wave. Edit these in data/levels/<level>_waves.tres. A wave is a list of
## enemies plus a `kind` that gives it an identity: how it spawns, what the
## banner says, and what is special about it (docs/ROUNDS.md).

## Wave kinds. Each changes how the director spawns the wave:
##   standard  two entrances at a time, flankers join late
##   rush      light runners pour in fast from two entrances
##   siege     heavies first with their escorts, from one entrance at a time
##   ambush    every entrance at once, in pulses
##   ranged    the world's specialists, spread wide so they keep their distance
##   bounty    a standard wave plus a bounty target that flees and pays tickets
##   finale    the world's alpha with a health bar, and its horde
const KINDS: Array[StringName] = [&"standard", &"rush", &"siege", &"ambush", &"ranged", &"bounty", &"finale"]

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
## Optional banner text that replaces "WAVE n — TITLE", e.g. "FINAL WAVE".
@export var banner := ""

@export_group("Identity")
## One of KINDS.
@export var kind: StringName = &"standard"
## Short name for the banner ("RUNNER RUSH"). Empty = just the wave number.
@export var title := ""
## One line of advice shown under the banner.
@export var hint := ""
## Environmental twist for this wave (see WaveTwist.IDS); empty = none.
@export var twist: StringName = &""

@export_group("Surge")
## Fraction of the wave (0-1) that must have spawned before the surge: a
## telegraphed pack that arrives together through one entrance. 0 = no surge.
@export_range(0.0, 1.0) var surge_at := 0.0
## Enemies in the surge (taken from this wave's list, not added to it).
@export var surge_count := 0

@export_group("Set piece")
## Enemy ID of the alpha that leads this wave (finales). It gets a health bar.
@export var boss: StringName = &""
## Fraction of the wave that must have spawned before the alpha arrives.
@export_range(0.0, 1.0) var boss_at := 0.25
## Enemy ID of the bounty target: it flees instead of fighting and pays
## `bounty_tickets` if it is popped before it escapes.
@export var bounty: StringName = &""
@export var bounty_tickets := 150
## Seconds the bounty target stays before it escapes.
@export var bounty_seconds := 40.0

@export_group("Flow")
## Length of the break before this wave (0 = the wave set's break_seconds).
@export var rest_before := 0.0


func total_enemies() -> int:
	var total := 0
	for k in spawns:
		total += int(spawns[k])
	return total
