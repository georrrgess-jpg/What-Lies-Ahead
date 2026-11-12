extends Node
## Versioned local save (user://profile.json): mastery, equipped cosmetics,
## per-level progress and settings. Everything else in the game reads and writes
## through this autoload; nothing persistent lives in level scenes.

signal saved

const SAVE_VERSION := 1
const DEFAULT_PATH := "user://profile.json"

const DEFAULT_SETTINGS := {
	"mouse_sensitivity": 1.0,
	"fov": 85.0,
	"master_volume": 0.9,
	"music_volume": 0.55,
	"sfx_volume": 0.9,
	"camera_shake": 1.0,
	"flashes": 1.0,
	"graphics": "high",
	"fullscreen": false,
}

var save_path := DEFAULT_PATH
var data: Dictionary = {}
## True when the last load found a file it could not read (and set it aside).
var recovered_from_bad_save := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			save_path = arg.trim_prefix("--profile=")
	load_profile()


func defaults() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"mastery": {},    # weapon_id -> { "xp": int, "kills": int }
		"equipped": {},   # weapon_id -> { "decal": id, "cell": id, "finish": id }
		"levels": {},     # level_id -> { "best_wave": int, "completed": bool, "clears": int }
		"settings": DEFAULT_SETTINGS.duplicate(),
		"last_weapon": "",
	}


func load_profile() -> void:
	data = defaults()
	recovered_from_bad_save = false
	if not FileAccess.file_exists(save_path):
		return
	var text := FileAccess.get_file_as_string(save_path)
	var json := JSON.new()
	if text.is_empty() or json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		_set_aside_bad_save()
		return
	data = _migrate(json.data)


## Writes to a temp file first so a crash mid-write cannot corrupt the save.
func save_profile() -> bool:
	data["version"] = SAVE_VERSION
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Profile: cannot write %s (error %d)" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	var err := DirAccess.rename_absolute(tmp, save_path)
	if err != OK:
		push_warning("Profile: cannot replace %s (error %d)" % [save_path, err])
		return false
	saved.emit()
	return true


func reset_progress() -> void:
	var settings: Dictionary = data["settings"]
	data = defaults()
	data["settings"] = settings
	save_profile()


# --- level progress -------------------------------------------------------

func level_entry(level_id: StringName) -> Dictionary:
	var levels: Dictionary = data["levels"]
	var key := String(level_id)
	if not levels.has(key):
		levels[key] = {"best_wave": 0, "completed": false, "clears": 0}
	return levels[key]


func best_wave(level_id: StringName) -> int:
	return int(level_entry(level_id)["best_wave"])


func is_level_completed(level_id: StringName) -> bool:
	return bool(level_entry(level_id)["completed"])


func record_wave_cleared(level_id: StringName, wave_number: int) -> void:
	var entry := level_entry(level_id)
	entry["best_wave"] = maxi(int(entry["best_wave"]), wave_number)


func record_level_cleared(level_id: StringName) -> void:
	var entry := level_entry(level_id)
	entry["completed"] = true
	entry["clears"] = int(entry["clears"]) + 1


# --- internals ------------------------------------------------------------

func _set_aside_bad_save() -> void:
	recovered_from_bad_save = true
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var bad := "%s.unreadable-%s" % [save_path, stamp]
	DirAccess.rename_absolute(save_path, bad)
	push_warning("Profile: save was unreadable; kept a copy at %s and started fresh." % bad)
	data = defaults()


## Copies only known, well-typed fields onto fresh defaults, so a partial or
## older save still loads. Bump SAVE_VERSION and add steps here when the
## format changes.
func _migrate(raw: Dictionary) -> Dictionary:
	var out := defaults()
	# version 0 -> 1: nothing to convert yet.
	if typeof(raw.get("mastery")) == TYPE_DICTIONARY:
		for key in raw["mastery"]:
			var m = raw["mastery"][key]
			if typeof(m) == TYPE_DICTIONARY:
				out["mastery"][String(key)] = {
					"xp": maxi(0, int(m.get("xp", 0))),
					"kills": maxi(0, int(m.get("kills", 0))),
				}
	if typeof(raw.get("equipped")) == TYPE_DICTIONARY:
		for key in raw["equipped"]:
			var e = raw["equipped"][key]
			if typeof(e) == TYPE_DICTIONARY:
				var slots := {}
				for slot in ["decal", "cell", "finish"]:
					slots[slot] = String(e.get(slot, ""))
				out["equipped"][String(key)] = slots
	if typeof(raw.get("levels")) == TYPE_DICTIONARY:
		for key in raw["levels"]:
			var l = raw["levels"][key]
			if typeof(l) == TYPE_DICTIONARY:
				out["levels"][String(key)] = {
					"best_wave": maxi(0, int(l.get("best_wave", 0))),
					"completed": bool(l.get("completed", false)),
					"clears": maxi(0, int(l.get("clears", 0))),
				}
	if typeof(raw.get("settings")) == TYPE_DICTIONARY:
		for key in DEFAULT_SETTINGS:
			if raw["settings"].has(key) and typeof(raw["settings"][key]) in _compatible_types(DEFAULT_SETTINGS[key]):
				var v = raw["settings"][key]
				out["settings"][key] = float(v) if typeof(DEFAULT_SETTINGS[key]) == TYPE_FLOAT else v
	out["last_weapon"] = String(raw.get("last_weapon", ""))
	return out


func _compatible_types(default_value) -> Array:
	match typeof(default_value):
		TYPE_FLOAT: return [TYPE_FLOAT, TYPE_INT]
		TYPE_BOOL: return [TYPE_BOOL]
		_: return [typeof(default_value)]
