class_name WeaponSlots
extends HBoxContainer
## HUD strip for the two carried weapons, right above the ammo counter: one
## chip per slot with its key and name. The held one is a dark plate outlined
## in its weapon colour; the other is dimmed and shows its own ammo. The held
## chip pops when the player switches.

const DIM := Color(0.62, 0.6, 0.72)

var _weapons: WeaponController
var _rows: Array[PanelContainer] = []
var _keys: Array[Label] = []
var _names: Array[Label] = []
var _ammo: Array[Label] = []
## Per slot: [held plate, stowed plate, held key cap, stowed key cap].
var _boxes: Array[Array] = []
var _active := -1
var _shown_ammo: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(-1, -1)]


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 2:
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.size_flags_vertical = Control.SIZE_SHRINK_END
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)
		var key := UiKit.label(str(i + 1), 22, UiKit.INK, true)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key.custom_minimum_size = Vector2(30, 30)
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		key.add_theme_constant_override("shadow_offset_y", 0)
		h.add_child(key)
		var name_label := UiKit.label("", 26, Color.WHITE, true)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(name_label)
		var ammo := UiKit.label("", 22, UiKit.CREAM, true)
		ammo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(ammo)
		add_child(row)
		_rows.append(row)
		_keys.append(key)
		_names.append(name_label)
		_ammo.append(ammo)
		_boxes.append([_plate(true), _plate(false), UiKit.box(UiKit.CYAN, Color.TRANSPARENT, 8, 0, 0), UiKit.box(DIM, Color.TRANSPARENT, 8, 0, 0)])


func _plate(held: bool) -> StyleBoxFlat:
	var box := UiKit.box(Color(UiKit.INK, 0.86) if held else Color(UiKit.INK, 0.5), UiKit.CYAN if held else Color.TRANSPARENT, 12, 3 if held else 0, 5)
	box.content_margin_left = 7
	box.content_margin_right = 14
	return box


func bind(weapons: WeaponController) -> void:
	_weapons = weapons
	weapons.slots_changed.connect(func(_s, _a): refresh())
	weapons.ammo_changed.connect(func(_m, _r): _refresh_ammo())
	refresh()


## Restyles both chips (slot or active weapon changed).
func refresh() -> void:
	if _weapons == null:
		return
	for i in 2:
		var w := _weapons.slot_weapon(i)
		_rows[i].visible = w != null
		if w == null:
			continue
		var active := i == _weapons.active_slot
		var accent := w.tracer_color
		var plate: StyleBoxFlat = _boxes[i][0 if active else 1]
		var cap: StyleBoxFlat = _boxes[i][2 if active else 3]
		if active:
			plate.border_color = accent
			cap.bg_color = accent
		_rows[i].add_theme_stylebox_override("panel", plate)
		_rows[i].modulate.a = 1.0 if active else 0.8
		_keys[i].add_theme_stylebox_override("normal", cap)
		_names[i].text = w.display_name.to_upper()
		_names[i].add_theme_font_size_override("font_size", 28 if active else 21)
		_names[i].add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.6) if active else Color(1, 1, 1, 0.85))
		# The held weapon's ammo is the big counter; the other shows its own here.
		_ammo[i].visible = not active
		_shown_ammo[i] = Vector2i(-1, -1)
	if _active != _weapons.active_slot:
		if _active >= 0 and is_visible_in_tree():
			UiFx.pulse(_rows[_weapons.active_slot], 1.1)
		_active = _weapons.active_slot
	_refresh_ammo()


## Updates the stowed weapon's ammo text when it changed.
func _refresh_ammo() -> void:
	if _weapons == null:
		return
	for i in 2:
		var w := _weapons.slot_weapon(i)
		if w == null or not _ammo[i].visible:
			continue
		var a := _weapons.ammo_of(w.id)
		if a != _shown_ammo[i]:
			_shown_ammo[i] = a
			_ammo[i].text = "%d/%d" % [a.x, a.y]
