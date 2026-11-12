class_name SightPreview
extends Control
## The view through a sight, drawn flat for menus: its window and frame, a
## soft backdrop behind the glass and its reticle in the middle (the same
## patterns as the lens in game; art/shaders/sight_preview.gdshader). Iron
## sights are drawn as a notch and post. Give it a size and an item:
##
##   var preview := SightPreview.new()
##   preview.custom_minimum_size = Vector2(220, 160)
##   preview.item = Cosmetics.item(&"sight_holo_ring")

const SHADER := "res://art/shaders/sight_preview.gdshader"
const IRON := Color(0.2, 0.16, 0.33)

## The sight shown (a "weapon_sight" CosmeticItem; null or iron sights draws the notch and post).
var item: CosmeticItem:
	set(value):
		item = value
		_refresh()

var _glass: ColorRect
var _material: ShaderMaterial


func _init(it: CosmeticItem = null) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER)
	_glass = ColorRect.new()
	_glass.material = _material
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_glass)
	resized.connect(_refresh)
	item = it


func _refresh() -> void:
	var optic := WeaponSights.optic_name(item) != ""
	_glass.visible = optic
	queue_redraw()
	if not optic:
		return
	var shortest := maxf(1.0, minf(size.x, size.y))
	_material.set_shader_parameter("aspect", size / shortest)
	_material.set_shader_parameter("pattern", WeaponSights.pattern_index(item))
	_material.set_shader_parameter("reticle_color", WeaponSights.reticle_color(item))
	_material.set_shader_parameter("accent_color", item.color(1, Color(0.07, 0.71, 0.64)))
	_material.set_shader_parameter("lens_round", 1.0 if bool(WeaponSights.setting(item, "round", false)) else 0.0)
	_material.set_shader_parameter("edge_shadow", float(WeaponSights.setting(item, "edge_shadow", 0.0)))
	_material.set_shader_parameter("extent", float(WeaponSights.setting(item, "preview_scale", 2.6)))


## Iron sights: the rear notch with the front post standing in it.
func _draw() -> void:
	if _glass.visible:
		return
	var unit := minf(size.x, size.y) * 0.5
	var mid := size * 0.5
	var base := mid.y + unit * 0.55
	var glow := Color(0.35, 0.95, 1.0)
	draw_rect(Rect2(mid.x - unit * 0.9, base, unit * 1.8, unit * 0.22), IRON)
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(mid.x + side * unit * 0.55 - unit * 0.17, base - unit * 0.5, unit * 0.34, unit * 0.52), IRON)
		draw_circle(Vector2(mid.x + side * unit * 0.55, base - unit * 0.32), unit * 0.06, glow)
	draw_rect(Rect2(mid.x - unit * 0.08, base - unit * 0.72, unit * 0.16, unit * 0.74), IRON.lightened(0.15))
	draw_circle(Vector2(mid.x, base - unit * 0.6), unit * 0.07, glow)
