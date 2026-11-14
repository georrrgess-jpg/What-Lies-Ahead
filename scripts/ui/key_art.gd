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
