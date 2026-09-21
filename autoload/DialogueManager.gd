extends Node
## Lightweight dialogue queue. The HUD's DialogueBox listens to these signals.
## Autoloaded as "DialogueManager".
##
## A "line" is a Dictionary: {"speaker": String, "text": String}
## Call start([...lines]) to show a sequence; advance() steps through it.

signal dialogue_started()
signal line_shown(speaker: String, text: String)
signal dialogue_finished()

var _queue: Array = []
var _active: bool = false

func is_active() -> bool:
	return _active

func queue_size() -> int:
	return _queue.size()

## Accepts an Array of line Dictionaries, or an Array of [speaker, text] pairs,
## or a single "text" String for quick barks.
func start(lines) -> void:
	_queue.clear()
	if lines is String:
		_queue.append({"speaker": "", "text": lines})
	elif lines is Array:
		for l in lines:
			if l is Dictionary:
				_queue.append({"speaker": l.get("speaker", ""), "text": l.get("text", "")})
			elif l is Array and l.size() >= 2:
				_queue.append({"speaker": str(l[0]), "text": str(l[1])})
			elif l is String:
				_queue.append({"speaker": "", "text": l})
	if _queue.is_empty():
		return
	_active = true
	get_tree().paused = true
	DebugConsole.dlog("DLG start q=%d (was_active=%s)" % [_queue.size(), _active])
	dialogue_started.emit()
	_show_next()

func advance() -> void:
	if not _active:
		return
	DebugConsole.dlog("DLG advance q=%d" % _queue.size())
	if _queue.is_empty():
		_finish()
	else:
		_show_next()

func _show_next() -> void:
	var line: Dictionary = _queue.pop_front()
	line_shown.emit(line.get("speaker", ""), line.get("text", ""))

func _finish() -> void:
	_active = false
	get_tree().paused = false
	DebugConsole.dlog("DLG finish -> unpaused")
	dialogue_finished.emit()
