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
var debug_mode: bool = false                 # F2: every station/gate/portal opens regardless of progress
var lang: String = "en"                      # F3: "en" / "ko" — dialogue text + voice language

signal lang_changed(lang: String)

const KO_PATH := "res://assets/help/dialogue_ko.json"
const UI_KO_PATH := "res://assets/help/ui_ko.json"   # English UI string -> Korean (TranslationServer)
const CJK_FONT_PATH := "res://assets/fonts/help_ko.otf"
var _ko_speakers: Dictionary = {}
var _ko_lines: Dictionary = {}
var _cjk_font: Font = null

## Korean translations are keyed by the same id as the voice clips:
## md5(speaker|english_text)[:12]. English text stays the canonical key.
static func line_id(speaker: String, text: String) -> String:
	return (speaker + "|" + text).md5_text().substr(0, 12)

func _load_locale() -> void:
	if FileAccess.file_exists(KO_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(KO_PATH))
		if parsed is Dictionary:
			_ko_speakers = parsed.get("speakers", {})
			_ko_lines = parsed.get("lines", {})
	if ResourceLoader.exists(CJK_FONT_PATH):
		_cjk_font = load(CJK_FONT_PATH)
		# The CJK subset (Latin + Hangul) becomes the default UI font for every
		# Control, so translated captions render. Set at runtime: as the project
		# setting gui/theme/custom_font it stalled the web build's boot.
		ThemeDB.fallback_font = _cjk_font          # custom-drawn text (draw_string)
		var th: Theme = ThemeDB.get_project_theme()
		if th == null:
			th = ThemeDB.get_default_theme()
		if th:
			th.default_font = _cjk_font            # Labels / Buttons / RichTextLabels
	# UI strings: every Label/Button/RichTextLabel auto-translates its text through
	# the TranslationServer, so captions, labels and menus follow the locale.
	if FileAccess.file_exists(UI_KO_PATH):
		var ui = JSON.parse_string(FileAccess.get_file_as_string(UI_KO_PATH))
		if ui is Dictionary:
			var t := Translation.new()
			t.locale = "ko"
			for k in ui.keys():
				t.add_message(k, ui[k])
			TranslationServer.add_translation(t)
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		lang = str(cf.get_value("ui", "lang", "en"))
	TranslationServer.set_locale(lang)

func set_lang(l: String) -> void:
	if l == lang:
		return
	lang = l
	TranslationServer.set_locale(lang)
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("ui", "lang", lang)
	cf.save("user://settings.cfg")
	lang_changed.emit(lang)

## Korean text for an English line, or "" when there is no translation.
func ko_text(speaker: String, text: String) -> String:
	return str(_ko_lines.get(line_id(speaker, text), ""))

## [speaker, text] to display for the current language.
func localize(speaker: String, text: String) -> Array:
	if lang == "ko":
		var ko := ko_text(speaker, text)
		if ko != "":
			return [str(_ko_speakers.get(speaker, speaker)), ko]
	return [speaker, text]

## Font that covers the current language (the CJK subset for Korean), or null.
func ui_font() -> Font:
	return _cjk_font if lang == "ko" else null

signal debug_mode_changed(on: bool)

## Progress gate helper: true when the flag is set OR debug mode is on.
func unlocked(flag: String) -> bool:
	return debug_mode or flag == "" or has_flag(flag)

func set_debug_mode(on: bool) -> void:
	if debug_mode == on:
		return
	debug_mode = on
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("debug", "mode", on)
	cf.save("user://settings.cfg")
	debug_mode_changed.emit(on)

func _load_debug_mode() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		debug_mode = bool(cf.get_value("debug", "mode", false))

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

func _ready() -> void:
	_load_debug_mode()
	_load_locale()

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
