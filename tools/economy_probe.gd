extends SceneTree
## Headless checks of the Sparks economy (developer tool). Prints one line per
## check and exits with 1 if any failed:
##
##   godot --headless --path . --script res://tools/economy_probe.gd
##
##   rules      what kills, levels and ranks pay; the price ladder; the level track
##   earning    Wallet.earn / spend, Sparks for level-ups and mastery ranks
##   buying     Cosmetics.can_buy / buy on a fresh profile
##   featured   the daily selection: deterministic, mixed, discounted, stable
##   contracts  three at a time, completion and roll-over
##   migration  old saves (tools/fixtures/economy/*.json, written in the old
##              format) keep everything the pre-economy game said they owned
##              (*.expected.json, produced by that version of the game)
##
## Script mode compiles this file before the autoloads exist, so it only uses
## untyped references to game classes. It never touches the real save.

const FIXTURES := "res://tools/fixtures/economy"
const SCRATCH := "user://economy_probe.json"

var _failed := 0
var Shop
var Board
var Legacy
var profile
var wallet
var cosmetics
var progression
var mastery
var game_data


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	await process_frame
	profile = root.get_node("Profile")
	wallet = root.get_node("Wallet")
	cosmetics = root.get_node("Cosmetics")
	progression = root.get_node("Progression")
	mastery = root.get_node("Mastery")
	game_data = root.get_node("GameData")
	Shop = load("res://scripts/economy/shop_catalog.gd")
	Board = load("res://scripts/progression/contract_board.gd")
	Legacy = load("res://scripts/economy/legacy_grant.gd")
	_rules()
	_fresh_profile()
	_earning()
	_buying()
	_featured()
	_contracts()
	_migration()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	print("[probe] %s" % ("ALL PASSED" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failed += 1
	print("[probe] %s  %s%s" % ["ok  " if ok else "FAIL", name, ("  (" + detail + ")") if detail != "" else ""])


func _fresh_profile() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	profile.save_path = SCRATCH
	profile.load_profile()


# --- rules -------------------------------------------------------------------------

func _rules() -> void:
	var rules = wallet.rules
	var kill := []
	for id in [&"tourist_shambler", &"lifeguard_runner", &"deep_diver", &"boardwalk_bruiser"]:
		kill.append(rules.kill_sparks(game_data.enemy(id).tickets))
	_check("rules: a tourist, a runner, a diver and a bruiser drop 1, 1, 2 and 5 Sparks", kill == [1, 1, 2, 5], str(kill))
	_check("rules: level 2 pays 60 Sparks, level 5 (milestone) 175, level 40 350",
		[rules.level_sparks(2), rules.level_sparks(5), rules.level_sparks(40)] == [60, 175, 350])
	var empty := []
	for lvl in range(2, progression.MAX_LEVEL + 1):
		if progression.level_weapons(lvl).is_empty() and progression.level_rewards(lvl).is_empty():
			empty.append(lvl)
	_check("rules: every level from 2 to %d gives a weapon or a cosmetic" % progression.MAX_LEVEL, empty.is_empty(), str(empty))
	var off_ladder := []
	var total := 0
	for it in Shop.items():
		total += it.price
		if it.price != rules.price_for(it.rarity) and it.slot != &"weapon_sight":
			off_ladder.append(String(it.id))
	_check("rules: %d items for sale (%d Sparks), priced on the rarity ladder" % [Shop.items().size(), total], off_ladder.is_empty(), str(off_ladder))
	var sections := []
	for section in Shop.sections():
		sections.append("%s %d" % [section["title"], section["items"].size()])
	print("[probe]       shop sections: ", ", ".join(sections))


# --- earning -----------------------------------------------------------------------

func _earning() -> void:
	_check("earning: a new profile starts with 0 Sparks", wallet.balance() == 0)
	wallet.earn(500, &"test")
	_check("earning: earn adds to the balance and the lifetime total", wallet.balance() == 500 and wallet.lifetime_earned() == 500)
	_check("earning: spending more than the balance is refused", not wallet.spend(501, &"test") and wallet.balance() == 500)
	_check("earning: spend takes Sparks and keeps the lifetime total", wallet.spend(200, &"test") and wallet.balance() == 300 and wallet.lifetime_earned() == 500)
	var before: int = wallet.balance()
	progression.add_xp(progression.xp_for_level(4))
	var expected: int = wallet.rules.level_sparks(2) + wallet.rules.level_sparks(3) + wallet.rules.level_sparks(4)
	_check("earning: reaching level 4 pays the Sparks of levels 2, 3 and 4", progression.level() == 4 and wallet.balance() - before == expected, "%d of %d" % [wallet.balance() - before, expected])
	before = wallet.balance()
	mastery.grant(&"ion_carbine", mastery.rank_floor(2), 0)
	expected = wallet.rules.rank_sparks(1) + wallet.rules.rank_sparks(2)
	_check("earning: mastery ranks 1 and 2 pay their Sparks", mastery.rank(&"ion_carbine") == 2 and wallet.balance() - before == expected, "%d of %d" % [wallet.balance() - before, expected])
	_check("earning: Wallet.format adds thousands separators", wallet.format(1234567) == "1,234,567" and wallet.format(950) == "950")


# --- buying ------------------------------------------------------------------------

func _buying() -> void:
	_fresh_profile()
	var it = cosmetics.item(&"fin_synthwave")
	var cost: int = cosmetics.price_of(it)
	_check("buying: a shop item is for sale and not owned", cosmetics.is_for_sale(it) and not cosmetics.is_owned(it, &"ion_carbine"))
	_check("buying: it cannot be equipped or bought without Sparks", not cosmetics.can_buy(it, &"ion_carbine") and not cosmetics.buy(it, &"ion_carbine") and not cosmetics.equip(&"weapon_finish", it, &"ion_carbine"))
	wallet.earn(cost + 40, &"test")
	_check("buying: buy charges price_of and grants the item", cosmetics.buy(it, &"ion_carbine") and wallet.balance() == 40 and cosmetics.is_owned(it, &"ion_carbine"))
	_check("buying: it is no longer for sale and cannot be bought twice", not cosmetics.is_for_sale(it) and not cosmetics.buy(it, &"ion_carbine") and wallet.balance() == 40)
	_check("buying: it equips, on any weapon it fits", cosmetics.equip(&"weapon_finish", it, &"pulse_pistol") and cosmetics.equipped(&"weapon_finish", &"pulse_pistol") == it)
	profile.load_profile()
	_check("buying: the purchase is saved", cosmetics.is_owned(it) and wallet.balance() == 40)
	var earned_reward = cosmetics.item(&"kfx_pixel")
	_check("buying: an earned reward is not for sale", not cosmetics.is_for_sale(earned_reward) and not cosmetics.buy(earned_reward))
	var p: Vector2i = Shop.progress()
	_check("buying: ShopCatalog.progress counts it", p.x == 1 and p.y == Shop.items().size(), str(p))


# --- featured ----------------------------------------------------------------------

func _featured() -> void:
	_fresh_profile()
	var today: int = Shop.day()
	var first := _ids(Shop.pick_featured(today))
	_check("featured: %d items, the same every time for one day" % wallet.rules.featured_count,
		first.size() == wallet.rules.featured_count and first == _ids(Shop.pick_featured(today)) and first == _ids(Shop.featured()), str(first))
	var rarities := []
	for it in Shop.featured():
		rarities.append(int(it.rarity))
	rarities.sort()
	_check("featured: one item of every rarity (common to legendary)", rarities == [0, 1, 2, 3], str(rarities))
	var changes := 0
	var seen := {}
	for d in range(today, today + 14):
		var ids := _ids(Shop.pick_featured(d))
		if ids != _ids(Shop.pick_featured(d + 1)):
			changes += 1
		for id in ids:
			seen[id] = true
	_check("featured: the selection rotates every day (14 of 14 days differ, %d different items in two weeks)" % seen.size(), changes == 14 and seen.size() >= 20)
	var it = Shop.featured()[0]
	var cut: int = int(round(it.price * (1.0 - wallet.rules.featured_discount) / 5.0)) * 5
	_check("featured: %s costs %d instead of %d" % [it.display_name, cut, it.price], Shop.price(it) == cut and cosmetics.price_of(it) == cut and Shop.discount(it) > 0.0 and Shop.base_price(it) == it.price)
	var other = null
	for candidate in Shop.items():
		if not Shop.is_featured(candidate):
			other = candidate
			break
	_check("featured: other items cost their full price", Shop.price(other) == other.price and Shop.discount(other) == 0.0)
	wallet.earn(cut, &"test")
	_check("featured: buying it charges the discounted price", Shop.can_buy(it) and Shop.buy(it) and wallet.balance() == 0 and not Shop.can_buy(it))
	_check("featured: the day's selection does not refill after a purchase", _ids(Shop.featured()) == first)
	profile.load_profile()
	_check("featured: and is the same after a restart", _ids(Shop.featured()) == first)


func _ids(items: Array) -> Array:
	var out := []
	for it in items:
		out.append(String(it.id))
	return out


# --- contracts ---------------------------------------------------------------------

func _contracts() -> void:
	_fresh_profile()
	var hand: Array = Board.active()
	var ids := []
	for entry in hand:
		ids.append(String(entry["id"]))
	_check("contracts: a new profile is dealt the three easiest", ids == ["c_pop", "c_waves", "c_headshots"], str(ids))
	_check("contracts: kills count towards 'Pop 100 zombies'", Board.record(&"kills", 60).is_empty() and Board.progress(hand[0]) == 60)
	var done: Array = Board.record(&"kills", 60)
	_check("contracts: reaching the goal completes it once", done.size() == 1 and Board.is_done(hand[0]) and Board.record(&"kills", 500).is_empty() and Board.completed_count() == 1)
	_check("contracts: a finished contract stays on the board until the run ends", Board.active().size() == 3)
	var dealt: Array = Board.roll_over()
	var after := []
	for entry in Board.active():
		after.append(String(entry["id"]))
	_check("contracts: roll-over replaces it with a different one", dealt.size() == 1 and after.size() == 3 and not after.has("c_pop") and after.has("c_waves"), str(after))
	var worst := 0
	var duplicates := false
	for i in 60:
		for entry in Board.active():
			Board.record(Board.template(entry).stat, 100000, StringName(String(entry["weapon"])))
		Board.roll_over()
		var now := {}
		for entry in Board.active():
			duplicates = duplicates or now.has(entry["id"])
			now[entry["id"]] = true
		worst = maxi(worst, Board.active().size())
	_check("contracts: after 60 rounds there are still exactly three, never two of a kind", worst == 3 and Board.active().size() == 3 and not duplicates)
	var pay := 0
	for template in Board.templates():
		pay += template.sparks
	print("[probe]       %d contract templates, %d Sparks on average" % [Board.templates().size(), pay / maxi(1, Board.templates().size())])


# --- migration ---------------------------------------------------------------------

func _migration() -> void:
	for name in ["legacy_early", "legacy_level9", "legacy_mid", "legacy_max"]:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.expected.json" % [FIXTURES, name]))
		var f := FileAccess.open(SCRATCH, FileAccess.WRITE)
		f.store_string(FileAccess.get_file_as_string("%s/%s.json" % [FIXTURES, name]))
		f.close()
		profile.load_profile()
		var xp_before: int = progression.xp()
		Legacy.apply_if_pending()
		var lost := []
		var owned := 0
		for it in game_data.cosmetics():
			var has: bool = cosmetics.is_owned_anywhere(it)
			owned += 1 if has else 0
			if expected["owned"].has(String(it.id)) and not has:
				lost.append(String(it.id))
		var weapons_lost := []
		for id in expected["weapons"]:
			if not game_data.is_weapon_unlocked(game_data.weapon(StringName(id))):
				weapons_lost.append(id)
		var unequipped := []
		for key in expected["equipped"]:
			var parts := String(key).split("@")
			var worn = cosmetics.equipped(StringName(parts[0]), StringName(parts[1]) if parts.size() > 1 else &"")
			if worn == null or String(worn.id) != String(expected["equipped"][key]):
				unequipped.append(key)
		var report: Dictionary = profile.section("economy").get("legacy", {})
		_check("migration: %s keeps all %d cosmetics it owned (owns %d now)" % [name, expected["owned"].size(), owned], lost.is_empty(), str(lost))
		_check("migration: %s keeps its %d weapons and %d equipped items" % [name, expected["weapons"].size(), expected["equipped"].size()],
			weapons_lost.is_empty() and unequipped.is_empty(), "%s %s" % [weapons_lost, unequipped])
		_check("migration: %s level %d -> %d (XP %d -> %d), %d Sparks back pay" % [name, expected["level"], progression.level(), xp_before, progression.xp(), int(report.get("sparks", 0))],
			progression.xp() >= xp_before and wallet.balance() == int(report.get("sparks", -1)) and wallet.balance() > 0)
		var balance: int = wallet.balance()
		profile.load_profile()
		Legacy.apply_if_pending()
		_check("migration: %s is migrated once (saved as version %d)" % [name, profile.SAVE_VERSION], wallet.balance() == balance and not profile.section("economy").has("legacy_pending"))
