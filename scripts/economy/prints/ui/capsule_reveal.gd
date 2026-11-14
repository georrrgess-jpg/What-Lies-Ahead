class_name CapsuleReveal
extends Control
## The opening moment of a Prize Capsule (and of a trade-up or a Token
## Counter buy): the capsule flies out of the chute, wobbles in a glow of its
## rarity, pops in a burst of rays, and the print turns on a stand while its
## rolls count up: rarity, finish, the shine meter sweeping Factory -> Polished
## -> Mint, the rare-print stamp, the serial rolling to its number, and what
## became of a repeat. A click, Enter or Esc skips to the end.
##
##   reveal.play(PrizePrints.open_capsule(), from_point)
##   reveal.closed / another_requested / equip_requested(print)

signal closed
signal another_requested
signal equip_requested(p: Dictionary)

const STAGE_SIZE := Vector2(700, 460)

var result: Dictionary = {}
var _seq: Tween
var _dim: ColorRect
var _rays: Rays
var _capsule: BigCapsule
var _flash: ColorRect
var _stage_frame: KitPanel
var _stage: LockerStage
var _stage_glow: ColorRect
var _info: VBoxContainer
var _rarity_chip: KitChip
var _title: Label
var _subtitle: Label
var _grade_bar: ProgressBar
var _grade_label: Label
var _grade_value: Label
var _variant_chip: KitChip
var _variant_note: Label
var _serial: Label
var _serial_tag: KitChip
var _pattern: Label
var _outcome: Label
var _buttons: HBoxContainer
var _another: SignButton
var _equip: SignButton
var _done: SignButton
var _hint: Label
var _ticks := 0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(UiKit.INK, 0.9)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_rays = Rays.new()
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rays)
	_build_stage()
	_build_info()
	_capsule = BigCapsule.new()
	add_child(_capsule)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_hint = UiKit.label("CLICK TO SKIP", UiKit.SIZE_SMALL, Color(UiKit.MUTED, 0.8), true)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_bottom = -10
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)


func _build_stage() -> void:
	_stage_frame = UiKit.neon_panel(UiKit.AMBER, 8)
	_stage_frame.custom_minimum_size = STAGE_SIZE
	_stage_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage_frame)
	var case := Control.new()
	case.clip_contents = true
	case.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_frame.add_child(case)
	_stage_glow = ColorRect.new()
	_stage_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow := Shader.new()
	glow.code = """shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0, 0.7, 0.2, 1.0);
void fragment() {
	vec2 d = (UV - vec2(0.5, 0.62)) * vec2(1.0, 1.35);
	float g = smoothstep(0.75, 0.0, length(d));
	COLOR = vec4(mix(vec3(0.06, 0.04, 0.15), tint.rgb * 0.75, g * g), 1.0);
	COLOR.rgb += tint.rgb * (0.5 + 0.5 * sin(atan(d.y, d.x) * 16.0 - TIME * 0.4)) * g * 0.16;
}"""
	var m := ShaderMaterial.new()
	m.shader = glow
	_stage_glow.material = m
	case.add_child(_stage_glow)
	_stage = LockerStage.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	case.add_child(_stage)


func _build_info() -> void:
	_info = VBoxContainer.new()
	_info.custom_minimum_size.x = 620
	_info.add_theme_constant_override("separation", UiKit.GAP_S)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info)
	_rarity_chip = UiKit.chip("", UiKit.AMBER, 24)
	_rarity_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_info.add_child(_rarity_chip)
	_title = UiKit.arcade_label("", 60)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size.x = 620
	_info.add_child(_title)
	_subtitle = UiKit.label("", UiKit.SIZE_SMALL, UiKit.MUTED, true)
	_info.add_child(_subtitle)
	_info.add_child(UiKit.spacer(8))
	# Grade: the shine meter with its three zones.
	var grade_row := HBoxContainer.new()
	grade_row.add_theme_constant_override("separation", UiKit.GAP_M)
	_info.add_child(grade_row)
	grade_row.add_child(_caption("SHINE"))
	_grade_bar = UiKit.progress(0.0, 22.0, UiKit.CYAN)
	_grade_bar.max_value = 1.0
	_grade_bar.custom_minimum_size.x = 300
	_grade_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grade_row.add_child(_grade_bar)
	_grade_label = UiKit.label("", UiKit.SIZE_LABEL, UiKit.CREAM, true)
	_grade_label.custom_minimum_size.x = 140
	grade_row.add_child(_grade_label)
	_grade_value = UiKit.label("", UiKit.SIZE_SMALL, UiKit.MUTED)
	grade_row.add_child(_grade_value)
	var variant_row := HBoxContainer.new()
	variant_row.add_theme_constant_override("separation", UiKit.GAP_M)
	_info.add_child(variant_row)
	variant_row.add_child(_caption("PRINT"))
	_variant_chip = UiKit.chip("", UiKit.PINK, 24)
	variant_row.add_child(_variant_chip)
	_variant_note = UiKit.label("", UiKit.SIZE_SMALL, UiKit.MUTED)
	variant_row.add_child(_variant_note)
	var serial_row := HBoxContainer.new()
	serial_row.add_theme_constant_override("separation", UiKit.GAP_M)
	_info.add_child(serial_row)
	serial_row.add_child(_caption("SERIAL"))
	_serial = UiKit.arcade_label("", 54, UiKit.AMBER)
	serial_row.add_child(_serial)
	_serial_tag = UiKit.chip("", UiKit.AMBER, 20)
	_serial_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	serial_row.add_child(_serial_tag)
	_pattern = UiKit.label("", UiKit.SIZE_SMALL, UiKit.MUTED)
	_info.add_child(_pattern)
	_outcome = UiKit.label("", UiKit.SIZE_LABEL, UiKit.CYAN, true)
	_info.add_child(_outcome)
	_info.add_child(UiKit.spacer(10))
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", UiKit.GAP_M)
	_info.add_child(_buttons)
	_another = UiKit.sign_button("OPEN ANOTHER", SignButton.Kind.PRIMARY, 26)
	_another.pressed.connect(func(): another_requested.emit())
	_buttons.add_child(_another)
	_equip = UiKit.sign_button("EQUIP", SignButton.Kind.SECONDARY, 26)
	_equip.pressed.connect(func(): equip_requested.emit(result.get("print", {})))
	_buttons.add_child(_equip)
	_done = UiKit.sign_button("DONE", SignButton.Kind.NEUTRAL, 26)
	_done.pressed.connect(close)
	_buttons.add_child(_done)


func _caption(text: String) -> Label:
	var l := UiKit.label(text, UiKit.SIZE_SMALL, UiKit.CYAN, true)
	l.custom_minimum_size.x = 90
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


## Plays the reveal of `res` (a PrizePrints result: print, repeat, recycled,
## tokens, rarity). `from` is where the capsule starts (the machine's chute, in
## this control's space); `weapon` the weapon the print is shown on;
## `can_open_more` shows OPEN ANOTHER.
func play(res: Dictionary, from: Vector2, weapon: WeaponData, can_open_more: bool) -> void:
	result = res
	var p: Dictionary = res["print"]
	var col := PrintLook.rarity_color(p)
	visible = true
	_layout()
	_fill(p, weapon, can_open_more)
	_hide_reveal()
	_capsule.color = col
	_capsule.open = 0.0
	_capsule.glow = 0.0
	_capsule.rotation = 0.0
	_capsule.position = from - _capsule.size * 0.5
	_capsule.scale = Vector2.ONE * 0.3
	_capsule.visible = true
	_rays.color = col
	_rays.strength = 0.0
	_dim.modulate.a = 0.0
	_hint.visible = true
	var rarity := int(res.get("rarity", 0))
	var centre := size * Vector2(0.5, 0.46) - _capsule.size * 0.5
	_seq = create_tween()
	_seq.tween_property(_dim, "modulate:a", 1.0, 0.25)
	_seq.parallel().tween_property(_capsule, "position", centre, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_seq.parallel().tween_property(_capsule, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Wobbles: more of them, and a brighter glow, the rarer it is.
	var wobbles: int = [2, 2, 3, 4][clampi(rarity, 0, 3)]
	for i in wobbles:
		var lean := 0.14 + 0.05 * i
		_seq.tween_callback(Sfx.play.bind(&"prz_shake", -10.0 + i, 1.0 + 0.06 * i))
		_seq.tween_property(_capsule, "rotation", lean, 0.09)
		_seq.tween_property(_capsule, "rotation", -lean, 0.14)
		_seq.parallel().tween_property(_capsule, "glow", (i + 1.0) / wobbles, 0.14)
		_seq.tween_property(_capsule, "rotation", 0.0, 0.08)
		_seq.tween_interval(0.12)
	_seq.tween_callback(_pop.bind(rarity))
	_seq.tween_property(_capsule, "open", 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_seq.parallel().tween_property(_flash, "color:a", 0.0, 0.5).from(0.85)
	_seq.parallel().tween_property(_rays, "strength", 1.0, 0.4)
	_seq.tween_callback(_show_stage)
	_seq.tween_interval(0.15)
	_seq.tween_callback(_show_title)
	_seq.tween_interval(0.25)
	_ticks = 0
	_seq.tween_method(_set_shine, 0.0, float(p["shine"]), 0.3 + float(p["shine"]) * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_seq.tween_interval(0.15)
	_seq.tween_callback(_show_variant)
	_seq.tween_interval(0.3 if String(p.get("var", "")) == "" else 0.55)
	_seq.tween_method(_set_serial, 0.0, float(p["serial"]), 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_seq.tween_callback(_show_serial_tag)
	_seq.tween_interval(0.2)
	_seq.tween_callback(_finish)


func _layout() -> void:
	var total := STAGE_SIZE.x + UiKit.GAP_XL + _info.custom_minimum_size.x
	var left := (size.x - total) * 0.5
	_stage_frame.position = Vector2(left, (size.y - STAGE_SIZE.y) * 0.5)
	_stage_frame.size = STAGE_SIZE
	_info.position = Vector2(left + STAGE_SIZE.x + UiKit.GAP_XL, _stage_frame.position.y - 6.0)
	_info.size = Vector2(_info.custom_minimum_size.x, STAGE_SIZE.y)
	_capsule.size = Vector2(260, 260)
	_capsule.pivot_offset = _capsule.size * 0.5


func _fill(p: Dictionary, weapon: WeaponData, can_open_more: bool) -> void:
	var col := PrintLook.rarity_color(p)
	var fin := PrizePrints.finish_of(p)
	_rarity_chip.set_text(PrintLook.rarity_name(p).to_upper() + "  ·  PRIZE PRINT")
	_rarity_chip.set_color(col)
	_title.text = fin.display_name.to_upper() if fin else ""
	_title.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.45))
	_subtitle.text = "Series %d  ·  %s  ·  minted %s  ·  fits %s" % [PrizePrints.series().number, PrizePrints.series().display_name,
		PrintLook.minted_text(p), "any weapon" if String(p.get("w", "")) == "" else GameData.weapon(StringName(String(p["w"]))).display_name]
	_pattern.text = "Pattern %d  ·  shown on the %s" % [int(p["seed"]), weapon.display_name if weapon else ""]
	(_stage_glow.material as ShaderMaterial).set_shader_parameter("tint", col)
	_stage_frame.accent = col
	_stage_frame.queue_redraw()
	var loadout := Cosmetics.weapon_loadout(weapon.id) if weapon else {}
	loadout["finish"] = fin
	loadout["print"] = p
	_stage.show_weapon(weapon, loadout)
	_another.visible = can_open_more
	_equip.visible = not bool(result.get("recycled", false))
	_equip.set_text("EQUIP ON %s" % weapon.display_name.to_upper() if weapon else "EQUIP")
	if bool(result.get("recycled", false)):
		_outcome.text = "REPEAT  ·  RECYCLED INTO +%d PRIZE TOKENS" % int(result["tokens"])
		_outcome.add_theme_color_override("font_color", UiKit.AMBER)
	elif bool(result.get("repeat", false)):
		_outcome.text = "REPEAT  ·  A KEEPER, ADDED TO YOUR STACK"
		_outcome.add_theme_color_override("font_color", UiKit.CYAN)
	else:
		_outcome.text = "NEW FOR YOUR COLLECTION!"
		_outcome.add_theme_color_override("font_color", UiKit.GREEN)
	if bool(result.get("lucky", false)):
		_outcome.text += "   ·   LUCK METER PAID OUT"


func _hide_reveal() -> void:
	_stage_frame.visible = false
	_info.visible = false
	for row in [_rarity_chip, _title, _subtitle, _variant_chip, _variant_note, _serial, _serial_tag, _pattern, _outcome, _buttons]:
		row.modulate.a = 0.0
	_grade_bar.value = 0.0
	_grade_label.text = ""
	_grade_value.text = ""
	_serial.text = "#000"


func _pop(rarity: int) -> void:
	Sfx.play(&"prz_pop", -3.0)
	Sfx.play(StringName("prz_reveal_%d" % rarity), -2.0)
	_rays.burst()


func _show_stage() -> void:
	_stage_frame.visible = true
	_info.visible = true
	UiFx.pop_in(_stage_frame, 0.0, 0.7)
	_capsule.visible = false


func _show_title() -> void:
	for row in [_rarity_chip, _title, _subtitle]:
		UiFx.fade_in(row, 0.25)


func _set_shine(v: float) -> void:
	_grade_bar.value = v
	var g := PrintRoll.grade(v, PrizePrints.series())
	_grade_label.text = PrintLook.GRADES[g].to_upper()
	_grade_label.add_theme_color_override("font_color", PrintLook.GRADE_COLORS[g])
	_grade_value.text = "%.3f" % v
	var step := int(v * 20.0)
	if step > _ticks:
		_ticks = step
		Sfx.play(&"prz_tick", -14.0, 0.9 + v * 0.5)


func _show_variant() -> void:
	var p: Dictionary = result["print"]
	var v := String(p.get("var", ""))
	if v == "":
		_variant_chip.set_text("STANDARD")
		_variant_chip.set_color(UiKit.PURPLE)
		_variant_note.text = ""
		UiFx.fade_in(_variant_chip, 0.2)
	else:
		_variant_chip.set_text(String(PrintLook.VARIANTS[v]["name"]).to_upper())
		_variant_chip.set_color(PrintLook.variant_color(p))
		_variant_note.text = "rare print  ·  " + PrintLook.variant_odds(v)
		_variant_chip.modulate.a = 1.0
		UiFx.pop_in(_variant_chip, 0.0, 1.8)
		Sfx.play(&"prz_variant", -3.0)
		_flash.color = Color(PrintLook.variant_color(p), 0.5)
		create_tween().tween_property(_flash, "color:a", 0.0, 0.5)
	UiFx.fade_in(_variant_note, 0.3)


func _set_serial(v: float) -> void:
	_serial.modulate.a = 1.0
	_serial.text = PrintLook.serial_text(maxi(1, roundi(v)))


func _show_serial_tag() -> void:
	var serial := int(result["print"]["serial"])
	var tag := PrintLook.serial_tag(serial)
	_serial_tag.set_text(tag)
	_serial_tag.visible = tag != ""
	if tag != "":
		UiFx.pop_in(_serial_tag)
		Sfx.play(&"prz_tick", -6.0, 1.6)
	UiFx.fade_in(_pattern, 0.3)


func _finish() -> void:
	_hint.visible = false
	if bool(result.get("recycled", false)):
		Sfx.play(&"prz_token", -4.0)
	UiFx.fade_in(_outcome, 0.25)
	UiFx.fade_in(_buttons, 0.25)
	var focus := _another if _another.visible else _done
	focus.grab_focus.call_deferred()


## Jumps to the end of the reveal.
func skip() -> void:
	if _seq == null or not _seq.is_running():
		return
	_seq.kill()
	var p: Dictionary = result["print"]
	_dim.modulate.a = 1.0
	_capsule.visible = false
	_rays.strength = 1.0
	_flash.color.a = 0.0
	_stage_frame.visible = true
	_stage_frame.scale = Vector2.ONE
	_info.visible = true
	for row in [_rarity_chip, _title, _subtitle, _variant_note, _pattern]:
		row.modulate.a = 1.0
	_ticks = 999
	_set_shine(float(p["shine"]))
	_show_variant()
	_variant_chip.modulate.a = 1.0
	_variant_chip.scale = Vector2.ONE
	_set_serial(float(p["serial"]))
	_show_serial_tag()
	_serial_tag.modulate.a = 1.0
	_serial_tag.scale = Vector2.ONE
	_finish()
	_outcome.modulate.a = 1.0
	_buttons.modulate.a = 1.0


func close() -> void:
	if _seq:
		_seq.kill()
	visible = false
	_stage.show_weapon(null, {})
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and _seq and _seq.is_running():
		skip()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		if _seq and _seq.is_running():
			skip()
		elif event.is_action_pressed("ui_cancel"):
			close()
		else:
			return
		get_viewport().set_input_as_handled()


## Rotating rays and a soft glow in the rarity colour behind everything.
class Rays extends Control:
	var color := Color.WHITE
	var strength := 0.0
	var _time := 0.0
	var _kick := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func burst() -> void:
		_kick = 1.0

	func _process(delta: float) -> void:
		_time += delta
		_kick = maxf(0.0, _kick - delta * 1.6)
		if visible:
			queue_redraw()

	func _draw() -> void:
		if strength <= 0.0:
			return
		var c := size * Vector2(0.5, 0.46)
		var reach := size.length() * 0.6
		var rays := 18
		for i in rays:
			var a := _time * 0.18 + TAU * i / rays
			var w := 0.07 + 0.03 * sin(_time * 1.3 + i)
			var pts := PackedVector2Array([c, c + Vector2.from_angle(a - w) * reach, c + Vector2.from_angle(a + w) * reach])
			var cols := PackedColorArray([Color(color, 0.32 * strength + _kick * 0.3), Color(color, 0.0), Color(color, 0.0)])
			draw_polygon(pts, cols)
		for k in 6:
			draw_circle(c, (6 - k) * 70.0 * (1.0 + _kick * 0.6), Color(color, 0.05 * strength))


## The big two-tone capsule: wobbles, glows and splits open.
class BigCapsule extends Control:
	var color := Color.WHITE
	var open := 0.0:
		set(v):
			open = v
			queue_redraw()
	var glow := 0.0:
		set(v):
			glow = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.36
		for k in 5:
			draw_circle(c, r * (1.25 + k * 0.18 + glow * 0.4), Color(color, (0.08 + glow * 0.1) * (1.0 - open)))
		var gap := open * r * 1.6
		var fade := 1.0 - open
		_half(c + Vector2(-gap * 0.3, -gap), r, color, true, -open * 0.9, fade)
		_half(c + Vector2(gap * 0.3, gap), r, UiKit.CREAM, false, open * 0.7, fade)

	func _half(at: Vector2, r: float, col: Color, top: bool, turn: float, alpha: float) -> void:
		if alpha <= 0.01:
			return
		draw_set_transform(at, turn, Vector2.ONE)
		var pts := PackedVector2Array()
		for k in 25:
			var a := (PI if top else 0.0) + PI * k / 24.0
			pts.append(Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, Color(col, alpha))
		draw_polyline(pts, Color(col.darkened(0.4), alpha), 4.0, true)
		draw_line(Vector2(-r, 0), Vector2(r, 0), Color(col.darkened(0.4), alpha), 5.0, true)
		if top:
			draw_circle(Vector2(-r * 0.38, -r * 0.5), r * 0.16, Color(1, 1, 1, 0.65 * alpha))
		draw_set_transform(Vector2.ZERO)
