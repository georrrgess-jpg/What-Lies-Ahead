class_name CareerCards
extends RefCounted
## Builders for the Career page, all from the UI kit: the level block, the
## cards of the level road, contract and milestone tiles, weapon mastery
## cards and the small stat tiles. Each returns a finished Control; tiles
## carry the longer text the page shows while they are focused.

const ROAD_CARD := Vector2(172, 200)
const MASTERY_CARD := Vector2(236, 150)
const CONTRACT_TILE := Vector2(210, 164)
const MILESTONE_TILE := Vector2(54, 54)


## A caption over a value on a dark tile ("ZOMBIES POPPED" / "1,500").
static func stat_tile(caption: String, value: String, accent := UiKit.CYAN) -> Control:
	var box := UiKit.card_panel(10)
	box.custom_minimum_size.x = 150
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -8)
	box.add_child(v)
	var c := UiKit.label(caption, UiKit.SIZE_SMALL, accent, true)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	var val := UiKit.label(value, 34, Color.WHITE, true)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(val)
	return box


## The player's level: badge, title, XP bar and what is left to the next level.
static func level_block() -> Control:
	var lvl := Progression.level()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_M)
	row.add_child(UiKit.level_badge(132.0))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.custom_minimum_size.x = 250
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var title := Cosmetics.equipped_or_default(&"title")
	col.add_child(UiKit.label((title.display_name if title else "Rookie").to_upper(), 22, UiKit.CYAN, true))
	col.add_child(UiKit.sign_label("LEVEL %d" % lvl, 54))
	var bar := UiKit.progress(Progression.level_progress(), 18.0, UiKit.AMBER)
	col.add_child(bar)
	col.add_child(UiKit.spacer(UiKit.GAP_XS))
	var next := "Top level reached" if lvl >= Progression.MAX_LEVEL else "%s XP to level %d" % [Wallet.format(Progression.xp_to_next()), lvl + 1]
	col.add_child(UiKit.label(next, UiKit.SIZE_SMALL, UiKit.CREAM))
	return row


# --- level road ---------------------------------------------------------------------

## One level of the road: what it gives (a cosmetic, a weapon or a stamp) and
## its Sparks. Levels already reached read "Claimed"; the next one is outlined.
static func road_card(lvl: int, current: int, thumbs: CosmeticThumbs) -> ItemCard:
	var rewards := Progression.level_rewards(lvl)
	var weapons := Progression.level_weapons(lvl)
	var card: ItemCard
	if weapons.is_empty() and not rewards.is_empty():
		var locker_card := LockerCard.create(ROAD_CARD)
		locker_card.show_item(rewards[0], null, thumbs)
		locker_card.set_new(false)
		card = locker_card
	else:
		var stamp := Progression.stamp(lvl)
		card = UiKit.item_card((stamp[0] if not stamp.is_empty() else "Level %d" % lvl).to_upper(), ROAD_CARD)
		card.set_preview(RewardArt.stamp(stamp[0] if not stamp.is_empty() else "Level", false, Vector2.ZERO))
		card.set_rarity(UiKit.AMBER if not weapons.is_empty() else Color.TRANSPARENT)
	card.toggle_mode = false
	var is_next := lvl == current + 1
	card.set_tag("NEXT  ·  LV %d" % lvl if is_next else "LV %d" % lvl, UiKit.PINK if is_next else (UiKit.AMBER if Progression.is_milestone_level(lvl) else UiKit.CYAN))
	if lvl <= current:
		card.set_status("Claimed", UiKit.GREEN)
	else:
		card.set_price(Progression.level_sparks(lvl))
	if is_next:
		card.add_theme_stylebox_override("normal", KitTex.box(&"card_selected"))
	card.set_meta(&"detail", road_detail(lvl, current))
	return card


## "LEVEL 12  ·  New weapon: Rail Lancer  ·  +110 Sparks  ·  2 levels to go".
static func road_detail(lvl: int, current: int) -> String:
	var parts := PackedStringArray(["LEVEL %d" % lvl])
	var reward := Progression.reward_text(lvl)
	if reward != "":
		parts.append(reward)
	parts.append("+%d %s" % [Progression.level_sparks(lvl), Wallet.CURRENCY])
	if lvl <= current:
		parts.append("claimed")
	elif lvl == current + 1:
		parts.append("%s XP to go" % Wallet.format(Progression.xp_to_next()))
	else:
		parts.append("%d levels to go" % (lvl - current))
	return "  ·  ".join(parts)


## The piece of road between two level cards (lit once it has been walked).
static func road_link(walked: bool) -> Control:
	var link := ColorRect.new()
	link.color = UiKit.CYAN if walked else Color("3a2d6b")
	link.custom_minimum_size = Vector2(14, 6)
	link.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	link.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return link


# --- contracts and milestones ---------------------------------------------------------

## The three active contracts side by side (ContractBoard), each with its
## goal, progress bar and reward.
static func contracts_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_S)
	for entry in ContractBoard.active():
		row.add_child(contract_tile(entry))
	return row


## One active contract: name, goal, progress and what it pays.
static func contract_tile(entry: Dictionary) -> CareerTile:
	var template := ContractBoard.template(entry)
	var done := ContractBoard.is_done(entry)
	var tile := CareerTile.make(CONTRACT_TILE)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.set_marked(done)
	var name := UiKit.label(ContractBoard.title(entry).to_upper(), 24, UiKit.GREEN if done else UiKit.CREAM, true)
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tile.body.add_child(name)
	var goal := UiKit.body(ContractBoard.describe(entry), 0.0, UiKit.SIZE_SMALL, UiKit.MUTED)
	goal.max_lines_visible = 2
	goal.add_theme_constant_override("line_spacing", -6)
	goal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile.body.add_child(goal)
	tile.body.add_child(_meter(ContractBoard.fraction(entry), UiKit.GREEN if done else Wallet.COLOR_GLOW,
		"DONE" if done else "%s / %s" % [Wallet.format(ContractBoard.progress(entry)), Wallet.format(ContractBoard.goal(entry))]))
	if template:
		tile.body.add_child(_pay_row(template.sparks, template.xp))
		tile.detail = "%s  ·  %s  ·  pays %d %s and %s XP%s" % [ContractBoard.title(entry).to_upper(), ContractBoard.describe(entry),
			template.sparks, Wallet.CURRENCY, Wallet.format(template.xp), ". Done: a new one is dealt after the run" if done else ""]
	return tile


## A long-term goal as a small medal: a check once reached, a ring of
## progress until then. The page shows what it asks for while it is focused.
static func milestone_tile(ch: Challenge) -> CareerTile:
	var done := ChallengeBook.is_complete(ch)
	var tile := CareerTile.make(MILESTONE_TILE, 6)
	tile.set_marked(done)
	var medal := MilestoneMedal.new()
	medal.fraction = ChallengeBook.fraction(ch)
	medal.done = done
	medal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile.body.add_child(medal)
	var pay := "%s XP" % Wallet.format(ch.xp)
	if ch.sparks > 0:
		pay = "%d %s and %s" % [ch.sparks, Wallet.CURRENCY, pay]
	var rewards := ChallengeBook.rewards(ch)
	if not rewards.is_empty():
		pay += " and the %s %s" % [rewards[0].display_name, rewards[0].slot_label().to_lower()]
	var count := "reached" if done else "%s / %s" % [Wallet.format(ChallengeBook.progress(ch)), Wallet.format(ch.goal)]
	tile.detail = "%s  ·  %s  ·  %s  ·  pays %s" % [ch.display_name.to_upper(), ch.describe(), count, pay]
	return tile


# --- weapon mastery -------------------------------------------------------------------

## One weapon: tier badge, rank, progress to the next rank and what that
## rank gives. Locked weapons say what unlocks them.
static func mastery_card(w: WeaponData) -> CareerTile:
	var rank := Mastery.rank(w.id)
	var unlocked := GameData.is_weapon_unlocked(w)
	var tier_color := ProgStyle.rank_color(rank)
	var tile := CareerTile.make(MASTERY_CARD)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiKit.GAP_S)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.body.add_child(head)
	head.add_child(TierBadge.new(rank, 62.0))
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", -6)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(names)
	var name := UiKit.label(w.display_name.to_upper(), 22, UiKit.CREAM if unlocked else UiKit.MUTED, true)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.max_lines_visible = 2
	name.add_theme_constant_override("line_spacing", -8)
	names.add_child(name)
	names.add_child(UiKit.label(Mastery.rank_label(rank).capitalize() if unlocked else "Locked", UiKit.SIZE_SMALL, tier_color if rank > 0 else UiKit.MUTED, true))
	tile.body.add_child(UiKit.filler())
	var next := _next_reward(w.id, rank)
	var foot := "Fully mastered"
	if not unlocked:
		foot = w.unlock.describe() if w.unlock else "Locked"
	elif next:
		foot = "Rank %d: %s" % [next.requirement.amount, next.display_name]
	tile.body.add_child(_meter(Mastery.rank_progress(w.id), tier_color if rank > 0 else UiKit.CYAN, ""))
	var foot_label := UiKit.label(foot, UiKit.SIZE_SMALL, UiKit.AMBER if not unlocked else UiKit.MUTED)
	foot_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tile.body.add_child(foot_label)
	tile.detail = _mastery_detail(w, rank, next, unlocked)
	tile.set_meta(&"weapon", w.id)
	return tile


static func _mastery_detail(w: WeaponData, rank: int, next: CosmeticItem, unlocked: bool) -> String:
	if not unlocked:
		return "%s  ·  %s to unlock it" % [w.display_name.to_upper(), w.unlock.describe() if w.unlock else "Locked"]
	var parts := PackedStringArray([w.display_name.to_upper(), "%s kills" % Wallet.format(Mastery.kills(w.id))])
	var ceiling := Mastery.rank_ceiling(rank)
	if ceiling < 0:
		parts.append("%s XP, fully mastered" % Wallet.format(Mastery.xp(w.id)))
	else:
		parts.append("%s / %s XP to rank %d" % [Wallet.format(Mastery.xp(w.id)), Wallet.format(ceiling), rank + 1])
	if next:
		parts.append("next: %s (%s)" % [next.display_name, next.slot_label().to_lower()])
	return "  ·  ".join(parts)


static func _next_reward(weapon_id: StringName, rank: int) -> CosmeticItem:
	for it in Mastery.rank_track(weapon_id):
		if it.price == 0 and it.requirement.amount > rank:
			return it
	return null


# --- shared pieces --------------------------------------------------------------------

## A slim bar with an optional count to its right.
static func _meter(fraction: float, color: Color, count: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_S)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := UiKit.progress(fraction, 12.0, color)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	if count != "":
		row.add_child(UiKit.label(count, UiKit.SIZE_SMALL, UiKit.CREAM, true))
	return row


## What a goal pays: Sparks and XP.
static func _pay_row(sparks: int, xp: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_M)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if sparks > 0:
		row.add_child(UiKit.price_tag(sparks, UiKit.SIZE_SMALL))
	row.add_child(UiKit.label("+%s XP" % Wallet.format(xp), UiKit.SIZE_SMALL, ProgStyle.XP_COLOR, true))
	return row


## The face of a milestone tile: a ring that fills with progress around a
## star, or a green check once the milestone is reached.
class MilestoneMedal extends Control:
	var fraction := 0.0
	var done := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 3.0
		draw_arc(c, r, 0.0, TAU, 32, Color("3a2d6b"), 4.0, true)
		var color := UiKit.GREEN if done else UiKit.AMBER
		if done or fraction > 0.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * (1.0 if done else fraction), 32, color, 4.0, true)
		var icon := KitTex.tex(&"icon_check" if done else &"icon_star")
		if icon:
			var side := r * 1.15
			draw_texture_rect(icon, Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side)), false, color if done else Color(color, 0.35 + 0.65 * fraction))
