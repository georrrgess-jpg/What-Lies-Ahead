class_name ArsenalPage
extends MenuPage
## Arsenal: every weapon in a grid (locked ones show what unlocks them), a
## large turntable preview with the weapon's equipped cosmetics, stat bars
## computed from WeaponData, its role, traits and mastery rank, and buttons
## to put it in the primary or secondary slot of the Loadout.

const CARD_SIZE := Vector2(268, 172)
const THUMB_SIZE := Vector2i(252, 104)
## Stat bars: [label, getter, max]. Values above max fill the bar.
const STATS := [
	["Damage / sec", "_stat_dps", 260.0],
	["Burst damage", "_stat_burst", 260.0],
	["Range", "_stat_range", 60.0],
	["Handling", "_stat_handling", 1.0],
	["Mobility", "_stat_mobility", 1.0],
	["Magazine", "_stat_magazine", 1.0],
]

var _weapon: WeaponData
var _cards := {}
var _thumbs: Array[SubViewport] = []
## Card thumbnail pivots by weapon id (rebuilt when cosmetics change).
var _thumb_pivots := {}
var _name: Label
var _category: Label
var _rank: Label
var _rank_bar: ProgressBar
var _role: Label
var _traits: HFlowContainer
var _stat_bars: Array[ProgressBar] = []
var _stat_values: Array[Label] = []
var _lock_note: Label
var _equip: Array[Button] = []
var _loadout_cards: Array[PanelContainer] = []
var _viewport: SubViewport
var _pivot: Node3D
var _model: Node3D
var _ring: MeshInstance3D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.custom_minimum_size = Vector2(1740, 0)
	panel.add_child(col)
	col.add_child(_build_head())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 26)
	col.add_child(body)
	body.add_child(_build_grid())
	body.add_child(_build_preview())
	body.add_child(_build_info())
	_select(GameData.weapon(Loadout.primary()))


func _process(delta: float) -> void:
	if visible and _pivot:
		_pivot.rotate_y(delta * 0.55)


func refresh() -> void:
	# Skins may have changed in the Locker since the cards were drawn.
	for id in _thumb_pivots:
		_fill_thumb(_thumb_pivots[id], GameData.weapon(id))
	for t in _thumbs:
		t.render_target_update_mode = SubViewport.UPDATE_ONCE
	_select(_weapon if _weapon else GameData.weapon(Loadout.primary()))


# --- layout ----------------------------------------------------------------------

func _build_head() -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	var title := UiKit.label("ARSENAL", 64, UiKit.AMBER, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	for slot in 2:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(390, 0)
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(card)
		_loadout_cards.append(card)
	var back_button := UiKit.soft_button("Back", 30)
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(func(): back.emit())
	head.add_child(back_button)
	return head


func _build_grid() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(CARD_SIZE.x * 2 + 30, 780)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	var group := ButtonGroup.new()
	for w in GameData.weapons():
		var card := _weapon_card(w, group)
		grid.add_child(card)
		_cards[w.id] = card
		if w == GameData.weapons()[0]:
			card.name = "FirstFocus"
	return scroll


func _weapon_card(w: WeaponData, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = group
	b.custom_minimum_size = CARD_SIZE
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(_select.bind(w))
	b.mouse_entered.connect(func(): Sfx.play(&"ui_hover", -14.0))
	b.pressed.connect(func(): Sfx.play(&"ui_click", -6.0))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	v.add_theme_constant_override("separation", -2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var thumb := TextureRect.new()
	thumb.name = "Thumb"
	thumb.custom_minimum_size = Vector2(THUMB_SIZE)
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.texture = _thumbnail(w, b)
	v.add_child(thumb)
	var name_label := UiKit.label(w.display_name.to_upper(), 24, Color.WHITE, true)
	name_label.name = "Name"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(name_label)
	var sub := UiKit.label("", 19, UiKit.CREAM)
	sub.name = "Sub"
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(sub)
	var badge := UiKit.label("", 18, UiKit.INK, true)
	badge.name = "Badge"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_constant_override("shadow_offset_y", 0)
	badge.position = Vector2(CARD_SIZE.x - 64, 8)
	badge.custom_minimum_size = Vector2(54, 26)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(badge)
	return b


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


func _build_preview() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.custom_minimum_size = Vector2(640, 520)
	v.add_child(holder)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	holder.add_child(_viewport)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.2, 1.32)
	cam.rotation_degrees = Vector3(-8, 0, 0)
	cam.fov = 38.0
	_viewport.add_child(cam)
	_add_lights(_viewport)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.46
	torus.rings = 48
	torus.ring_segments = 6
	_ring.mesh = torus
	_ring.position = Vector3(0, -0.27, 0)
	_ring.scale = Vector3(1, 0.4, 1)
	_viewport.add_child(_ring)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.44
	cyl.height = 0.03
	cyl.radial_segments = 48
	disc.mesh = cyl
	disc.position = Vector3(0, -0.285, 0)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(UiKit.INK, 1.0).lightened(0.08)
	dm.roughness = 0.6
	disc.material_override = dm
	_viewport.add_child(disc)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -8)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(names)
	_name = UiKit.label("", 50, Color.WHITE, true)
	names.add_child(_name)
	_category = UiKit.label("", 26, UiKit.CYAN, true)
	names.add_child(_category)
	var rank_box := VBoxContainer.new()
	rank_box.add_theme_constant_override("separation", 6)
	rank_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rank_box)
	_rank = UiKit.label("", 24, UiKit.INK, true)
	_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank.custom_minimum_size = Vector2(170, 38)
	_rank.add_theme_constant_override("shadow_offset_y", 0)
	rank_box.add_child(_rank)
	_rank_bar = UiKit.progress(0.0, 10.0, UiKit.AMBER)
	rank_box.add_child(_rank_bar)
	return v


func _build_info() -> Control:
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	info.custom_minimum_size = Vector2(470, 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_role = UiKit.label("", 23, UiKit.CREAM)
	_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_role.custom_minimum_size = Vector2(460, 120)
	info.add_child(_role)
	_traits = HFlowContainer.new()
	_traits.add_theme_constant_override("h_separation", 8)
	_traits.add_theme_constant_override("v_separation", 8)
	info.add_child(_traits)
	info.add_child(UiKit.spacer(4))
	for stat in STATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := UiKit.label(String(stat[0]).to_upper(), 21, Color(1, 1, 1, 0.85), true)
		l.custom_minimum_size = Vector2(170, 0)
		row.add_child(l)
		var bar := UiKit.progress(0.0, 16.0, UiKit.CYAN)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var value := UiKit.label("", 21, Color.WHITE)
		value.custom_minimum_size = Vector2(92, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		info.add_child(row)
		_stat_bars.append(bar)
		_stat_values.append(value)
	info.add_child(UiKit.spacer(10))
	_lock_note = UiKit.label("", 26, UiKit.AMBER, true)
	_lock_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_lock_note)
	for slot in 2:
		var b := UiKit.button("", 34)
		b.custom_minimum_size = Vector2(0, 82)
		b.pressed.connect(_equip_slot.bind(slot))
		info.add_child(b)
		_equip.append(b)
	var hint := UiKit.label("You carry both into every run: switch with 1 / 2 or the mouse wheel. The Loadout Station swaps the held one for free between waves.", 20, Color(1, 1, 1, 0.65))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(hint)
	return info


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


# --- selection ---------------------------------------------------------------------

func _select(w: WeaponData) -> void:
	if w == null:
		return
	_weapon = w
	var unlocked := GameData.is_weapon_unlocked(w)
	(_cards[w.id] as Button).set_pressed_no_signal(true)
	_name.text = w.display_name.to_upper()
	_category.text = w.category.to_upper()
	_role.text = w.role
	var rank := Mastery.rank(w.id)
	_rank.text = UiKit.rank_name(rank, w.max_rank())
	_rank.add_theme_stylebox_override("normal", UiKit.box(UiKit.AMBER if rank > 0 else Color(0.62, 0.6, 0.72), Color.TRANSPARENT, 19, 0, 4))
	_rank_bar.value = Mastery.rank_progress(w.id)
	_build_traits(w)
	for i in STATS.size():
		var result: Array = call(STATS[i][1], w)
		_stat_bars[i].value = clampf(float(result[0]) / float(STATS[i][2]), 0.04, 1.0)
		_stat_values[i].text = String(result[1])
		_stat_bars[i].add_theme_stylebox_override("fill", UiKit.box(w.tracer_color, Color.TRANSPARENT, 8, 0, 0))
	_lock_note.visible = not unlocked
	if not unlocked:
		_lock_note.text = "LOCKED  ·  %s" % (w.unlock.describe() if w.unlock else "")
	var slot := Loadout.slot_of(w.id)
	for i in 2:
		var b := _equip[i]
		b.disabled = not unlocked or slot == i
		b.text = ("%s  ·  EQUIPPED" if slot == i else "EQUIP AS %s") % String(Loadout.SLOT_NAMES[i]).to_upper()
	_refresh_cards()
	_refresh_loadout()
	_build_preview_model()


func _equip_slot(slot: int) -> void:
	if _weapon and Loadout.set_slot(slot, _weapon.id):
		Sfx.play(&"weap_switch", -4.0)
		_select(_weapon)


func _refresh_cards() -> void:
	for id in _cards:
		var w := GameData.weapon(id)
		var b: Button = _cards[id]
		var unlocked := GameData.is_weapon_unlocked(w)
		var selected := w == _weapon
		var normal := UiKit.box(Color(UiKit.INK, 0.78), Color(w.tracer_color, 0.35), 16, 2, 10)
		var hover := UiKit.box(Color(UiKit.PURPLE, 0.6), Color(w.tracer_color, 0.7), 16, 3, 10)
		var on := UiKit.box(Color(UiKit.NAVY, 0.95), w.tracer_color, 16, 5, 10)
		b.add_theme_stylebox_override("normal", on if selected else normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.add_theme_stylebox_override("focus", UiKit.box(Color.TRANSPARENT, UiKit.CYAN, 18, 3, 0))
		(b.find_child("Thumb", true, false) as TextureRect).modulate = Color.WHITE if unlocked else Color(0.35, 0.32, 0.45)
		var sub := b.find_child("Sub", true, false) as Label
		sub.text = w.category if unlocked else "LOCKED · " + (w.unlock.describe() if w.unlock else "")
		sub.add_theme_color_override("font_color", UiKit.CREAM if unlocked else UiKit.AMBER)
		var badge := b.find_child("Badge", true, false) as Label
		var slot := Loadout.slot_of(w.id)
		badge.visible = slot >= 0
		if slot >= 0:
			badge.text = "1ST" if slot == Loadout.PRIMARY else "2ND"
			badge.add_theme_stylebox_override("normal", UiKit.box(w.tracer_color, Color.TRANSPARENT, 8, 0, 2))


func _refresh_loadout() -> void:
	for slot in 2:
		var card := _loadout_cards[slot]
		var w := GameData.weapon(Loadout.slot(slot))
		for c in card.get_children():
			c.queue_free()
		card.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.8), w.tracer_color if w else Color.TRANSPARENT, 14, 3, 10))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -6)
		card.add_child(v)
		v.add_child(UiKit.label(String(Loadout.SLOT_NAMES[slot]).to_upper() + "  [%d]" % (slot + 1), 18, UiKit.CYAN, true))
		v.add_child(UiKit.label(w.display_name.to_upper() if w else "—", 28, Color.WHITE, true))


func _build_traits(w: WeaponData) -> void:
	for c in _traits.get_children():
		c.queue_free()
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
	for t in tags:
		var chip := UiKit.label(t, 18, UiKit.INK, true)
		chip.add_theme_constant_override("shadow_offset_y", 0)
		var sb := UiKit.box(w.tracer_color.lerp(Color.WHITE, 0.35), Color.TRANSPARENT, 10, 0, 4)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		chip.add_theme_stylebox_override("normal", sb)
		_traits.add_child(chip)


# --- stats: [value for the bar, text] ------------------------------------------------

func _stat_dps(w: WeaponData) -> Array:
	return [w.damage_per_second(), "%d" % roundi(w.damage_per_second())]


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
