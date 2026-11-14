class_name KeyArt
extends RefCounted
## Key-art stills of the levels: art/keyart/<level_id>.jpg, rendered from each
## level's menu camera by tools/capture_keyart.gd. Used by the loading screen
## and the Play page's world cards; both fall back to their plain look when a
## level has no still yet.

const DIR := "res://art/keyart/"
const CARD_SHADER := "res://art/shaders/ui_keyart_card.gdshader"

## Stills by level id, kept for the session: the menu is rebuilt after every
## run and would otherwise read all ten from disk again on the main thread.
static var _cache := {}


## Starts loading every level's still on the loader thread.
static func prefetch() -> void:
	for level in _levels():
		var path := DIR + String(level.id) + ".jpg"
		if not _cache.has(level.id) and ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path)


## True once every still prefetch() asked for has loaded (texture() then
## returns at once).
static func prefetched() -> bool:
	for level in _levels():
		var path := DIR + String(level.id) + ".jpg"
		if not _cache.has(level.id) and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return false
	return true


static func _levels() -> Array[LevelData]:
	var out: Array[LevelData] = []
	for w in GameData.worlds():
		out.append_array(w.levels)
	return out


## The still for `level`, or null if none has been rendered.
static func texture(level: LevelData) -> Texture2D:
	if level == null:
		return null
	if not _cache.has(level.id):
		var path := DIR + String(level.id) + ".jpg"
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_cache[level.id] = ResourceLoader.load_threaded_get(path)
		else:
			_cache[level.id] = load(path) if ResourceLoader.exists(path) else null
	return _cache[level.id]


## Calls `done(texture)` with the still for `level` (null if it has none):
## at once when it is loaded, else once the loader thread has read it, so a
## screen that opens with key art does not wait on the disk.
static func request(level: LevelData, done: Callable) -> void:
	if level == null or _cache.has(level.id):
		done.call(texture(level))
		return
	var path := DIR + String(level.id) + ".jpg"
	if not ResourceLoader.exists(path):
		done.call(null)
		return
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)
	var tree := Engine.get_main_loop() as SceneTree
	var poll := func(again: Callable) -> void:
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			tree.process_frame.connect(again.bind(again), CONNECT_ONE_SHOT)
		elif done.is_valid():
			done.call(texture(level))
	tree.process_frame.connect(poll.bind(poll), CONNECT_ONE_SHOT)
