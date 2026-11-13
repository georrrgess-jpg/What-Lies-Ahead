class_name HudBanner
extends Control
## Big-moment banner across the upper middle of the HUD: round intro, wave
## cleared, final wave, boss, portal open, level cleared, defeat. Three text
## layers (a small kicker, the title, a subtitle) over a dark band with two
## neon lines; the band wipes open, the title punches in, the other lines
## slide in after it, and everything leaves together.
##
##   banner.show_banner("WAVE 3 CLEARED", "+12 ENERGY", "", &"cleared")
##
## A new banner replaces the one on screen. If it arrives within MERGE_WINDOW
## of a round intro it keeps that intro's wave as its kicker, so a round-type
## banner sent right after wave_started reads "WAVE 4" over "BLITZ ROUND".

## style: [title colour, accent colour]
const STYLES := {
	&"wave": [Color.WHITE, UiKit.CYAN],
	&"final": [UiKit.PINK_LIGHT, UiKit.PINK],
	&"cleared": [Color.WHITE, UiKit.GREEN],
	&"boss": [Color(1.0, 0.86, 0.8), UiKit.RED],
	&"portal": [Color.WHITE, UiKit.CYAN],
	&"victory": [Color(1.0, 0.9, 0.6), UiKit.AMBER],
	&"defeat": [Color(1.0, 0.72, 0.76), UiKit.RED],
}
const MERGE_WINDOW := 0.4
const HOLD := 1.9
const TITLE_SIZE := 100
const TITLE_MIN_SIZE := 56
const BAND_TOP := 46.0
const BAND_HEIGHT := 122.0
const SUB_TOP := 176.0

static var _fade_texture: GradientTexture2D

var _band: TextureRect
var _lines: Array[TextureRect] = []
var _kicker: Label
var _title: Label
var _sub: Label
var _tween: Tween
var _blinks: Array[Tween] = []
var _started_msec := -100000
var _current_kicker := ""
var _current_is_intro := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 230)
	_band = _strip(BAND_TOP, BAND_HEIGHT)
	_band.modulate = Color(UiKit.INK, 0.0)
	for y in [BAND_TOP, BAND_TOP + BAND_HEIGHT - 5.0]:
		var line := _strip(y, 5.0)
		line.modulate.a = 0.0
		_lines.append(line)
	_kicker = _line_label(34, 0.0, 44.0)
	_title = _line_label(TITLE_SIZE, BAND_TOP, BAND_HEIGHT)
	_sub = _line_label(38, SUB_TOP, 50.0)
	_sub.add_theme_color_override("font_color", UiKit.CREAM)


func _strip(top: float, height: float) -> TextureRect:
	if _fade_texture == null:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.22, 0.78, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
		_fade_texture = GradientTexture2D.new()
		_fade_texture.gradient = grad
		_fade_texture.width = 256
		_fade_texture.height = 4
	var r := TextureRect.new()
	r.texture = _fade_texture
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_TOP_WIDE)
	r.offset_left = 180
	r.offset_right = -180
	r.offset_top = top
	r.offset_bottom = top + height
	add_child(r)
	return r


func _line_label(font_size: int, top: float, height: float) -> Label:
	var l := UiKit.arcade_label("", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = top
	l.offset_bottom = top + height
	l.modulate.a = 0.0
	add_child(l)
	return l


## The style a banner text suggests ("BOSS" -> boss, "CLEARED" -> cleared...).
static func style_for(text: String) -> StringName:
	var t := text.to_upper()
	if t.contains("BOSS"):
		return &"boss"
	if t.contains("FINAL"):
		return &"final"
	if t.contains("CLEARED") or t.contains("CLEAR!"):
		return &"cleared"
	if t.contains("PORTAL"):
		return &"portal"
	return &"wave"


## Splits a one-line banner text into [title, subtitle] at a line break, a
## dash between spaces or a double space ("PORTAL OPEN — FOLLOW THE LIGHTS").
static func split(text: String) -> PackedStringArray:
	for mark in ["\n", " — ", " – ", " - ", "  "]:
		var at := text.find(mark)
		if at > 0:
			return PackedStringArray([text.substr(0, at).strip_edges(), text.substr(at + mark.length()).strip_edges()])
	return PackedStringArray([text.strip_edges(), ""])


## Plays a banner. `intro` marks a round intro (see MERGE_WINDOW); `hold` is
## how long it stays once it has arrived.
func show_banner(title: String, sub := "", kicker := "", style: StringName = &"wave", hold := HOLD, intro := false) -> void:
	var now := Time.get_ticks_msec()
	if kicker == "" and _current_is_intro and now - _started_msec < int(MERGE_WINDOW * 1000.0) and not title.to_upper().contains("WAVE"):
		kicker = _current_kicker
	_started_msec = now
	_current_is_intro = intro
	_current_kicker = kicker if kicker != "" else title
	var colors: Array = STYLES.get(style, STYLES[&"wave"])
	var accent: Color = colors[1]
	_title.text = title.to_upper()
	_title.add_theme_color_override("font_color", colors[0])
	_title.add_theme_font_size_override("font_size", _fit(_title.text))
	_kicker.text = kicker.to_upper()
	_kicker.add_theme_color_override("font_color", accent)
	_sub.text = sub.to_upper()
	for line in _lines:
		line.self_modulate = accent
	_play(hold, style == &"boss" or style == &"final")
	Sfx.play(&"ui_whoosh", -11.0, 0.8)


## Removes the banner at once (the HUD is being hidden).
func clear() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	for c in get_children():
		(c as Control).modulate.a = 0.0
	_current_is_intro = false


## Largest title size at which `text` fits the band.
func _fit(text: String) -> int:
	var room := maxf(400.0, size.x - 520.0)
	var width := UiKit.display_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
	if width <= room:
		return TITLE_SIZE
	return maxi(TITLE_MIN_SIZE, int(TITLE_SIZE * room / width))


func _play(hold: float, alarm: bool) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	for blink in _blinks:
		blink.kill()
	_blinks.clear()
	var centre := Vector2(size.x * 0.5, 0.0)
	_band.pivot_offset = Vector2(_band.size.x * 0.5, BAND_HEIGHT * 0.5)
	_band.scale = Vector2(0.0, 1.0)
	_band.modulate.a = 0.0
	_title.pivot_offset = centre + Vector2(0.0, BAND_HEIGHT * 0.5)
	_title.scale = Vector2(1.55, 1.55)
	_title.modulate.a = 0.0
	_kicker.modulate.a = 0.0
	_kicker.position.y = -18.0
	_sub.modulate.a = 0.0
	_sub.position.y = SUB_TOP + 18.0
	for i in 2:
		_lines[i].modulate.a = 0.0
		_lines[i].pivot_offset = Vector2(_lines[i].size.x * (0.0 if i == 0 else 1.0), 2.5)
		_lines[i].scale = Vector2(0.0, 1.0)
	var tw := create_tween().set_parallel(true)
	_tween = tw
	tw.tween_property(_band, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_band, "modulate:a", 0.62, 0.12)
	for line in _lines:
		tw.tween_property(line, "scale:x", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(line, "modulate:a", 1.0, 0.1)
	tw.tween_property(_title, "scale", Vector2.ONE, 0.26).set_delay(0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_title, "modulate:a", 1.0, 0.1).set_delay(0.05)
	tw.tween_property(_kicker, "position:y", 0.0, 0.2).set_delay(0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_kicker, "modulate:a", 1.0, 0.14).set_delay(0.14)
	tw.tween_property(_sub, "position:y", SUB_TOP, 0.2).set_delay(0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sub, "modulate:a", 1.0, 0.14).set_delay(0.22)
	if alarm:
		# Boss and final-wave banners blink their lines twice.
		for line in _lines:
			var blink := line.create_tween().set_loops(2)
			blink.tween_property(line, "self_modulate:a", 0.25, 0.14).set_delay(0.3)
			blink.tween_property(line, "self_modulate:a", 1.0, 0.14)
			_blinks.append(blink)
	tw.chain().tween_interval(hold)
	tw.chain().tween_property(_title, "modulate:a", 0.0, 0.28)
	tw.tween_property(_title, "scale", Vector2(1.06, 1.06), 0.28)
	tw.tween_property(_kicker, "modulate:a", 0.0, 0.2)
	tw.tween_property(_sub, "modulate:a", 0.0, 0.2)
	tw.tween_property(_band, "modulate:a", 0.0, 0.28)
	for line in _lines:
		tw.tween_property(line, "modulate:a", 0.0, 0.28)
	tw.chain().tween_callback(func(): _current_is_intro = false)
