extends RefCounted
## The results screen's operator portrait (the player card's OperatorPreview)
## at four window sizes, while popups land: a level up, a mastery rank, new
## Locker items and Prize prints, a new weapon. Per size it saves a still,
## <shot>_<w>x<h>.png, and prints the portrait's box, its 3D view's size and
## whether its model was rebuilt ("[operator] <size> ..."); a box that is not
## square, a view that is not the box's size or a rebuilt model is a FAIL.
## Needs a renderer:
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . -- --profile=<scratch copy> \
##       --shot=/tmp/x.png --shot-scene=results --shot-stress=1 \
##       --shot-run=res://scripts/dev/results_operator_probe.gd

const SIZES: Array[Vector2i] = [
	Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(1280, 720), Vector2i(1024, 768),
]

var _tree: SceneTree
var _failed := 0


func run(shot: Node, director: Node) -> void:
	_tree = shot.get_tree()
	var portraits := director.get_parent().find_children("*", "OperatorPreview", true, false)
	if portraits.is_empty():
		print("[operator] FAIL no operator portrait on the results screen")
		return
	var portrait := portraits[0] as OperatorPreview
	var model := portrait._model
	_popups(director)
	for s in SIZES:
		_tree.root.size = s
		await _frames(150)
		var box := portrait.get_global_rect()
		var view := portrait._viewport.size
		var drawn := box.size * portrait.get_global_transform_with_canvas().get_scale()
		var problems := PackedStringArray()
		if absf(box.size.x - box.size.y) > 1.0:
			problems.append("box not square")
		if absf(view.x / float(view.y) - box.size.x / box.size.y) > 0.02:
			problems.append("view aspect differs from the box")
		if portrait._model != model:
			problems.append("model rebuilt")
		print("[operator] %s %dx%d box=%dx%d drawn=%dx%d view=%dx%d %s" % [
			"FAIL" if not problems.is_empty() else "PASS", s.x, s.y, box.size.x, box.size.y,
			drawn.x, drawn.y, view.x, view.y, ", ".join(problems)])
		_failed += int(not problems.is_empty())
		await RenderingServer.frame_post_draw
		var file := "%s_%dx%d.png" % [String(shot.path).get_basename(), s.x, s.y]
		_tree.root.get_texture().get_image().save_png(file)
		_popups(director)
	print("[operator] DONE %d sizes, %d failed" % [SIZES.size(), _failed])


## Everything a big run can announce at its end, at once.
func _popups(director: Node) -> void:
	Progression.level_up.emit(Progression.level() + 1)
	var weapon := GameData.weapons()[0]
	Mastery.rank_up.emit(weapon, 5)
	var items: Array[CosmeticItem] = []
	items.assign(GameData.cosmetics().slice(0, 6))
	for it in items:
		Cosmetics.unlocked.emit(it)
		Mastery.reward_unlocked.emit(weapon, it)
	Progression.rewards_unlocked.emit(items)
	Cosmetics.prints_changed.emit()
	for slot in [&"avatar", &"banner", &"title", &"finish"]:
		Cosmetics.equipped_changed.emit(slot, weapon.id)
	if director.get("hud"):
		director.hud.visible = true


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame
