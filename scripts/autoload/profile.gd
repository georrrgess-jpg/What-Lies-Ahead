extends Node
## Versioned local save (user://profile.json): mastery, equipped cosmetics,
## per-level progress and settings. Everything else in the game reads and writes
## through this autoload; nothing persistent lives in level scenes.

signal saved

const SAVE_VERSION := 3
const DEFAULT_PATH := "user://profile.json"

const DEFAULT_SETTINGS := {
	"mouse_sensitivity": 1.0,
	"ads_sensitivity": 0.9,
	"reticle_style": "auto",
	"reticle_color": "white",
	"fov": 72.0,
	"master_volume": 0.9,
	"music_volume": 0.7,
	"sfx_volume": 0.9,
	"ambience_volume": 1.0,
	"invert_y": false,
	"camera_shake": 1.0,
	"flashes": 1.0,
	"graphics": "high",
	"fullscreen": false,
	"difficulty": "standard",
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
		"levels": {},     # level_id -> { "best_wave", "completed", "clears", "best_score" }
		"settings": DEFAULT_SETTINGS.duplicate(),
		"last_weapon": "",
		# Free-form sections owned by individual systems (see section()):
		# "cosmetics", "progression", "unlocks", "loadout", "stats", ...
		"sections": {},
	}


## A persistent dictionary owned by one system (created on first use). Its
## contents are saved as-is, so keep them to JSON types (numbers, strings,
## bools, arrays, dictionaries). Call save_profile() after changing it.
func section(name: String) -> Dictionary:
	var all: Dictionary = data["sections"]
	if typeof(all.get(name)) != TYPE_DICTIONARY:
		all[name] = {}
	return all[name]


func load_profile() -> void:
	data = defaults()
	recovered_from_bad_save = false
	if not FileAccess.file_exists(save_path):
		# A save interrupted between writing and replacing leaves only these.
		for alt in [save_path + ".tmp", save_path + ".bak"]:
			var raw = _read_json(alt)
			if raw is Dictionary:
				data = _migrate(raw)
				return
		return
	var parsed = _read_json(save_path)
	if not parsed is Dictionary:
		_set_aside_bad_save()
		return
	data = _migrate(parsed)


## The JSON dictionary in `path`, or null if missing or unreadable.
static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if text.is_empty() or json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return null
	return json.data


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
	# Replace in one step where the OS allows; otherwise keep the old save as
	# .bak until the new one is in place (load_profile falls back to it).
	var err := DirAccess.rename_absolute(tmp, save_path)
	if err != OK and FileAccess.file_exists(save_path):
		var bak := save_path + ".bak"
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(save_path, bak)
		err = DirAccess.rename_absolute(tmp, save_path)
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
		levels[key] = {"best_wave": 0, "completed": false, "clears": 0, "best_score": 0}
	return levels[key]


func best_wave(level_id: StringName) -> int:
	return int(level_entry(level_id)["best_wave"])


func is_level_completed(level_id: StringName) -> bool:
	return bool(level_entry(level_id)["completed"])


func best_score(level_id: StringName) -> int:
	return int(level_entry(level_id).get("best_score", 0))


## Returns true if this is a new best for the level.
func record_score(level_id: StringName, value: int) -> bool:
	var entry := level_entry(level_id)
	if value > int(entry.get("best_score", 0)):
		entry["best_score"] = value
		return true
	return false


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
	if typeof(raw.get("sections")) == TYPE_DICTIONARY:
		for key in raw["sections"]:
			if typeof(raw["sections"][key]) == TYPE_DICTIONARY:
				out["sections"][String(key)] = raw["sections"][key]
	# version 1 -> 2: per-weapon equipped rewards moved into the cosmetics section.
	if typeof(raw.get("equipped")) == TYPE_DICTIONARY:
		var cos: Dictionary = out["sections"].get("cosmetics", {})
		var eq: Dictionary = cos.get("equipped", {})
		for weapon_id in raw["equipped"]:
			var e = raw["equipped"][weapon_id]
			if typeof(e) == TYPE_DICTIONARY:
				for slot in ["decal", "cell", "finish"]:
					var id := String(e.get(slot, ""))
					if id != "":
						eq["weapon_%s@%s" % [slot, weapon_id]] = id
		cos["equipped"] = eq
		out["sections"]["cosmetics"] = cos
	if typeof(raw.get("levels")) == TYPE_DICTIONARY:
		for key in raw["levels"]:
			var l = raw["levels"][key]
			if typeof(l) == TYPE_DICTIONARY:
				out["levels"][String(key)] = {
					"best_wave": maxi(0, int(l.get("best_wave", 0))),
					"completed": bool(l.get("completed", false)),
					"clears": maxi(0, int(l.get("clears", 0))),
					"best_score": maxi(0, int(l.get("best_score", 0))),
				}
	if typeof(raw.get("settings")) == TYPE_DICTIONARY:
		for key in DEFAULT_SETTINGS:
			if raw["settings"].has(key) and typeof(raw["settings"][key]) in _compatible_types(DEFAULT_SETTINGS[key]):
				var v = raw["settings"][key]
				out["settings"][key] = float(v) if typeof(DEFAULT_SETTINGS[key]) == TYPE_FLOAT else v
		# Options newer than DEFAULT_SETTINGS (look sensitivity, aim mode...).
		for key in Settings.EXTRA_DEFAULTS:
			if raw["settings"].has(key) and typeof(raw["settings"][key]) in _compatible_types(Settings.EXTRA_DEFAULTS[key]):
				var e = raw["settings"][key]
				out["settings"][key] = float(e) if typeof(Settings.EXTRA_DEFAULTS[key]) == TYPE_FLOAT else e
	out["last_weapon"] = String(raw.get("last_weapon", ""))
	# version 2 -> 3: the Sparks economy re-gated and priced cosmetics. The save
	# is flagged here; LegacyGrant (run by the Cosmetics autoload, once the game
	# data is loaded) keeps everything it owned and pays its Sparks back pay.
	if int(raw.get("version", 0)) < 3:
		var economy: Dictionary = out["sections"].get("economy", {})
		economy["legacy_pending"] = true
		out["sections"]["economy"] = economy
	return out


func _compatible_types(default_value) -> Array:
	match typeof(default_value):
		TYPE_FLOAT: return [TYPE_FLOAT, TYPE_INT]
		TYPE_BOOL: return [TYPE_BOOL]
		_: return [typeof(default_value)]
