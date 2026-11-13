class_name CinePlayer
extends Node3D
## Plays a timeline of CineShots full-screen, locked to a music track.
##
## While it plays, the scene it was started over (the main menu) is taken out
## of the tree, so nothing of it renders, processes or hears input, and the
## music and ambience that were playing are paused. Everything is put back
## when the reel ends or is skipped (any key, click or button).
##
## Sets (level scenes, or the studio) are loaded and instantiated on a worker
## thread a few shots ahead, attached at their first cut and freed after their
## last shot, so at most a couple are alive at once. Each shot's actors hang
## off one node that is freed at the next cut.

signal ended

const LOOKAHEAD := 4
const MUSIC_DB := -3.0

var shots: Array[CineShot] = []
var music_path := "res://audio/music/showreel_trailer.ogg"
## Start at the shot containing this time (seconds on the timeline).
var start_at := 0.0
## Stop here (< 0: at the end of the last shot).
var stop_at := -1.0
## Rendering to a video: no skipping, and quit when done.
var render_mode := false
## Called once when the reel ends or is skipped.
var on_finished: Callable
## Print set load times and the worst frame times at the end.
var report := false

var camera: Camera3D
var overlay: CineOverlay
var _clock := 0.0
var _index := -1
var _running := false
var _done := false
var _stage: CineStage
var _actors: Node3D
var _music: AudioStreamPlayer
var _sets := {}
var _jobs := {}
var _loading := {}
var _results := {}
var _mutex := Mutex.new()
var _active_set := ""
var _suspended: Node
var _suspended_index := 0
var _paused: Array[AudioStreamPlayer] = []
var _last_tick := 0
var _worst: Array = []
var _load_ms := {}


func _ready() -> void:
	name = "CinePlayer"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var t := 0.0
	for s in shots:
		s.start = t
		t += s.length
	if stop_at < 0.0 or stop_at > t:
		stop_at = t
	_suspend_host()
	camera = Camera3D.new()
	camera.far = 1200.0
	add_child(camera)
	camera.make_current()
	overlay = CineOverlay.new()
	add_child(overlay)
	overlay.fade(1.0, 0.0)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	_music.stream = load(music_path)
	_music.volume_db = MUSIC_DB + Sfx.mix_db(StringName(music_path.get_file().get_basename()))
	add_child(_music)
	var first := maxi(0, _shot_at(start_at))
	_clock = shots[first].start if not shots.is_empty() else 0.0
	_prepare_from(first)
	if render_mode:
		# A video has no wall-clock: load the first set now so frame one is the shot.
		_wait_for(shots[first].set_id)
		_begin()


func _begin() -> void:
	_running = true
	overlay.fade(0.0, 0.0)
	_music.play(_clock)
	if render_mode:
		print("[showreel] start frame %d at %.2f s" % [Engine.get_process_frames(), _clock])


## The scene underneath leaves the tree (it keeps its state) and its sounds pause.
func _suspend_host() -> void:
	var tree := get_tree()
	var host := tree.current_scene
	if host and host != self:
		_suspended = host
		_suspended_index = host.get_index()
		tree.root.remove_child.call_deferred(host)
	tree.current_scene = self
	for c in Sfx.get_children():
		var p := c as AudioStreamPlayer
		if p and p.playing and not p.stream_paused:
			p.stream_paused = true
			_paused.append(p)


func _restore_host() -> void:
	var tree := get_tree()
	if _suspended and is_instance_valid(_suspended):
		if _suspended.get_parent() == null:
			tree.root.add_child(_suspended)
			tree.root.move_child(_suspended, mini(_suspended_index, tree.root.get_child_count() - 1))
		tree.current_scene = _suspended
		for c in _suspended.find_children("*", "Camera3D", true, false):
			var cam := c as Camera3D
			if cam.get_viewport() == get_viewport():
				cam.make_current()
				break
	for p in _paused:
		if is_instance_valid(p):
			p.stream_paused = false


## Ends playback (also what skipping does): restores the scene underneath,
## then calls on_finished and frees itself.
func finish() -> void:
	if _done:
		return
	_done = true
	Engine.time_scale = 1.0
	_music.stop()
	Sfx.cut_positional()
	if report:
		_print_report()
	if render_mode:
		get_tree().quit()
		return
	if _actors:
		_actors.queue_free()
	for id in _sets:
		_sets[id].queue_free()
	for id in _loading:
		ResourceLoader.load_threaded_get(_loading[id])
	for id in _jobs:
		WorkerThreadPool.wait_for_task_completion(_jobs[id])
	for id in _results:
		(_results[id] as Node).free()
	camera.current = false
	remove_child(camera)
	camera.queue_free()
	_restore_host()
	ended.emit()
	if on_finished.is_valid():
		on_finished.call()
	queue_free()


func _input(event: InputEvent) -> void:
	if render_mode or _done:
		return
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed() and not event.is_echo()
	get_viewport().set_input_as_handled()
	if pressed:
		finish()


func _process(delta: float) -> void:
	if _done:
		return
	_track_frame_time()
	if not _running:
		var first := _shot_at(_clock)
		_collect_jobs()
		if first >= 0 and _sets.has(shots[first].set_id):
			_begin()
		return
	_clock += delta / maxf(Engine.time_scale, 0.0001)
	if _clock >= stop_at:
		finish()
		return
	var i := _shot_at(_clock)
	if i != _index:
		_cut(i)
	_collect_jobs()
	if _stage:
		_stage.update(_clock - shots[_index].start, delta)


func _shot_at(time: float) -> int:
	for i in shots.size():
		if time < shots[i].start + shots[i].length:
			return i
	return shots.size() - 1


## Seconds into the reel (for tools that capture at a time).
func clock() -> float:
	return _clock


## The shot playing now.
func current_shot() -> CineShot:
	return shots[_index] if _index >= 0 else null


func _cut(i: int) -> void:
	_index = i
	Engine.time_scale = 1.0
	overlay.clear_text()
	if _actors:
		_actors.queue_free()
	var shot := shots[i]
	if shot.set_id != _active_set:
		_attach_set(shot.set_id)
	_release_unused(i)
	_prepare_from(i + 1)
	_actors = Node3D.new()
	_actors.name = "Shot_" + shot.id
	add_child(_actors)
	overlay.reset_lens()
	camera.near = 0.05
	CineStage.restore_lighting(_sets[shot.set_id])
	_stage = CineStage.new(_actors, camera, overlay, _sets[shot.set_id], shot.length)
	shot.build.call(_stage)
	_stage.update(_clock - shot.start, 0.0)


func _attach_set(id: String) -> void:
	if _active_set != "" and _sets.has(_active_set):
		var old: Node3D = _sets[_active_set]
		if old.get_parent() == self:
			remove_child(old)
	if not _sets.has(id):
		_wait_for(id)
	var s: Node3D = _sets[id]
	var t0 := Time.get_ticks_usec()
	add_child(s)
	move_child(s, 0)
	_load_ms[id + " attach"] = (Time.get_ticks_usec() - t0) / 1000.0
	_active_set = id


## Frees sets no shot from `i` on uses again.
func _release_unused(i: int) -> void:
	var needed := {}
	for k in range(i, shots.size()):
		needed[shots[k].set_id] = true
	for id in _sets.keys():
		if not needed.has(id):
			(_sets[id] as Node).queue_free()
			_sets.erase(id)


## Starts loading the sets of the next few shots: the level scene loads on
## the engine's loader threads, then a worker thread instantiates it.
func _prepare_from(i: int) -> void:
	for k in range(i, mini(i + LOOKAHEAD, shots.size())):
		var id := shots[k].set_id
		if _sets.has(id) or _jobs.has(id) or _loading.has(id):
			continue
		if id == "studio":
			_sets[id] = CineStudio.new()
			continue
		var level := GameData.level(StringName(id))
		if level == null:
			push_warning("showreel: unknown set " + id)
			_sets[id] = CineStudio.new()
			continue
		_loading[id] = level.scene_path
		_load_ms[id + " requested"] = snappedf(_clock, 0.01)
		ResourceLoader.load_threaded_request(level.scene_path)


## Worker thread: instantiates a loaded level as scenery (no RunDirector).
func _build_level(id: String, packed: PackedScene) -> void:
	var t0 := Time.get_ticks_usec()
	var root: Node3D = packed.instantiate() if packed else Node3D.new()
	for n in root.find_children("RunDirector", "", true, false):
		n.get_parent().remove_child(n)
		n.free()
	_mutex.lock()
	_results[id] = root
	_load_ms[id + " instantiate"] = (Time.get_ticks_usec() - t0) / 1000.0
	_mutex.unlock()


## Hands finished loads to a worker and collects finished instances.
func _collect_jobs() -> void:
	for id in _loading.keys():
		var status := ResourceLoader.load_threaded_get_status(_loading[id])
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_start_instance(id)
	for id in _jobs.keys():
		if WorkerThreadPool.is_task_completed(_jobs[id]):
			_finish_job(id)


func _start_instance(id: String) -> void:
	var packed := ResourceLoader.load_threaded_get(_loading[id]) as PackedScene
	_loading.erase(id)
	_load_ms[id + " loaded"] = snappedf(_clock, 0.01)
	_jobs[id] = WorkerThreadPool.add_task(_build_level.bind(id, packed), false, "showreel set " + id)


## Blocks until set `id` exists (only when a cut comes before its load is done).
func _wait_for(id: String) -> void:
	var t0 := Time.get_ticks_usec()
	if _loading.has(id):
		_start_instance(id)
	if _jobs.has(id):
		_finish_job(id)
	_load_ms[id + " waited"] = (Time.get_ticks_usec() - t0) / 1000.0


func _finish_job(id: String) -> void:
	WorkerThreadPool.wait_for_task_completion(_jobs[id])
	_jobs.erase(id)
	_mutex.lock()
	var root: Node3D = _results.get(id)
	_results.erase(id)
	_mutex.unlock()
	_sets[id] = root if root else CineStudio.new()


func _track_frame_time() -> void:
	var now := Time.get_ticks_usec()
	if _last_tick > 0 and _running and _index >= 0:
		_worst.append([(now - _last_tick) / 1000.0, shots[_index].id, snappedf(_clock, 0.01)])
		_worst.sort_custom(func(a, b): return a[0] > b[0])
		if _worst.size() > 5:
			_worst.resize(5)
	_last_tick = now


func _print_report() -> void:
	print("[showreel] set timings (ms): ", _load_ms)
	print("[showreel] worst frames (ms, shot, time): ", _worst)
