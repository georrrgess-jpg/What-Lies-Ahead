extends Control
## In-run rounds overlay (registered by data/ui/hud_rounds.tres): the world
## markers the wave system needs beyond the shared HUD (which shows the wave
## banners, the round chip and, through RoundsBossBar, the alpha's health):
##   - a marker on the entrance a surge is about to pour through;
##   - a marker that follows the bounty target, with its time left;
##   - small pings over the last few zombies of a wave.

const SURGE_COLOR := Color(1.0, 0.3, 0.42)
const PING_COLOR := Color(1.0, 0.76, 0.29)

var _director: RunDirector
var _player: Player
var _surge: Waypoint
var _bounty: Waypoint
var _time := 0.0
var _bounty_seconds := -1
var _pinging := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surge = _marker("SURGE", SURGE_COLOR, "portal", Vector3(0, 3.0, 0))
	_bounty = _marker("BOUNTY", UiKit.AMBER, "kiosk", Vector3(0, 2.7, 0))


## Full screen: the markers place themselves.
func hud_slot() -> StringName:
	return &"overlay"


func bind(director: RunDirector, player: Player) -> void:
	_director = director
	_player = player
	_surge.camera = player.camera
	_bounty.camera = player.camera
	director.bounty_changed.connect(_on_bounty_changed)
	director.surge_warning.connect(_on_surge_warning)
	director.run_finished.connect(func(_r): visible = false)


func _process(delta: float) -> void:
	if _director == null:
		return
	_time += delta
	_surge.visible = _director.surge_point() != null
	if is_instance_valid(_director.bounty):
		var seconds := int(ceil(_director.bounty_seconds_left()))
		if seconds != _bounty_seconds:
			_bounty_seconds = seconds
			_bounty.label = "BOUNTY  %ds" % seconds
	if _director.is_closing_out():
		_pinging = true
		queue_redraw()
	elif _pinging:
		_pinging = false
		queue_redraw()


# --- markers -------------------------------------------------------------------

func _marker(text: String, color: Color, icon: String, offset: Vector3) -> Waypoint:
	var w := Waypoint.new()
	w.label = text
	w.color = color
	w.icon = icon
	w.offset = offset
	w.visible = false
	add_child(w)
	return w


func _on_surge_warning(point: Node3D, _seconds: float) -> void:
	_surge.target = point
	_surge.visible = true


func _on_bounty_changed(target: Zombie) -> void:
	_bounty.target = target
	_bounty.visible = target != null


## Pings over the last few zombies of a wave, so nobody has to hunt for them.
func _draw() -> void:
	if _director == null or _player == null or not _director.is_closing_out():
		return
	var camera := _player.camera
	var rect := get_viewport_rect().size
	var pulse := 0.6 + 0.4 * sin(_time * 7.0)
	for z in _director.alive_enemies():
		if not is_instance_valid(z) or z.is_dead() or z == _director.bounty:
			continue
		var world := z.global_position + Vector3.UP * (2.2 * z.data.body_scale + 0.5)
		var behind := camera.is_position_behind(world)
		var p := camera.unproject_position(world)
		if behind:
			p = rect - p
			p.y = rect.y - 70.0
		p = p.clamp(Vector2(60, 60), rect - Vector2(60, 60))
		var c := Color(PING_COLOR, pulse)
		var dark := Color(UiKit.INK, 0.85)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-15, -15), p + Vector2(15, -15), p + Vector2(0, 9)]), dark)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-10, -12), p + Vector2(10, -12), p + Vector2(0, 4)]), c)
