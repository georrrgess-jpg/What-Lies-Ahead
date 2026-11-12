extends Node
## Scene flow: menu <-> level, the current level/weapon selection, and the one
## place that decides whether the mouse is captured.

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

var level: LevelData
var weapon_id: StringName
## Which menu page to open when the menu scene loads ("" = title).
var menu_page := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Developer hooks (automated playtests / screenshots). No effect in normal play.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autoplay") or arg.begins_with("--shot") or arg == "--dump-profile":
			var dev = load("res://scripts/dev/dev_driver.gd").new()
			dev.name = "DevDriver"
			add_child(dev)
			break


func start_level(level_id: StringName, starter_weapon: StringName) -> bool:
	var data := GameData.level(level_id)
	if data == null or not GameData.is_level_unlocked(data):
		push_warning("Game: level '%s' is not available" % level_id)
		return false
	level = data
	weapon_id = starter_weapon if GameData.weapon(starter_weapon) else GameData.default_weapon_id()
	Profile.data["last_weapon"] = String(weapon_id)
	get_tree().paused = false
	get_tree().change_scene_to_file(data.scene_path)
	return true


## Reloads the level scene, which rebuilds the run from scratch.
func retry() -> void:
	if level:
		start_level(level.id, weapon_id)
	else:
		to_menu()


func to_menu(page := "") -> void:
	menu_page = page
	get_tree().paused = false
	capture_mouse(false)
	get_tree().change_scene_to_file(MENU_SCENE)


func capture_mouse(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
