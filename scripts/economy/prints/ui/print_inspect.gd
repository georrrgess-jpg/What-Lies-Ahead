class_name PrintInspect
extends VBoxContainer
## The inspect view of one Prize Print: the print live on a turntable (drag
## to turn), every roll it has (grade and shine, rare print and its odds,
## serial and what makes it special, pattern, mint date, fit, where it came
## from), and what can be done with it: wear it on a weapon (picked with the
## arrows), favourite it (protected from recycling and trade-ups), recycle it
## into Capsule Credits.

## Something about the print changed (worn, favourite, recycled).
signal changed

var print_data: Dictionary = {}
## The details under the case (dimmed while there is no print).
var _info: VBoxContainer
var _weapon_id: StringName
var _glow: ColorRect
var _stage: LockerStage
var _rarity: KitChip
var _title: Label
var _rows := {}
var _weapon_plate: SlotPlate
var _equip: SignButton
var _fav: SignButton
var _recycle: SignButton
var _empty: Label


func _init() -> void:
	add_theme_constant_override("separation", UiKit.GAP_S)
	var frame := UiKit.metal_frame(10)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size.y = 180
	add_child(frame)
	var case := Control.new()
	case.clip_contents = true
	frame.add_child(case)
	_glow = ColorRect.new()
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	case.add_child(_glow)
	_stage = LockerStage.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	case.add_child(_stage)
	_empty = UiKit.body("Open a capsule: your prints show up here.", 0.0, UiKit.SIZE_LABEL, UiKit.MUTED)
	_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	case.add_child(_empty)
	# The details sit on a signboard so they read over the live world.
	var board := UiKit.signboard(14)
	add_child(board)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", UiKit.GAP_S)
	board.add_child(_info)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiKit.GAP_M)
	_info.add_child(head)
	_title = UiKit.sign_label("", 38)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	head.add_child(_title)
	_rarity = UiKit.chip("", UiKit.AMBER, 20)
	_rarity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_rarity)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UiKit.GAP_M)
	grid.add_theme_constant_override("v_separation", 0)
	_info.add_child(grid)
	for key in ["SHINE", "PRINT", "SERIAL", "PATTERN", "MINTED", "FROM"]:
		grid.add_child(UiKit.label(key, UiKit.SIZE_SMALL, UiKit.CYAN, true))
		var value := UiKit.label("", UiKit.SIZE_BODY, UiKit.CREAM)
		grid.add_child(value)
		_rows[key] = value
	var wear := HBoxContainer.new()
	wear.add_theme_constant_override("separation", UiKit.GAP_S)
	_info.add_child(wear)
	var prev := UiKit.icon_button(&"icon_arrow_left", "Previous weapon")
	prev.pressed.connect(_step_weapon.bind(-1))
	wear.add_child(prev)
	_weapon_plate = UiKit.slot_plate("WEAR ON", "")
	_weapon_plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wear.add_child(_weapon_plate)
	var next := UiKit.icon_button(&"icon_arrow_right", "Next weapon")
	next.pressed.connect(_step_weapon.bind(1))
	wear.add_child(next)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", UiKit.GAP_S)
	_info.add_child(actions)
	_equip = UiKit.sign_button("EQUIP", SignButton.Kind.PRIMARY, 24)
	_equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equip.pressed.connect(_on_equip)
	actions.add_child(_equip)
	_fav = UiKit.sign_button("♥ KEEP", SignButton.Kind.NEUTRAL, 24)
	_fav.tooltip_text = "Favourite: protected from recycling and trade-ups."
	_fav.pressed.connect(_on_favourite)
	actions.add_child(_fav)
	_recycle = UiKit.sign_button("RECYCLE", SignButton.Kind.GOLD, 24)
	_recycle.pressed.connect(_on_recycle)
	actions.add_child(_recycle)
	var spot := Shader.new()
	spot.code = """shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.42, 0.2, 0.72, 1.0);
void fragment() {
	vec2 d = (UV - vec2(0.5, 0.6)) * vec2(1.0, 1.3);
	float g = smoothstep(0.8, 0.0, length(d));
	COLOR = vec4(mix(vec3(0.07, 0.05, 0.17), tint.rgb * 0.8, g * g), 1.0);
	COLOR.rgb += tint.rgb * (0.5 + 0.5 * sin(atan(d.y, d.x) * 12.0 + TIME * 0.25)) * g * 0.18;
}"""
	var m := ShaderMaterial.new()
	m.shader = spot
	_glow.material = m
	show_print({})


## Shows `p` (or the empty state for {}). `weapon_id` is the weapon offered to wear it on.
func show_print(p: Dictionary, weapon_id: StringName = &"") -> void:
	print_data = p
	if weapon_id != &"":
		_weapon_id = weapon_id
	if GameData.weapon(_weapon_id) == null:
		_weapon_id = StringName(String(Profile.data.get("last_weapon", "")))
	if GameData.weapon(_weapon_id) == null:
		_weapon_id = GameData.default_weapon_id()
	var has := not p.is_empty()
	_empty.visible = not has
	for c in _info.get_children():
		(c as CanvasItem).modulate.a = 1.0 if has else 0.35
	if not has:
		if _stage.is_node_ready():
			_stage.show_weapon(null, {})
		_title.text = "NO PRINT"
		_rarity.visible = false
		for k in _rows:
			(_rows[k] as Label).text = "-"
		return
	var fin := PrizePrints.finish_of(p)
	var col := PrintLook.rarity_color(p)
	(_glow.material as ShaderMaterial).set_shader_parameter("tint", col)
	_title.text = (fin.display_name if fin else "?").to_upper()
	_rarity.visible = true
	_rarity.set_text(PrintLook.rarity_name(p).to_upper())
	_rarity.set_color(col)
	_rows["SHINE"].text = "%s  ·  %.3f" % [PrintLook.grade_name(p), float(p["shine"])]
	(_rows["SHINE"] as Label).add_theme_color_override("font_color", PrintLook.grade_color(p))
	var v := String(p.get("var", ""))
	_rows["PRINT"].text = "%s  ·  %s" % [PrintLook.variant_name(p), PrintLook.variant_odds(v)] if v != "" else "Standard"
	(_rows["PRINT"] as Label).add_theme_color_override("font_color", PrintLook.variant_color(p) if v != "" else UiKit.CREAM)
	var serial := int(p["serial"])
	var tag := PrintLook.serial_tag(serial)
	_rows["SERIAL"].text = PrintLook.serial_text(serial) + ("  ·  " + tag.capitalize() if tag != "" else "")
	(_rows["SERIAL"] as Label).add_theme_color_override("font_color", UiKit.AMBER if tag != "" else UiKit.CREAM)
	_rows["PATTERN"].text = "Seed %d" % int(p["seed"])
	_rows["MINTED"].text = PrintLook.minted_text(p)
	_rows["FROM"].text = {"capsule": "A Prize Capsule", "tradeup": "A trade-up", "counter": "The Credit Counter"}.get(String(p.get("src", "")), "?")
	_show_on_stage()
	_refresh_actions()


func _show_on_stage() -> void:
	var weapon := GameData.weapon(_weapon_id)
	var loadout := Cosmetics.weapon_loadout(_weapon_id)
	loadout["finish"] = PrizePrints.finish_of(print_data)
	loadout["print"] = print_data
	_stage.show_weapon(weapon, loadout)


func _refresh_actions() -> void:
	var weapon := GameData.weapon(_weapon_id)
	var fits := PrizePrints.fits(print_data, _weapon_id)
	var worn := PrizePrints.equipped(_weapon_id) == print_data
	_weapon_plate.set_value(weapon.display_name.to_upper() if weapon else "")
	var on := PrizePrints.worn_on(print_data)
	_weapon_plate.set_note("Worn on %d weapon%s" % [on.size(), "" if on.size() == 1 else "s"] if not on.is_empty() else ("Fits any weapon" if fits else "Does not fit"))
	_equip.set_text("TAKE OFF" if worn else "EQUIP")
	_equip.disabled = not fits
	var fav := bool(print_data.get("fav", false))
	_fav.set_text("♥ KEPT" if fav else "♡ KEEP")
	_fav.modulate = Color(1.25, 0.9, 1.1) if fav else Color.WHITE
	_recycle.set_text("RECYCLE +%d" % PrizePrints.token_value(print_data))
	_recycle.disabled = not PrizePrints.can_recycle(print_data)
	_recycle.tooltip_text = "" if PrizePrints.can_recycle(print_data) else "Favourites and worn prints are protected."


func _step_weapon(direction: int) -> void:
	var weapons := GameData.weapons()
	var at := weapons.find(GameData.weapon(_weapon_id))
	_weapon_id = weapons[posmod(at + direction, weapons.size())].id
	UiSound.select()
	if not print_data.is_empty():
		_show_on_stage()
		_refresh_actions()


func _on_equip() -> void:
	if print_data.is_empty():
		return
	if PrizePrints.equipped(_weapon_id) == print_data:
		PrizePrints.take_off(_weapon_id)
		Sfx.play(&"cos_unequip", -6.0)
	elif PrizePrints.equip(print_data, _weapon_id):
		UiSound.equip()
	else:
		UiSound.deny()
		return
	_refresh_actions()
	changed.emit()


func _on_favourite() -> void:
	if print_data.is_empty():
		return
	PrizePrints.set_favourite(print_data, not bool(print_data.get("fav", false)))
	UiSound.select()
	_refresh_actions()
	changed.emit()


func _on_recycle() -> void:
	if not PrizePrints.can_recycle(print_data):
		UiSound.deny()
		return
	var p := print_data
	var value := PrizePrints.token_value(p)
	var text := "%s %s becomes %d Capsule Credit%s. This cannot be undone." % [PrintLook.title(p), PrintLook.serial_text(int(p["serial"])), value, "" if value == 1 else "s"]
	UiKit.confirm(self, "RECYCLE THIS PRINT?", text, "RECYCLE", func():
		if PrizePrints.recycle(p) > 0:
			Sfx.play(&"prz_token", -4.0)
			show_print({})
			changed.emit())
