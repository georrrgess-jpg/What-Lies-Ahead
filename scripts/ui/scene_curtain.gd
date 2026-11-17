class_name SceneCurtain
extends CanvasLayer
## A short dim between scenes (Game.to_menu): it fades in over the old scene,
## runs the scene change under it (which holds the frame while the menu is
## built), and lifts once the new scene has drawn a few frames, so the load
## reads as a cut to black instead of a frozen screen. It blocks input while
## it is up and runs while the tree is paused (results, pause menu).

## The menu's own veil colour (MainMenu._fade), so the two blend.
const COLOR := Color(0.02, 0.0, 0.06)
const LIFT_TIME := 0.3
## Frames the new scene draws under the curtain before it lifts.
const SETTLE_FRAMES := 3

var _rect: ColorRect


## Dims the screen over `seconds`, then calls `then`. Ignored while a curtain
## is already up (a double-pressed button).
static func close(tree: SceneTree, seconds: float, then: Callable) -> void:
	if tree.root.get_children().any(func(n: Node) -> bool: return n is SceneCurtain):
		return
	var curtain := SceneCurtain.new()
	tree.root.add_child(curtain)
	curtain._run(seconds, then)


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(COLOR, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func _run(seconds: float, then: Callable) -> void:
	var dim := create_tween()
	dim.tween_property(_rect, "color:a", 1.0, seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await dim.finished
	then.call()
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	var lift := create_tween()
	lift.tween_property(_rect, "color:a", 0.0, LIFT_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	lift.tween_callback(queue_free)
