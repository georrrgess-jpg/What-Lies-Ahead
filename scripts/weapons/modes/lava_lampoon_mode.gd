class_name LavaLampoonMode
extends WeaponMode
## Lava Lampoon: a full-auto lava-lamp blaster.
##
## Warm-up groove: for the first GROOVE_TIME seconds of a string the lamp is
## still heating and the gun fires at WARM_INTERVAL; then it locks into its
## data rate (WeaponData.fire_interval) and the lamp glows brighter (`groove`,
## read by scripts/weapons/views/lava_lampoon_view.gd). Resting the trigger
## for COOL_TIME lets it cool again.
##
## Every shot is a molten glob (LavaLampoonGlob) aimed from the muzzle at the
## point under the crosshair; it hits like a ray shot (headshots, falloff) and
## splats a small lava puddle (LavaPuddle) that burns zombies walking through.
##
## Active reload: the reload (scripts/weapons/reloads/lava_lampoon_reload.gd)
## flips the lamp upside down. Pressing reload again while it is upside down
## (WINDOW_START to WINDOW_END of the reload) skips the rest of the flip: the
## lamp snaps back over in SKIP_TIME and goes straight to the twist-lock
## (LOCK_AT). One try per reload: a press before the window misses (the
## reload just plays out). The view learns of the skip through SKIP_META.

const GROOVE_TIME := 0.5
const WARM_INTERVAL := 0.13
const COOL_TIME := 0.35
## The flip window and the twist-lock, as fractions of the reload.
const WINDOW_START := 0.4
const WINDOW_END := 0.63
const LOCK_AT := 0.8
## A press this early is the one that started the reload: not a try.
const IGNORE_BEFORE := 0.1
## Seconds the lamp takes to snap back over after a skip.
const SKIP_TIME := 0.24
## View metadata: [skip progress (or -1 for a miss)] for the reload animation.
const SKIP_META := &"lava_skip"
const GROOVY_SOUND := &"weap_lava_groovy"
const MISS_SOUND := &"weap_lava_miss"
const LOCK_SOUND := &"weap_lava_lock"

## 0-1: how far into the warm-up groove the current string is.
var groove := 0.0
var _held := 0.0
var _rest := 10.0
var _since := 10.0
var _tried := false


func trigger(spinning: bool, delta: float) -> bool:
	_since += delta
	_active_reload()
	if spinning:
		_rest = 0.0
		_held += delta
	else:
		_rest += delta
		if _rest >= COOL_TIME:
			_held = 0.0
	groove = clampf(_held / GROOVE_TIME, 0.0, 1.0)
	return groove >= 1.0 or _since >= WARM_INTERVAL - 0.001


func end_trigger() -> void:
	_held = 0.0
	groove = 0.0


func launch(from: Vector3, dir: Vector3, scale: float) -> bool:
	var eye := controller.player.aim_transform().origin
	var query := PhysicsRayQueryParameters3D.create(eye, eye + dir * data.max_range, WeaponController.MASK_WORLD | WeaponController.MASK_ENEMIES)
	query.exclude = [controller.player.get_rid()]
	var hit := controller.player.get_world_3d().direct_space_state.intersect_ray(query)
	var aim_at: Vector3 = hit["position"] if not hit.is_empty() else eye + dir * data.max_range
	var to := aim_at - from
	LavaLampoonGlob.launch(controller, from, to.normalized() if to.length() > 0.5 else dir, data, scale)
	_since = 0.0
	return true


func reloaded() -> void:
	_tried = false


func dispose() -> void:
	_tried = false


## A press of reload during this weapon's reload: in the flip window it skips
## to the twist-lock, before it it misses (once per reload).
func _active_reload() -> void:
	if not controller.is_reloading() or controller.current != data:
		_tried = false
		return
	if _tried or not Input.is_action_just_pressed("reload"):
		return
	var p := controller.reload_progress()
	if p < IGNORE_BEFORE or p > WINDOW_END:
		return
	_tried = true
	var view := controller.player.view
	if p < WINDOW_START:
		view.set_meta(SKIP_META, [-1.0])
		Sfx.play(MISS_SOUND, -4.0)
		return
	var skip := (LOCK_AT - p) * data.reload_time - SKIP_TIME
	view.set_meta(SKIP_META, [p])
	controller.hurry_reload(data, skip)
	Sfx.play(GROOVY_SOUND, -2.0)
