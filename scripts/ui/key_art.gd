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


## The still for `level`, or null if none has been rendered.
static func texture(level: LevelData) -> Texture2D:
	if level == null:
		return null
	if not _cache.has(level.id):
		var path := DIR + String(level.id) + ".jpg"
		_cache[level.id] = load(path) if ResourceLoader.exists(path) else null
	return _cache[level.id]
