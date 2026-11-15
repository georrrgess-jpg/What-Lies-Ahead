class_name MythicFx
extends RefCounted
## The Mythic rarity's look (CosmeticItem.Rarity.MYTHIC, the Endless rewards):
## wherever a rarity is shown, a Mythic item gets an animated red-gold flow
## with a sweeping glint (art/shaders/ui_mythic.gdshader) instead of a flat
## colour, so it reads above Legendary's gold. One shared material; it keeps
## dark pixels (ink, shadows) as they are, so it suits plates, lines and text.
##
##   MythicFx.dress(rarity_line, item)   # ColorRect, Label, chip...: Mythic only
##   MythicFx.tint(item)                 # the colour of this moment (for _draw code)

const SHADER := "res://art/shaders/ui_mythic.gdshader"
## The gold end of the Mythic flow (the red end is the rarity colour).
const GOLD := Color(1.0, 0.76, 0.24)

static var _material: ShaderMaterial


static func is_mythic(item: CosmeticItem) -> bool:
	return item != null and item.rarity == CosmeticItem.Rarity.MYTHIC


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load(SHADER)
	return _material


## Gives `control` the Mythic treatment when `item` is Mythic, and takes it
## away otherwise (cards and panels are reused for other items). A chip's
## lettering follows its plate.
static func dress(control: CanvasItem, item: CosmeticItem) -> void:
	var on := is_mythic(item)
	if on:
		control.material = material()
	elif control.material == _material:
		control.material = null
	if control is KitChip:
		for child in control.get_children():
			if child is Label:
				child.use_parent_material = on


## The Mythic colour right now (red to gold), for code that draws its own
## shapes; other rarities get their flat colour.
static func tint(item: CosmeticItem) -> Color:
	var base := CosmeticItem.rarity_color(item.rarity)
	if not is_mythic(item):
		return base
	var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0015)
	return base.lerp(GOLD, k)
