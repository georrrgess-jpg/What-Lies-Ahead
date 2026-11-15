class_name HubcapShot
extends Node3D
## A thrown hubcap (the Road Rager, scripts/weapons/modes/hubcap_boomerang_mode.gd).
## It is physical and visible the whole way, with travel time on both legs:
##
##   out    flies where it was aimed at projectile_speed, slowing towards the
##          apex at max_range like a boomerang; from the hip it drifts right
##          as it goes (DRIFT), aimed down the sights it flies dead straight
##   hang   spins in place for a moment at the apex
##   back   swings home to the gun: from the hip in a wide loop out to the
##          right (SWING), aimed down the sights straight back down the line
##
## It slices through every zombie it passes, once on the way out and once on
## the way back (each strike is a full hit; headshots count where the disc
## passes the head). A wall on the way out turns it for home early; on the
## way back it skids along walls. Hits go through WeaponController.ring_hit.
##
## The catch is the ammo: a hubcap that comes home goes straight back in the
## magazine (WeaponController.catch_round), and mid-reload it also takes
## CATCH_RELOAD_CUT seconds off the reload, so a player who keeps catching
## never runs dry. Only a hubcap that cannot get home within BACK_GIVE_UP is
## lost. A "pile-up" (PILEUP strikes in one throw) turns the hubcap gold and
## its strikes for the rest of the flight deal PILEUP_BONUS times damage.

const MASK_WORLD := 1
## Disc reach (m) beyond a zombie's capsule at which it strikes.
const REACH := 0.3
## The out leg slows to (1 - OUT_SLOWDOWN) of its speed at the apex.
const OUT_SLOWDOWN := 0.6
const HANG_TIME := 0.12
## Hip throws: the out leg drifts DRIFT m right by the apex, and the return
## starts out SWING (share of its speed) sideways, so it loops back wide.
const DRIFT := 1.2
const SWING := 0.85
## Back leg: starts at BACK_START and reaches BACK_TOP times the throw speed.
const BACK_START := 0.45
const BACK_TOP := 1.35
const BACK_ACCEL_TIME := 0.5
## Homing rate (1/s) over the back leg: gentle at first so the loop opens up.
const STEER_START := 2.2
const STEER_END := 14.0
## After this long on the way back it ghosts through scenery; after
## BACK_GIVE_UP it drops, lost.
const BACK_SOLID_TIME := 1.6
const BACK_GIVE_UP := 3.0
const CATCH_DISTANCE := 0.9
## Strikes in one throw for a pile-up, and the damage of strikes after it.
const PILEUP := 4
const PILEUP_BONUS := 1.5
const CATCH_RELOAD_CUT := 0.6
const TRAIL := 16
## Near the camera the hubcap is drawn smaller and without its trail.
const NEAR_EYE := 2.4
const SPIN_RATE := 34.0
const SPIN_SOUND := &"hub_spin_loop"
const PILEUP_COLOR := Color(1.0, 0.8, 0.28)
const SPARKS := [Color(1.0, 0.62, 0.2), Color(1.0, 0.95, 0.75), Color(1.0, 0.35, 0.12)]
const CAP_SCENE := "res://art/models/hubcap_boomerang_cap.glb"

enum Phase { OUT, HANG, BACK }

var weapon: WeaponData
var controller: WeaponController
var phase := Phase.OUT
var velocity := Vector3.ZERO
## 0 = a hip throw (curving), 1 = aimed down the sights (straight).
var straight := 0.0
var strikes := 0
var _origin := Vector3.ZERO
var _dir := Vector3.FORWARD
var _side := Vector3.RIGHT
var _speed := 1.0
var _range := 1.0
var _s := 0.0
var _phase_time := 0.0
var _struck := {}
var _spin := 0.0
var _cap: Node3D
var _glow: MeshInstance3D
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _history := PackedVector3Array()
var _hum: AudioStreamPlayer3D
var _exclude: Array[RID] = []

static var _cap_scene: PackedScene
static var _glow_mesh: TorusMesh
static var _mats := {}


## Throws a hubcap from `from` along `dir` under `parent`; `aimed` is the
## player's ADS blend (1 = a straight throw).
static func launch(parent: Node, from: Vector3, dir: Vector3, w: WeaponData, owner_controller: WeaponController, aimed: float) -> HubcapShot:
	var h := HubcapShot.new()
	h.weapon = w
	h.controller = owner_controller
	h.straight = clampf(aimed, 0.0, 1.0)
	h._dir = dir.normalized()
	parent.add_child(h)
	h.global_position = from
	h._origin = from
	return h


func _ready() -> void:
	_speed = maxf(1.0, weapon.projectile_speed)
	_range = maxf(2.0, weapon.max_range)
	var side := _dir.cross(Vector3.UP)
	_side = side.normalized() if side.length() > 0.05 else Vector3.RIGHT
	velocity = _dir * _speed
	_exclude.append(controller.player.get_rid())
	if _cap_scene == null and ResourceLoader.exists(CAP_SCENE):
		_cap_scene = load(CAP_SCENE)
	_cap = _cap_scene.instantiate() if _cap_scene else Node3D.new()
	add_child(_cap)
	_disable_shadows(_cap)
	if _glow_mesh == null:
		_glow_mesh = TorusMesh.new()
		_glow_mesh.inner_radius = 0.8
		_glow_mesh.outer_radius = 1.0
		_glow_mesh.rings = 24
		_glow_mesh.ring_segments = 6
	_glow = MeshInstance3D.new()
	_glow.mesh = _glow_mesh
	_glow.material_override = _glow_material(weapon.tracer_color)
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cap.add_child(_glow)
	_glow.scale = Vector3(1.0, 1.4, 1.0) * weapon.projectile_size * 1.15
	_trail_mesh = ImmediateMesh.new()
	_trail = MeshInstance3D.new()
	_trail.mesh = _trail_mesh
	_trail.top_level = true
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)
	_trail.global_transform = Transform3D.IDENTITY
	_start_hum()


## The additive rim glow round the disc, one per colour.
static func _glow_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(color.lerp(Color.WHITE, 0.15), 0.55)
		_mats[key] = m
	return _mats[key]


func _start_hum() -> void:
	var s := Sfx.stream(SPIN_SOUND)
	if s == null:
		return
	if s is AudioStreamWAV and s.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = int(s.get_length() * s.mix_rate)
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = s
	_hum.bus = &"SFX"
	_hum.unit_size = 6.0
	_hum.volume_db = -6.0 + Sfx.mix_db(SPIN_SOUND)
	_hum.pitch_scale = randf_range(0.96, 1.04)
	add_child(_hum)
	_hum.play()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller) or not is_instance_valid(controller.player):
		queue_free()
		return
	_phase_time += delta
	match phase:
		Phase.OUT:
			_fly_out(delta)
		Phase.HANG:
			if _phase_time >= HANG_TIME:
				_turn_back()
		Phase.BACK:
			_fly_back(delta)


func _process(delta: float) -> void:
	_spin += delta * SPIN_RATE
	# Flies nearly flat, banked into its curve, spinning on its axle.
	var dir := velocity.normalized() if velocity.length() > 0.1 else _dir
	var side := dir.cross(Vector3.UP)
	var bank := 0.35 if phase != Phase.BACK else -0.5 * (1.0 - straight) + 0.2
	var up := Vector3.UP.rotated(side.normalized(), bank) if side.length() > 0.01 else Vector3.UP
	var cam := get_viewport().get_camera_3d()
	var near := clampf(cam.global_position.distance_to(global_position) / NEAR_EYE, 0.3, 1.0) if cam else 1.0
	_cap.global_basis = Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, _spin)
	_cap.scale = Vector3.ONE * near
	_draw_trail(cam, near < 1.0)
	if _hum:
		_hum.pitch_scale = lerpf(0.85, 1.2, clampf(velocity.length() / (_speed * BACK_TOP), 0.0, 1.0))


# --- flight -------------------------------------------------------------------

func _fly_out(delta: float) -> void:
	var k := _s / _range
	_s = minf(_range, _s + _speed * (1.0 - OUT_SLOWDOWN * k * k) * delta)
	var k2 := _s / _range
	var to := _origin + _dir * _s + _side * DRIFT * (1.0 - straight) * k2 * k2
	var from := global_position
	var hit := _ray(from, to)
	if not hit.is_empty():
		_strike_along(from, hit["position"])
		_glance(hit)
		_turn_back()
		return
	_strike_along(from, to)
	velocity = (to - from) / maxf(delta, 0.0001)
	global_position = to
	if _s >= _range:
		phase = Phase.HANG
		_phase_time = 0.0


func _turn_back() -> void:
	phase = Phase.BACK
	_phase_time = 0.0
	_struck.clear()
	var home := _home() - global_position
	home.y *= 0.5
	var back := home.normalized() if home.length() > 0.1 else -_dir
	var swing := _side * SWING * (1.0 - straight)
	velocity = (back + swing).normalized() * _speed * BACK_START


func _fly_back(delta: float) -> void:
	var home := _home()
	var to_home := home - global_position
	var dist := to_home.length()
	if dist <= CATCH_DISTANCE:
		_caught()
		return
	if _phase_time > BACK_GIVE_UP:
		_lost()
		return
	var k := clampf(_phase_time / BACK_ACCEL_TIME, 0.0, 1.0)
	var speed := _speed * lerpf(BACK_START, BACK_TOP, k)
	var steer := lerpf(STEER_START, STEER_END, clampf(_phase_time / BACK_SOLID_TIME, 0.0, 1.0))
	var want := to_home / dist * speed
	velocity = velocity.lerp(want, minf(1.0, steer * delta)).normalized() * speed
	var from := global_position
	var to := from + velocity * delta
	if velocity.length() * delta >= dist:
		to = home
	if _phase_time < BACK_SOLID_TIME:
		var hit := _ray(from, to)
		if not hit.is_empty():
			var n: Vector3 = hit["normal"]
			_strike_along(from, hit["position"])
			# Skids along the wall and carries on home.
			velocity = velocity.slide(n) + n * speed * 0.25
			global_position = hit["position"] + n * 0.12
			_scrape(hit)
			return
	_strike_along(from, to)
	global_position = to


## Where the hubcap is caught: the gun's muzzle.
func _home() -> Vector3:
	return controller.player.view.muzzle_position()


# --- strikes ------------------------------------------------------------------

## Strikes every zombie the segment `from` - `to` passes (once per leg).
func _strike_along(from: Vector3, to: Vector3) -> void:
	var seg := to - from
	var flat := Vector2(seg.x, seg.z)
	var len_sq := flat.length_squared()
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead() or _struck.has(z.get_instance_id()):
			continue
		var base := z.global_position
		var s := z.data.body_scale
		var rel := Vector2(base.x - from.x, base.z - from.z)
		var t := clampf(rel.dot(flat) / len_sq, 0.0, 1.0) if len_sq > 0.0001 else 0.0
		var at := from + seg * t
		if at.y < base.y - 0.1 or at.y > base.y + 1.95 * s:
			continue
		if Vector2(at.x - base.x, at.z - base.z).length() <= REACH + z.data.capsule_radius * s:
			_strike(z, at, seg.normalized() if seg.length() > 0.001 else velocity.normalized())


func _strike(z: Zombie, point: Vector3, dir: Vector3) -> void:
	_struck[z.get_instance_id()] = true
	var head := z.is_head_hit(point, point - dir * 0.6)
	var dmg := weapon.damage * (weapon.headshot_multiplier if head else 1.0) * (PILEUP_BONUS if strikes >= PILEUP else 1.0)
	strikes += 1
	var level := get_parent()
	WeaponFx.burst(level, point, -dir, SPARKS, 8 if not head else 12, 4.5, 0.28, 0.035, 80.0)
	Sfx.play_at(weapon.ricochet_sound, point, -2.0, 1.0 + 0.06 * mini(strikes, 8))
	controller.ring_hit(weapon, z, point, dir, dmg, head)
	if strikes == PILEUP:
		_glow.material_override = _glow_material(PILEUP_COLOR)
		WeaponFx.flash(level, point, PILEUP_COLOR, 0.8, 0.2)
		Sfx.play_at(&"hub_pileup", point, -1.0)


## Off a wall on the way out: sparks, a clang, and the hubcap turns for home.
func _glance(hit: Dictionary) -> void:
	var n: Vector3 = hit["normal"]
	var at: Vector3 = hit["position"]
	WeaponFx.burst(get_parent(), at, n, SPARKS, 10, 4.0, 0.3, 0.04)
	ImpactMarks.scuff(get_parent(), hit, _dir, weapon)
	Sfx.play_at(weapon.bounce_sound, at, -2.0, randf_range(0.95, 1.08))
	global_position = at + n * 0.12


func _scrape(hit: Dictionary) -> void:
	WeaponFx.burst(get_parent(), hit["position"], hit["normal"], SPARKS, 6, 3.0, 0.22, 0.03)
	Sfx.play_at(weapon.bounce_sound, hit["position"], -6.0, randf_range(1.1, 1.25))


func _caught() -> void:
	var pileup := strikes >= PILEUP
	controller.hurry_reload(weapon, CATCH_RELOAD_CUT)
	controller.catch_round(weapon)
	Sfx.play(weapon.catch_sound, -3.0 if pileup else -5.0, 1.1 if pileup else 1.0)
	controller.player.view.weapon_event(weapon, &"catch_pileup" if pileup else &"catch")
	queue_free()


## Could not get home: it clatters down where it is and is gone.
func _lost() -> void:
	WeaponFx.burst(get_parent(), global_position, Vector3.UP, SPARKS, 8, 2.5, 0.3, 0.035)
	Sfx.play_at(weapon.bounce_sound, global_position, -4.0, 0.8)
	queue_free()


# --- helpers ------------------------------------------------------------------

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD)
	query.exclude = _exclude
	return get_world_3d().direct_space_state.intersect_ray(query)


func _draw_trail(cam: Camera3D, hidden: bool) -> void:
	if _history.is_empty() or hidden:
		_history.resize(TRAIL)
		_history.fill(global_position)
	for i in range(TRAIL - 1, 0, -1):
		_history[i] = _history[i - 1]
	_history[0] = global_position
	if cam == null or hidden:
		_trail_mesh.clear_surfaces()
		return
	var color := PILEUP_COLOR if strikes >= PILEUP else weapon.tracer_color
	WeaponFx.begin_ribbons(_trail_mesh, WeaponFx.ribbon_material())
	WeaponFx.add_ribbon(_trail_mesh, _history, weapon.projectile_size * 0.9, Color(color, 0.6), cam.global_position)
	WeaponFx.end_ribbons(_trail_mesh)


static func _disable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_shadows(child)
