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
## The reel is framed for 16:9: on a narrower screen the camera keeps the
## 16:9 width (more shows above and below, under the bars) so nothing framed
## to the sides is cut off.
const FRAME_ASPECT := 16.0 / 9.0

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
var _late: Array[Callable] = []
var _whips: Array = []
var _env: Environment


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


## Calls `f(t)` every frame after the camera has moved (things pinned to the
## lens: a viewmodel, a focus point, a flare).
func after_camera(f: Callable) -> void:
	_late.append(f)


## The game world runs at `scale` between `from` and `to`, easing in over
## `ramp_in` and back out over `ramp_out` seconds (a speed ramp).
func slowmo(from: float, to: float, scale: float, ramp_in := 0.12, ramp_out := 0.12) -> void:
	_slowmo.append([from, to, scale, ramp_in, ramp_out])


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
	for f in _late:
		f.call(t)
	Engine.time_scale = _time_scale()


func _time_scale() -> float:
	var scale := 1.0
	for s in _slowmo:
		var k := clampf((t - s[0]) / s[3], 0.0, 1.0) * clampf((s[1] - t) / s[4], 0.0, 1.0)
		scale = minf(scale, lerpf(1.0, s[2], k * k * (3.0 - 2.0 * k)))
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


## A camera path through keys `[time, position, look_at]` (shot seconds): a
## Catmull-Rom curve through both, so the camera's speed never jumps at a key.
## The ends hold still (zero speed) only if their keys repeat a position.
func spline(keys: Array) -> void:
	_track = func(_k: float) -> Transform3D:
		return _look(_spline_at(keys, 1, t), _spline_at(keys, 2, t))


static func _spline_at(keys: Array, field: int, time: float) -> Vector3:
	var n := keys.size()
	if time <= keys[0][0]:
		return keys[0][field]
	if time >= keys[n - 1][0]:
		return keys[n - 1][field]
	var i := 0
	while i < n - 2 and time >= keys[i + 1][0]:
		i += 1
	var t0: float = keys[i][0]
	var t1: float = keys[i + 1][0]
	var p0: Vector3 = keys[maxi(i - 1, 0)][field]
	var p1: Vector3 = keys[i][field]
	var p2: Vector3 = keys[i + 1][field]
	var p3: Vector3 = keys[mini(i + 2, n - 1)][field]
	# Tangents scaled by the neighbouring spans keep the speed continuous
	# across keys that are unevenly spaced in time.
	var span := t1 - t0
	var m1: Vector3 = (p2 - p0) / maxf(0.001, float(keys[mini(i + 1, n - 1)][0]) - float(keys[maxi(i - 1, 0)][0])) * span
	var m2: Vector3 = (p3 - p1) / maxf(0.001, float(keys[mini(i + 2, n - 1)][0]) - float(keys[i][0])) * span
	var u := (time - t0) / maxf(0.001, span)
	var u2 := u * u
	var u3 := u2 * u
	return p1 * (2.0 * u3 - 3.0 * u2 + 1.0) + m1 * (u3 - 2.0 * u2 + u) + p2 * (-2.0 * u3 + 3.0 * u2) + m2 * (u3 - u2)


## Field of view from `from` to `to` over the shot (a zoom).
func fov(from: float, to := -1.0) -> void:
	_fov = Vector2(from, to if to > 0.0 else from)


## A whip pan: the camera snaps `degrees` sideways (positive = to the right)
## with a motion smear. `into` = the shot opens at the end of the whip
## (over its first `seconds`), else the shot ends on it (its last `seconds`).
func whip(degrees := 70.0, seconds := 0.22, into := false) -> void:
	_whips.append([degrees, seconds, into])


## A camera shake of `strength` metres starting at `when`, decaying over `seconds`.
func shake(when: float, strength := 0.08, seconds := 0.35) -> void:
	_shakes.append([when, strength, seconds])


func _update_camera() -> void:
	var k := clampf(t / maxf(0.01, length), 0.0, 1.0)
	if _track.is_valid():
		camera.global_transform = _track.call(k)
	lens_fov(lerpf(_fov.x, _fov.y, ease(k, -1.6)))
	_apply_whips()
	var jolt := 0.0
	for s in _shakes:
		var age: float = t - s[0]
		if age >= 0.0 and age < s[2]:
			jolt += s[1] * (1.0 - age / s[2]) * Settings.shake_scale()
	if jolt > 0.0:
		# Slow enough (4-6 Hz) to read as a jolt at 30 fps, not as jitter.
		var b := camera.global_basis
		camera.global_position += (b.x * sin(t * 37.0) + b.y * cos(t * 29.0 + 1.3)) * jolt
		camera.rotate_object_local(Vector3.FORWARD, sin(t * 23.0) * jolt * 0.25)


## Sets the vertical field of view of the 16:9 frame; on a narrower screen the
## camera keeps that frame's width instead (see FRAME_ASPECT).
func lens_fov(vertical: float) -> void:
	var size := camera.get_viewport().get_visible_rect().size
	if size.x / maxf(1.0, size.y) < FRAME_ASPECT - 0.01:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(vertical) * 0.5) * FRAME_ASPECT))
	else:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = vertical


func _apply_whips() -> void:
	var smear := 0.0
	for w in _whips:
		var seconds: float = w[1]
		var k: float = (1.0 - clampf(t / seconds, 0.0, 1.0)) if w[2] else clampf((t - (length - seconds)) / seconds, 0.0, 1.0)
		if k <= 0.0:
			continue
		# Fastest at the cut: leaving turns toward the whip, arriving settles
		# from the other side, so the pan reads as one move across the cut.
		var turn: float = deg_to_rad(w[0]) * k * k * (1.0 if w[2] else -1.0)
		camera.rotate_object_local(Vector3.UP, turn)
		smear += k * 0.08
	if overlay:
		overlay.smear(Vector2(smear, 0.0))


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


## One shot of `weapon_id` from `from` to `to`: its real tracer style (or the
## tracer cosmetic `tracer`), the muzzle flash and its fire sound.
func shoot(weapon_id: StringName, from: Vector3, to: Vector3, power := 1.0, sound := true, tracer: StringName = &"") -> void:
	var w := GameData.weapon(weapon_id)
	var item := Cosmetics.item(tracer) if tracer != &"" else null
	if item == null or not TracerStyles.draw(actors, from, to, w.tracer_width, item):
		WeaponFx.shot(actors, from, to, w, power)
	WeaponFx.flash(actors, from, w.tracer_color, 0.35, 0.08)
	if sound:
		Sfx.play(w.fire_sound, -6.0, randf_range(0.97, 1.03))


## The set's environment, copied once per set so a shot can relight it
## without touching the level's own resource. Null on a set without one.
func environment() -> Environment:
	if _env:
		return _env
	if set_root == null:
		return null
	if set_root.has_meta(&"cine_env"):
		_env = set_root.get_meta(&"cine_env")
		return _env
	var we := set_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if we == null or we.environment == null:
		return null
	_env = we.environment.duplicate()
	we.environment = _env
	set_root.set_meta(&"cine_env", _env)
	set_root.set_meta(&"cine_env_base", we.environment.duplicate())
	return _env


## Relights the set for this shot: ambient and exposure scaled by `ambient`
## and `exposure`, glow intensity `glow` (bloom from emissive signs and bulbs),
## and the sun's energy times `sun`. Restored to the level's own at the next
## shot on the set (CinePlayer calls restore_lighting()).
func lighting(ambient := 1.0, exposure := 1.0, glow := -1.0, sun := 1.0) -> void:
	var env := environment()
	if env == null:
		return
	var base: Environment = set_root.get_meta(&"cine_env_base")
	env.ambient_light_energy = base.ambient_light_energy * ambient
	env.tonemap_exposure = base.tonemap_exposure * exposure
	if glow >= 0.0:
		env.glow_enabled = true
		env.glow_intensity = glow
	for l in set_root.find_children("*", "DirectionalLight3D", true, false):
		var d := l as DirectionalLight3D
		if not d.has_meta(&"cine_energy"):
			d.set_meta(&"cine_energy", d.light_energy)
		d.light_energy = float(d.get_meta(&"cine_energy")) * sun


## Puts the set's lighting back to the level's own (between shots).
static func restore_lighting(on_set: Node) -> void:
	if on_set == null or not on_set.has_meta(&"cine_env"):
		return
	var env: Environment = on_set.get_meta(&"cine_env")
	var base: Environment = on_set.get_meta(&"cine_env_base")
	env.ambient_light_energy = base.ambient_light_energy
	env.tonemap_exposure = base.tonemap_exposure
	env.glow_enabled = base.glow_enabled
	env.glow_intensity = base.glow_intensity
	for l in on_set.find_children("*", "DirectionalLight3D", true, false):
		if l.has_meta(&"cine_energy"):
			l.light_energy = l.get_meta(&"cine_energy")


## Where `world` falls on the screen (fractions), or (-1, -1) behind the camera.
func on_screen(world: Vector3) -> Vector2:
	if camera.is_position_behind(world):
		return Vector2(-1, -1)
	return camera.unproject_position(world) / camera.get_viewport().get_visible_rect().size


## Keeps the lens focused on `target()` (a Callable returning a world point),
## sharp within `radius` screen heights, blurring by `amount` beyond.
func focus_on(target: Callable, radius := 0.22, amount := 0.01) -> void:
	if overlay == null:
		return
	after_camera(func(_t: float):
		var p := on_screen(target.call())
		if p.x >= 0.0:
			overlay.focus(p, radius, amount))


## An anamorphic flare pinned to world point `where()` (a Callable returning
## a world point: a low sun, a lamp, a pair of eyes), rising to `strength`
## over `rise` seconds from `from_t`, fading over `fall` seconds after `until`.
func flare_at(where: Callable, color: Color, strength := 0.6, from_t := 0.0, rise := 0.0, until := INF, fall := 0.3) -> void:
	if overlay == null:
		return
	after_camera(func(now: float):
		var p := on_screen(where.call())
		var k := clampf((now - from_t) / maxf(rise, 0.001), 0.0, 1.0) * clampf(1.0 - (now - until) / fall, 0.0, 1.0)
		overlay.flare(p, color, strength * k if p.x >= -0.2 and p.x <= 1.2 else 0.0))


## A light that only lives for this shot.
func light(pos: Vector3, color: Color, energy := 2.0, radius := 8.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = radius
	l.position = pos
	actors.add_child(l)
	return l
