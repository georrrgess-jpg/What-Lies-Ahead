extends Node
## Game-wide event bus. Systems that live outside a level (progression,
## achievements, cosmetics unlocks, stats) listen here instead of reaching into
## the run director.

signal run_started(director: Node)
signal enemy_killed(enemy: Node, weapon_id: StringName, headshot: bool, points: int)
signal wave_cleared(wave_number: int, total_waves: int)
## Emitted once per run (victory, defeat or abandon) with RunDirector.result().
signal run_finished(result: Dictionary)
