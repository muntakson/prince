extends Node
## Class competition: student login and live progress reporting to the
## classroom server (classroom/server.js, API in classroom/API.md).
## Autoloaded as "Classroom".
##
## When a student is logged in, story flags, chapter changes, lost letters,
## failed mini-games and the live tumor hunt are queued as events and sent in
## batches every few seconds; the server turns them into the scoreboard and
## each student's Mira status board. Nothing is sent in practice mode
## (Chapter Select / ?chapter=) or while debug mode (F2) is on, so shortcuts
## never count. Network errors keep the queue and retry.
##
## Server address: on the web build, the page's own origin (nginx proxies
## /api/ to the classroom server); override with ?api=<url>. On desktop,
## the PRINCE_API environment variable or the `api=<url>` user argument
## (godot --path . -- api=http://localhost:8110), else DEFAULT_API.

signal login_changed(logged_in: bool)
signal login_result(ok: bool, message: String)
signal score_changed(score: int)

const DEFAULT_API := "https://prince.aiedus.org"
const SETTINGS := "user://settings.cfg"
const FLUSH_EVERY := 2.0
const PING_EVERY := 15.0
const MAX_QUEUE := 500

var api_base := ""
var token := ""
var student_name := ""
var student_no := 0
var class_code := ""
var class_title := ""
var practice := false          # Chapter Select / URL jump: progress does not count
var score := -1                # latest total from the server (-1 = not known yet)

var _queue: Array = []
var _in_flight: Array = []
var _sending := false
var _flush_t := 0.0
var _ping_t := 0.0
var _http_events: HTTPRequest
var _http_login: HTTPRequest

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep reporting while dialogue/menus pause the tree
	api_base = _resolve_api()
	_http_events = HTTPRequest.new()
	_http_events.timeout = 10.0
	_http_events.request_completed.connect(_on_events_done)
	add_child(_http_events)
	_http_login = HTTPRequest.new()
	_http_login.timeout = 10.0
	_http_login.request_completed.connect(_on_login_done)
	add_child(_http_login)
	_load()
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.chapter_changed.connect(_on_chapter_changed)

func _resolve_api() -> String:
	var url := ""
	if OS.has_feature("web"):
		url = str(JavaScriptBridge.eval("(new URLSearchParams(window.location.search)).get('api') || window.location.origin", true))
	else:
		url = OS.get_environment("PRINCE_API")
		for a in OS.get_cmdline_user_args():
			if a.begins_with("api="):
				url = a.substr(4)
		if url == "":
			url = DEFAULT_API
	return url.strip_edges().trim_suffix("/")

func logged_in() -> bool:
	return token != ""

## True when progress is being reported right now.
func counting() -> bool:
	return logged_in() and not practice and not GameState.debug_mode

func who() -> String:
	return "%s (%s #%d)" % [student_name, class_code, student_no]

# ------------------------------------------------------------------ login
func login(code: String, no: int, pin: String) -> void:
	if _http_login.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var body := JSON.stringify({"class": code.strip_edges().to_upper(), "no": no, "pin": pin.strip_edges()})
	var err := _http_login.request(api_base + "/api/login", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		login_result.emit(false, "Can't reach the class server.")

func _on_login_done(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var data = JSON.parse_string(body.get_string_from_utf8()) if body.size() > 0 else null
	if result != HTTPRequest.RESULT_SUCCESS:
		login_result.emit(false, "Can't reach the class server. Check the internet connection.")
		return
	if code != 200 or not (data is Dictionary) or not data.has("token"):
		var msg := "Class code, number or PIN is wrong."
		if data is Dictionary and data.has("error"):
			msg = str(data["error"])
		login_result.emit(false, msg)
		return
	token = str(data["token"])
	student_name = str(data.get("name", ""))
	student_no = int(data.get("no", 0))
	class_code = str(data.get("class", ""))
	class_title = str(data.get("className", ""))
	_save()
	_resync()
	login_result.emit(true, "")
	login_changed.emit(true)

func logout() -> void:
	token = ""
	student_name = ""
	student_no = 0
	class_code = ""
	class_title = ""
	score = -1
	_queue.clear()
	_save()
	login_changed.emit(false)

## Send everything the game already knows (flags set before logging in, or
## a Continue from a save): the server keeps the best-ever state, so repeats
## are harmless.
func _resync() -> void:
	if not counting():
		return
	for f in GameState.flags.keys():
		_queue.append({"type": "flag", "name": f, "value": GameState.flags[f]})
	_queue.append({"type": "chapter", "id": GameState.current_chapter})
	_flush_t = FLUSH_EVERY

# ------------------------------------------------------------------ events
func event(type: String, data: Dictionary = {}) -> void:
	if not counting():
		return
	var ev := data.duplicate()
	ev["type"] = type
	_queue.append(ev)
	if _queue.size() > MAX_QUEUE:
		_queue = _queue.slice(_queue.size() - MAX_QUEUE)

func _on_chapter_changed(id: String) -> void:
	event("chapter", {"id": id})

func _on_flag_changed(flag: String, value: Variant) -> void:
	# the server ignores flags it does not score; numbers keep their value (quiz stars)
	event("flag", {"name": flag, "value": value})

func _process(delta: float) -> void:
	if not logged_in():
		return
	_flush_t += delta
	_ping_t += delta
	if _ping_t >= PING_EVERY:
		_ping_t = 0.0
		if counting() and _queue.is_empty():
			_queue.append({"type": "ping"})
	if _flush_t >= FLUSH_EVERY and not _sending and not _queue.is_empty():
		_flush_t = 0.0
		_send()

func _send() -> void:
	_in_flight = _queue.slice(0, 100)
	_queue = _queue.slice(_in_flight.size())
	var body := JSON.stringify({"token": token, "events": _in_flight})
	var err := _http_events.request(api_base + "/api/events", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		_queue = _in_flight + _queue
		_in_flight = []
		return
	_sending = true

func _on_events_done(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_sending = false
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		_in_flight = []
		var data = JSON.parse_string(body.get_string_from_utf8())
		if data is Dictionary and data.has("score") and int(data["score"]) != score:
			score = int(data["score"])
			score_changed.emit(score)
		return
	if result == HTTPRequest.RESULT_SUCCESS and code == 401:
		# PIN was reset or the class was deleted: ask the student to log in again
		_in_flight = []
		logout()
		return
	# network trouble: put the batch back and retry on the next flush
	_queue = _in_flight + _queue
	_in_flight = []

# ------------------------------------------------------------------ settings
func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) != OK:
		return
	token = str(cf.get_value("classroom", "token", ""))
	student_name = str(cf.get_value("classroom", "name", ""))
	student_no = int(cf.get_value("classroom", "no", 0))
	class_code = str(cf.get_value("classroom", "class", ""))
	class_title = str(cf.get_value("classroom", "class_title", ""))

func _save() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS)
	cf.set_value("classroom", "token", token)
	cf.set_value("classroom", "name", student_name)
	cf.set_value("classroom", "no", student_no)
	cf.set_value("classroom", "class", class_code)
	cf.set_value("classroom", "class_title", class_title)
	cf.save(SETTINGS)
