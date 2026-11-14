class_name CapsuleReveal
extends Control
## The opening of a Prize Capsule, full screen. The machine fills the screen
## and its crank turns with weight while the capsules churn; one drops and
## the camera pushes in on the chute. The capsule wobbles in the middle of
## the screen with light of its rarity leaking from the seam (the rarer, the
## longer and harder), over a music cue that swells with it (prz_build). It
## bursts in a reveal of its rarity (confetti, streamers, rings and rays;
## Legendary turns the screen gold under a rain of gold), the cue resolves
## (prz_reveal_<rarity>), and the print lands on the hero card (PrintHero).
## OPEN 5 drops five capsules in a row that pop one after another, the best
## last. The first click, Enter or Esc jumps to the result; Esc closes.
##
##   reveal.play(PrizePrints.open_capsule(), weapon, can_open_more)
##   reveal.play_multi(results, weapons, can_open_five)
##   reveal.closed / another_requested(count) / equip_requested(print)

signal closed
signal another_requested(count: int)
signal equip_requested(p: Dictionary)

## Seconds the capsule wobbles before it bursts, per rarity.
const WOBBLE := [1.0, 1.5, 2.1, 2.9]
## Length of the build cue (audio/sfx/prz_build.wav); it starts part-way in
## so its peak lands on the burst.
const BUILD_LENGTH := 4.0
const BANNERS := ["COMMON", "RARE!", "EPIC!", "LEGENDARY!"]
const MULTI := 5

var result: Dictionary = {}
## The page's thumbnail baker (the OPEN 5 cards).
var thumbs: CosmeticThumbs
var _results: Array = []
var _weapons: Array = []
var _seq: Tween
var _burst_done := false
var _multi := false
var _can_more := false
var _dim: ColorRect
var _fx: RevealFx
var _machine: CapsuleMachine
var _capsule: BigCapsule
var _hero: PrintHero
var _banner: Label
var _flash: ColorRect
var _hint: Label
var _cue: AudioStreamPlayer
var _knocks := 0
var _wobble_time := 1.0
# OPEN 5.
var _row: HBoxContainer
var _slots: Array[MultiSlot] = []
var _multi_panel: VBoxContainer
var _multi_summary: Label
var _multi_more: SignButton
var _multi_done: SignButton


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(UiKit.INK, 0.94)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_fx = RevealFx.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fx)
	_machine = CapsuleMachine.new()
	_machine.series_text = "SERIES %d" % PrizePrints.series().number
	_machine.series_name = PrizePrints.series().display_name.to_upper()
	add_child(_machine)
	_build_multi()
	_hero = PrintHero.new()
	_hero.another_requested.connect(func(): another_requested.emit(1))
	_hero.equip_requested.connect(func(p: Dictionary): equip_requested.emit(p))
	_hero.done_requested.connect(_on_hero_done)
	_hero.landed.connect(func(): _hint.visible = false)
	add_child(_hero)
	_capsule = BigCapsule.new()
	add_child(_capsule)
	_banner = UiKit.arcade_label("", 120, UiKit.AMBER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_hint = UiKit.label("CLICK TO SKIP", UiKit.SIZE_SMALL, Color(UiKit.MUTED, 0.8), true)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_bottom = -UiKit.GAP_L
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_cue = AudioStreamPlayer.new()
	_cue.bus = &"UI"
	add_child(_cue)


func _build_multi() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_multi_panel = VBoxContainer.new()
	_multi_panel.add_theme_constant_override("separation", UiKit.GAP_L)
	_multi_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_multi_panel)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", UiKit.GAP_L)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_multi_panel.add_child(_row)
	for i in MULTI:
		var slot := MultiSlot.new()
		slot.card.pressed.connect(_inspect_multi.bind(i))
		_row.add_child(slot)
		_slots.append(slot)
	_multi_summary = UiKit.label("", UiKit.SIZE_LABEL, UiKit.CREAM, true)
	_multi_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_multi_panel.add_child(_multi_summary)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", UiKit.GAP_M)
	_multi_panel.add_child(buttons)
	_multi_more = UiKit.sign_button("OPEN 5 MORE", SignButton.Kind.PRIMARY, 30)
	_multi_more.pressed.connect(func(): another_requested.emit(MULTI))
	buttons.add_child(_multi_more)
	_multi_done = UiKit.sign_button("DONE", SignButton.Kind.NEUTRAL, 30)
	_multi_done.pressed.connect(close)
	buttons.add_child(_multi_done)


# --- one capsule ----------------------------------------------------------------------------

## Plays the opening of `res` (a PrizePrints.open_capsule result) shown on
## `weapon`; `can_open_more` offers OPEN ANOTHER at the end.
func play(res: Dictionary, weapon: WeaponData, can_open_more: bool) -> void:
	result = res
	_multi = false
	var p: Dictionary = res["print"]
	var rarity := PrizePrints.rarity(p)
	var col := PrintLook.rarity_color(p)
	_begin()
	_hero.setup(res, weapon, PrintHero.Style.CARNIVAL, _fx, can_open_more)
	_wobble_time = WOBBLE[clampi(rarity, 0, 3)]
	_capsule.color = col
	_seq = create_tween()
	_machine_in(_seq)
	_seq.tween_callback(_machine.turn.bind(col, true))
	_seq.tween_interval(2.0)
	_seq.tween_callback(_push_in)
	_seq.tween_interval(0.55)
	_seq.tween_callback(_start_cue)
	_knocks = 0
	_seq.tween_method(_wobble, 0.0, 1.0, _wobble_time)
	_seq.tween_callback(_burst.bind(rarity, col))
	_seq.tween_interval([0.5, 0.6, 0.8, 1.6][clampi(rarity, 0, 3)])
	_seq.tween_callback(_land)


## Shared start: the overlay, the machine at full size, nothing else.
func _begin() -> void:
	visible = true
	_burst_done = false
	_fx.clear()
	_fx.centre = size * Vector2(0.5, 0.46)
	_hero.visible = false
	_multi_panel.get_parent().visible = false
	_banner.visible = false
	_capsule.visible = false
	_capsule.reset()
	_flash.color.a = 0.0
	_hint.visible = true
	_dim.modulate.a = 0.0
	var h := size.y * 0.9
	_machine.size = Vector2(h * CapsuleMachine.DESIGN.x / CapsuleMachine.DESIGN.y, h)
	_machine.position = (size - _machine.size) * 0.5
	_machine.pivot_offset = _machine.size * 0.5
	_machine.scale = Vector2.ONE
	_machine.modulate.a = 1.0
	_machine.visible = true
	_machine.capsule_count = PrizePrints.capsules()


func _machine_in(tw: Tween) -> void:
	tw.tween_property(_dim, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(_machine, "scale", Vector2.ONE, 0.4).from(Vector2.ONE * 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_machine, "modulate:a", 1.0, 0.2).from(0.0)


## The camera pushes in on the chute; the capsule leaves it for the middle of the screen.
func _push_in() -> void:
	Sfx.play(&"prz_whoosh", -6.0)
	var chute := _machine.chute_point()
	_machine.pivot_offset = chute
	var start := _machine.position + chute
	var radius := _machine.chute_capsule_radius()
	_machine.take_capsule()
	_capsule.visible = true
	_capsule.size = Vector2(300, 300)
	_capsule.pivot_offset = _capsule.size * 0.5
	_capsule.position = start - _capsule.size * 0.5
	_capsule.scale = Vector2.ONE * (radius / (_capsule.size.x * 0.36))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_machine, "scale", Vector2.ONE * 3.2, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_machine, "modulate:a", 0.0, 0.45).set_delay(0.1)
	tw.tween_property(_capsule, "position", size * Vector2(0.5, 0.48) - _capsule.size * 0.5, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_capsule, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_fx, "rays", 0.35, 0.5)


## The build cue, started so that its peak lands on the burst.
func _start_cue() -> void:
	_cue.stream = Sfx.stream(&"prz_build")
	if _cue.stream:
		_cue.volume_db = -4.0 + Sfx.mix_db(&"prz_build")
		_cue.play(maxf(0.0, BUILD_LENGTH - _wobble_time))


## t 0-1 through the wobble: it rocks faster and harder, hops, and light
## leaks from the seam; a knock on every swing.
func _wobble(t: float) -> void:
	var phase := t * _wobble_time * TAU * (1.1 + 1.9 * t)
	var amount := lerpf(0.05, 0.3, pow(t, 1.4))
	_capsule.rotation = sin(phase) * amount
	_capsule.shake = Vector2(0, -absf(sin(phase)) * 22.0 * t * t)
	_capsule.leak = pow(t, 1.3)
	_capsule.glow = t
	_fx.rays = 0.35 + 0.4 * t
	var knock := int(phase / PI)
	if knock > _knocks:
		_knocks = knock
		Sfx.play(&"prz_shake", -14.0 + 8.0 * t, 0.9 + 0.25 * t)


## The capsule bursts: a flash, the pop and the resolve, confetti by rarity.
## Legendary turns the screen gold.
func _burst(rarity: int, col: Color) -> void:
	_burst_done = true
	_cue.stop()
	Sfx.play(&"prz_pop", -3.0)
	Sfx.play(StringName("prz_reveal_%d" % rarity), -1.0)
	var at := _capsule.position + _capsule.size * 0.5
	_fx.color = col
	_fx.burst(rarity, at, col)
	_capsule.rotation = 0.0
	_capsule.shake = Vector2.ZERO
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_capsule, "open", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_flash, "color", Color(col.lerp(Color.WHITE, 0.6), 0.0), 0.55).from(Color(col.lerp(Color.WHITE, 0.6), 0.9))
	tw.tween_property(_fx, "rays", 1.0, 0.4)
	_show_banner(rarity, col)
	if rarity >= 3:
		tw.tween_property(_fx, "golden", 1.0, 0.5)
		_fx.rain(140)
		create_tween().tween_callback(_fx.rain.bind(70)).set_delay(0.7)


func _show_banner(rarity: int, col: Color) -> void:
	_banner.visible = true
	_banner.text = BANNERS[clampi(rarity, 0, 3)]
	_banner.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.3))
	_banner.add_theme_font_size_override("font_size", [72, 96, 120, 150][clampi(rarity, 0, 3)])
	_banner.size = Vector2(size.x, 200)
	_banner.position = Vector2(0, size.y * 0.46 - 100.0)
	_banner.pivot_offset = _banner.size * 0.5
	var tw := create_tween()
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.25).from(Vector2.ONE * 2.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_banner, "modulate:a", 1.0, 0.12).from(0.0)
	tw.tween_interval(0.3 + 0.3 * rarity)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.3)


## The capsule is gone; the hero card takes over.
func _land() -> void:
	_capsule.visible = false
	_machine.visible = false
	_banner.visible = false
	_hero.visible = true
	_hint.visible = true
	_fx.centre = _hero_centre()
	_hero.play()


func _hero_centre() -> Vector2:
	return size * Vector2(0.32, 0.45)


# --- OPEN 5 ----------------------------------------------------------------------------------

## Opens five capsules at once: one quick turn, five capsules in a row that
## wobble and pop one after another (the rarest last), each turning into
## its print's card. `weapons[i]` is the weapon `results[i]` is shown on.
func play_multi(results: Array, weapons: Array, can_open_five: bool) -> void:
	_multi = true
	_results = results
	_weapons = weapons
	_can_more = can_open_five
	_begin()
	_multi_panel.get_parent().visible = true
	_multi_summary.modulate.a = 0.0
	_multi_more.get_parent().modulate.a = 0.0
	_multi_more.visible = can_open_five
	for i in MULTI:
		_slots[i].visible = i < results.size()
		if i < results.size():
			_slots[i].prepare(results[i], weapons[i], thumbs)
	_seq = create_tween()
	_machine_in(_seq)
	_seq.tween_callback(_machine.turn.bind(Color.WHITE, false))
	_seq.tween_interval(1.25)
	_seq.tween_callback(_machine_away)
	_seq.tween_interval(0.35)
	for i in results.size():
		_seq.tween_callback(_slots[i].drop_in)
		_seq.tween_interval(0.1)
	_seq.tween_interval(0.35)
	for i in results.size():
		var rarity := PrizePrints.rarity(results[i]["print"])
		_seq.tween_method(_slots[i].wobble, 0.0, 1.0, 0.35 + 0.2 * rarity)
		_seq.tween_callback(_pop_slot.bind(i))
		_seq.tween_interval(0.25 + 0.15 * rarity)
	_seq.tween_callback(_multi_finish)


func _machine_away() -> void:
	_machine.take_capsule()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_machine, "modulate:a", 0.0, 0.3)
	tw.tween_property(_machine, "scale", Vector2.ONE * 1.3, 0.3)
	tw.tween_property(_fx, "rays", 0.4, 0.4)
	Sfx.play(&"prz_rattle", -6.0, 1.15)


func _pop_slot(i: int) -> void:
	var p: Dictionary = _results[i]["print"]
	var rarity := PrizePrints.rarity(p)
	var col := PrintLook.rarity_color(p)
	_slots[i].pop()
	var at := get_global_transform_with_canvas().affine_inverse() * (_slots[i].get_global_transform_with_canvas() * (_slots[i].size * 0.5))
	_fx.burst(maxi(0, rarity - 1), at, col)
	if rarity >= 3:
		_fx.golden = 1.0
		_fx.rain(90)
	Sfx.play(&"prz_pop", -6.0, 1.0 + 0.05 * i)
	Sfx.play(StringName("prz_reveal_%d" % rarity), -5.0 if rarity < 2 else -2.0)


func _multi_finish() -> void:
	_hint.visible = false
	var fresh := 0
	var tokens := 0
	for r in _results:
		if bool(r.get("recycled", false)):
			tokens += int(r.get("tokens", 0))
		elif not bool(r.get("repeat", false)):
			fresh += 1
	_multi_summary.text = "%d NEW  ·  %d REPEATS%s  ·  CLICK A PRINT FOR ITS DETAILS" % [fresh, _results.size() - fresh,
		("  ·  +%d PRIZE TOKENS" % tokens) if tokens > 0 else ""]
	UiFx.fade_in(_multi_summary, 0.25)
	UiFx.fade_in(_multi_more.get_parent(), 0.25)
	(_multi_more if _multi_more.visible else _multi_done).grab_focus.call_deferred()


## A card of OPEN 5 was clicked: its hero card, finished (DONE goes back to the row).
func _inspect_multi(i: int) -> void:
	if _seq and _seq.is_running():
		return
	_multi_panel.get_parent().visible = false
	_fx.rays = 0.6
	_hero.setup(_results[i], _weapons[i], PrintHero.Style.CARNIVAL, _fx, false)
	_hero.visible = true
	_hero.finish_now()


func _on_hero_done() -> void:
	if not _multi:
		close()
		return
	_hero.release()
	_hero.visible = false
	_multi_panel.get_parent().visible = true
	_multi_done.grab_focus.call_deferred()


# --- skip and close ----------------------------------------------------------------------------

func is_playing() -> bool:
	return (_seq != null and _seq.is_running()) or _hero.is_playing()


## Jumps to the end: the hero card (or the row of five), finished.
func skip() -> void:
	if _seq:
		_seq.kill()
	_cue.stop()
	_machine.take_capsule()
	_machine.visible = false
	_capsule.visible = false
	_banner.visible = false
	_flash.color.a = 0.0
	_dim.modulate.a = 1.0
	_fx.rays = 1.0
	if _multi:
		for slot in _slots:
			if slot.visible:
				slot.finish_now()
		_multi_finish()
		return
	var rarity := PrizePrints.rarity(result["print"])
	if not _burst_done:
		_burst_done = true
		Sfx.play(StringName("prz_reveal_%d" % rarity), -3.0)
		_fx.color = PrintLook.rarity_color(result["print"])
		_fx.golden = 1.0 if rarity >= 3 else 0.0
	_fx.centre = _hero_centre()
	_hero.visible = true
	_hero.finish_now()


func close() -> void:
	if _seq:
		_seq.kill()
	_cue.stop()
	_machine.take_capsule()
	_hero.release()
	for slot in _slots:
		slot.release()
	_fx.clear()
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible or not is_playing():
		return
	var click := event as InputEventMouseButton
	if (click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_accept") \
			or event.is_action_pressed("ui_cancel"):
		skip()
		get_viewport().set_input_as_handled()


## While the overlay is up it owns the keys: Esc steps back (see back()),
## and nothing reaches the menu behind it (Q / E would change page).
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey or event is InputEventJoypadButton) or not event.is_pressed():
		return
	if event.is_action_pressed("ui_cancel"):
		back()
	get_viewport().set_input_as_handled()


## BACK / Esc on a finished reveal: from a print of OPEN 5 back to the row, else close.
func back() -> void:
	if is_playing():
		skip()
	elif _multi and _hero.visible:
		_on_hero_done()
	else:
		close()


## The big two-tone capsule: it wobbles, glows, leaks light of its rarity
## from the seam, and splits open.
class BigCapsule extends Control:
	const LEAKS := 11
	var color := Color.WHITE
	var open := 0.0:
		set(v):
			open = v
			queue_redraw()
	var glow := 0.0:
		set(v):
			glow = v
			queue_redraw()
	var leak := 0.0:
		set(v):
			leak = v
			queue_redraw()
	var shake := Vector2.ZERO:
		set(v):
			shake = v
			queue_redraw()
	var _half := PackedVector2Array()
	var _tri := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	var _tri_cols := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in 25:
			var a := PI + PI * k / 24.0
			_half.append(Vector2(cos(a), sin(a)))

	func reset() -> void:
		open = 0.0
		glow = 0.0
		leak = 0.0
		shake = Vector2.ZERO
		rotation = 0.0
		scale = Vector2.ONE

	func _draw() -> void:
		var c := size * 0.5 + shake
		var r := size.x * 0.36
		for k in 5:
			draw_circle(c, r * (1.2 + k * 0.16 + glow * 0.35), Color(color, (0.05 + glow * 0.09) * (1.0 - open)))
		if leak > 0.0 and open < 0.5:
			_draw_leaks(c, r)
		var gap := open * r * 1.7
		var fade := 1.0 - open
		_draw_half(c + Vector2(-gap * 0.3, -gap), r, color, true, -open * 0.9, fade)
		_draw_half(c + Vector2(gap * 0.3, gap), r, UiKit.CREAM, false, open * 0.7, fade)
		if leak > 0.0 and open <= 0.0:
			draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(color.lerp(Color.WHITE, 0.6), leak), 4.0 + 6.0 * leak, true)

	## Thin beams of light fanning out of the seam.
	func _draw_leaks(c: Vector2, r: float) -> void:
		var bright := color.lerp(Color.WHITE, 0.4)
		for i in LEAKS:
			var x := (float(i) / (LEAKS - 1) - 0.5) * 1.8 * r
			var up := -1.0 if i % 2 == 0 else 1.0
			var length := r * (0.8 + 1.6 * leak) * (0.6 + 0.4 * sin(i * 2.3 + leak * 9.0))
			var spread := 0.08 + 0.05 * (i % 3)
			var dir := Vector2(x * 0.004, up).normalized()
			var base := c + Vector2(x * (1.0 - absf(x) / (r * 4.0)), 0)
			_tri[0] = base
			_tri[1] = base + dir.rotated(-spread) * length
			_tri[2] = base + dir.rotated(spread) * length
			_tri_cols[0] = Color(bright, 0.55 * leak)
			_tri_cols[1] = Color(color, 0.0)
			_tri_cols[2] = Color(color, 0.0)
			draw_polygon(_tri, _tri_cols)

	func _draw_half(at: Vector2, r: float, col: Color, top: bool, turn: float, alpha: float) -> void:
		if alpha <= 0.01:
			return
		draw_set_transform(at, turn, Vector2(r, r * (1.0 if top else -1.0)))
		draw_colored_polygon(_half, Color(col, alpha))
		draw_polyline(_half, Color(col.darkened(0.4), alpha), 4.0 / r, true)
		draw_set_transform(at, turn, Vector2.ONE)
		draw_line(Vector2(-r, 0), Vector2(r, 0), Color(col.darkened(0.4), alpha), 5.0, true)
		if top:
			draw_circle(Vector2(-r * 0.38, -r * 0.5), r * 0.16, Color(1, 1, 1, 0.65 * alpha))
		draw_set_transform(Vector2.ZERO)


## One of the five OPEN 5 places: a small capsule that drops in, wobbles
## and pops into its print's card.
class MultiSlot extends Control:
	const CARD := Vector2(232, 270)
	var card: PrintCard
	var _capsule: BigCapsule
	var _res: Dictionary

	func _init() -> void:
		custom_minimum_size = CARD
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		card = PrintCard.create(CARD)
		card.toggle_mode = false
		card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(card)
		_capsule = BigCapsule.new()
		_capsule.size = Vector2(200, 200)
		_capsule.position = (CARD - _capsule.size) * 0.5
		_capsule.pivot_offset = _capsule.size * 0.5
		add_child(_capsule)

	func prepare(res: Dictionary, weapon: WeaponData, thumbs: CosmeticThumbs) -> void:
		_res = res
		card.show_print(res["print"], weapon, thumbs)
		card.modulate.a = 0.0
		card.disabled = true
		_capsule.reset()
		_capsule.color = PrintLook.rarity_color(res["print"])
		_capsule.visible = false

	func drop_in() -> void:
		_capsule.visible = true
		var tw := create_tween()
		tw.tween_property(_capsule, "position:y", (CARD.y - _capsule.size.y) * 0.5, 0.35).from(-500.0).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		Sfx.play(&"prz_shake", -10.0, 1.1)

	func wobble(t: float) -> void:
		_capsule.rotation = sin(t * TAU * 3.0) * 0.22 * t
		_capsule.leak = t
		_capsule.glow = t

	func pop() -> void:
		_capsule.rotation = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_capsule, "open", 1.0, 0.35)
		card.disabled = false
		UiFx.pop_in(card, 0.05, 0.6)

	func finish_now() -> void:
		_capsule.visible = false
		card.modulate.a = 1.0
		card.scale = Vector2.ONE
		card.disabled = false

	func release() -> void:
		_capsule.visible = false
