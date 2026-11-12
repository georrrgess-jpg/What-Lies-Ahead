extends Node
## Small audio helper: one-shot UI/world sounds by name, plus looping music
## and ambience. Sounds are looked up in res://audio/sfx/<name>.wav; a missing
## file is skipped quietly so gameplay never depends on audio assets.

const SFX_DIR := "res://audio/sfx/"
const MUSIC_DIR := "res://audio/music/"

## How many copies of one sound may play at once (stops nine pellets or a
## crowd of groans from stacking into noise).
const MAX_VOICES := 4

var _cache := {}
var _variants := {}
var _voices := {}
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _music_name := ""
var _ambience_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = &"Ambience"
	add_child(_ambience)


func stream(sound: StringName) -> AudioStream:
	if sound == &"":
		return null
	if _cache.has(sound):
		return _cache[sound]
	var s: AudioStream = null
	for path in [SFX_DIR + sound + ".wav", MUSIC_DIR + sound + ".ogg", SFX_DIR + sound + ".ogg"]:
		if ResourceLoader.exists(path):
			s = load(path)
			break
	_cache[sound] = s
	return s


## Loads every sound effect up front so the first shot or groan does not hitch.
func warm_up() -> void:
	var dir := DirAccess.open(SFX_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		# Exported builds list "name.wav.import" instead of "name.wav".
		var base := file.trim_suffix(".import")
		if base.ends_with(".wav"):
			stream(StringName(base.trim_suffix(".wav")))


## A sound may have numbered variants (name_b, name_c); one is picked at random.
func _pick(sound: StringName) -> AudioStream:
	if not _variants.has(sound):
		var list: Array = []
		for suffix in ["", "_b", "_c", "_d"]:
			var s := stream(StringName(String(sound) + suffix))
			if s:
				list.append(s)
		_variants[sound] = list
	var options: Array = _variants[sound]
	return options[randi() % options.size()] if not options.is_empty() else null


func _claim_voice(sound: StringName) -> bool:
	var n := int(_voices.get(sound, 0))
	if n >= MAX_VOICES:
		return false
	_voices[sound] = n + 1
	return true


func _release_voice(sound: StringName) -> void:
	_voices[sound] = maxi(0, int(_voices.get(sound, 1)) - 1)


## Non-positional one-shot (UI, the player's own weapon, announcer cues).
func play(sound: StringName, volume_db := 0.0, pitch := 1.0) -> void:
	var s := _pick(sound)
	if s == null or not _claim_voice(sound):
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = &"SFX"
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.finished.connect(func(): _release_voice(sound); p.queue_free())
	add_child(p)
	p.play()


## Positional one-shot in the current scene.
func play_at(sound: StringName, position: Vector3, volume_db := 0.0, pitch := 1.0, unit_size := 9.0) -> void:
	var s := _pick(sound)
	var scene := get_tree().current_scene
	if s == null or scene == null or not _claim_voice(sound):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = &"SFX"
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = unit_size
	p.max_distance = 70.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.finished.connect(func(): _release_voice(sound); p.queue_free())
	p.tree_exiting.connect(func(): if p.playing: _release_voice(sound))
	scene.add_child(p)
	p.global_position = position
	p.play()


func play_music(track: StringName, volume_db := -9.0) -> void:
	if track == _music_name and _music.playing:
		return
	_music_name = track
	_start_loop(_music, track, volume_db)


func stop_music() -> void:
	_music_name = ""
	_music.stop()


func play_ambience(track: StringName, volume_db := -8.0) -> void:
	if track == _ambience_name and _ambience.playing:
		return
	_ambience_name = track
	_start_loop(_ambience, track, volume_db)


func stop_ambience() -> void:
	_ambience_name = ""
	_ambience.stop()


func _start_loop(player: AudioStreamPlayer, track: StringName, volume_db: float) -> void:
	var s := stream(track)
	player.stop()
	if s == null:
		return
	if s is AudioStreamOggVorbis:
		s.loop = true
	elif s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = int(s.get_length() * s.mix_rate)
	player.stream = s
	player.volume_db = volume_db
	player.play()
