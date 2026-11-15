extends RefCounted
## Stills of the Prizes page (developer tool): every tab, the capsule opening
## frame by frame for each rarity, OPEN 5, and Prize Fusion (the trade-up)
## frame by frame. Run on a scratch profile, with a fixed frame rate (one
## frame is 1/60 s of the sequences):
##
##   xvfb-run -a godot --path . --fixed-fps 60 --resolution 960x540 -- --profile=/tmp/prints/s.json \
##       --shot=/tmp/prints/prizes.png --shot-scene=prizes --shot-run=res://tools/prizes_shots.gd
##
## Saves <shot>_<name>.png. Options:
##   --shot-only=tabs       just the five tabs (for checking other window sizes)
##   --shot-rarity=0..3     open only that rarity (default: all four, Common to Legendary)

## How each rarity's staged print looks: shine, rare print, serial.
const STAGED := [[0.42, "", 23], [0.74, "", 4], [0.93, "glitter", 1], [0.962, "holo", 7]]

var _tree: SceneTree
var _shot: Node
var _base := ""


func run(shot: Node, menu: Node) -> void:
	_tree = shot.get_tree()
	_shot = shot
	_base = String(shot.path).get_basename()
	var page := menu.page("prizes") as PrizesPage
	_stage_collection()
	page.refresh()
	await _frames(40)
	await _tabs(page)
	if _arg("only", "") == "tabs":
		return
	var only := _arg("rarity", "")
	for r in 4:
		if only == "" or only == str(r):
			await _opening(page, r)
	if only == "":
		await _open_five(page)
		await _fusion(page)
		await _locker(menu)


func _tabs(page: PrizesPage) -> void:
	page.show_view(&"capsules")
	await _frames(30)
	await _save("capsules")
	page.show_view(&"collection")
	page.collection_view.select(PrizePrints.held()[PrizePrints.held().size() - 1])
	await _frames(60)
	await _save("collection")
	page.show_view(&"tradeup")
	page.fusion_view.auto_fill()
	await _frames(60)
	await _save("tradeup")
	page.show_view(&"counter")
	await _frames(60)
	await _save("counter")
	page.show_view(&"odds")
	await _frames(30)
	await _save("odds")
	page.show_view(&"capsules")
	await _frames(20)


## A collection of 40 prints with every rare print in it, and capsules to open.
func _stage_collection() -> void:
	PrizePrints.rng.seed = 2026
	PrizePrints.set_auto_recycle(false)
	for i in 40:
		PrizePrints.roll_capsule()
	var held := PrizePrints.held()
	var vars := ["holo", "glitter", "misprint", "glitter"]
	for i in vars.size():
		held[i * 7]["var"] = vars[i]
	PrizePrints.add_capsules(12)
	Profile.section("prints")["tokens"] = 140
	PrizePrints.set_auto_recycle(true)


## One opening of rarity `r`, frame by frame: the machine, the crank, the
## push-in, the wobble, the burst, the landing, the stamps and the hero card.
func _opening(page: PrizesPage, r: int) -> void:
	var res := PrizePrints.open_capsule()
	var p: Dictionary = res["print"]
	p["f"] = String(PrizePrints.by_rarity()[r][0])
	p["shine"] = STAGED[r][0]
	p["var"] = STAGED[r][1]
	p["serial"] = STAGED[r][2]
	p["w"] = ""
	res["rarity"] = r
	res["repeat"] = false
	res["recycled"] = false
	page.busy = true
	page._pending = [res]
	page._reveal.play(res, page.weapon_for(p), true)
	var wobble: float = CapsuleReveal.WOBBLE[r]
	var burst := 0.4 + 2.0 + 0.55 + wobble
	var land: float = burst + [0.5, 0.6, 0.8, 1.6][r]
	var marks := [["a_machine", 0.35], ["b_crank", 1.3], ["c_drop", 2.3], ["d_push", 2.75], ["e_wobble", 2.95 + wobble * 0.8],
		["f_burst", burst + 0.12], ["g_reveal", burst + 0.45], ["h_land", land + 0.45], ["i_stamps", land + 2.3], ["j_hero", land + 5.5]]
	await _timeline(marks, "open%d_" % r)
	page._reveal.close()
	await _frames(10)


func _open_five(page: PrizesPage) -> void:
	page.open_capsules(CapsuleReveal.MULTI)
	await _timeline([["a", 1.0], ["b", 2.4], ["c", 3.6], ["d", 5.0], ["e", 9.0]], "five_")
	page._reveal._inspect_multi(4)
	await _frames(30)
	await _save("five_f_inspect")
	page._reveal.close()
	await _frames(10)


func _fusion(page: PrizesPage) -> void:
	page.show_view(&"tradeup")
	page.fusion_view.auto_fill()
	await _frames(20)
	var picked: Array = page.fusion_view._picked.duplicate()
	var res := PrizePrints.trade_up(picked)
	page.play_fusion(res, picked)
	await _timeline([["a_pods", 0.9], ["b_charge", 2.4], ["c_charged", 3.7], ["d_stream", 4.4], ["e_core", 5.5],
		["f_holo", 6.6], ["g_stamps", 8.6], ["h_hero", 11.5]], "fusion_")
	page._fusion.close()
	await _frames(10)


## A print worn on the Ion Carbine, seen from the Locker.
func _locker(menu: Node) -> void:
	var worn: Dictionary = PrizePrints.held()[0]
	PrizePrints.equip(worn, &"ion_carbine")
	menu._show("locker")
	var locker := menu.page("locker") as LockerPage
	locker.select_weapon(&"ion_carbine")
	locker.select_item(StringName(String(worn["f"])))
	await _frames(90)
	await _save("locker")


## Saves a frame at each [name, seconds] mark, counted from now.
func _timeline(marks: Array, prefix: String) -> void:
	var frame := 0
	for m in marks:
		while frame < roundi(float(m[1]) * 60.0):
			await _tree.process_frame
			frame += 1
		await _save(prefix + String(m[0]))


func _arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-%s=" % key):
			return a.split("=", true, 1)[1]
	return fallback


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var file := "%s_%s.png" % [_base, name]
	_shot.get_viewport().get_texture().get_image().save_png(file)
	print("[shot] saved ", file)
