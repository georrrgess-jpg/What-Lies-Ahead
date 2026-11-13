class_name MenuBackdrop
extends Node3D
## The live 3D scene behind the main menu. Shows a level's scenery with a
## slow cinematic camera drifting around the level's menu camera points, and
## dips through the menu's veil to another level when the player browses
## worlds.
##
## Nothing here blocks a frame: the level scene loads on a loader thread, and
## the swap is spread over the frames the veil is dark: the old scene leaves
## on one frame, the new one is instantiated and trimmed for the menu on the
## next, enters the tree on the one after, and the old one is freed a branch
## per frame after that.
##
## Trimmed for the menu (the menu runs no level, and the camera barely moves):
##   - gameplay only: the RunDirector, collision shapes, the navigation mesh;
##   - props behind the camera or smaller on screen than MIN_ANGLE are hidden,
##     small far props stop casting shadows, lights that cannot reach the view
##     are switched off, and the sun's shadows end at SHADOW_DISTANCE.
## PackedScenes stay cached (CACHE of them; the one on screen survives a run,
## so coming back from a level shows it again without a load).

signal level_shown(level: LevelData)

const DRIFT := 0.035
## Veil in and out when the world changes, seconds.
const FADE_OUT := 0.25
const FADE_IN := 0.5
## Level scenes kept loaded while the menu is open.
const CACHE := 3
## A world must stay selected this long before it loads, so flicking
## through the carousel does not start a load for every world passed.
const SETTLE := 0.2
## Props whose bounding sphere covers less than this angle (radians) are
## hidden: about 9 px across on a 1080p screen.
const MIN_ANGLE := 0.0085
## How far the drifting camera strays from its anchor, metres.
const STRAY := 6.0
## Props below this radius stop casting shadows past SHADOW_NEAR metres.
const SMALL_CASTER := 1.2
const SHADOW_NEAR := 22.0
const SHADOW_DISTANCE := 60.0
## Nodes the menu never needs, by class.
const GAMEPLAY_ONLY := ["CollisionShape3D", "CollisionPolygon3D"]

## PackedScenes by path, most recent last (shared between menu visits).
static var _cache := {}

var current: LevelData
var _scene: Node3D
var _camera: Camera3D
var _time := 0.0
## Seconds since the shown level came up (the camera drift's clock).
var _drift := 0.0
var _from := Vector3(28, 9, 18)
var _to := Vector3(-2, 3, -4)
var _fade: ColorRect
## The level the menu asked for last, and when.
var _wanted: LevelData
var _wanted_at := 0.0
## The one scene loading on the loader thread ("" when none).
var _loading := ""
## The level being swapped in and its loaded scene.
var _building: LevelData
var _packed_scene: PackedScene
var _built: Node3D
## Old scenes out of the tree, freed one branch per frame.
var _trash: Array[Node] = []
var _veil: Tween
## 0: idle, 1: veil going dark, 2: old scene out (instantiate next frame),
## 3: instantiated (enters the tree next frame).
var _swap_step := 0


## `fade_rect` is a full-screen ColorRect (in the menu's UI) used as the veil
## between backdrops. It starts opaque until the first world is up.
func setup(fade_rect: ColorRect) -> void:
	_fade = fade_rect
	_fade.modulate.a = 1.0
	_camera = Camera3D.new()
	_camera.fov = 52.0
	_camera.far = 900.0
	add_child(_camera)
	_camera.make_current()


## Shows `level`, loading it in the background. `instant` is kept for callers:
## the first world always fades in from the veil once it is ready.
func show_level(level: LevelData, _instant := false) -> void:
	if level == null or not ResourceLoader.exists(level.scene_path):
		return
	if level != _wanted:
		_wanted = level
		_wanted_at = _time


## True once the asked-for world is on screen and the veil has lifted.
func is_settled() -> bool:
	return _wanted == null or (current == _wanted and _swap_step == 0 and _fade.modulate.a < 0.01)


func _exit_tree() -> void:
	if _built:
		_built.free()
	for n in _trash:
		if is_instance_valid(n):
			n.free()
	_trash.clear()
	# Keep only what is on screen for the next visit.
	for path in _cache.keys():
		if current == null or path != current.scene_path:
			_cache.erase(path)


func _process(delta: float) -> void:
	_time += delta
	_drift += delta
	if _swap_step == 0:
		_free_some()
	_advance()
	if _camera == null:
		return
	# Cinematic drift: a slow figure-eight around the menu viewpoint, always
	# looking at the target, with a gentle breathing height.
	var t := _drift * DRIFT * TAU
	var side := (_to - _from).cross(Vector3.UP).normalized()
	var pos := _from + side * sin(t) * 5.0 + (_to - _from).normalized() * sin(t * 2.0) * 2.0 + Vector3.UP * sin(t * 1.3) * 0.8
	_camera.look_at_from_position(pos, _to + Vector3.UP * sin(t * 0.7) * 0.5)


## One step of load -> veil -> swap -> unveil per frame at most.
func _advance() -> void:
	match _swap_step:
		1:
			return
		2:
			_build()
			return
		3:
			_add_built()
			return
	if _loading != "" and not _finish_load():
		return
	if _wanted == null or _wanted == current or (current and _time - _wanted_at < SETTLE):
		return
	var path := _wanted.scene_path
	if not _cache.has(path):
		_loading = path
		ResourceLoader.load_threaded_request(path)
		return
	_packed_scene = _cache[path]
	# Most recently used last.
	_cache.erase(path)
	_cache[path] = _packed_scene
	_building = _wanted
	_veil_out()


## Collects the scene loading on the loader thread into the cache once it is
## done. False while it is still loading.
func _finish_load() -> bool:
	var status := ResourceLoader.load_threaded_get_status(_loading)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return false
	var packed: PackedScene = null
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		packed = ResourceLoader.load_threaded_get(_loading) as PackedScene
	if packed:
		_cache[_loading] = packed
		while _cache.size() > CACHE:
			_cache.erase(_cache.keys()[0])
	elif _wanted and _wanted.scene_path == _loading:
		# A level that does not load leaves the world as it is.
		_wanted = current
	_loading = ""
	return true


## Instantiates the level (out of the tree) and trims it for the menu.
func _build() -> void:
	var level := _building
	var scene := _packed_scene.instantiate() as Node3D
	_packed_scene = null
	_swap_step = 3
	if scene:
		var director := scene.find_child("RunDirector", true, false)
		if director:
			director.get_parent().remove_child(director)
			director.free()
		var view := _View.new(level.menu_camera_from, level.menu_camera_to)
		_trim(scene, scene.transform, view)
	_built = scene
	if scene == null:
		_swap_step = 0
		_wanted = current
		_veil_in()


func _trim(node: Node, xform: Transform3D, view: _View) -> void:
	for child in node.get_children():
		if child.get_class() in GAMEPLAY_ONLY:
			node.remove_child(child)
			child.free()
			continue
		var x := xform
		if child is Node3D:
			x = xform * (child as Node3D).transform
		if child is NavigationRegion3D:
			(child as NavigationRegion3D).navigation_mesh = null
		elif child is GeometryInstance3D:
			view.trim_geometry(child as GeometryInstance3D, x)
		elif child is OmniLight3D or child is SpotLight3D:
			view.trim_light(child as Light3D, x)
		_trim(child, x, view)


## Veil goes dark, then the old scene leaves.
func _veil_out() -> void:
	_swap_step = 1
	if _veil and _veil.is_valid():
		_veil.kill()
	_veil = create_tween()
	_veil.tween_property(_fade, "modulate:a", 1.0, FADE_OUT * (1.0 - _fade.modulate.a)).set_trans(Tween.TRANS_SINE)
	_veil.tween_callback(_remove_old)


func _remove_old() -> void:
	if _scene:
		remove_child(_scene)
		_trash.append(_scene)
		_scene = null
	_swap_step = 2


## The new scene enters the tree, then the veil lifts.
func _add_built() -> void:
	_swap_step = 0
	var level := _building
	_scene = _built
	_built = null
	add_child(_scene)
	_tune_sun()
	current = level
	_from = level.menu_camera_from
	_to = level.menu_camera_to
	_drift = 0.0
	_camera.make_current()
	# Level music in the menu would clash with the menu theme; ambience is fine.
	Sfx.play_ambience(level.ambience, level.ambience_volume_db - 6.0)
	_veil_in()
	level_shown.emit(level)


func _veil_in() -> void:
	_veil = create_tween()
	# A moment for the new scene's first draws before the veil starts to lift.
	_veil.tween_interval(0.05)
	_veil.tween_property(_fade, "modulate:a", 0.0, FADE_IN).set_trans(Tween.TRANS_SINE)


## Shorter sun shadows: the menu view is a few dozen metres deep.
func _tune_sun() -> void:
	for child in _scene.get_children():
		var sun := child as DirectionalLight3D
		if sun and sun.shadow_enabled:
			sun.directional_shadow_max_distance = minf(sun.directional_shadow_max_distance, SHADOW_DISTANCE)


## Frees old scenes a branch at a time so no frame pays for a whole level.
func _free_some() -> void:
	if _trash.is_empty():
		return
	var n: Node = _trash[_trash.size() - 1]
	if not is_instance_valid(n):
		_trash.pop_back()
		return
	var last := n
	while last.get_child_count() > 0 and _count(last) > 400:
		last = last.get_child(last.get_child_count() - 1)
	if last == n:
		_trash.pop_back()
	last.free()


static func _count(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count(c)
		if total > 400:
			break
	return total


## The menu camera's view of a level, for deciding what it can never see.
class _View:
	var from: Vector3
	var forward: Vector3

	func _init(f: Vector3, t: Vector3) -> void:
		from = f
		forward = (t - f).normalized()

	func trim_geometry(gi: GeometryInstance3D, x: Transform3D) -> void:
		if not gi.visible:
			return
		var box := x * gi.get_aabb()
		var centre := box.get_center()
		var radius := box.size.length() * 0.5
		var dist := centre.distance_to(from)
		var behind := (centre - from).dot(forward) < -(radius * 3.0 + MenuBackdrop.STRAY)
		var tiny := radius / maxf(dist - MenuBackdrop.STRAY, 1.0) < MenuBackdrop.MIN_ANGLE
		if behind or tiny:
			gi.visible = false
		elif radius < MenuBackdrop.SMALL_CASTER and dist > MenuBackdrop.SHADOW_NEAR:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func trim_light(light: Light3D, x: Transform3D) -> void:
		var reach := (light as OmniLight3D).omni_range if light is OmniLight3D else (light as SpotLight3D).spot_range
		var to := x.origin - from
		if to.dot(forward) < -(reach + MenuBackdrop.STRAY) or to.length() > reach + 90.0:
			light.visible = false
		light.shadow_enabled = false
