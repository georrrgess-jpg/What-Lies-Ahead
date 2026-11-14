extends RefCounted
## Headless layout check: at several window sizes, reports any two visible
## buttons whose rectangles overlap and any visible control that sticks out
## of the window (or out of the box that lays it out). Run it through the
## screenshot launcher (scripts/dev/screenshot.gd):
##
##   # every menu page (and the tabs of the Locker, Prizes, Career and Shop):
##   godot --headless --path . -- --profile=<copy> --shot=/tmp/x.png --shot-scene=menu \
##       --shot-run=res://scripts/dev/ui_layout_probe.gd
##   # an in-level screen: results, defeat, pause or kiosk (the station panel);
##   # --shot-stress=1 fills the results with every section:
##   godot --headless --path . -- --profile=<copy> --shot=/tmp/x.png --shot-scene=results \
##       --shot-stress=1 --shot-run=res://scripts/dev/ui_layout_probe.gd
##
## Prints "[layout] FAIL <where> <size>: ..." per problem and a summary line
## "[layout] DONE <screens> screens, <n> problems".

## Window sizes in pixels (the canvas follows with canvas_items / expand).
const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2000, 1092),
	Vector2i(1920, 1200), Vector2i(1366, 768), Vector2i(2560, 1080), Vector2i(1024, 768),
]
## Pixels a rectangle may stick out before it counts (outlines, rounding).
const SLACK := 2.0
## Seconds to let page transitions, staggers and count-ups settle.
const SETTLE := 0.6

var _tree: SceneTree
var _problems := 0
var _screens := 0
var _seen := {}


func run(shot: Node, context: Node) -> void:
	_tree = shot.get_tree()
	if context.has_method("page"):
		await _menu(context)
	else:
		await _check_all_sizes(String(shot.args.get("scene", "level")))
	print("[layout] DONE %d screens, %d problems" % [_screens, _problems])


# --- what to walk ------------------------------------------------------------------

func _menu(menu: Node) -> void:
	var ids: Array = ["title"] + menu._home.known_pages.filter(func(id): return id != "title")
	for id in ids:
		menu._show(id, false)
		await _settle()
		await _check_all_sizes(id)
		var page: Node = menu.page(id)
		for tabs in _tab_rows(page):
			for tab_id in tabs.ids().duplicate():
				if not tabs.is_visible_in_tree():
					break
				tabs.select(tab_id, true)
				await _settle()
				await _check_all_sizes("%s/%s" % [id, tab_id])


## The tab rows a page shows (KitTabs that are in the tree and visible).
func _tab_rows(page: Node) -> Array[KitTabs]:
	var out: Array[KitTabs] = []
	if page == null:
		return out
	for node in page.find_children("*", "KitTabs", true, false):
		var tabs := node as KitTabs
		if tabs.is_visible_in_tree() and tabs.ids().size() > 1:
			out.append(tabs)
	return out


func _settle() -> void:
	await _tree.create_timer(SETTLE, true, false, true).timeout


func _check_all_sizes(where: String) -> void:
	var start := _tree.root.size
	for s in SIZES:
		_tree.root.size = s
		for i in 4:
			await _tree.process_frame
		_check(where, s)
	_tree.root.size = start
	await _tree.process_frame


# --- the checks ---------------------------------------------------------------------

func _check(where: String, window: Vector2i) -> void:
	_screens += 1
	var view := _tree.root.get_visible_rect()
	var buttons: Array = []
	for c in _visible_controls(_tree.root):
		var rect := _rect(c)
		var clip := _clip_rect(c, view)
		if not clip.intersects(rect):
			continue
		if c is BaseButton and rect.get_area() > 1.0:
			buttons.append([c, rect.intersection(clip)])
		if _covers(rect, view):
			continue
		if not view.grow(SLACK).encloses(rect) and clip == view:
			_fail(where, window, "%s is outside the window (%s in %s)" % [_name(c), _r(rect), _r(view)])
		var scroll := c as ScrollContainer
		if scroll and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and scroll.get_child_count() > 0:
			var content := scroll.get_child(0) as Control
			if content and content.size.x > scroll.size.x + SLACK:
				_fail(where, window, "%s is wider than its scroll box %s (%d > %d)" % [_name(content), _name(scroll), content.size.x, scroll.size.x])
		var parent := c.get_parent() as Container
		if parent and not (parent is ScrollContainer) and parent.is_visible_in_tree() and not _rect(parent).grow(SLACK).encloses(rect):
			_fail(where, window, "%s sticks out of %s (%s in %s)" % [_name(c), _name(parent), _r(rect), _r(_rect(parent))])
	for i in buttons.size():
		for j in range(i + 1, buttons.size()):
			var a: Control = buttons[i][0]
			var b: Control = buttons[j][0]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			var overlap: Rect2 = (buttons[i][1] as Rect2).intersection(buttons[j][1])
			if overlap.size.x > SLACK and overlap.size.y > SLACK:
				_fail(where, window, "buttons overlap: %s and %s (%s)" % [_name(a), _name(b), _r(overlap)])


## Each problem once per screen (the same one at several sizes is listed once
## with the first size it shows at).
func _fail(where: String, window: Vector2i, what: String) -> void:
	var key := where + what.get_slice(" (", 0)
	if _seen.has(key):
		return
	_seen[key] = true
	_problems += 1
	print("[layout] FAIL %s %dx%d: %s" % [where, window.x, window.y, what])


## Controls drawn now: visible in the tree, not faded out, not zero-sized.
## Full-screen layers (dims, backdrops) are walked but not reported.
func _visible_controls(node: Node) -> Array[Control]:
	var out: Array[Control] = []
	for child in node.get_children():
		if child is CanvasLayer and not (child as CanvasLayer).visible:
			continue
		var c := child as Control
		if c:
			if not c.visible or c.modulate.a < 0.05 or c.self_modulate.a < 0.0:
				continue
			if c.size.x >= 1.0 and c.size.y >= 1.0:
				out.append(c)
		out.append_array(_visible_controls(child))
	return out


func _rect(c: Control) -> Rect2:
	return c.get_global_transform() * Rect2(Vector2.ZERO, c.size)


## Where `c` can be seen: the window cut by every ancestor that clips.
func _clip_rect(c: Control, view: Rect2) -> Rect2:
	var clip := view
	var p := c.get_parent()
	while p:
		var pc := p as Control
		if pc and (pc.clip_contents or pc is ScrollContainer):
			clip = clip.intersection(_rect(pc))
		p = p.get_parent()
	return clip


func _covers(rect: Rect2, view: Rect2) -> bool:
	return rect.grow(SLACK).encloses(view)


func _name(c: Node) -> String:
	var text = c.get("text")
	var label := " \"%s\"" % String(text).left(24) if text is String and text != "" else ""
	return "%s%s [%s]" % [c.get_class(), label, c.name]


func _r(r: Rect2) -> String:
	return "%d,%d %dx%d" % [r.position.x, r.position.y, r.size.x, r.size.y]
