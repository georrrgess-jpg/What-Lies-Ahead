extends Control
## In-run rounds HUD (registered by data/ui/hud_rounds.tres). Everything the
## wave system needs on screen beyond the shared HUD's banner:
##   - a chip under the wave counter: the difficulty tier and the name of the
##     wave in progress (during a break: the wave that comes next);
##   - the alpha's name and health bar while a finale boss stands, with a
##     notch at each phase threshold;
##   - a marker on the entrance a surge is about to pour through;
##   - a marker that follows the bounty target, with its time left;
##   - small pings over the last few zombies of a wave.

const MARGIN := 48.0
const CHIP_Y := 164.0
const BAR_TOP := 26.0
const BAR_WIDTH := 620.0
const BAR_HEIGHT := 22.0
const SURGE_COLOR := Color(1.0, 0.3, 0.42)
const PING_COLOR := Color(1.0, 0.76, 0.29)

var _director: RunDirector
var _player: Player
var _chip: Label
var _boss_box: Control
var _boss_name: Label
var _boss_bar: ProgressBar
var _boss_fill: StyleBoxFlat
var _boss_notches: Control
var _surge: Waypoint
var _bounty: Waypoint
var _surge_anchor: Node3D
var _time := 0.0
var _shown_health := 1.0
var _bounty_seconds := -1
var _pinging := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_chip()
	_build_boss_bar()
	_surge = _marker("SURGE", SURGE_COLOR, "portal", Vector3(0, 3.0, 0))
	_bounty = _marker("BOUNTY", UiKit.AMBER, "kiosk", Vector3(0, 2.7, 0))


func bind(director: RunDirector, player: Player) -> void:
	_director = director
	_player = player
	_surge.camera = player.camera
	_bounty.camera = player.camera
	director.boss_changed.connect(_on_boss_changed)
	director.bounty_changed.connect(_on_bounty_changed)
	director.surge_warning.connect(_on_surge_warning)
	director.state_changed.connect(func(_s): _refresh_chip())
	director.run_finished.connect(func(_r): visible = false)
	_chip.add_theme_color_override("font_color", Difficulty.color(director.difficulty))
	_refresh_chip()


func _process(delta: float) -> void:
	if _director == null:
		return
	_time += delta
	var boss := _director.boss
	if is_instance_valid(boss):
		_shown_health = move_toward(_shown_health, boss.health_fraction(), delta * 0.8)
		_boss_bar.value = _shown_health
	_surge.visible = _director.surge_point() != null
	if is_instance_valid(_director.bounty):
		var seconds := int(ceil(_director.bounty_seconds_left()))
		if seconds != _bounty_seconds:
			_bounty_seconds = seconds
			_bounty.label = "BOUNTY  %ds" % seconds
	if _director.is_closing_out():
		_pinging = true
		queue_redraw()
	elif _pinging:
		_pinging = false
		queue_redraw()


# --- chip ----------------------------------------------------------------------

func _build_chip() -> void:
	_chip = UiKit.label("", 22, UiKit.CYAN, true)
	var plate := UiKit.box(Color(UiKit.INK, 0.6), Color.TRANSPARENT, 12, 0, 0)
	plate.content_margin_left = 12
	plate.content_margin_right = 12
	plate.content_margin_top = 1
	plate.content_margin_bottom = 2
	_chip.add_theme_stylebox_override("normal", plate)
	_chip.position = Vector2(MARGIN + 4, CHIP_Y)
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chip)


## "HARD  ·  RUNNER RUSH" in a wave, "HARD  ·  NEXT: RUNNER RUSH" before it.
func _refresh_chip() -> void:
	var text := Difficulty.label(_director.difficulty)
	var wave: WaveData = null
	var upcoming := _director.is_intermission()
	if upcoming and _director.wave_number < _director.total_waves():
		wave = _director.waves.waves[_director.wave_number]
	elif _director.state == RunDirector.State.WAVE:
		wave = _director.current_wave()
	if wave and wave.title != "":
		text += "  ·  %s%s" % ["NEXT: " if upcoming else "", wave.title]
	_chip.text = text
	_chip.visible = _director.state != RunDirector.State.CLEARED and _director.state != RunDirector.State.DEFEAT


# --- boss bar ------------------------------------------------------------------

func _build_boss_bar() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.position = Vector2.ZERO
	box.offset_left = 0.0
	box.offset_right = 0.0
	box.offset_top = BAR_TOP
	box.offset_bottom = BAR_TOP
	_boss_name = UiKit.arcade_label("", 40, UiKit.PINK_LIGHT)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_boss_name)
	_boss_bar = UiKit.progress(1.0, BAR_HEIGHT, UiKit.PINK)
	_boss_bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_boss_bar.add_theme_stylebox_override("background", UiKit.box(Color(UiKit.INK, 0.9), UiKit.CREAM, int(BAR_HEIGHT / 2), 3, 0))
	_boss_fill = UiKit.box(UiKit.PINK, Color.TRANSPARENT, int(BAR_HEIGHT / 2), 0, 0)
	_boss_bar.add_theme_stylebox_override("fill", _boss_fill)
	box.add_child(_boss_bar)
	_boss_notches = Control.new()
	_boss_notches.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.add_child(_boss_notches)
	_boss_notches.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boss_box = box
	box.visible = false


func _on_boss_changed(boss: Zombie) -> void:
	if boss == null:
		var fade := _boss_box.create_tween()
		fade.tween_property(_boss_bar, "value", 0.0, 0.3)
		fade.tween_property(_boss_box, "modulate:a", 0.0, 0.6).set_delay(0.5)
		fade.tween_callback(func(): _boss_box.visible = false)
		return
	_boss_name.text = boss.data.display_name.to_upper()
	var tint := UiKit.PINK
	var thresholds := PackedFloat32Array()
	for b in boss.behaviours:
		if b is AlphaBossBehaviour:
			tint = b.color
			thresholds = b.phases
	_boss_fill.bg_color = tint
	_boss_name.add_theme_color_override("font_color", tint.lightened(0.35))
	for c in _boss_notches.get_children():
		c.queue_free()
	for t in thresholds:
		var notch := ColorRect.new()
		notch.color = UiKit.CREAM
		notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		notch.size = Vector2(4, BAR_HEIGHT)
		notch.position = Vector2(BAR_WIDTH * t - 2.0, 0)
		_boss_notches.add_child(notch)
	_shown_health = 1.0
	_boss_bar.value = 1.0
	_boss_box.visible = true
	_boss_box.modulate.a = 0.0
	_boss_box.pivot_offset = Vector2(BAR_WIDTH * 0.5, 30)
	_boss_box.scale = Vector2(1.2, 1.2)
	var pop := _boss_box.create_tween().set_parallel()
	pop.tween_property(_boss_box, "modulate:a", 1.0, 0.25)
	pop.tween_property(_boss_box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- markers -------------------------------------------------------------------

func _marker(text: String, color: Color, icon: String, offset: Vector3) -> Waypoint:
	var w := Waypoint.new()
	w.label = text
	w.color = color
	w.icon = icon
	w.offset = offset
	w.visible = false
	add_child(w)
	return w


func _on_surge_warning(point: Node3D, _seconds: float) -> void:
	_surge.target = point
	_surge.visible = true


func _on_bounty_changed(target: Zombie) -> void:
	_bounty.target = target
	_bounty.visible = target != null


## Pings over the last few zombies of a wave, so nobody has to hunt for them.
func _draw() -> void:
	if _director == null or _player == null or not _director.is_closing_out():
		return
	var camera := _player.camera
	var rect := get_viewport_rect().size
	var pulse := 0.6 + 0.4 * sin(_time * 7.0)
	for z in _director.alive_enemies():
		if not is_instance_valid(z) or z.is_dead() or z == _director.bounty:
			continue
		var world := z.global_position + Vector3.UP * (2.2 * z.data.body_scale + 0.5)
		var behind := camera.is_position_behind(world)
		var p := camera.unproject_position(world)
		if behind:
			p = rect - p
			p.y = rect.y - 70.0
		p = p.clamp(Vector2(60, 60), rect - Vector2(60, 60))
		var c := Color(PING_COLOR, pulse)
		var dark := Color(UiKit.INK, 0.85)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-15, -15), p + Vector2(15, -15), p + Vector2(0, 9)]), dark)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-10, -12), p + Vector2(10, -12), p + Vector2(0, 4)]), c)
