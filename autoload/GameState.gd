extends Node
## Global game state: story progress, chapter tracking, and world flags.
## Autoloaded as "GameState".

signal chapter_changed(chapter_id: String)
signal flag_changed(flag: String, value: Variant)

## Ordered story chapters. Drives progression and the chapter title cards.
const CHAPTERS := {
	"cave":        {"title": "Chapter 1 — The Cave",              "scene": "res://scenes/world/Cave.tscn"},
	"palace":      {"title": "Chapter 2 — The Princess's Chamber", "scene": "res://scenes/world/Palace.tscn"},
	"laboratory":  {"title": "Chapter 3 — The Molecular Kingdom",  "scene": "res://scenes/world/Laboratory.tscn"},
	"bioworld":    {"title": "Chapter 4 — Inside the Cell",        "scene": "res://scenes/world/BioWorld.tscn"},
	"lymph":       {"title": "Chapter 5 — The Lymph Node",         "scene": "res://scenes/world/LymphNode.tscn"},
	"tumor":       {"title": "Chapter 6 — The Tumor",              "scene": "res://scenes/world/Tumor.tscn"},
}

var current_chapter: String = "cave"
var last_checkpoint: Dictionary = {}          # {chapter, position}
var flags: Dictionary = {}                     # arbitrary story flags
var play_seconds: float = 0.0
var cutscene_active: bool = false            # true while a scripted sequence plays (player frozen)

func _process(delta: float) -> void:
	play_seconds += delta

func set_chapter(chapter_id: String) -> void:
	if not CHAPTERS.has(chapter_id):
		push_warning("Unknown chapter: %s" % chapter_id)
		return
	current_chapter = chapter_id
	chapter_changed.emit(chapter_id)

func chapter_title(chapter_id: String = "") -> String:
	var id := chapter_id if chapter_id != "" else current_chapter
	return CHAPTERS.get(id, {}).get("title", id)

func chapter_scene(chapter_id: String = "") -> String:
	var id := chapter_id if chapter_id != "" else current_chapter
	return CHAPTERS.get(id, {}).get("scene", "")

func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value
	flag_changed.emit(flag, value)

func get_flag(flag: String, default: Variant = false) -> Variant:
	return flags.get(flag, default)

func has_flag(flag: String) -> bool:
	return flags.get(flag, false) == true

func set_checkpoint(chapter_id: String, position: Vector2) -> void:
	last_checkpoint = {"chapter": chapter_id, "position": {"x": position.x, "y": position.y}}

func reset() -> void:
	current_chapter = "cave"
	last_checkpoint = {}
	flags.clear()
	play_seconds = 0.0

## --- serialization (used by SaveManager) ---
func to_dict() -> Dictionary:
	return {
		"current_chapter": current_chapter,
		"last_checkpoint": last_checkpoint,
		"flags": flags,
		"play_seconds": play_seconds,
	}

func from_dict(d: Dictionary) -> void:
	current_chapter = d.get("current_chapter", "cave")
	last_checkpoint = d.get("last_checkpoint", {})
	flags = d.get("flags", {})
	play_seconds = d.get("play_seconds", 0.0)
