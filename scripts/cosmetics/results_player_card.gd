extends RefCounted
## Results-screen section (data/ui/results_player_card.tres): a slim
## player card, and beside it everything that landed in the Locker during
## this run (or the collection progress when nothing did). One row, so it
## adds as little height as possible to the results panel.

const MAX_CHIPS := 4


static func build(_result: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var card := PlayerCard.build(true) as PlayerCard
	card.slim = true
	row.add_child(card)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 8)
	row.add_child(side)
	var fresh := Cosmetics.unlocked_this_run()
	if fresh.is_empty():
		side.add_child(UiKit.label("LOCKER", UiKit.SIZE_LABEL, UiKit.CYAN, true))
		var owned := 0
		for it in GameData.cosmetics():
			if Cosmetics.is_owned_anywhere(it):
				owned += 1
		side.add_child(UiKit.label("%d / %d items collected" % [owned, GameData.cosmetics().size()], 22, UiKit.CREAM))
		var bar := UiKit.progress(float(owned) / maxf(1.0, GameData.cosmetics().size()), 12.0, UiKit.AMBER)
		side.add_child(bar)
		return row
	fresh.sort_custom(func(a, b): return a.rarity > b.rarity)
	side.add_child(UiKit.label("NEW IN YOUR LOCKER", UiKit.SIZE_LABEL, UiKit.CYAN, true))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	side.add_child(chips)
	for i in mini(MAX_CHIPS, fresh.size()):
		chips.add_child(_chip(fresh[i]))
	if fresh.size() > MAX_CHIPS:
		chips.add_child(UiKit.label("+%d more" % (fresh.size() - MAX_CHIPS), 20, UiKit.CREAM))
	Sfx.play(&"cos_unlock", -4.0)
	return row


static func _chip(it: CosmeticItem) -> Control:
	var chip := UiKit.card_panel(10)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -6)
	chip.add_child(col)
	col.add_child(UiKit.label(it.display_name.to_upper(), 22, CosmeticItem.rarity_color(it.rarity).lerp(UiKit.CREAM, 0.3), true))
	col.add_child(UiKit.label(LockerCatalog.category_label(it), UiKit.SIZE_SMALL, UiKit.MUTED))
	return chip
