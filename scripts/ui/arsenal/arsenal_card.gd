class_name ArsenalCard
extends Button
## A wide weapon card of the Arsenal's dock: a reserved tag row (EQUIPPED on
## the left, a padlock and what unlocks the weapon on the right), the weapon's
## picture and its name. The previewed card wears the cyan outline; the
## loadout's weapon wears the EQUIPPED tag; locked cards are dimmed.
##
## Hover, focus and selection animate the picture inside the card (clipped
## to its box), never the card itself, so nothing grows over its neighbours.

## Font size of the name, and the smallest it shrinks to before it is cut
## with an ellipsis (the tooltip has the full name).
const NAME_SIZE := 24
const NAME_MIN_SIZE := 18
## Height of the tag row; the tags live in it, so they never cover the name.
const TAG_ROW := 26.0
const INSET := 10.0
const LOCKED_TINT := Color(0.42, 0.38, 0.55)
## How much the picture grows on hover / focus.
const LIFT := 1.07

var weapon: WeaponData
## The card being previewed: cyan outline.
var selected := false:
	set(v):
		if selected == v:
			return
		selected = v
		_restyle()
		if v:
			_animate_picture(0.92, 0.2)
var _picture: TextureRect
var _name: Label
var _tag: KitChip
var _lock: HBoxContainer
var _lock_text: Label
var _tween: Tween
var _lifted := false


static func make(w: WeaponData) -> ArsenalCard:
	var c := ArsenalCard.new()
	c.weapon = w
	c._build()
	return c


func _build() -> void:
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	add_theme_stylebox_override("focus", KitTex.box(&"focus_ring"))
	add_theme_stylebox_override("pressed", KitTex.box(&"card_selected"))
	add_theme_stylebox_override("disabled", KitTex.box(&"card"))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(INSET))
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	col.add_child(_tag_row())
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(holder)
	_picture = TextureRect.new()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.resized.connect(func(): _picture.pivot_offset = _picture.size * 0.5)
	holder.add_child(_picture)
	_name = UiKit.sign_label(weapon.display_name.to_upper(), NAME_SIZE)
	_name.name = "CardName"
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.resized.connect(_fit_name)
	col.add_child(_name)
	_restyle()
	mouse_entered.connect(_update_lift)
	mouse_exited.connect(_update_lift)
	focus_entered.connect(_update_lift)
	focus_exited.connect(_update_lift)
	pressed.connect(UiSound.select)


## The row above the picture: EQUIPPED tag (left), padlock + unlock (right).
func _tag_row() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = TAG_ROW
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag = UiKit.chip("EQUIPPED", UiKit.CYAN, 16, false)
	_tag.name = "EquippedTag"
	_tag.visible = false
	row.add_child(_tag)
	row.add_child(UiKit.filler())
	_lock = HBoxContainer.new()
	_lock.add_theme_constant_override("separation", 4)
	_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock.visible = false
	row.add_child(_lock)
	_lock.add_child(UiKit.icon(&"icon_lock", 22.0, UiKit.AMBER))
	_lock_text = UiKit.label("", 18, UiKit.AMBER, true)
	_lock_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock.add_child(_lock_text)
	return row


## Shows the weapon's state: equipped, locked, its picture.
func refresh(picture: Texture2D) -> void:
	_picture.texture = picture
	var unlocked := GameData.is_weapon_unlocked(weapon)
	_tag.visible = Loadout.slot_of(weapon.id) >= 0
	_lock.visible = not unlocked
	_lock_text.text = ArsenalStats.short_unlock(weapon) if not unlocked else ""
	# A long unlock line gives way to the padlock alone (the tooltip has it).
	_lock_text.visible = _lock_text.text.length() <= 9
	_picture.modulate = Color.WHITE if unlocked else LOCKED_TINT
	_name.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.75)
	var tip := weapon.display_name
	if not unlocked:
		tip += "\nLocked: %s" % ArsenalStats.unlock_text(weapon)
	tooltip_text = tip


func _restyle() -> void:
	var face := &"card_selected" if selected else &"card"
	add_theme_stylebox_override("normal", KitTex.box(face))
	add_theme_stylebox_override("hover", KitTex.box(&"card_selected" if selected else &"card_hover"))


## The name in the largest size from NAME_SIZE down to NAME_MIN_SIZE that
## fits on one line; past that it keeps NAME_MIN_SIZE and ends in "…".
func _fit_name() -> void:
	var room := _name.size.x - 6.0
	if room <= 0.0:
		return
	var font := UiKit.display_font()
	var font_size := NAME_SIZE
	while font_size > NAME_MIN_SIZE and font.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
		font_size -= 1
	if _name.get_theme_font_size(&"font_size") != font_size:
		_name.add_theme_font_size_override(&"font_size", font_size)
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.clip_text = true


## True when the whole name shows (no ellipsis).
func name_fits() -> bool:
	var font_size := _name.get_theme_font_size(&"font_size")
	return UiKit.display_font().get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= _name.size.x


func _update_lift() -> void:
	var want := (is_hovered() or has_focus()) and not disabled
	if want == _lifted:
		return
	_lifted = want
	_animate_picture(-1.0, UiFx.FAST)
	if want and is_hovered():
		UiSound.hover()


## Moves the picture to its resting scale (lifted or not), from `from` when
## given; replaces any animation still running.
func _animate_picture(from: float, seconds: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	var rest := LIFT if _lifted else 1.0
	if Settings.reduce_motion():
		_picture.scale = Vector2.ONE * rest
		return
	if from > 0.0:
		_picture.scale = Vector2.ONE * from
	_tween = create_tween()
	_tween.tween_property(_picture, "scale", Vector2.ONE * rest, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
