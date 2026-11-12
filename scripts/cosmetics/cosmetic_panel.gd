class_name CosmeticPanel
extends KitPanel
## The item signboard of the Locker and the Shop: a cosmetic's name, rarity,
## what it is and what it does, and exactly one action for where the player
## stands with it:
##   owned      EQUIP (pink), or an EQUIPPED plate once it is worn
##   for sale   BUY with the price (gold); when the player cannot pay, how
##              many Sparks are missing and how to earn them
##   locked     the requirement with a progress bar (and the price that
##              follows, for items that are also sold)
## The panel only asks: connect equip_requested, unequip_requested,
## buy_requested and locker_requested. refused() answers a press that
## cannot do anything yet.

signal equip_requested(item: CosmeticItem)
signal unequip_requested(item: CosmeticItem)
signal buy_requested(item: CosmeticItem)
## Shop mode: the player wants to see an item they own in the Locker.
signal locker_requested(item: CosmeticItem)

var item: CosmeticItem
## The Shop sells and does not equip: owned items offer a jump to the Locker.
var shop_mode := false
var _weapon_id: StringName
var _name: Label
var _rarity: KitChip
var _category: Label
var _description: Label
var _owned_row: HBoxContainer
var _owned_text: Label
var _requirement: KitPanel
var _requirement_text: Label
var _requirement_bar: ProgressBar
var _requirement_progress: Label
var _requirement_price: HBoxContainer
var _shortfall: Label
var _equip: SignButton
var _equipped: KitPanel
var _buy: SignButton
var _buy_price: HBoxContainer
var _locker: SignButton
var _unequip: SignButton


func _init() -> void:
	kind = Kind.SIGNBOARD
	_style()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_XS)
	add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiKit.GAP_M)
	col.add_child(head)
	_name = UiKit.sign_label("", UiKit.SIZE_HEADING)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_name)
	_rarity = UiKit.chip("", UiKit.CYAN, 22)
	head.add_child(_rarity)
	_category = UiKit.label("", 22, UiKit.CYAN, true)
	_category.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_category)
	col.add_child(UiKit.spacer(UiKit.GAP_XS))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UiKit.GAP_L)
	col.add_child(body)
	body.add_child(_build_story())
	body.add_child(_build_actions())


## Left half: what the item is, and where the player stands with it.
func _build_story() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", UiKit.GAP_S)
	_description = UiKit.body("", 240, 22)
	_description.max_lines_visible = 4
	_description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_description)
	col.add_child(UiKit.filler())
	_owned_row = HBoxContainer.new()
	_owned_row.add_theme_constant_override("separation", UiKit.GAP_S)
	_owned_row.add_child(UiKit.icon(&"icon_check", 26.0, UiKit.GREEN))
	_owned_text = UiKit.label("", 22, UiKit.GREEN, true)
	_owned_row.add_child(_owned_text)
	col.add_child(_owned_row)
	_shortfall = UiKit.body("", 240, UiKit.SIZE_SMALL, UiKit.RED)
	col.add_child(_shortfall)
	return col


## Right half: the one action, or what unlocks the item.
func _build_actions() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 340
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", UiKit.GAP_S)
	col.add_child(_build_requirement())
	_unequip = UiKit.sign_button("UNEQUIP", SignButton.Kind.NEUTRAL, 24)
	_unequip.size_flags_horizontal = Control.SIZE_SHRINK_END
	_unequip.pressed.connect(func(): unequip_requested.emit(item))
	col.add_child(_unequip)
	_equip = UiKit.sign_button("EQUIP", SignButton.Kind.PRIMARY, 44)
	_equip.custom_minimum_size.y = 88
	_equip.pressed.connect(func(): equip_requested.emit(item))
	col.add_child(_equip)
	_buy = UiKit.sign_button("", SignButton.Kind.GOLD, 40)
	_buy.custom_minimum_size.y = 88
	_buy.pressed.connect(func(): buy_requested.emit(item))
	col.add_child(_buy)
	_buy_price = HBoxContainer.new()
	_buy_price.alignment = BoxContainer.ALIGNMENT_CENTER
	_buy_price.add_theme_constant_override("separation", UiKit.GAP_M)
	_buy_price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buy_price.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_buy_price.offset_bottom = -8
	_buy.add_child(_buy_price)
	_locker = UiKit.sign_button("EQUIP IN LOCKER", SignButton.Kind.SECONDARY, 32)
	_locker.custom_minimum_size.y = 88
	_locker.pressed.connect(func(): locker_requested.emit(item))
	col.add_child(_locker)
	_equipped = UiKit.neon_panel(UiKit.CYAN)
	_equipped.set_padding(24, 14)
	_equipped.custom_minimum_size.y = 80
	var plate := HBoxContainer.new()
	plate.alignment = BoxContainer.ALIGNMENT_CENTER
	plate.add_theme_constant_override("separation", UiKit.GAP_S)
	plate.add_child(UiKit.icon(&"icon_check", 36.0, UiKit.CYAN))
	plate.add_child(UiKit.sign_label("EQUIPPED", 38))
	_equipped.add_child(plate)
	col.add_child(_equipped)
	return col


## Padlock, what unlocks the item, how far along the player is, and the
## price that follows when the item is also sold.
func _build_requirement() -> Control:
	_requirement = UiKit.neon_panel(UiKit.AMBER)
	_requirement.set_padding(18, 14)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_XS)
	_requirement.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiKit.GAP_S)
	col.add_child(head)
	head.add_child(UiKit.icon(&"icon_lock", 30.0))
	var caption := UiKit.label("LOCKED", UiKit.SIZE_LABEL, UiKit.AMBER, true)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(caption)
	_requirement_price = HBoxContainer.new()
	_requirement_price.add_theme_constant_override("separation", UiKit.GAP_S)
	head.add_child(_requirement_price)
	_requirement_text = UiKit.body("", 280, 22, UiKit.CREAM)
	_requirement_text.max_lines_visible = 2
	_requirement_text.add_theme_constant_override("line_spacing", -4)
	col.add_child(_requirement_text)
	var meter := HBoxContainer.new()
	meter.add_theme_constant_override("separation", UiKit.GAP_M)
	col.add_child(meter)
	_requirement_bar = UiKit.progress(0.0, 14.0, UiKit.AMBER)
	_requirement_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_requirement_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.add_child(_requirement_bar)
	_requirement_progress = UiKit.label("", UiKit.SIZE_SMALL, UiKit.AMBER, true)
	meter.add_child(_requirement_progress)
	return _requirement


## Shows `it` as the player stands with it (on `weapon_id` for weapon slots).
func show_item(it: CosmeticItem, weapon_id: StringName = &"") -> void:
	item = it
	_weapon_id = weapon_id
	visible = it != null
	if it == null:
		return
	_name.text = it.display_name.to_upper()
	_rarity.set_text(CosmeticItem.rarity_name(it.rarity).to_upper())
	_rarity.set_color(CosmeticItem.rarity_color(it.rarity))
	_category.text = _category_text(it)
	_description.text = it.description
	refresh()


## Re-reads the item's state (after equipping, buying, a change of balance).
func refresh() -> void:
	if item == null:
		return
	var ctx := LockerCatalog.context(item.slot, _weapon_id)
	var state := LockerCatalog.state(item, _weapon_id)
	var owned := state <= LockerCatalog.State.OWNED
	var worn := state == LockerCatalog.State.EQUIPPED
	var purchasable := state == LockerCatalog.State.FOR_SALE and Cosmetics.can_unlock_purchase(item, ctx)
	_owned_row.visible = owned
	_owned_text.text = _owned_text_for(item)
	_requirement.visible = not owned and not purchasable
	if _requirement.visible:
		_show_requirement(ctx, state == LockerCatalog.State.FOR_SALE)
	var missing := PurchaseFlow.shortfall(item) if purchasable else 0
	_shortfall.visible = missing > 0
	_shortfall.text = "%s more %s needed. %s" % [Wallet.format(missing), Wallet.CURRENCY, PurchaseFlow.EARN_HINT]
	_equip.visible = owned and not worn and not shop_mode
	_equipped.visible = worn and not shop_mode
	_locker.visible = owned and shop_mode
	_buy.visible = purchasable
	if purchasable:
		_show_price(missing == 0)
	_unequip.visible = worn and not shop_mode and not LockerCatalog.has_default(item.slot) and Cosmetics.equipped(item.slot, ctx) == item


## The button the player presses for this item (null when there is none:
## the item is worn or still locked).
func action_button() -> Button:
	for b: Button in [_equip, _buy, _locker, _unequip]:
		if b.visible:
			return b
	return null


## The item cannot be used yet: the sound, and a nudge of what is missing.
func refused() -> void:
	UiSound.deny()
	if _requirement.visible:
		UiFx.pulse(_requirement, 1.04)


## Draws the eye to the action (after a purchase turns BUY into EQUIP).
func pulse_action() -> void:
	var b := action_button()
	if b:
		UiFx.pulse(b, 1.12)


func _category_text(it: CosmeticItem) -> String:
	var text := LockerCatalog.category_label(it).to_upper()
	if not it.is_weapon_slot():
		return text
	var w := GameData.weapon(it.weapon_id)
	return "%s  ·  %s" % [text, (w.display_name.to_upper() + " ONLY") if w else "FITS EVERY WEAPON"]


func _owned_text_for(it: CosmeticItem) -> String:
	if it.price > 0:
		return "Bought with %s" % Wallet.CURRENCY
	return "Unlocked" if it.requirement else "Yours from the start"


func _show_requirement(ctx: StringName, for_sale: bool) -> void:
	_requirement_text.text = LockerCatalog.unlock_text(item)
	var fraction := LockerCatalog.progress(item, ctx)
	_requirement_bar.get_parent().visible = fraction >= 0.0
	_requirement_bar.value = maxf(0.0, fraction)
	_requirement_progress.text = LockerCatalog.progress_text(item, ctx)
	_clear(_requirement_price)
	_requirement_price.visible = for_sale
	if for_sale:
		_requirement_price.add_child(UiKit.label("THEN", UiKit.SIZE_SMALL, UiKit.MUTED, true))
		_requirement_price.add_child(UiKit.price_tag(item.price, 22))


## The face of the BUY button: "BUY" and the price on a dark plate (red when
## the player cannot pay it yet).
func _show_price(affordable: bool) -> void:
	_clear(_buy_price)
	var word := UiKit.label("BUY", 40, Color("3a1a08"), true)
	word.add_theme_constant_override("shadow_offset_y", 0)
	_buy_price.add_child(word)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.92), Color.TRANSPARENT, 22, 0, 4))
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_right", 14)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(pad)
	pad.add_child(UiKit.price_tag(item.price, 34, affordable))
	_buy_price.add_child(plate)
	_buy.modulate = Color.WHITE if affordable else Color(0.82, 0.8, 0.86)


static func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
