class_name IntroOverlay
extends Control
## The startup sequence, played once per session over the main menu:
##   0.0  black; a boot blip and a pulse line races across the screen
##   0.5  a synthwave sun rises behind a scrolling neon grid
##   1.2  the title drops in letter by letter (a tick per letter), glitching
##   2.6  "PRESS ANY KEY" pulses; any key/click (or 7 s) opens the menu
##        through a portal iris that reveals the live 3D backdrop.
## Any input before the title lands skips straight to the end of the build.

signal finished

var _time := 0.0
var _logo: NeonLogo
var _prompt: Label
var _iris: ColorRect
var _iris_mat: ShaderMaterial
var _closing := false
var _ready_for_input := false
var _glitch := 0.0
var _flash := 0.0
var _logo_home := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The black (and everything drawn in _draw) sits inside this iris rect.
	_iris = ColorRect.new()
	_iris.color = Color(0.03, 0.01, 0.08)
	_iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_iris.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_iris_mat = ShaderMaterial.new()
	_iris_mat.shader = load("res://art/shaders/ui_iris.gdshader")
	_iris.material = _iris_mat
	add_child(_iris)
	_iris.show_behind_parent = true
	_logo = NeonLogo.new()
	_logo.size_px = 168
	add_child(_logo)
	_logo.letter_landed.connect(_on_letter)
	_prompt = UiKit.arcade_label("PRESS ANY KEY", 38, UiKit.CYAN)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.modulate.a = 0.0
	add_child(_prompt)
	resized.connect(_layout)
	_layout.call_deferred()
	_logo.appear(1.2, 0.075)
	Sfx.play(&"intro_boot", -4.0)
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.tween_callback(func(): Sfx.play(&"intro_swell", -3.0))
	tw.tween_interval(2.0)
	tw.tween_callback(func():
		_ready_for_input = true
		Sfx.play(&"title_hit", -2.0)
		_flash = 1.0)
	tw.tween_interval(4.5)
	tw.tween_callback(close)


func _layout() -> void:
	var s := size
	_logo_home = Vector2(s.x * 0.5 - _logo.custom_minimum_size.x * 0.5, s.y * 0.2)
	_logo.position = _logo_home
	_prompt.size = Vector2(s.x, 50)
	_prompt.position = Vector2(0, s.y * 0.82)
	_iris_mat.set_shader_parameter("aspect", Vector2(s.x / maxf(1.0, s.y), 1.0))


func _on_letter(_i: int) -> void:
	Sfx.play(&"title_tick", -10.0, randf_range(0.95, 1.1))
	_glitch = 0.18


func _gui_input(event: InputEvent) -> void:
	_handle(event)


func _unhandled_input(event: InputEvent) -> void:
	_handle(event)


func _handle(event: InputEvent) -> void:
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed()
	if not pressed or _closing:
		return
	get_viewport().set_input_as_handled()
	if not _ready_for_input:
		# Skip the build-up: show the finished title immediately.
		_logo.show_now()
		_time = maxf(_time, 2.6)
		_ready_for_input = true
		_flash = 0.6
		return
	close()


func close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.play(&"ui_whoosh", -3.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_logo, "modulate:a", 0.0, 0.35)
	tw.tween_property(_prompt, "modulate:a", 0.0, 0.2)
	tw.tween_method(func(r: float): _iris_mat.set_shader_parameter("radius", r), 0.0, 1.3, 0.9).set_delay(0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		finished.emit()
		queue_free())


func _process(delta: float) -> void:
	_time += delta
	_glitch = maxf(0.0, _glitch - delta)
	_flash = maxf(0.0, _flash - delta * 2.5)
	if _ready_for_input and not _closing:
		_prompt.modulate.a = 0.55 + 0.45 * sin(_time * 4.0)
	# Glitch jitter on the title while letters land.
	_logo.position = _logo_home + Vector2((randf() - 0.5) * 14.0 * _glitch, 0.0)
	queue_redraw()


func _draw() -> void:
	if _closing and _iris_mat.get_shader_parameter("radius") > 1.2:
		return
	var s := size
	var horizon := s.y * 0.62
	var t := _time
	var fade_in := clampf((t - 0.35) / 0.8, 0.0, 1.0)
	if _closing:
		fade_in *= 1.0 - clampf(float(_iris_mat.get_shader_parameter("radius")) / 1.2, 0.0, 1.0)

	# Sky gradient bands.
	for i in 24:
		var k := float(i) / 24.0
		var c := Color("0b0623").lerp(Color("5a1b6e"), k * k).lerp(Color("ff5aa0"), maxf(0.0, k - 0.7) * 1.6)
		draw_rect(Rect2(0, horizon * k, s.x, horizon / 24.0 + 1.0), Color(c, fade_in))

	# Synthwave sun with cut stripes, rising.
	var rise := ease(clampf((t - 0.5) / 1.4, 0.0, 1.0), -2.0)
	var sun_c := Vector2(s.x * 0.5, horizon - s.y * 0.05 - rise * s.y * 0.1)
	var sun_r := s.y * 0.2
	draw_circle(sun_c, sun_r * 1.5, Color(1.0, 0.35, 0.6, 0.12 * fade_in))
	draw_circle(sun_c, sun_r * 1.2, Color(1.0, 0.45, 0.55, 0.15 * fade_in))
	var bands := 22
	for i in bands:
		var y0 := sun_c.y - sun_r + 2.0 * sun_r * float(i) / bands
		var dy := y0 - sun_c.y
		var half := sqrt(maxf(0.0, sun_r * sun_r - dy * dy))
		var k := float(i) / bands
		var gap := k > 0.5 and int(i) % 3 == 0
		if gap or y0 > horizon:
			continue
		var c := Color("ffe14a").lerp(Color("ff3fa4"), k)
		draw_rect(Rect2(sun_c.x - half, y0, half * 2.0, 2.0 * sun_r / bands + 1.0), Color(c, fade_in))

	# Ground and perspective grid scrolling toward the viewer.
	draw_rect(Rect2(0, horizon, s.x, s.y - horizon), Color(Color("12052a"), fade_in))
	var grid_a := fade_in * 0.85
	var cyan := Color(UiKit.CYAN, grid_a)
	var pink := Color(UiKit.PINK, grid_a)
	for i in range(-16, 17):
		var x_far := s.x * 0.5 + i * s.x * 0.035
		var x_near := s.x * 0.5 + i * s.x * 0.32
		draw_line(Vector2(x_far, horizon), Vector2(x_near, s.y), Color(pink, grid_a * 0.7), 2.0, true)
	var scroll := fmod(t * 0.6, 1.0)
	for i in 14:
		var z := (float(i) + scroll) / 14.0
		var y := horizon + (s.y - horizon) * pow(z, 2.2)
		draw_line(Vector2(0, y), Vector2(s.x, y), Color(cyan, grid_a * z), 1.5 + z * 2.0, true)
	draw_line(Vector2(0, horizon), Vector2(s.x, horizon), Color(Color("ff9ad0"), fade_in), 3.0, true)

	# The opening pulse line racing across the screen.
	var pulse := clampf(t / 0.5, 0.0, 1.0)
	if t < 1.2:
		var a := 1.0 - clampf((t - 0.5) / 0.7, 0.0, 1.0)
		var pts := PackedVector2Array()
		for i in 60:
			var x := s.x * float(i) / 59.0
			if x > s.x * pulse:
				break
			var beat := exp(-pow((float(i) - 30.0) / 2.5, 2.0)) * 80.0 * sin(float(i) * 1.7)
			pts.append(Vector2(x, horizon + beat))
		if pts.size() > 1:
			draw_polyline(pts, Color(UiKit.CYAN, a), 4.0, true)
			draw_polyline(pts, Color(1, 1, 1, a), 1.5, true)

	# Title-hit flash.
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.85, 0.95, _flash * 0.35 * Settings.flash_scale()))
