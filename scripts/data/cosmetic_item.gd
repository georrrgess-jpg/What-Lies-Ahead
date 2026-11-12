class_name CosmeticItem
extends Resource
## One cosmetic: a weapon finish, energy-cell colour, decal or charm, glove
## skin, kill effect, tracer style, banner, title or avatar. Purely visual.
##
## Items are discovered by scanning data/cosmetics/ (any subfolder), so adding
## a skin is: drop a new .tres in there. Unlocks come from `requirement`
## (null = owned by default), or from the shop: an item with a `price` is
## bought with Sparks (see Cosmetics.buy) once its requirement, if any, is met.

enum Rarity { COMMON, RARE, EPIC, LEGENDARY, MASTERY }

## Stable ID saved in the profile. Never rename once shipped.
@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## Where it goes. Weapon slots (per weapon): "weapon_finish", "weapon_cell",
## "weapon_decal", "weapon_charm", "weapon_sight". Global slots: "gloves", "kill_effect",
## "tracer", "banner", "title", "avatar". New slots can be added freely.
@export var slot: StringName = &"weapon_finish"
## For weapon slots: the weapon this is for. Empty = fits every weapon.
@export var weapon_id: StringName
@export var rarity: Rarity = Rarity.COMMON
@export var requirement: Requirement
## Price in Sparks. 0 = not for sale (owned through `requirement` alone).
## A priced item is owned once bought; its requirement only gates the purchase.
@export var price := 0
## Main colours (meaning depends on slot; finishes use [shell, trim, accent]).
@export var colors: PackedColorArray = PackedColorArray()
## Free-form parameters for the renderer of this slot, e.g.
## {"metallic": 0.8, "roughness": 0.3, "shader": "res://...", "pattern": "stripes"}.
@export var params: Dictionary = {}
@export var sort_order := 0


func color(i: int, fallback := Color.WHITE) -> Color:
	return colors[i] if i < colors.size() else fallback


func is_weapon_slot() -> bool:
	return String(slot).begins_with("weapon_")


func fits_weapon(wid: StringName) -> bool:
	return weapon_id == &"" or weapon_id == wid


func slot_label() -> String:
	match String(slot):
		"weapon_finish": return "Weapon finish"
		"weapon_cell": return "Energy cell"
		"weapon_decal": return "Decal"
		"weapon_charm": return "Charm"
		"weapon_sight": return "Sight"
		"gloves": return "Gloves"
		"kill_effect": return "Kill effect"
		"tracer": return "Tracer"
		"banner": return "Banner"
		"title": return "Title"
		"avatar": return "Avatar"
	return String(slot).capitalize()


static func rarity_color(r: Rarity) -> Color:
	match r:
		Rarity.RARE: return Color("4fb4ff")
		Rarity.EPIC: return Color("b45cff")
		Rarity.LEGENDARY: return Color("ffb22e")
		Rarity.MASTERY: return Color("35f0ff")
	return Color("c9c6d2")


static func rarity_name(r: Rarity) -> String:
	return ["Common", "Rare", "Epic", "Legendary", "Mastery"][int(r)]
