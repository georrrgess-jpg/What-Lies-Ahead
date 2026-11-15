class_name WorldCard
extends Control
## One world in the Play page carousel: the world's key art cropped to the
## rounded card, with the world number and name, tagline, progress stars and
## best score over it. A locked world is greyed under hazard stripes, with a
## padlock and what opens it. The selected card wears a cream trim with a
## chase of marquee bulbs, glows in the world's accent, and a band of light
## sweeps across it when it is picked. The carousel feeds `set_depth()` so the
## art slides behind the frame (parallax). Without key art the card shows the
## world's colours. Mouse input is left to the carousel (click and drag).
## It only redraws when its state changes, and while selected at the bulbs'
## step rate.

const SIZE := Vector2(460, 248)
const RADIUS := 22
## How far the art reaches past each side of the card for the parallax slide.
const ART_PAD := 34.0
## Bulbs of the marquee chase around the selected card.
const BULB_SPACING := 30.0
const BULB_STEP := 0.14
const CHASE := 3

var world: WorldData
var index := 0
## The line over the name ("" = "WORLD n"; the Endless card says ENDLESS).
var caption := ""
var selected := false:
	set(v):
		if selected != v:
			selected = v
			_on_selected_changed()
var _hover := false
var _title: Label
var _art: TextureRect
var _art_mat: ShaderMaterial
## Drawn over the art: lock veil, accent bar, trim, bulbs and padlock.
var _frame: Control
var _status: Label
var _stars: HBoxContainer
var _bg := StyleBoxFlat.new()
var _bar := StyleBoxFlat.new()
var _border := StyleBoxFlat.new()
var _shade := StyleBoxFlat.new()
var _unlocked := true
var _bulbs := PackedVector2Array()
var _phase := 0
var _bulb_timer: Timer
var _sweep: Tween


## Progress stars of a level, 0-3: a third of the waves, two thirds, cleared.
static func stars(level: LevelData) -> int:
	if level == null:
		return 0
	if Profile.is_level_completed(level.id):
		return 3
	var waves := level.wave_set.waves.size() if level.wave_set else 0
	if waves <= 0:
		return 0
	return clampi(Profile.best_wave(level.id) * 3 / waves, 0, 2)


## Most stars over the levels of `w`.
static func world_stars(w: WorldData) -> int:
	var most := 0
	for l in w.levels:
		most = maxi(most, stars(l))
	return most


## A row of three star icons with `count` of them gold.
static func star_row(count: int, icon_size := 30.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		row.add_child(UiKit.icon(&"icon_star" if i < count else &"icon_star_empty", icon_size))
	return row


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE * 0.5
	# Hover is the card's; clicks and drags go on to the carousel.
	mouse_filter = Control.MOUSE_FILTER_PASS
	_unlocked = GameData.is_world_unlocked(world)
	_add_art()
	_frame = Control.new()
	_frame.size = SIZE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	add_child(_frame)
	var v := VBoxContainer.new()
	v.position = Vector2(26, 20)
	# A locked card keeps its title clear of the padlock in the corner.
	v.size = Vector2(SIZE.x - 52 - (64.0 if not _unlocked else 0.0), SIZE.y - 42)
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	v.add_child(UiKit.label(caption if caption != "" else "WORLD %d" % (index + 1), 22, world.secondary_color, true))
	_title = UiKit.arcade_label(world.display_name.to_upper(), 40, Color.WHITE)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_constant_override("line_spacing", -10)
	v.add_child(_title)
	var tag := UiKit.label(world.tagline, 20, UiKit.CREAM)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tag)
	v.add_child(UiKit.filler())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", UiKit.GAP_S)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(foot)
	_stars = star_row(0, 28.0)
	foot.add_child(_stars)
	_status = UiKit.label("", 20, Color.WHITE, true)
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_status)
	for l: Label in [tag, _status]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_color_override("font_outline_color", Color(UiKit.INK, 0.85))
		l.add_theme_constant_override("outline_size", 6)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	_bulb_timer = Timer.new()
	_bulb_timer.wait_time = BULB_STEP
	_bulb_timer.timeout.connect(_step_bulbs)
	add_child(_bulb_timer)
	refresh()


## The first level's key art, wider than the card (for the parallax slide),
## rounded and shaded so the text reads over it.
func _add_art() -> void:
	var texture := KeyArt.texture(world.levels[0]) if not world.levels.is_empty() else null
	if texture == null:
		return
	_art = TextureRect.new()
	_art.texture = texture
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_art.size = SIZE + Vector2(ART_PAD * 2.0, 0.0)
	_art.position.x = -ART_PAD
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Its shader draws only the card's shape: the slack rect is not on screen
	# (scripts/dev/ui_layout_probe.gd skips it).
	_art.set_meta(&"layout_overhang", true)
	_art_mat = ShaderMaterial.new()
	_art_mat.shader = load(KeyArt.CARD_SHADER)
	_art_mat.set_shader_parameter("rect_size", SIZE)
	_art_mat.set_shader_parameter("inset", Vector2(ART_PAD, 0.0))
	_art_mat.set_shader_parameter("radius", float(RADIUS))
	_art_mat.set_shader_parameter("shade", world.backdrop_color.darkened(0.35))
	_art.material = _art_mat
	add_child(_art)


## Where the card sits in the carousel (signed distance from the selected
## slot, in cards): the art slides against the motion for depth.
func set_depth(distance: float) -> void:
	if _art == null:
		return
	var shift := clampf(distance, -1.5, 1.5) / 1.5 * ART_PAD
	_art.position.x = -ART_PAD + shift
	_art_mat.set_shader_parameter("inset", Vector2(ART_PAD - shift, 0.0))


## Re-reads progress (stars, best score, lock state).
func refresh() -> void:
	_unlocked = GameData.is_world_unlocked(world)
	var best := 0
	for l in world.levels:
		best = maxi(best, Profile.best_score(l.id))
	var most := world_stars(world)
	_stars.visible = _unlocked
	for i in _stars.get_child_count():
		(_stars.get_child(i) as TextureRect).texture = KitTex.tex(&"icon_star" if i < most else &"icon_star_empty")
	if _unlocked:
		_status.text = "BEST %s" % ScorePanel._fmt(best) if best > 0 else ("CLEARED" if most >= 3 else "NOT PLAYED YET")
		_status.add_theme_color_override("font_color", Color.WHITE)
	else:
		_status.text = world.requirement.describe().to_upper()
		_status.add_theme_color_override("font_color", UiKit.AMBER)
	if _art:
		_art_mat.set_shader_parameter("saturation", 1.0 if _unlocked else 0.15)
		_art_mat.set_shader_parameter("stripes", 0.0 if _unlocked else 1.0)
	queue_redraw()
	_frame.queue_redraw()


func _set_hover(on: bool) -> void:
	_hover = on
	_frame.queue_redraw()
	if on and not selected:
		UiSound.hover()


## Picked: the bulbs start chasing and a band of light sweeps across the art.
func _on_selected_changed() -> void:
	queue_redraw()
	if _frame == null:
		return
	_frame.queue_redraw()
	if _sweep and _sweep.is_valid():
		_sweep.kill()
	if not selected:
		_bulb_timer.stop()
		if _art:
			_art_mat.set_shader_parameter("sweep", -1.0)
		return
	if _bulbs.is_empty():
		_bulbs = _bulb_points()
	_bulb_timer.start()
	if _art and is_visible_in_tree():
		_sweep = create_tween()
		_sweep.tween_method(func(t: float): _art_mat.set_shader_parameter("sweep", t), 0.0, 1.0, 0.7) \
				.set_delay(0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_sweep.tween_callback(func(): _art_mat.set_shader_parameter("sweep", -1.0))


func _step_bulbs() -> void:
	if not is_visible_in_tree():
		return
	_phase = (_phase + 1) % CHASE
	_frame.queue_redraw()


## Bulb centres, evenly spaced along the middle of the selected trim.
func _bulb_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	var box := SIZE - Vector2(6, 6)
	var r := float(RADIUS) - 3.0
	var arc := PI * 0.5 * r
	var lengths: Array[float] = [box.x - r * 2.0, box.y - r * 2.0]
	var length: float = (lengths[0] + lengths[1]) * 2.0 + arc * 4.0
	var count := int(length / BULB_SPACING)
	for i in count:
		points.append(Vector2(3, 3) + _outline_point(length * i / count, box, r, lengths, arc))
	return points


## The point `t` pixels along a rounded `box` outline, clockwise from the end
## of its top-left corner.
static func _outline_point(t: float, box: Vector2, r: float, lengths: Array[float], arc: float) -> Vector2:
	var corners := [Vector2(box.x - r, r), Vector2(box.x - r, box.y - r), Vector2(r, box.y - r), Vector2(r, r)]
	var starts := [Vector2(r, 0), Vector2(box.x, r), Vector2(box.x - r, box.y), Vector2(0, box.y - r)]
	var dirs := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	for side in 4:
		var straight: float = lengths[side % 2]
		if t <= straight:
			return starts[side] + dirs[side] * t
		t -= straight
		if t <= arc:
			var a: float = -PI * 0.5 + side * PI * 0.5 + t / r
			return corners[side] + Vector2(cos(a), sin(a)) * r
		t -= arc
	return starts[0]


## Backing fill and the selection glow (under the art).
func _draw() -> void:
	_bg.bg_color = world.backdrop_color.darkened(0.2)
	_bg.set_corner_radius_all(RADIUS)
	_bg.shadow_color = Color(world.accent_color, 0.55 if selected else 0.0)
	_bg.shadow_size = 26 if selected else 0
	draw_style_box(_bg, Rect2(Vector2.ZERO, size))


## Everything over the art: the lock veil, the accent bar, the trim, the bulbs and the padlock.
func _draw_frame() -> void:
	var accent := world.accent_color
	var r := Rect2(Vector2.ZERO, size)
	if not _unlocked:
		_shade.bg_color = Color(0.02, 0.0, 0.06, 0.4)
		_shade.set_corner_radius_all(RADIUS)
		_frame.draw_style_box(_shade, r)
	_bar.bg_color = accent if _unlocked else UiKit.AMBER.darkened(0.25)
	_bar.corner_radius_bottom_left = RADIUS
	_bar.corner_radius_bottom_right = RADIUS
	_frame.draw_style_box(_bar, Rect2(0, size.y - 10, size.x, 10))
	_border.draw_center = false
	_border.set_corner_radius_all(RADIUS)
	_border.border_color = UiKit.CREAM if selected else Color(accent, 0.9 if _hover else 0.5)
	_border.set_border_width_all(6 if selected else 3)
	_border.anti_aliasing = true
	_frame.draw_style_box(_border, r)
	if selected and not _bulbs.is_empty():
		_draw_bulbs()
	if not _unlocked:
		var at := Vector2(size.x - 50, 48)
		_frame.draw_circle(at, 34.0, Color(UiKit.INK, 0.85))
		_frame.draw_circle(at, 34.0, UiKit.AMBER, false, 3.0, true)
		_frame.draw_texture_rect(KitTex.tex(&"icon_lock"), Rect2(at - Vector2(24, 24), Vector2(48, 48)), false)


func _draw_bulbs() -> void:
	var warm := Color(1.0, 0.86, 0.55)
	for i in _bulbs.size():
		var lit := i % CHASE == _phase
		if lit:
			_frame.draw_circle(_bulbs[i], 8.0, Color(warm, 0.28))
			_frame.draw_circle(_bulbs[i], 4.0, Color(1.0, 0.97, 0.86))
		else:
			_frame.draw_circle(_bulbs[i], 3.2, Color(0.72, 0.5, 0.3, 0.9))
