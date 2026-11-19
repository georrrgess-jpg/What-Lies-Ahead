class_name TicketRipperView
extends RefCounted
## Ticket Ripper viewmodel motion (WeaponData.view_script):
##   roll      the roll of tickets in the drum shrinks with the magazine
##             (from full to its bare core) and turns as it feeds, spinning
##             up with the trigger and coasting down after it
##   ribbon    the tickets hanging out of the feed slot (Rib0..3) swing on
##             springs: each shot flicks them out and tugs the slot; the
##             leading ticket, torn off by the reload, spools back out over
##             the first REGROW_SHOTS shots after it
##   counter   the streak figure on the drum's left plate (TicketRipperMode
##             .count()) and the ring of 15 pips round it; a printed winner
##             chases gold round the ring and reads WIN!; a broken streak
##             flashes the figure red
##   flakes    a pinch of ticket confetti from the slot every other shot
## Inspect: the gun shows its left flank and prints a long prize ticket out
## of the feed slot, the roll whirring, its joke typing out as it feeds; a
## tug tears it off and it flutters away.
## The static helpers are shared with the reload
## (scripts/weapons/reloads/ticket_ripper_reload.gd), which poses the same parts.

const HOLO_SHADER := "res://art/shaders/holo.gdshader"
const PIPS := 15
const RIBS := 4
const COUNTER := "TicketCounter"
## Roll radius scale with an empty magazine (the bare core).
const ROLL_EMPTY := 0.38
## Degrees the roll turns per shot fed, and how fast its spin coasts down.
const ROLL_STEP := 26.0
const ROLL_COAST := 6.0
## Ribbon springs: stiffness, damping, the flick a shot gives (degrees, about
## the barrel axis, outward), and the idle sway.
const RIB_K := 160.0
const RIB_DAMP := 9.0
const RIB_FLICK := 9.0
const RIB_SWAY := 1.6
const SLOT_TUG := 0.0025
const REGROW_SHOTS := 6.0
const HOLO_TINT := Color(1.0, 0.62, 0.82)
const GOLD := Color(1.0, 0.84, 0.25)
const RED := Color(1.0, 0.26, 0.3)
## Inspect: length, the printed ticket (length, height, model units), when it
## prints and tears (seconds), and its jokes (one at random).
const INSPECT_LENGTH := 3.2
const TICKET := Vector2(0.3, 0.032)
const PRINT := Vector2(0.45, 1.85)
const TEAR_AT := 2.15
const PAPER := Color(1.0, 0.93, 0.76)
const INK := Color(0.72, 0.08, 0.32)
const JOKES: Array[String] = [
	"ADMIT ONE - BRAINS NOT INCLUDED",
	"WINNER! ...OF THIS TICKET",
	"GOOD FOR ONE (1) FREE SCREAM",
	"KEEP THIS TICKET. OR DON'T.",
	"WHY DID THE ZOMBIE SKIP THE RIDE? NO GUTS",
	"NOT VALID FOR UNDEAD PERSONS",
]
const INSPECT_POSES := [
	[0.0, Vector3(0.14, -0.14, -0.62), Vector3(2.0, 14.0, -4.0)],
	[0.14, Vector3(0.04, -0.12, -0.57), Vector3(8.0, 72.0, -4.0)],
	[0.55, Vector3(0.02, -0.12, -0.56), Vector3(6.0, 80.0, -2.0)],
	[0.72, Vector3(0.03, -0.13, -0.57), Vector3(10.0, 74.0, 2.0)],
	[0.86, Vector3(0.08, -0.13, -0.6), Vector3(6.0, 34.0, 2.0)],
	[1.0, Vector3(0.14, -0.15, -0.62), Vector3(2.0, 6.0, 0.0)],
]
const FLAKES := [Color(1.0, 0.95, 0.8), Color(1.0, 0.4, 0.55), Color(1.0, 0.84, 0.3)]

var _roll_spin := 0.0
var _roll_vel := 0.0
var _rib_angle := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _rib_vel := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _tug := 0.0
var _shots := 0
var _time := 0.0
var _label: Label3D
var _pips: Array[Node3D] = []
var _ticket: Node3D
var _paper: MeshInstance3D
var _joke: Label3D
var _text := ""
var _torn := false


func setup(v: WeaponView) -> void:
	register(v)
	_pips = pips(v)
	_label = counter_label(v)
	holo_material(v)


func fired(v: WeaponView) -> void:
	_shots += 1
	_roll_vel = minf(_roll_vel + ROLL_STEP * 12.0, ROLL_STEP * 16.0)
	var side := 1.0 if _shots % 2 == 0 else 0.6
	for i in RIBS:
		_rib_vel[i] += RIB_FLICK * side * (1.0 + 0.35 * i) * 14.0
	_tug = 1.0
	var tip := v.part("Rib3")
	if tip and not tip.visible:
		tip.visible = true
		tip.scale = Vector3.ONE * 0.05
	elif tip and tip.scale.x < 1.0:
		tip.scale = Vector3.ONE * minf(1.0, tip.scale.x + 1.0 / REGROW_SHOTS)
	if _shots % 2 == 0 and v.part("Rib0"):
		v.spark_burst(v.rest_transform("Rib0").origin + Vector3(-0.01, -0.01, 0.0), Vector3(-1.0, -0.4, 0.0), FLAKES, 2, 0.7, 0.35, 0.006)


func event(_v: WeaponView, _event_name: StringName) -> void:
	pass


func update(v: WeaponView, delta: float) -> void:
	_time += delta
	_roll_vel = move_toward(_roll_vel, 0.0, delta * ROLL_STEP * 16.0 * ROLL_COAST / 6.0)
	_roll_spin = fmod(_roll_spin + _roll_vel * delta, 360.0)
	if v.is_reloading():
		return
	var w := weapons_of(v)
	var mag := w.magazine() if w else v.data.magazine_size
	pose_roll(v, roll_scale(float(mag) / v.data.magazine_size), _roll_spin, Vector3.ZERO)
	_update_ribbon(v, delta)
	var mode := w.mode as TicketRipperMode if w else null
	show_counter(_label, _pips, mode, _time)


func inspect_length() -> float:
	return INSPECT_LENGTH


func inspect_poses() -> Array:
	return INSPECT_POSES


func inspect_start(v: WeaponView) -> void:
	inspect_end(v)
	_text = JOKES.pick_random()
	_torn = false
	_ticket = Node3D.new()
	_ticket.name = "InspectTicket"
	_ticket.visible = false
	v.model.add_child(_ticket)
	_paper = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var paper := StandardMaterial3D.new()
	paper.albedo_color = PAPER
	paper.roughness = 0.85
	box.material = paper
	_paper.mesh = box
	_paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ticket.add_child(_paper)
	_joke = Label3D.new()
	_joke.font = UiKit.display_font()
	_joke.font_size = 48
	_joke.pixel_size = 0.00028
	_joke.modulate = INK
	_joke.outline_size = 0
	_joke.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_joke.shaded = false
	_joke.double_sided = false
	_joke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_joke.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	_joke.position = Vector3(-0.0012, 0.0, 0.01)
	_ticket.add_child(_joke)


func inspect(v: WeaponView, t: float) -> void:
	if _ticket == null:
		return
	var slot := v.rest_transform("Rib0").origin + Vector3(-0.03, 0.012, 0.0)
	var fed := WeaponInspect.window(t, PRINT.x, PRINT.y)
	if t >= PRINT.x and t < PRINT.y:
		_roll_vel = maxf(_roll_vel, ROLL_STEP * 14.0)
		if not _ticket.visible:
			Sfx.play(&"tkr_crank", -8.0, 1.1)
	_ticket.visible = fed > 0.0
	var length := maxf(0.002, TICKET.x * fed)
	var b := Basis.IDENTITY
	var at := slot
	if t >= TEAR_AT:
		if not _torn:
			_torn = true
			Sfx.play(&"tkr_tear", -6.0)
			v.spark_burst(slot, Vector3(-1, 0.3, 0), FLAKES, 4, 0.5, 0.3, 0.005)
		# Flutters down and away, rocking.
		var f := t - TEAR_AT
		b = Basis.from_euler(Vector3(sin(f * 9.0) * 0.5 * f, 0.4 * f, sin(f * 6.0) * 0.6 * f))
		at += Vector3(-0.12 * f, -0.5 * f * f, 0.05 * f)
		_ticket.visible = f < 0.8
	_ticket.transform = Transform3D(b, at)
	# The paper is a unit box stretched out of the slot (+Z); the joke types out on it.
	_paper.transform = Transform3D(Basis.from_scale(Vector3(0.0015, TICKET.y, length)), Vector3(0.0, 0.0, length * 0.5))
	var shown := clampi(int(_text.length() * WeaponInspect.window(t, PRINT.x + 0.05, PRINT.y - 0.1)), 0, _text.length())
	_joke.text = _text.substr(0, shown)


func inspect_end(_v: WeaponView) -> void:
	if _ticket:
		_ticket.queue_free()
		_ticket = null
		_paper = null
		_joke = null


## Each ticket swings on its own spring toward a slow sway; shots flick them out.
func _update_ribbon(v: WeaponView, delta: float) -> void:
	_tug = maxf(0.0, _tug - delta * 14.0)
	for i in RIBS:
		var target := sin(_time * 1.9 + i * 0.7) * RIB_SWAY * (1.0 + i * 0.4)
		_rib_vel[i] += ((target - _rib_angle[i]) * RIB_K - _rib_vel[i] * RIB_DAMP) * delta
		_rib_angle[i] = clampf(_rib_angle[i] + _rib_vel[i] * delta, -35.0, 35.0)
	pose_ribbon(v, _rib_angle, Vector3(-SLOT_TUG * _tug, 0.0, 0.0))


# --- shared with the reload ---------------------------------------------------------

static func register(v: WeaponView) -> void:
	v.register_part("Roll")
	v.register_part("RollHolo")
	for i in RIBS:
		v.register_part("Rib%d" % i)
	for i in PIPS:
		v.register_part("Pip%d" % i)


## The held weapon's controller when the view shows that weapon (null in previews).
static func weapons_of(v: WeaponView) -> WeaponController:
	if v.player and v.player.weapons and v.player.weapons.current == v.data:
		return v.player.weapons
	return null


static func pips(v: WeaponView) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for i in PIPS:
		out.append(v.part("Pip%d" % i))
	return out


## Radius scale of the roll with `fill` (0-1) of the magazine left.
static func roll_scale(fill: float) -> float:
	return lerpf(ROLL_EMPTY, 1.0, sqrt(clampf(fill, 0.0, 1.0)))


## Poses the roll: radius scale `k`, turned `spin` degrees, moved by `offset` (model space).
static func pose_roll(v: WeaponView, k: float, spin: float, offset: Vector3, tumble := Vector3.ZERO) -> void:
	var roll := v.part("Roll")
	if roll == null:
		return
	var rest := v.rest_transform("Roll")
	var b := Basis.from_euler(tumble * (PI / 180.0)) * Basis(Vector3.RIGHT, deg_to_rad(spin)) * Basis.from_scale(Vector3(1.0, k, k))
	roll.transform = Transform3D(rest.basis * b, rest.origin + offset)


## Poses the ribbon: each ticket's swing (degrees about the barrel axis,
## positive outward) on its rest pose, the slot end moved by `slot_offset`.
static func pose_ribbon(v: WeaponView, angles: PackedFloat32Array, slot_offset: Vector3) -> void:
	for i in RIBS:
		var rib := v.part("Rib%d" % i)
		if rib == null:
			continue
		var rest := v.rest_transform("Rib%d" % i)
		var origin := rest.origin + (slot_offset if i == 0 else Vector3.ZERO)
		rib.transform = Transform3D(rest.basis * Basis(Vector3.BACK, deg_to_rad(-angles[i])), origin).scaled_local(rib.scale)


## The streak figure on the counter face, made on first use.
static func counter_label(v: WeaponView) -> Label3D:
	var found := v.model.find_child(COUNTER, true, false) as Label3D
	if found:
		return found
	var anchor := v.model.find_child("CounterPoint", true, false) as Node3D
	if anchor == null:
		return null
	var label := Label3D.new()
	label.name = COUNTER
	label.font = UiKit.display_font()
	label.font_size = 64
	label.pixel_size = 0.00034
	label.outline_size = 10
	label.outline_modulate = Color(0.25, 0.02, 0.12)
	label.modulate = GOLD
	label.text = "00"
	label.shaded = false
	label.double_sided = false
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anchor.add_child(label)
	# Face out of the drum's left plate (-X).
	label.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	return label


## The hologram roll's shader (RollHolo), made on first use; the part starts hidden.
static func holo_material(v: WeaponView) -> ShaderMaterial:
	var holo := v.part("RollHolo") as MeshInstance3D
	if holo == null:
		return null
	if holo.material_override is ShaderMaterial:
		return holo.material_override
	var m := ShaderMaterial.new()
	m.shader = load(HOLO_SHADER)
	m.set_shader_parameter("holo_color", HOLO_TINT)
	m.set_shader_parameter("span", 0.05)
	holo.material_override = m
	holo.visible = false
	return m


## The counter and pips for `mode` (null in previews: an idle 00).
static func show_counter(label: Label3D, pip_nodes: Array[Node3D], mode: TicketRipperMode, time: float) -> void:
	var lit := mode.count() if mode else 0
	var ready := mode != null and mode.winner_ready
	var chase := int(time * 22.0)
	for i in pip_nodes.size():
		if pip_nodes[i]:
			pip_nodes[i].visible = (i + chase) % 3 != 0 if ready else i < lit
	if label == null:
		return
	var broke := mode != null and mode.since_break < 0.45
	var popped := mode != null and mode.since_winner < 0.35
	if ready:
		label.text = "WIN!"
		label.modulate = GOLD.lerp(Color.WHITE, 0.5 + 0.5 * sin(time * 24.0))
		label.scale = Vector3.ONE * 0.62
	elif broke:
		label.text = "00"
		label.modulate = RED if int(time * 14.0) % 2 == 0 else Color(0.5, 0.1, 0.15)
		label.scale = Vector3.ONE
	else:
		label.text = "%02d" % lit
		label.modulate = Color.WHITE.lerp(GOLD, 0.6) if popped else GOLD
		label.scale = Vector3.ONE * (1.0 + 0.25 * maxf(0.0, 1.0 - mode.since_hit * 10.0) if mode else 1.0)
