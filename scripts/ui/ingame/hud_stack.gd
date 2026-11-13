class_name HudStack
extends VBoxContainer
## The HUD's one stack for everything transient that is not a banner: run
## notices ("Energy topped up", "Overshield down"), unlock toasts, challenge
## cards. Entries slide in from the right edge, newest at the bottom, and
## leave by themselves. At most CAP are shown: when a new one needs room the
## oldest entry of the lowest priority goes, and a new entry that is less
## important than everything on screen is skipped.
##
##   stack.push("Energy topped up", HudStack.Priority.GOOD, &"bolt")
##   stack.push_card(my_card, HudStack.Priority.REWARD, 4.5)

enum Priority { INFO, GOOD, REWARD, BAD }

const CAP := 3
const COLORS := {
	Priority.INFO: UiKit.CYAN,
	Priority.GOOD: UiKit.GREEN,
	Priority.REWARD: UiKit.AMBER,
	Priority.BAD: UiKit.RED,
}
const SECONDS := {Priority.INFO: 2.6, Priority.GOOD: 2.6, Priority.REWARD: 4.5, Priority.BAD: 3.2}
const SLIDE := 70.0

## Live entries, oldest first: { slot, body, priority, key, tween }.
var _entries: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 8)


## Shows a one-line notice. The same text again only refreshes the entry
## that is already there.
func push(text: String, priority := Priority.INFO, icon: StringName = &"") -> void:
	if text == "":
		return
	for entry in _entries:
		if entry["key"] == text:
			_hold(entry, SECONDS[priority])
			UiFx.pulse(entry["body"], 1.06)
			return
	var accent: Color = COLORS[priority]
	var pill := PanelContainer.new()
	var box := UiKit.box(Color(UiKit.INK, 0.8), accent, 14, 0, 0)
	box.border_width_left = 6
	box.content_margin_left = 18
	box.content_margin_right = 20
	box.content_margin_top = 6
	box.content_margin_bottom = 8
	pill.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	pill.add_child(row)
	if icon != &"":
		row.add_child(HudIcon.make(icon, 28.0, accent))
	var label := UiKit.label(text, 26, UiKit.CREAM)
	label.add_theme_constant_override("shadow_offset_y", 2)
	row.add_child(label)
	_add(pill, priority, text, SECONDS[priority])


## Shows any Control as an entry (an unlock toast, a challenge card).
func push_card(card: Control, priority := Priority.REWARD, seconds := 4.5) -> void:
	_add(card, priority, "", seconds)


## Removes everything at once.
func clear() -> void:
	for entry in _entries:
		(entry["slot"] as Control).queue_free()
	_entries.clear()


func _add(body: Control, priority: Priority, key: String, seconds: float) -> void:
	if not _make_room(priority):
		body.queue_free()
		return
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_child(slot)
	_ignore_mouse(body)
	slot.add_child(body)
	var need := body.get_combined_minimum_size()
	slot.custom_minimum_size = need
	body.size = need
	body.position = Vector2(SLIDE, 0.0)
	body.modulate.a = 0.0
	var entry := {"slot": slot, "body": body, "priority": priority, "key": key, "tween": null}
	_entries.append(entry)
	_hold(entry, seconds, true)


## Frees a place for an entry of `priority`. False if the stack is full of
## more important things.
func _make_room(priority: Priority) -> bool:
	if _entries.size() < CAP:
		return true
	var victim := -1
	for i in _entries.size():
		var p: int = _entries[i]["priority"]
		if p <= priority and (victim < 0 or p < int(_entries[victim]["priority"])):
			victim = i
	if victim < 0:
		return false
	_remove(_entries[victim])
	return true


## (Re)starts an entry's life: slide in if `enter`, stay `seconds`, slide out.
func _hold(entry: Dictionary, seconds: float, enter := false) -> void:
	var old: Tween = entry["tween"]
	if old and old.is_valid():
		old.kill()
	var body: Control = entry["body"]
	var tw := body.create_tween()
	entry["tween"] = tw
	if enter:
		tw.set_parallel(true)
		tw.tween_property(body, "position:x", 0.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(body, "modulate:a", 1.0, 0.14)
		tw.set_parallel(false)
	else:
		body.position.x = 0.0
		body.modulate.a = 1.0
	tw.tween_interval(seconds)
	tw.tween_property(body, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(body, "position:x", SLIDE * 0.6, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(_remove.bind(entry))


func _remove(entry: Dictionary) -> void:
	var old: Tween = entry["tween"]
	if old and old.is_valid():
		old.kill()
	_entries.erase(entry)
	(entry["slot"] as Control).queue_free()


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
