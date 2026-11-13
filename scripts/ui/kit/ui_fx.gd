class_name UiFx
extends RefCounted
## The kit's shared motion, so every screen moves the same way. All of it is
## tween based: nothing here runs per frame once an animation has finished.
##
##   UiFx.page_in(page, 1.0)                 # page slides in from the right
##   UiFx.stagger_in(grid.get_children())    # cards deal in one after another
##   UiFx.count_up(label, 0, 1250)           # numbers roll up
##
## Rules: page changes take PAGE seconds or less, hover and focus react in
## FAST, lists stagger by STAGGER per item (capped), and only transforms and
## alpha are animated (never layout).

## Hover, focus and press feedback.
const FAST := 0.1
## Page enter / exit.
const PAGE := 0.24
## Delay between items of a staggered list.
const STAGGER := 0.03
## A staggered list never takes longer than this to start its last item.
const STAGGER_MAX := 0.3
## How far pages slide.
const SLIDE := 70.0
const HOVER_SCALE := 1.04


## Slides and fades `page` in. `direction` 1 enters from the right, -1 from the left.
static func page_in(page: Control, direction := 1.0, delay := 0.06) -> Tween:
	page.visible = true
	page.modulate.a = 0.0
	page.position.x = SLIDE * direction
	var tw := page.create_tween().set_parallel(true)
	tw.tween_property(page, "modulate:a", 1.0, PAGE - delay).set_delay(delay)
	tw.tween_property(page, "position:x", 0.0, PAGE - delay).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tw


## Slides and fades `page` out, then hides it and restores its position.
static func page_out(page: Control, direction := 1.0) -> Tween:
	var tw := page.create_tween().set_parallel(true)
	tw.tween_property(page, "modulate:a", 0.0, PAGE * 0.6)
	tw.tween_property(page, "position:x", -SLIDE * direction, PAGE * 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		page.visible = false
		page.position.x = 0.0
		page.modulate.a = 1.0)
	return tw


## Deals `items` (Controls) in one after another: each pops from slightly small
## and fades in. Safe inside containers (only scale and alpha are animated).
static func stagger_in(items: Array, delay := 0.0, step := STAGGER) -> void:
	var count := items.size()
	if count == 0:
		return
	step = minf(step, STAGGER_MAX / count)
	for i in count:
		var c := items[i] as Control
		if c == null:
			continue
		pop_in(c, delay + i * step)


## One control pops in (see stagger_in).
static func pop_in(c: Control, delay := 0.0, from_scale := 0.86) -> Tween:
	c.pivot_offset = c.size * 0.5
	c.modulate.a = 0.0
	var tw := c.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(func():
		c.pivot_offset = c.size * 0.5
		c.scale = Vector2(from_scale, from_scale))
	tw.set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.12)
	tw.tween_property(c, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


## Fades `c` in from transparent.
static func fade_in(c: CanvasItem, seconds := 0.2, delay := 0.0) -> Tween:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, seconds).set_delay(delay)
	return tw


## Grows `c` a little while hovered or focused (and back).
static func hover(c: Control, on: bool, amount := HOVER_SCALE) -> void:
	c.pivot_offset = c.size * 0.5
	var k := amount if on else 1.0
	c.create_tween().tween_property(c, "scale", Vector2(k, k), FAST).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Button press: a quick squash that springs back to `rest` scale.
static func squash(c: Control, rest := 1.0) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(1.05, 0.9) * rest, 0.05)
	tw.tween_property(c, "scale", Vector2(rest, rest), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A single attention pulse (a value changed, a reward landed).
static func pulse(c: Control, amount := 1.18) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(amount, amount), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Side-to-side shake: the action was refused (locked, cannot afford).
static func deny(c: Control) -> void:
	var home := c.position.x
	var tw := c.create_tween()
	for dx in [-9.0, 8.0, -6.0, 4.0, 0.0]:
		tw.tween_property(c, "position:x", home + dx, 0.04)
	UiSound.deny()


## Rolls the number in `label` from `from` to `to`. `format` (optional) turns
## the integer into text; the default adds thousands separators.
static func count_up(label: Label, from: int, to: int, seconds := 0.5, format := Callable()) -> Tween:
	var tw := label.create_tween()
	var show := func(v: float):
		var n := int(round(v))
		label.text = format.call(n) if format.is_valid() else Wallet.format(n)
	if from == to:
		show.call(float(to))
		return tw
	tw.tween_method(show, float(from), float(to), seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tw


## Animates a ProgressBar (or Range) to `value`.
static func fill_to(bar: Range, value: float, seconds := 0.35, delay := 0.0) -> Tween:
	var tw := bar.create_tween()
	tw.tween_property(bar, "value", value, seconds).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tw
