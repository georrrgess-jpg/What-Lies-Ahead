class_name LockerCard
extends Button
## One item tile in the Locker grid: thumbnail or icon, name, rarity frame,
## lock state with its requirement, an EQUIPPED check and a NEW badge.

const CARD_SIZE := Vector2(206, 236)
const THUMB_HEIGHT := 150.0

var item: CosmeticItem
var owned := false
var _equipped_badge: Control
var _new_badge: Control
var _selected := false


func _init(it: CosmeticItem, is_owned: bool) -> void:
	item = it
	owned = is_owned
	custom_minimum_size = CARD_SIZE
	focus_mode = Control.FOCUS_ALL
	toggle_mode = false
	clip_contents = true
	_restyle()


func _ready() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 6
	col.offset_right = -6
	col.offset_top = 6
	col.offset_bottom = -6
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var thumb := _thumbnail()
	thumb.custom_minimum_size = Vector2(0, THUMB_HEIGHT)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(thumb)
	if not owned:
		thumb.add_child(_lock_overlay())
	var name_label := UiKit.label(item.display_name, 21, Color.WHITE if owned else Color(1, 1, 1, 0.6), true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 2
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_constant_override("line_spacing", -6)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)
	var strip := ColorRect.new()
	strip.color = CosmeticItem.rarity_color(item.rarity)
	strip.custom_minimum_size = Vector2(0, 5)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(strip)
	_equipped_badge = _badge_equipped()
	add_child(_equipped_badge)
	_new_badge = _badge_new()
	add_child(_new_badge)
	_new_badge.visible = Cosmetics.is_new(item)
	_equipped_badge.visible = false


## Equipped and selected states drive the frame and badges.
func set_state(is_equipped: bool, is_selected: bool) -> void:
	_selected = is_selected
	if _equipped_badge:
		_equipped_badge.visible = is_equipped
	if _new_badge:
		_new_badge.visible = Cosmetics.is_new(item)
	_restyle()


func _restyle() -> void:
	var rc := CosmeticItem.rarity_color(item.rarity)
	var bg := Color(UiKit.INK, 0.82).lerp(rc, 0.12 if owned else 0.04)
	var normal := UiKit.box(bg, Color(rc, 0.9 if owned else 0.45), 16, 5 if _selected else 3, 0)
	if _selected:
		normal.bg_color = bg.lerp(rc, 0.18)
		normal.shadow_color = Color(rc, 0.45)
		normal.shadow_size = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lerp(rc, 0.24)
	hover.border_color = rc.lerp(Color.WHITE, 0.3)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	add_theme_stylebox_override("hover_pressed", hover)
	add_theme_stylebox_override("focus", UiKit.box(Color.TRANSPARENT, UiKit.CYAN, 18, 3, 0))


func _thumbnail() -> Control:
	match item.slot:
		&"banner":
			var holder := MarginContainer.new()
			for side in ["left", "right", "top", "bottom"]:
				holder.add_theme_constant_override("margin_" + side, 10 if side != "top" else 18)
			holder.add_child(BannerView.new(item, 12.0))
			return holder
		&"title":
			var plate := CenterContainer.new()
			var l := UiKit.arcade_label(item.display_name.to_upper(), 26, CosmeticItem.rarity_color(item.rarity).lerp(Color.WHITE, 0.35))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(CARD_SIZE.x - 24, 0)
			plate.add_child(l)
			return plate
		&"weapon_cell", &"kill_effect", &"tracer":
			return CosmeticIcon.new(item)
	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex := CosmeticThumbs.cached(item)
	if tex:
		rect.texture = tex
	else:
		rect.set_meta("wants_thumb", true)
	return rect


## The Locker hands the card's TextureRect a baked thumbnail when ready.
func thumbnail_rect() -> TextureRect:
	for c in find_children("*", "TextureRect", true, false):
		if c.has_meta("wants_thumb"):
			return c
	return null


func _lock_overlay() -> Control:
	var shade := ColorRect.new()
	shade.color = Color(UiKit.INK, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(col)
	var lock := LockGlyph.new()
	lock.custom_minimum_size = Vector2(34, 40)
	lock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(lock)
	var req := UiKit.label(LockerCatalog.unlock_text(item), 17, UiKit.CREAM)
	req.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	req.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	req.max_lines_visible = 3
	req.custom_minimum_size = Vector2(CARD_SIZE.x - 28, 0)
	req.add_theme_constant_override("line_spacing", -5)
	req.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(req)
	return shade


func _badge_equipped() -> Control:
	var badge := CheckGlyph.new()
	badge.custom_minimum_size = Vector2(36, 36)
	badge.size = Vector2(36, 36)
	badge.position = Vector2(CARD_SIZE.x - 44, 8)
	return badge


func _badge_new() -> Control:
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UiKit.box(UiKit.AMBER, Color("b8711c"), 10, 0, 4))
	var l := UiKit.label("NEW", 17, UiKit.INK, true)
	l.add_theme_constant_override("shadow_offset_y", 0)
	pill.add_child(l)
	pill.position = Vector2(8, 8)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pill


## A small padlock drawn in code.
class LockGlyph extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_arc(Vector2(w * 0.5, h * 0.42), w * 0.28, PI, TAU, 16, UiKit.CREAM, 5.0, true)
		var body := StyleBoxFlat.new()
		body.bg_color = UiKit.CREAM
		body.set_corner_radius_all(6)
		draw_style_box(body, Rect2(0, h * 0.42, w, h * 0.58))
		draw_circle(Vector2(w * 0.5, h * 0.66), w * 0.1, UiKit.INK)


## A round cyan check mark.
class CheckGlyph extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, size.x * 0.5, UiKit.CYAN)
		draw_circle(c, size.x * 0.5 - 3, Color("0d8f9a"))
		draw_polyline(PackedVector2Array([c + Vector2(-8, 0), c + Vector2(-2, 7), c + Vector2(9, -7)]), Color.WHITE, 4.5, true)
