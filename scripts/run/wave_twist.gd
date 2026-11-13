class_name WaveTwist
extends RefCounted
## Each world's environmental twist: a wave where the place itself joins in.
## A wave names one in WaveData.twist; the run director calls begin() when the
## wave starts, on_spawn() for every zombie and end() when it is cleared.
##
##   jackpot      Prize Pier: every ticket prize pays double
##   blackout     Neon Skyline: the block loses power; only the neon stays lit
##   frenzy       Tidal Tunnels: feeding time, the whole horde is enraged
##   low_gravity  Launch Pad 9: the gravity plating fails; long floaty jumps,
##                and the leapers and jetpacks go off more often
##   whiteout     Summit Lodge: the storm closes in (the level's FrostWeather
##                prop brings the fog and wind on the final wave)
##   power_cut    Midnight Mall: the mains trip (the level's environment script
##                cuts the lights to the moon and red emergency lamps)

const IDS: Array[StringName] = [&"jackpot", &"blackout", &"frenzy", &"low_gravity", &"whiteout", &"power_cut"]

const JACKPOT_TICKETS := 2.0
const BLACKOUT_LIGHT := 0.32
const BLACKOUT_SECONDS := 1.6
const LOW_GRAVITY := 0.45
const LOW_GRAVITY_SPECIALS := 0.6

var id: StringName
var _director: RunDirector
var _environment: Environment
var _ambient := 0.0
var _background := 0.0
var _lights := {}       # DirectionalLight3D -> its energy
var _gravity := 0.0


func _init(twist: StringName, director: RunDirector) -> void:
	id = twist
	_director = director


func begin() -> void:
	match id:
		&"jackpot":
			_director.ticket_scale = JACKPOT_TICKETS
		&"blackout":
			_dim(true)
		&"low_gravity":
			_gravity = _director.player.gravity
			_director.player.gravity = _gravity * LOW_GRAVITY


func end() -> void:
	match id:
		&"jackpot":
			_director.ticket_scale = 1.0
		&"blackout":
			_dim(false)
		&"low_gravity":
			_director.player.gravity = _gravity


## Called for every zombie spawned during the wave, before it enters the tree.
func on_spawn(z: Zombie) -> void:
	match id:
		&"frenzy":
			z.enrage.call_deferred(600.0)
		&"low_gravity":
			z.special_scale *= LOW_GRAVITY_SPECIALS
			for b in z.behaviours:
				if &"cooldown" in b:
					b.set(&"cooldown", float(b.get(&"cooldown")) * LOW_GRAVITY_SPECIALS)


## Fades the level's sky, ambient light and sun down (or back up).
func _dim(on: bool) -> void:
	var level := _director.get_parent()
	if _environment == null:
		var we := level.get_node_or_null("WorldEnvironment") as WorldEnvironment
		if we == null or we.environment == null:
			return
		# Work on a copy: the scene's resource is shared with the next Retry.
		we.environment = we.environment.duplicate()
		_environment = we.environment
		_ambient = _environment.ambient_light_energy
		_background = _environment.background_energy_multiplier
		for node in level.find_children("*", "DirectionalLight3D", true, false):
			_lights[node] = (node as DirectionalLight3D).light_energy
	var k := BLACKOUT_LIGHT if on else 1.0
	var tw := _director.create_tween().set_parallel()
	tw.tween_property(_environment, "ambient_light_energy", _ambient * k, BLACKOUT_SECONDS)
	tw.tween_property(_environment, "background_energy_multiplier", _background * k, BLACKOUT_SECONDS)
	for light in _lights:
		if is_instance_valid(light):
			tw.tween_property(light, "light_energy", float(_lights[light]) * k, BLACKOUT_SECONDS)
