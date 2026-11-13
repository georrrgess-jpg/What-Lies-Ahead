class_name AimVignette
extends CanvasLayer
## Screen shading while aiming down sights, drawn under the HUD: a soft
## darkening of the screen edges, and around a long scope's eyepiece the
## black surround of the scope (art/shaders/sight_vignette.gdshader).
## WeaponView drives it every frame with set_state().

const SHADER := "res://art/shaders/sight_vignette.gdshader"

var _rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	layer = 1
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER)
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.visible = false
	add_child(_rect)


## `strength` 0-1 darkens the screen edges. `scope` 0-1 closes a scope's
## surround around the eyepiece at `centre` (screen UV) with `radius` (share
## of the screen height).
func set_state(strength: float, scope: float, centre: Vector2, radius: float) -> void:
	var shown := strength > 0.004 or scope > 0.004
	_rect.visible = shown
	if not shown:
		return
	var size := _rect.size
	_material.set_shader_parameter("strength", strength)
	_material.set_shader_parameter("scope", scope)
	_material.set_shader_parameter("centre", centre)
	_material.set_shader_parameter("radius", radius)
	_material.set_shader_parameter("aspect", size.x / maxf(1.0, size.y))
