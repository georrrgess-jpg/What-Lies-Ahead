class_name ArsenalPage
extends MenuPage
## Arsenal: the weapon showroom. Five regions, each in its own box:
##   - the shell's top bar (destinations, level, Sparks, settings);
##   - the left sidebar (ArsenalSidebar): PRIMARY / SECONDARY categories and
##     the two loadout slots;
##   - the preview (ArsenalPreview): the selected weapon's real model on a
##     teal pedestal over the sunset pier; drag to turn it;
##   - the right panel (ArsenalDetails): name, what it does, stats, mastery
##     and the EQUIP button;
##   - the bottom dock (ArsenalDock): the category's weapons as wide cards,
##     a page at a time.
## Browsing and equipping are separate: a card click (or A / Enter on it)
## previews the weapon (cyan outline); only EQUIP (or F / the pad's Y) puts it
## in the loadout (the EQUIPPED tag). A weapon only goes in its own class's
## slot. ArsenalLayout decides the card count and spacing from the window.
##
## Keys: 1 / 2 (pad LB / RB) switch category, the triggers turn the dock's
## pages, F (pad Y) equips, Esc (pad B) goes back.

## The set's Ferris wheel is loaded on a thread before the shell builds the page.
const HEAVY_RESOURCES := [ArsenalShowroom.WHEEL_SCENE]

var _weapon: WeaponData
var _category := Loadout.PRIMARY
var _layout: ArsenalLayout
var _thumbs: WeaponThumbs
var _sidebar: ArsenalSidebar
var _preview: ArsenalPreview
var _details: ArsenalDetails
var _dock: ArsenalDock
var _root: VBoxContainer
var _upper: HBoxContainer
var _backdrop: TextureRect
## Cosmetics changed while the page was away: pictures and the model are redone.
var _look_changed := false
var _trigger_held := 0


func uses_shell_header() -> bool:
	return true


func shows_header_row() -> bool:
	return false


func backdrop() -> Control:
	return _backdrop


func _ready() -> void:
	_thumbs = WeaponThumbs.new()
	add_child(_thumbs)
	_backdrop = _dusk()
	_root = VBoxContainer.new()
	_root.name = "ArsenalRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_upper = HBoxContainer.new()
	_upper.name = "Upper"
	_upper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_upper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_upper)
	_build_regions()
	resized.connect(_apply_layout)
	get_tree().root.size_changed.connect(_apply_layout)
	Cosmetics.equipped_changed.connect(func(_slot: StringName, _weapon_id: StringName): _look_changed = true)
	_apply_layout()


func _build_regions() -> void:
	_sidebar = ArsenalSidebar.new()
	_sidebar.name = "Sidebar"
	_sidebar.category_pressed.connect(_on_category_pressed)
	_sidebar.slot_pressed.connect(_on_slot_pressed)
	_sidebar.back_pressed.connect(func(): back.emit())
	_upper.add_child(_sidebar)
	_preview = ArsenalPreview.new()
	_preview.name = "Preview"
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upper.add_child(_preview)
	_details = ArsenalDetails.new()
	_details.name = "Details"
	_details.equip_pressed.connect(_equip_selected)
	_upper.add_child(_details)
	_dock = ArsenalDock.new()
	_dock.name = "Dock"
	_dock.chosen.connect(_select)
	_root.add_child(_dock)
	_dock.build(Loadout.weapons_for(Loadout.PRIMARY) + Loadout.weapons_for(Loadout.SECONDARY))


## The full-screen layer behind the page: a dusk gradient instead of the live world.
func _dusk() -> TextureRect:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color("2a1a55"), Color("120c2e")])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	var rect := TextureRect.new()
	rect.name = "ArsenalDusk"
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func refresh() -> void:
	if _look_changed and _weapon:
		_preview.rebuild()
	_look_changed = false
	var w := _weapon if _weapon else GameData.weapon(Loadout.slot(_category))
	_weapon = null
	_select(w)
	_refresh_states()
	_apply_layout()
	# The pictures on screen first, then the rest.
	var first: Array[WeaponData] = []
	for c in _dock.visible_cards():
		first.append(c.weapon)
	_thumbs.bake(first)
	_thumbs.bake(GameData.weapons())


func first_focus() -> Control:
	return _dock.card(_weapon.id) if _weapon else null


# --- responsive layout -------------------------------------------------------------

## Re-applies ArsenalLayout's rules for the page's size and the window's scale.
func _apply_layout() -> void:
	if not is_inside_tree() or size.x < 1.0:
		return
	var win := get_tree().root
	var screen_scale := float(win.size.x) / maxf(1.0, win.get_visible_rect().size.x)
	_layout = ArsenalLayout.compute(size, screen_scale)
	_root.add_theme_constant_override("separation", _layout.gap)
	_upper.add_theme_constant_override("separation", _layout.gap)
	_sidebar.custom_minimum_size.x = _layout.sidebar_width
	_sidebar.set_padding(_layout.padding, _layout.padding)
	_sidebar.set_spacing(_layout.gap)
	_details.custom_minimum_size.x = _layout.details_width
	_details.set_padding(_layout.padding, _layout.padding)
	_details.set_stat_columns(_layout.stat_columns)
	_details.set_about_size(_layout.about_size)
	_dock.custom_minimum_size.y = _layout.dock_height
	_dock.set_spacing(_layout.gap, _layout.padding)
	_dock.set_per_page(_layout.cards)
	_dock.set_room(size.x)
	if _weapon:
		_dock.show_weapon(_weapon.id, false)


## The rules in force (for the probe).
func layout() -> ArsenalLayout:
	return _layout


# --- browsing ------------------------------------------------------------------------

## Previews `w`: the card's outline, the details and the model (the screenshot
## launcher calls this too).
func _select(w: WeaponData) -> void:
	if w == null:
		return
	var changed := w != _weapon
	_weapon = w
	var slot := Loadout.slot_for(w)
	if slot != _category or _dock.cards().is_empty():
		_show_category(slot)
	_dock.show_weapon(w.id)
	for c: ArsenalCard in _dock.cards():
		c.selected = c.weapon == w
	_details.show_weapon(w, changed)
	_preview.show_weapon(w)


## Shows category `slot` in the sidebar and the dock (its page with the weapon shown).
func _show_category(slot: int) -> void:
	_category = slot
	_sidebar.set_category(slot)
	var focus_id := _weapon.id if _weapon and Loadout.slot_for(_weapon) == slot else Loadout.slot(slot)
	_dock.show_list(Loadout.weapons_for(slot), focus_id)
	_dock.refresh(_weapon.id if _weapon else &"", _picture)


## A category tab, the 1 / 2 keys or LB / RB: show the category and preview
## the weapon equipped in it (the focus follows if it was on a card).
func _switch_category(slot: int) -> void:
	if slot == _category:
		return
	UiSound.tab()
	var focus := get_viewport().gui_get_focus_owner()
	var on_card := focus is ArsenalCard
	_show_category(slot)
	_select(GameData.weapon(Loadout.slot(slot)))
	if on_card:
		_dock.card(_weapon.id).grab_focus()


func _on_category_pressed(slot: int) -> void:
	if slot == _category:
		_sidebar.set_category(slot)
		return
	_switch_category(slot)


## A loadout slot: preview the weapon in it.
func _on_slot_pressed(slot: int) -> void:
	_select(GameData.weapon(Loadout.slot(slot)))


func _picture(w: WeaponData) -> Texture2D:
	return WeaponThumbs.texture(w)


## Cards (tags, locks, pictures) and the loadout slots, after anything changed.
func _refresh_states() -> void:
	_dock.refresh(_weapon.id if _weapon else &"", _picture)
	_sidebar.refresh(_picture)
	if _weapon:
		_details.refresh_action(_weapon)


# --- equipping ------------------------------------------------------------------------

## Puts the previewed weapon in its class's slot (EQUIP, F, the pad's Y).
func _equip_selected() -> void:
	if _weapon == null:
		return
	var button := _details.equip_button()
	if not GameData.is_weapon_unlocked(_weapon) or Loadout.slot_of(_weapon.id) >= 0:
		UiFx.deny(button)
		return
	var had_focus := button.has_focus()
	if not Loadout.equip(_weapon.id):
		UiFx.deny(button)
		return
	UiSound.equip()
	_refresh_states()
	# EQUIP just went quiet (EQUIPPED): the focus goes back to the card.
	if had_focus:
		_dock.card(_weapon.id).grab_focus()


# --- keys and pad ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or KitDialog.open_count > 0:
		return
	var handled := true
	if event.is_action_pressed("weapon_1"):
		_switch_category(Loadout.PRIMARY)
	elif event.is_action_pressed("weapon_2"):
		_switch_category(Loadout.SECONDARY)
	elif _pad_pressed(event, JOY_BUTTON_LEFT_SHOULDER):
		_switch_category(Loadout.PRIMARY)
	elif _pad_pressed(event, JOY_BUTTON_RIGHT_SHOULDER):
		_switch_category(Loadout.SECONDARY)
	elif _pad_pressed(event, JOY_BUTTON_Y) or _key_pressed(event, KEY_F):
		_equip_selected()
	elif event is InputEventJoypadMotion:
		var step := _trigger_step(event as InputEventJoypadMotion)
		handled = step != 0
		if handled:
			_dock.turn(step)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


static func _pad_pressed(event: InputEvent, button: JoyButton) -> bool:
	var pad := event as InputEventJoypadButton
	return pad != null and pad.pressed and pad.button_index == button


static func _key_pressed(event: InputEvent, key: Key) -> bool:
	var k := event as InputEventKey
	return k != null and k.pressed and not k.echo and k.physical_keycode == key


## -1 / 1 once per pull of the left / right trigger (0 otherwise).
func _trigger_step(event: InputEventJoypadMotion) -> int:
	var side := 0
	if event.axis == JOY_AXIS_TRIGGER_LEFT:
		side = -1
	elif event.axis == JOY_AXIS_TRIGGER_RIGHT:
		side = 1
	if side == 0:
		return 0
	if event.axis_value < 0.3 and _trigger_held == side:
		_trigger_held = 0
	elif event.axis_value > 0.6 and _trigger_held != side:
		_trigger_held = side
		return side
	return 0


# --- for the probe and the screenshot launcher -----------------------------------------------

func preview() -> ArsenalPreview:
	return _preview


func details() -> ArsenalDetails:
	return _details


func dock() -> ArsenalDock:
	return _dock


func sidebar() -> ArsenalSidebar:
	return _sidebar


func selected() -> WeaponData:
	return _weapon


func category() -> int:
	return _category
