extends RefCounted
## Results-screen section (data/ui/results_player_card.tres): the player card
## plus everything that landed in the Locker during this run.

const MAX_CHIPS := 5


static func build(_result: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.add_child(UiKit.spacer(4))
	var card := PlayerCard.build(false)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(card)
	var fresh := Cosmetics.unlocked_this_run()
	if fresh.is_empty():
		return col
	fresh.sort_custom(func(a, b): return a.rarity > b.rarity)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	row.add_child(UiKit.label("NEW IN YOUR LOCKER", 24, UiKit.AMBER, true))
	for i in mini(MAX_CHIPS, fresh.size()):
		row.add_child(_chip(fresh[i]))
	if fresh.size() > MAX_CHIPS:
		row.add_child(UiKit.label("+%d more" % (fresh.size() - MAX_CHIPS), 22, UiKit.CREAM))
	Sfx.play(&"cos_unlock", -4.0)
	return col


static func _chip(it: CosmeticItem) -> Control:
	var c := CosmeticItem.rarity_color(it.rarity)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiKit.box(Color(c, 0.22), c, 12, 2, 8))
	chip.add_child(UiKit.label(it.display_name, 20, Color.WHITE, true))
	chip.tooltip_text = "%s  ·  %s" % [LockerCatalog.category_label(it), CosmeticItem.rarity_name(it.rarity)]
	return chip
