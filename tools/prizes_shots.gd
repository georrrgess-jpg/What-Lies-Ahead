extends RefCounted
## Stills of the Prizes page (developer tool): the machine, the opening
## sequence frame by frame, the collection with the inspect view, the
## trade-up, the Token Counter and the odds. Run on a scratch profile:
##
##   xvfb-run -a godot --path . --resolution 960x540 -- --profile=/tmp/prints/s.json \
##       --shot=/tmp/prints/prizes.png --shot-scene=prizes --shot-run=res://tools/prizes_shots.gd
##
## Saves <shot>_<name>.png. --shot-print=holo|glitter|misprint|none stages the
## opened print as a Legendary Mint with that rare print (default holo).

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
	await _save("machine")
	await _opening(page)
	page._reveal.close()
	await _frames(20)
	page._show_view(&"collection")
	page._select(PrizePrints.held()[PrizePrints.held().size() - 1])
	await _frames(60)
	await _save("collection")
	page._show_view(&"tradeup")
	page._auto_fill()
	await _frames(60)
	await _save("tradeup")
	page._show_view(&"counter")
	await _frames(60)
	await _save("counter")
	page._show_view(&"odds")
	await _frames(20)
	await _save("odds")
	# A print worn on the Ion Carbine, seen from the Locker.
	var worn: Dictionary = PrizePrints.held()[0]
	PrizePrints.equip(worn, &"ion_carbine")
	menu._show("locker")
	var locker := menu.page("locker") as LockerPage
	locker.select_weapon(&"ion_carbine")
	locker.select_item(StringName(String(worn["f"])))
	await _frames(90)
	await _save("locker")


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
	PrizePrints.add_capsules(6)
	Profile.section("prints")["tokens"] = 140
	PrizePrints.set_auto_recycle(true)


func _opening(page: PrizesPage) -> void:
	page._open_capsule()
	var res: Dictionary = page._pending
	var p: Dictionary = res["print"]
	var staged := _arg("print", "holo")
	p["f"] = "fin_marquee"
	p["var"] = "" if staged == "none" else staged
	p["shine"] = 0.962
	p["serial"] = 7
	res["rarity"] = 3
	res["repeat"] = false
	res["recycled"] = false
	page._machine._drop_color = PrintLook.rarity_color(p)
	# Run with --fixed-fps 60: one frame is 1/60 s of the sequence.
	var frame := 0
	for t in [0.4, 1.3, 1.9, 2.6, 3.4, 4.3, 5.4, 7.5]:
		while frame < roundi(t * 60.0):
			await _tree.process_frame
			frame += 1
		await _save("open_%.2f" % t)


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
