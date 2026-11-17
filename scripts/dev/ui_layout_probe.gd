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
##   # the in-run HUD with every widget up (Endless: --shot-level=endless_city), at the
##   # station (kiosk), paused there (pause) or away from it (level):
##   godot --headless --path . -- --profile=<copy> --shot=/tmp/x.png --shot-scene=kiosk \
##       --shot-level=endless_city --shot-stress=1 --shot-run=res://scripts/dev/ui_layout_probe.gd
##
## Blocks marked with the meta `hud_block` (the HUD's corner columns, chips,
## station board, world-marker labels, the pause menu's content) must not
## overlap one another, whatever layer they are drawn in.
##
## Prints "[layout] FAIL <where> <size>: ..." per problem and a summary line
## "[layout] DONE <screens> screens, <n> problems".
##
## Overlays drawn above the page (a raised z_index, such as the coach marks'
## callout, which goes away by itself) are not counted as overlapping the
## buttons under them; controls faded out (alpha under 5%, counting their
## parents) are not checked, nor a control marked with the meta
## `layout_overhang` (its rect is wider than what its shader draws).

## Window sizes in pixels (the canvas follows with canvas_items / expand).
const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2000, 1092),
	Vector2i(1920, 1200), Vector2i(1366, 768), Vector2i(2560, 1080), Vector2i(1024, 768),
	Vector2i(1280, 1024),
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
		# The page's frame: its content and the header row the shell draws for it.
		var page: Node = menu.page(id)
		await _walk_tabs(page.get_parent() if page else null, id, {})


## Every tab of every tab row on the page, and the rows those tabs reveal
## (the Locker's groups show their own category rows).
func _walk_tabs(page: Node, where: String, visited: Dictionary) -> void:
	for tabs in _tab_rows(page):
		if visited.has(tabs):
			continue
		visited[tabs] = true
		for tab_id in tabs.ids().duplicate():
			if not tabs.is_visible_in_tree():
				break
			tabs.select(tab_id, true)
			await _settle()
			print("[layout] screen %s/%s" % [where, tab_id])
			await _check_all_sizes("%s/%s" % [where, tab_id])
			await _walk_tabs(page, "%s/%s" % [where, tab_id], visited)


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
		await _tree.create_timer(0.15, true, false, true).timeout
		_check(where, s)
	_tree.root.size = start
	await _tree.process_frame


# --- the checks ---------------------------------------------------------------------

func _check(where: String, window: Vector2i) -> void:
	_screens += 1
	var view := _tree.root.get_visible_rect()
	var buttons: Array = []
	var blocks: Array[Control] = []
	for c in _visible_controls(_tree.root):
		var rect := _rect(c)
		var clip := _clip_rect(c, view)
		if not clip.intersects(rect):
			continue
		if c.has_meta(&"hud_block"):
			blocks.append(c)
		if c is BaseButton and rect.get_area() > 1.0:
			buttons.append([c, rect.intersection(clip), _layer(c)])
		_check_slices(where, window, c)
		if _covers(rect, view) or c.has_meta(&"layout_overhang"):
			continue
		if not view.grow(SLACK).encloses(rect) and clip == view:
			_fail(where, window, "%s is outside the window (%s in %s)" % [_name(c), _r(rect), _r(view)])
		var scroll := c as ScrollContainer
		if scroll and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and scroll.get_child_count() > 0:
			var content := scroll.get_child(0) as Control
			if content and content.size.x > scroll.size.x + SLACK:
				_fail(where, window, "%s is wider than its scroll box %s (%d > %d)" % [_name(content), _name(scroll), content.size.x, scroll.size.x])
		var parent := c.get_parent() as Container
		# Laid-out rectangles: a control's own scale and nudge (hover, pulse) are motion, not layout.
		var laid := Rect2(c.position, c.size)
		if parent and not (parent is ScrollContainer) and parent.is_visible_in_tree() and not Rect2(Vector2.ZERO, parent.size).grow(SLACK).encloses(laid):
			_fail(where, window, "%s sticks out of %s (%s in %s)" % [_name(c), _name(parent), _r(laid), _r(Rect2(Vector2.ZERO, parent.size))])
	for i in buttons.size():
		for j in range(i + 1, buttons.size()):
			var a: Control = buttons[i][0]
			var b: Control = buttons[j][0]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a) or buttons[i][2] != buttons[j][2]:
				continue
			var overlap: Rect2 = (buttons[i][1] as Rect2).intersection(buttons[j][1])
			if overlap.size.x > SLACK and overlap.size.y > SLACK:
				_fail(where, window, "buttons overlap: %s and %s (%s)" % [_name(a), _name(b), _r(overlap)])
	_check_blocks(where, window, blocks)


## A 9-slice frame (StyleBoxTexture) drawn too small: a button's frame below
## KitTex.min_frame_size (its middle rows squeeze into a band), any frame below its own
## fixed borders (the corners squash and the middle row smears out past them as
## a thin line: the Locker's PRIMARIES/SECONDARIES and tab buttons).
func _check_slices(where: String, window: Vector2i, c: Control) -> void:
	var names: Array = []
	if c is Button and (c as Button).flat:
		return
	if c is BaseButton:
		names = ["normal", "hover", "pressed", "hover_pressed"]
	elif c is PanelContainer or c is Panel:
		names = ["panel"]
	for n in names:
		var sb := c.get_theme_stylebox(n) as StyleBoxTexture
		if sb == null or sb.texture == null:
			continue
		var h := c.size.y + sb.expand_margin_top + sb.expand_margin_bottom
		var w := c.size.x + sb.expand_margin_left + sb.expand_margin_right
		var need_h := sb.texture_margin_top + sb.texture_margin_bottom
		var need_w := sb.texture_margin_left + sb.texture_margin_right
		if c is BaseButton:
			var need := KitTex.min_frame_size(sb)
			need_w = need.x
			need_h = need.y
		if h + 0.5 < need_h or w + 0.5 < need_w:
			_fail(where, window, "%s frame '%s' squashed: drawn %dx%d, its texture needs %dx%d (%s in %s)" % [_name(c), n, w, h, need_w, need_h, _script_of(c), _script_of(c.get_parent())])
			return


func _script_of(n: Node) -> String:
	var sc: Script = n.get_script() if n else null
	return sc.resource_path.get_file() if sc else (n.get_class() if n else "-")


## Any two HUD blocks drawing over each other (neither inside the other).
func _check_blocks(where: String, window: Vector2i, blocks: Array[Control]) -> void:
	for i in blocks.size():
		for j in range(i + 1, blocks.size()):
			var a := blocks[i]
			var b := blocks[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			var overlap := _rect(a).intersection(_rect(b))
			if overlap.size.x > SLACK and overlap.size.y > SLACK:
				_fail(where, window, "HUD blocks overlap: %s and %s (%s)" % [_name(a), _name(b), _r(overlap)])


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
			if not c.visible or c.modulate.a < 0.05:
				continue
			if c.size.x >= 1.0 and c.size.y >= 1.0 and _alpha(c) >= 0.05:
				out.append(c)
		out.append_array(_visible_controls(child))
	return out


## The alpha `c` is drawn with (its own modulate times its parents').
func _alpha(c: Node) -> float:
	var a := 1.0
	while c:
		var item := c as CanvasItem
		if item:
			a *= item.modulate.a
		c = c.get_parent()
	return a


## The overlay a control is drawn in: the CanvasLayer and the nearest raised z_index.
func _layer(c: Node) -> String:
	var z := 0
	var n := c
	while n and not (n is CanvasLayer) and n != _tree.root:
		var item := n as CanvasItem
		if item and item.z_index > 0 and z == 0:
			z = item.z_index
		n = n.get_parent()
	return "%s:%d" % [n.get_instance_id() if n else 0, z]


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
