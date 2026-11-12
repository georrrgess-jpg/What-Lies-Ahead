class_name MenuBackdrop
extends Node3D
## The live 3D scene behind the main menu. Shows a level's scenery (its
## RunDirector removed) with a slow cinematic camera drifting around the
## level's menu camera points, and cross-fades to another level when the
## player browses worlds. Level scenes load on a background thread so
## browsing doesn't hitch.

signal level_shown(level: LevelData)

const DRIFT := 0.035

var current: LevelData
var _scene: Node3D
var _camera: Camera3D
var _time := 0.0
var _from := Vector3(28, 9, 18)
var _to := Vector3(-2, 3, -4)
var _pending: LevelData
var _pending_path := ""
var _fade: ColorRect
var _cache := {}
var _fading := false


## `fade_rect` is a full-screen black ColorRect (in the menu's UI) used for
## cross-fades between backdrops.
func setup(fade_rect: ColorRect) -> void:
	_fade = fade_rect
	_camera = Camera3D.new()
	_camera.fov = 52.0
	_camera.far = 900.0
	add_child(_camera)
	_camera.make_current()


## Shows `level` (cross-fading if something is already shown).
func show_level(level: LevelData, instant := false) -> void:
	if level == null or level == current and _scene != null:
		return
	if not ResourceLoader.exists(level.scene_path):
		return
	_pending = level
	_pending_path = level.scene_path
	if not _cache.has(_pending_path):
		ResourceLoader.load_threaded_request(_pending_path)
	if instant or _scene == null:
		_swap_now(level, _load_now(_pending_path))
		_fade.modulate.a = 1.0
		create_tween().tween_property(_fade, "modulate:a", 0.0, 0.8)


func _load_now(path: String) -> PackedScene:
	if _cache.has(path):
		return _cache[path]
	var res: PackedScene = ResourceLoader.load_threaded_get(path) if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE else load(path)
	if res == null:
		res = load(path)
	_cache[path] = res
	return res


func _process(delta: float) -> void:
	_time += delta
	# Waiting for a threaded load to finish before cross-fading.
	if _pending and _pending != current:
		var status := ResourceLoader.THREAD_LOAD_LOADED if _cache.has(_pending_path) else ResourceLoader.load_threaded_get_status(_pending_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED and not _fading:
			_fading = true
			var level := _pending
			var tw := create_tween()
			tw.tween_property(_fade, "modulate:a", 1.0, 0.35)
			tw.tween_callback(func():
				_swap_now(level, _load_now(level.scene_path))
				_fading = false)
			tw.tween_property(_fade, "modulate:a", 0.0, 0.6)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_pending = current
	if _camera == null:
		return
	# Cinematic drift: a slow figure-eight around the menu viewpoint, always
	# looking at the target, with a gentle breathing height.
	var t := _time * DRIFT * TAU
	var side := (_to - _from).cross(Vector3.UP).normalized()
	var pos := _from + side * sin(t) * 5.0 + (_to - _from).normalized() * sin(t * 2.0) * 2.0 + Vector3.UP * sin(t * 1.3) * 0.8
	_camera.look_at_from_position(pos, _to + Vector3.UP * sin(t * 0.7) * 0.5)



func _swap_now(level: LevelData, packed: PackedScene) -> void:
	if packed == null:
		return
	if _scene:
		_scene.queue_free()
	_scene = packed.instantiate()
	# Scenery only: the menu does not run a level.
	for n in _scene.find_children("*", "", true, false):
		if n.name == "RunDirector":
			n.get_parent().remove_child(n)
			n.free()
			break
	add_child(_scene)
	current = level
	_pending = level
	_from = level.menu_camera_from
	_to = level.menu_camera_to
	_time = 0.0
	if _camera:
		_camera.make_current()
	# Level music in the menu would clash with the menu theme; ambience is fine.
	Sfx.play_ambience(level.ambience, level.ambience_volume_db - 6.0)
	level_shown.emit(level)
