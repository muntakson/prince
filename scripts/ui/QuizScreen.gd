extends CanvasLayer
class_name QuizScreen
## Chapter quiz: three "what would happen if...?" questions shown when the
## player walks through a chapter's exit door (Portal). Nobody gets stuck: a
## wrong answer is greyed out and the player tries again. A star is earned for
## each question answered right on the first try; stars are saved as flags
## ("quizstars_<chapter>") and totalled in the Science Words codex.
## Emits `finished` when the player presses Continue on the results card.

signal finished

## chapter id -> questions. Each: q, options (first one is correct; shuffled
## at runtime), why (shown after the right answer). [en, ko] pairs.
const QUIZZES := {
	"laboratory": [
		{"q": ["The Printing Press finds a letter with no Royal Seal. What happens?",
				"인쇄기가 왕의 봉인이 없는 편지를 발견했다. 어떻게 될까?"],
		 "options": [["It ignores the letter: no seal, no reading", "편지를 무시한다. 봉인이 없으면 읽지 않는다"],
				["It reads the letter twice as fast", "편지를 두 배로 빨리 읽는다"],
				["It reads the letter backwards", "편지를 거꾸로 읽는다"]],
		 "why": ["The 5′ cap tells the ribosome the mRNA is genuine and where to start. Without it, almost no protein is made.",
				"5′ 캡은 리보솜에게 진짜 mRNA임을, 그리고 어디서 시작할지 알려 준다. 캡이 없으면 단백질이 거의 만들어지지 않는다."]},
		{"q": ["Why must the letter get a Bubble Shield before it is injected?",
				"편지를 주사하기 전에 왜 거품 방패를 씌워야 할까?"],
		 "options": [["Shredders in the body would cut it up within minutes", "몸속 파쇄기들이 몇 분 만에 잘게 잘라 버리기 때문에"],
				["To make the letter heavy enough to sink", "편지를 무겁게 만들어 가라앉히려고"],
				["So the letter can turn into protein by itself", "편지가 스스로 단백질로 변할 수 있도록"]],
		 "why": ["RNases are everywhere. The lipid nanoparticle (LNP) hides the mRNA from them and carries it into cells.",
				"RNase는 어디에나 있다. 지질 나노입자(LNP)가 mRNA를 그들로부터 숨겨 세포 안으로 나른다."]},
		{"q": ["You make the letter's Fuse much longer. What changes?",
				"편지의 도화선을 훨씬 길게 만들었다. 무엇이 달라질까?"],
		 "options": [["The letter lasts longer, so more protein gets made", "편지가 더 오래 버텨서 단백질이 더 많이 만들어진다"],
				["The protein it builds gets longer", "만들어지는 단백질이 더 길어진다"],
				["Nothing at all", "아무것도 달라지지 않는다"]],
		 "why": ["The poly(A) tail is never built into protein, but a longer tail takes longer to nibble away, so the mRNA is read more times.",
				"폴리(A) 꼬리는 단백질로 만들어지지 않지만, 길수록 갉아 없애는 데 오래 걸려 mRNA가 더 여러 번 읽힌다."]},
	],
	"bioworld": [
		{"q": ["Why does the Magnet Fat wait for acid before it breaks the Swallow Bubble?",
				"자석 지방은 왜 산성이 되어서야 삼킴 주머니를 깰까?"],
		 "options": [["Only in acid does it turn positive and tear the wall", "산성에서만 양전하를 띠고 벽을 찢을 수 있어서"],
				["Acid melts every kind of fat", "산은 모든 지방을 녹여서"],
				["Acid wakes up the Printing Press", "산이 인쇄기를 깨워서"]],
		 "why": ["The ionizable lipid is neutral in the blood (gentle) but turns positive in the acidic endosome, where it disrupts the membrane.",
				"이온화 지질은 핏속에서는 중성(순함)이지만, 산성인 엔도솜 안에서 양전하를 띠어 막을 흔들어 놓는다."]},
		{"q": ["What happens if you wait too long to break out?",
				"탈출을 너무 오래 미루면 어떻게 될까?"],
		 "options": [["The Digesting Sack merges in and digests the letter", "소화 주머니가 합쳐져 편지를 소화해 버린다"],
				["The letter turns into protein inside the bubble", "편지가 주머니 안에서 단백질로 변한다"],
				["Nothing: waiting is always safe", "아무 일도 없다. 기다리는 건 늘 안전하다"]],
		 "why": ["If the endosome fuses with a lysosome, its enzymes destroy the mRNA. Escaping in time is one of the hardest steps for real vaccines.",
				"엔도솜이 리소좀과 합쳐지면 그 효소들이 mRNA를 파괴한다. 제때 탈출하는 것은 실제 백신에서도 가장 어려운 단계 중 하나다."]},
		{"q": ["The Printing Press reads  AUG · GCU · UAA.  How many beads end up in the chain?",
				"인쇄기가  AUG · GCU · UAA  를 읽는다. 사슬에는 구슬이 몇 개 달릴까?"],
		 "options": [["2", "2개"], ["3", "3개"], ["9", "9개"]],
		 "why": ["Each three-letter word (codon) adds one amino acid: AUG and GCU add two. UAA is THE END mark (a stop codon), so it adds none.",
				"세 글자 단어(코돈) 하나가 아미노산 하나를 붙인다. AUG와 GCU가 두 개를 붙이고, UAA는 ‘끝’ 표시(종결 코돈)라서 아무것도 붙이지 않는다."]},
	],
	"lymph": [
		{"q": ["Thousands of Knights wait in the Training Camp. Why does only one wake up?",
				"훈련소에는 기사 수천 명이 기다린다. 왜 단 하나만 깨어날까?"],
		 "options": [["Only its lock fits the Enemy's Face", "그 기사의 자물쇠만 적의 얼굴에 맞아서"],
				["It was the first one to arrive", "가장 먼저 도착해서"],
				["It is the biggest Knight", "가장 덩치가 커서"]],
		 "why": ["Every T-cell has its own receptor (TCR) shape. Only the one that fits the antigen on MHC is activated, then it copies itself.",
				"T세포마다 수용체(TCR) 모양이 다르다. MHC 위의 항원에 맞는 T세포만 활성화되고, 그다음 자신을 복제한다."]},
		{"q": ["How does the Scout Cell find its way to the Training Camp?",
				"정찰병 세포는 훈련소로 가는 길을 어떻게 찾을까?"],
		 "options": [["It sniffs out a Scent Trail with its antennae", "더듬이로 냄새 길을 맡아 따라간다"],
				["It follows the Printing Press", "인쇄기를 따라간다"],
				["It wanders until it bumps into it", "부딪힐 때까지 이리저리 떠돈다"]],
		 "why": ["Lymph nodes release chemokines such as CCL19; the dendritic cell's CCR7 receptors sense them and steer toward the stronger signal.",
				"림프절은 CCL19 같은 케모카인을 내뿜고, 수지상세포의 CCR7 수용체가 그것을 감지해 신호가 강한 쪽으로 움직인다."]},
		{"q": ["Why does the letter describe only a harmless piece of the cancer?",
				"편지는 왜 암의 해롭지 않은 조각 하나만 담고 있을까?"],
		 "options": [["A piece is enough to learn its face, and it cannot cause cancer", "조각만으로도 얼굴을 익히기에 충분하고, 암을 일으킬 수 없어서"],
				["A piece slows the cancer down all by itself", "조각 자체가 암을 느리게 만들어서"],
				["The body only fights things that are harmless", "몸은 해롭지 않은 것하고만 싸워서"]],
		 "why": ["The antigen is just a recognisable fragment. The immune system learns it safely, then hunts any cell that shows it.",
				"항원은 알아볼 수 있는 조각일 뿐이다. 면역계는 그것을 안전하게 익힌 뒤, 같은 조각을 보이는 세포를 사냥한다."]},
	],
	"tumor": [
		{"q": ["A tumor cell flashes a Fake Pass. What does the Pass Blocker do?",
				"종양 세포가 가짜 통행증을 내민다. 통행증 차단제는 무엇을 할까?"],
		 "options": [["Covers the Knight's badge reader so the fake pass stops working", "기사의 배지 판독기를 덮어 가짜 통행증이 통하지 않게 한다"],
				["Kills the tumor cell by itself", "스스로 종양 세포를 죽인다"],
				["Makes brand-new Knights", "새 기사를 만든다"]],
		 "why": ["Anti-PD-1 antibodies block PD-1 on T-cells, so tumor PD-L1 can no longer switch them off. The T-cells still do the killing.",
				"항-PD-1 항체는 T세포의 PD-1을 막아, 종양의 PD-L1이 더는 T세포를 끄지 못하게 한다. 죽이는 일은 여전히 T세포가 한다."]},
		{"q": ["Why must a Knight check the Display Window before it strikes?",
				"기사는 왜 공격하기 전에 진열창을 확인해야 할까?"],
		 "options": [["To spare healthy cells, which show their own faces", "자기 얼굴을 보이는 건강한 세포를 살려 주려고"],
				["To recharge its poison", "독을 다시 채우려고"],
				["Because tumor cells have no windows", "종양 세포에는 진열창이 없어서"]],
		 "why": ["Every cell shows protein pieces on MHC class I. T-cells kill only cells showing the antigen they were trained on.",
				"모든 세포는 MHC 1형에 단백질 조각을 내보인다. T세포는 자기가 훈련받은 항원을 보이는 세포만 죽인다."]},
		{"q": ["Years later, the cancer tries to come back. Who stops it fast?",
				"몇 년 뒤, 암이 다시 돌아오려 한다. 누가 재빨리 막을까?"],
		 "options": [["Veteran Knights", "노련한 기사"],
				["A new Royal Letter the body writes by itself", "몸이 스스로 쓴 새 왕의 편지"],
				["Bubble Shields still floating in the blood", "아직 핏속을 떠도는 거품 방패"]],
		 "why": ["Memory T-cells live for years. The mRNA and LNPs were broken down within days, but the immune memory stays.",
				"기억 T세포는 수년 동안 산다. mRNA와 LNP는 며칠 만에 분해되지만, 면역 기억은 남는다."]},
	],
}

const CHAPTER_NAMES := {
	"laboratory": ["The Royal Letter", "왕의 편지"], "bioworld": ["Inside the Cell", "세포 속으로"],
	"lymph": ["The Training Camp", "훈련소"], "tumor": ["The Tumor Fortress", "종양 요새"],
}

var chapter := ""
var _qi := 0
var _first_try := true
var _stars := 0
var _font: Font = null
var _title: Label
var _progress: Label
var _question: Label
var _why: Label
var _buttons: VBoxContainer
var _next: Button

static func has_quiz(chapter_id: String) -> bool:
	return QUIZZES.has(chapter_id)

static func stars(chapter_id: String) -> int:
	return int(GameState.get_flag("quizstars_" + chapter_id, 0))

static func total_stars() -> int:
	var n := 0
	for ch in QUIZZES.keys():
		n += stars(ch)
	return n

static func max_stars() -> int:
	return QUIZZES.size() * 3

static func open(tree: SceneTree, chapter_id: String) -> QuizScreen:
	var qs := QuizScreen.new()
	qs.chapter = chapter_id
	tree.root.add_child(qs)
	return qs

func _l() -> int:
	return 1 if GameState.lang == "ko" else 0

func _ready() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_font = GameState.ui_font()
	_build()
	_show_question()

func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # localized here
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if _font:
		l.add_theme_font_override("font", _font)
	return l

func _button(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size = Vector2(0, 64)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", size)
	if _font:
		b.add_theme_font_override("font", _font)
	# outlined cards so the answers read as clickable on the dark panel
	for st in [["normal", Color(0.13, 0.14, 0.24), Color(0.45, 0.55, 0.85)],
			["hover", Color(0.18, 0.2, 0.34), Color(1.0, 0.82, 0.35)],
			["pressed", Color(0.22, 0.24, 0.4), Color(1.0, 0.82, 0.35)],
			["focus", Color(0, 0, 0, 0), Color(1.0, 0.82, 0.35)],
			["disabled", Color(0.09, 0.09, 0.14), Color(0.25, 0.27, 0.36)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = st[1]
		sb.border_color = st[2]
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(10)
		sb.draw_center = st[0] != "focus"
		b.add_theme_stylebox_override(st[0], sb)
	return b

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var panel := PanelContainer.new()
	var vw: float = get_viewport().get_visible_rect().size.x
	var half: float = minf(330.0, vw / 2.0 - 16.0)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -half
	panel.offset_right = half
	panel.offset_top = -360
	panel.offset_bottom = 360
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.12, 0.98)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.82, 0.35, 0.8)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)
	var ln := _l()
	_title = _label(("관문 퀴즈: %s" if ln == 1 else "Gate Quiz: %s") % CHAPTER_NAMES.get(chapter, ["", ""])[ln], 26, Color(1.0, 0.88, 0.5))
	vb.add_child(_title)
	_progress = _label("", 18, Color(0.7, 0.75, 0.88))
	vb.add_child(_progress)
	_question = _label("", 23, Color(0.95, 0.96, 1.0))
	vb.add_child(_question)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	vb.add_child(_buttons)
	_why = _label("", 18, Color(0.6, 1.0, 0.7))
	vb.add_child(_why)
	_next = _button("", 24)
	_next.visible = false
	_next.pressed.connect(_on_next)
	vb.add_child(_next)

func _quiz() -> Array:
	return QUIZZES.get(chapter, [])

func _show_question() -> void:
	var ln := _l()
	var qd: Dictionary = _quiz()[_qi]
	_first_try = true
	_progress.text = ("문제 %d / %d    ★ %d" if ln == 1 else "Question %d of %d    ★ %d") % [_qi + 1, _quiz().size(), _stars]
	_question.text = qd["q"][ln]
	_why.text = ""
	_next.visible = false
	for c in _buttons.get_children():
		c.queue_free()
	var order: Array = range(qd["options"].size())
	order.shuffle()
	for i in order:
		var b := _button(qd["options"][i][ln], 20)
		b.pressed.connect(_on_answer.bind(b, i == 0))
		_buttons.add_child(b)

func _on_answer(b: Button, correct: bool) -> void:
	var ln := _l()
	if correct:
		AudioManager.sfx("mg_win" if _first_try else "lock")
		if _first_try:
			_stars += 1
		b.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
		b.add_theme_color_override("font_disabled_color", Color(0.5, 1.0, 0.6))
		for c in _buttons.get_children():
			(c as Button).disabled = true
		var qd: Dictionary = _quiz()[_qi]
		_why.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
		_why.text = ("정답! " if ln == 1 else "Right! ") + qd["why"][ln]
		_progress.text = ("문제 %d / %d    ★ %d" if ln == 1 else "Question %d of %d    ★ %d") % [_qi + 1, _quiz().size(), _stars]
		_next.text = ("다음" if ln == 1 else "Next") if _qi + 1 < _quiz().size() else ("결과 보기" if ln == 1 else "See results")
		_next.visible = true
		_next.grab_focus()
	else:
		AudioManager.sfx("wrong")
		_first_try = false
		b.disabled = true
		_why.add_theme_color_override("font_color", Color(1.0, 0.75, 0.5))
		_why.text = "아니다. 다시 생각해 보라!" if ln == 1 else "Not quite. Think again!"

func _on_next() -> void:
	AudioManager.sfx("ui_click")
	if _next.has_meta("done"):
		_close()
		return
	_qi += 1
	if _qi < _quiz().size():
		_show_question()
	else:
		_show_results()

func _show_results() -> void:
	var ln := _l()
	var best: int = maxi(_stars, stars(chapter))
	GameState.set_flag("quizstars_" + chapter, best)
	for c in _buttons.get_children():
		c.queue_free()
	var full := "★".repeat(_stars) + "☆".repeat(_quiz().size() - _stars)
	_progress.text = ""
	_question.text = full
	_question.add_theme_font_size_override("font_size", 56)
	_question.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	var msg: String
	if _stars == _quiz().size():
		msg = "완벽하다! 모두 첫 번째에 맞혔다." if ln == 1 else "Perfect! All right on the first try."
	elif _stars > 0:
		msg = ("첫 번째에 %d개를 맞혔다. 잘했다!" if ln == 1 else "%d right on the first try. Well done!") % _stars
	else:
		msg = "괜찮다. 이제 모든 답을 알게 되었다!" if ln == 1 else "That's okay. Now you know every answer!"
	_why.add_theme_color_override("font_color", Color(0.9, 0.91, 0.96))
	_why.text = msg + ("\n\n총 별: %d / %d" if ln == 1 else "\n\nTotal stars: %d / %d") % [total_stars(), max_stars()]
	_next.text = "계속" if ln == 1 else "Continue"
	_next.set_meta("done", true)
	_next.visible = true
	_next.grab_focus()

func _close() -> void:
	get_tree().paused = false
	finished.emit()
	queue_free()
