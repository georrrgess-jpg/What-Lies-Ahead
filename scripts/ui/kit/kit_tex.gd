class_name KitTex
extends RefCounted
## The kit's materials: textures from art/ui/ (tools/gen_ui_textures.py) and
## the 9-slice style boxes made from them. Everything is cached, so asking
## for the same box twice costs nothing.
##
##   panel.add_theme_stylebox_override("panel", KitTex.box(&"signboard"))
##   icon.texture = KitTex.tex(&"icon_spark")

const DIR := "res://art/ui/"

## name: [margin_x, margin_y, pad (shadow/glow outside the shape), content_x, content_y]
## Margins are the 9-slice corners; `pad` becomes the expand margin so the
## painted shape (not its shadow) lines up with the control's rectangle.
const SPECS := {
	&"metal_frame": [64, 64, 8, 40, 38],
	&"metal_plate": [40, 40, 8, 26, 20],
	&"signboard": [60, 60, 10, 38, 34],
	&"marquee": [56, 56, 10, 44, 30],
	&"neon_plate": [36, 36, 12, 20, 12],
	&"card": [28, 28, 10, 12, 12],
	&"card_hover": [28, 28, 10, 12, 12],
	&"card_selected": [28, 28, 10, 12, 12],
	&"focus_ring": [30, 30, 14, 0, 0],
	&"shadow": [40, 40, 16, 0, 0],
	&"keycap": [20, 20, 2, 14, 6],
}
## Button families: [margin_x, margin_y, pad, content_x, content_top, content_bottom, press_drop]
const BUTTONS := {
	&"btn": [38, 34, 10, 34, 12, 20, 5],
	&"sign_back": [44, 30, 10, 42, 10, 17, 4],
	&"btn_icon": [30, 30, 8, 12, 10, 16, 4],
}

static var _textures := {}
static var _boxes := {}


## The texture art/ui/<name>.png (null if it does not exist).
static func tex(name: StringName) -> Texture2D:
	if not _textures.has(name):
		var path := DIR + String(name) + ".png"
		_textures[name] = load(path) if ResourceLoader.exists(path) else null
	return _textures[name]


## A shared 9-slice box for `name` (see SPECS). Do not modify the result;
## use box_copy() for a box you want to tint or re-pad.
static func box(name: StringName) -> StyleBoxTexture:
	if not _boxes.has(name):
		_boxes[name] = _make(name)
	return _boxes[name]


## A private copy of box(name), optionally tinted and with its own padding.
static func box_copy(name: StringName, tint := Color.WHITE, content := Vector2(-1, -1)) -> StyleBoxTexture:
	var sb: StyleBoxTexture = box(name).duplicate()
	sb.modulate_color = tint
	if content.x >= 0.0:
		sb.content_margin_left = content.x
		sb.content_margin_right = content.x
	if content.y >= 0.0:
		sb.content_margin_top = content.y
		sb.content_margin_bottom = content.y
	return sb


## The box of one state of a button family: button(&"btn", &"pink", &"hover").
## Families: btn (colours pink, teal, gold, purple, grey), sign_back, btn_icon.
static func button(family: StringName, color: StringName, state: StringName) -> StyleBoxTexture:
	var file := String(family) + ("_" + String(color) if color != &"" else "") + "_" + String(state)
	var key := StringName(file)
	if _boxes.has(key):
		return _boxes[key]
	var spec: Array = BUTTONS[family]
	var sb := StyleBoxTexture.new()
	sb.texture = tex(key)
	sb.texture_margin_left = spec[0]
	sb.texture_margin_right = spec[0]
	sb.texture_margin_top = spec[1]
	sb.texture_margin_bottom = spec[1]
	sb.set_expand_margin_all(spec[2])
	sb.content_margin_left = spec[3]
	sb.content_margin_right = spec[3]
	var drop: int = spec[6] if state == &"pressed" else 0
	sb.content_margin_top = spec[4] + drop
	sb.content_margin_bottom = spec[5] - drop
	_boxes[key] = sb
	return sb


static func _make(name: StringName) -> StyleBoxTexture:
	var spec: Array = SPECS[name]
	var sb := StyleBoxTexture.new()
	sb.texture = tex(name)
	sb.texture_margin_left = spec[0]
	sb.texture_margin_right = spec[0]
	sb.texture_margin_top = spec[1]
	sb.texture_margin_bottom = spec[1]
	sb.set_expand_margin_all(spec[2])
	sb.content_margin_left = spec[3]
	sb.content_margin_right = spec[3]
	sb.content_margin_top = spec[4]
	sb.content_margin_bottom = spec[4]
	return sb
