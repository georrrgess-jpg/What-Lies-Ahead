class_name PlayerCard
extends Control
## The player card: the equipped banner (animated), operator portrait, title
## and account level. It follows the equipped cosmetics live.
##
##   add_child(PlayerCard.build(true))    # compact strip for the title screen
##   add_child(PlayerCard.build(false))   # full card (results, Locker)
##
## The Locker previews items on it with preview(slot, item).

const COMPACT_SIZE := Vector2(560, 150)
const SLIM_SIZE := Vector2(520, 112)
const FULL_SIZE := Vector2(980, 176)

var compact := false
## An even shorter compact card (results screen), without the operator line.
var slim := false
var _banner: BannerView
var _portrait: OperatorPreview
var _title: Label
var _level: Label
var _bar: ProgressBar
var _operator: Label
var _stats: Label
var _overrides := {}


static func build(is_compact: bool) -> Control:
	var card := PlayerCard.new()
	card.compact = is_compact
	return card


func _ready() -> void:
	custom_minimum_size = SLIM_SIZE if slim else (COMPACT_SIZE if compact else FULL_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner = BannerView.new(null, 18.0)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_banner)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 14)
	row.offset_left = 12
	row.offset_right = -16
	row.offset_top = 8
	row.offset_bottom = -8
	add_child(row)
	_portrait = OperatorPreview.new()
	_portrait.follow_equipped = false
	_portrait.item = _shown(&"avatar")
	_portrait.framing = OperatorPreview.Framing.PORTRAIT
	_portrait.turntable_speed = 0.0
	_portrait.custom_minimum_size = Vector2(custom_minimum_size.y - 16, custom_minimum_size.y - 16)
	row.add_child(_portrait)
	row.add_child(_info_column())
	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", UiKit.box(Color.TRANSPARENT, Color(1, 1, 1, 0.35), 18, 3, 0))
	add_child(frame)
	Cosmetics.equipped_changed.connect(_on_equipped_changed)
	refresh()


func _on_equipped_changed(_slot: StringName, _weapon_id: StringName) -> void:
	refresh()


func _info_column() -> Control:
	var plate := PanelContainer.new()
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.5), Color.TRANSPARENT, 14, 0, 10 if compact else 14))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	plate.add_child(col)
	_title = UiKit.arcade_label("", 30 if slim else (34 if compact else 46))
	_title.clip_text = true
	col.add_child(_title)
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 12)
	col.add_child(level_row)
	_level = UiKit.arcade_label("", 22 if compact else 26, UiKit.AMBER)
	level_row.add_child(_level)
	_bar = UiKit.progress(0.0, 12.0 if compact else 14.0, UiKit.AMBER)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_row.add_child(_bar)
	_operator = UiKit.label("", 18 if compact else 22, UiKit.CREAM)
	_operator.visible = not slim
	col.add_child(_operator)
	if not compact:
		_stats = UiKit.label("", 20, Color(1, 1, 1, 0.75))
		col.add_child(_stats)
	return plate


## Shows `item` on the card in place of what is equipped in its slot
## ("banner", "title" or "avatar"); null restores the equipped item.
func preview(slot: StringName, item: CosmeticItem) -> void:
	if item:
		_overrides[slot] = item
	else:
		_overrides.erase(slot)
	if is_inside_tree():
		refresh()


func _shown(slot: StringName) -> CosmeticItem:
	return _overrides.get(slot, Cosmetics.equipped_or_default(slot))


func refresh() -> void:
	if _banner == null:
		return
	_banner.set_banner(_shown(&"banner"))
	var title := _shown(&"title")
	_title.text = (title.display_name if title else "Rookie").to_upper()
	_title.add_theme_color_override("font_color", CosmeticItem.rarity_color(title.rarity).lerp(Color.WHITE, 0.35) if title else Color.WHITE)
	_level.text = "LV %d" % Progression.level()
	_bar.value = Progression.level_progress()
	var op := _shown(&"avatar")
	_operator.text = "Operator  ·  %s" % (op.display_name if op else "Boardwalk Ranger")
	if _portrait.item != op:
		_portrait.show_operator(op, false)
	if _stats:
		var cleared := 0
		for world in GameData.worlds():
			for level in world.levels:
				if level and Profile.is_level_completed(level.id):
					cleared += 1
		_stats.text = "%s zombies popped   ·   %d level%s cleared   ·   %d / %d locker items" % [
			_thousands(Mastery.total_kills()), cleared, "" if cleared == 1 else "s", _owned_count(), GameData.cosmetics().size()]


func _owned_count() -> int:
	var n := 0
	for it in GameData.cosmetics():
		if Cosmetics.is_owned_anywhere(it):
			n += 1
	return n


static func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
