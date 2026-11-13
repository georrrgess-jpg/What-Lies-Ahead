class_name CoachMarks
extends Control
## First-time menu guidance: when a page is opened for the first time (or the
## guided first deployment is on), one coach mark points at the one control
## that matters there with a single line of text. It never blocks: the ring
## and callout ignore the mouse except for GOT IT, and the mark goes away when
## the page changes or after a while.
##
## Each mark anchors to a named control (ANCHORS: node names first, then a
## button whose text starts with a word, then the first control of a class).
## If none is found the callout sits under the page header without a ring.

const HOLD := 14.0
## page id -> [seen id, text, anchor candidates]
const MARKS := {
	"arsenal": [&"coach_arsenal", "Pick a weapon, then EQUIP it as your primary or secondary.",
		["CoachAnchor", "EquipPrimary", "text:EQUIP", "text:SWAP"]],
	"locker": [&"coach_locker", "Pick a tab, then a card to try it on. Looks only, never power.",
		["CoachAnchor", "LockerTabs", "class:KitTabs"]],
	"shop": [&"coach_shop", "Sparks buy cosmetics here. The featured row is on sale today.",
		["CoachAnchor", "ShopTabs", "class:ItemCard"]],
	"career": [&"coach_career", "Your level track: every level pays Sparks and unlocks something.",
		["CoachAnchor", "LevelTrack", "class:KitTabs"]],
}
## The guided first deployment: home -> PLAY, Play page -> DEPLOY.
const GUIDE := {
	"title": ["Start here: PLAY opens the worlds. Prize Pier is first.", ["PlayButton", "text:PLAY"]],
	"play": ["Your loadout is set. Pick a difficulty, then DEPLOY!", ["DeployButton", "text:DEPLOY"]],
}

var _menu: Node
var _page := ""
var _ring: Panel
var _callout: KitPanel
var _text: Label
var _anchor: Control
var _left := 0.0
var _timer: Timer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	_ring = Panel.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = UiKit.AMBER
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(UiKit.AMBER, 0.45)
	sb.shadow_size = 14
	_ring.add_theme_stylebox_override("panel", sb)
	add_child(_ring)
	_callout = UiKit.neon_panel(UiKit.AMBER)
	_callout.set_padding(20, 12)
	_callout.custom_minimum_size.x = 420
	add_child(_callout)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_M)
	_callout.add_child(row)
	_text = UiKit.body("", 380, UiKit.SIZE_BODY, UiKit.CREAM)
	_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_text)
	var ok := UiKit.sign_button("GOT IT", SignButton.Kind.NEUTRAL, 22)
	ok.name = "CoachGotIt"
	ok.focus_mode = Control.FOCUS_CLICK
	ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_dismiss)
	row.add_child(ok)
	_hide()
	_timer = Timer.new()
	_timer.wait_time = 0.25
	_timer.autostart = true
	_timer.timeout.connect(_poll)
	add_child(_timer)


## Follows `menu` (the MainMenu) and coaches the pages it opens.
func watch(menu: Node) -> void:
	_menu = menu


func _poll() -> void:
	if _menu == null:
		return
	var page := String(_menu.get("_current_page")) if _menu.get("_current_page") != null else ""
	if page != _page:
		_page = page
		_hide()
		_consider(page)
	if _callout.visible:
		_left -= _timer.wait_time
		if _left <= 0.0 or (_anchor != null and not _anchor.is_visible_in_tree()):
			_hide()
		else:
			_place()


func _consider(page: String) -> void:
	if not Onboarding.tips_enabled() or _menu.has_node("FirstRunFlow"):
		return
	var guide := Onboarding.guide_step()
	if GUIDE.has(page) and guide in ["play", "deploy"]:
		_show(GUIDE[page][0], GUIDE[page][1])
		if page == "play":
			Onboarding.set_guide_step("done")
		return
	if MARKS.has(page) and not Onboarding.seen(MARKS[page][0]):
		Onboarding.mark_seen(MARKS[page][0])
		Profile.save_profile()
		_show(MARKS[page][1], MARKS[page][2])


## Looks at the current page again (after the welcome flow closes).
func recheck() -> void:
	_page = ""


## Shows `text` pointing at the first of `anchors` found on the current page.
func show_mark(text: String, anchors: Array) -> void:
	_show(text, anchors)


func _show(text: String, anchors: Array) -> void:
	var root: Node = _menu.call("page", _page) if _menu.has_method("page") else _menu
	_anchor = find_anchor(root if root else _menu, anchors)
	_text.text = text
	_left = HOLD
	_callout.visible = true
	_ring.visible = _anchor != null
	_place()
	UiFx.pop_in(_callout)
	UiSound.toast()


## The first control matching one of `anchors` under `root`: a node name,
## "text:WORD" (a button whose text starts with WORD) or "class:Name".
static func find_anchor(root: Node, anchors: Array) -> Control:
	if root == null:
		return null
	for a in anchors:
		var key := String(a)
		var found: Control = null
		if key.begins_with("text:"):
			found = _find_button(root, key.trim_prefix("text:"))
		elif key.begins_with("class:"):
			found = _find_class(root, key.trim_prefix("class:"))
		else:
			found = root.find_child(key, true, false) as Control
		if found and found.is_visible_in_tree():
			return found
	return null


static func _find_button(node: Node, word: String) -> Control:
	if node is BaseButton and node.get("text") != null and String(node.get("text")).to_upper().begins_with(word) and (node as Control).is_visible_in_tree():
		return node
	for c in node.get_children():
		var f := _find_button(c, word)
		if f:
			return f
	return null


static func _find_class(node: Node, cls: String) -> Control:
	var script := node.get_script() as Script
	if node is Control and script and script.get_global_name() == cls and (node as Control).is_visible_in_tree():
		return node
	for c in node.get_children():
		var f := _find_class(c, cls)
		if f:
			return f
	return null


func _place() -> void:
	var view := get_viewport_rect().size
	if _anchor == null:
		_callout.position = Vector2((view.x - _callout.size.x) * 0.5, MenuPage.TOP_BAR + MenuPage.HEADER + 40.0)
		return
	var r := _anchor.get_global_rect()
	var inv := get_global_transform().affine_inverse()
	r = Rect2(inv * r.position, r.size)
	_ring.position = r.position - Vector2(10, 10)
	_ring.size = r.size + Vector2(20, 20)
	# Callout below the anchor, or above it when there is no room.
	var pos := Vector2(r.position.x, r.end.y + 24.0)
	if pos.y + _callout.size.y > view.y - 20.0:
		pos.y = r.position.y - _callout.size.y - 24.0
	pos.x = clampf(pos.x, 20.0, view.x - _callout.size.x - 20.0)
	_callout.position = pos


func _dismiss() -> void:
	UiSound.click()
	_hide()


func _hide() -> void:
	_callout.visible = false
	_ring.visible = false
	_anchor = null


## True while a mark is showing (for tests).
func showing() -> bool:
	return _callout.visible


## The text of the mark showing now.
func current_text() -> String:
	return _text.text if _callout.visible else ""
