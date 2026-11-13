class_name CineStage
extends RefCounted
## What one shot of a cinematic gets to work with: the camera, a node for its
## actors (freed at the cut, with every effect spawned under it), timed events,
## simple movers and helpers that stage the game's real zombies, operators,
## weapons and effects. A shot's `build` callable fills the stage once, then
## CinePlayer calls update() every frame with the shot's local time.
##
## Time is the shot's real (unscaled) time, locked to the music; slow motion
## (slowmo) only slows the game world.

const ZOMBIE_SCENE := "res://scenes/enemies/zombie.tscn"

## Seconds since the shot started (unscaled).
var t := 0.0
## Length of the shot in seconds.
var length := 1.0
## Parent for everything the shot spawns; freed at the cut.
var actors: Node3D
var camera: Camera3D
var overlay: CineOverlay
## The set the shot plays on (a level scene or the studio).
var set_root: Node3D

var _events: Array = []
var _next_event := 0
var _movers: Array = []
var _track: Callable
var _fov := Vector2(50.0, 50.0)
var _shakes: Array = []
var _slowmo: Array = []
var _tickers: Array[Callable] = []


func _init(actor_root: Node3D, cam: Camera3D, ui: CineOverlay, on_set: Node3D, seconds: float) -> void:
	actors = actor_root
	camera = cam
	overlay = ui
	set_root = on_set
	length = seconds


# --- timeline -----------------------------------------------------------------

## Calls `f` once when the shot reaches `at` seconds.
func at(when: float, f: Callable) -> void:
	_events.append([when, f])
	_events.sort_custom(func(a, b): return a[0] < b[0])


## Calls `f(t)` every frame of the shot (t = the shot's local time).
func every_frame(f: Callable) -> void:
	_tickers.append(f)


## The game world runs at `scale` between `from` and `to` (eased in and out).
func slowmo(from: float, to: float, scale: float) -> void:
	_slowmo.append([from, to, scale])


## Advances the shot to local time `now`; `game_delta` is the scaled delta.
func update(now: float, game_delta: float) -> void:
	t = now
	while _next_event < _events.size() and _events[_next_event][0] <= t:
		var f: Callable = _events[_next_event][1]
		_next_event += 1
		if f.is_valid():
			f.call()
	for m in _movers:
		if is_instance_valid(m[0]) and t >= m[2] and t < m[3]:
			(m[0] as Node3D).global_position += m[1] * game_delta
	for f in _tickers:
		f.call(t)
	_update_camera()
	Engine.time_scale = _time_scale()


func _time_scale() -> float:
	var scale := 1.0
	for s in _slowmo:
		var ramp := 0.12
		var k := clampf((t - s[0]) / ramp, 0.0, 1.0) * clampf((s[1] - t) / ramp, 0.0, 1.0)
		scale = minf(scale, lerpf(1.0, s[2], k))
	return scale


# --- camera -------------------------------------------------------------------

## The camera eases from `from` (looking at `look_from`) to `to` (looking at
## `look_to`) over the shot. `ease_curve` as in ease(): 1 linear, <0 in-out.
func dolly(from: Vector3, look_from: Vector3, to: Vector3, look_to: Vector3, ease_curve := -1.6) -> void:
	_track = func(k: float) -> Transform3D:
		var e := ease(k, ease_curve)
		return _look(from.lerp(to, e), look_from.lerp(look_to, e))


## The camera circles `centre` from `deg_from` to `deg_to` (0 = +Z side).
func orbit(centre: Vector3, radius: float, height: float, deg_from: float, deg_to: float, look_offset := Vector3.ZERO, ease_curve := 1.0) -> void:
	_track = func(k: float) -> Transform3D:
		var a := deg_to_rad(lerpf(deg_from, deg_to, ease(k, ease_curve)))
		return _look(centre + Vector3(sin(a) * radius, height, cos(a) * radius), centre + look_offset)


## The camera keeps `offset` from `node` and looks at the node plus `look_offset`.
func follow(node: Node3D, offset: Vector3, look_offset := Vector3(0, 1.2, 0)) -> void:
	_track = func(_k: float) -> Transform3D:
		if not is_instance_valid(node):
			return camera.global_transform
		return _look(node.global_position + offset, node.global_position + look_offset)


## Any camera path: `f(k)` returns the transform for shot progress k (0-1).
func track(f: Callable) -> void:
	_track = f


## Field of view from `from` to `to` over the shot (a zoom).
func fov(from: float, to := -1.0) -> void:
	_fov = Vector2(from, to if to > 0.0 else from)


## A camera shake of `strength` metres starting at `when`, decaying over `seconds`.
func shake(when: float, strength := 0.08, seconds := 0.35) -> void:
	_shakes.append([when, strength, seconds])


func _update_camera() -> void:
	var k := clampf(t / maxf(0.01, length), 0.0, 1.0)
	if _track.is_valid():
		camera.global_transform = _track.call(k)
	camera.fov = lerpf(_fov.x, _fov.y, ease(k, -1.6))
	var jolt := 0.0
	for s in _shakes:
		var age: float = t - s[0]
		if age >= 0.0 and age < s[2]:
			jolt += s[1] * (1.0 - age / s[2]) * Settings.shake_scale()
	if jolt > 0.0:
		var b := camera.global_basis
		camera.global_position += (b.x * sin(t * 91.0) + b.y * cos(t * 77.0)) * jolt
		camera.rotate_object_local(Vector3.FORWARD, sin(t * 63.0) * jolt * 0.25)


func _look(from: Vector3, target: Vector3) -> Transform3D:
	if from.is_equal_approx(target):
		return Transform3D(Basis.IDENTITY, from)
	var up := Vector3.UP if absf((target - from).normalized().y) < 0.99 else Vector3.FORWARD
	return Transform3D(Basis.looking_at(target - from, up), from)


# --- actors -------------------------------------------------------------------

## Moves `node` at `velocity` (m/s of game time) between `from` and `to` seconds.
func move(node: Node3D, velocity: Vector3, from := 0.0, to := INF) -> void:
	_movers.append([node, velocity, from, to])


## A real zombie of `id`, standing at `pos` and facing `yaw` degrees
## (0 = +Z), playing `clip` (looped clips by base name: "Walk", "Idle"...).
## It has no target, so it never chases: the shot moves and animates it.
## With `emerge` it climbs in with its Emerge clip first.
func zombie(id: StringName, pos: Vector3, yaw := 0.0, clip := "Idle", rate := 1.0, emerge := false) -> Zombie:
	var data := GameData.enemy(id)
	var z := (load(ZOMBIE_SCENE) as PackedScene).instantiate() as Zombie
	z.setup(data if data else GameData.enemy(&"tourist_shambler"), null, 1.0)
	if not emerge:
		z.speed = 0.0
	z.position = pos
	z.rotation.y = deg_to_rad(yaw)
	actors.add_child(z)
	if not emerge:
		play(z, clip, rate)
	return z


## A zombie walking from `pos` along `yaw` at its walk clip's natural pace
## (times `pace`), or running with `run`.
func walker(id: StringName, pos: Vector3, yaw: float, pace := 1.0, run := false, from := 0.0) -> Zombie:
	var z := zombie(id, pos, yaw)
	var info := Zombie._clip_table(String(z.data.model_scene.resource_path) if z.data.model_scene else Zombie.MODEL_PATH)
	var clip := ("Run_Heavy" if z.data.heavy and info.has("Run_Heavy") else "Run") if run \
		else ("Walk_Heavy" if z.data.heavy and info.has("Walk_Heavy") else "Walk")
	play(z, clip, pace)
	var speed := float(info.get(clip, {}).get("speed", 2.0)) * z.data.body_scale * pace
	var dir := Vector3(sin(deg_to_rad(yaw)), 0.0, cos(deg_to_rad(yaw)))
	move(z, dir * speed, from)
	return z


## Plays `clip` on any animated actor (tries "<clip>-loop" too); `seek` < 0
## starts at a random phase so crowds never move in step.
func play(actor: Node, clip: String, rate := 1.0, seek := -1.0, blend := 0.0) -> void:
	var anim := actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null:
		return
	var name := clip if anim.has_animation(clip) else clip + "-loop"
	if not anim.has_animation(name):
		name = "Idle-loop" if anim.has_animation("Idle-loop") else "Idle"
		if not anim.has_animation(name):
			return
	anim.play(name, blend)
	anim.speed_scale = rate
	var l := anim.get_animation(name).length
	anim.seek(seek if seek >= 0.0 else randf() * l * (1.0 if anim.get_animation(name).loop_mode != Animation.LOOP_NONE else 0.0), true)


## Kills `z` with a real hit (its death clip, confetti and the head pop on a
## headshot), shot along `dir`. `effect` also plays that kill-effect cosmetic.
func kill(z: Zombie, weapon_id: StringName, headshot := false, dir := Vector3.FORWARD, push := 4.0, effect: StringName = &"") -> void:
	if not is_instance_valid(z) or z.is_dead():
		return
	z.process_mode = Node.PROCESS_MODE_INHERIT
	var at := head(z) if headshot else chest(z)
	z.take_hit(z.health + 99999.0, at, dir.normalized(), weapon_id, headshot, push)
	if effect != &"":
		KillEffects.play(actors, chest(z), Cosmetics.item(effect))


## A non-lethal hit (flinch, pop, sound).
func hit(z: Zombie, weapon_id: StringName, amount: float, at: Vector3, dir: Vector3) -> void:
	if is_instance_valid(z) and not z.is_dead():
		z.take_hit(amount, at, dir.normalized(), weapon_id, false, 1.5)


## Chest height of a zombie (or any actor) in world space.
func chest(z: Node3D) -> Vector3:
	return z.global_position + Vector3.UP * 1.1 * _height_scale(z)


## Head centre of a zombie (or any actor) in world space.
func head(z: Node3D) -> Vector3:
	return z.global_position + Vector3.UP * 1.62 * _height_scale(z)


func _height_scale(z: Node3D) -> float:
	return (z.data.body_scale if z is Zombie else 1.0) * z.global_basis.get_scale().y


## An operator (an "avatar" cosmetic id) at `pos` facing `yaw`, playing `clip`.
func operator(item_id: StringName, pos: Vector3, yaw := 0.0, clip := "Idle") -> Node3D:
	var op := Operators.instantiate(Cosmetics.item(item_id))
	op.position = pos
	op.rotation.y = deg_to_rad(yaw)
	actors.add_child(op)
	if clip != "Idle":
		Operators.play(op, clip, "")
	return op


## A weapon model of `weapon_id` wearing `finish` (and optionally `charm`),
## without first-person arms. Not added to the tree.
func weapon(weapon_id: StringName, finish: StringName = &"", charm: StringName = &"", sight: StringName = &"") -> Node3D:
	var w := GameData.weapon(weapon_id)
	var model := w.viewmodel.instantiate() as Node3D
	WeaponCosmetics.prepare_preview(model)
	WeaponCosmetics.apply(model, w, {
		"finish": Cosmetics.item(finish) if finish != &"" else null,
		"charm": Cosmetics.item(charm) if charm != &"" else null,
		"sight": Cosmetics.item(sight) if sight != &"" else null,
	})
	return model


## Re-skins a weapon model made by weapon() with another finish.
func reskin(model: Node3D, weapon_id: StringName, finish: StringName) -> void:
	WeaponCosmetics.apply(model, GameData.weapon(weapon_id), {"finish": Cosmetics.item(finish) if finish != &"" else null})


## The muzzle of a weapon model in world space (its origin if it has none).
func muzzle(model: Node3D) -> Vector3:
	var m := model.find_child("Muzzle", true, false) as Node3D
	return m.global_position if m else model.global_position


## One shot of `weapon_id` from `from` to `to`: its real tracer style, the
## muzzle flash and its fire sound.
func shoot(weapon_id: StringName, from: Vector3, to: Vector3, power := 1.0, sound := true) -> void:
	var w := GameData.weapon(weapon_id)
	WeaponFx.shot(actors, from, to, w, power)
	WeaponFx.flash(actors, from, w.tracer_color, 0.35, 0.08)
	if sound:
		Sfx.play(w.fire_sound, -6.0, randf_range(0.97, 1.03))


## A light that only lives for this shot.
func light(pos: Vector3, color: Color, energy := 2.0, radius := 8.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = radius
	l.position = pos
	actors.add_child(l)
	return l
