extends RefCounted
## The Locker's weapon picker under rapid switching: on the WEAPON SKINS tab,
## steps the customised weapon 20 times one frame apart
## and 20 times at about five per second, timing every frame, then waits for
## the thumbnails to settle and checks that the case's model and every
## visible card's thumbnail belong to the weapon now customised.
## (12 s at most for the thumbnails to catch up after each run.)
## Run on a real display so the 3D work is timed too:
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 1600x900 -- \
##       --profile=<copy> --shot=/tmp/x.png --shot-scene=locker \
##       --shot-run=res://scripts/dev/locker_switch_probe.gd
##
## Prints "[switch] <phase>: frames N, max X ms, p95 Y ms" and
## "[switch] DONE <n> mismatches"; saves <shot> after the last switch.

var _tree: SceneTree
var _page: LockerPage
var _mismatches := 0


func run(shot: Node, menu: Node) -> void:
	_tree = menu.get_tree()
	_page = menu.page("locker")
	print("[switch] start")
	var slot := &"weapon_finish"
	_page.show_category(slot)
	await _wait_settled()
	await _measure("idle", -1)
	await _measure("every frame", 0)
	await _check(slot)
	await _measure("5 per second", 200)
	await _check(slot)
	var image := _tree.root.get_texture().get_image()
	image.save_png(String(shot.call("_arg", "shot", "/tmp/locker_switch.png")))
	print("[switch] DONE %d mismatches" % _mismatches)


## 20 weapon steps, one a frame (`gap_ms` 0) or one every `gap_ms` (none
## for -1: 20 frames of the page at rest), timing
## each frame until the thumbnail queue drains (or 12 s pass).
func _measure(phase: String, gap_ms: int) -> void:
	var times: Array[float] = []
	var last := Time.get_ticks_usec()
	var steps := 0
	var start := Time.get_ticks_msec()
	var next_step := start
	if gap_ms < 0:
		steps = 20
	while times.size() < 20 or steps < 20 or (_busy() and Time.get_ticks_msec() - start < 12000):
		if steps < 20 and Time.get_ticks_msec() >= next_step:
			_page._step_weapon(1)
			steps += 1
			next_step += gap_ms
		await _tree.process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	var sorted := times.duplicate()
	sorted.sort()
	print("[switch] %s: frames %d, max %.1f ms, p95 %.1f ms, settled in %.1f s" % [phase, times.size(),
			sorted[-1], sorted[int(sorted.size() * 0.95)], (Time.get_ticks_msec() - start) / 1000.0])


func _busy() -> bool:
	var thumbs := _page._thumbs
	return thumbs.is_processing() or not thumbs._queue.is_empty() or not _page._weapon_timer.is_stopped()


func _wait_settled() -> void:
	var start := Time.get_ticks_msec()
	while _busy() and Time.get_ticks_msec() - start < 12000:
		await _tree.process_frame
	for i in 4:
		await _tree.process_frame


## The case and every visible card show the weapon now customised.
func _check(slot: StringName) -> void:
	await _wait_settled()
	var weapon := _page._weapon()
	var stage: LockerStage = _page._showcase._stage
	if stage._weapon != weapon:
		_fail("%s: case shows %s, customising %s" % [slot, stage._weapon.id if stage._weapon else &"-", weapon.id])
	if _page._showcase.item != _page._selected:
		_fail("%s: case shows another item than the selected one" % slot)
	var cards := 0
	var blank := 0
	for card in _page._cards:
		if not card.visible:
			continue
		cards += 1
		if card.weapon != weapon:
			_fail("%s: card %s is for %s" % [slot, card.item.id, card.weapon.id if card.weapon else &"-"])
			continue
		if not CosmeticThumbs.can_bake(card.item):
			continue
		var want := CosmeticThumbs.cached(card.item, weapon)
		if card._picture.texture == null:
			blank += 1
		if card._picture.texture != want:
			var owner := "none"
			for k in CosmeticThumbs._cache:
				if CosmeticThumbs._cache[k] == card._picture.texture:
					owner = k
			_fail("%s: card %s shows thumbnail %s on %s" % [slot, card.item.id, owner, weapon.id])
	print("[switch] checked %s on %s: %d cards, %d still baking" % [slot, weapon.id, cards, blank])


func _fail(what: String) -> void:
	_mismatches += 1
	print("[switch] MISMATCH " + what)
