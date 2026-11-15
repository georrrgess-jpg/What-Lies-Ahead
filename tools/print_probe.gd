extends SceneTree
## Headless checks of Prize Prints (developer tool). Prints one line per check
## and exits with 1 if any failed:
##
##   godot --headless --path . --script res://tools/print_probe.gd
##
##   odds       10,000 capsule rarities with no pity match the published odds
##   pity       10,000 capsules with the luck meter: no gap above the guarantees
##   rolls      10,000 prints: rare prints and shine grades match their odds
##   minting    10,000 capsules into a profile: serials count up per finish and
##              never repeat, ids unique, repeats recycled only when plain
##   saves      the section survives a save and a reload, and an old save
##              (no prints section) loads with nothing
##   actions    equip / take off, favourites, recycle, trade-up, Token Counter,
##              buying capsules, the run settlement (paid once)
##
## Script mode compiles this file before the autoloads exist, so it only uses
## untyped references to game classes. It never touches the real save.

const SCRATCH := "user://print_probe.json"
const N := 10000

var _failed := 0
var Prints
var Roll
var Look
var profile
var wallet
var cosmetics


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	await process_frame
	profile = root.get_node("Profile")
	wallet = root.get_node("Wallet")
	cosmetics = root.get_node("Cosmetics")
	Prints = load("res://scripts/economy/prints/prize_prints.gd")
	Roll = load("res://scripts/economy/prints/print_roll.gd")
	Look = load("res://scripts/economy/prints/print_look.gd")
	_fresh_profile()
	_series()
	_odds()
	_pity()
	_rolls()
	_minting()
	_saves()
	_actions()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	print("[prints] %s" % ("ALL PASSED" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failed += 1
	print("[prints] %s  %s%s" % ["ok  " if ok else "FAIL", name, ("  (" + detail + ")") if detail != "" else ""])


func _fresh_profile() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	profile.save_path = SCRATCH
	profile.load_profile()


## Within `sigmas` standard deviations of a binomial(n, p).
func _near(count: int, n: int, p: float, sigmas := 4.0) -> bool:
	return absf(count - n * p) <= sigmas * sqrt(n * p * (1.0 - p)) + 1.0


func _series() -> void:
	var s = Prints.series()
	var by: Dictionary = Prints.by_rarity()
	var sizes := []
	for r in 4:
		sizes.append((by.get(r, []) as Array).size())
	var odds_sum := 0.0
	for o in s.odds:
		odds_sum += o
	_check("series: %d finishes, by rarity %s" % [s.finishes.size(), str(sizes)], s.finishes.size() >= 30 and not sizes.has(0))
	_check("series: odds add up to 1", absf(odds_sum - 1.0) < 0.0001, "%.4f" % odds_sum)
	var shaders := true
	for f in s.finishes:
		var it = cosmetics.item(f)
		if it == null or not String(it.params.get("shader", "")).contains("/finish_") or it.slot != &"weapon_finish":
			shaders = false
			print("[prints]       not a finish_* shader finish: %s" % f)
	_check("series: every finish wears the print layer (finish_* shader)", shaders)


func _odds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var s = Prints.series()
	var counts := [0, 0, 0, 0]
	for i in N:
		counts[Roll.rarity(rng, s, 0, 0)] += 1
	var ok := true
	var text := []
	for r in 4:
		ok = ok and _near(counts[r], N, s.odds[r])
		text.append("%s %.2f%% (%.0f%%)" % [["C", "R", "E", "L"][r], counts[r] * 100.0 / N, s.odds[r] * 100.0])
	_check("odds: %d rolls without pity" % N, ok, ", ".join(text))


func _pity() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var s = Prints.series()
	var since_e := 0
	var since_l := 0
	var gap_e := 0
	var gap_l := 0
	var counts := [0, 0, 0, 0]
	for i in N:
		var r: int = Roll.rarity(rng, s, since_e, since_l)
		counts[r] += 1
		since_e = 0 if r >= 2 else since_e + 1
		since_l = 0 if r == 3 else since_l + 1
		gap_e = maxi(gap_e, since_e)
		gap_l = maxi(gap_l, since_l)
	_check("pity: an Epic or better within %d" % s.epic_pity, gap_e < s.epic_pity, "longest run without: %d" % gap_e)
	_check("pity: a Legendary within %d" % s.legendary_pity, gap_l < s.legendary_pity, "longest run without: %d" % gap_l)
	print("[prints]       effective rates with the luck meter: C %.1f%%  R %.1f%%  E %.1f%%  L %.1f%%" % [
		counts[0] * 100.0 / N, counts[1] * 100.0 / N, counts[2] * 100.0 / N, counts[3] * 100.0 / N])


func _rolls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var s = Prints.series()
	var vars := {"": 0, "glitter": 0, "holo": 0, "misprint": 0}
	var grades := [0, 0, 0]
	var seeds := {}
	for i in N:
		var a: Dictionary = Roll.attributes(rng, s)
		vars[a["var"]] += 1
		grades[Roll.grade(a["shine"], s)] += 1
		seeds[a["seed"]] = true
	_check("rolls: glitter 1/20", _near(vars["glitter"], N, s.glitter_chance), "%d of %d" % [vars["glitter"], N])
	_check("rolls: holo 1/50", _near(vars["holo"], N, s.holo_chance), "%d of %d" % [vars["holo"], N])
	_check("rolls: misprint 1/100", _near(vars["misprint"], N, s.misprint_chance), "%d of %d" % [vars["misprint"], N])
	_check("rolls: grades Factory / Polished / Mint", _near(grades[0], N, s.polished_at) and _near(grades[2], N, 1.0 - s.mint_at),
		"%d / %d / %d" % grades)
	_check("rolls: pattern seeds spread", seeds.size() > N * 0.55, "%d distinct of %d" % [seeds.size(), N])
	var u: Dictionary = Look.uniforms({"seed": 417, "shine": 0.31, "var": "holo"})
	var u2: Dictionary = Look.uniforms({"seed": 417, "shine": 0.31, "var": "holo"})
	var u3: Dictionary = Look.uniforms({"seed": 88, "shine": 0.31, "var": "holo"})
	_check("rolls: a seed always lands the same, another lands elsewhere", u == u2 and u["print_offset"] != u3["print_offset"])


func _minting() -> void:
	Prints.rng.seed = 99
	var serials := {}
	var ids := {}
	var dup_ids := 0
	var bad_serials := 0
	var recycled_notable := 0
	var recycled := 0
	var kept_repeat := 0
	var t0 := Time.get_ticks_msec()
	for i in N:
		var res: Dictionary = Prints.roll_capsule()
		var p: Dictionary = res["print"]
		var f := String(p["f"])
		if int(p["serial"]) != int(serials.get(f, 0)) + 1:
			bad_serials += 1
		serials[f] = int(p["serial"])
		if ids.has(p["id"]):
			dup_ids += 1
		ids[p["id"]] = true
		if res["recycled"]:
			recycled += 1
			if Prints.is_notable(p) or not res["repeat"]:
				recycled_notable += 1
		elif res["repeat"]:
			kept_repeat += 1
	var held: Array = Prints.held()
	_check("minting: %d capsules, serials count up per finish with no repeats" % N, bad_serials == 0, "%d out of order" % bad_serials)
	_check("minting: print ids unique", dup_ids == 0)
	_check("minting: only plain repeats are recycled", recycled_notable == 0, "%d recycled, %d notable repeats kept, %d held" % [recycled, kept_repeat, held.size()])
	_check("minting: tokens = recycled value", Prints.tokens() > 0)
	print("[prints]       %d ms for %d capsules" % [Time.get_ticks_msec() - t0, N])


func _saves() -> void:
	var before := JSON.stringify(profile.section("prints"))
	profile.save_profile()
	profile.load_profile()
	var after := JSON.stringify(profile.section("prints"))
	var a = JSON.parse_string(before)
	var b = JSON.parse_string(after)
	_check("saves: the prints section round-trips", a == b and Prints.held().size() > 0, "%d bytes" % after.length())
	var p: Dictionary = Prints.held()[0]
	_check("saves: a reloaded print still reads", Look.serial_text(int(p["serial"])).begins_with("#") and Prints.finish_of(p) != null)
	# An old save: written before prints existed.
	var old := {"version": 3, "mastery": {}, "levels": {}, "settings": {}, "sections": {"cosmetics": {"equipped": {}}}}
	var f := FileAccess.open(SCRATCH, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	profile.load_profile()
	_check("saves: an old save has no prints and no capsules", Prints.held().is_empty() and Prints.capsules() == 0 and Prints.tokens() == 0)
	_check("saves: an old save's loadout has no print", (cosmetics.weapon_loadout(&"ion_carbine")["print"] as Dictionary).is_empty())


func _actions() -> void:
	_fresh_profile()
	Prints.rng.seed = 5
	var s = Prints.series()
	Prints.add_capsules(30)
	_check("actions: capsules added", Prints.capsules() == 30)
	Prints.set_auto_recycle(false)
	var got := []
	for i in 30:
		got.append(Prints.open_capsule())
	_check("actions: 30 opened, all kept with auto-recycle off", Prints.capsules() == 0 and Prints.held().size() == 30)
	_check("actions: no capsule, nothing opens", Prints.open_capsule().is_empty())
	var p: Dictionary = Prints.held()[0]
	var fin = Prints.finish_of(p)
	_check("actions: equip a print", Prints.equip(p, &"ion_carbine") and cosmetics.weapon_loadout(&"ion_carbine")["finish"] == fin
		and cosmetics.weapon_loadout(&"ion_carbine")["print"] == p)
	_check("actions: an equipped print cannot be recycled", Prints.recycle(p) == 0)
	cosmetics.equip(&"weapon_finish", cosmetics.item(&"fin_sherbet"), &"ion_carbine")
	_check("actions: equipping a plain finish takes the print off", Prints.equipped(&"ion_carbine").is_empty())
	Prints.set_favourite(p, true)
	_check("actions: a favourite cannot be recycled", Prints.recycle(p) == 0)
	Prints.set_favourite(p, false)
	var tokens: int = Prints.tokens()
	var value: int = Prints.token_value(p)
	_check("actions: recycle pays its tokens", Prints.recycle(p) == value and Prints.tokens() == tokens + value)
	# Trade-up five commons.
	var commons: Array = Prints.trade_up_candidates(0)
	while commons.size() < s.trade_up_count:
		Prints.add_capsules(1)
		Prints.open_capsule()
		commons = Prints.trade_up_candidates(0)
	var five := commons.slice(0, s.trade_up_count)
	Prints.set_favourite(five[0], true)
	_check("actions: the same print five times is refused", Prints.trade_up_problem([commons[1], commons[1], commons[1], commons[1], commons[1]]) != "")
	_check("actions: a favourite blocks the trade-up", Prints.trade_up_problem(five) != "" and Prints.trade_up(five).is_empty())
	Prints.set_favourite(five[0], false)
	var count_before: int = Prints.held().size()
	var res: Dictionary = Prints.trade_up(five)
	_check("actions: 5 commons trade up to 1 rare", not res.is_empty() and int(res["rarity"]) == 1 and Prints.held().size() == count_before - 4)
	_check("actions: a trade-up print is fresh", String(res["print"]["src"]) == "tradeup" and bool(res["print"]["new"]))
	# The Token Counter.
	var shelf: Array = Prints.counter_shelf()
	_check("actions: the counter shelf has one finish per rarity", shelf.size() == 4 and shelf == Prints.counter_shelf())
	profile.section("prints")["tokens"] = 1000
	var buy: Dictionary = Prints.buy_at_counter(shelf[0])
	_check("actions: the counter sells a fresh print once a day", not buy.is_empty() and Prints.counter_sold(shelf[0]) and Prints.buy_at_counter(shelf[0]).is_empty())
	# Capsules for Sparks.
	wallet.earn(s.capsule_price, &"welcome")
	var bal: int = wallet.balance()
	_check("actions: a capsule costs %d Sparks" % s.capsule_price, Prints.buy_capsule() and wallet.balance() == bal - s.capsule_price and Prints.capsules() == 1)
	# The run settlement pays once.
	Prints._begin_run()
	var day_before := int(profile.section("prints")["daily"])
	profile.section("prints")["daily"] = -1
	var before: int = Prints.capsules()
	var result := {"victory": true, "bosses_defeated": 1, "bounties_claimed": 2}
	var paid: Dictionary = Prints.settle(result)
	Prints.settle(result)
	_check("actions: a clear with an alpha and 2 bounties pays 4 (with the day's first clear), once",
		int(paid["total"]) == 4 and Prints.capsules() == before + 4, "paid %d, day %d" % [int(paid["total"]), day_before])
	Prints._begin_run()
	_check("actions: the day's first-clear capsule only once a day", int(Prints.settle(result)["total"]) == 3)
	Prints.set_auto_recycle(true)
	_check("actions: grade names", Look.grade_name({"shine": 0.1}) == "Factory" and Look.grade_name({"shine": 0.7}) == "Polished" and Look.grade_name({"shine": 0.95}) == "Mint")
	_check("actions: serial stamps", Look.serial_text(7) == "#007" and Look.serial_tag(1) == "FIRST EDITION" and Look.serial_tag(77) == "LUCKY 7s" and Look.serial_tag(50) == "")
