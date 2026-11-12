extends Node
## Small audio helper: one-shot UI/world sounds by name, plus looping music
## and ambience. Sounds are looked up in res://audio/sfx/<name>.wav; a missing
## file is skipped quietly so gameplay never depends on audio assets.
##
## Levels are set in one place: every sound gets the gain and bus of its
## category in the mix table (audio/mix.tres) on top of the volume a call asks
## for. Music and ambience changes cross-fade.

const SFX_DIR := "res://audio/sfx/"
const MUSIC_DIR := "res://audio/music/"
## Per-category (and per-sound) gain and bus. See SoundMix.
const MIX: SoundMix = preload("res://audio/mix.tres")

## How many copies of one sound may play at once (stops nine pellets or a
## crowd of groans from stacking into noise).
const MAX_VOICES := 4
## How far (dB) a positional sound may rise above its volume when it is closer
## than its unit size. (Godot's own cap is an absolute +3 dB, which made every
## nearby sound equally loud whatever its volume.)
const NEAR_HEADROOM_DB := 3.0
## Seconds a music or ambience change takes to cross-fade.
const CROSSFADE := 0.6
## Positional sounds beyond this distance are not played.
const MAX_DISTANCE := 70.0
## Mix categories that are the player's own feedback (hits, pops, kill
## effects, their weapon's world sounds). play_at plays them flat, with the
## distance falloff worked out once at the start, instead of as 3D players:
## dozens of short 3D players a second each rewrite their bus routing every
## frame, which in Godot 4.7 races the audio mixer thread (a rare crash in
## AudioServer::_mix_step). Enemy voices, attacks and telegraphs stay 3D,
## where direction matters.
const FLAT_CATEGORIES: Array[StringName] = [&"impact", &"confirm", &"kill_effect", &"weapon"]

var _cache := {}
var _variants := {}
var _voices := {}
var _mix := {}
var _music: LoopDeck
var _ambience: LoopDeck


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = LoopDeck.new(self, &"Music", CROSSFADE)
	_ambience = LoopDeck.new(self, &"Ambience", CROSSFADE)


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


## Gain (dB) the mix table adds to `sound`, for code that plays a stream from
## stream() on its own player.
func mix_db(sound: StringName) -> float:
	return _mix_of(sound)[0]


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


## [gain_db, bus, flat] of a sound, worked out once.
func _mix_of(sound: StringName) -> Array:
	if not _mix.has(sound):
		_mix[sound] = [MIX.gain_db(sound), MIX.bus_of(sound), MIX.category_of(sound) in FLAT_CATEGORIES]
	return _mix[sound]


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


## Keeps at most MAX_VOICES copies of a sound; when full, the oldest copy is
## cut so the newest (usually the most important) is always heard.
func _claim_voice(sound: StringName, player: Node) -> void:
	var list: Array = _voices.get(sound, [])
	list = list.filter(func(p): return is_instance_valid(p))
	while list.size() >= MAX_VOICES:
		var oldest: Node = list.pop_front()
		oldest.queue_free()
	list.append(player)
	_voices[sound] = list


## Non-positional one-shot (UI, the player's own weapon, announcer cues).
func play(sound: StringName, volume_db := 0.0, pitch := 1.0) -> void:
	var s := _pick(sound)
	if s == null:
		return
	var mix := _mix_of(sound)
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = mix[1]
	p.volume_db = volume_db + mix[0]
	p.pitch_scale = pitch
	p.finished.connect(p.queue_free)
	_claim_voice(sound, p)
	add_child(p)
	p.play()


## Positional one-shot in the current scene.
func play_at(sound: StringName, position: Vector3, volume_db := 0.0, pitch := 1.0, unit_size := 9.0) -> void:
	var s := _pick(sound)
	var scene := get_tree().current_scene
	if s == null or scene == null:
		return
	var mix := _mix_of(sound)
	if mix[2]:
		_play_flat_at(s, sound, position, volume_db + mix[0], mix[1], pitch, unit_size)
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = mix[1]
	p.volume_db = volume_db + mix[0]
	p.max_db = p.volume_db + NEAR_HEADROOM_DB
	p.pitch_scale = pitch
	p.unit_size = unit_size
	p.max_distance = MAX_DISTANCE
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.finished.connect(p.queue_free)
	_claim_voice(sound, p)
	scene.add_child(p)
	p.global_position = position
	p.play()


## A positional sound played without a 3D player: the same inverse-distance
## falloff a 3D player would apply, worked out once from the camera.
func _play_flat_at(s: AudioStream, sound: StringName, position: Vector3, volume_db: float, bus: StringName, pitch: float, unit_size: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var distance := camera.global_position.distance_to(position) if camera else unit_size
	if distance > MAX_DISTANCE:
		return
	var falloff := minf(NEAR_HEADROOM_DB, linear_to_db(unit_size / maxf(distance, 0.01)))
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = bus
	p.volume_db = volume_db + falloff
	p.pitch_scale = pitch
	p.finished.connect(p.queue_free)
	_claim_voice(sound, p)
	add_child(p)
	p.play()


## Cross-fades to a music loop. With `in_time`, a loop of the same length
## starts where the current one is, so a variant of the same song (a level's
## final-wave loop) takes over mid-bar.
## Asking for the track that already plays only fades it to the new volume.
func play_music(track: StringName, volume_db := -9.0, in_time := false) -> void:
	_music.play(track, _loop_stream(track), volume_db + mix_db(track), in_time)


func stop_music() -> void:
	_music.stop()


## Cross-fades to an ambience bed (the playing bed just fades to the new volume).
func play_ambience(track: StringName, volume_db := -8.0) -> void:
	_ambience.play(track, _loop_stream(track), volume_db + mix_db(track), false)


func stop_ambience() -> void:
	_ambience.stop()


func _loop_stream(track: StringName) -> AudioStream:
	var s := stream(track)
	if s is AudioStreamOggVorbis:
		s.loop = true
	elif s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = int(s.get_length() * s.mix_rate)
	return s


## Two players that cross-fade one looping track into the next (equal power).
class LoopDeck:
	extends RefCounted

	var track := &""
	var _host: Node
	var _fade_time: float
	var _current: AudioStreamPlayer
	var _previous: AudioStreamPlayer
	var _tween: Tween
	var _crossfading := false
	var _from_db := 0.0
	var _to_db := 0.0

	func _init(host: Node, bus: StringName, fade_time: float) -> void:
		_host = host
		_fade_time = fade_time
		_current = _add_player(bus)
		_previous = _add_player(bus)

	## Fades `stream` in over whatever plays now (a null stream just fades out).
	## The track that already plays is only faded to `volume_db`.
	func play(track_name: StringName, stream: AudioStream, volume_db: float, in_time: bool) -> void:
		if track_name == track and _current.playing:
			_retarget(volume_db)
			return
		if stream == null:
			stop()
			return
		var start := 0.0
		var old := _current.stream
		if in_time and _current.playing and old and absf(old.get_length() - stream.get_length()) < 0.05:
			start = fmod(_current.get_playback_position(), stream.get_length())
		_hand_over()
		track = track_name
		_to_db = volume_db
		_current.stream = stream
		_set_mix(0.0)
		_current.play(start)

	func stop() -> void:
		track = &""
		_hand_over()

	func _retarget(volume_db: float) -> void:
		if is_equal_approx(volume_db, _to_db):
			return
		_to_db = volume_db
		if _crossfading:
			return  # the cross-fade under way lands on the new level
		if _tween:
			_tween.kill()
		_tween = _host.create_tween()
		_tween.tween_property(_current, "volume_db", volume_db, _fade_time)

	## The playing track becomes the one fading out; a track still fading out
	## from an earlier change is cut.
	func _hand_over() -> void:
		if _tween:
			_tween.kill()
		_previous.stop()
		var spare := _previous
		_previous = _current
		_from_db = _current.volume_db
		_current = spare
		_current.stop()
		_crossfading = true
		_tween = _host.create_tween()
		_tween.tween_method(_set_mix, 0.0, 1.0, _fade_time)
		_tween.tween_callback(_end_fade)

	func _end_fade() -> void:
		_previous.stop()
		_crossfading = false

	func _set_mix(k: float) -> void:
		_current.volume_db = _to_db + linear_to_db(maxf(sin(k * PI * 0.5), 0.001))
		_previous.volume_db = _from_db + linear_to_db(maxf(cos(k * PI * 0.5), 0.001))

	func _add_player(bus: StringName) -> AudioStreamPlayer:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		_host.add_child(p)
		return p
