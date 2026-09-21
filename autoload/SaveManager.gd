extends Node
## Save / load to user:// as JSON. Works on desktop, web (IndexedDB) and Android.
## Autoloaded as "SaveManager".

signal saved()
signal loaded()

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"game_state": GameState.to_dict(),
		"inventory": Inventory.to_dict(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: could not open save file for writing.")
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	saved.emit()
	return true

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: corrupt save file.")
		return false
	GameState.from_dict(parsed.get("game_state", {}))
	Inventory.from_dict(parsed.get("inventory", {}))
	loaded.emit()
	return true

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		# On web, use the sandboxed remove:
		if FileAccess.file_exists(SAVE_PATH):
			var d := DirAccess.open("user://")
			if d: d.remove("savegame.json")

func save_summary() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var gs: Dictionary = parsed.get("game_state", {})
	return {
		"chapter": gs.get("current_chapter", "cave"),
		"timestamp": parsed.get("timestamp", 0),
	}
