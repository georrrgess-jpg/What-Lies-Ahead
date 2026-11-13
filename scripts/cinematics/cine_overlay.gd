class_name CineOverlay
extends CanvasLayer
## The 2D layer of a cinematic: the lens and colour grade (cine_grade.gdshader:
## a look per act, fake depth of field, whip-pan smear, anamorphic flares),
## letterbox bars, flashes, fades, wipes and the type (the UI kit's display
## font, docs/UI_STYLE.md). Every motion runs on unscaled time so slow motion
## never slows the titles.
##
## Coordinates are the 1920x1080 canvas; `at` positions are fractions of it.

const WIPE_SHADER := "res://art/shaders/cine_wipe.gdshader"
const GRADE_SHADER := "res://art/shaders/cine_grade.gdshader"
const BAR_HEIGHT := 96.0
## The picture between the bars (1920 x 888 on the 16:9 canvas): on any
## screen shape the bars leave this aspect, matching the 16:9 framing the
## camera keeps (CineStage.FRAME_ASPECT), so nothing is cropped differently.
const PICTURE_ASPECT := 1920.0 / (1080.0 - 2.0 * BAR_HEIGHT)
## Looks per act: [lift (shadows), gain (highlights), contrast, saturation, vignette].
const GRADES := {
	&"neutral": [Vector3.ZERO, Vector3.ONE, 1.0, 1.0, 0.0],
	&"dusk": [Vector3(0.05, 0.015, 0.08), Vector3(1.1, 0.94, 0.84), 1.16, 0.95, 0.6],
	&"day": [Vector3(0.015, 0.0, 0.035), Vector3(1.04, 1.0, 0.96), 1.07, 1.08, 0.32],
	&"night": [Vector3(0.03, 0.0, 0.06), Vector3(1.0, 0.96, 1.08), 1.1, 1.14, 0.42],
	&"studio": [Vector3(0.02, 0.0, 0.045), Vector3(1.04, 1.0, 1.05), 1.08, 1.1, 0.48],
	&"golden": [Vector3(0.05, 0.02, 0.06), Vector3(1.12, 0.98, 0.86), 1.1, 1.04, 0.5],
}

var root: Control
var _bars: Array[ColorRect] = []
var _flash: ColorRect
var _fade: ColorRect
var _wipe: ColorRect
var _wipe_mat: ShaderMaterial
var _text_layer: Control
var _grade: ColorRect
var _grade_mat: ShaderMaterial
var _grade_tween: Tween
var _lens_tween: Tween
var _bar_amount := 1.0


func _init() -> void:
	layer = 60


func _ready() -> void:
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	UiKit.apply(root)
	_grade = _full(ColorRect.new())
	_grade_mat = ShaderMaterial.new()
	_grade_mat.shader = load(GRADE_SHADER)
	_grade.material = _grade_mat
	_text_layer = _full(Control.new())
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0.0, 0.0, 0.0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		if top:
			bar.anchor_bottom = 0.0
		else:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
		root.add_child(bar)
		_bars.append(bar)
	_fade = _full(ColorRect.new())
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_flash = _full(ColorRect.new())
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_wipe = _full(ColorRect.new())
	_wipe_mat = ShaderMaterial.new()
	_wipe_mat.shader = load(WIPE_SHADER)
	_wipe.material = _wipe_mat
	_wipe.visible = false
	root.resized.connect(_on_resized)
	_on_resized()
	grade(&"neutral")
	focus(Vector2(0.5, 0.5), 0.3, 0.0)
	reset_lens()
	bars(1.0, 0.0)


func _full(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)
	return c


func _on_resized() -> void:
	var aspect := Vector2(root.size.x / maxf(1.0, root.size.y), 1.0)
	_wipe_mat.set_shader_parameter("aspect", aspect)
	_grade_mat.set_shader_parameter("aspect", aspect)
	bars(_bar_amount, 0.0)


## Height of one letterbox bar on this screen (canvas pixels).
func bar_height() -> float:
	return maxf(0.0, (root.size.y - root.size.x / PICTURE_ASPECT) * 0.5)


func _tween() -> Tween:
	return create_tween().set_ignore_time_scale(true)


# --- lens and grade -------------------------------------------------------------

## Blends to the look `look_name` (GRADES) over `seconds` (0 = at once, on a cut).
func grade(look_name: StringName, seconds := 0.0) -> void:
	var g: Array = GRADES.get(look_name, GRADES[&"neutral"])
	if _grade_tween and _grade_tween.is_valid():
		_grade_tween.kill()
	var params := {"lift": g[0], "gain": g[1], "contrast": g[2], "saturation": g[3], "vignette": g[4]}
	if seconds <= 0.0:
		for key in params:
			_grade_mat.set_shader_parameter(key, params[key])
		return
	_grade_tween = _tween().set_parallel(true)
	for key in params:
		_grade_tween.tween_method(func(v): _grade_mat.set_shader_parameter(key, v), _grade_mat.get_shader_parameter(key), params[key], seconds)


## Fake shallow focus: sharp within `radius` (screen heights) of `point`
## (fractions of the screen), blurring by up to `amount` beyond; a rack focus
## is a second call with another point and `seconds` > 0. amount 0 = all sharp.
func focus(point: Vector2, radius := 0.25, amount := 0.012, seconds := 0.0) -> void:
	if _lens_tween and _lens_tween.is_valid():
		_lens_tween.kill()
	if seconds <= 0.0:
		_grade_mat.set_shader_parameter("focus", point)
		_grade_mat.set_shader_parameter("focus_radius", radius)
		_grade_mat.set_shader_parameter("defocus", amount)
		return
	_lens_tween = _tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for pair in [["focus", point], ["focus_radius", radius], ["defocus", amount]]:
		_lens_tween.tween_method(func(v): _grade_mat.set_shader_parameter(pair[0], v), _grade_mat.get_shader_parameter(pair[0]), pair[1], seconds)


## Directional motion blur (a whip pan): `span` in screen fractions (0 = off).
func smear(span: Vector2) -> void:
	_grade_mat.set_shader_parameter("smear", span)


## An anamorphic flare at `at` (fractions of the screen); strength 0 = off.
func flare(at: Vector2, color: Color, strength: float) -> void:
	_grade_mat.set_shader_parameter("flare_pos", at)
	_grade_mat.set_shader_parameter("flare_color", Vector4(color.r, color.g, color.b, strength))


## Every lens effect off (each shot starts clean).
func reset_lens() -> void:
	if _lens_tween and _lens_tween.is_valid():
		_lens_tween.kill()
	_grade_mat.set_shader_parameter("defocus", 0.0)
	smear(Vector2.ZERO)
	flare(Vector2.ZERO, Color.BLACK, 0.0)


# --- frame --------------------------------------------------------------------

## Letterbox bars: 1 = cinematic, 0 = gone, over `seconds`.
func bars(amount: float, seconds := 0.4) -> void:
	_bar_amount = amount
	var h := bar_height() * amount
	for i in _bars.size():
		var bar := _bars[i]
		var top := i == 0
		if seconds <= 0.0:
			bar.offset_bottom = h if top else 0.0
			bar.offset_top = 0.0 if top else -h
			continue
		var tw := _tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(bar, "offset_bottom" if top else "offset_top", h if top else -h, seconds)


## A white (or `color`) flash that fades over `seconds`.
func flash(color := Color.WHITE, seconds := 0.35, strength := 0.9) -> void:
	_flash.color = Color(color, strength * Settings.flash_scale())
	_tween().tween_property(_flash, "color:a", 0.0, seconds).set_ease(Tween.EASE_OUT)


## Fades to (alpha 1) or from (alpha 0) black.
func fade(alpha: float, seconds: float, color := Color.BLACK) -> void:
	_fade.color = Color(color, _fade.color.a)
	if seconds <= 0.0:
		_fade.color.a = alpha
		return
	_tween().tween_property(_fade, "color:a", alpha, seconds)


## The striped neon wipe: covers the frame at the half-way point.
func wipe(seconds := 0.5) -> void:
	_wipe_mat.set_shader_parameter("mode", 0)
	_wipe.visible = true
	var tw := _tween()
	tw.tween_method(func(k: float): _wipe_mat.set_shader_parameter("progress", k), 0.0, 1.0, seconds)
	tw.tween_callback(func(): _wipe.visible = false)


## An iris closing (to 0) or opening (to 1.2) over `seconds`.
func iris(from: float, to: float, seconds: float) -> void:
	_wipe_mat.set_shader_parameter("mode", 1)
	_wipe.visible = true
	var tw := _tween()
	tw.tween_method(func(k: float): _wipe_mat.set_shader_parameter("progress", k), from, to, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if to > 1.0:
		tw.tween_callback(func(): _wipe.visible = false)


# --- type ---------------------------------------------------------------------

## Big display text that slams in (scale punch), holds for `hold` seconds and
## pops out. `at` is the centre as a fraction of the screen.
func slam(text: String, font_size := 120, color := Color.WHITE, at := Vector2(0.5, 0.5), hold := 1.0, tilt := -3.0) -> Label:
	var l := UiKit.arcade_label(text, font_size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(l, at)
	l.rotation_degrees = tilt
	l.scale = Vector2.ONE * 2.4
	l.modulate.a = 0.0
	var tw := _tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 1.0, 0.08)
	tw.chain().tween_interval(hold)
	_out(tw, l)
	return l


## Text that slides in from the left with a skew-like overshoot (a kicker).
func slide(text: String, font_size := 64, color := UiKit.CYAN, at := Vector2(0.5, 0.5), hold := 1.0, from_right := false) -> Label:
	var l := UiKit.arcade_label(text, font_size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(l, at)
	var home := l.position
	l.position.x += 900.0 if from_right else -900.0
	l.modulate.a = 0.0
	var tw := _tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:x", home.x, 0.22).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 1.0, 0.1)
	tw.chain().tween_interval(hold)
	_out(tw, l)
	return l


## A lower-third name card: a neon panel with a title and a note, sliding in
## at the bottom left (or right).
func name_card(title: String, note: String, accent := UiKit.PINK, hold := 1.3, right := false) -> Control:
	var panel := UiKit.neon_panel(accent)
	panel.set_padding(28, 12)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -6)
	panel.add_child(col)
	if note != "":
		col.add_child(UiKit.label(note.to_upper(), UiKit.SIZE_LABEL, accent, true))
	col.add_child(UiKit.sign_label(title.to_upper(), UiKit.SIZE_TITLE))
	_text_layer.add_child(panel)
	panel.reset_size()
	var y := root.size.y - bar_height() - panel.size.y - 34.0
	var x := root.size.x - panel.size.x - 72.0 if right else 72.0
	panel.position = Vector2(x + (500.0 if right else -500.0), y)
	panel.modulate.a = 0.0
	var tw := _tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "position:x", x, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.12)
	tw.chain().tween_interval(hold)
	tw.chain().tween_property(panel, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(panel.queue_free)
	return panel


## A clean title card: a small spaced kicker over a large title in the
## display face, fading and drifting in (no slam), holding `hold` seconds.
## `at` is the centre as a fraction of the screen.
func title_card(title: String, kicker := "", at := Vector2(0.5, 0.5), hold := 1.6, accent := UiKit.CYAN, title_size := 84) -> Control:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	if kicker != "":
		var k := UiKit.label(_spaced(kicker.to_upper()), UiKit.SIZE_LABEL, accent, true)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(k)
	var t := UiKit.sign_label(title.to_upper(), title_size)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	_text_layer.add_child(col)
	col.reset_size()
	var home := _inside(root.size * at - col.size * 0.5, col.size)
	col.position = home + Vector2(0, 18)
	col.modulate.a = 0.0
	var tw := _tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(col, "position:y", home.y, 0.6)
	tw.tween_property(col, "modulate:a", 1.0, 0.45)
	tw.chain().tween_interval(hold)
	tw.chain().tween_property(col, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(col.queue_free)
	return col


## A small spaced caption low in the frame (a place name), fading in and out.
func caption(text: String, hold := 1.2, color := UiKit.CREAM) -> Label:
	var l := UiKit.label(_spaced(text.to_upper()), UiKit.SIZE_LABEL, color, true)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(l, Vector2(0.5, 1.0 - (bar_height() + 46.0) / maxf(1.0, root.size.y)))
	l.modulate.a = 0.0
	var tw := _tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.35)
	tw.tween_interval(hold)
	tw.tween_property(l, "modulate:a", 0.0, 0.35)
	tw.tween_callback(l.queue_free)
	return l


## Letter-spaced capitals for small type ("N E O N").
func _spaced(text: String) -> String:
	return " ".join(text.split("")).replace("   ", "     ")


## A centred reward card (rank up, level up, unlock) that punches in.
func reward_card(title: String, note: String, accent: Color, hold := 0.8, at := Vector2(0.5, 0.5), icon: StringName = &"") -> Control:
	var panel := UiKit.neon_panel(accent)
	panel.set_padding(48, 22)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	panel.add_child(col)
	if icon != &"":
		var ic := UiKit.icon(icon, 84.0, accent)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(ic)
	var t := UiKit.arcade_label(title, 96, accent.lerp(Color.WHITE, 0.25))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var n := UiKit.label(note.to_upper(), UiKit.SIZE_HEADING, UiKit.CREAM, true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(n)
	_text_layer.add_child(panel)
	panel.reset_size()
	panel.pivot_offset = panel.size * 0.5
	panel.position = root.size * at - panel.size * 0.5
	panel.scale = Vector2.ONE * 0.3
	panel.rotation_degrees = randf_range(-4.0, 4.0)
	var tw := _tween()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(panel, "scale", Vector2.ONE * 1.25, 0.12)
	tw.parallel().tween_property(panel, "modulate:a", 0.0, 0.12)
	tw.tween_callback(panel.queue_free)
	return panel


## The game's logo at `at`; stays until clear(). With `reveal` > 0 it
## fades up and settles over that many seconds instead of slamming in.
func logo(at := Vector2(0.5, 0.36), size_px := 150, reveal := 0.0) -> NeonLogo:
	var l := NeonLogo.new()
	l.size_px = size_px
	_text_layer.add_child(l)
	l.show_now()
	l.reset_size()
	l.position = _inside(root.size * at - l.custom_minimum_size * 0.5, l.custom_minimum_size)
	l.pivot_offset = l.custom_minimum_size * 0.5
	l.modulate.a = 0.0
	var tw := _tween().set_parallel(true)
	if reveal > 0.0:
		l.scale = Vector2.ONE * 1.12
		tw.tween_property(l, "scale", Vector2.ONE, reveal * 2.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "modulate:a", 1.0, reveal).set_trans(Tween.TRANS_SINE)
		return l
	l.scale = Vector2.ONE * 2.0
	tw.tween_property(l, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 1.0, 0.1)
	return l


## A marquee sign (bulbs chasing) that drops in; stays until clear().
func marquee(text: String, font_size := 72, at := Vector2(0.5, 0.8)) -> MarqueeSign:
	var m := UiKit.marquee(text, font_size)
	_text_layer.add_child(m)
	m.reset_size()
	var home := _inside(root.size * at - m.size * 0.5, m.size)
	m.position = home - Vector2(0, 260)
	m.modulate.a = 0.0
	var tw := _tween().set_parallel(true)
	tw.tween_property(m, "position:y", home.y, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "modulate:a", 1.0, 0.1)
	tw.chain().tween_callback(m.flash)
	return m


## A row of chips (feature counts) popping in one after another.
func chips(texts: PackedStringArray, at := Vector2(0.5, 0.62), step := 0.12, colors: Array = []) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_M)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_text_layer.add_child(row)
	for i in texts.size():
		var c := UiKit.chip(texts[i], colors[i % colors.size()] if not colors.is_empty() else UiKit.CYAN, 30)
		c.modulate.a = 0.0
		row.add_child(c)
		var tw := _tween()
		tw.tween_interval(step * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.08)
	row.reset_size()
	row.position = _inside(root.size * at - row.size * 0.5, row.size)
	return row


## A Sparks counter (the kit's spark icon and gold digits) counting from
## `from` to `to` over `seconds`; stays until clear().
func spark_counter(from: int, to: int, seconds: float, at := Vector2(0.5, 0.2)) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_S)
	row.add_child(UiKit.spark_icon(96.0))
	var digits := UiKit.arcade_label(Wallet.format(from), 104, Wallet.COLOR)
	row.add_child(digits)
	_text_layer.add_child(row)
	row.reset_size()
	var place := func(): row.position = root.size * at - row.size * 0.5
	place.call()
	var tw := _tween()
	tw.tween_method(func(v: float):
		digits.text = Wallet.format(int(v))
		row.reset_size()
		place.call(), float(from), float(to), seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return row


func _place(l: Control, at: Vector2) -> void:
	_text_layer.add_child(l)
	l.reset_size()
	l.position = _inside(root.size * at - l.size * 0.5, l.size)
	l.pivot_offset = l.size * 0.5


## Keeps a piece of type of `size` at `pos` inside the picture between the
## bars, with a margin (title-safe on any screen shape).
func _inside(pos: Vector2, size: Vector2) -> Vector2:
	var margin := 28.0
	var top := bar_height() * _bar_amount + margin
	var bottom := root.size.y - bar_height() * _bar_amount - margin - size.y
	return Vector2(clampf(pos.x, margin, maxf(margin, root.size.x - margin - size.x)), clampf(pos.y, top, maxf(top, bottom)))


func _out(tw: Tween, c: Control) -> void:
	tw.chain().tween_property(c, "scale", Vector2.ONE * 1.12, 0.12)
	tw.parallel().tween_property(c, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(c.queue_free)


## Removes every piece of type (titles that stay until told otherwise).
func clear_text(seconds := 0.0) -> void:
	for c in _text_layer.get_children():
		if seconds <= 0.0:
			c.queue_free()
		else:
			var tw := _tween()
			tw.tween_property(c, "modulate:a", 0.0, seconds)
			tw.tween_callback(c.queue_free)
