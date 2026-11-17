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
static var _scaled := {}


## The texture art/ui/<name>.png (null if it does not exist).
static func tex(name: StringName) -> Texture2D:
	if not _textures.has(name):
		var path := DIR + String(name) + ".png"
		_textures[name] = load(path) if ResourceLoader.exists(path) else null
	return _textures[name]


## `box` at `scale` (0.5: half): the same frame drawn smaller, for a control
## shorter or narrower than the frame's texture. A 9-slice drawn below its
## texture size squeezes its middle rows (and below its borders squashes its
## corners), which smears a thin band across the control; a smaller copy of
## the frame stretches instead. Cached; content margins stay as they are, so
## the control keeps its size and padding.
static func scaled_box(box: StyleBoxTexture, scale: float) -> StyleBoxTexture:
	var key := "%d@%.2f" % [box.get_instance_id(), scale]
	if _scaled.has(key):
		return _scaled[key]
	var img := box.texture.get_image()
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.resize(maxi(1, roundi(img.get_width() * scale)), maxi(1, roundi(img.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	var sb: StyleBoxTexture = box.duplicate()
	sb.texture = ImageTexture.create_from_image(img)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, roundf(box.get_texture_margin(side) * scale))
		sb.set_expand_margin(side, roundf(box.get_expand_margin(side) * scale))
	sb.set_meta(&"kit_base", box)
	_scaled[key] = sb
	return sb


## Fits every frame state of `c` (normal, hover, pressed...) to its size: a
## smaller copy of the frame while the control is smaller than the frame's
## texture, the full frame again when it grows (see scaled_box). Kit buttons
## and tiles call it when they resize and after they change a frame.
static func fit_frames(c: Control) -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"panel"]:
		if not c.has_theme_stylebox_override(state):
			continue
		var sb := c.get_theme_stylebox(state) as StyleBoxTexture
		if sb == null or sb.texture == null:
			continue
		var base: StyleBoxTexture = sb.get_meta(&"kit_base", sb)
		var scale := fit_scale(base, c.size)
		var want := base if scale >= 1.0 else scaled_box(base, scale)
		if want != sb:
			c.add_theme_stylebox_override(state, want)


## The largest of 1, 1/2 and 1/4 at which `box` fits a control of `size`
## (with the frame's expand margins): its borders fit and at least half of
## the texture's middle rows and columns survive (min_frame_size). A mild
## squeeze of a plain middle is invisible; a heavy one smears a band.
static func fit_scale(box: StyleBoxTexture, size: Vector2) -> float:
	for scale: float in [1.0, 0.5, 0.25]:
		var w: float = size.x + (box.expand_margin_left + box.expand_margin_right) * scale
		var h: float = size.y + (box.expand_margin_top + box.expand_margin_bottom) * scale
		var need := min_frame_size(box) * scale
		if need.x <= w + 0.5 and need.y <= h + 0.5:
			return scale
	return 0.25


## The smallest drawn size (expand margins included) at which `box` looks
## right: its borders plus half of its middle, on each axis.
static func min_frame_size(box: StyleBoxTexture) -> Vector2:
	var tex := box.texture.get_size()
	var borders := Vector2(box.texture_margin_left + box.texture_margin_right, box.texture_margin_top + box.texture_margin_bottom)
	return borders + (tex - borders) * 0.5


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
