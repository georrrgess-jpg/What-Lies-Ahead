extends RefCounted
## The Locker's NEW markers, played like a player clearing them: every card
## of every tab on the weapon being customised is looked at, then every tab
## badge on that weapon must read 0 (each badge counts only NEW cards its
## tray can show). Then the picker visits each weapon whose class tab still
## shows a count, and the home tile's count must reach 0. Also checks that
## the header's group badges add up to the home tile's count throughout.
##
##   godot --headless --path . -- --profile=<copy> --shot=/tmp/x.png \
##       --shot-scene=locker --shot-run=res://scripts/dev/locker_new_probe.gd
##
## Prints "[new] ..." lines and "[new] DONE before N, after M, problems P".

var _problems := 0


func run(_shot: Node, menu: Node) -> void:
	var page: LockerPage = menu.page("locker")
	var before := Cosmetics.new_count()
	_check_totals(page, "start")
	for slot in _tabs(page):
		page.show_category(slot)
		_check_tab(page, slot)
		_look_at_all(page)
	var left := 0
	for slot in _tabs(page):
		page.show_category(slot)
		left += _badge(page._tabs.button(slot))
	print("[new] after every card on %s: tab badges %d, still new %d, class badges %d / %d" % [page._weapon_id, left,
			Cosmetics.new_count(), _badge(page._class_tabs[0]), _badge(page._class_tabs[1])])
	if left != 0:
		_fail("tab badges left on %s: %d" % [page._weapon_id, left])
	_check_totals(page, "after one weapon")
	# Visit each weapon the class tabs point to, as the arrows would.
	var visits := 0
	for w in GameData.weapons():
		if not _has_new_specific(w.id):
			continue
		visits += 1
		page.select_weapon(w.id)
		for slot in _tabs(page):
			page.show_category(slot)
			_check_tab(page, slot)
			_look_at_all(page)
		await menu.get_tree().process_frame
	_check_totals(page, "end")
	for it in GameData.cosmetics():
		if Cosmetics.is_new(it):
			_fail("still new %s (%s)" % [it.id, it.slot])
	print("[new] DONE before %d, after %d (weapons visited %d), problems %d" % [before, Cosmetics.new_count(), visits, _problems])


## A tab's badge equals the NEW cards on show.
func _check_tab(page: LockerPage, slot: StringName) -> void:
	var shown := page._cards.filter(func(c: LockerCard) -> bool: return c.visible and Cosmetics.is_new(c.item)).size()
	var badge := _badge(page._tabs.button(slot))
	if badge != shown:
		_fail("%s on %s: badge %d, NEW cards %d" % [slot, page._weapon_id, badge, shown])


## The header's groups add up to the home tile's count (plus new prints).
func _check_totals(page: LockerPage, when: String) -> void:
	var total := 0
	for g in LockerFilters.GROUPS:
		total += _badge(page._groups.button(g["id"]))
	var home := Cosmetics.new_count() + PrizePrints.new_count()
	print("[new] %s: header %d, home tile %d (+%d prints)" % [when, total, Cosmetics.new_count(), PrizePrints.new_count()])
	if total != home:
		_fail("%s: header %d != home %d" % [when, total, home])


func _has_new_specific(weapon_id: StringName) -> bool:
	for it in GameData.cosmetics():
		if it.weapon_id == weapon_id and Cosmetics.is_new(it):
			return true
	return false


func _badge(button: Control) -> int:
	var chip := button.get_node_or_null("Badge") as KitChip if button else null
	return int(chip._label.text) if chip and chip.visible else 0


func _tabs(page: LockerPage) -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(LockerFilters.all_tabs().filter(func(slot: StringName) -> bool: return slot != LockerFilters.PRINTS and page._has_tab(slot)))
	return out


func _look_at_all(page: LockerPage) -> void:
	for card in page._cards:
		if card.visible:
			page._select(card.item, false)


func _fail(what: String) -> void:
	_problems += 1
	print("[new] PROBLEM " + what)
