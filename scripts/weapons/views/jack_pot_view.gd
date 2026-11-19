extends RefCounted
## Jack Pot viewmodel motion (WeaponData.view_script). The loaded box sits
## lid-first in the launch cup (Box, its Lid hinged at the back). A shot
## throws it out of the cup and the crank (Crank) kicks back a quarter turn
## as the launch spring lets go; the next box rises out of the cup on a
## springy overshoot. While loaded the box quivers now and then and its lid
## lifts a crack (something inside wants out). The three bulbs on the top
## edge (Bulb0..2) light one per box out in the field; with all three out
## the oldest one's bulb blinks: the next shot pops it. The fat trigger
## (Trigger) pulls on every shot.
## Inspect: the crank winds to the music-box tune and a little slot-machine
## marquee rises out of the top, its three reels spinning to a stop one by
## one on card faces (the lid peeks, unimpressed). One time in JACKPOT_CHANCE
## they land 7-7-7: a jingle, the bulbs chase, the lid flies open and gold
## confetti bursts out of the box.

const BULBS := 3
## Seconds: the box leaves the cup, then the next one rises into it.
const THROW := 0.07
const LOAD_START := 0.14
const LOAD_TIME := 0.24
## The launch cup's axis in model space (it leans up 22 degrees; the box's
## mesh is built along it, its node is not turned).
const CUP_AXIS := Vector3(0.0, 0.375, -0.927)
## How far the box flies out of the cup before it vanishes, and how deep the
## next one starts (along the cup's axis, model units).
const THROW_DEPTH := 0.09
const LOAD_DEPTH := 0.07
const CRANK_KICK := -90.0
const TRIGGER_TIME := 0.1
## Every PEEK_EVERY seconds the loaded box's lid lifts a crack for PEEK_TIME.
const PEEK_EVERY := 2.6
const PEEK_TIME := 0.32
const PEEK_DEG := 22.0
## Inspect: length, the reels' faces, when each reel stops (seconds), the
## crank's wind (turns) and the marquee (model space, its size).
const INSPECT_LENGTH := 3.1
const JACKPOT_CHANCE := 1.0 / 20.0
const FACES: Array[String] = ["7", "J", "Q", "K", "A"]
const REEL_STOPS: Array[float] = [1.35, 1.65, 1.95]
const CRANK_TURNS := 2.0
const MARQUEE_AT := Vector3(0.0, 0.118, 0.05)
const MARQUEE_SIZE := Vector3(0.09, 0.036, 0.006)
const REEL_GAP := 0.027
const GOLD := Color(1.0, 0.82, 0.22)
const SEVEN := Color(1.0, 0.25, 0.3)
const CONFETTI := [Color(1.0, 0.84, 0.25), Color(1.0, 0.95, 0.6), Color(1.0, 0.35, 0.6), Color(0.4, 0.9, 1.0)]
const INSPECT_POSES := [
	[0.0, Vector3(0.14, -0.14, -0.62), Vector3(2.0, 10.0, -4.0)],
	[0.15, Vector3(0.05, -0.13, -0.47), Vector3(22.0, 32.0, 4.0)],
	[0.5, Vector3(0.04, -0.12, -0.46), Vector3(26.0, 26.0, 2.0)],
	[0.72, Vector3(0.04, -0.12, -0.46), Vector3(24.0, 22.0, 0.0)],
	[0.84, Vector3(0.06, -0.13, -0.56), Vector3(18.0, 36.0, 4.0)],
	[1.0, Vector3(0.14, -0.15, -0.62), Vector3(4.0, 6.0, 0.0)],
]

var _box: Node3D
var _lid: Node3D
var _crank: Node3D
var _trigger: Node3D
var _bulbs: Array[Node3D] = []
var _marquee: Node3D
var _reels: Array[Label3D] = []
var _faces: Array[String] = []
var _jackpot := false
var _stopped := 0
var _since_shot := 10.0
var _time := 0.0


func setup(v: WeaponView) -> void:
	for part in ["Box", "Lid", "Crank", "Drum", "Trigger", "ArmLFist"]:
		v.register_part(part)
	v.part("ArmLFist").visible = false
	for i in BULBS:
		v.register_part("Bulb%d" % i)
		_bulbs.append(v.part("Bulb%d" % i))
	_box = v.part("Box")
	_lid = v.part("Lid")
	_crank = v.part("Crank")
	_trigger = v.part("Trigger")


func fired(_v: WeaponView) -> void:
	_since_shot = 0.0


func event(_v: WeaponView, _event_name: StringName) -> void:
	pass


func update(v: WeaponView, delta: float) -> void:
	_since_shot += delta
	_time += delta
	_light_bulbs(v)
	if v.is_reloading():
		return
	_pose_box(v)
	if _crank:
		var kick := sin(PI * clampf(_since_shot / 0.22, 0.0, 1.0)) * (1.0 - clampf(_since_shot / 0.22, 0.0, 1.0) * 0.5)
		_crank.transform = v.rest_transform("Crank") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(CRANK_KICK * kick)), Vector3.ZERO)
	if _trigger:
		var k := sin(clampf(_since_shot / TRIGGER_TIME, 0.0, 1.0) * PI)
		_trigger.transform = v.rest_transform("Trigger") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-22.0 * k)), Vector3.ZERO)


## Thrown out of the cup, the next one rising in (none when the magazine is
## empty), the idle quiver and the lid's peek.
func _pose_box(v: WeaponView) -> void:
	if _box == null:
		return
	var loaded := _magazine(v) > 0
	var depth := 0.0
	var squash := 1.0
	if _since_shot < THROW:
		depth = -THROW_DEPTH * _since_shot / THROW
		_box.visible = true
	elif _since_shot < LOAD_START:
		_box.visible = false
	else:
		_box.visible = loaded
		var u := clampf((_since_shot - LOAD_START) / LOAD_TIME, 0.0, 1.0)
		depth = LOAD_DEPTH * (1.0 - _spring(u))
		squash = 1.0 + 0.08 * sin(PI * clampf(u * 1.6, 0.0, 1.0)) * (1.0 - u)
	var quiver := 0.0
	var peek := fmod(_time, PEEK_EVERY)
	if peek < PEEK_TIME:
		quiver = sin(peek * 90.0) * 1.2 * sin(PI * peek / PEEK_TIME)
	var pose := Transform3D(Basis(CUP_AXIS, deg_to_rad(quiver)).scaled(Vector3.ONE * squash), CUP_AXIS * -depth)
	_box.transform = v.rest_transform("Box") * pose
	if _lid:
		var lift := PEEK_DEG * sin(PI * clampf(peek / PEEK_TIME, 0.0, 1.0)) if _since_shot > LOAD_START + LOAD_TIME else 0.0
		_lid.transform = v.rest_transform("Lid") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(lift)), Vector3.ZERO)


## One bulb per box out; the oldest blinks when the next shot will pop it.
func _light_bulbs(v: WeaponView) -> void:
	var mode := _mode(v)
	var out := mode.boxes_out() if mode else 0
	for i in _bulbs.size():
		if _bulbs[i] == null:
			continue
		var on := i < out
		if on and out >= JackPotBox.MAX_BOXES and i == 0:
			on = fmod(_time, 0.4) < 0.24
		_bulbs[i].visible = on


func inspect_length() -> float:
	return INSPECT_LENGTH


func inspect_poses() -> Array:
	return INSPECT_POSES


func inspect_start(v: WeaponView) -> void:
	_jackpot = v.inspect_rare(JACKPOT_CHANCE)
	_faces.clear()
	if _jackpot:
		_faces.assign(["7", "7", "7"])
	else:
		# Never three sevens; now and then two, for the tease.
		_faces.assign([FACES.pick_random(), FACES.pick_random(), FACES.pick_random()])
		if randf() < 0.3:
			_faces.assign(["7", "7", FACES[randi_range(1, FACES.size() - 1)]])
		elif _faces.count("7") == 3:
			_faces[2] = "K"
	_stopped = 0
	_build_marquee(v)
	Sfx.play(&"jp_tune", -8.0)


func inspect(v: WeaponView, t: float) -> void:
	if _marquee == null:
		return
	# The crank winds round and eases to a stop as the last reel lands.
	if _crank:
		var wind := WeaponInspect.window(t, 0.2, REEL_STOPS[2]) * CRANK_TURNS * TAU
		_crank.transform = v.rest_transform("Crank") * Transform3D(Basis(Vector3.RIGHT, -wind), Vector3.ZERO)
	var rise := WeaponInspect.window(t, 0.35, 0.65) * (1.0 - WeaponInspect.window(t, 2.55, 2.85))
	_marquee.visible = rise > 0.01
	_marquee.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-35.0)).scaled(Vector3(1.0, maxf(0.01, rise), 1.0)),
		MARQUEE_AT + Vector3(0.0, -0.012 * (1.0 - rise), 0.0))
	for i in _reels.size():
		_spin_reel(v, i, t)
	var payoff := t - REEL_STOPS[2]
	if _jackpot and payoff > 0.0:
		var chase := int(payoff * 12.0) % _bulbs.size()
		for i in _bulbs.size():
			if _bulbs[i]:
				_bulbs[i].visible = i == chase or payoff > 0.9
	if _lid:
		var open := 0.0
		if _jackpot:
			open = 110.0 * WeaponInspect.window(payoff, 0.0, 0.08) * (1.0 - WeaponInspect.window(payoff, 0.7, 1.0))
		else:
			open = PEEK_DEG * 1.4 * WeaponInspect.hump(payoff, 0.15, 0.75)
		_lid.transform = v.rest_transform("Lid") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(open)), Vector3.ZERO)


func inspect_end(_v: WeaponView) -> void:
	if _marquee:
		_marquee.queue_free()
		_marquee = null
	_reels.clear()


## Each reel flicks through the faces, scrolling down, then lands on its
## face with a little bounce.
func _spin_reel(v: WeaponView, i: int, t: float) -> void:
	var reel := _reels[i]
	var stop := REEL_STOPS[i]
	var spin_from := 0.55
	if t < spin_from:
		reel.text = FACES[(i * 2 + 1) % FACES.size()]
		reel.position.y = 0.0
		return
	if t < stop:
		var turns := (t - spin_from) * 16.0
		reel.text = FACES[int(turns + i * 2) % FACES.size()]
		reel.position.y = -fposmod(turns, 1.0) * 0.012 + 0.006
		reel.modulate = SEVEN if reel.text == "7" else Color.WHITE
		return
	reel.text = _faces[i]
	reel.modulate = SEVEN if reel.text == "7" else Color.WHITE
	var u := t - stop
	reel.position.y = -0.006 * exp(-u * 12.0) * cos(u * 40.0)
	if _stopped <= i:
		_stopped = i + 1
		Sfx.play(&"jp_clunk", -12.0, 1.4 + i * 0.08)
		if i == _reels.size() - 1:
			_payoff(v)


func _payoff(v: WeaponView) -> void:
	if not _jackpot:
		if _faces.count("7") == 2:
			Sfx.play(&"jp_tease", -10.0)
		return
	Sfx.play(&"cos_kill_jackpot", -6.0)
	for r in _reels:
		r.outline_modulate = Color(0.55, 0.1, 0.0)
	if _box:
		var at := WeaponInspect.in_model(v, _box)
		FxBurst.spawn(v.model, at + Vector3(0.0, 0.04, 0.0), Vector3(0, 1, 0.2), CONFETTI, 26, 0.9, 0.9, 0.007, 60.0, Vector3(0, -0.9, 0), WeaponView._burst_mesh())


## The marquee: a dark panel with a gold rim that rises out of the top, and
## three reels.
func _build_marquee(v: WeaponView) -> void:
	inspect_end(v)
	_marquee = Node3D.new()
	_marquee.name = "InspectMarquee"
	v.model.add_child(_marquee)
	var panel := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = MARQUEE_SIZE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.04, 0.22)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.05, 0.35)
	box.material = mat
	panel.mesh = box
	panel.position = Vector3(0.0, MARQUEE_SIZE.y * 0.5, 0.0)
	_marquee.add_child(panel)
	var rim := MeshInstance3D.new()
	var rim_box := BoxMesh.new()
	rim_box.size = MARQUEE_SIZE + Vector3(0.008, 0.008, -0.002)
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = GOLD
	rim_mat.metallic = 0.8
	rim_mat.roughness = 0.3
	rim_box.material = rim_mat
	rim.mesh = rim_box
	rim.position = Vector3(0.0, MARQUEE_SIZE.y * 0.5, -0.002)
	_marquee.add_child(rim)
	for i in 3:
		var holder := Node3D.new()
		holder.position = Vector3((i - 1) * REEL_GAP, MARQUEE_SIZE.y * 0.5, MARQUEE_SIZE.z * 0.5 + 0.0008)
		_marquee.add_child(holder)
		var reel := Label3D.new()
		reel.font = UiKit.display_font()
		reel.font_size = 64
		reel.pixel_size = 0.00042
		reel.outline_size = 10
		reel.outline_modulate = Color(0.1, 0.0, 0.15)
		reel.shaded = false
		reel.double_sided = false
		reel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(reel)
		_reels.append(reel)
	for m in _marquee.find_children("*", "GeometryInstance3D", true, false):
		(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _magazine(v: WeaponView) -> int:
	if v.player and v.player.weapons and v.player.weapons.current == v.data:
		return v.player.weapons.magazine()
	return v.data.magazine_size


func _mode(v: WeaponView) -> JackPotMode:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return null
	return p.weapons.mode as JackPotMode


## A springy settle from 0 to 1 (overshoots a little).
static func _spring(u: float) -> float:
	return 1.0 - exp(-6.0 * u) * cos(11.0 * u)
