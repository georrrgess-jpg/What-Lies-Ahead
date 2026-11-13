extends RefCounted
## Headless check of the Locker, Shop and Career pages, driven only through
## the keyboard actions a player has: browsing with the arrows, changing
## category with A / D, equipping and buying with Enter (through the confirm
## dialog), the "cannot afford" refusal, the jump from the Shop to the Locker,
## and that a purchase survives a reload of the profile. Run it with:
##
##   godot --headless --path . -- --profile=<scratch copy> --shot=/tmp/x.png \
##       --shot-scene=locker --shot-run=res://scripts/dev/meta_pages_probe.gd
##
## Prints one "[probe] ok|FAIL ..." line per check and a final summary.

var _tree: SceneTree
var _menu: Node
var _failed := 0
var _checks := 0


func run(shot: Node, menu: Node) -> void:
	_tree = shot.get_tree()
	_menu = menu
	Profile.section("wallet")["balance"] = 5000
	await _locker()
	await _shop()
	await _career()
	print("[probe] DONE %d checks, %d failed" % [_checks, _failed])


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failed += 1
	print("[probe] %s %s" % ["ok" if ok else "FAIL", what])


func _frames(count := 3) -> void:
	for i in count:
		await _tree.process_frame


func _press(action: StringName) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(2)


func _focus() -> Control:
	return _tree.root.gui_get_focus_owner()


func _dialog() -> KitDialog:
	for node in _menu.get_children():
		if node is KitDialog and not node.is_queued_for_deletion():
			return node
	return null


func _locker() -> void:
	_menu._show("locker")
	await _frames(20)
	var page: LockerPage = _menu.page("locker")
	_check(_focus() is LockerCard and (_focus() as LockerCard).item == page._selected, "locker: focus starts on the selected card")
	var first := page._selected
	await _press(&"ui_right")
	_check(page._selected != first and (_focus() as LockerCard).item == page._selected, "locker: right arrow selects the next card")
	await _press(&"ui_down")
	_check(_focus() is LockerCard, "locker: down arrow stays in the grid")
	await _press(&"move_right")
	_check(page._slot == page._tabs.ids()[1] and _focus() is LockerCard, "locker: D opens the next category with focus on a card")
	await _press(&"move_left")
	_check(page._slot == &"avatar", "locker: A goes back a category")
	# Equip an owned operator that is not worn.
	var owned := _find(&"avatar", LockerCatalog.State.OWNED, page._weapon_id)
	if owned:
		page.select_item(owned.id)
		await _frames()
		await _press(&"ui_accept")
		_check(Cosmetics.equipped(&"avatar") == owned, "locker: Enter equips %s" % owned.id)
	# Buy something for sale through the confirm dialog, keyboard only.
	var sale: CosmeticItem = null
	for cat in LockerCatalog.CATEGORIES:
		for it in LockerCatalog.items(cat["slot"], page._weapon_id, LockerCatalog.Filter.FOR_SALE):
			if sale == null and Cosmetics.can_buy(it, LockerCatalog.context(it.slot, page._weapon_id)):
				sale = it
	_check(sale != null, "locker: something is for sale and affordable")
	if sale == null:
		return
	page.select_item(sale.id)
	await _frames()
	var before := Wallet.balance()
	var price := Cosmetics.price_of(sale)
	await _press(&"ui_accept")
	await _frames(4)
	_check(_dialog() != null, "locker: Enter on %s opens the confirm dialog" % sale.id)
	await _press(&"ui_cancel")
	await _frames(12)
	_check(_dialog() == null and Cosmetics.is_for_sale(sale) and _focus() is LockerCard, "locker: Esc cancels and focus returns to the card")
	await _press(&"ui_accept")
	await _frames(4)
	await _press(&"ui_right")
	await _press(&"ui_accept")
	await _frames(12)
	_check(Cosmetics.is_owned(sale, page._ctx()) and Wallet.balance() == before - price, "locker: confirming buys it for %d Sparks" % price)
	_check(_focus() == page._panel.action_button() and (_focus() as Button).text == "EQUIP", "locker: focus lands on EQUIP after the purchase")
	Profile.load_profile()
	_check(Cosmetics.is_owned(sale, page._ctx()) and Wallet.balance() == before - price, "profile reload: %s still owned, balance kept" % sale.id)
	await _press(&"ui_accept")
	_check(Cosmetics.equipped(sale.slot, page._ctx()) == sale, "locker: the bought item equips after the reload")


func _shop() -> void:
	_menu._show("shop")
	await _frames(20)
	var page: ShopPage = _menu.page("shop")
	_check(_focus() is LockerCard and (_focus() as LockerCard).item == page._selected, "shop: focus starts on the selected card")
	var first := page._selected
	await _press(&"ui_right")
	_check(page._selected != first, "shop: right arrow selects the next card")
	var slot := page._slot
	await _press(&"move_right")
	_check(page._slot != slot and _focus() is LockerCard, "shop: D opens the next section")
	# Too dear: no dialog, nothing changes.
	var dear: CosmeticItem = null
	for it in ShopCatalog.for_sale():
		if dear == null and ShopCatalog.is_open(it):
			dear = it
	if dear:
		Profile.section("wallet")["balance"] = 0
		Wallet.balance_changed.emit(0)
		page.select_item(dear.id)
		page._focus_selected()
		await _frames()
		await _press(&"ui_accept")
		await _frames(4)
		_check(_dialog() == null and Cosmetics.is_for_sale(dear), "shop: Enter on %s without Sparks is refused" % dear.id)
		_check(page._panel._shortfall.visible, "shop: the signboard says how many Sparks are missing")
		Profile.section("wallet")["balance"] = 5000
		Wallet.balance_changed.emit(5000)
		await _press(&"ui_accept")
		await _frames(4)
		await _press(&"ui_right")
		await _press(&"ui_accept")
		await _frames(12)
		_check(not Cosmetics.is_for_sale(dear), "shop: with Sparks, Enter and confirm buy it")
		_check(_focus() == page._panel.action_button(), "shop: focus lands on the jump to the Locker")
		await _press(&"ui_accept")
		await _frames(20)
		var locker: LockerPage = _menu.page("locker")
		_check(_menu._current_page == "locker" and locker._selected == dear, "shop: the jump opens the Locker on the bought item")
		await _press(&"ui_cancel")
		await _frames(20)
		_check(_menu._current_page == "shop", "shop: BACK returns from the Locker to the Shop")


func _career() -> void:
	_menu._show("career")
	await _frames(20)
	var page: CareerPage = _menu.page("career")
	_check(_focus() == page._next_card, "career: focus starts on the next level of the road")
	await _press(&"ui_right")
	_check(_focus() is ItemCard and _focus() != page._next_card, "career: right arrow walks the road")
	var moved := 0
	for i in 4:
		await _press(&"ui_down")
		if _focus() is CareerTile:
			moved += 1
	_check(moved > 0 and page._goal_detail.text != "", "career: down arrow reaches the goals and explains the focused one")
	for i in 14:
		if not (_focus() as Control).has_meta(&"weapon"):
			await _press(&"ui_right")
	_check(_focus() is CareerTile and (_focus() as CareerTile).has_meta(&"weapon"), "career: right arrow reaches weapon mastery")
	await _press(&"ui_accept")
	await _frames(20)
	_check(_menu._current_page == "locker", "career: Enter on a weapon opens its skins in the Locker")


func _find(slot: StringName, state: LockerCatalog.State, weapon_id: StringName) -> CosmeticItem:
	for it in LockerCatalog.items(slot, weapon_id):
		if LockerCatalog.state(it, weapon_id) == state:
			return it
	return null
