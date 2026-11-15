class_name PrintHero
extends Control
## The finish of a reveal: the hero card of the new print. The print lands on
## a 3D turntable (PrintStage) and a band of light sweeps across it to show
## its grade, then its traits stamp in one by one: the GRADE, the rare PRINT
## (with its own flourish), the SERIAL rolling to its number (a burst of gold
## for a low or lucky one), then what became of it and the buttons.
## Shared by the capsule opening (CapsuleReveal) and Prize Fusion
## (FusionReveal), which style it CARNIVAL or HOLOGRAM.
##
##   hero.setup(res, weapon, PrintHero.Style.CARNIVAL, fx)
##   hero.play()          # the landing and the stamps; emits `landed` at the end
##   hero.finish_now()    # skip to the finished card

signal landed
signal another_requested
signal equip_requested(p: Dictionary)
signal done_requested

enum Style { CARNIVAL, HOLOGRAM }

const STAGE_MAX := Vector2(820, 600)
const INFO_WIDTH := 640.0
const GLOW_SHADER := """shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0, 0.7, 0.2, 1.0);
uniform float grid = 0.0;
void fragment() {
	vec2 d = (UV - vec2(0.5, 0.62)) * vec2(1.0, 1.35);
	float g = smoothstep(0.75, 0.0, length(d));
	vec3 col = mix(vec3(0.06, 0.04, 0.15), tint.rgb * 0.75, g * g);
	col += tint.rgb * (0.5 + 0.5 * sin(atan(d.y, d.x) * 16.0 - TIME * 0.4)) * g * 0.16 * (1.0 - grid);
	vec2 cell = abs(fract(UV * vec2(24.0, 16.0)) - 0.5);
	float lines = smoothstep(0.47, 0.5, max(cell.x, cell.y));
	col += tint.rgb * lines * 0.22 * grid * (0.4 + g);
	col += tint.rgb * 0.06 * grid * sin(UV.y * 300.0 - TIME * 6.0);
	COLOR = vec4(col, 1.0);
}"""

static var _glow_shader: Shader

var result: Dictionary = {}
var style := Style.CARNIVAL
var _fx: RevealFx
var _weapon: WeaponData
var _seq: Tween
var _card: VBoxContainer
var _stage_frame: KitPanel
var _stage: PrintStage
var _glow: ColorRect
var _info: VBoxContainer
var _header: Label
var _rarity_chip: KitChip
var _title: Label
var _subtitle: Label
var _grade: TraitStamp
var _print: TraitStamp
var _serial: TraitStamp
var _outcome: Label
var _buttons: HBoxContainer
var _another: SignButton
var _equip: SignButton
var _done: SignButton


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", UiKit.GAP_L)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_card)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", UiKit.GAP_XL)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(body)
	body.add_child(_build_stage())
	body.add_child(_build_info())
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", UiKit.GAP_M)
	_card.add_child(_buttons)
	_another = UiKit.sign_button("OPEN ANOTHER", SignButton.Kind.PRIMARY, 30)
	_another.pressed.connect(func(): another_requested.emit())
	_buttons.add_child(_another)
	_equip = UiKit.sign_button("EQUIP", SignButton.Kind.SECONDARY, 30)
	_equip.pressed.connect(func(): equip_requested.emit(result.get("print", {})))
	_buttons.add_child(_equip)
	_done = UiKit.sign_button("DONE", SignButton.Kind.NEUTRAL, 30)
	_done.pressed.connect(func(): done_requested.emit())
	_buttons.add_child(_done)
	resized.connect(_fit)


func _build_stage() -> Control:
	_stage_frame = UiKit.neon_panel(UiKit.AMBER, 8)
	_stage_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var case := Control.new()
	case.clip_contents = true
	case.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_frame.add_child(case)
	_glow = ColorRect.new()
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _glow_shader == null:
		_glow_shader = Shader.new()
		_glow_shader.code = GLOW_SHADER
	var m := ShaderMaterial.new()
	m.shader = _glow_shader
	_glow.material = m
	case.add_child(_glow)
	_stage = PrintStage.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	case.add_child(_stage)
	return _stage_frame


func _build_info() -> Control:
	_info = VBoxContainer.new()
	_info.custom_minimum_size.x = INFO_WIDTH
	_info.alignment = BoxContainer.ALIGNMENT_CENTER
	_info.add_theme_constant_override("separation", UiKit.GAP_S)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header = UiKit.label("YOU GOT", UiKit.SIZE_LABEL, UiKit.CYAN, true)
	_info.add_child(_header)
	_rarity_chip = UiKit.chip("", UiKit.AMBER, 24)
	_rarity_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_info.add_child(_rarity_chip)
	_title = UiKit.arcade_label("", 64)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size.x = INFO_WIDTH
	_info.add_child(_title)
	_subtitle = UiKit.label("", UiKit.SIZE_SMALL, UiKit.MUTED, true)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.custom_minimum_size.x = INFO_WIDTH
	_info.add_child(_subtitle)
	_info.add_child(UiKit.spacer(UiKit.GAP_S))
	_grade = TraitStamp.new("GRADE", true)
	_info.add_child(_grade)
	_print = TraitStamp.new("PRINT", false)
	_info.add_child(_print)
	_serial = TraitStamp.new("SERIAL", false)
	_info.add_child(_serial)
	_info.add_child(UiKit.spacer(UiKit.GAP_XS))
	_outcome = UiKit.label("", UiKit.SIZE_LABEL, UiKit.GREEN, true)
	_outcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outcome.custom_minimum_size.x = INFO_WIDTH
	_info.add_child(_outcome)
	return _info


## The stage takes what the screen leaves beside the info column.
func _fit() -> void:
	var room := Vector2(size.x - INFO_WIDTH - UiKit.GAP_XL - 160.0, size.y - 260.0)
	_stage_frame.custom_minimum_size = Vector2(clampf(room.x, 520.0, STAGE_MAX.x), clampf(room.y, 400.0, STAGE_MAX.y))


## Fills the card for `res` (a PrizePrints result) shown on `weapon`, and
## hides everything a reveal brings in.
func setup(res: Dictionary, weapon: WeaponData, hero_style: Style, fx: RevealFx, can_open_more: bool) -> void:
	result = res
	style = hero_style
	_fx = fx
	_weapon = weapon
	_fit()
	var p: Dictionary = res["print"]
	var col := PrintLook.rarity_color(p)
	var fin := PrizePrints.finish_of(p)
	var holo := style == Style.HOLOGRAM
	_header.text = "PRIZE FUSION COMPLETE" if holo else ("YOU GOT" if String(p.get("src", "")) != "counter" else "FRESH FROM THE COUNTER")
	_header.add_theme_color_override("font_color", UiKit.CYAN)
	_rarity_chip.set_text(PrintLook.rarity_name(p).to_upper() + "  ·  PRIZE PRINT")
	_rarity_chip.set_color(col)
	_title.text = fin.display_name.to_upper() if fin else ""
	_title.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.45))
	var fits := "any weapon" if String(p.get("w", "")) == "" else GameData.weapon(StringName(String(p["w"]))).display_name
	_subtitle.text = "Series %d %s  ·  pattern %d  ·  minted %s  ·  fits %s" % [PrizePrints.series().number,
		PrizePrints.series().display_name, int(p["seed"]), PrintLook.minted_text(p), fits]
	var glow := _glow.material as ShaderMaterial
	glow.set_shader_parameter("tint", UiKit.CYAN.lerp(col, 0.35) if holo else col)
	glow.set_shader_parameter("grid", 1.0 if holo else 0.0)
	_stage_frame.accent = UiKit.CYAN if holo else col
	_stage.show_print(weapon, p)
	_fill_traits(p)
	_fill_outcome()
	_another.visible = can_open_more
	_equip.visible = not bool(result.get("recycled", false)) and weapon != null
	_equip.set_text("EQUIP ON %s" % weapon.display_name.to_upper() if weapon else "EQUIP")
	_hide_all()


func _fill_traits(p: Dictionary) -> void:
	var g := PrizePrints.grade(p)
	var s := PrizePrints.series()
	var share: int = [roundi(s.polished_at * 100.0), roundi((s.mint_at - s.polished_at) * 100.0), roundi((1.0 - s.mint_at) * 100.0)][g]
	_grade.set_value(PrintLook.GRADES[g].to_upper(), PrintLook.GRADE_COLORS[g], "shine %.3f  ·  %d%% of prints" % [float(p["shine"]), share])
	_grade.set_meter(float(p["shine"]), PrintLook.GRADE_COLORS[g])
	var v := String(p.get("var", ""))
	if v == "":
		_print.set_value("STANDARD", UiKit.MUTED, "no rare print")
	else:
		_print.set_value(String(PrintLook.VARIANTS[v]["name"]).to_upper(), PrintLook.variant_color(p), "rare print  ·  " + PrintLook.variant_odds(v))
	var serial := int(p["serial"])
	var tag := PrintLook.serial_tag(serial)
	_serial.set_value(PrintLook.serial_text(serial), UiKit.AMBER if tag != "" else UiKit.CREAM,
		tag if tag != "" else "%s print of this finish" % _ordinal(serial))


static func _ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		suffix = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return Wallet.format(n) + suffix


func _fill_outcome() -> void:
	var text := "NEW FOR YOUR COLLECTION!"
	var col := UiKit.GREEN
	if bool(result.get("recycled", false)):
		text = "REPEAT  ·  RECYCLED INTO +%d PRIZE TOKENS" % int(result["tokens"])
		col = UiKit.AMBER
	elif bool(result.get("repeat", false)):
		text = "REPEAT  ·  A KEEPER, ADDED TO YOUR STACK"
		col = UiKit.CYAN
	if bool(result.get("lucky", false)):
		text += "  ·  LUCK METER PAID OUT"
	_outcome.text = text
	_outcome.add_theme_color_override("font_color", col)


func _hide_all() -> void:
	for c in [_header, _rarity_chip, _title, _subtitle, _outcome, _buttons, _grade, _print, _serial, _stage_frame]:
		(c as CanvasItem).modulate.a = 0.0
	_stage.set_holo(0.0 if style == Style.HOLOGRAM else 1.0)


## The landing: the stage pops in and the print drops on (or, as a hologram,
## is scanned in), the shine sweeps, then each trait stamps in.
func play() -> void:
	if _seq:
		_seq.kill()
	var p: Dictionary = result["print"]
	var rarity := PrizePrints.rarity(p)
	_seq = create_tween()
	_seq.tween_callback(_show_stage)
	if style == Style.HOLOGRAM:
		_seq.tween_method(_stage.set_holo, 0.0, 1.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_seq.tween_interval(0.5)
	_seq.tween_callback(_show_title)
	_seq.tween_interval(0.35)
	_seq.tween_callback(_sweep)
	_seq.tween_interval(0.5)
	_seq.tween_callback(_stamp_grade)
	_seq.tween_interval(0.55)
	_seq.tween_callback(_stamp_print)
	_seq.tween_interval(0.5 if String(p.get("var", "")) == "" else 1.0)
	_seq.tween_callback(_serial.stamp)
	_seq.tween_method(_roll_serial, 0.0, float(p["serial"]), 0.45 + 0.1 * rarity).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_seq.tween_callback(_serial_done)
	_seq.tween_interval(0.35)
	_seq.tween_callback(_finish)


func _show_stage() -> void:
	UiFx.pop_in(_stage_frame, 0.0, 0.6)
	if style == Style.CARNIVAL:
		_stage.drop_in(0.9)
		Sfx.play(&"prz_shake", -10.0, 0.8)
	else:
		_stage.settle()
		_stage.set_holo(0.0)
		Sfx.play(&"prz_fuse_form", -4.0)


func _show_title() -> void:
	for i in 4:
		UiFx.fade_in([_header, _rarity_chip, _title, _subtitle][i], 0.25, i * 0.06)
	UiFx.pop_in(_title, 0.06, 1.25)


func _sweep() -> void:
	var p: Dictionary = result["print"]
	_stage.sweep_tween(PrizePrints.grade(p), PrintLook.grade_color(p))
	Sfx.play(&"prz_shine", -7.0 + 2.0 * PrizePrints.grade(p))


func _stamp_grade() -> void:
	_grade.stamp()
	_grade.fill_meter(0.5)
	Sfx.play(&"prz_stamp", -5.0)


func _stamp_print() -> void:
	var p: Dictionary = result["print"]
	_print.stamp()
	if String(p.get("var", "")) == "":
		Sfx.play(&"prz_stamp", -9.0, 1.1)
		return
	Sfx.play(&"prz_stamp", -5.0)
	Sfx.play(&"prz_variant", -3.0)
	_print.flourish()
	if _fx:
		_fx.sparkle(_center_of(_print), 14, PrintLook.variant_color(p), 220.0)
	_stage.sweep_tween(2, PrintLook.variant_color(p))


func _roll_serial(v: float) -> void:
	_serial.set_value_text(PrintLook.serial_text(maxi(1, roundi(v))))


func _serial_done() -> void:
	var serial := int(result["print"]["serial"])
	_roll_serial(serial)
	if PrintLook.serial_tag(serial) == "":
		Sfx.play(&"prz_stamp", -9.0, 1.2)
		return
	Sfx.play(&"prz_serial", -4.0)
	_serial.flourish()
	if _fx:
		_fx.sparkle(_center_of(_serial), 18, UiKit.AMBER, 240.0)


func _finish() -> void:
	if bool(result.get("recycled", false)):
		Sfx.play(&"prz_token", -4.0)
	UiFx.fade_in(_outcome, 0.25)
	UiFx.fade_in(_buttons, 0.25)
	var focus := _another if _another.visible else _done
	focus.grab_focus.call_deferred()
	landed.emit()


## Jumps to the finished card.
func finish_now() -> void:
	if _seq:
		_seq.kill()
	for c in [_header, _rarity_chip, _title, _subtitle, _grade, _print, _serial, _stage_frame]:
		(c as Control).modulate.a = 1.0
		(c as Control).scale = Vector2.ONE
		(c as Control).rotation = 0.0
	_stage.settle()
	_grade.fill_meter(0.0)
	_roll_serial(int(result["print"]["serial"]))
	_finish()
	_outcome.modulate.a = 1.0
	_buttons.modulate.a = 1.0


func is_playing() -> bool:
	return _seq != null and _seq.is_running()


## Hides the 3D print (the overlay closed).
func release() -> void:
	if _seq:
		_seq.kill()
	_stage.show_weapon(null, {})


func _center_of(c: Control) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * (c.get_global_transform_with_canvas() * (c.size * 0.5))


## One trait of the print on a dark plate: a caption, a big value, a note
## (and for the grade, the shine meter). It stamps in: big, tilted and
## transparent, then down with a thump.
class TraitStamp extends PanelContainer:
	var _caption: Label
	var _value: Label
	var _note: Label
	var _meter: ProgressBar
	var _meter_value := 0.0
	var _accent: ColorRect

	func _init(caption: String, with_meter: bool) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_stylebox_override("panel", KitTex.box_copy(&"card", Color.WHITE, Vector2(16, 10)))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UiKit.GAP_M)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)
		_accent = ColorRect.new()
		_accent.custom_minimum_size = Vector2(6, 0)
		_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_accent)
		_caption = UiKit.label(caption, UiKit.SIZE_SMALL, UiKit.CYAN, true)
		_caption.custom_minimum_size.x = 96
		_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_caption)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(col)
		_value = UiKit.arcade_label("", 44)
		col.add_child(_value)
		_note = UiKit.label("", UiKit.SIZE_SMALL, UiKit.MUTED)
		col.add_child(_note)
		if with_meter:
			_meter = UiKit.progress(0.0, 12.0, UiKit.CYAN)
			_meter.max_value = 1.0
			_meter.custom_minimum_size.x = 200
			_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(_meter)

	func set_value(text: String, color: Color, note: String) -> void:
		_value.text = text
		_value.add_theme_color_override("font_color", color)
		_accent.color = color
		_note.text = note

	func set_value_text(text: String) -> void:
		_value.text = text

	func set_meter(value: float, color: Color) -> void:
		_meter_value = value
		_meter.add_theme_stylebox_override("fill", UiKit.bar_fill(color, 12.0))
		_meter.value = 0.0

	func fill_meter(seconds: float) -> void:
		if _meter == null:
			return
		if seconds <= 0.0:
			_meter.value = _meter_value
		else:
			UiFx.fill_to(_meter, _meter_value, seconds)

	## Slams in from big and tilted.
	func stamp() -> void:
		pivot_offset = size * Vector2(0.3, 0.5)
		modulate.a = 0.0
		scale = Vector2.ONE * 1.6
		rotation = -0.1
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "modulate:a", 1.0, 0.1)
		tw.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "rotation", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	## The special flourish: the value swells and glows.
	func flourish() -> void:
		_value.pivot_offset = _value.size * Vector2(0.0, 0.5)
		var tw := create_tween()
		tw.tween_property(_value, "scale", Vector2.ONE * 1.35, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(_value, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		var glow := create_tween()
		glow.tween_property(self, "self_modulate", Color(1.6, 1.4, 1.1), 0.12)
		glow.tween_property(self, "self_modulate", Color.WHITE, 0.6)
