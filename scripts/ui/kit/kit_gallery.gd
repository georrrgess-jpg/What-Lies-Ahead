class_name KitGallery
extends Control
## Every kit component on one screen: the living companion of
## docs/UI_STYLE.md and the quickest way to check a change to the kit.
##
##   godot --path . -- --shot=out.png --shot-scene=kit


func _ready() -> void:
	UiKit.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("2a1b4f")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var cols := HBoxContainer.new()
	cols.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, UiKit.PAGE_MARGIN)
	cols.add_theme_constant_override("separation", UiKit.GAP_XL)
	add_child(cols)
	cols.add_child(_signs())
	cols.add_child(_board())
	cols.add_child(_tray())
	UiKit.toast("Toast: 450 Sparks banked", Wallet.COLOR, &"icon_spark", 600.0)


func _column(width: float) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = width
	v.add_theme_constant_override("separation", UiKit.GAP_M)
	return v


## Marquee, every button kind and state, tabs, prompts.
func _signs() -> Control:
	var v := _column(520)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiKit.GAP_M)
	var back := UiKit.back_button()
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(back)
	head.add_child(UiKit.marquee("KIT", 72))
	v.add_child(head)
	v.add_child(UiKit.section("BUTTONS", "primary, secondary, gold, neutral"))
	for entry in [["DEPLOY", SignButton.Kind.PRIMARY], ["OPEN ARSENAL", SignButton.Kind.SECONDARY], ["BUY", SignButton.Kind.GOLD], ["DETAILS", SignButton.Kind.NEUTRAL]]:
		v.add_child(UiKit.sign_button(entry[0], entry[1]))
	var off := UiKit.sign_button("LOCKED")
	off.disabled = true
	v.add_child(off)
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", UiKit.GAP_S)
	for name in [&"icon_gear", &"icon_power", &"icon_home", &"icon_film", &"icon_tutorial", &"icon_arrow_left", &"icon_arrow_right"]:
		icons.add_child(UiKit.icon_button(name))
	v.add_child(icons)
	v.add_child(UiKit.section("TABS"))
	var tabs := UiKit.tabs()
	tabs.add_tab(&"a", "MASTERY")
	tabs.add_tab(&"b", "CHALLENGES", 3)
	tabs.add_tab(&"c", "STATS")
	v.add_child(tabs)
	v.add_child(UiKit.section("PROMPTS"))
	var prompts := HBoxContainer.new()
	prompts.add_theme_constant_override("separation", UiKit.GAP_L)
	for entry in [["ESC", "Back"], ["E", "Equip"], ["LMB", "Select"], ["SPACE", "Skip"]]:
		prompts.add_child(UiKit.key_prompt(entry[0], entry[1]))
	v.add_child(prompts)
	return v


## Signboard with a title, chip, stats, bars and the player widgets.
func _board() -> Control:
	var v := _column(560)
	var plates := HBoxContainer.new()
	plates.add_theme_constant_override("separation", UiKit.GAP_M)
	plates.add_child(UiKit.slot_plate("PRIMARY [1]", "ION CARBINE"))
	var second := UiKit.slot_plate("SECONDARY [2]", "PULSE PISTOL")
	second.active = false
	plates.add_child(second)
	v.add_child(plates)
	var board := UiKit.signboard()
	v.add_child(board)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_S)
	board.add_child(col)
	var title := UiKit.sign_label("ION CARBINE", UiKit.SIZE_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	col.add_child(UiKit.chip("AUTO · RANK 3"))
	var role := UiKit.label("Sustained fire", UiKit.SIZE_LABEL, UiKit.CREAM)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(role)
	col.add_child(UiKit.section("STATS"))
	var dps := UiKit.stat_row("DPS", "131")
	col.add_child(dps)
	var reach := UiKit.stat_row("RANGE", "", true)
	reach.set_value("36 m", 0.6)
	col.add_child(reach)
	col.add_child(UiKit.progress(0.45, 18.0, UiKit.AMBER))
	col.add_child(UiKit.sign_button("SWAP SLOTS"))
	var player := HBoxContainer.new()
	player.add_theme_constant_override("separation", UiKit.GAP_M)
	player.add_child(UiKit.level_badge())
	player.add_child(UiKit.sparks_chip())
	player.add_child(UiKit.price_tag(450))
	player.add_child(UiKit.price_tag(9000, UiKit.SIZE_LABEL, false))
	v.add_child(player)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", UiKit.GAP_S)
	chips.add_child(UiKit.chip("NEW", UiKit.PINK, 18, false))
	chips.add_child(UiKit.chip("EQUIPPED", UiKit.CYAN, 18, false))
	chips.add_child(UiKit.chip("LEGENDARY", UiKit.AMBER))
	chips.add_child(UiKit.chip("LOCKED", UiKit.NAVY))
	v.add_child(chips)
	return v


## Metal tray of item cards in every state, a neon panel and a scroll area.
func _tray() -> Control:
	var v := _column(640)
	var tray := UiKit.metal_frame()
	v.add_child(tray)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_S)
	tray.add_child(row)
	var group := ButtonGroup.new()
	var art := KitTex.tex(&"icon_spark")
	var plain := UiKit.item_card("PULSE PISTOL", Vector2(180, 220))
	plain.set_image(art)
	plain.set_tag("1ST")
	var chosen := UiKit.item_card("ION CARBINE", Vector2(180, 220))
	chosen.set_image(art)
	chosen.set_new(true)
	chosen.set_rarity(UiKit.PURPLE)
	var locked := UiKit.item_card("RAIL LANCER", Vector2(180, 220))
	locked.set_image(art)
	locked.set_locked("Lv 9")
	for card: ItemCard in [plain, chosen, locked]:
		card.button_group = group
		row.add_child(card)
	chosen.selected = true
	var offer := UiKit.item_card("COMET TRAIL", Vector2(180, 220))
	offer.set_image(art)
	offer.set_price(450)
	offer.button_group = group
	v.add_child(offer)
	var neon := UiKit.neon_panel(UiKit.PINK)
	neon.add_child(UiKit.body("Neon panel: highlights, toasts and callouts.", 560))
	v.add_child(neon)
	var plate := UiKit.metal_plate()
	plate.add_child(UiKit.label("METAL PLATE", UiKit.SIZE_LABEL, UiKit.CREAM, true))
	v.add_child(plate)
	var scroll := UiKit.scroll(Vector2(0, 150))
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in 8:
		list.add_child(UiKit.label("Scroll area row %d" % (i + 1), UiKit.SIZE_BODY, UiKit.CREAM))
	scroll.add_child(list)
	v.add_child(scroll)
	return v
