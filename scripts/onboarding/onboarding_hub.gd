class_name OnboardingHub
extends Node
## Lives under Game for the whole session (Onboarding.install()).
##   - In real runs: one-time hints in a small card (first break, low energy,
##     each special enemy's tell, first portal, first defeat), each stored as
##     seen, all off when the "tips" setting is off.
##   - In the menu: attaches CoachMarks to every MainMenu that loads.

## Enemy id -> its tell, shown the first time one of them is on the field.
const TELLS := {
	&"boardwalk_bruiser": ["BOARDWALK BRUISER", "It roars, then charges in a straight line. Sidestep the charge."],
	&"lifeguard_runner": ["LIFEGUARD RUNNER", "Fast and fragile. Pop it before it closes the gap."],
	&"mascot_inker": ["MASCOT INKER", "Its ink sac swells, then it lobs ink. Strafe sideways or close in."],
	&"jelly_head": ["JELLY HEAD", "When its hat glows, a ring marks the shock. Step out of the ring."],
	&"deep_diver": ["DEEP DIVER", "The helmet shrugs off headshots until the visor cracks. Keep at it."],
	&"dune_hazmat_worker": ["IRRADIATED HAZMAT", "It bursts when it falls: step out of the glowing ring."],
	&"dune_jet_mechanic": ["JETPACK MECHANIC", "The jetpack sputters, then it hops over cover to you."],
	&"dune_space_cadet": ["SPACE CADET", "It crouches before it pounces. Strafe during the crouch."],
	&"frost_frozen_tourist": ["FROZEN TOURIST", "The ice shell soaks body shots. Headshots get through."],
	&"frost_ski_racer": ["SKI RACER", "It tucks, then rushes in a line. Step sideways."],
	&"frost_yeti": ["YETI", "It rears back with a snowball. A headshot in the windup cancels it."],
	&"hover_courier": ["HOVER COURIER", "Boots flare, then it leaps in. High ground is not safe."],
	&"neon_punk": ["NEON PUNK", "Hear the rattle? A headshot knocks the spray can down."],
	&"riot_bruiser": ["RIOT BRUISER", "The shield blocks the front. Shoot over it or flank."],
}
const HINTS := {
	&"first_break": ["WAVE CLEARED", "Breaks are shopping time: follow the marker to the Loadout Station."],
	&"low_ammo": ["LOW ON ENERGY", "The Loadout Station tops your weapons up between waves."],
	&"first_portal": ["PORTAL OPEN", "Follow the chasing lights on the deck to the portal."],
	&"first_defeat": ["DOWN, NOT OUT", "Continue restarts from the last checkpoint. Too spicy? Pick Casual on the Play page."],
}

var _director: RunDirector
var _menu: Node
var _scan: Timer
var _seen_enemies := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_restore_tips_setting()
	Settings.changed.connect(_remember_tips_setting)
	Events.run_started.connect(_on_run_started)
	Events.run_finished.connect(_on_run_finished)
	_scan = Timer.new()
	_scan.wait_time = 0.5
	_scan.autostart = true
	_scan.timeout.connect(_on_scan)
	add_child(_scan)


## The profile keeps only the settings it has defaults for, so the "tips"
## choice is also kept in the onboarding section and put back on load.
func _restore_tips_setting() -> void:
	var sec := Profile.section(Onboarding.SECTION)
	if sec.has("tips") and not Profile.data["settings"].has("tips"):
		Profile.data["settings"]["tips"] = bool(sec["tips"])


func _remember_tips_setting() -> void:
	Profile.section(Onboarding.SECTION)["tips"] = Onboarding.tips_enabled()


## Shows hint `id` once (title and text from HINTS or TELLS).
func hint(id: StringName, title: String, text: String) -> void:
	if not Onboarding.tips_enabled() or Onboarding.seen(id) or Game.tutorial_active:
		return
	Onboarding.mark_seen(id)
	var scene := get_tree().current_scene
	if scene:
		HintCard.show_hint(scene, title, text)


func _on_run_started(director: Node) -> void:
	_seen_enemies.clear()
	_director = director as RunDirector
	if _director == null or _director is TutorialRun:
		_director = null
		return
	_director.state_changed.connect(_on_state_changed)
	_director.player.weapons.ammo_changed.connect(_on_ammo_changed)


func _on_state_changed(state: RunDirector.State) -> void:
	match state:
		RunDirector.State.BREAK:
			_show(&"first_break")
		RunDirector.State.EXTRACTION:
			_show(&"first_portal")


func _on_ammo_changed(magazine: int, reserve: int) -> void:
	var w := _director.player.weapons if is_instance_valid(_director) else null
	if w == null or w.current == null or w.current.uses_heat():
		return
	if reserve + magazine <= w.current.magazine_size and reserve < w.current.reserve_start / 3:
		_show(&"low_ammo")


func _on_run_finished(result: Dictionary) -> void:
	if not bool(result.get("victory", true)) and not bool(result.get("abandoned", false)) and _director:
		# Over the results screen, which appears a moment later.
		get_tree().create_timer(2.4, true, false, true).timeout.connect(_show.bind(&"first_defeat"))
	_director = null


func _show(id: StringName) -> void:
	var entry: Array = HINTS[id]
	hint(id, entry[0], entry[1])


## Twice a second: a new special enemy on the field, or a main menu to coach.
func _on_scan() -> void:
	if is_instance_valid(_director) and _director.state == RunDirector.State.WAVE:
		for z in _director.alive_enemies():
			if is_instance_valid(z) and z.data and not _seen_enemies.has(z.data.id):
				_seen_enemies[z.data.id] = true
				if TELLS.has(z.data.id):
					hint(StringName("enemy_" + String(z.data.id)), TELLS[z.data.id][0], TELLS[z.data.id][1])
	var scene := get_tree().current_scene
	if scene and scene != _menu and scene.name == "MainMenu":
		_menu = scene
		var marks := CoachMarks.new()
		marks.name = "CoachMarks"
		scene.add_child(marks)
		marks.watch(scene)
