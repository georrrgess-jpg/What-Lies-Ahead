class_name PrintCard
extends ItemCard
## One Prize Print on a kit item card: the baked thumbnail of the print itself,
## its serial in the corner (gold when special), the rarity line, the finish
## name, its grade and rare print under it, NEW, a heart for a favourite and a
## WORN mark. Cards are reused: show_print() turns a card into another print.

const CARD_SIZE := Vector2(176, 206)

var print_data: Dictionary = {}
var weapon: WeaponData
var _heart: Label
var _worn: KitChip
var _pick: KitChip


static func create(card_size := CARD_SIZE) -> PrintCard:
	var c := PrintCard.new()
	c.custom_minimum_size = card_size
	c._build("")
	c.title_size = 21
	c._heart = UiKit.label("♥", 26, UiKit.PINK, true)
	c._heart.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	c._heart.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	c._heart.grow_vertical = Control.GROW_DIRECTION_BEGIN
	c._heart.position -= Vector2(10, 64)
	c._heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(c._heart)
	c._worn = KitChip.make("WORN", UiKit.GREEN, 14, false)
	c._worn.position = Vector2(8, 34)
	c.add_child(c._worn)
	c._pick = KitChip.make("", UiKit.AMBER, 18, false)
	c._pick.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	c._pick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c._pick.visible = false
	c._worn.visible = false
	c.add_child(c._pick)
	return c


## Shows `p` (a PrizePrints dictionary) on this card, on `shown_on`.
func show_print(p: Dictionary, shown_on: WeaponData, thumbs: CosmeticThumbs) -> void:
	print_data = p
	weapon = shown_on
	var fin := PrizePrints.finish_of(p)
	set_title(fin.display_name.to_upper() if fin else "?")
	set_rarity(PrintLook.rarity_color(p))
	var serial := int(p.get("serial", 0))
	set_tag(PrintLook.serial_text(serial), UiKit.AMBER if PrintLook.serial_tag(serial) != "" else UiKit.CYAN)
	set_image(CosmeticThumbs.cached_print(p, shown_on))
	if _picture.texture == null and thumbs:
		thumbs.request_print(p, _on_thumbnail.bind(String(p.get("id", "")), shown_on), shown_on)
	refresh_state()


## Re-reads NEW, favourite and worn (after equipping or browsing).
func refresh_state() -> void:
	if print_data.is_empty():
		return
	set_new(bool(print_data.get("new", false)))
	_heart.visible = bool(print_data.get("fav", false))
	_worn.visible = not PrizePrints.worn_on(print_data).is_empty()
	var text := PrintLook.grade_name(print_data).to_upper()
	var v := String(print_data.get("var", ""))
	if v != "":
		set_status(text + "  ·  " + String(PrintLook.VARIANTS[v]["short"]), PrintLook.variant_color(print_data))
	else:
		set_status(text, PrintLook.grade_color(print_data))


## A big mark in the middle of the card ("1", "2" ... in a trade-up). "" hides it.
func set_pick(text: String) -> void:
	_pick.visible = text != ""
	_pick.set_text(text)


func _on_thumbnail(texture: Texture2D, for_id: String, for_weapon: WeaponData) -> void:
	if String(print_data.get("id", "")) == for_id and for_weapon == weapon:
		set_image(texture)
