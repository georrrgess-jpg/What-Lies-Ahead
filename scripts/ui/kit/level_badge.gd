class_name LevelBadge
extends Control
## Gold shield with a level number. By default it shows the player's level
## and follows it; set_level() pins another number (a reward track, a
## requirement).
##
##   bar.add_child(UiKit.level_badge())          # the player's level, 72 px
##   var need := UiKit.level_badge(48.0)
##   need.set_level(5)

var _number: Label
var _follow := true


static func make(badge_size := 72.0) -> LevelBadge:
	var b := LevelBadge.new()
	b._build(badge_size)
	return b


func _build(badge_size: float) -> void:
	custom_minimum_size = Vector2(badge_size, badge_size)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shield := TextureRect.new()
	shield.texture = KitTex.tex(&"level_badge")
	shield.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shield.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shield)
	_number = UiKit.sign_label("1", int(badge_size * 0.42))
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_number.offset_bottom = -badge_size * 0.08
	_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_number)


func _ready() -> void:
	if _follow:
		_number.text = str(Progression.level())
		Progression.level_up.connect(_on_level_up)


## Shows `level` and stops following the player's level.
func set_level(level: int) -> void:
	_follow = false
	_number.text = str(level)


func _on_level_up(new_level: int) -> void:
	if not _follow:
		return
	_number.text = str(new_level)
	if is_visible_in_tree():
		UiFx.pulse(self, 1.25)
