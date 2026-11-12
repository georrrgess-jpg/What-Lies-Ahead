class_name CareerCards
extends RefCounted
## Builders for the Career page's cards: the player card, reward-track cards,
## weapon mastery cards and challenge tiles. Each returns a finished Control.

const KIND_LABELS := {"weapon_finish": "Weapon finish", "weapon_cell": "Energy cell", "banner": "Banner", "title": "Title"}


## Account level, XP bar, equipped title and banner, lifetime stats.
static func player_card() -> Control:
	var lvl := Progression.level()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.9), Color(ProgStyle.level_color(lvl), 0.7), 20, 3, 0))
	card.clip_contents = true
	var banner_item := Cosmetics.equipped(&"banner")
	if banner_item:
		var art := RewardArt.new(banner_item, false, Vector2.ZERO)
		art.modulate = Color(1, 1, 1, 0.55)
		card.add_child(art)
	card.add_child(shade_gradient(0.92, 0.35))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.add_theme_constant_override("margin_left", 26)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	margin.add_child(row)
	row.add_child(LevelEmblem.new(lvl, 128.0))
	row.add_child(_level_column(lvl))
	row.add_child(_stats_column())
	return card


static func _level_column(lvl: int) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	var title := Cosmetics.equipped(&"title")
	var title_text := title.display_name.to_upper() if title else "PIER ROOKIE"
	col.add_child(UiKit.label(title_text, 24, title.color(0, UiKit.CREAM) if title else Color(1, 1, 1, 0.65), true))
	var head := HBoxContainer.new()
	col.add_child(head)
	var level_label := UiKit.arcade_label("LEVEL %d" % lvl, 58, Color.WHITE)
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(level_label)
	var bar := ProgStyle.bar(22.0, ProgStyle.XP_COLOR)
	bar.value = Progression.level_progress()
	col.add_child(bar)
	var foot := HBoxContainer.new()
	col.add_child(foot)
	var xp_text := UiKit.label("%s XP total" % ProgStyle.num(Progression.xp()), 22, UiKit.CREAM)
	xp_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(xp_text)
	var next := "MAX LEVEL" if lvl >= Progression.MAX_LEVEL else "%s XP to level %d" % [ProgStyle.num(Progression.xp_to_next()), lvl + 1]
	foot.add_child(UiKit.label(next, 22, ProgStyle.XP_COLOR, true))
	return col


static func _stats_column() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var done := ChallengeBook.completion()
	var clears := 0
	for key in Profile.data["levels"]:
		clears += int(Profile.data["levels"][key].get("clears", 0))
	grid.add_child(_stat("LIFETIME KILLS", ProgStyle.num(Mastery.total_kills())))
	grid.add_child(_stat("LEVEL CLEARS", ProgStyle.num(clears)))
	grid.add_child(_stat("CHALLENGES", "%d / %d" % [done.x, done.y]))
	grid.add_child(_stat("RUNS", ProgStyle.num(int(Profile.section("progression").get("runs_played", 0)))))
	return grid


static func _stat(caption: String, value: String) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.75), Color.TRANSPARENT, 14, 0, 10))
	box.custom_minimum_size = Vector2(190, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -8)
	box.add_child(v)
	var c := UiKit.label(caption, 17, UiKit.CYAN, true)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	var val := UiKit.label(value, 34, Color.WHITE, true)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(val)
	return box


## Left-to-right darkening so text stays readable over any banner.
static func shade_gradient(left_alpha: float, right_alpha: float) -> TextureRect:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(UiKit.INK, left_alpha), Color(UiKit.INK, right_alpha)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 4
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


# --- reward track ------------------------------------------------------------------

## One level on the reward track: level chip, preview, reward name and kind.
static func track_card(lvl: int, current: int) -> Control:
	var items := Progression.level_rewards(lvl)
	var item: CosmeticItem = items[0] if not items.is_empty() else null
	var owned := lvl <= current
	var is_next := lvl == current + 1
	var accent := CosmeticItem.rarity_color(item.rarity) if item else UiKit.AMBER
	var card := PanelContainer.new()
	var border := UiKit.CYAN if is_next else Color(accent, 0.45)
	card.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.82), border, 16, 4 if is_next else 2, 10))
	card.custom_minimum_size = Vector2(190, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	head.add_child(LevelEmblem.new(lvl, 34.0))
	var tag := UiKit.label("NEXT" if is_next else ("OWNED" if owned else "LEVEL %d" % lvl), 18, UiKit.CYAN if is_next else UiKit.CREAM, true)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tag)
	var stamp := Progression.stamp(lvl)
	var art := RewardArt.new(item, false, Vector2(150, 84)) if item else RewardArt.stamp(stamp[0] if not stamp.is_empty() else "", false, Vector2(150, 84))
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(art)
	var name := UiKit.label(item.display_name if item else (stamp[0] if not stamp.is_empty() else "—"), 22, Color.WHITE, true)
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.custom_minimum_size = Vector2(150, 0)
	v.add_child(name)
	var kind := String(KIND_LABELS.get(String(item.slot), item.slot_label())) if item else "Pier Pass stamp"
	v.add_child(UiKit.label(kind, 17, Color(accent, 0.9) if item else UiKit.AMBER))
	card.tooltip_text = item.description if item else (stamp[1] if stamp.size() > 1 else "")
	if is_next:
		var bar := ProgStyle.bar(8.0, UiKit.CYAN)
		bar.value = Progression.level_progress()
		v.add_child(bar)
	return card


# --- weapon mastery -------------------------------------------------------------------

## Tier badge, rank, XP bar, kills and the weapon's rank-by-rank reward strip.
## Owned rewards in the strip equip on click; `on_change` runs afterwards.
static func weapon_card(w: WeaponData, on_change: Callable) -> Control:
	var rank := Mastery.rank(w.id)
	var tier_col := ProgStyle.rank_color(rank)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.78), Color(tier_col, 0.5 if rank > 0 else 0.15), 18, 3, 14))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	head.add_child(TierBadge.new(rank, 74.0))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -6)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(names)
	names.add_child(UiKit.label(w.display_name.to_upper(), 32, Color.WHITE, true))
	names.add_child(UiKit.label(Mastery.rank_label(rank), 22, tier_col if rank > 0 else Color(1, 1, 1, 0.55), true))
	var kills := VBoxContainer.new()
	kills.add_theme_constant_override("separation", -8)
	kills.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(kills)
	var kv := UiKit.label(ProgStyle.num(Mastery.kills(w.id)), 32, Color.WHITE, true)
	kv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kills.add_child(kv)
	var kc := UiKit.label("KILLS", 16, UiKit.CYAN, true)
	kc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kills.add_child(kc)
	var bar := ProgStyle.bar(14.0, tier_col if rank > 0 else UiKit.CYAN)
	bar.value = Mastery.rank_progress(w.id)
	v.add_child(bar)
	var ceiling := Mastery.rank_ceiling(rank)
	var xp_text := "%s XP · fully mastered" % ProgStyle.num(Mastery.xp(w.id)) if ceiling < 0 \
		else "%s / %s XP to rank %d" % [ProgStyle.num(Mastery.xp(w.id)), ProgStyle.num(ceiling), rank + 1]
	v.add_child(UiKit.label(xp_text, 19, UiKit.CREAM))
	v.add_child(_reward_strip(w, rank, on_change))
	return card


static func _reward_strip(w: WeaponData, rank: int, on_change: Callable) -> Control:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 4)
	var by_rank := {}
	for it in Mastery.rank_track(w.id):
		if not by_rank.has(it.requirement.amount):
			by_rank[it.requirement.amount] = it
	for r in range(1, Mastery.max_rank() + 1):
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		strip.add_child(cell)
		var it: CosmeticItem = by_rank.get(r)
		var art := RewardArt.new(it, rank < r, Vector2(42, 42)) if it else RewardArt.stamp("", rank < r, Vector2(42, 42))
		art.mouse_filter = Control.MOUSE_FILTER_PASS
		art.tooltip_text = "Rank %d: %s (%s)" % [r, it.display_name, it.slot_label()] if it else "Rank %d" % r
		if it and rank >= r:
			_make_equippable(art, w.id, on_change)
		cell.add_child(art)
		var t := Mastery.tier(r)
		var lab := UiKit.label(str(r), 15, t.color if rank >= r else Color(1, 1, 1, 0.4), true)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(lab)
	return strip


## Click toggles the item on this weapon; the equipped one wears a ring.
static func _make_equippable(art: RewardArt, weapon_id: StringName, on_change: Callable) -> void:
	var it := art.item
	art.equipped = Cosmetics.equipped(it.slot, weapon_id) == it
	art.mouse_filter = Control.MOUSE_FILTER_STOP
	art.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	art.tooltip_text += "\nClick to %s" % ("unequip" if art.equipped else "equip")
	art.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Cosmetics.equip(it.slot, null if art.equipped else it, weapon_id)
			Sfx.play(&"ui_click", -6.0)
			on_change.call())


# --- challenges -----------------------------------------------------------------------

## A challenge with its progress bar, XP reward and any cosmetic reward.
static func challenge_tile(ch: Challenge, weapon_id: StringName, compact := false) -> Control:
	var done := ChallengeBook.is_complete(ch, weapon_id)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.78), Color(UiKit.GREEN, 0.6) if done else Color(1, 1, 1, 0.08), 16, 2, 12))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var name := UiKit.label(ch.display_name.to_upper(), 24 if compact else 27, UiKit.GREEN if done else Color.WHITE, true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	top.add_child(UiKit.label("+%s XP" % ProgStyle.num(ch.xp), 20, UiKit.AMBER, true))
	var desc := UiKit.label(ch.describe(), 19, UiKit.CREAM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 10)
	v.add_child(bar_row)
	var bar := ProgStyle.bar(12.0, UiKit.GREEN if done else UiKit.CYAN)
	bar.value = ChallengeBook.fraction(ch, weapon_id)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(bar)
	var count := "DONE" if done else "%s / %s" % [ProgStyle.num(ChallengeBook.progress(ch, weapon_id)), ProgStyle.num(ch.goal)]
	bar_row.add_child(UiKit.label(count, 18, UiKit.GREEN if done else Color.WHITE, true))
	var rewards := ChallengeBook.rewards(ch)
	if not rewards.is_empty() and not compact:
		var art := RewardArt.new(rewards[0], not done, Vector2(118, 72))
		art.mouse_filter = Control.MOUSE_FILTER_PASS
		art.tooltip_text = "%s: %s" % [rewards[0].slot_label(), rewards[0].display_name]
		art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(art)
	return card
