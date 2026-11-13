class_name RoundsBossBar
extends VBoxContainer
## The finale alpha's name and health bar (registered by
## data/ui/hud_boss_bar.tres), in the HUD's "top" slot under the objective
## pill. A notch marks each phase threshold; it pops in when the alpha
## arrives and fades out when it falls.

const BAR_WIDTH := 640.0
const BAR_HEIGHT := 22.0

var _director: RunDirector
var _name: Label
var _bar: ProgressBar
var _fill: StyleBoxFlat
var _notches: Control
var _shown := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", -2)
	_name = UiKit.arcade_label("", 38, UiKit.PINK_LIGHT)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name)
	_bar = UiKit.progress(1.0, BAR_HEIGHT, UiKit.PINK)
	_bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar.add_theme_stylebox_override("background", UiKit.box(Color(UiKit.INK, 0.9), UiKit.CREAM, int(BAR_HEIGHT / 2), 3, 0))
	_fill = UiKit.box(UiKit.PINK, Color.TRANSPARENT, int(BAR_HEIGHT / 2), 0, 0)
	_bar.add_theme_stylebox_override("fill", _fill)
	add_child(_bar)
	_notches = Control.new()
	_notches.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_notches)
	_notches.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	set_process(false)


## Under the objective pill, centred.
func hud_slot() -> StringName:
	return &"top"


func bind(director: RunDirector, _player: Player) -> void:
	_director = director
	director.boss_changed.connect(_on_boss_changed)


func _process(delta: float) -> void:
	var boss := _director.boss
	if is_instance_valid(boss):
		_shown = move_toward(_shown, boss.health_fraction(), delta * 0.8)
		_bar.value = _shown


func _on_boss_changed(boss: Zombie) -> void:
	if boss == null:
		set_process(false)
		var fade := create_tween()
		fade.tween_property(_bar, "value", 0.0, 0.3)
		fade.tween_property(self, "modulate:a", 0.0, 0.6).set_delay(0.5)
		fade.tween_callback(func(): visible = false)
		return
	_name.text = boss.data.display_name.to_upper()
	var tint := UiKit.PINK
	var thresholds := PackedFloat32Array()
	for b in boss.behaviours:
		if b is AlphaBossBehaviour:
			tint = b.color
			thresholds = b.phases
	_fill.bg_color = tint
	_name.add_theme_color_override("font_color", tint.lightened(0.35))
	for c in _notches.get_children():
		c.queue_free()
	for t in thresholds:
		var notch := ColorRect.new()
		notch.color = UiKit.CREAM
		notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		notch.size = Vector2(4, BAR_HEIGHT)
		notch.position = Vector2(BAR_WIDTH * t - 2.0, 0)
		_notches.add_child(notch)
	_shown = 1.0
	_bar.value = 1.0
	visible = true
	set_process(true)
	modulate.a = 0.0
	pivot_offset = Vector2(BAR_WIDTH * 0.5, 30)
	scale = Vector2(1.2, 1.2)
	var pop := create_tween().set_parallel()
	pop.tween_property(self, "modulate:a", 1.0, 0.25)
	pop.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
