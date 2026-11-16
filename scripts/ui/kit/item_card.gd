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
## Title font size, and the smallest it shrinks to so a long word still fits.
const TITLE_SIZE := 24
const TITLE_MIN_SIZE := 14
## A name shrinks to fit two lines down to this size; past it, a third line
## reads better than tiny letters.
const TITLE_TWO_LINE_MIN := 18
## Line spacing at TITLE_SIZE (tight, as the titles are capitals); it scales
## with the font size so smaller titles do not overlap.
const TITLE_LINE_SPACING := -8.0
## Space the card keeps free on each side of its contents (the column's inset).
const INSET := 10.0
## The line under the name shrinks to at most this fraction of its size to fit a narrow card.
## The inset, and the card width under which it is used, for the narrow Arsenal cards.
const NARROW_INSET := 5.0
const NARROW_WIDTH := 120.0
const STATUS_MIN_SCALE := 0.5
## Past this much shrinking the padlock goes, so the text can stay bigger.
const STATUS_ICON_SCALE := 0.8

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
## Title font size before shrinking to fit (cards may set a smaller one).
var title_size := TITLE_SIZE:
	set(value):
		title_size = value
		if _title:
			_fit_title()
var _col: VBoxContainer
var _title: Label
var _status: HBoxContainer
var _tag: KitChip
var _new: KitChip
var _rarity: ColorRect
var _lifted := false
var _inset := INSET


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
	_col = VBoxContainer.new()
	var col := _col
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(INSET))
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
	_title = UiKit.label(title, TITLE_SIZE, UiKit.CREAM, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Wrap between words only; a word too wide for the card shrinks the text
	# instead of breaking ("SHUTTERBU / G").
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	_title.resized.connect(_fit_title)
	resized.connect(_on_resized)
	_title.max_lines_visible = 2
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
	_fit_title()


## Picks the title size so that every word fits the card's width (a name
## never breaks inside a word or spills past the card's edges) and nothing
## is cut off: the biggest size at which the name takes two lines, down to
## TITLE_TWO_LINE_MIN; below that, the biggest at which it takes three.
func _fit_title() -> void:
	# A little slack for the outline, which draws outside the glyphs.
	var width := _title.size.x - 6.0
	if width <= 0.0:
		return
	var font := _title.get_theme_font(&"font")
	var words := _title.text.split(" ", false)
	var font_size := title_size
	var lines := _line_count(font, words, font_size, width)
	var two_line_min := mini(TITLE_TWO_LINE_MIN, title_size)
	while lines > 2 and font_size > two_line_min:
		font_size -= 1
		lines = _line_count(font, words, font_size, width)
	if lines > 2:
		font_size = title_size
		lines = _line_count(font, words, font_size, width)
		while lines > 3 and font_size > TITLE_MIN_SIZE:
			font_size -= 1
			lines = _line_count(font, words, font_size, width)
	var spacing := roundi(TITLE_LINE_SPACING * font_size / TITLE_SIZE)
	if _title.get_theme_font_size(&"font_size") != font_size:
		_title.add_theme_font_size_override(&"font_size", font_size)
	if _title.get_theme_constant(&"line_spacing") != spacing:
		_title.add_theme_constant_override(&"line_spacing", spacing)
	_title.max_lines_visible = clampi(lines, 2, 3)


## How many lines `words` wrap to at `font_size` in `width` (wrapping only
## between words), or 99 when one word alone is wider than `width`.
static func _line_count(font: Font, words: PackedStringArray, font_size: int, width: float) -> int:
	if words.is_empty():
		return 1
	var space := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var lines := 1
	var line_w := -space
	for word in words:
		var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if w > width:
			return 99
		if line_w + space + w > width:
			lines += 1
			line_w = w
		else:
			line_w += space + w
	return lines


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
		_fit_status()


## Padlock and a short requirement ("Lv 5") under the name; dims the picture.
func set_locked(requirement: String) -> void:
	_clear_status()
	_holder.modulate = LOCKED_TINT
	_status.add_child(UiKit.icon(&"icon_lock", 26.0))
	_status.add_child(UiKit.label(requirement, 22, UiKit.AMBER, true))
	_status.visible = true
	_fit_status()


## Spark icon and a price under the name; red when the player cannot pay.
func set_price(amount: int, affordable := true) -> void:
	_clear_status()
	_holder.modulate = Color.WHITE
	_status.add_child(UiKit.price_tag(amount, 22, affordable))
	_status.visible = true
	_fit_status()


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


## The line under the picture for a cosmetic's rarity: its colour, and for a
## Mythic item the animated red-gold flow (MythicFx) on a thicker line and
## on the title.
func set_item_rarity(item: CosmeticItem) -> void:
	set_rarity(CosmeticItem.rarity_color(item.rarity))
	MythicFx.dress(_rarity, item)
	MythicFx.dress(_title, item)
	_rarity.custom_minimum_size.y = 6 if MythicFx.is_mythic(item) else 4


## Cards narrower than NARROW_WIDTH trim the column's inset so names and the
## line under them get the room.
func _on_resized() -> void:
	_inset = NARROW_INSET if size.x < NARROW_WIDTH else INSET
	_col.offset_left = _inset
	_col.offset_right = -_inset
	_fit_status()


## Shrinks the line under the name (text and icons together) until it fits
## inside the card, so "Wave 10" on a narrow card never runs off its edge.
func _fit_status() -> void:
	if not _status.visible or size.x <= 0.0:
		return
	var room := size.x - 2.0 * _inset
	var icons := _status.get_children().filter(func(c: Node) -> bool: return c is TextureRect)
	for icon: Control in icons:
		icon.visible = true
	var factor := _shrink_status(room, STATUS_ICON_SCALE)
	if factor < STATUS_ICON_SCALE:
		# Too narrow for the padlock and a readable line: keep the line.
		for icon: Control in icons:
			icon.visible = false
		_shrink_status(room, STATUS_MIN_SCALE)


## Scales the line down in steps until it fits `room` or reaches `floor_scale`;
## returns the scale it ended on.
func _shrink_status(room: float, floor_scale: float) -> float:
	var factor := 1.0
	_scale_status(factor)
	while _status.get_combined_minimum_size().x > room and factor > floor_scale:
		factor -= 0.05
		_scale_status(factor)
	return factor


func _scale_status(factor: float) -> void:
	for node in _status.find_children("*", "", true, false):
		if node is Label:
			if not node.has_meta(&"base_size"):
				node.set_meta(&"base_size", node.get_theme_font_size(&"font_size"))
			node.add_theme_font_size_override(&"font_size", roundi(node.get_meta(&"base_size") * factor))
		elif node is TextureRect:
			if not node.has_meta(&"base_size"):
				node.set_meta(&"base_size", node.custom_minimum_size)
			node.custom_minimum_size = (node.get_meta(&"base_size") as Vector2) * factor


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
