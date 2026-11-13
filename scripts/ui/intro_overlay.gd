class_name IntroOverlay
extends Control
## The startup sequence, played once per session over the main menu
## (scored by audio/sfx/cine_startup.wav, tools/audio_packs/showreel.py: a
## warm, low score that builds from silence, no bright stings):
##   0.0  a Spark glows up in the dark with a soft ring of light
##   1.4  a montage of four real-time vignettes on the showreel's studio set
##        (a zombie, a weapon in an animated finish with a spinning charm, a
##        kill effect, three operators), one cut per beat, no words
##   4.6  the logo rises in as a marquee sign with chasing bulbs, the montage
##        dissolves to the live menu backdrop, the tagline lands
##   5.4  the feature counts pop in (real numbers from GameData)
##   7.2  "PRESS ANY KEY" over the live backdrop; any key opens the menu
## The first key/click before 7.2 skips to that end state; the next closes.
## The montage's models load on threads behind the boot sting, so the first
## frame never waits on a load.

signal finished

const HOLD_AT := 7.2
const MONTAGE_AT := 1.4
const LOGO_AT := 4.6
const CUT := 0.8
## Longest the montage waits for its models before taking them as they are.
const MONTAGE_WAIT := 0.6
const ZOMBIE_SCENE := "res://scenes/enemies/zombie.tscn"
const SPARK_TEX := &"icon_spark"
## The montage's featured items (by id).
const ZOMBIE := &"tourist_shambler"
const WEAPON := &"ion_carbine"
const FINISH := &"fin_marquee"
const CHARM := &"charmx_ferris_wheel"
const KILL_EFFECT := &"kfx_disco"
const TRACER := &"tracer_neon"
const OPERATORS: Array[StringName] = [&"op_pixel_pal", &"op_windup", &"op_cosmic_sheriff"]

var _time := 0.0
var _closing := false
var _at_end := false
var _bg: ColorRect
var _shade: ColorRect
var _spark: TextureRect
var _ring := 0.0
var _view: SubViewportContainer
var _viewport: SubViewport
var _camera: Camera3D
var _actors: Node3D
var _stage: CineStage
var _shot := -1
var _shots: Array[CineShot] = []
var _logo: MarqueeSign
var _tagline: Label
var _chips: HBoxContainer
var _prompt: Label
var _flash := 0.0
var _fx: Control
var _score: AudioStreamPlayer
var _paused: Array[AudioStreamPlayer] = []
var _preload: PackedStringArray = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg = _rect(Color(0.02, 0.01, 0.06))
	_view = SubViewportContainer.new()
	_view.stretch = true
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.visible = false
	add_child(_view)
	_shade = _rect(Color(0.02, 0.0, 0.08, 0.0))
	_spark = UiKit.icon(SPARK_TEX, 240.0, Wallet.COLOR)
	_spark.pivot_offset = Vector2(120, 120)
	_spark.scale = Vector2.ONE * 0.6
	_spark.modulate.a = 0.0
	add_child(_spark)
	_build_title()
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	resized.connect(_layout)
	_layout.call_deferred()
	_hush_menu_music()
	_score = AudioStreamPlayer.new()
	_score.stream = Sfx.stream(&"cine_startup")
	_score.bus = &"Music"
	_score.volume_db = Sfx.mix_db(&"cine_startup") - 6.0
	add_child(_score)
	_score.play()
	_start_loads()
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(_spark, "modulate:a", 1.0, 0.7).set_delay(0.2)
	tw.parallel().tween_property(_spark, "scale", Vector2.ONE, 1.0).set_delay(0.2).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _ring = 0.001)
	tw.tween_property(_spark, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(_spark, "scale", Vector2.ONE * 1.4, 0.3)


func _rect(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(r)
	return r


func _build_title() -> void:
	_logo = UiKit.marquee("WHAT LIES AHEAD", 150)
	_logo.modulate.a = 0.0
	add_child(_logo)
	_tagline = UiKit.arcade_label("AN ARCADE ZOMBIE SURVIVAL", 48, UiKit.CYAN)
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tagline.modulate.a = 0.0
	add_child(_tagline)
	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override("separation", UiKit.GAP_M)
	_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_chips)
	var colors := [UiKit.CYAN, UiKit.PINK, UiKit.AMBER, UiKit.CYAN, UiKit.PINK]
	var counts := [
		"%d WORLDS" % GameData.worlds().size(), "%d WEAPONS" % GameData.weapons().size(),
		"%d ZOMBIES" % GameData.enemies().size(), "%d OPERATORS" % GameData.cosmetics().filter(func(c): return c.slot == &"avatar").size(),
		"%d COSMETICS" % GameData.cosmetics().size()]
	for i in counts.size():
		var c := UiKit.chip(counts[i], colors[i], 36)
		c.modulate.a = 0.0
		_chips.add_child(c)
	_prompt = UiKit.arcade_label("PRESS ANY KEY", 56, UiKit.CREAM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.modulate.a = 0.0
	add_child(_prompt)


func _layout() -> void:
	var s := size
	_spark.position = s * 0.5 - Vector2(120, 120)
	_logo.reset_size()
	_logo.position = Vector2(s.x * 0.5 - _logo.size.x * 0.5, s.y * 0.2)
	_logo.pivot_offset = _logo.size * 0.5
	_tagline.size = Vector2(s.x, 56)
	_tagline.position = Vector2(0, _logo.position.y + _logo.size.y + 22.0)
	_chips.reset_size()
	_chips.position = Vector2(s.x * 0.5 - _chips.size.x * 0.5, s.y * 0.6)
	_prompt.size = Vector2(s.x, 60)
	_prompt.position = Vector2(0, s.y * 0.8)


## Pauses the menu theme (and ambience) for the length of the score.
func _hush_menu_music() -> void:
	for c in Sfx.get_children():
		var p := c as AudioStreamPlayer
		if p and p.playing and not p.stream_paused:
			p.stream_paused = true
			_paused.append(p)


func _resume_menu_music() -> void:
	for p in _paused:
		if is_instance_valid(p):
			p.stream_paused = false
	_paused.clear()


# --- montage -------------------------------------------------------------------

func _start_loads() -> void:
	_preload = [ZOMBIE_SCENE, GameData.weapon(WEAPON).viewmodel.resource_path]
	for id in OPERATORS:
		_preload.append(Operators.model_path(Cosmetics.item(id)))
	for path in _preload:
		if ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path)
	_shots = [
		CineShot.make("zombie", "studio", CUT, _v_zombie),
		CineShot.make("weapon", "studio", CUT, _v_weapon),
		CineShot.make("kill", "studio", CUT, _v_kill),
		CineShot.make("operators", "studio", CUT, _v_operators),
	]


## Builds the montage's stage once its models have loaded. False while they
## are still loading (the spark holds the screen a moment longer); past
## MONTAGE_WAIT it stops waiting and takes them as they are.
func _ensure_montage() -> bool:
	if _viewport:
		return true
	if _time < MONTAGE_AT + MONTAGE_WAIT:
		for path in _preload:
			if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				return false
	for path in _preload:
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_get(path)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.audio_listener_enable_3d = false
	_view.add_child(_viewport)
	_viewport.add_child(CineStudio.new())
	_camera = Camera3D.new()
	_viewport.add_child(_camera)
	_camera.make_current()
	return true


func _cut_to(i: int) -> void:
	_shot = i
	if _actors:
		_actors.queue_free()
	_actors = Node3D.new()
	_viewport.add_child(_actors)
	_stage = CineStage.new(_actors, _camera, null, null, CUT)
	_shots[i].build.call(_stage)
	_stage.update(0.0, 0.0)


func _end_montage() -> void:
	Engine.time_scale = 1.0
	Sfx.cut_positional()
	_stage = null
	if _viewport:
		_view.visible = false
		_viewport.queue_free()
		_viewport = null
		_actors = null


func _v_zombie(st: CineStage) -> void:
	var z := st.zombie(ZOMBIE, Vector3(0, 0.42, 0), 0.0, "Roar", 0.6)
	st.fov(30.0, 24.0)
	st.dolly(Vector3(0.4, 1.85, 3.4), st.head(z) + Vector3(0, -0.3, 0), Vector3(0.2, 1.9, 2.7), st.head(z) + Vector3(0, -0.25, 0))


func _v_weapon(st: CineStage) -> void:
	var model := st.weapon(WEAPON, FINISH, CHARM)
	var pivot := Node3D.new()
	st.actors.add_child(pivot)
	pivot.position = Vector3(0, 1.25, 0)
	pivot.add_child(model)
	var box := WeaponCosmetics.visible_bounds(model)
	model.position = -box.get_center()
	pivot.scale = Vector3.ONE * 1.5 / maxf(0.01, maxf(box.size.x, maxf(box.size.y, box.size.z)))
	st.every_frame(func(t: float):
		pivot.rotation.y = deg_to_rad(-60.0 + t * 70.0)
		pivot.rotation.z = sin(t * 4.0) * 0.08)
	st.fov(30.0, 27.0)
	st.dolly(Vector3(0, 1.45, 2.6), Vector3(0, 1.25, 0), Vector3(0, 1.4, 2.2), Vector3(0, 1.25, 0))


func _v_kill(st: CineStage) -> void:
	var z := st.zombie(&"lifeguard_runner", Vector3(0, 0.42, 0), 20.0, "Walk", 0.7)
	st.fov(36.0, 32.0)
	st.dolly(Vector3(1.0, 1.6, 3.4), Vector3(0, 1.3, 0), Vector3(0.7, 1.5, 3.0), Vector3(0, 1.2, 0))
	st.slowmo(0.1, 0.8, 0.4)
	st.at(0.12, func():
		st.shoot(&"pulse_pistol", Vector3(3.5, 1.6, 1.0), st.head(z), 1.0, false, TRACER)
		st.kill(z, &"pulse_pistol", true, Vector3(-1, 0, -0.3), 3.0, KILL_EFFECT))


func _v_operators(st: CineStage) -> void:
	for i in OPERATORS.size():
		st.operator(OPERATORS[i], Vector3((i - 1) * 1.15, 0.0 if i != 1 else 0.42, -absf(i - 1) * 0.4), -(i - 1) * 8.0, "Pose")
	st.fov(38.0, 34.0)
	st.dolly(Vector3(-1.2, 1.3, 3.8), Vector3(0, 1.2, 0), Vector3(1.0, 1.25, 3.4), Vector3(0, 1.25, 0))


# --- title -------------------------------------------------------------------------

func _show_title(instant: bool) -> void:
	_bg.color.a = 0.0
	_shade.color = Color(0.02, 0.0, 0.08, 0.4)
	_spark.visible = false
	var d := 0.0 if instant else 1.0
	if instant:
		_logo.modulate.a = 1.0
		_logo.scale = Vector2.ONE
		_tagline.modulate.a = 1.0
		for c in _chips.get_children():
			c.modulate.a = 1.0
		return
	_logo.scale = Vector2.ONE * 1.12
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_logo, "scale", Vector2.ONE, 0.9 * d).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(_logo, "modulate:a", 1.0, 0.5 * d).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_logo.flash).set_delay(0.5)
	tw.tween_property(_tagline, "modulate:a", 1.0, 0.3).set_delay(0.45)
	for i in _chips.get_child_count():
		var c := _chips.get_child(i)
		c.scale = Vector2.ONE
		tw.tween_property(c, "modulate:a", 1.0, 0.12).set_delay(1.0 + i * 0.25)
	_flash = 0.35


## Takes every key, click and button before the menu underneath sees it.
func _input(event: InputEvent) -> void:
	_handle(event)


func _handle(event: InputEvent) -> void:
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed()
	get_viewport().set_input_as_handled()
	if not pressed or _closing or event.is_echo():
		return
	if not _at_end:
		_skip_to_end()
		return
	close()


## Jumps to the held title: logo, tagline, counts and the prompt.
func _skip_to_end() -> void:
	_time = maxf(_time, HOLD_AT)
	_end_montage()
	_show_title(true)
	_reach_hold()


func _reach_hold() -> void:
	_at_end = true
	_score.stop()
	_resume_menu_music()


func close() -> void:
	if _closing:
		return
	_closing = true
	_end_montage()
	_score.stop()
	_resume_menu_music()
	Sfx.play(&"ui_whoosh", -3.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		finished.emit()
		queue_free())


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.0001)
	_time += real
	_flash = maxf(0.0, _flash - real * 3.0)
	if _ring > 0.0:
		_ring += real * 1.6
	if not _at_end and not _closing:
		_run_timeline()
	if _at_end and not _closing:
		_prompt.modulate.a = 0.55 + 0.45 * sin(_time * 4.0)
	_fx.queue_redraw()


func _run_timeline() -> void:
	if _time >= MONTAGE_AT and _time < LOGO_AT:
		if not _ensure_montage():
			return
		_view.visible = true
		var i := clampi(int((_time - MONTAGE_AT) / CUT), 0, _shots.size() - 1)
		if i != _shot:
			_cut_to(i)
		_stage.update(_time - MONTAGE_AT - i * CUT, get_process_delta_time())
	elif _time >= LOGO_AT and _logo.modulate.a == 0.0:
		_end_montage()
		_show_title(false)
	if _time >= HOLD_AT:
		_reach_hold()


func _draw_fx() -> void:
	var s := size
	if _ring > 0.0 and _ring < 1.2:
		var c := s * 0.5
		var r := _ring * s.y * 0.6
		_fx.draw_arc(c, r, 0.0, TAU, 96, Color(Wallet.COLOR_GLOW, 1.0 - _ring / 1.2), 10.0 * (1.2 - _ring), true)
		_fx.draw_arc(c, r * 0.7, 0.0, TAU, 96, Color(Wallet.COLOR, 0.6 * (1.0 - _ring / 1.2)), 4.0, true)
	if _flash > 0.0:
		_fx.draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.92, 0.97, _flash * 0.4 * Settings.flash_scale()))
