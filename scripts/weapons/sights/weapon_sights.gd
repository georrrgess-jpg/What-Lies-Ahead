class_name WeaponSights
extends RefCounted
## Sights: per-weapon cosmetics in the slot "weapon_sight" (data/cosmetics/sights).
## An item either keeps the weapon's own iron sights (no params.optic) or
## clamps an optic from art/models/sights.glb to the weapon's top:
##
##   params.optic            a key of OPTICS ("Reflex", "Holo", "Tube", "Prism", "Scope"...)
##   params.reticle          a pattern from PATTERNS
##   params.zoom             magnification on top of the weapon's own aimed zoom
##   params.reticle_degrees  angle of one reticle unit (default 1.2)
##   params.fill             share of the aimed view the window fills (overrides OPTICS)
##   params.ads_time         multiplier on the weapon's time to raise the sight
##   colors                  [reticle, housing accent]
##
## apply() fits an item to any weapon model (viewmodel or menu preview) and
## returns its SightRig; WeaponCosmetics.apply calls it for every model, so
## the Locker, thumbnails and the viewmodel all show the fitted sight.

const SLOT := &"weapon_sight"
const SCENE := "res://art/models/sights.glb"
const LENS_SHADER := "res://art/shaders/sight_lens.gdshader"
const RIG := "SightRig"
const PATTERNS := {
	"dot": 0, "ring": 1, "chevron": 2, "circle_dot": 3, "star": 4, "heart": 5, "pixel": 6,
	"horseshoe": 7, "scope": 8, "periscope": 9, "diamond": 10, "marquee": 11, "slit": 12, "hex": 13,
	"post": 14, "burst": 15, "ranger": 16, "snowflake": 17, "quarters": 18,
}
## Per optic: `round` window, `fill` (the window's half-height as a share of
## the aimed view's half-height: sets how close the eye sits), `edge_shadow`
## (dark rim of a tube), `glass` (opacity of the glass tint), `glow` (halo
## around the reticle), `vignette` (darkening of the screen edges when aimed)
## and `scope_view` (aimed, only the eyepiece view is shown).
const OPTICS := {
	"Reflex": {"round": false, "fill": 0.235, "vignette": 0.26},
	"Holo": {"round": false, "fill": 0.24, "vignette": 0.26},
	"Tube": {"round": true, "fill": 0.28, "edge_shadow": 0.35, "vignette": 0.3},
	"Prism": {"round": true, "fill": 0.5, "edge_shadow": 0.5, "vignette": 0.42},
	"Scope": {"round": true, "fill": 0.84, "edge_shadow": 0.4, "glass": 0.015, "glow": 0.3, "vignette": 0.6, "scope_view": true},
	"Periscope": {"round": true, "fill": 0.28, "edge_shadow": 0.35, "vignette": 0.3},
	"Gem": {"round": true, "fill": 0.25, "edge_shadow": 0.15, "vignette": 0.26},
	"Gallery": {"round": true, "fill": 0.25, "vignette": 0.26},
	"Eye": {"round": true, "fill": 0.28, "edge_shadow": 0.3, "vignette": 0.3},
	"Hex": {"round": false, "fill": 0.24, "vignette": 0.26},
	"Brass": {"round": true, "fill": 0.48, "edge_shadow": 0.5, "vignette": 0.42},
	"Burst": {"round": true, "fill": 0.24, "vignette": 0.26},
	"Ranger": {"round": false, "fill": 0.36, "edge_shadow": 0.25, "vignette": 0.34},
	"Frost": {"round": true, "fill": 0.28, "edge_shadow": 0.35, "vignette": 0.3},
	"Porthole": {"round": true, "fill": 0.26, "edge_shadow": 0.2, "vignette": 0.28},
}
## Choices of the "Sight reticle colour" setting ("auto" keeps each sight's own).
const COLORS := {
	"red": Color(1.0, 0.2, 0.26),
	"cyan": Color(0.3, 0.95, 1.0),
	"pink": Color(1.0, 0.4, 0.8),
	"green": Color(0.45, 1.0, 0.4),
	"yellow": Color(1.0, 0.86, 0.25),
	"white": Color(1.0, 1.0, 1.0),
}

static var _scene: PackedScene


## The sight a weapon wears: the equipped item, else the slot's default.
static func equipped(weapon_id: StringName) -> CosmeticItem:
	return Cosmetics.equipped_or_default(SLOT, weapon_id)


## The optic model an item uses ("" for iron sights).
static func optic_name(item: CosmeticItem) -> String:
	if item == null:
		return ""
	var optic := String(item.params.get("optic", ""))
	return optic if OPTICS.has(optic) else ""


static func pattern_index(item: CosmeticItem) -> int:
	return int(PATTERNS.get(String(item.params.get("reticle", "dot")), 0)) if item else 0


## An optic setting: the item's own params first, then the optic's defaults.
static func setting(item: CosmeticItem, key: String, fallback: Variant) -> Variant:
	if item and item.params.has(key):
		return item.params[key]
	return (OPTICS.get(optic_name(item), {}) as Dictionary).get(key, fallback)


## The reticle colour: the "sight_color" setting, or the item's own on "auto".
static func reticle_color(item: CosmeticItem) -> Color:
	var pick := String(Settings.value("sight_color"))
	if COLORS.has(pick):
		return COLORS[pick]
	return item.color(0, COLORS["red"]) if item else COLORS["red"]


## Fits `item` (null = iron sights) to a weapon model, replacing any sight
## fitted before, and returns the model's SightRig.
static func apply(model: Node3D, weapon: WeaponData, item: CosmeticItem) -> SightRig:
	var old := model.get_node_or_null(RIG)
	if old:
		model.remove_child(old)
		old.free()
	var rig := SightRig.new()
	rig.name = RIG
	model.add_child(rig)
	rig.setup(model, weapon, item)
	return rig


## Tools only (screenshots, the ADS audit): wears `sight_id` on a weapon for
## this session, owned or not, without saving.
static func wear_for_session(weapon_id: StringName, sight_id: StringName) -> void:
	var section := Profile.section("cosmetics")
	if not section.has("equipped"):
		section["equipped"] = {}
	Unlocks.grant(StringName("cosmetic:" + String(sight_id)))
	section["equipped"]["%s@%s" % [SLOT, weapon_id]] = String(sight_id)


static func rig_of(model: Node3D) -> SightRig:
	return model.get_node_or_null(RIG) as SightRig if model else null


## A fresh copy of an item's optic with its colours and lens applied (the
## reticle painted on the glass, as menus show it), or null for iron sights.
## The optic's origin is the underside of its base; -Z points to the muzzle.
static func build_optic(item: CosmeticItem) -> Node3D:
	var optic := optic_name(item)
	if optic == "":
		return null
	if _scene == null:
		_scene = load(SCENE) as PackedScene
	var library := _scene.instantiate()
	var node := library.get_node_or_null("Sight_" + optic) as Node3D
	if node == null:
		library.free()
		return null
	library.remove_child(node)
	library.free()
	node.transform = Transform3D.IDENTITY
	var color := reticle_color(item)
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if base == null:
				continue
			match String(base.resource_name):
				"SightLens":
					mi.set_surface_override_material(i, lens_material(item, mi))
				"SightAccent" when item.colors.size() > 1:
					var accent: StandardMaterial3D = base.duplicate()
					accent.albedo_color = item.color(1)
					mi.set_surface_override_material(i, accent)
				"SightGlow":
					var glow: StandardMaterial3D = base.duplicate()
					glow.albedo_color = color
					glow.emission = color
					mi.set_surface_override_material(i, glow)
	return node


## The lens material of `item` for the window mesh `lens` (in preview mode).
static func lens_material(item: CosmeticItem, lens: MeshInstance3D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WeaponCosmetics.shader(LENS_SHADER)
	var size := lens.mesh.get_aabb().size
	var half := Vector2(maxf(size.x, 1e-4), maxf(size.y, 1e-4))
	m.set_shader_parameter("lens_aspect", half / maxf(half.x, half.y))
	m.set_shader_parameter("lens_round", 1.0 if bool(setting(item, "round", false)) else 0.0)
	m.set_shader_parameter("edge_shadow", float(setting(item, "edge_shadow", 0.0)))
	m.set_shader_parameter("glass_color", Color(0.6, 0.92, 1.0, float(setting(item, "glass", 0.05))))
	m.set_shader_parameter("glow", float(setting(item, "glow", 1.0)))
	m.set_shader_parameter("pattern", pattern_index(item))
	m.set_shader_parameter("reticle_color", reticle_color(item))
	m.set_shader_parameter("reticle_size", tan(deg_to_rad(float(setting(item, "reticle_degrees", 1.2)))))
	m.set_shader_parameter("preview", 1.0)
	m.set_shader_parameter("preview_scale", float(setting(item, "preview_scale", 2.6)))
	return m
