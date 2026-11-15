class_name FusionReveal
extends Control
## Prize Fusion, the trade-up, full screen: a futuristic machine on the pier.
## The five prints lock into the pods one by one, the holographic rings spin
## up and beams charge the core (prz_fuse_charge), the prints break up into
## streams of light that pour into it (prz_fuse_stream), the core flashes in
## the colour of the next rarity, and a hologram scans the new print into
## being on the hero card (PrintHero, HOLOGRAM style) over Fusion's own sting.
## The first click, Enter or Esc jumps to the result; Esc closes.
##
##   fusion.play(PrizePrints.trade_up(picked), picked, weapon, thumbs)

signal closed
signal equip_requested(p: Dictionary)

const BACKDROP := """shader_type canvas_item;
uniform float charge = 0.0;
void fragment() {
	vec2 uv = UV;
	vec3 col = mix(vec3(0.02, 0.03, 0.10), vec3(0.06, 0.04, 0.18), uv.y);
	vec2 g = abs(fract(uv * vec2(32.0, 18.0)) - 0.5);
	col += vec3(0.1, 0.5, 0.7) * smoothstep(0.46, 0.5, max(g.x, g.y)) * (0.12 + 0.2 * charge);
	col += vec3(0.2, 0.8, 1.0) * 0.04 * sin(uv.y * 600.0 - TIME * 8.0);
	float sweep = fract(TIME * 0.25);
	col += vec3(0.2, 0.9, 1.0) * exp(-pow((uv.y - sweep) * 40.0, 2.0)) * 0.12;
	float v = length((uv - 0.5) * vec2(1.6, 1.0));
	COLOR = vec4(col * (1.15 - v * 0.6), 0.97);
}"""

var result: Dictionary = {}
var _picked: Array = []
var _seq: Tween
var _back: ColorRect
var _fx: RevealFx
var _chamber: FusionChamber
var _title: Label
var _subtitle: Label
var _hero: PrintHero
var _flash: ColorRect
var _hint: Label
var _formed := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_back = ColorRect.new()
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = BACKDROP
	var m := ShaderMaterial.new()
	m.shader = shader
	_back.material = m
	add_child(_back)
	_fx = RevealFx.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fx)
	_chamber = FusionChamber.new()
	add_child(_chamber)
	_title = UiKit.arcade_label("PRIZE FUSION", 84, FusionChamber.CYAN)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.offset_top = UiKit.GAP_L
	add_child(_title)
	_subtitle = UiKit.label("", UiKit.SIZE_LABEL, UiKit.CREAM, true)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_subtitle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_subtitle.offset_top = UiKit.GAP_L + 104
	add_child(_subtitle)
	_hero = PrintHero.new()
	_hero.equip_requested.connect(func(p: Dictionary): equip_requested.emit(p))
	_hero.done_requested.connect(close)
	_hero.landed.connect(func(): _hint.visible = false)
	add_child(_hero)
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


## Plays the fusion of `picked` (the five prints, already traded) into
## `res` (the PrizePrints.trade_up result), shown on `weapon`.
func play(res: Dictionary, picked: Array, weapon: WeaponData, thumbs: CosmeticThumbs) -> void:
	result = res
	_picked = picked
	_formed = false
	visible = true
	var p: Dictionary = res["print"]
	var rarity := PrizePrints.rarity(p)
	var col := PrintLook.rarity_color(p)
	_fx.clear()
	_fx.color = FusionChamber.CYAN
	_fx.centre = size * Vector2(0.5, 0.52)
	_hero.visible = false
	_hero.setup(res, weapon, PrintHero.Style.HOLOGRAM, _fx, false)
	_hint.visible = true
	_flash.color.a = 0.0
	_subtitle.text = "%d %s PRINTS  →  1 %s PRINT" % [picked.size(), _rn(rarity - 1).to_upper(), _rn(rarity).to_upper()]
	_layout_chamber()
	_chamber.reset()
	_chamber.core_color = col
	_chamber.core_text = "?"
	_chamber.modulate.a = 1.0
	_chamber.scale = Vector2.ONE
	_chamber.visible = true
	for c in [_title, _subtitle]:
		c.visible = true
		c.modulate.a = 1.0
	_set_charge(0.0)
	_seq = create_tween()
	_seq.tween_property(self, "modulate:a", 1.0, 0.25).from(0.0)
	for i in picked.size():
		_seq.tween_callback(_load_pod.bind(i, weapon, thumbs))
		_seq.tween_interval(0.16)
	_seq.tween_interval(0.2)
	_seq.tween_callback(Sfx.play.bind(&"prz_fuse_charge", -3.0))
	_seq.tween_method(_set_charge, 0.0, 1.0, 2.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_seq.tween_callback(_start_stream)
	for i in picked.size():
		_seq.parallel().tween_method(_chamber.set_dissolve.bind(i), 0.0, 1.0, 0.7).set_delay(0.1 * i)
	_seq.tween_property(_chamber, "core", 1.0, 0.5)
	_seq.tween_callback(_form.bind(rarity, col))
	_seq.tween_interval(0.45)
	_seq.tween_callback(_show_hero)


static func _rn(r: int) -> String:
	return CosmeticItem.rarity_name(clampi(r, 0, 3) as CosmeticItem.Rarity)


func _layout_chamber() -> void:
	var h := size.y * 0.72
	_chamber.size = Vector2(minf(size.x * 0.8, h * 1.3), h)
	_chamber.position = Vector2((size.x - _chamber.size.x) * 0.5, size.y * 0.2)
	_chamber.pivot_offset = _chamber.core_point()


func _load_pod(i: int, weapon: WeaponData, thumbs: CosmeticThumbs) -> void:
	var p: Dictionary = _picked[i]
	var shown := GameData.weapon(StringName(String(p.get("w", "")))) if String(p.get("w", "")) != "" else weapon
	_chamber.pod_textures[i] = CosmeticThumbs.cached_print(p, shown)
	if _chamber.pod_textures[i] == null and thumbs:
		thumbs.request_print(p, func(tex: Texture2D): _chamber.pod_textures[i] = tex, shown)
	_chamber.pod_colors[i] = PrintLook.rarity_color(p)
	Sfx.play(&"prz_fuse_slot", -6.0, 0.9 + 0.1 * i)


func _set_charge(v: float) -> void:
	_chamber.charge = v
	(_back.material as ShaderMaterial).set_shader_parameter("charge", v)


func _start_stream() -> void:
	_chamber.stream = 1.0
	Sfx.play(&"prz_fuse_stream", -4.0)


## The core flashes in the new rarity's colour and the chamber gives way.
func _form(rarity: int, col: Color) -> void:
	_formed = true
	_chamber.stream = 0.0
	Sfx.play(&"prz_fuse_sting", -2.0)
	_fx.color = col
	_fx.burst(maxi(0, rarity - 1), _chamber.position + _chamber.core_point(), col)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_flash, "color", Color(col.lerp(Color.WHITE, 0.7), 0.0), 0.5).from(Color(col.lerp(Color.WHITE, 0.7), 0.9))
	tw.tween_property(_chamber, "scale", Vector2.ONE * 0.4, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(_chamber, "modulate:a", 0.0, 0.4)
	tw.tween_property(_fx, "rays", 0.8, 0.4)
	for c in [_title, _subtitle]:
		tw.tween_property(c, "modulate:a", 0.0, 0.3)


func _show_hero() -> void:
	_chamber.visible = false
	_hero.visible = true
	_fx.centre = size * Vector2(0.32, 0.45)
	_hero.play()


func is_playing() -> bool:
	return (_seq != null and _seq.is_running()) or _hero.is_playing()


## Jumps to the finished hero card.
func skip() -> void:
	if _seq:
		_seq.kill()
	modulate.a = 1.0
	if not _formed:
		_formed = true
		Sfx.play(&"prz_fuse_sting", -3.0)
	_chamber.visible = false
	_title.visible = false
	_subtitle.visible = false
	_flash.color.a = 0.0
	_fx.color = PrintLook.rarity_color(result["print"])
	_fx.rays = 0.8
	_fx.centre = size * Vector2(0.32, 0.45)
	_set_charge(0.4)
	_hero.visible = true
	_hero.finish_now()


func close() -> void:
	if _seq:
		_seq.kill()
	_hero.release()
	_fx.clear()
	_chamber.reset()
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


## While the overlay is up it owns the keys (Esc closes a finished fusion).
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey or event is InputEventJoypadButton) or not event.is_pressed():
		return
	if event.is_action_pressed("ui_cancel"):
		close()
	get_viewport().set_input_as_handled()
