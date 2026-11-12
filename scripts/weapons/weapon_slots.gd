class_name WeaponSlots
extends VBoxContainer
## HUD cards for the two carried weapons, shown beside the ammo counter:
## key, name and ammo per slot, the held one highlighted in its weapon colour.

var _weapons: WeaponController
var _rows: Array[PanelContainer] = []
var _keys: Array[Label] = []
var _names: Array[Label] = []
var _ammo: Array[Label] = []


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 2:
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)
		var key := UiKit.label(str(i + 1), 22, UiKit.INK, true)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key.custom_minimum_size = Vector2(30, 30)
		key.add_theme_constant_override("shadow_offset_y", 0)
		h.add_child(key)
		var name_label := UiKit.label("", 24, Color.WHITE, true)
		name_label.custom_minimum_size = Vector2(230, 0)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(name_label)
		var ammo := UiKit.label("", 22, UiKit.CREAM)
		ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ammo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ammo.custom_minimum_size = Vector2(92, 0)
		h.add_child(ammo)
		add_child(row)
		_rows.append(row)
		_keys.append(key)
		_names.append(name_label)
		_ammo.append(ammo)


func bind(weapons: WeaponController) -> void:
	_weapons = weapons
	weapons.slots_changed.connect(func(_s, _a): refresh())
	weapons.ammo_changed.connect(func(_m, _r): refresh())
	refresh()


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
		var box := UiKit.box(Color(UiKit.NAVY, 0.86) if active else Color(UiKit.INK, 0.5),
			accent if active else Color.TRANSPARENT, 12, 3 if active else 0, 6)
		box.content_margin_left = 8
		box.content_margin_right = 14
		_rows[i].add_theme_stylebox_override("panel", box)
		_rows[i].modulate.a = 1.0 if active else 0.72
		_keys[i].add_theme_stylebox_override("normal", UiKit.box(accent if active else Color(0.62, 0.6, 0.72), Color.TRANSPARENT, 8, 0, 0))
		_names[i].text = w.display_name.to_upper()
		_names[i].add_theme_color_override("font_color", Color.WHITE if active else Color(1, 1, 1, 0.8))
		var a := _weapons.ammo_of(w.id)
		_ammo[i].text = "%d / %d" % [a.x, a.y]
