class_name BannerView
extends ColorRect
## An animated banner (the "banner" cosmetic): a rounded rectangle drawn by
## art/shaders/skin_banner.gdshader with the item's style and colours, or, for
## banners described by params.pattern (the level and challenge rewards), by
## art/shaders/mastery_banner.gdshader, as the reward road shows them.
## Styles from SCENES_FIRST up (illustrated scenes, mascots and patterns) are
## drawn by art/shaders/skin_banner_scenes.gdshader.

const SHADER := "res://art/shaders/skin_banner.gdshader"
const SCENES_SHADER := "res://art/shaders/skin_banner_scenes.gdshader"
const SCENES_FIRST := 14
const PATTERN_SHADER := "res://art/shaders/mastery_banner.gdshader"
const FALLBACK := [Color("ff7a59"), Color("ff3f9f"), Color("3d1f73")]

var radius := 18.0
var item: CosmeticItem


func _init(banner: CosmeticItem = null, corner_radius := 18.0) -> void:
	item = banner
	radius = corner_radius
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	resized.connect(_sync_size)
	set_banner(banner)


## Shows `banner` (null = the default banner, or a sunset if there is none).
func set_banner(banner: CosmeticItem) -> void:
	item = banner if banner else Cosmetics.default_item(&"banner")
	var m := material as ShaderMaterial
	if item and item.params.has("pattern") and not item.params.has("style"):
		m.shader = load(PATTERN_SHADER)
		m.set_shader_parameter("base_color", item.color(0, FALLBACK[2]))
		m.set_shader_parameter("pattern_color", item.color(1, FALLBACK[1]))
		m.set_shader_parameter("accent_color", item.color(2, FALLBACK[0]))
		m.set_shader_parameter("pattern", maxi(0, RewardArt.PATTERNS.find(String(item.params["pattern"]))))
		m.set_shader_parameter("corner", radius)
	else:
		var style := int(item.params.get("style", 0)) if item else 0
		m.shader = load(SCENES_SHADER if style >= SCENES_FIRST else SHADER)
		m.set_shader_parameter("style", style - SCENES_FIRST if style >= SCENES_FIRST else style)
		for i in 3:
			var c: Color = item.color(i, FALLBACK[i]) if item else FALLBACK[i]
			m.set_shader_parameter(["color_a", "color_b", "color_c"][i], c)
		m.set_shader_parameter("radius", radius)
	_sync_size()


func _sync_size() -> void:
	(material as ShaderMaterial).set_shader_parameter("rect_size", size)
