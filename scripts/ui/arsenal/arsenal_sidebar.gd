class_name ArsenalSidebar
extends KitPanel
## The Arsenal's left sidebar: the PRIMARY and SECONDARY category tabs (with
## how many of each are unlocked and their key), the two loadout slots (what
## is equipped in each, with its picture; a click shows that weapon) and,
## at the bottom, the BACK sign.

signal category_pressed(slot: int)
signal slot_pressed(slot: int)
signal back_pressed

const TAB_NAMES := ["PRIMARY", "SECONDARY"]
const SLOT_HEIGHT := 118.0

var _tabs: Array[SignButton] = []
var _counts: Array[Label] = []
var _slots: Array[Button] = []
var _slot_names: Array[Label] = []
var _slot_pictures: Array[TextureRect] = []
var _col: VBoxContainer


func _init() -> void:
	kind = Kind.SIGNBOARD
	_style()
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", UiKit.GAP_S)
	add_child(_col)
	var group := ButtonGroup.new()
	for slot in 2:
		_add_tab(slot, group)
	_col.add_child(UiKit.spacer(UiKit.GAP_XS))
	_col.add_child(UiKit.section("LOADOUT"))
	for slot in 2:
		_col.add_child(_slot_button(slot))
	var back := UiKit.back_button()
	back.name = "BackButton"
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_col.add_child(UiKit.spacer(UiKit.GAP_XS))
	back.pressed.connect(func(): back_pressed.emit())
	_col.add_child(back)


func _add_tab(slot: int, group: ButtonGroup) -> void:
	var tab := SignButton.make_tab(TAB_NAMES[slot], group, 26)
	tab.name = "Category%s" % String(Loadout.SLOT_NAMES[slot])
	tab.pressed.connect(func(): category_pressed.emit(slot))
	_col.add_child(tab)
	_tabs.append(tab)
	var count := UiKit.label("", UiKit.SIZE_SMALL, UiKit.MUTED)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	count.clip_text = true
	_col.add_child(count)
	_counts.append(count)


## A loadout slot: caption, picture and name of the equipped weapon.
func _slot_button(slot: int) -> Button:
	var b := Button.new()
	b.name = "Slot%s" % String(Loadout.SLOT_NAMES[slot])
	b.custom_minimum_size.y = SLOT_HEIGHT
	# The slots share the sidebar's spare height (bigger pictures on tall screens).
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	b.clip_contents = true
	b.add_theme_stylebox_override("normal", KitTex.box(&"card"))
	b.add_theme_stylebox_override("hover", KitTex.box(&"card_hover"))
	b.add_theme_stylebox_override("pressed", KitTex.box(&"card_hover"))
	b.add_theme_stylebox_override("focus", KitTex.box(&"focus_ring"))
	b.pressed.connect(func():
		UiSound.click()
		slot_pressed.emit(slot))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var caption := UiKit.label("%s  [%d]" % [String(Loadout.SLOT_NAMES[slot]).to_upper(), slot + 1], 20, UiKit.CYAN, true)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(caption)
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(picture)
	var label := UiKit.sign_label("", 26)
	label.name = "SlotName"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(label)
	_slots.append(b)
	_slot_pictures.append(picture)
	_slot_names.append(label)
	return b


## Lights the tab of the shown category.
func set_category(slot: int) -> void:
	for i in 2:
		_tabs[i].set_pressed_no_signal(i == slot)


## Re-reads the unlocked counts and the loadout; `picture` maps a weapon to its thumbnail.
func refresh(picture: Callable) -> void:
	var held := Loadout.slots()
	for slot in 2:
		_counts[slot].text = "[%d]   %d / %d unlocked" % [slot + 1, Loadout.available(slot).size(), Loadout.weapons_for(slot).size()]
		var w := GameData.weapon(held[slot])
		var text := w.display_name.to_upper() if w else "EMPTY"
		if _slot_names[slot].text != text and is_visible_in_tree():
			UiFx.pulse(_slot_pictures[slot], 1.08)
		_slot_names[slot].text = text
		_slots[slot].tooltip_text = "%s slot: %s" % [Loadout.SLOT_NAMES[slot], w.display_name if w else "empty"]
		_slot_pictures[slot].texture = picture.call(w) if w else null


func tabs() -> Array[SignButton]:
	return _tabs


func slots() -> Array[Button]:
	return _slots


func set_spacing(gap: int) -> void:
	_col.add_theme_constant_override("separation", gap)
