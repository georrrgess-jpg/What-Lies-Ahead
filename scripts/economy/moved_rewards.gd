class_name MovedRewards
extends RefCounted
## One-time carry-over for level rewards that moved to the Shop (updates 12,
## 13, 16, 20, 23 and 24: new guns and melee weapons took their levels). A save that had already reached the
## level keeps the item it earned there (granted "cosmetic:<id>"); everyone
## else buys it in the Shop. "moved_rewards" in the progression section
## records the batches applied, so each runs once per profile.

## Batch id -> {cosmetic id: the level that used to give it}.
const BATCHES := {
	"u12": {&"charm_duck": 11, &"cell_blue_raspberry": 24, &"banner_ferris_glow": 28, &"banner_night_shift": 32},
	# Update 13: Jack Pot (16), Popcorn Popper (19), Yo-Yo Loco (27) and Strike Zone (38).
	"u13": {&"title_funnel_cake_fiend": 16, &"title_sharpshooter": 19, &"title_ferris_wheel_fighter": 27, &"title_neon_nightmare": 38},
	# Update 16: Ticket Ripper (12) and Coin-Op (22).
	"u16": {&"title_midway_regular": 12, &"fin_gunmetal_gold": 22},
	# Update 20: the melee weapons Ticket Flipper (17), Swirl Smasher (25) and High Striker (39).
	"u20": {&"decal_paw": 17, &"banner_marquee": 25, &"title_grand_prize": 39},
	# Update 23: Sarsaparilla Six (29) and Tin Sergeant (35).
	"u23": {&"finish_arcade_night": 29, &"charm_crown": 35},
	# Update 24: Bullseye Longbow (41).
	"u24": {&"finish_harlequin_tea": 41},
}


static func apply_if_pending() -> void:
	var sec := Profile.section("progression")
	var done: Array = sec.get("moved_rewards", [])
	var changed := false
	for batch in BATCHES:
		if done.has(batch):
			continue
		apply(BATCHES[batch])
		done.append(batch)
		changed = true
	if changed:
		sec["moved_rewards"] = done
		Profile.save_profile()


## Grants every item whose old level the save has reached. Returns their ids.
static func apply(items: Dictionary) -> Array[StringName]:
	var kept: Array[StringName] = []
	for id in items:
		var it := Cosmetics.item(id)
		if it and Progression.xp() >= Progression.xp_for_level(int(items[id])) and not Cosmetics.is_owned_anywhere(it):
			Cosmetics.grant(it)
			kept.append(id)
	return kept
