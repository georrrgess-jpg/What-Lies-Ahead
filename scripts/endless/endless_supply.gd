class_name EndlessSupply
extends Node3D
## A supply crate of an Endless run: dropped by the EndlessDirector at a
## `supply_drop` marker every few breaks. It sways down under a parachute
## from high above (FALL_SECONDS), thumps down in a cloud of dust and lights
## a green flare; walking into it refills both weapons, heals and pays
## tickets (EndlessRules.supply_*).

signal collected(crate: EndlessSupply)

const FALL_SECONDS := 5.0
const FALL_HEIGHT := 34.0
const PICKUP := 2.4
const FLARE := Color(0.35, 1.0, 0.45)
const DUST := [Color(0.55, 0.5, 0.46), Color(0.42, 0.38, 0.35), Color(0.7, 0.64, 0.56)]

var director: RunDirector
var tickets := 150
var heal := 50.0
var landed := false

var _crate: Node3D
var _chute: Node3D
var _flare: OmniLight3D
var _beam: MeshInstance3D
var _time := 0.0
var _done := false


func _ready() -> void:
	add_to_group("endless_supply")
	_build()
	_crate.position.y = FALL_HEIGHT
	Sfx.play(&"end_supply_incoming", -2.0)


func _process(delta: float) -> void:
	_time += delta
	if not landed:
		var t := minf(1.0, _time / FALL_SECONDS)
		_crate.position.y = FALL_HEIGHT * (1.0 - t)
		_crate.rotation.z = sin(_time * 1.7) * 0.12 * (1.0 - t)
		if t >= 1.0:
			_land()
		return
	if _flare:
		_flare.light_energy = 2.2 + sin(_time * 9.0) * 0.6 + randf() * 0.3
	if _beam:
		_beam.rotation.y += delta * 0.6
	var player := director.player if director else null
	if not _done and player and player.alive and player.global_position.distance_to(global_position) < PICKUP:
		_collect(player)


func _land() -> void:
	landed = true
	_crate.position.y = 0.0
	_crate.rotation = Vector3.ZERO
	Sfx.play_at(&"end_supply_land", global_position + Vector3.UP, 0.0, 1.0, 16.0)
	EndlessProps.burst(get_parent(), global_position + Vector3.UP * 0.3, Vector3.UP, DUST, 40, 4.0, 1.0, 0.14, 85.0)
	if _chute:
		var tw := create_tween()
		tw.tween_property(_chute, "scale", Vector3(1.4, 0.05, 1.4), 0.6)
		tw.tween_callback(_chute.queue_free)
	_flare = EndlessProps.light(self, FLARE, 2.2, 9.0, Vector3(0, 1.6, 0))


func _collect(player: Player) -> void:
	_done = true
	player.weapons.top_up()
	player.heal(heal)
	if director:
		director.add_tickets(tickets, "SUPPLY +%d" % tickets, global_position + Vector3.UP * 2.0)
		director.notice.emit("SUPPLIES: energy full  ·  +%d health  ·  +%d tickets" % [int(heal), tickets], &"good")
	Sfx.play(&"purchase", -2.0)
	Fx.confetti(get_parent(), global_position + Vector3.UP * 1.2)
	collected.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.05, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


# --- looks ---------------------------------------------------------------------

## The kit's airdrop crate (art/models/city_supply_crate.glb) when it exists,
## else a hazard-striped crate under a striped canopy; a green light beam
## marks it from afar.
func _build() -> void:
	_crate = Node3D.new()
	_crate.name = "Crate"
	add_child(_crate)
	var prop := EndlessProps.model("supply_crate")
	if prop:
		_crate.add_child(prop)
		_chute = prop.find_child("*Chute*", true, false) as Node3D
	else:
		EndlessProps.box(_crate, Vector3(1.3, 1.0, 1.3), Vector3(0, 0.5, 0), EndlessProps.mat(Color(0.3, 0.42, 0.24)))
		EndlessProps.box(_crate, Vector3(1.36, 0.22, 1.36), Vector3(0, 0.5, 0), EndlessProps.hazard_mat())
		EndlessProps.box(_crate, Vector3(0.5, 0.06, 0.5), Vector3(0, 1.02, 0), EndlessProps.mat(FLARE, 2.5))
		_chute = Node3D.new()
		_chute.name = "Chute"
		_crate.add_child(_chute)
		var canopy := SphereMesh.new()
		canopy.radius = 2.6
		canopy.height = 2.0
		canopy.is_hemisphere = true
		canopy.radial_segments = 16
		canopy.rings = 4
		var mi := MeshInstance3D.new()
		mi.mesh = canopy
		mi.material_override = EndlessProps.mat(Color(1.0, 0.45, 0.15), 0.4)
		mi.position = Vector3(0, 4.6, 0)
		_chute.add_child(mi)
		for i in 4:
			var a := TAU * i / 4 + PI * 0.25
			var line := EndlessProps.box(_chute, Vector3(0.03, 3.8, 0.03), Vector3(cos(a) * 1.1, 2.9, sin(a) * 1.1), EndlessProps.mat(Color(0.9, 0.9, 0.85)))
			line.rotation = Vector3(sin(a) * 0.28, 0, -cos(a) * 0.28)
	_beam = EndlessProps.cylinder(self, 0.35, 40.0, Vector3(0, 20.0, 0), _beam_mat(), 8)


static func _beam_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(FLARE, 0.18)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
