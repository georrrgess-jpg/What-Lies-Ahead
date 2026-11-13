class_name CellGlow
extends Node
## Animates a weapon's energy-cell glow for cell cosmetics with
## params.animate: "rainbow" cycles the hue, "pulse" breathes between the
## item's colours. Added to the weapon model by WeaponCosmetics.
##
## The viewmodel swaps Cell materials for per-instance copies after cosmetics
## are applied (for reload glow ramps), so the surfaces are looked up by their
## mesh material name and the current override is recoloured every frame.

var mode := "rainbow"
var colors := PackedColorArray()
var _surfaces: Array = []    # [MeshInstance3D, surface index]
var _time := 0.0


func _ready() -> void:
	for node in get_parent().find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(i)
			if base and base.resource_name == "Cell":
				_surfaces.append([mi, i])


func _process(delta: float) -> void:
	_time += delta
	var c := _color()
	for entry in _surfaces:
		var mi: MeshInstance3D = entry[0]
		if not is_instance_valid(mi):
			continue
		var m := mi.get_surface_override_material(entry[1]) as StandardMaterial3D
		if m:
			WeaponCosmetics.tint_cell(m, c)


func _color() -> Color:
	if mode == "pulse" and colors.size() >= 2:
		return colors[0].lerp(colors[1], 0.5 + 0.5 * sin(_time * 3.2))
	return Color.from_hsv(fmod(_time * 0.18, 1.0), 0.75, 1.0)
