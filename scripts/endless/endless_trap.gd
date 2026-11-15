class_name EndlessTrap
extends Node3D
## A trap of an Endless map, built by the EndlessDirector at an
## `endless_feature` marker (kind "trap_fire" or "trap_shock"). The player
## pays a few tickets at it to arm it; for `seconds` it burns (gas burners
## through the street grate) or shocks (a sparking grid off a generator)
## every zombie inside `radius`, then it cools down before it can be armed
## again. Its damage follows the wave's health scale, so it stays a real tool
## late in a run. It never hurts the player.

enum State { READY, ACTIVE, COOLDOWN }

const FIRE := &"trap_fire"
const SHOCK := &"trap_shock"
## Seconds between damage pulses, and damage per pulse at health scale 1.
const PULSE := {FIRE: 0.3, SHOCK: 0.75}
const DAMAGE := {FIRE: 20.0, SHOCK: 55.0}
## Heavy zombies take this share.
const HEAVY_SHARE := 0.6
const FLAMES := [Color(1.0, 0.85, 0.3), Color(1.0, 0.5, 0.12), Color(0.95, 0.25, 0.08)]
const ARCS := Color(0.55, 0.85, 1.0)
const CITY_FIRE := "res://scenes/props/city_fire.tscn"

var kind: StringName = FIRE
var district: StringName
var radius := 4.5
var price := 250
var seconds := 15.0
var cooldown := 40.0
var director: RunDirector
## True while the player stands close enough to arm it.
var player_inside := false
var state := State.READY

var _left := 0.0
var _pulse := 0.0
var _sound := 0.0
var _sign: Label3D
var _lamp: MeshInstance3D
var _glow: OmniLight3D
var _emitters: Array[Vector3] = []
## Fire: a flame tongue over each burner, shown while it burns.
var _flames: Array[Node3D] = []
var _time := 0.0


func _ready() -> void:
	add_to_group("endless_trap")
	_build()
	_set_state(State.READY)


## What the HUD prompt says while the player stands here ({} while it runs).
func prompt() -> Dictionary:
	match state:
		State.READY:
			return {"action": "arm the %s trap" % _noun(), "price": price, "accent": _accent()}
		State.COOLDOWN:
			return {"action": "%s trap recharging" % _noun(), "price": 0, "accent": UiKit.MUTED, "note": "%d s" % ceili(_left), "disabled": true}
	return {}


## Arms it (the director has taken the tickets).
func arm() -> void:
	if state != State.READY:
		return
	_set_state(State.ACTIVE)
	_left = seconds
	_pulse = 0.0
	Sfx.play_at(&"end_trap_fire" if kind == FIRE else &"end_trap_shock", global_position + Vector3.UP, 0.0, 1.0, 14.0)


func _process(delta: float) -> void:
	_watch_player()
	match state:
		State.ACTIVE:
			_left -= delta
			_pulse -= delta
			_sound -= delta
			if _pulse <= 0.0:
				_pulse = PULSE[kind]
				_strike()
			if _glow:
				_glow.light_energy = (3.2 if kind == FIRE else 2.6) * randf_range(0.65, 1.2)
			_time += delta
			for i in _flames.size():
				if _flames[i] is MeshInstance3D:
					_flames[i].scale.y = 0.75 + 0.35 * sin(_time * 13.0 + i * 1.7) + randf() * 0.15
			if _left <= 0.0:
				_set_state(State.COOLDOWN)
				_left = cooldown
		State.COOLDOWN:
			_left -= delta
			if _left <= 0.0:
				_set_state(State.READY)
				if player_inside or _near_player(14.0):
					Sfx.play_at(&"end_trap_ready", global_position + Vector3.UP, -4.0)


## One damage pulse: every zombie inside takes its share, with flames or arcs.
func _strike() -> void:
	if kind == FIRE:
		for e in _emitters:
			EndlessProps.burst(get_parent(), to_global(e), Vector3.UP, FLAMES, 7, 5.5, 0.55, 0.16, 18.0, Vector3(0, 2.5, 0))
		if _sound <= 0.0:
			_sound = 2.4
			Sfx.play_at(&"end_trap_fire", global_position + Vector3.UP, -6.0, randf_range(0.95, 1.05), 12.0)
	if director == null:
		return
	var scale := director.endless.health_scale() if director.endless else 1.0
	var hits := 0
	# A copy: a kill takes the zombie out of the director's list.
	for item in director.alive_enemies().duplicate():
		if not is_instance_valid(item) or (item as Zombie).is_dead():
			continue
		var z: Zombie = item
		var flat := Vector2(z.global_position.x - global_position.x, z.global_position.z - global_position.z)
		if flat.length() > radius or absf(z.global_position.y - global_position.y) > 2.5:
			continue
		var amount: float = DAMAGE[kind] * scale * (HEAVY_SHARE if z.data.heavy else 1.0)
		var chest := z.global_position + Vector3.UP * 1.0 * z.data.body_scale
		if kind == SHOCK:
			if hits < 6:
				LightningBolt.spawn(get_parent(), to_global(_emitters[hits % _emitters.size()]), chest, ARCS, 0.07, 0.2, 0.35)
			z.interrupt()
		hits += 1
		z.take_hit(amount, chest, Vector3.UP, kind, false)
	if kind == SHOCK and hits > 0 and _sound <= 0.0:
		_sound = 0.7
		Sfx.play_at(&"end_trap_shock", global_position + Vector3.UP, -5.0, randf_range(0.92, 1.08), 12.0)


func _watch_player() -> void:
	var player := director.player if director else null
	player_inside = player != null and player.alive and _near_player(radius + 1.2)


func _near_player(distance: float) -> bool:
	var player := director.player if director else null
	return player != null and player.global_position.distance_to(global_position) < distance


func _set_state(new_state: State) -> void:
	state = new_state
	var color: Color = {State.READY: Color(0.4, 1.0, 0.5), State.ACTIVE: _accent(), State.COOLDOWN: Color(1.0, 0.3, 0.25)}[new_state]
	if _lamp:
		_lamp.material_override = EndlessProps.mat(color, 3.0)
	if _glow:
		_glow.visible = new_state == State.ACTIVE
	for f in _flames:
		f.visible = new_state == State.ACTIVE
	if _sign:
		_sign.text = "%s TRAP\n%s" % [_noun().to_upper(), "%d TICKETS" % price if new_state == State.READY else ("ARMED" if new_state == State.ACTIVE else "RECHARGING")]
		_sign.modulate = color.lerp(Color.WHITE, 0.2)


func _noun() -> String:
	return "fire" if kind == FIRE else "shock"


func _accent() -> Color:
	return Color(1.0, 0.5, 0.15) if kind == FIRE else Color(0.4, 0.75, 1.0)


# --- looks ---------------------------------------------------------------------

## The kit's prop when it exists (art/models/city_trap_fire.glb with empties
## Burner0-3, ..._shock.glb with Spark0-3, both with a Console), else a
## hazard-ringed street grate with burners or a generator and a grid. Fire
## burns as the kit's CityFire when it exists, else as flame cones.
func _build() -> void:
	var console := Vector3(radius + 0.6, 0, 0)
	var prop := EndlessProps.model(String(kind))
	if prop:
		add_child(prop)
		for i in 4:
			var marker := prop.find_child(("Burner%d" if kind == FIRE else "Spark%d") % i, true, false) as Node3D
			if marker:
				_emitters.append(to_local(marker.global_position))
		var c := prop.find_child("Console", true, false) as Node3D
		if c:
			console = to_local(c.global_position)
	else:
		_build_stand_in()
	if _emitters.is_empty():
		var n := 6 if kind == FIRE else 1
		for i in n:
			var a := TAU * i / n
			_emitters.append(Vector3(cos(a), 0.1, sin(a)) * radius * 0.55 if kind == FIRE else Vector3(0, 0.5, 0))
	if kind == FIRE:
		for e in _emitters:
			_flames.append(_flame(e))
	_glow = EndlessProps.light(self, _accent(), 3.0, radius * 2.4, Vector3(0, 1.2, 0))
	_sign = EndlessProps.sign(self, "", 40, Color.WHITE, console + Vector3(0, 2.6, 0))


## A flame over a burner: the kit's CityFire, else an additive cone that
## flickers in height while it burns.
func _flame(at: Vector3) -> Node3D:
	if ResourceLoader.exists(CITY_FIRE):
		var fire: Node3D = (load(CITY_FIRE) as PackedScene).instantiate()
		fire.set("size", 0.9)
		fire.set("with_light", false)
		fire.set("with_smoke", false)
		fire.position = at
		fire.visible = false
		add_child(fire)
		return fire
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.42
	cone.height = 2.2
	cone.radial_segments = 8
	cone.rings = 1
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.45, 0.1, 0.75)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone.material = m
	var pivot := MeshInstance3D.new()
	pivot.mesh = cone
	pivot.position = at + Vector3(0, 1.1, 0)
	pivot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.visible = false
	add_child(pivot)
	return pivot


func _build_stand_in() -> void:
	var ring := EndlessProps.cylinder(self, radius, 0.06, Vector3(0, 0.03, 0), EndlessProps.hazard_mat(), 32)
	ring.name = "HazardRing"
	EndlessProps.cylinder(self, radius - 0.35, 0.08, Vector3(0, 0.04, 0), EndlessProps.mat(Color(0.16, 0.15, 0.17), 0.0, 0.4), 32)
	var post := Node3D.new()
	post.name = "Console"
	post.position = Vector3(radius + 0.6, 0, 0)
	add_child(post)
	EndlessProps.box(post, Vector3(0.5, 1.2, 0.4), Vector3(0, 0.6, 0), EndlessProps.mat(Color(0.3, 0.32, 0.36), 0.0, 0.5))
	_lamp = EndlessProps.box(post, Vector3(0.3, 0.18, 0.3), Vector3(0, 1.3, 0), EndlessProps.mat(Color.GREEN, 3.0))
	if kind == FIRE:
		for i in 6:
			var a := TAU * i / 6
			var at := Vector3(cos(a), 0, sin(a)) * radius * 0.55
			EndlessProps.cylinder(self, 0.22, 0.3, at + Vector3(0, 0.15, 0), EndlessProps.mat(Color(0.35, 0.2, 0.12)), 10)
			EndlessProps.cylinder(self, 0.12, 0.05, at + Vector3(0, 0.32, 0), EndlessProps.mat(Color(1.0, 0.45, 0.1), 2.0), 10)
	else:
		EndlessProps.box(self, Vector3(1.2, 1.0, 0.9), Vector3(0, 0.5, 0), EndlessProps.mat(Color(0.95, 0.7, 0.15)))
		EndlessProps.cylinder(self, 0.18, 0.7, Vector3(0, 1.35, 0), EndlessProps.mat(Color(0.5, 0.8, 1.0), 2.5), 10)
		for i in 4:
			var a := TAU * i / 4 + PI * 0.25
			EndlessProps.box(self, Vector3(radius * 1.6, 0.05, 0.08), Vector3(0, 0.1, 0), EndlessProps.mat(Color(0.4, 0.7, 1.0), 1.5)).rotation.y = a
