class_name BannerView
extends ColorRect
## An animated banner (the "banner" cosmetic): a rounded rectangle drawn by
## art/shaders/skin_banner.gdshader with the item's style and colours.

const SHADER := "res://art/shaders/skin_banner.gdshader"
const FALLBACK := [Color("ff7a59"), Color("ff3f9f"), Color("3d1f73")]

var radius := 18.0
var item: CosmeticItem


func _init(banner: CosmeticItem = null, corner_radius := 18.0) -> void:
	item = banner
	radius = corner_radius
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load(SHADER)
	material = m
	resized.connect(_sync_size)
	set_banner(banner)


## Shows `banner` (null = the default banner, or a sunset if there is none).
func set_banner(banner: CosmeticItem) -> void:
	item = banner if banner else Cosmetics.default_item(&"banner")
	var m := material as ShaderMaterial
	m.set_shader_parameter("style", int(item.params.get("style", 0)) if item else 0)
	for i in 3:
		var c: Color = item.color(i, FALLBACK[i]) if item else FALLBACK[i]
		m.set_shader_parameter(["color_a", "color_b", "color_c"][i], c)
	m.set_shader_parameter("radius", radius)
	_sync_size()


func _sync_size() -> void:
	(material as ShaderMaterial).set_shader_parameter("rect_size", size)
