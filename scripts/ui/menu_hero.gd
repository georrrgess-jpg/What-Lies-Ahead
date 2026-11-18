class_name MenuHero
extends KitPanel
## The home screen's hero: the world PLAY opens, large. A window of the
## world's key art (slowly panning, leaning a little with the mouse) on a
## neon plate in the world's accent, with CONTINUE / START HERE, the level's
## name, the world, stars and progress over the shaded foot of the art, and a
## pager (◀ WORLD 2 / 15 ▶) to step through the open worlds. Locked worlds
## are skipped; the arrow past the last open world names what opens the next.

## The browsed world changed (by the pager or a refresh): its index and first level.
signal world_changed(index: int, level: LevelData)

## The art window inside the plate.
const WINDOW := Vector2(836, 300)
## The art is drawn this much larger than the window so it can pan.
const OVERSCAN := 1.14
## Seconds for one slow pan across the art and back.
const PAN_PERIOD := 26.0
## Most the art leans towards the mouse, canvas pixels.
const LEAN := 14.0

var world_index := -1
var _window: Control
var _art: TextureRect
var _art_material: ShaderMaterial
var _caption: KitChip
var _counter: Label
var _prev: SignButton
var _next: SignButton
var _name: Label
var _world: Label
var _stars: HBoxContainer
var _note: Label
## Open world indices, in order.
var _open: Array[int] = []
var _time := 0.0
var _lean := Vector2.ZERO
var _swap: Tween


static func create() -> MenuHero:
	var h := MenuHero.new()
	h.kind = Kind.NEON
	h._padding = 10.0
	h._style()
	return h


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window = Control.new()
	_window.custom_minimum_size = WINDOW
	_window.clip_contents = true
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_window)
	_build_art()
	_build_head()
	_build_foot()
	_window.resized.connect(_fit_art)
	set_process(DisplayServer.get_name() != "headless")


## The art fills the window with room to pan; the card shader rounds it,
## shades the text corner and masks it to the window.
func _build_art() -> void:
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_material = ShaderMaterial.new()
	_art_material.shader = load(KeyArt.CARD_SHADER)
	_art_material.set_shader_parameter("radius", 12.0)
	_art_material.set_shader_parameter("shade", Color(UiKit.INK, 1.0))
	_art_material.set_shader_parameter("shade_amount", 0.62)
	_art.material = _art_material
	_window.add_child(_art)


## CONTINUE and the pager across the top of the art.
func _build_head() -> void:
	var head := HBoxContainer.new()
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	head.offset_left = UiKit.GAP_L
	head.offset_right = -UiKit.GAP_M
	head.offset_top = UiKit.GAP_M
	head.add_theme_constant_override("separation", UiKit.GAP_S)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(head)
	_caption = UiKit.chip("CONTINUE", UiKit.PINK, 24)
	head.add_child(_caption)
	head.add_child(UiKit.filler())
	var pager := HBoxContainer.new()
	pager.add_theme_constant_override("separation", UiKit.GAP_S)
	pager.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(pager)
	_prev = UiKit.icon_button(&"icon_arrow_left", "Previous world")
	_prev.name = "PrevWorld"
	_prev.pressed.connect(step.bind(-1))
	pager.add_child(_prev)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.72), Color.TRANSPARENT, 24, 0, 6))
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pager.add_child(plate)
	_counter = UiKit.label("", UiKit.SIZE_SMALL, UiKit.CREAM, true)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.custom_minimum_size.x = 150
	plate.add_child(_counter)
	_next = UiKit.icon_button(&"icon_arrow_right", "Next world")
	_next.name = "NextWorld"
	_next.pressed.connect(step.bind(1))
	pager.add_child(_next)


## The level's name, the world and the progress over the foot of the art.
func _build_foot() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	col.offset_left = UiKit.GAP_L
	col.offset_right = -UiKit.GAP_L
	col.offset_bottom = -UiKit.GAP_M
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(col)
	_world = UiKit.label("", UiKit.SIZE_LABEL, UiKit.CREAM, true)
	_world.add_theme_color_override("font_outline_color", Color(UiKit.INK, 0.9))
	_world.add_theme_constant_override("outline_size", 8)
	col.add_child(_world)
	_name = UiKit.arcade_label("", 72)
	_name.clip_text = true
	col.add_child(_name)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", UiKit.GAP_S)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(foot)
	_stars = WorldCard.star_row(0, 30.0)
	foot.add_child(_stars)
	_note = UiKit.label("", UiKit.SIZE_BODY, UiKit.CREAM)
	_note.add_theme_color_override("font_outline_color", Color(UiKit.INK, 0.9))
	_note.add_theme_constant_override("outline_size", 8)
	_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_note)


## Re-reads the worlds: shows the player's next goal unless they browsed to
## another open world since the page was built.
func refresh() -> void:
	var worlds := GameData.worlds()
	_open.clear()
	for i in worlds.size():
		if GameData.is_world_unlocked(worlds[i]):
			_open.append(i)
	if _open.is_empty():
		return
	var goal := _goal_index()
	_show_world(world_index if world_index in _open else goal, false)


## Steps `by` open worlds along (the pager, or the shoulder of a pad).
func step(by: int) -> void:
	var at := _open.find(world_index)
	var to := clampi(at + by, 0, _open.size() - 1)
	if to == at:
		UiFx.deny(_next if by > 0 else _prev)
		return
	UiSound.select()
	_show_world(_open[to], true)


## The first open world not cleared yet; when all are, the one played last.
func _goal_index() -> int:
	var worlds := GameData.worlds()
	for i in _open:
		if not _is_cleared(worlds[i]):
			return i
	var last := int(Profile.section("menu").get("world", 0))
	return last if last in _open else _open[_open.size() - 1]


static func _is_cleared(world: WorldData) -> bool:
	for l in world.levels:
		if not Profile.is_level_completed(l.id):
			return false
	return true


func _show_world(index: int, animate: bool) -> void:
	var changed := index != world_index
	world_index = index
	var worlds := GameData.worlds()
	var world := worlds[index]
	var level: LevelData = world.levels[0] if not world.levels.is_empty() else null
	_caption.set_text(_caption_for(index))
	_caption.set_color(world.accent_color)
	accent = world.accent_color
	_counter.text = "WORLD %d / %d" % [index + 1, worlds.size()]
	_world.text = "WORLD %d  ·  %s" % [index + 1, world.display_name.to_upper()]
	_name.text = (level.display_name if level else world.display_name).to_upper()
	var count := WorldCard.world_stars(world)
	for i in _stars.get_child_count():
		(_stars.get_child(i) as TextureRect).texture = KitTex.tex(&"icon_star" if i < count else &"icon_star_empty")
	# No stars yet: the progress line says so on its own.
	_stars.visible = count > 0
	_note.text = MenuHome.goal_progress(level)
	_fit_pager()
	if animate and changed:
		_swap_art(level)
	else:
		KeyArt.request(level, _set_art)
	if changed:
		world_changed.emit(index, level)


## CONTINUE on the goal, START HERE before anything is cleared, PLAY AGAIN
## on a cleared world, else the world's place in the story.
func _caption_for(index: int) -> String:
	var worlds := GameData.worlds()
	if _is_cleared(worlds[index]):
		return "PLAY AGAIN"
	for i in _open:
		if _is_cleared(worlds[i]):
			return "CONTINUE"
	return "START HERE"


## The arrows grey out at the ends; past the last open world the tooltip
## says what opens the next one.
func _fit_pager() -> void:
	var at := _open.find(world_index)
	_prev.disabled = at <= 0
	_next.disabled = at >= _open.size() - 1
	# An arrow that greys out under the keyboard hands focus to the other one.
	if _prev.disabled and _prev.has_focus() and not _next.disabled:
		_next.grab_focus()
	elif _next.disabled and _next.has_focus() and not _prev.disabled:
		_prev.grab_focus()
	var worlds := GameData.worlds()
	var after := world_index + 1
	if _next.disabled and after < worlds.size() and worlds[after].requirement:
		_next.tooltip_text = "World %d: %s" % [after + 1, worlds[after].requirement.describe()]
	else:
		_next.tooltip_text = "Next world"
	_prev.visible = _open.size() > 1
	_next.visible = _open.size() > 1 or after < worlds.size()


## The old art fades, the new one slides in from the side it came from.
func _swap_art(level: LevelData) -> void:
	if _swap and _swap.is_valid():
		_swap.kill()
	_swap = create_tween()
	_swap.tween_property(_art, "modulate:a", 0.0, 0.1)
	_swap.tween_callback(func(): KeyArt.request(level, _set_art))
	_swap.tween_property(_art, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
	UiFx.pulse(_name, 1.05)


func _set_art(art: Texture2D) -> void:
	_art.texture = art


func _fit_art() -> void:
	_art.size = _window.size * OVERSCAN
	_art_material.set_shader_parameter("rect_size", _window.size)
	_place_art()


## Slow pan along a figure of eight plus the lean towards the mouse.
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	var view := get_viewport_rect().size
	var mouse := (get_viewport().get_mouse_position() / view - Vector2(0.5, 0.5)) * 2.0
	_lean = _lean.lerp(mouse.clampf(-1.0, 1.0) * LEAN, 1.0 - exp(-delta * 3.0))
	_place_art()


func _place_art() -> void:
	var room := _art.size - _window.size
	var t := _time / PAN_PERIOD * TAU
	var pan := Vector2(0.5 - 0.5 * cos(t), 0.5 + 0.35 * sin(t * 2.0)) * room
	_art.position = -(pan - _lean).clamp(Vector2.ZERO, room)
	_art_material.set_shader_parameter("inset", -_art.position)


## The arrows of the pager (for focus wiring).
func pager_buttons() -> Array[Control]:
	return [_prev, _next]
