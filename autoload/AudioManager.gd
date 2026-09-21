extends Node
## Simple music + SFX manager with pooled one-shot players.
## Autoloaded as "AudioManager". Audio files are optional — missing files are
## skipped gracefully so the skeleton runs before final assets exist.

var _music: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
const POOL_SIZE := 8

var music_volume_db: float = -6.0
var sfx_volume_db: float = -3.0
var _current_music_path: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.volume_db = music_volume_db
	add_child(_music)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = sfx_volume_db
		add_child(p)
		_sfx_pool.append(p)

func play_music(path: String, loop: bool = true) -> void:
	if path == _current_music_path and _music.playing:
		return
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream == null:
		return
	if stream is AudioStream:
		if "loop" in stream:
			stream.loop = loop
	_music.stream = stream
	_music.volume_db = music_volume_db
	_music.play()
	_current_music_path = path

func stop_music() -> void:
	_music.stop()
	_current_music_path = ""

func play_sfx(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = sfx_volume_db
			p.play()
			return
