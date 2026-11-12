class_name ArmoryPage
extends MenuPage
## Armory: per-weapon mastery progress and cosmetic rewards. Unlocked rewards
## can be equipped here; the preview shows the result.

var _weapon: WeaponData
var _tabs := {}
var _name: Label
var _role: Label
var _rank: Label
var _xp: Label
var _kills: Label
var _bar: ProgressBar
var _rewards: VBoxContainer
var _viewport: SubViewport
var _pivot: Node3D
var _model: Node3D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(1420, 0)
	panel.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := UiKit.label("ARMORY", 64, UiKit.AMBER, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var back_button := UiKit.soft_button("Back", 30)
	back_button.pressed.connect(func(): back.emit())
	head.add_child(back_button)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 14)
	col.add_child(tabs)
	var group := ButtonGroup.new()
	for weapon in GameData.weapons():
		var b := UiKit.soft_button(weapon.display_name, 32)
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var on := UiKit.box(UiKit.PINK, UiKit.PINK_DARK, 18, 0, 10)
		on.border_width_bottom = 6
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.pressed.connect(_select.bind(weapon))
		tabs.add_child(b)
		_tabs[weapon.id] = b
		if weapon == GameData.weapons()[0]:
			b.name = "FirstFocus"

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 26)
	col.add_child(body)

	# Left: 3D preview.
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.custom_minimum_size = Vector2(620, 480)
	body.add_child(holder)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	holder.add_child(_viewport)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.05, 1.25)
	cam.fov = 40.0
	_viewport.add_child(cam)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	key.light_energy = 1.4
	key.light_color = Color(1.0, 0.93, 0.85)
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -140, 0)
	fill.light_energy = 0.7
	fill.light_color = Color(0.75, 0.6, 1.0)
	_viewport.add_child(fill)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.65, 0.95)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)

	# Right: mastery info and rewards.
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	body.add_child(info)
	_name = UiKit.label("", 52, Color.WHITE, true)
	info.add_child(_name)
	_role = UiKit.label("", 24, UiKit.CREAM)
	_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_role)
	info.add_child(UiKit.spacer(6))
	var rank_row := HBoxContainer.new()
	info.add_child(rank_row)
	_rank = UiKit.label("", 36, UiKit.CYAN, true)
	_rank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_row.add_child(_rank)
	_kills = UiKit.label("", 26, UiKit.CREAM)
	rank_row.add_child(_kills)
	_bar = UiKit.progress(0.0, 22.0)
	info.add_child(_bar)
	_xp = UiKit.label("", 24, UiKit.CREAM)
	info.add_child(_xp)
	info.add_child(UiKit.spacer(8))
	info.add_child(UiKit.label("MASTERY REWARDS", 30, UiKit.AMBER, true))
	_rewards = VBoxContainer.new()
	_rewards.add_theme_constant_override("separation", 10)
	info.add_child(_rewards)

	_select(GameData.weapons()[0])


func _process(delta: float) -> void:
	if visible and _pivot:
		_pivot.rotate_y(delta * 0.6)


func refresh() -> void:
	if _weapon:
		_select(_weapon)


func _select(weapon: WeaponData) -> void:
	_weapon = weapon
	(_tabs[weapon.id] as Button).set_pressed_no_signal(true)
	_name.text = weapon.display_name.to_upper()
	_role.text = weapon.role
	var rank := Mastery.rank(weapon.id)
	var xp := Mastery.xp(weapon.id)
	_rank.text = UiKit.rank_name(rank, weapon.max_rank())
	_kills.text = "Lifetime kills: %d" % Mastery.kills(weapon.id)
	_bar.value = Mastery.rank_progress(weapon.id)
	var ceiling := weapon.xp_ceiling(rank)
	_xp.text = "%d XP — fully mastered" % xp if ceiling < 0 else "%d / %d XP to rank %d" % [xp, ceiling, rank + 1]
	_build_rewards()
	_build_preview()


func _build_rewards() -> void:
	for c in _rewards.get_children():
		c.queue_free()
	var rank := Mastery.rank(_weapon.id)
	for reward in Mastery.rewards(_weapon.id):
		var unlocked := Cosmetics.is_owned(reward)
		var equipped := Cosmetics.equipped(reward.slot, _weapon.id) == reward
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.7), UiKit.CYAN if equipped else Color.TRANSPARENT, 14, 3 if equipped else 0, 12))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		row.add_child(h)
		var swatch := ColorRect.new()
		swatch.color = reward.color(0) if unlocked else Color(0.3, 0.28, 0.4)
		swatch.custom_minimum_size = Vector2(46, 46)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(swatch)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", -6)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(text)
		text.add_child(UiKit.label(reward.display_name, 30, Color.WHITE if unlocked else Color(1, 1, 1, 0.55), true))
		text.add_child(UiKit.label("%s  ·  %s" % [reward.slot_label(), reward.requirement.describe() if reward.requirement else ""], 22, UiKit.CREAM if unlocked else Color(1, 1, 1, 0.45)))
		if unlocked:
			var b := UiKit.soft_button("Unequip" if equipped else "Equip", 26)
			b.custom_minimum_size = Vector2(170, 0)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.pressed.connect(_toggle.bind(reward, equipped))
			h.add_child(b)
		else:
			var locked := UiKit.label("LOCKED", 24, Color(1, 1, 1, 0.5), true)
			locked.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(locked)
		_rewards.add_child(row)


func _toggle(reward: CosmeticItem, currently_equipped: bool) -> void:
	Cosmetics.equip(reward.slot, null if currently_equipped else reward, _weapon.id)
	_select(_weapon)


func _build_preview() -> void:
	if _model:
		_model.queue_free()
		_model = null
	if _weapon.viewmodel == null:
		return
	_model = _weapon.viewmodel.instantiate()
	_pivot.add_child(_model)
	for arm_name in ["ArmL", "ArmR"]:
		var arm := _model.find_child(arm_name, true, false) as Node3D
		if arm:
			arm.visible = false
	WeaponCosmetics.apply(_model, _weapon, Cosmetics.weapon_loadout(_weapon.id))
	# Centre the weapon on the turntable.
	var bounds := _bounds(_model)
	_model.position = -bounds.get_center()
	var largest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	_pivot.scale = Vector3.ONE * (0.75 / maxf(0.01, largest))


func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.is_visible_in_tree() or m.mesh == null:
			continue
		var xf := node.global_transform.affine_inverse() * m.global_transform
		var box := xf * m.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
