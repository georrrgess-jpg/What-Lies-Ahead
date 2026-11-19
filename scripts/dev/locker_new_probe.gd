extends RefCounted
## The Locker's NEW markers: lists every item counted as new (the home
## tile's "N new to try on") with where the Locker shows it, then looks at
## every card of every tab on the weapon being customised (what is left, and
## what the weapon plate says about it), then on every weapon, as a player
## clicking through would, and reports what is still counted as new.
##
##   godot --headless --path . -- --profile=<copy> --shot=/tmp/x.png \
##       --shot-scene=locker --shot-run=res://scripts/dev/locker_new_probe.gd
##
## Prints "[new] item <id> ..." lines and "[new] DONE before N, after M".


func run(_shot: Node, menu: Node) -> void:
	var page: LockerPage = menu.page("locker")
	var before := Cosmetics.new_count()
	for it in GameData.cosmetics():
		if Cosmetics.is_new(it):
			print("[new] item %s slot %s weapon '%s' tab %s shown on %s" % [it.id, it.slot, it.weapon_id,
					page._has_tab(it.slot), _shown_on(page, it)])
	# A player who looks at every card of every tab on the weapon they customise.
	for slot in _tabs(page):
		page.show_category(slot)
		_look_at_all(page)
	print("[new] after every card on %s: %d still new" % [page._weapon_id, Cosmetics.new_count()])
	for slot in _tabs(page):
		if Cosmetics.new_count(slot) > 0:
			page.show_category(slot)
			print("[new]   tab %s badge %d, cards marked NEW %d, weapon note '%s'" % [slot, Cosmetics.new_count(slot),
					page._cards.filter(func(c: LockerCard) -> bool: return c.visible and Cosmetics.is_new(c.item)).size(),
					page._weapon_plate._note.text])
	# ... and then on every weapon.
	for slot in _tabs(page):
		var weapons: Array = GameData.weapons() if LockerCatalog.is_weapon_slot(slot) else [page._weapon()]
		for w in weapons:
			page.select_weapon((w as WeaponData).id)
			page.show_category(slot)
			_look_at_all(page)
		await menu.get_tree().process_frame
	for it in GameData.cosmetics():
		if Cosmetics.is_new(it):
			print("[new] still new %s slot %s" % [it.id, it.slot])
	var badges := 0
	for id in page._group_tabs:
		for slot in (page._group_tabs[id] as KitTabs).ids():
			badges += PrizePrints.new_count() if slot == LockerFilters.PRINTS else Cosmetics.new_count(slot)
	print("[new] DONE before %d, after %d (tab badges %d)" % [before, Cosmetics.new_count(), badges])


## The weapons whose tray (unfiltered) shows `it`, or "-" when none does.
func _shown_on(page: LockerPage, it: CosmeticItem) -> String:
	var out: Array[String] = []
	for w in GameData.weapons():
		if LockerFilters.items(it.slot, w.id, LockerFilters.State.new()).has(it):
			out.append(String(w.id))
	return ", ".join(out) if not out.is_empty() else "-"


func _tabs(page: LockerPage) -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(LockerFilters.all_tabs().filter(func(slot: StringName) -> bool: return slot != LockerFilters.PRINTS and page._has_tab(slot)))
	return out


func _look_at_all(page: LockerPage) -> void:
	for card in page._cards:
		if card.visible:
			page._select(card.item, false)
