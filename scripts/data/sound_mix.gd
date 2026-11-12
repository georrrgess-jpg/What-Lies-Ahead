class_name SoundMix
extends Resource
## The game's mix table (audio/mix.tres). Every sound belongs to a category; a
## category sets the bus it plays on and a gain in dB that Sfx adds to the
## volume each call asks for, and a single sound can carry a trim on top.
## Balance the game here rather than at call sites, and re-check the result
## with `python3 tools/audio_mix_report.py`.

## Category -> gain (dB) added to every sound in it.
@export var category_gain_db: Dictionary[StringName, float] = {}
## Category -> the bus its sounds play on (a category not listed uses "SFX").
@export var category_bus: Dictionary[StringName, StringName] = {}
## Sound name -> category. A key ending in "_" is a prefix rule ("cos_kill_"
## covers "cos_kill_coins"); an exact name beats a prefix, a longer prefix a
## shorter one.
@export var sound_category: Dictionary[StringName, StringName] = {}
## Sound name -> fine trim (dB) on top of its category gain.
@export var sound_trim_db: Dictionary[StringName, float] = {}
## Category of a sound the table does not list.
@export var default_category: StringName = &"misc"


## The category `sound` belongs to.
func category_of(sound: StringName) -> StringName:
	if sound_category.has(sound):
		return sound_category[sound]
	var sound_name := String(sound)
	var best := ""
	for key: StringName in sound_category:
		var rule := String(key)
		if rule.ends_with("_") and rule.length() > best.length() and sound_name.begins_with(rule):
			best = rule
	return sound_category[StringName(best)] if best != "" else default_category


## Gain in dB the mix adds to `sound`.
func gain_db(sound: StringName) -> float:
	return float(category_gain_db.get(category_of(sound), 0.0)) + float(sound_trim_db.get(sound, 0.0))


## The bus `sound` plays on.
func bus_of(sound: StringName) -> StringName:
	return category_bus.get(category_of(sound), &"SFX")
