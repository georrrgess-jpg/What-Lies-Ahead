class_name CosmeticShowcase
extends Control
## The display case of the Locker and the Shop: a spot-lit recess in a
## riveted frame that shows any cosmetic live. Operators stand on a pedestal,
## weapon cosmetics are worn by a weapon hovering over its stand, gloves are
## held in first person, kill effects pop a dummy zombie, tracers are fired
## across the stage, and banners and titles are shown on the player card.
## The glow behind takes the colour of the item's rarity.
##
##   var case := CosmeticShowcase.new()
##   case.show_item(item, weapon)       # weapon: what weapon cosmetics are shown on
##   case.celebrate("ADDED TO YOUR LOCKER")

## The operator is drawn this much taller than the case, cropping the empty
## room above and below it.
const OPERATOR_ZOOM := 1.3

var item: CosmeticItem
var _case: Control
var _glow: ColorRect
var _operator: OperatorPreview
var _stage: LockerStage
var _card_view: VBoxContainer
var _banner: BannerView
var _title: Label
var _card: PlayerCard
var _hint: Label
var _stamp: KitChip
var _flash: ColorRect

static var _spot_shader: Shader


func _init() -> void:
	custom_minimum_size = Vector2(520, 300)
	var frame := UiKit.metal_frame(34)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_case = Control.new()
	_case.clip_contents = true
	_case.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.add_child(_case)
	_glow = ColorRect.new()
	_glow.material = _spot_material()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_case.add_child(_glow)
	_operator = OperatorPreview.new()
	_operator.follow_equipped = false
	_operator.pedestal = true
	_operator.turntable_speed = 16.0
	_operator.visible = false
	_case.add_child(_operator)
	_stage = LockerStage.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.visible = false
	_case.add_child(_stage)
	_build_card_view()
	_build_overlays()
	_case.resized.connect(_fit_operator)


func _build_card_view() -> void:
	_card_view = VBoxContainer.new()
	_card_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_view.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_view.add_theme_constant_override("separation", UiKit.GAP_M)
	_card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_view.visible = false
	_case.add_child(_card_view)
	_banner = BannerView.new(null, 20.0)
	_banner.custom_minimum_size = Vector2(520, 150)
	_banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_view.add_child(_banner)
	_title = UiKit.arcade_label("", 56)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(560, 0)
	_title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_view.add_child(_title)
	var caption := UiKit.label("ON YOUR PLAYER CARD", UiKit.SIZE_SMALL, UiKit.MUTED, true)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_view.add_child(caption)
	_card = PlayerCard.build(true) as PlayerCard
	_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_view.add_child(_card)


## The hint at the bottom, the purchase stamp and the flash, above the item.
func _build_overlays() -> void:
	_hint = UiKit.label("", UiKit.SIZE_SMALL, Color(UiKit.MUTED, 0.85))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_bottom = -6
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_case.add_child(_hint)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_case.add_child(_flash)
	_stamp = UiKit.chip("", Wallet.COLOR, 30)
	_stamp.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_stamp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stamp.offset_top = 18
	_stamp.visible = false
	_case.add_child(_stamp)


## Shows `it` live. `weapon` is the weapon that weapon cosmetics, gloves and
## tracers are shown on; `flourish` plays the "just equipped" moment.
func show_item(it: CosmeticItem, weapon: WeaponData, flourish := false) -> void:
	item = it
	if it == null:
		return
	_operator.visible = it.slot == &"avatar"
	_card_view.visible = it.slot == &"banner" or it.slot == &"title"
	_stage.visible = not (_operator.visible or _card_view.visible)
	(_glow.material as ShaderMaterial).set_shader_parameter("tint", CosmeticItem.rarity_color(it.rarity))
	_hint.text = ""
	match it.slot:
		&"avatar":
			_operator.show_operator(it, flourish)
			_hint.text = "Drag to turn"
		&"banner", &"title":
			_show_on_card(it)
		&"gloves":
			var arms := Cosmetics.weapon_loadout(weapon.id)
			arms["arms"] = it
			_stage.show_arms(weapon, arms)
		&"kill_effect":
			_stage.show_kill_effect(it)
		&"tracer":
			_stage.show_tracer(it, weapon)
		_:
			var loadout := Cosmetics.weapon_loadout(weapon.id)
			loadout[String(it.slot).trim_prefix("weapon_")] = it
			_stage.show_weapon(weapon, loadout)
			_hint.text = "Drag to turn"
	if flourish:
		_flash_once(0.35)


func _show_on_card(it: CosmeticItem) -> void:
	# The card shows only this item's own slot differently from what is worn.
	_card.preview(&"banner", it if it.slot == &"banner" else null)
	_card.preview(&"title", it if it.slot == &"title" else null)
	_banner.visible = it.slot == &"banner"
	_title.visible = it.slot == &"title"
	if it.slot == &"banner":
		_banner.set_banner(it)
	else:
		_title.text = it.display_name.to_upper()
		_title.add_theme_color_override("font_color", CosmeticItem.rarity_color(it.rarity).lerp(Color.WHITE, 0.35))


## The purchase moment: the case flashes, Sparks burst out of it and a stamp
## with `text` pops in for a moment.
func celebrate(text: String) -> void:
	_flash_once(0.8)
	PurchaseFlow.burst(_case)
	_stamp.set_text(text)
	_stamp.visible = true
	var tw := UiFx.pop_in(_stamp)
	tw.chain().tween_interval(1.8)
	tw.chain().tween_property(_stamp, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(func(): _stamp.visible = false)


func _flash_once(strength: float) -> void:
	_flash.color.a = strength
	_flash.create_tween().tween_property(_flash, "color:a", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _fit_operator() -> void:
	var extra := _case.size.y * (OPERATOR_ZOOM - 1.0) * 0.5
	_operator.position = Vector2(0.0, -extra)
	_operator.size = Vector2(_case.size.x, _case.size.y + extra * 2.0)


func _spot_material() -> ShaderMaterial:
	if _spot_shader == null:
		_spot_shader = Shader.new()
		_spot_shader.code = """shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.42, 0.2, 0.72, 1.0);
void fragment() {
	vec2 d = (UV - vec2(0.5, 0.6)) * vec2(1.0, 1.25);
	float g = smoothstep(0.78, 0.0, length(d));
	vec3 glow = mix(vec3(0.42, 0.2, 0.72), tint.rgb, 0.55);
	COLOR = vec4(mix(vec3(0.06, 0.04, 0.15), glow * 0.72, g * g), 1.0);
	float rays = 0.5 + 0.5 * sin(atan(d.y, d.x) * 14.0 + TIME * 0.2);
	COLOR.rgb += glow * rays * g * 0.16;
	COLOR.rgb *= 1.0 - 0.35 * smoothstep(0.35, 0.75, abs(UV.y - 0.5) * 1.5);
}"""
	var m := ShaderMaterial.new()
	m.shader = _spot_shader
	return m
