class_name ShopSpotlight
extends Control
## The Shop's Mythic spotlight, at the head of today's picks: the Mythic item
## of ShopCatalog.spotlight() on a shop card set in a glowing, animated
## red-gold frame (MythicFx) under a MYTHIC ribbon. It is never discounted;
## once bought the card reads OWNED like any other. The Shop page owns the
## card (selection, buying); this only frames it.

const SIZE := Vector2(236, 190)
const FRAME := 7.0
const CARD_SIZE := SIZE - Vector2(FRAME, FRAME) * 2.0

var card: LockerCard


func _init(shop_card: LockerCard) -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE
	box.set_corner_radius_all(18)
	box.shadow_color = Color(1.0, 0.8, 0.4, 0.75)
	box.shadow_size = 10
	frame.add_theme_stylebox_override("panel", box)
	frame.material = MythicFx.material()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	card = shop_card
	card.size_flags_horizontal = Control.SIZE_FILL
	add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(FRAME))
	var ribbon := KitChip.make("MYTHIC", UiKit.CREAM, 16)
	ribbon.material = MythicFx.material()
	for child in ribbon.get_children():
		if child is Label:
			child.use_parent_material = true
	add_child(ribbon)
	ribbon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	ribbon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ribbon.position.y = -14.0


## Shows `it` (null hides the spotlight).
func show_item(it: CosmeticItem, shown_on: WeaponData, thumbs: CosmeticThumbs) -> void:
	visible = it != null
	card.visible = visible
	if it:
		card.show_item(it, shown_on, thumbs)
