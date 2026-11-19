extends RefCounted
## The Arsenal's release check, driven like a player would (mouse clicks and
## drags pushed into the viewport, keys and pad buttons through Input), at
## the five target window sizes and while the window is resized:
##   regions      the five regions (top bar, sidebar, preview, details, dock)
##                are on screen and never overlap
##   labels       every label fits, or is cut with an ellipsis and has a tooltip
##   buttons      the topmost control under each button's centre is that button
##   cards        every card of both categories is reachable by paging, and the
##                selected one is on the shown page
##   framing      every weapon's model (every visible mesh, the charm included)
##                projects inside the preview rectangle at several turns
##   browsing     category switches x20, 30 cards clicked one frame apart, drag
##                on the preview turns the weapon and drag on a card does not
##   equipping    the button's states, equip -> leave -> come back, equip ->
##                save -> reload the profile, keys (F, 1 / 2, LB / RB, arrows)
##   data         mastery at 0 and at max rank, longest name and description,
##                locked weapons (a fresh profile has many)
## Run (headless is enough; on a real display the window itself is resized):
##
##   godot --headless --path . -- --profile=<scratch copy> --shot=/tmp/x.png \
##       --shot-scene=arsenal --shot-run=res://scripts/dev/arsenal_probe.gd
##
## Prints "[arsenal] PASS|FAIL <check> <size>: detail" and
## "[arsenal] DONE <n> checks, <m> failed".

const SIZES: Array[Vector2i] = [
	Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1366, 768), Vector2i(1280, 720), Vector2i(1024, 768),
]
## Card count the dock should show at each of SIZES.
const CARDS := [6, 6, 5, 5, 4]
const SLACK := 2.0
const YAWS := [0.0, 0.8, 1.6, 2.4, 3.2, 4.0, 4.8, 5.6]

var _tree: SceneTree
var _menu: Node
var _page: ArsenalPage
var _checks := 0
var _failed := 0
var _size := ""


func run(_shot: Node, menu: Node) -> void:
	_tree = menu.get_tree()
	_menu = menu
	_page = menu.page("arsenal")
	await _settle()
	for i in SIZES.size():
		await _resize(SIZES[i])
		await _check_size(CARDS[i])
	_size = "resizing"
	await _check_live_resize()
	await _resize(Vector2i(1600, 900))
	_size = "1600x900"
	await _check_interactions()
	print("[arsenal] DONE %d checks, %d failed" % [_checks, _failed])


func _check(ok: bool, what: String, detail := "") -> void:
	_checks += 1
	if not ok:
		_failed += 1
	print("[arsenal] %s %s %s%s" % ["PASS" if ok else "FAIL", what, _size, (": " + detail) if detail != "" else ""])


# --- helpers ------------------------------------------------------------------------------

func _frames(count := 2) -> void:
	for i in count:
		await _tree.process_frame


func _settle(seconds := 0.35) -> void:
	await _tree.create_timer(seconds, true, false, true).timeout
	await _frames(2)


## Resizes the window: the OS window on a real display, the root viewport headless.
func _resize(s: Vector2i) -> void:
	_size = "%dx%d" % [s.x, s.y]
	if DisplayServer.get_name() == "headless":
		_tree.root.size = s
	else:
		DisplayServer.window_set_size(s)
		_tree.root.size = s
	await _settle(0.25)


func _rect(c: Control) -> Rect2:
	return c.get_global_transform() * Rect2(Vector2.ZERO, c.size)


func _view() -> Rect2:
	return _tree.root.get_visible_rect()


func _push(event: InputEvent) -> void:
	_tree.root.push_input(event, true)


func _move_to(at: Vector2, mask := 0) -> void:
	var m := InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	m.button_mask = mask
	_push(m)


func _click(at: Vector2) -> void:
	_move_to(at)
	for down in [true, false]:
		var b := InputEventMouseButton.new()
		b.position = at
		b.global_position = at
		b.button_index = MOUSE_BUTTON_LEFT
		b.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		b.pressed = down
		_push(b)


## The control the mouse would hit at `at` (canvas pixels).
func _hit(at: Vector2) -> Control:
	_move_to(at)
	return _tree.root.gui_get_hovered_control()


func _action(action: StringName) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(2)


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(2)


func _pad(button: JoyButton) -> void:
	for down in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(2)


func _select(w: WeaponData) -> void:
	_page._select(w)
	_page.preview().flush()
	await _frames(2)


func _visible_in(c: Control) -> bool:
	return c.is_visible_in_tree() and _alpha(c) > 0.05


func _alpha(c: CanvasItem) -> float:
	var a := 1.0
	var n: Node = c
	while n:
		if n is CanvasItem:
			a *= (n as CanvasItem).modulate.a
		n = n.get_parent()
	return a


# --- per size ------------------------------------------------------------------------------

func _check_size(cards: int) -> void:
	_check(_page.dock().per_page == cards, "dock-card-count", "%d (want %d) %s" % [_page.dock().per_page, cards, _page.layout()])
	for slot in 2:
		_page._switch_category(slot)
		await _settle(0.3)
		_check_regions()
		_check_labels()
		await _check_buttons()
		await _check_cards(slot)
	await _check_framing()


## The five regions: inside the window, apart from one another.
func _check_regions() -> void:
	var regions := {
		"topbar": _menu._top_bar, "sidebar": _page.sidebar(), "preview": _page.preview(),
		"details": _page.details(), "dock": _page.dock(),
	}
	var problems: Array[String] = []
	var names := regions.keys()
	for i in names.size():
		var a := _rect(regions[names[i]])
		if not _view().grow(SLACK).encloses(a):
			problems.append("%s outside the window %s" % [names[i], a])
		if a.size.x < 40.0 or a.size.y < 40.0:
			problems.append("%s collapsed %s" % [names[i], a])
		for j in range(i + 1, names.size()):
			var overlap := a.intersection(_rect(regions[names[j]]))
			if overlap.size.x > SLACK and overlap.size.y > SLACK:
				problems.append("%s overlaps %s by %s" % [names[i], names[j], overlap.size])
	_check(problems.is_empty(), "regions", "; ".join(problems))
	var preview := _rect(_page.preview())
	_check(preview.size.x >= 480.0 and preview.size.y >= 380.0, "preview-size", "%s" % preview.size)


## Every label on the page fits its box, or is cut with an ellipsis and has a tooltip.
func _check_labels() -> void:
	var problems: Array[String] = []
	for node in _page.find_children("*", "Label", true, false):
		var l := node as Label
		if not _visible_in(l) or l.text == "" or l.size.x < 1.0:
			continue
		var problem := _label_problem(l)
		if problem != "":
			problems.append(problem)
	_check(problems.is_empty(), "labels", "; ".join(problems.slice(0, 6)))


func _label_problem(l: Label) -> String:
	var font := l.get_theme_font(&"font")
	var font_size := l.get_theme_font_size(&"font_size")
	if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
		var need := l.get_minimum_size().y
		var lines_ok := l.max_lines_visible < 0 or l.get_line_count() <= l.max_lines_visible
		if need > l.size.y + SLACK or not lines_ok:
			return "\"%s\" wraps past its box" % l.text.left(30)
		return ""
	var width := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if width <= l.size.x + SLACK:
		return ""
	var cut := l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
	if cut and _tooltip_of(l) != "":
		return ""
	return "\"%s\" is clipped (%d > %d)%s" % [l.text.left(30), width, l.size.x, "" if cut else " without an ellipsis"]


## The tooltip that shows over `c` (its own, or its nearest ancestor's).
func _tooltip_of(c: Control) -> String:
	var n: Node = c
	while n is Control:
		if (n as Control).tooltip_text != "":
			return (n as Control).tooltip_text
		n = n.get_parent()
	return ""


## Each button on the page answers the mouse at its centre.
func _check_buttons() -> void:
	var problems: Array[String] = []
	var count := 0
	for node in _page.find_children("*", "BaseButton", true, false):
		var b := node as BaseButton
		if not _visible_in(b) or b.size.x < 4.0:
			continue
		count += 1
		var hit := _hit(_rect(b).get_center())
		if hit != b and not (hit and b.is_ancestor_of(hit) and hit.mouse_filter != Control.MOUSE_FILTER_STOP):
			problems.append("%s is under %s" % [b.name, hit.name if hit else "nothing"])
	await _frames(1)
	_check(problems.is_empty() and count >= 10, "buttons-hit", "%d buttons; %s" % [count, "; ".join(problems.slice(0, 6))])


## Every card of the category is reachable by paging, inside the dock's row.
func _check_cards(slot: int) -> void:
	var dock := _page.dock()
	var seen := {}
	var problems: Array[String] = []
	var row := _rect(dock.find_child("Cards", true, false) as Control)
	for p in dock.pages():
		dock.turn(-99)
		dock.turn(p)
		while dock.sliding():
			await _frames(1)
		await _frames(2)
		for c in dock.visible_cards():
			seen[c.weapon.id] = true
			if not row.grow(SLACK).encloses(_rect(c)):
				problems.append("%s outside the dock row" % c.weapon.id)
			if c.find_child("EquippedTag", true, false).visible and _rect(c.find_child("EquippedTag", true, false)).intersects(_rect(c.find_child("CardName", true, false))):
				problems.append("%s tag over its name" % c.weapon.id)
	var all := Loadout.weapons_for(slot)
	_check(seen.size() == all.size() and problems.is_empty(), "cards-reachable-%d" % slot, "%d / %d; %s" % [seen.size(), all.size(), "; ".join(problems.slice(0, 4))])
	_page._select(_page.selected())
	await _frames(2)
	_check(dock.visible_cards().has(dock.card(_page.selected().id)), "selected-card-shown-%d" % slot)


## Every weapon's model, every visible mesh and the charm, projects inside the
## preview rectangle at each of YAWS.
func _check_framing() -> void:
	var bad: Array[String] = []
	var worst := INF
	for w in GameData.weapons():
		await _select(w)
		var preview := _page.preview()
		for yaw in YAWS:
			preview.set_yaw(yaw)
			await _frames(2)
			var margin := _model_margin(preview)
			worst = minf(worst, margin)
			if margin < 0.0:
				bad.append("%s at %.1f (%.0f px out)" % [w.id, yaw, -margin])
				break
	_check(bad.is_empty(), "framing-all-weapons", "least margin %.0f px; %s" % [worst, "; ".join(bad.slice(0, 5))])


## Least distance (canvas px) from the model's projected parts to the preview's
## edges; negative when something is outside.
func _model_margin(preview: ArsenalPreview) -> float:
	var model := preview.model()
	if model == null:
		return -999.0
	var cam := preview.camera()
	var vp := cam.get_viewport() as SubViewport
	var rect := _rect(preview)
	var k := rect.size / Vector2(vp.size)
	var least := INF
	for node in model.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		var box := gi.get_aabb()
		for i in 8:
			var p := cam.unproject_position(gi.global_transform * box.get_endpoint(i)) * k + rect.position
			least = minf(least, minf(minf(p.x - rect.position.x, rect.end.x - p.x), minf(p.y - rect.position.y, rect.end.y - p.y)))
	return least


# --- resizing while open -----------------------------------------------------------------------

func _check_live_resize() -> void:
	var sizes: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1024, 768), Vector2i(1700, 950), Vector2i(1280, 720), Vector2i(2560, 1080), Vector2i(1366, 768)]
	_page._select(GameData.weapon(&"scatter_blaster"))
	for s in sizes:
		if DisplayServer.get_name() == "headless":
			_tree.root.size = s
		else:
			DisplayServer.window_set_size(s)
		# Browse while the window changes: two frames, then the next size.
		_page._select(GameData.weapons()[s.x % GameData.weapons().size()])
		await _frames(2)
	await _settle(0.3)
	_size = "after-resizes"
	_check_regions()
	_check_labels()
	await _check_buttons()
	var preview := _page.preview()
	preview.flush()
	await _frames(2)
	_check(_model_margin(preview) >= 0.0, "framing-after-resize", "%.0f px" % _model_margin(preview))


# --- interactions ----------------------------------------------------------------------------

func _check_interactions() -> void:
	await _check_categories()
	await _check_rapid_clicks()
	await _check_drag()
	await _check_keyboard()
	await _check_equip_states()
	await _check_equip_persists()
	await _check_mastery_ends()
	await _check_long_text()
	await _check_locked()
	_check(_page.find_child("CoachAnchor", true, false) != null, "coach-anchor")


## 20 category switches by tab click, key and pad button.
func _check_categories() -> void:
	var problems: Array[String] = []
	var tabs := _page.sidebar().tabs()
	for i in 20:
		var want := (i + 1) % 2
		match i % 3:
			0:
				_click(_rect(tabs[want]).get_center())
				await _frames(2)
			1:
				await _key(KEY_1 if want == 0 else KEY_2)
			2:
				await _pad(JOY_BUTTON_LEFT_SHOULDER if want == 0 else JOY_BUTTON_RIGHT_SHOULDER)
		var list := _page.dock().cards()
		var right := _page.category() == want and Loadout.slot_for(_page.selected()) == want
		right = right and list.size() == Loadout.weapons_for(want).size() and tabs[want].button_pressed and not tabs[1 - want].button_pressed
		if not right:
			problems.append("switch %d to %d" % [i, want])
	await _settle(0.3)
	_check_regions()
	_check(problems.is_empty(), "category-switch-x20", "; ".join(problems))


## 30 cards clicked, one per frame (turning pages as needed): the last one wins
## and only one model is left in the viewport.
func _check_rapid_clicks() -> void:
	var dock := _page.dock()
	var last: WeaponData
	for i in 30:
		var shown := dock.visible_cards()
		if i % 4 == 3:
			dock.turn(1 if dock.page < dock.pages() - 1 else -99)
			shown = dock.visible_cards()
			await _frames(1)
		var c: ArsenalCard = shown[i % shown.size()]
		_click(_rect(c).get_center())
		last = c.weapon
		await _frames(1)
	await _settle(0.3)
	var preview := _page.preview()
	var holder := preview.model().get_parent() if preview.model() else null
	_check(_page.selected() == last and preview.weapon == last, "rapid-select-30", "%s / %s" % [_page.selected().id, preview.weapon.id if preview.weapon else &""])
	_check(holder != null and holder.get_child_count() == 1, "old-models-freed", "%d models" % (holder.get_child_count() if holder else -1))
	_check(dock.card(last.id).selected and dock.visible_cards().has(dock.card(last.id)), "rapid-select-outline")
	_check((_page.details().find_child("WeaponName", true, false) as Label).text == last.display_name.to_upper(), "rapid-select-details")


## A drag on the preview turns the weapon; a drag that starts on a card or
## on the EQUIP button does not (and the click still reaches the card).
func _check_drag() -> void:
	var preview := _page.preview()
	var middle := _rect(preview).get_center()
	_check(_hit(middle) == preview, "preview-hit", "%s" % _hit(middle))
	var before: float = preview._yaw
	await _drag(middle, Vector2(160, 0))
	_check(absf(preview._yaw - before) > 0.5, "drag-rotates", "%.2f -> %.2f" % [before, preview._yaw])
	before = preview._yaw
	var c: ArsenalCard = _page.dock().visible_cards()[0]
	await _drag(_rect(c).get_center(), Vector2(160, 0))
	_check(is_equal_approx(preview._yaw, before), "drag-on-card-no-rotate")
	await _drag(_rect(_page.details().equip_button()).get_center(), Vector2(-200, 0))
	_check(is_equal_approx(preview._yaw, before), "drag-on-button-no-rotate")
	await _drag(_rect(_page.sidebar()).get_center(), Vector2(200, 0))
	_check(is_equal_approx(preview._yaw, before), "drag-on-sidebar-no-rotate")


func _drag(from: Vector2, by: Vector2) -> void:
	_move_to(from)
	var press := InputEventMouseButton.new()
	press.position = from
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	_push(press)
	for i in 8:
		var m := InputEventMouseMotion.new()
		m.position = from + by * (i + 1) / 8.0
		m.relative = by / 8.0
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		_push(m)
		await _frames(1)
	var release := InputEventMouseButton.new()
	release.position = from + by
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	_push(release)
	await _frames(2)


## Focus walks the cards (across pages), Enter previews, F equips.
func _check_keyboard() -> void:
	_page._switch_category(Loadout.PRIMARY)
	await _frames(2)
	var dock := _page.dock()
	dock.turn(-99)
	dock.visible_cards()[0].grab_focus()
	var visited := {}
	for i in dock.cards().size() + 2:
		var f := _tree.root.gui_get_focus_owner()
		if f is ArsenalCard:
			visited[(f as ArsenalCard).weapon.id] = true
		await _action(&"ui_right")
	_check(KitDialog.open_count == 0 and _tree.root.gui_get_focus_owner() == dock.cards()[-1], "focus-stops-at-last-card")
	_check(visited.size() == dock.cards().size(), "focus-walks-all-cards", "%d / %d" % [visited.size(), dock.cards().size()])
	var focused := _tree.root.gui_get_focus_owner() as ArsenalCard
	await _action(&"ui_accept")
	_check(focused != null and _page.selected() == focused.weapon, "accept-selects")
	var target := _unequipped(Loadout.PRIMARY)
	if target:
		await _select(target)
		dock.card(target.id).grab_focus()
		await _key(KEY_F)
		_check(Loadout.slot(Loadout.PRIMARY) == target.id, "key-F-equips", String(target.id))
	_check(_menu.has_method("_go_back"), "back-available")


## The unlocked weapon of `slot` that is not equipped (null if none).
func _unequipped(slot: int) -> WeaponData:
	for w in Loadout.available(slot):
		if Loadout.slot_of(w.id) < 0:
			return w
	return null


## EQUIP PRIMARY / SECONDARY, EQUIPPED (disabled) and the EQUIPPED tag.
func _check_equip_states() -> void:
	var button := _page.details().equip_button()
	for slot in 2:
		var w := _unequipped(slot)
		if w == null:
			continue
		await _select(w)
		var want := "EQUIP %s" % ("PRIMARY" if slot == 0 else "SECONDARY")
		_check(button.text == want and not button.disabled, "button-%s" % want.to_lower().replace(" ", "-"), button.text)
		_click(_rect(button).get_center())
		await _settle(0.2)
		_check(button.text == "EQUIPPED" and button.disabled, "button-equipped-after-click", button.text)
		_check(Loadout.slot(slot) == w.id and _page.dock().card(w.id).find_child("EquippedTag", true, false).visible, "equipped-tag-%d" % slot)
		var slot_name := _page.sidebar().slots()[slot].find_child("SlotName", true, false) as Label
		_check(slot_name.text == w.display_name.to_upper(), "sidebar-slot-%d" % slot, slot_name.text)
	_check_regions()
	_check_labels()


## Equip, leave the page and come back; then save and reload the profile.
func _check_equip_persists() -> void:
	var w := _unequipped(Loadout.SECONDARY)
	if w == null:
		w = _unequipped(Loadout.PRIMARY)
	if w == null:
		_check(true, "equip-persists", "nothing left to equip in this profile")
		return
	await _select(w)
	_click(_rect(_page.details().equip_button()).get_center())
	await _frames(2)
	_menu._show("title", false)
	await _settle(0.2)
	_menu._show("arsenal", false)
	await _settle(0.3)
	_check(_page.selected() == w and _page.dock().card(w.id).find_child("EquippedTag", true, false).visible, "equip-exit-reenter", String(_page.selected().id))
	var slot := Loadout.slot_for(w)
	var other := Loadout.slot(1 - slot)
	Profile.save_profile()
	Profile.data = {}
	Profile.load_profile()
	_check(Loadout.slot(slot) == w.id and Loadout.slot(1 - slot) == other, "equip-save-reload", "%s / %s" % Loadout.slots())
	var saved := FileAccess.get_file_as_string(Profile.save_path)
	var key := String(Loadout.SLOT_KEYS[slot])
	_check(saved.contains("\"%s\": \"%s\"" % [key, w.id]) or saved.contains("\"%s\":\"%s\"" % [key, w.id]), "equip-on-disk")


## Mastery 0 and max rank (the profile's mastery data is set in this copy).
func _check_mastery_ends() -> void:
	var w := GameData.weapon(Loadout.slot(Loadout.PRIMARY))
	var m: Dictionary = Profile.data["mastery"]
	for xp in [0, 10000000]:
		m[String(w.id)] = {"xp": xp, "kills": 0}
		_page._weapon = null
		await _select(w)
		var rank := (_page.details().find_child("MasteryRank", true, false) as Label).text
		var want := "MASTERY  %d / %d" % [0 if xp == 0 else w.max_rank(), w.max_rank()]
		_check(rank == want, "mastery-%s" % ("zero" if xp == 0 else "max"), rank)
		_check_labels()
		_check_regions()


## The longest name and the longest description.
func _check_long_text() -> void:
	var longest_name := GameData.weapons()[0]
	var longest_role := GameData.weapons()[0]
	for w in GameData.weapons():
		if w.display_name.length() > longest_name.display_name.length():
			longest_name = w
		if w.role.length() > longest_role.role.length():
			longest_role = w
	for w in [longest_name, longest_role]:
		await _select(w)
		await _settle(0.2)
		_check_labels()
		var about := _page.details().find_child("About", true, false) as Label
		var scroll := _page.details().find_child("AboutScroll", true, false) as ScrollContainer
		var reachable: bool = about.text == w.role and scroll.get_v_scroll_bar().max_value >= about.get_minimum_size().y - SLACK
		_check(reachable, "long-text-%s" % w.id, "%d chars" % w.role.length())
		_check_regions()
		var card := _page.dock().card(w.id)
		_check(card.name_fits() or card.tooltip_text.begins_with(w.display_name), "card-name-%s" % w.id)


## Locked weapons: dimmed card with a padlock, the requirement in the tooltip
## and the details, a disabled LOCKED button that does not equip.
func _check_locked() -> void:
	var locked: Array[WeaponData] = []
	for w in GameData.weapons():
		if not GameData.is_weapon_unlocked(w):
			locked.append(w)
	if locked.is_empty():
		_check(true, "locked", "none in this profile")
		return
	var held := Loadout.slots()
	for w in locked:
		await _select(w)
		var button := _page.details().equip_button()
		var card := _page.dock().card(w.id)
		var ok := button.disabled and button.text.begins_with("LOCKED") and card.tooltip_text.contains("Locked:")
		ok = ok and (_page.details().find_child("UnlockNote", true, false) as Label).text.contains(ArsenalStats.unlock_text(w))
		await _key(KEY_F)
		ok = ok and Loadout.slots() == held
		_check(ok, "locked-%s" % w.id, button.text)
	_check_labels()
	_check_regions()
