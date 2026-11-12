class_name ProgToasts
extends RefCounted
## Builders for the in-run progression toasts (LEVEL UP, RANK UP, challenge
## complete) and the shine/confetti effects they use. The HUD widget
## (scripts/ui/hud_widgets/progression_hud.gd) positions and queues them.

const CONFETTI := [Color("ff3fa4"), Color("35f0ff"), Color("ffc24a"), Color("52f060"), Color("b46bff")]


## Big centre toast for a new account level and what it unlocked.
static func level_up(lvl: int) -> PanelContainer:
	var col := ProgStyle.level_color(lvl)
	var panel := _panel(col)
	var row := _row(panel)
	var emblem := LevelEmblem.new(lvl, 104.0)
	emblem.flash = 1.0
	row.add_child(emblem)
	var v := _column(row)
	v.add_child(UiKit.arcade_label("LEVEL UP!", 58, UiKit.AMBER))
	v.add_child(UiKit.arcade_label("LEVEL %d" % lvl, 32, Color.WHITE))
	var reward := Progression.reward_text(lvl)
	if reward != "":
		v.add_child(UiKit.label(reward, 24, UiKit.CREAM))
	var items := Progression.level_rewards(lvl)
	if not items.is_empty():
		row.add_child(RewardArt.new(items[0], false, Vector2(120, 84)))
	return panel


## Centre toast for a weapon mastery rank, in the tier colour.
static func rank_up(weapon: WeaponData, rank: int) -> PanelContainer:
	var tier := Mastery.tier(rank)
	var col := tier.color if tier else UiKit.CYAN
	var panel := _panel(col)
	var row := _row(panel)
	var badge := TierBadge.new(rank, 100.0)
	badge.flash = 1.0
	row.add_child(badge)
	var v := _column(row)
	var new_tier := tier != null and tier.first_rank == rank
	v.add_child(UiKit.arcade_label("%s TIER!" % tier.display_name.to_upper() if new_tier else "RANK UP!", 52, col))
	v.add_child(UiKit.arcade_label("%s  ·  RANK %d" % [weapon.display_name.to_upper(), rank], 30, Color.WHITE))
	var rewards := Mastery.rewards_at(weapon.id, rank)
	if not rewards.is_empty():
		v.add_child(UiKit.label("Unlocked: %s (%s)" % [rewards[0].display_name, rewards[0].slot_label()], 24, UiKit.CREAM))
		row.add_child(RewardArt.new(rewards[0], false, Vector2(84, 84)))
	return panel


## Small card for the left column: challenge name, scope and XP.
static func challenge(ch: Challenge, weapon_id: StringName) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.NAVY, 0.92), UiKit.GREEN, 16, 3, 12))
	panel.custom_minimum_size = Vector2(430, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var check := check_icon(44.0, UiKit.GREEN)
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(check)
	var v := _column(row)
	v.add_child(UiKit.label("CHALLENGE COMPLETE", 18, UiKit.GREEN, true))
	v.add_child(UiKit.label(ch.display_name.to_upper(), 30, Color.WHITE, true))
	var w := GameData.weapon(weapon_id)
	var detail := "+%s XP" % ProgStyle.num(ch.xp)
	if w:
		detail += "  ·  %s" % w.display_name
	v.add_child(UiKit.label(detail, 20, UiKit.AMBER, true))
	return panel


## A filled circle with a check mark.
static func check_icon(px: float, color: Color) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var r := px * 0.5
		c.draw_circle(Vector2(r, r + px * 0.06), r, Color(UiKit.INK, 0.6))
		c.draw_circle(Vector2(r, r), r, color)
		var tick := PackedVector2Array([Vector2(r * 0.52, r * 1.02), Vector2(r * 0.88, r * 1.36), Vector2(r * 1.5, r * 0.66)])
		c.draw_polyline(tick, UiKit.INK, maxf(2.0, r * 0.26), true))
	return c


## Pop-in, shine and fade for a centre toast. Returns the tween.
static func animate(panel: Control, hold: float) -> Tween:
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * 0.7
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(hold)
	tw.chain().tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(panel, "position:y", panel.position.y - 30.0, 0.4)
	_shine(panel)
	return tw


## A one-shot burst of confetti at `at` (local to `parent`).
static func confetti(parent: Control, at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.amount = 44
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 1.6
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 380.0
	p.initial_velocity_max = 720.0
	p.gravity = Vector2(0, 900)
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 0.9
	p.scale_amount_max = 1.7
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	ramp.colors = PackedColorArray(CONFETTI)
	p.color_initial_ramp = ramp
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func _panel(border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := UiKit.box(Color(UiKit.NAVY, 0.94), border, 24, 4, 18)
	sb.content_margin_left = 22
	sb.content_margin_right = 28
	sb.shadow_color = Color(border, 0.35)
	sb.shadow_size = 18
	panel.add_theme_stylebox_override("panel", sb)
	panel.clip_contents = false
	return panel


static func _row(panel: PanelContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	return row


static func _column(row: HBoxContainer) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(v)
	return v


## A bright diagonal band that sweeps once across the panel.
static func _shine(panel: Control) -> void:
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(clip)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 4
	var band := TextureRect.new()
	band.texture = tex
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.size = Vector2(140, 400)
	band.rotation = 0.35
	band.position = Vector2(-260, -120)
	clip.add_child(band)
	var tw := band.create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(band, "position:x", 1100.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(clip.queue_free)
