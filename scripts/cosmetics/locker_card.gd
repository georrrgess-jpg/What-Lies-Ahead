class_name LockerCard
extends ItemCard
## One cosmetic on a kit item card (Locker and Shop grids): its thumbnail,
## banner, title plate or drawn icon, the rarity line, and the state the
## player has with it: an EQUIPPED tag, a NEW badge, the price in Sparks, or
## a padlock with the requirement. Cards are reused: show_item() turns a
## card into another item without rebuilding it.

const CARD_SIZE := Vector2(176, 200)

var item: CosmeticItem
## The weapon weapon cosmetics are shown on and owned for.
var weapon: WeaponData
var state := LockerCatalog.State.LOCKED
## Art that is not a thumbnail texture (banner, title plate, drawn icon).
var _art: Control


static func create(card_size := CARD_SIZE) -> LockerCard:
	var c := LockerCard.new()
	c.custom_minimum_size = card_size
	c._build("")
	return c


## Shows `it` on this card. `thumbs` bakes the thumbnail when none is cached.
func show_item(it: CosmeticItem, shown_on: WeaponData, thumbs: CosmeticThumbs) -> void:
	item = it
	weapon = shown_on
	set_title(it.display_name.to_upper())
	set_rarity(CosmeticItem.rarity_color(it.rarity))
	_show_art(thumbs)
	refresh_state()


## Re-reads ownership, price and badges (after equipping, buying, browsing).
func refresh_state() -> void:
	if item == null:
		return
	var weapon_id: StringName = weapon.id if weapon else &""
	state = LockerCatalog.state(item, weapon_id)
	set_tag("EQUIPPED" if state == LockerCatalog.State.EQUIPPED else "")
	set_new(Cosmetics.is_new(item))
	var gated := not Cosmetics.can_unlock_purchase(item, LockerCatalog.context(item.slot, weapon_id))
	if state == LockerCatalog.State.LOCKED or state == LockerCatalog.State.FOR_SALE and gated:
		set_locked(LockerCatalog.unlock_short(item))
	elif state == LockerCatalog.State.FOR_SALE:
		var price := Cosmetics.price_of(item)
		set_price(price, Wallet.can_afford(price))
	else:
		set_status("")


func _show_art(thumbs: CosmeticThumbs) -> void:
	if _art:
		_holder.remove_child(_art)
		_art.queue_free()
		_art = null
	# A title is its own picture, so it gets the whole card.
	_title.visible = item.slot != &"title"
	_picture.texture = null
	_picture.visible = CosmeticThumbs.can_bake(item)
	if _picture.visible:
		_picture.texture = CosmeticThumbs.cached(item, weapon)
		if _picture.texture == null and thumbs:
			thumbs.request(item, _on_thumbnail.bind(item), weapon)
		return
	match item.slot:
		&"banner":
			_art = _banner_art()
		&"title":
			_art = _title_art()
		_:
			_art = CosmeticIcon.new(item)
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_art)


## A baked thumbnail arrived; ignored if the card moved on to another item.
func _on_thumbnail(texture: Texture2D, for_item: CosmeticItem) -> void:
	if for_item == item:
		set_image(texture)


func _banner_art() -> Control:
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 4)
	pad.add_theme_constant_override("margin_top", 22)
	pad.add_theme_constant_override("margin_bottom", 14)
	pad.add_child(BannerView.new(item, 12.0))
	return pad


func _title_art() -> Control:
	var plate := CenterContainer.new()
	var text := item.display_name.to_upper()
	var label := UiKit.sign_label(text, 30 if text.length() < 12 else 25, CosmeticItem.rarity_color(item.rarity).lerp(Color.WHITE, 0.35))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_constant_override("line_spacing", -8)
	label.custom_minimum_size = Vector2(custom_minimum_size.x - 28, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(label)
	return plate
