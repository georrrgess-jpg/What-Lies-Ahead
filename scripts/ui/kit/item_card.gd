class_name ItemCard
extends Button
## Item card: a picture over a name, for weapons, cosmetics and shop offers.
## It is a toggle button: put the cards of one grid in a ButtonGroup and the
## selected one wears the cyan outline. Hover and keyboard focus lift it.
##
##   var card := UiKit.item_card("ION CARBINE")
##   card.button_group = group
##   card.set_image(thumbnail)
##   card.set_locked("Lv 5")            # padlock and requirement, picture dimmed
##   card.set_price(450)                # or: Spark icon and a price
##   card.set_tag("EQUIPPED")           # corner tag
##   card.set_new(true)                 # NEW badge
##   card.set_rarity(rarity_colour)     # coloured line under the picture
##   card.pressed.connect(_select.bind(item))

const LOCKED_TINT := Color(0.34, 0.31, 0.46)

## Whether this card is the selected one of its group.
var selected: bool:
	get:
		return button_pressed
	set(v):
		if v and button_group:
			for other in button_group.get_buttons():
				other.set_pressed_no_signal(false)
		set_pressed_no_signal(v)
var _picture: TextureRect
var _holder: Control
var _title: Label
var _status: HBoxContainer
var _tag: KitChip
var _new: KitChip
var _rarity: ColorRect
var _lifted := false


static func make(title: String, card_size := Vector2(220, 250)) -> ItemCard:
	var c := ItemCard.new()
	c.custom_minimum_size = card_size
	c._build(title)
	return c


func _build(title: String) -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	add_theme_stylebox_override("normal", KitTex.box(&"card"))
	add_theme_stylebox_override("hover", KitTex.box(&"card_hover"))
	add_theme_stylebox_override("pressed", KitTex.box(&"card_selected"))
	add_theme_stylebox_override("hover_pressed", KitTex.box(&"card_selected"))
	add_theme_stylebox_override("disabled", KitTex.box(&"card"))
	add_theme_stylebox_override("focus", KitTex.box(&"focus_ring"))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	_holder = Control.new()
	_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_holder)
	_picture = TextureRect.new()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_picture)
	_rarity = ColorRect.new()
	_rarity.custom_minimum_size = Vector2(0, 4)
	_rarity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rarity.visible = false
	col.add_child(_rarity)
	_title = UiKit.label(title, 24, UiKit.CREAM, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.max_lines_visible = 2
	_title.add_theme_constant_override("line_spacing", -8)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_title)
	_status = HBoxContainer.new()
	_status.alignment = BoxContainer.ALIGNMENT_CENTER
	_status.add_theme_constant_override("separation", 6)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.visible = false
	col.add_child(_status)
	mouse_entered.connect(_update_lift.bind(true))
	mouse_exited.connect(_update_lift.bind(false))
	focus_entered.connect(_update_lift.bind(true))
	focus_exited.connect(_update_lift.bind(false))
	pressed.connect(UiSound.select)


func set_title(text: String) -> void:
	_title.text = text


## The picture (a thumbnail texture; a ViewportTexture works).
func set_image(texture: Texture2D) -> void:
	_picture.texture = texture


## Puts any Control in the picture area instead of a texture.
func set_preview(node: Control) -> void:
	_picture.visible = false
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(node)


## A plain line under the name ("Carbine", "Owned"). "" hides it.
func set_status(text: String, color := UiKit.MUTED) -> void:
	_clear_status()
	_holder.modulate = Color.WHITE
	if text != "":
		_status.add_child(UiKit.label(text, 20, color))
		_status.visible = true


## Padlock and a short requirement ("Lv 5") under the name; dims the picture.
func set_locked(requirement: String) -> void:
	_clear_status()
	_holder.modulate = LOCKED_TINT
	_status.add_child(UiKit.icon(&"icon_lock", 26.0))
	_status.add_child(UiKit.label(requirement, 22, UiKit.AMBER, true))
	_status.visible = true


## Spark icon and a price under the name; red when the player cannot pay.
func set_price(amount: int, affordable := true) -> void:
	_clear_status()
	_holder.modulate = Color.WHITE
	_status.add_child(UiKit.price_tag(amount, 22, affordable))
	_status.visible = true


## Corner tag at the top left ("EQUIPPED", "1ST"). "" hides it.
func set_tag(text: String, color := UiKit.CYAN) -> void:
	if _tag == null:
		_tag = KitChip.make("", color, 16, false)
		add_child(_tag)
		_tag.position = Vector2(8, 8)
	_tag.visible = text != ""
	_tag.set_text(text)
	_tag.set_color(color)


## NEW badge at the top right.
func set_new(is_new: bool) -> void:
	if _new == null:
		if not is_new:
			return
		_new = KitChip.make("NEW", UiKit.PINK, 16, false)
		add_child(_new)
		_new.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_new.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_new.position.y = 8
		_new.offset_right = -8
	_new.visible = is_new


## Coloured line under the picture. Color.TRANSPARENT hides it.
func set_rarity(color: Color) -> void:
	_rarity.visible = color.a > 0.0
	_rarity.color = color


func _clear_status() -> void:
	for c in _status.get_children():
		_status.remove_child(c)
		c.queue_free()
	_status.visible = false


func _update_lift(entering: bool) -> void:
	var want := (is_hovered() or has_focus()) and not disabled
	if want == _lifted:
		return
	_lifted = want
	UiFx.hover(self, want, 1.035)
	if want and entering:
		UiSound.hover()
