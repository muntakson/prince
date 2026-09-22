extends Node
## Music + SFX + spoken dialogue ("voice mode").
## Autoloaded as "AudioManager". Audio files are optional — missing files are
## skipped gracefully.
##
## SFX: `AudioManager.sfx("jump")` plays res://assets/audio/jump.mp3 through a
## small pool of one-shot players (ElevenLabs sound-generation clips).
## Voice: every dialogue line has a pre-generated ElevenLabs clip at
## res://assets/voice/<md5(speaker|text)[:12]>.mp3 (see assets/voice/manifest.json).
## Voice mode is toggled with the V key (input action "voice_toggle"), the
## pause-menu / title-screen buttons, and is remembered in user://settings.cfg.
## Lines without a clip fall back to the browser's speechSynthesis (web) or the
## OS text-to-speech (desktop) so nothing is ever silent.

signal voice_toggled(on: bool)

const SFX_DIR := "res://assets/audio/"
const VOICE_DIR := "res://assets/voice/"
const SETTINGS_PATH := "user://settings.cfg"
const POOL_SIZE := 8

var music_volume_db: float = -6.0
var sfx_volume_db: float = -4.0
var voice_volume_db: float = 2.0
var voice_enabled: bool = true
var last_sfx: String = ""            # for browser automation (window.__ss.sfx)

var _music: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}          # path -> AudioStream
var _current_music_path: String = ""
var _tts_fallback_active := false
var _toast: Label
var _toast_t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.volume_db = music_volume_db
	add_child(_music)
	_voice = AudioStreamPlayer.new()
	_voice.volume_db = voice_volume_db
	add_child(_voice)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = sfx_volume_db
		add_child(p)
		_sfx_pool.append(p)
	_load_settings()
	_build_toast()
	DialogueManager.line_shown.connect(_on_line_shown)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	GameState.flag_changed.connect(_on_flag_changed)

# --------------------------------------------------------------------------
# music
func play_music(path: String, loop: bool = true) -> void:
	if path == _current_music_path and _music.playing:
		return
	var stream = _get_stream(path)
	if stream == null:
		return
	if "loop" in stream:
		stream.loop = loop
	_music.stream = stream
	_music.volume_db = music_volume_db
	_music.play()
	_current_music_path = path

func stop_music() -> void:
	_music.stop()
	_current_music_path = ""

# --------------------------------------------------------------------------
# sound effects
func sfx(name: String) -> void:
	play_sfx(SFX_DIR + name + ".mp3")

func play_sfx(path: String) -> void:
	var stream = _get_stream(path)
	if stream == null:
		return
	last_sfx = path.get_file().get_basename()
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = sfx_volume_db
			p.play()
			return
	# pool exhausted: steal the first player
	_sfx_pool[0].stream = stream
	_sfx_pool[0].play()

func _get_stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var s = load(path)
	if s is AudioStream:
		_cache[path] = s
		return s
	return null

# --------------------------------------------------------------------------
# voice mode
static func voice_id(speaker: String, text: String) -> String:
	return (speaker + "|" + text).md5_text().substr(0, 12)

func is_voice_playing() -> bool:
	return _voice.playing or _tts_fallback_active

func set_voice_enabled(on: bool, announce: bool = true) -> void:
	if voice_enabled == on:
		return
	voice_enabled = on
	if not on:
		stop_voice()
	_save_settings()
	voice_toggled.emit(on)
	if announce:
		sfx("voice_on" if on else "voice_off")
		show_toast("Voice: ON" if on else "Voice: OFF")
	DebugConsole.dlog("voice mode %s" % ("on" if on else "off"))

func toggle_voice() -> void:
	set_voice_enabled(not voice_enabled)

func speak(speaker: String, text: String) -> void:
	stop_voice()
	if text.strip_edges() == "":
		return
	var id := voice_id(speaker, text)
	var spoken := text
	var lang_code := "en-US"
	var path := VOICE_DIR + id + ".mp3"
	if GameState.lang == "ko":
		lang_code = "ko-KR"
		var ko: String = GameState.ko_text(speaker, text)
		if ko != "":
			spoken = ko
			path = VOICE_DIR + "ko/" + id + ".mp3"
	var stream = _get_stream(path)
	if stream != null:
		_voice.stream = stream
		_voice.play()
		return
	DebugConsole.dlog("voice: no clip for '%s' (%s) -> tts fallback" % [text.substr(0, 40), lang_code])
	_fallback_tts(spoken, lang_code)

func stop_voice() -> void:
	if _voice.playing:
		_voice.stop()
	if _tts_fallback_active:
		_tts_fallback_active = false
		if OS.has_feature("web"):
			JavaScriptBridge.eval("try{window.speechSynthesis&&speechSynthesis.cancel();}catch(e){}", true)
		elif DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
			DisplayServer.tts_stop()

func _fallback_tts(text: String, lang_code: String = "en-US") -> void:
	if OS.has_feature("web"):
		var js := "(function(t,l){try{if(!window.speechSynthesis)return;speechSynthesis.cancel();var u=new SpeechSynthesisUtterance(t);u.lang=l;u.rate=1.0;speechSynthesis.speak(u);}catch(e){}})(%s,%s);" % [JSON.stringify(text), JSON.stringify(lang_code)]
		JavaScriptBridge.eval(js, true)
		_tts_fallback_active = true
	elif DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		var voices := DisplayServer.tts_get_voices_for_language(lang_code.substr(0, 2))
		if voices.size() > 0:
			DisplayServer.tts_speak(text, voices[0])
			_tts_fallback_active = true

func _on_line_shown(speaker: String, text: String) -> void:
	sfx("dlg_next")
	if voice_enabled:
		speak(speaker, text)

func _on_dialogue_finished() -> void:
	stop_voice()

func _on_flag_changed(flag: String, value: Variant) -> void:
	if flag == "story_complete" and value:
		sfx("fanfare")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("voice_toggle") and not event.is_echo():
		toggle_voice()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lang_toggle") and not event.is_echo():
		toggle_lang()
		get_viewport().set_input_as_handled()

## F3: English <-> Korean for dialogue text and voice (also the help screen).
func toggle_lang() -> void:
	var l := "ko" if GameState.lang == "en" else "en"
	GameState.set_lang(l)
	stop_voice()
	sfx("voice_on")
	show_toast("언어: 한국어 (F3)" if l == "ko" else "Language: English (F3)")
	DebugConsole.dlog("lang %s" % l)

# --------------------------------------------------------------------------
# settings + toast
func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		voice_enabled = bool(cf.get_value("audio", "voice", true))

func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	cf.set_value("audio", "voice", voice_enabled)
	cf.save(SETTINGS_PATH)

func _build_toast() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 95
	add_child(cl)
	_toast = Label.new()
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.anchor_top = 0.0
	_toast.offset_left = -160
	_toast.offset_right = 160
	_toast.offset_top = 70
	_toast.offset_bottom = 118
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 24)
	if ResourceLoader.exists(GameState.CJK_FONT_PATH):
		_toast.add_theme_font_override("font", load(GameState.CJK_FONT_PATH))   # covers Latin + Hangul
	_toast.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.16, 0.92)
	sb.border_color = Color(0.4, 0.6, 0.9, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8)
	_toast.add_theme_stylebox_override("normal", sb)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	cl.add_child(_toast)

func show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_t = 1.4

func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.4:
			_toast.modulate.a = clampf(_toast_t / 0.4, 0.0, 1.0)
	if _tts_fallback_active and OS.has_feature("web"):
		var speaking = JavaScriptBridge.eval("(window.speechSynthesis&&speechSynthesis.speaking)?1:0", true)
		if not speaking:
			_tts_fallback_active = false
