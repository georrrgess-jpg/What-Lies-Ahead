class_name KeyArt
extends RefCounted
## Key-art stills of the levels: art/keyart/<level_id>.jpg, rendered from each
## level's menu camera by tools/capture_keyart.gd. Used by the loading screen
## and the Play page's world cards; both fall back to their plain look when a
## level has no still yet.

const DIR := "res://art/keyart/"
const CARD_SHADER := "res://art/shaders/ui_keyart_card.gdshader"


## The still for `level`, or null if none has been rendered.
static func texture(level: LevelData) -> Texture2D:
	if level == null:
		return null
	var path := DIR + String(level.id) + ".jpg"
	return load(path) if ResourceLoader.exists(path) else null
