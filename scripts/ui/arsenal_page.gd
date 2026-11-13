class_name ArsenalPage
extends MenuPage
## Arsenal: the selected weapon sits on the stand of a carnival workbench
## booth (a 3D diorama with Prize Pier's Ferris wheel at sunset behind it;
## drag to turn the weapon). Over it: the loadout's two slot plates in the
## header, a signboard with the weapon's name, firing mode and mastery rank,
## its role, six stats computed from WeaponData and the buttons that put it in
## the primary or secondary slot, and a metal tray with every weapon as a
## card (locked ones show what unlocks them).

const CARD_SIZE := Vector2(206, 196)
const THUMB_SIZE := Vector2i(252, 104)
const BOOTH_SCENE := "res://art/models/menu_booth.glb"
const WHEEL_SCENE := "res://art/models/ferris_wheel.glb"
const BLUEPRINT_SHADER := "res://art/shaders/ui_blueprint.gdshader"
## Height of the stand's turntable above the bench (see build_menu_booth.py).
const TURNTABLE_TOP := 0.085
const CAMERA_FROM := Vector3(0.33, 0.5, 2.6)
const CAMERA_TO := Vector3(0.33, 0.22, 0.0)
## The work lamp's bulb (see LAMP in build_menu_booth.py).
const LAMP_AT := Vector3(-0.42, 0.57, -0.3)
## The previewed weapon is scaled to fit this length and height on the stand.
const FIT := Vector2(0.84, 0.35)
## Width of the signboard.
const BOARD_WIDTH := 640.0
## Half size of a cradle pad: along the weapon, across it.
const PAD := Vector2(0.035, 0.055)
## Stats on the signboard, three per column: [label, getter].
const STATS := [
	["DPS", "_stat_dps"],
	["BURST", "_stat_burst"],
	["RANGE", "_stat_range"],
	["HANDLING", "_stat_handling"],
	["MOBILITY", "_stat_mobility"],
	["MAGAZINE", "_stat_magazine"],
]

var _weapon: WeaponData
var _cards := {}
var _thumbs: Array[SubViewport] = []
## Card thumbnail pivots by weapon id (rebuilt when cosmetics change).
var _thumb_pivots := {}
var _thumb_textures := {}
var _name: Label
var _chip: KitChip
var _role: Label
var _traits: HBoxContainer
var _stat_rows: Array[StatRow] = []
var _rank_label: Label
var _rank_bar: ProgressBar
var _lock_note: Label
var _swap: SignButton
var _equip_row: HBoxContainer
var _equip: Array[SignButton] = []
var _plates: Array[SlotPlate] = []
var _plate_row: HBoxContainer
var _board: KitPanel
# The diorama.
var _stage_view: SubViewportContainer
var _viewport: SubViewport
var _turntable: Node3D
var _pivot: Node3D
var _model: Node3D
var _ring: MeshInstance3D
var _forks: Array[Node3D] = []
var _collars: Array[Node3D] = []
var _screen_material: ShaderMaterial
## Where each weapon sits on the stand, by weapon id (see _seat_on_stand).
var _seats := {}
## The weapon rests with its muzzle to the left, turned a little to the camera.
var _yaw := PI
var _hold := 0.0
var _time := 0.0


func uses_shell_header() -> bool:
	return true


func header_extra() -> Control:
	return _plate_row


func backdrop() -> Control:
	return _stage_view


func _ready() -> void:
	_build_stage()
	_build_plates()
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", UiKit.GAP_M)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var top := HBoxContainer.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	top.add_child(_build_drag_area())
	top.add_child(_build_board())
	col.add_child(_build_tray())
	visibility_changed.connect(func(): set_process(is_visible_in_tree()))
	set_process(false)
	_select(GameData.weapon(Loadout.primary()))


func _process(delta: float) -> void:
	_time += delta
	# The weapon sways on the turntable; a drag turns it and holds it a moment.
	_hold = maxf(0.0, _hold - delta)
	var target := _yaw if _hold > 0.0 else _yaw + sin(_time * 0.45) * 0.32
	_turntable.rotation.y = lerp_angle(_turntable.rotation.y, target, minf(1.0, delta * 6.0))


func refresh() -> void:
	# Skins may have changed in the Locker since the cards were drawn.
	for id in _thumb_pivots:
		_fill_thumb(_thumb_pivots[id], GameData.weapon(id))
	for t in _thumbs:
		t.render_target_update_mode = SubViewport.UPDATE_ONCE
	_select(_weapon if _weapon else GameData.weapon(Loadout.primary()))
	UiFx.stagger_in(_cards.values())
	UiFx.pop_in(_board, 0.05, 0.94)


func first_focus() -> Control:
	return _cards.get(_weapon.id) if _weapon else null


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or KitDialog.open_count > 0:
		return
	for slot in 2:
		if event.is_action_pressed("weapon_%d" % (slot + 1)):
			_equip_slot(slot)
			get_viewport().set_input_as_handled()


# --- layout ----------------------------------------------------------------------

## The loadout's two plates, shown by the shell to the right of the marquee.
func _build_plates() -> void:
	_plate_row = HBoxContainer.new()
	_plate_row.alignment = BoxContainer.ALIGNMENT_END
	_plate_row.add_theme_constant_override("separation", UiKit.GAP_L)
	for slot in 2:
		var plate := UiKit.slot_plate("%s  [%d]" % [String(Loadout.SLOT_NAMES[slot]).to_upper(), slot + 1], "")
		plate.custom_minimum_size.x = 430
		_plate_row.add_child(plate)
		_plates.append(plate)


## The open area over the diorama: dragging it turns the weapon.
func _build_drag_area() -> Control:
	var area := Control.new()
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.mouse_default_cursor_shape = Control.CURSOR_DRAG
	area.gui_input.connect(_on_drag_input)
	var hint := UiKit.key_prompt("LMB", "Drag to turn")
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_right = -UiKit.GAP_L
	hint.modulate.a = 0.85
	area.add_child(hint)
	return area


func _on_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		_yaw += (event as InputEventMouseMotion).relative.x * 0.008
		_hold = 2.5


func _build_board() -> Control:
	_board = UiKit.signboard()
	_board.custom_minimum_size.x = BOARD_WIDTH
	_board.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiKit.GAP_S)
	_board.add_child(v)
	_name = UiKit.sign_label("", 56)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_name)
	_chip = UiKit.chip("", UiKit.CYAN, 26)
	v.add_child(_chip)
	_role = UiKit.body("", BOARD_WIDTH - 90.0, UiKit.SIZE_BODY)
	_role.max_lines_visible = 2
	_role.add_theme_constant_override("line_spacing", -6)
	_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_role.mouse_filter = Control.MOUSE_FILTER_STOP
	v.add_child(_role)
	_traits = HBoxContainer.new()
	_traits.alignment = BoxContainer.ALIGNMENT_CENTER
	_traits.add_theme_constant_override("separation", UiKit.GAP_S)
	v.add_child(_traits)
	v.add_child(_rule())
	v.add_child(_build_stats())
	v.add_child(_rule())
	v.add_child(_build_mastery())
	_lock_note = UiKit.label("", UiKit.SIZE_LABEL, UiKit.AMBER, true)
	_lock_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_lock_note)
	_swap = UiKit.sign_button("SWAP SLOTS", SignButton.Kind.PRIMARY, 44)
	_swap.custom_minimum_size.y = 78
	_swap.pressed.connect(_swap_slots)
	v.add_child(_swap)
	_equip_row = HBoxContainer.new()
	_equip_row.add_theme_constant_override("separation", UiKit.GAP_M)
	v.add_child(_equip_row)
	for slot in 2:
		var b := UiKit.sign_button("EQUIP %s" % String(Loadout.SLOT_NAMES[slot]).to_upper(), SignButton.Kind.PRIMARY if slot == 0 else SignButton.Kind.SECONDARY, 25)
		b.custom_minimum_size.y = 78
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_equip_slot.bind(slot))
		_equip_row.add_child(b)
		_equip.append(b)
	return _board


func _rule() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(UiKit.CREAM, 0.35)
	line.custom_minimum_size.y = 2
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## Six stats in two columns with a divider between them.
func _build_stats() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_L)
	for column in 2:
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		for i in 3:
			var stat := UiKit.stat_row(STATS[column * 3 + i][0])
			v.add_child(stat)
			_stat_rows.append(stat)
		row.add_child(v)
		if column == 0:
			var divider := _rule()
			divider.custom_minimum_size = Vector2(2, 0)
			row.add_child(divider)
	return row


func _build_mastery() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_M)
	_rank_label = UiKit.label("", 22, UiKit.AMBER, true)
	row.add_child(_rank_label)
	_rank_bar = UiKit.progress(0.0, 14.0, UiKit.AMBER)
	_rank_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rank_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_rank_bar)
	return row


## The riveted tray along the bottom with every weapon as a card.
func _build_tray() -> Control:
	var tray := UiKit.metal_frame()
	tray.set_padding(36, 32)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_S)
	tray.add_child(row)
	var group := ButtonGroup.new()
	for w in GameData.weapons():
		var card := UiKit.item_card(w.display_name.to_upper(), CARD_SIZE)
		card.button_group = group
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(_select.bind(w))
		_thumb_textures[w.id] = _thumbnail(w, card)
		card.set_image(_thumb_textures[w.id])
		row.add_child(card)
		_cards[w.id] = card
	return tray


## A small one-shot render of the weapon for its card.
func _thumbnail(w: WeaponData, holder: Node) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = THUMB_SIZE * 2
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	holder.add_child(vp)
	_add_lights(vp)
	var pivot := Node3D.new()
	vp.add_child(pivot)
	_thumb_pivots[w.id] = pivot
	_fill_thumb(pivot, w)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.02, 1.25)
	cam.fov = 26.0
	vp.add_child(cam)
	_thumbs.append(vp)
	return vp.get_texture()


## Puts a fresh model of `w` (with its equipped cosmetics) in a card's pivot.
func _fill_thumb(pivot: Node3D, w: WeaponData) -> void:
	for c in pivot.get_children():
		c.queue_free()
	var model := _weapon_model(w)
	if model == null:
		return
	var bounds := _bounds(model)
	model.position = -bounds.get_center()
	pivot.add_child(model)
	# Side-on, slightly from above, filling the card.
	pivot.rotation_degrees = Vector3(8, 82, 0)
	pivot.scale = Vector3.ONE * (1.0 / maxf(0.01, maxf(bounds.size.z, bounds.size.y * 2.2)))


func _add_lights(vp: SubViewport) -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	key.light_energy = 1.4
	key.light_color = Color(1.0, 0.93, 0.85)
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -140, 0)
	fill.light_energy = 0.7
	fill.light_color = Color(0.75, 0.6, 1.0)
	vp.add_child(fill)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.65, 0.95)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)


# --- the diorama -------------------------------------------------------------------

## The booth scene in its own viewport: sunset sky, the booth model, the
## Ferris wheel far behind, the sea, warm lamp light and the stand's moving parts.
func _build_stage() -> void:
	_stage_view = SubViewportContainer.new()
	_stage_view.stretch = true
	_stage_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_stage_view.add_child(_viewport)
	_add_stage_environment()
	_add_stage_lights()
	var booth := _instance(BOOTH_SCENE)
	if booth:
		_viewport.add_child(booth)
		_take_stand_parts(booth)
	_add_scenery()
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.far = 400.0
	cam.transform = Transform3D(Basis.IDENTITY, CAMERA_FROM).looking_at(CAMERA_TO, Vector3.UP)
	_viewport.add_child(cam)
	_turntable = Node3D.new()
	_viewport.add_child(_turntable)
	_pivot = Node3D.new()
	_turntable.add_child(_pivot)
	for part: Node3D in _forks + _collars:
		part.get_parent().remove_child(part)
		_turntable.add_child(part)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.262
	torus.outer_radius = 0.278
	torus.rings = 48
	torus.ring_segments = 6
	_ring.mesh = torus
	_ring.position.y = TURNTABLE_TOP
	_viewport.add_child(_ring)


static func _instance(path: String) -> Node3D:
	return (load(path) as PackedScene).instantiate() as Node3D if ResourceLoader.exists(path) else null


func _add_stage_environment() -> void:
	# Dusk: deep violet overhead falling to a coral horizon.
	var dusk := ProceduralSkyMaterial.new()
	dusk.sky_top_color = Color("2a1d63")
	dusk.sky_horizon_color = Color("f47f86")
	dusk.sky_curve = 0.09
	dusk.ground_horizon_color = Color("a8507e")
	dusk.ground_bottom_color = Color("1a1238")
	dusk.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = dusk
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.36, 0.8)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)


## A low pink sun from behind, the work lamp (the only shadow caster) and a
## cool fill from the camera side.
func _add_stage_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-18, -150, 0)
	sun.light_energy = 0.45
	sun.light_color = Color(1.0, 0.62, 0.55)
	_viewport.add_child(sun)
	var lamp := SpotLight3D.new()
	lamp.transform = Transform3D(Basis.IDENTITY, LAMP_AT).looking_at(Vector3(0.0, 0.1, 0.05), Vector3.UP)
	lamp.spot_range = 3.0
	lamp.spot_angle = 58.0
	lamp.spot_angle_attenuation = 0.7
	lamp.light_energy = 2.0
	lamp.light_color = Color(1.0, 0.82, 0.55)
	lamp.shadow_enabled = true
	_viewport.add_child(lamp)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-0.2, 0.8, 1.9)
	fill.omni_range = 6.0
	fill.light_energy = 0.6
	fill.light_color = Color(0.6, 0.75, 1.0)
	_viewport.add_child(fill)


## Pulls the stand's moving parts out of the booth model: the fork and collar
## become two of each on the turntable; the monitor gets its blueprint shader.
func _take_stand_parts(booth: Node3D) -> void:
	var fork := booth.find_child("StandFork", true, false) as Node3D
	var collar := booth.find_child("StandCollar", true, false) as Node3D
	if fork and collar:
		_forks = [fork, fork.duplicate() as Node3D]
		_collars = [collar, collar.duplicate() as Node3D]
		fork.get_parent().add_child(_forks[1])
		collar.get_parent().add_child(_collars[1])
	var screen := booth.find_child("BlueprintScreen", true, false) as MeshInstance3D
	if screen and ResourceLoader.exists(BLUEPRINT_SHADER):
		_screen_material = ShaderMaterial.new()
		_screen_material.shader = load(BLUEPRINT_SHADER)
		_screen_material.set_shader_parameter("thumb_aspect", float(THUMB_SIZE.x) / THUMB_SIZE.y)
		var screen_size := screen.mesh.get_aabb().size
		_screen_material.set_shader_parameter("screen_size", Vector2(screen_size.x, screen_size.y))
		screen.material_override = _screen_material
	var gull := booth.find_child("Gull", true, false) as Node3D
	if gull:
		gull.position = Vector3(1.3, 0.215, -7.0)


## The sea and the Ferris wheel on the horizon.
func _add_scenery() -> void:
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	sea.mesh = plane
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("3b2a6b")
	water.roughness = 0.3
	water.metallic = 0.4
	sea.material_override = water
	sea.position = Vector3(0, -3.4, -200)
	_viewport.add_child(sea)
	var wheel := _instance(WHEEL_SCENE)
	if wheel:
		wheel.set_script(load("res://scripts/props/ferris_wheel.gd"))
		wheel.position = Vector3(2.2, -4.3, -62.0)
		wheel.scale = Vector3.ONE * 0.33
		wheel.rotation_degrees.y = -12.0
		_viewport.add_child(wheel)


# --- selection ---------------------------------------------------------------------

func _select(w: WeaponData) -> void:
	if w == null:
		return
	var changed := w != _weapon
	_weapon = w
	var unlocked := GameData.is_weapon_unlocked(w)
	(_cards[w.id] as ItemCard).selected = true
	_fit_name(w.display_name.to_upper())
	var rank := Mastery.rank(w.id)
	var tags := _trait_tags(w)
	_chip.set_text("%s  ·  %s" % [tags[0] if not tags.is_empty() else w.category.to_upper(), UiKit.rank_name(rank, w.max_rank())])
	_chip.set_color(w.tracer_color.lerp(Color.WHITE, 0.25))
	_role.text = w.role.get_slice(".", 0)
	_role.tooltip_text = w.role
	_fill_traits(tags, w)
	for i in STATS.size():
		_stat_rows[i].set_value(String(call(STATS[i][1], w)[1]))
	_rank_label.text = "MASTERY  %d / %d" % [rank, w.max_rank()]
	_rank_bar.value = Mastery.rank_progress(w.id) if rank < w.max_rank() else 1.0
	_lock_note.visible = not unlocked
	if not unlocked:
		_lock_note.text = "LOCKED  ·  %s" % (w.unlock.describe() if w.unlock else "")
	var slot := Loadout.slot_of(w.id)
	_swap.visible = unlocked and slot >= 0
	_equip_row.visible = unlocked and slot < 0
	_refresh_cards()
	_refresh_loadout()
	_link_focus()
	_build_preview_model()
	_seat_on_stand()
	if _screen_material:
		_screen_material.set_shader_parameter("thumb", _thumb_textures[w.id])
	if changed and is_visible_in_tree():
		UiFx.pop_in(_name, 0.0, 0.9)


## Up from any card in the tray reaches the signboard's action, and down
## from it returns to the selected card.
func _link_focus() -> void:
	var action: Control = _swap if _swap.visible else (_equip[0] if _equip_row.visible else null)
	var card: Control = _cards[_weapon.id]
	for id in _cards:
		var c: Control = _cards[id]
		c.focus_neighbor_top = c.get_path_to(action) if action and c.is_inside_tree() else NodePath()
	for b: Control in [_swap, _equip[0], _equip[1]]:
		b.focus_neighbor_bottom = b.get_path_to(card) if b.is_inside_tree() else NodePath()


## The name in the biggest size that fits the board.
func _fit_name(text: String) -> void:
	var font_size := 56
	var room := BOARD_WIDTH - 90.0
	while font_size > 34 and UiKit.display_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
		font_size -= 2
	_name.text = text
	_name.add_theme_font_size_override("font_size", font_size)


func _equip_slot(slot: int) -> void:
	if _weapon == null or Loadout.slot_of(_weapon.id) == slot:
		return
	if Loadout.set_slot(slot, _weapon.id):
		UiSound.equip()
		_select(_weapon)
		UiFx.pulse(_plates[slot], 1.06)
		# The EQUIP buttons just gave way to SWAP SLOTS: keep the focus on the board.
		if _swap.is_visible_in_tree():
			_swap.grab_focus()
	else:
		UiFx.deny(_board)


## The selected weapon changes places with the one in the other slot.
func _swap_slots() -> void:
	var slot := Loadout.slot_of(_weapon.id) if _weapon else -1
	if slot >= 0:
		_equip_slot(1 - slot)


func _refresh_cards() -> void:
	for id in _cards:
		var w := GameData.weapon(id)
		var card: ItemCard = _cards[id]
		if GameData.is_weapon_unlocked(w):
			card.set_status("")
		else:
			card.set_locked(_short_lock(w))
		var slot := Loadout.slot_of(w.id)
		card.set_tag("" if slot < 0 else ("1ST" if slot == Loadout.PRIMARY else "2ND"), UiKit.CYAN if slot == Loadout.PRIMARY else UiKit.CREAM)


## "Lv 5" for a player-level lock, else the requirement's own text.
func _short_lock(w: WeaponData) -> String:
	if w.unlock == null:
		return "Locked"
	if w.unlock.kind == Requirement.Kind.PLAYER_LEVEL and w.unlock.all_of.is_empty():
		return "Lv %d" % w.unlock.amount
	return w.unlock.describe()


func _refresh_loadout() -> void:
	var selected_slot := Loadout.slot_of(_weapon.id) if _weapon else -1
	for slot in 2:
		var w := GameData.weapon(Loadout.slot(slot))
		_plates[slot].set_value(w.display_name.to_upper() if w else "EMPTY")
		_plates[slot].active = slot == selected_slot


## Short tags for how the weapon fires and what its shots do.
func _trait_tags(w: WeaponData) -> Array[String]:
	var tags: Array[String] = []
	if w.charge_time <= 0.0:
		tags.append("AUTO" if w.automatic or w.beam else "SEMI")
	if w.burst_count > 1:
		tags.append("BURST ×%d" % w.burst_count)
	if w.charge_time > 0.0:
		tags.append("CHARGE %.1fs" % w.charge_time)
	if w.beam:
		tags.append("BEAM")
	if w.pellets > 1:
		tags.append("%d PELLETS" % w.pellets)
	if w.pierce > 0:
		tags.append("PIERCES %d" % w.pierce)
	if w.chain_count > 0:
		tags.append("CHAINS ×%d" % w.chain_count)
	if w.seek_cone_degrees > 0.0:
		tags.append("SEEKING")
	if w.splash_radius > 0.0:
		tags.append("BLAST %.1f m" % w.splash_radius)
	if w.projectile_speed > 0.0 and w.projectile_gravity > 0.0:
		tags.append("LOBBED")
	match w.status_effect:
		&"chill":
			tags.append("FREEZES")
		&"shock":
			tags.append("SHOCKS")
	if w.uses_heat():
		tags.append("HEAT")
	return tags


## The tags after the first (which is on the chip) as small pills.
func _fill_traits(tags: Array[String], w: WeaponData) -> void:
	for c in _traits.get_children():
		_traits.remove_child(c)
		c.queue_free()
	_traits.visible = tags.size() > 1
	for i in range(1, mini(tags.size(), 4)):
		_traits.add_child(UiKit.chip(tags[i], w.tracer_color.lerp(UiKit.INK, 0.72), 18, false))


# --- stats: [value, text] -------------------------------------------------------------

## Sustained single-target damage per second at the real fire rate, reloads
## (or overheat vents) included, so a big magazine and a fast reload count.
func _stat_dps(w: WeaponData) -> Array:
	return [w.damage_per_second(), "%d" % roundi(w.damage_per_second())]


## Damage of one trigger pull: a whole burst, every pellet, a full charge.
func _stat_burst(w: WeaponData) -> Array:
	return [w.burst_damage(), "%d" % roundi(w.burst_damage())]


func _stat_range(w: WeaponData) -> Array:
	return [w.effective_range(), "%d m" % roundi(w.effective_range())]


## Aiming, reloading and switching speed, 0-1.
func _stat_handling(w: WeaponData) -> Array:
	var ads := inverse_lerp(0.26, 0.1, w.ads_time)
	var reload := inverse_lerp(2.6, 1.1, w.reload_time)
	var equip := inverse_lerp(0.5, 0.2, w.equip_time)
	var k := clampf((ads + reload + equip) / 3.0, 0.0, 1.0)
	return [k, "%d" % roundi(k * 100.0)]


func _stat_mobility(w: WeaponData) -> Array:
	var k := clampf(inverse_lerp(0.8, 1.0, w.move_speed_scale), 0.0, 1.0)
	return [k, "%d%%" % roundi(w.move_speed_scale * 100.0)]


## Magazine size on a square-root scale (a 6-round rail and a 50-tick beam both read).
func _stat_magazine(w: WeaponData) -> Array:
	var text := "%d" % w.magazine_size
	if w.uses_heat():
		text = "%.0fs" % (w.magazine_size * w.fire_interval)
	return [sqrt(w.magazine_size / 50.0), text]


# --- preview --------------------------------------------------------------------------

func _build_preview_model() -> void:
	if _model:
		_model.queue_free()
		_model = null
	_model = _weapon_model(_weapon)
	if _model == null:
		return
	_pivot.add_child(_model)
	var bounds := _bounds(_model)
	_model.position = -bounds.get_center()
	var largest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	_pivot.scale = Vector3.ONE * (0.74 / maxf(0.01, largest))
	# Start side-on (the side the player sees), then keep turning.
	_pivot.rotation = Vector3(0, deg_to_rad(-75), 0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = _weapon.tracer_color
	_ring.material_override = m
	if not GameData.is_weapon_unlocked(_weapon):
		_tint_locked(_model)


## Rests the previewed weapon on the stand: lifts it clear of the turntable
## and raises the two cradle forks until their pads touch its underside, so
## nothing floats and nothing cuts into the model. Worked out once per weapon
## from the model's triangles.
func _seat_on_stand() -> void:
	if _model == null or _forks.is_empty():
		for part: Node3D in _forks + _collars:
			part.visible = false
		return
	_fit_to_stand()
	if not _seats.has(_weapon.id):
		_pivot.position = Vector3.ZERO
		_seats[_weapon.id] = _measure_seat()
	var seat: Dictionary = _seats[_weapon.id]
	_pivot.position = Vector3(0.0, seat["lift"], 0.0)
	var along: Vector3 = seat["along"]
	for i in 2:
		var height: float = seat["pads"][i]
		_forks[i].visible = height > -INF
		_collars[i].visible = height > -INF
		_forks[i].position = along * seat["stations"][i] + Vector3(0.0, height, 0.0)
		_forks[i].rotation = Vector3(0.0, atan2(-along.z, along.x), 0.0)
		_collars[i].position = along * seat["stations"][i] + Vector3(0.0, TURNTABLE_TOP, 0.0)


## Sizes the preview for the stand: every weapon fits the same length and
## height, so a pistol stays smaller than a rifle instead of filling the booth.
func _fit_to_stand() -> void:
	var extent := _bounds(_model).size
	_pivot.scale = Vector3.ONE * minf(FIT.x / maxf(0.01, extent.z), FIT.y / maxf(0.01, extent.y))


## Where the weapon rests: {lift, along, stations[2], pads[2]} in turntable
## space. `along` is the weapon's long axis; a pad height of -INF means the
## weapon has nothing over that fork.
func _measure_seat() -> Dictionary:
	var along := (_pivot.basis * _model.basis * Vector3.FORWARD)
	along.y = 0.0
	along = along.normalized() if along.length() > 0.001 else Vector3.RIGHT
	var across := Vector3(-along.z, 0.0, along.x)
	# Every triangle corner as (along, across, height).
	var corners := PackedVector3Array()
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not _shown(m):
			continue
		var xf := _pivot.transform * _relative(_pivot, m)
		for v in m.mesh.get_faces():
			var p := xf * v
			corners.append(Vector3(p.dot(along), p.dot(across), p.y))
	var low := INF
	var near := INF
	var far := -INF
	for c in corners:
		low = minf(low, c.z)
		near = minf(near, c.x)
		far = maxf(far, c.x)
	var stations := [lerpf(near, far, 0.27), lerpf(near, far, 0.73)]
	var pads := [_underside(corners, stations[0]), _underside(corners, stations[1])]
	# Clear the turntable, and leave the forks room for their yokes and collars.
	var lift := TURNTABLE_TOP + 0.04 - low
	for pad: float in pads:
		if pad < INF:
			lift = maxf(lift, TURNTABLE_TOP + 0.09 - pad)
	for i in 2:
		pads[i] = pads[i] + lift if pads[i] < INF else -INF
	return {"lift": lift, "along": along, "stations": stations, "pads": pads}


## The lowest point of the model over a cradle pad centred at `station`
## along the weapon (INF if nothing is above the pad). Samples a grid of
## points across the pad against every triangle that overlaps it.
func _underside(corners: PackedVector3Array, station: float) -> float:
	var lowest := INF
	for t in range(0, corners.size(), 3):
		var a := corners[t]
		var b := corners[t + 1]
		var c := corners[t + 2]
		if maxf(a.x, maxf(b.x, c.x)) < station - PAD.x or minf(a.x, minf(b.x, c.x)) > station + PAD.x:
			continue
		if maxf(a.y, maxf(b.y, c.y)) < -PAD.y or minf(a.y, minf(b.y, c.y)) > PAD.y:
			continue
		for corner: Vector3 in [a, b, c]:
			if absf(corner.x - station) <= PAD.x and absf(corner.y) <= PAD.y:
				lowest = minf(lowest, corner.z)
		var det := (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
		if absf(det) < 1e-9:
			continue
		for ix in 5:
			var px := station + PAD.x * (ix - 2) * 0.5
			for iy in 7:
				var py := PAD.y * (iy - 3) / 3.0
				var wa := ((b.y - c.y) * (px - c.x) + (c.x - b.x) * (py - c.y)) / det
				var wb := ((c.y - a.y) * (px - c.x) + (a.x - c.x) * (py - c.y)) / det
				var wc := 1.0 - wa - wb
				if wa >= 0.0 and wb >= 0.0 and wc >= 0.0:
					lowest = minf(lowest, wa * a.z + wb * b.z + wc * c.z)
	return lowest


## True when `node` and everything between it and the preview pivot is visible.
func _shown(node: Node3D) -> bool:
	var n: Node = node
	while n and n != _pivot:
		if n is Node3D and not (n as Node3D).visible:
			return false
		n = n.get_parent()
	return true


## The viewmodel without arms, with the weapon's equipped cosmetics.
func _weapon_model(w: WeaponData) -> Node3D:
	if w == null or w.viewmodel == null:
		return null
	var model: Node3D = w.viewmodel.instantiate()
	for part_name in ["ArmL", "ArmR"]:
		var part := model.find_child(part_name, true, false) as Node3D
		if part:
			part.visible = false
	for holo in model.find_children("*Holo", "Node3D", true, false):
		(holo as Node3D).visible = false
	WeaponCosmetics.apply(model, w, Cosmetics.weapon_loadout(w.id))
	return model


## Locked weapons preview as a dark silhouette with a faint rim.
func _tint_locked(node: Node) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.13, 0.26)
	m.rim_enabled = true
	m.rim = 0.6
	m.roughness = 0.8
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m


func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.visible or m.mesh == null:
			continue
		var xf := _relative(node, m)
		var box := xf * m.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


## `child`'s transform in `root`'s space (works before the nodes enter the tree).
func _relative(root: Node3D, child: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = child
	while n and n != root:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
