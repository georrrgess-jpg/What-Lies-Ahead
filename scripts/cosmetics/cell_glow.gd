class_name CellGlow
extends Node
## Animates a weapon's energy-cell glow for cell cosmetics with
## params.animate: "rainbow" cycles the hue, "pulse" breathes between the
## item's colours, "flicker" stutters like a failing neon tube, "countdown"
## blinks faster and faster up to a white flash, "steps" jumps through the
## colours, "gradient" flows smoothly through them and "lubdub" beats twice
## like a heart. Added to the weapon model by WeaponCosmetics.
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
	return color_at(mode, colors, _time)


## The colour an animated cell glows in at time `t` (also drawn by CosmeticIcon).
static func color_at(anim: String, cols: PackedColorArray, t: float) -> Color:
	var first := cols[0] if cols.size() > 0 else Color.WHITE
	var second := cols[1] if cols.size() > 1 else Color.WHITE
	match anim:
		"pulse":
			if cols.size() >= 2:
				return first.lerp(second, 0.5 + 0.5 * sin(t * 3.2))
		"flicker":
			# Mostly lit; short drop-outs, and a stuttering outage every few seconds.
			var tick := floorf(t * 14.0)
			var out := _noise(tick) < 0.12 or (fmod(t, 3.7) > 3.25 and _noise(tick + 0.5) < 0.6)
			return first.darkened(0.88) if out else first
		"countdown":
			# Blinks speed up over 3.2 s, then a white flash.
			var phase := fmod(t, 3.2) / 3.2
			if phase > 0.92:
				return Color.WHITE.lerp(first, (phase - 0.92) / 0.08)
			return first if sin(phase * phase * 70.0) > -0.2 else first.darkened(0.85)
		"steps":
			return cols[int(t / 0.9) % cols.size()] if cols.size() > 0 else first
		"gradient":
			if cols.size() >= 2:
				var x := fmod(t * 0.3, float(cols.size()))
				var i := int(x)
				return cols[i].lerp(cols[(i + 1) % cols.size()], smoothstep(0.0, 1.0, x - i))
		"lubdub":
			var beat := fmod(t, 1.1)
			var k := exp(-pow((beat - 0.05) / 0.05, 2.0)) + 0.8 * exp(-pow((beat - 0.3) / 0.05, 2.0))
			return first.darkened(0.7).lerp(second, clampf(k, 0.0, 1.0))
	return Color.from_hsv(fmod(t * 0.18, 1.0), 0.75, 1.0)


static func _noise(n: float) -> float:
	return fposmod(sin(n * 12.9898) * 43758.5453, 1.0)
