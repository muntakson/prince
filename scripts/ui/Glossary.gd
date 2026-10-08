extends RefCounted
class_name Glossary
## Every science word in the game, introduced "nickname first": players meet a
## kingdom nickname (Royal Seal, Fuse, Knight...) and earn the real science name
## as a Word Card. Learned words are story flags ("word_<id>"), so they are
## saved with the game and listed in the Science Words codex (CodexScreen).
##
## In dialogue, drop a card into any line list with `Glossary.card("cap5")`.
## DialogueManager marks the word learned when the card is shown; the Korean
## card text is registered with GameState at startup (see register_ko).

const SPEAKER := "New Word"
const SPEAKER_KO := "새 단어"

## Codex sections, in story order.
const SECTIONS := [
	{"en": "The Royal Letter", "ko": "왕의 편지",
		"ids": ["mrna", "cap5", "utr5", "start_codon", "orf", "stop_codon", "utr3", "polya", "rnase"]},
	{"en": "The Bubble Shield", "ko": "거품 방패",
		"ids": ["lnp", "mixer", "ionizable", "dspc", "cholesterol", "peg"]},
	{"en": "Inside the Cell", "ko": "세포 속으로",
		"ids": ["dc", "endosome", "lysosome", "deadenylase", "exonuclease", "ribosome", "codon", "antigen", "mhc"]},
	{"en": "The Training Camp", "ko": "훈련소",
		"ids": ["lymph_node", "chemokine", "ccr7", "tcell", "tcr", "three_signals", "clonal"]},
	{"en": "The Tumor Fortress", "ko": "종양 요새",
		"ids": ["treg", "caf", "hypoxia", "pdl1", "antibody", "perforin", "apoptosis", "memory"]},
]

## id -> nickname / science name / one-sentence plain explanation (en + ko).
const WORDS := {
	# --- the royal letter (mRNA) ---
	"mrna": {
		"nick": ["Royal Letter", "왕의 편지"],
		"sci": ["mRNA (messenger RNA)", "mRNA (전령 RNA)"],
		"what": ["A temporary instruction note. The cell reads it, builds one protein, then throws it away.",
			"세포가 읽고 단백질 하나를 만든 뒤 버리는 임시 설명서."]},
	"cap5": {
		"nick": ["Royal Seal", "왕의 봉인"],
		"sci": ["5′ cap", "5′ 캡"],
		"what": ["A special cap on the front end. It proves the letter is genuine and shows the reader where to start.",
			"편지 앞쪽 끝의 특별한 모자. 진짜 편지임을 증명하고, 읽는 이에게 어디서 시작할지 알려 준다."]},
	"utr5": {
		"nick": ["Greeting", "인사말"],
		"sci": ["5′ UTR (5′ untranslated region)", "5′ UTR (5′ 비번역 부위)"],
		"what": ["A lead-in that is never built into protein. It helps the reader settle in and decides how eagerly the letter is read.",
			"단백질로 만들어지지 않는 머리말. 읽는 이가 자리를 잡게 돕고, 편지를 얼마나 열심히 읽을지 정한다."]},
	"start_codon": {
		"nick": ["BEGIN Mark", "‘시작’ 표시"],
		"sci": ["start codon (AUG)", "개시 코돈 (AUG)"],
		"what": ["The three letters AUG. Building starts here.",
			"세 글자 AUG. 여기서부터 만들기 시작한다."]},
	"orf": {
		"nick": ["Wanted Poster", "수배 전단"],
		"sci": ["antigen code (open reading frame, ORF)", "항원 암호 (열린 해독틀, ORF)"],
		"what": ["The real instructions: how to build one harmless piece of the cancer cell, so the body learns its face.",
			"진짜 설명서: 암세포의 해롭지 않은 조각 하나를 만드는 법. 몸이 적의 얼굴을 익히게 한다."]},
	"stop_codon": {
		"nick": ["THE END Mark", "‘끝’ 표시"],
		"sci": ["stop codon", "종결 코돈"],
		"what": ["Three letters (UAA, UAG or UGA) that mean: stop building here.",
			"‘여기서 그만 만들어라’라는 뜻의 세 글자 (UAA, UAG, UGA)."]},
	"utr3": {
		"nick": ["P.S. Note", "추신"],
		"sci": ["3′ UTR (3′ untranslated region)", "3′ UTR (3′ 비번역 부위)"],
		"what": ["A note after THE END. It is not built into protein, but it helps decide how long the letter lasts.",
			"‘끝’ 뒤에 붙은 메모. 단백질로 만들어지지 않지만, 편지가 얼마나 오래 버틸지 정하는 데 도움을 준다."]},
	"polya": {
		"nick": ["Fuse", "도화선"],
		"sci": ["poly(A) tail", "폴리(A) 꼬리"],
		"what": ["A long string of A letters (AAAA...). It burns shorter over time; when it is gone, the letter is destroyed.",
			"A 글자가 길게 이어진 줄 (AAAA...). 시간이 지나면 짧아지고, 다 닳으면 편지는 파괴된다."]},
	"rnase": {
		"nick": ["Shredder", "파쇄기"],
		"sci": ["RNase (RNA-cutting enzyme)", "RNase (RNA 분해효소)"],
		"what": ["Enzymes found almost everywhere, even on your skin. They cut up any RNA that has no protection.",
			"거의 모든 곳(심지어 피부 위)에 있는 효소. 보호막 없는 RNA를 잘게 자른다."]},
	# --- the bubble shield (LNP) ---
	"lnp": {
		"nick": ["Bubble Shield", "거품 방패"],
		"sci": ["lipid nanoparticle (LNP)", "지질 나노입자 (LNP)"],
		"what": ["A tiny ball of fat, about 80 nanometres wide (1,000 times thinner than a hair). It hides the mRNA and carries it into cells.",
			"지름 약 80나노미터(머리카락보다 1,000배 가는)의 작은 지방 공. mRNA를 숨겨서 세포 안으로 나른다."]},
	"mixer": {
		"nick": ["Bubble Maker", "거품 제조기"],
		"sci": ["microfluidic mixer", "미세유체 혼합기"],
		"what": ["A chip with hair-thin channels. A fat stream and an mRNA stream meet and fold into bubbles in a few thousandths of a second.",
			"머리카락처럼 가는 통로가 새겨진 칩. 지방 흐름과 mRNA 흐름이 만나 1,000분의 몇 초 만에 거품으로 접힌다."]},
	"ionizable": {
		"nick": ["Magnet Fat", "자석 지방"],
		"sci": ["ionizable lipid", "이온화 지질"],
		"what": ["A fat that turns positive only in acid. Then it grabs the negative mRNA, and later it helps tear the cell's bubble open.",
			"산성에서만 양전하를 띠는 지방. 그때 음전하인 mRNA를 붙잡고, 나중에는 세포 속 주머니를 찢는 것을 돕는다."]},
	"dspc": {
		"nick": ["Brick Fat", "벽돌 지방"],
		"sci": ["DSPC (helper phospholipid)", "DSPC (보조 인지질)"],
		"what": ["A fat shaped like a building block. It forms the wall of the bubble.",
			"벽돌처럼 생긴 지방. 거품의 벽을 쌓는다."]},
	"cholesterol": {
		"nick": ["Mortar", "시멘트"],
		"sci": ["cholesterol", "콜레스테롤"],
		"what": ["Fills the gaps between the bricks and makes the bubble wall sturdy.",
			"벽돌 사이 틈을 메워 거품 벽을 단단하게 한다."]},
	"peg": {
		"nick": ["Non-stick Coat", "미끄럼 코팅"],
		"sci": ["PEG-lipid", "PEG-지질"],
		"what": ["A slippery outer coat that stops the bubbles from clumping together.",
			"거품끼리 뭉치지 않게 하는 미끄러운 겉옷."]},
	# --- inside the cell ---
	"dc": {
		"nick": ["Scout Cell", "정찰병 세포"],
		"sci": ["dendritic cell", "수지상세포"],
		"what": ["An immune scout with long branching arms. It swallows things, checks them, and reports to the T-cells.",
			"긴 나뭇가지 팔을 가진 면역 정찰병. 무엇이든 삼켜 살펴보고 T세포에게 보고한다."]},
	"endosome": {
		"nick": ["Swallow Bubble", "삼킴 주머니"],
		"sci": ["endosome", "엔도솜"],
		"what": ["A pocket of membrane the cell pinches off when it swallows something. Inside, it slowly turns acidic.",
			"세포가 무언가를 삼킬 때 막을 오므려 만든 주머니. 안쪽이 점점 산성으로 변한다."]},
	"lysosome": {
		"nick": ["Digesting Sack", "소화 주머니"],
		"sci": ["lysosome", "리소좀"],
		"what": ["The cell's stomach. If it merges with the swallow bubble, everything inside is digested.",
			"세포의 위장. 삼킴 주머니와 합쳐지면 안에 든 것은 모두 소화된다."]},
	"deadenylase": {
		"nick": ["Fuse Nibbler", "도화선 갉개"],
		"sci": ["deadenylase", "탈아데닐화효소"],
		"what": ["Enzymes that nibble the poly(A) tail shorter, A by A.",
			"폴리(A) 꼬리를 A 하나씩 갉아 짧게 만드는 효소."]},
	"exonuclease": {
		"nick": ["Chewer", "씹개"],
		"sci": ["exonuclease", "엑소뉴클레아제"],
		"what": ["Enzymes that chew RNA from its ends, letter by letter.",
			"RNA를 끝에서부터 한 글자씩 씹어 먹는 효소."]},
	"ribosome": {
		"nick": ["Printing Press", "인쇄기"],
		"sci": ["ribosome", "리보솜"],
		"what": ["The cell's protein builder. It reads the letter and builds exactly what it describes.",
			"세포의 단백질 공장. 편지를 읽고 적힌 그대로 만든다."]},
	"codon": {
		"nick": ["Three-Letter Word", "세 글자 단어"],
		"sci": ["codon", "코돈"],
		"what": ["The letter is read three letters at a time. Each word calls for one amino acid, one bead in the protein chain.",
			"편지는 세 글자씩 읽힌다. 단어 하나가 아미노산 하나, 곧 단백질 사슬의 구슬 하나를 부른다."]},
	"antigen": {
		"nick": ["Enemy's Face", "적의 얼굴"],
		"sci": ["antigen", "항원"],
		"what": ["A recognisable piece of an invader or a cancer cell. The immune system learns to spot it.",
			"침입자나 암세포를 알아볼 수 있는 조각. 면역계는 이것을 알아보는 법을 배운다."]},
	"mhc": {
		"nick": ["Display Window", "진열창"],
		"sci": ["MHC (major histocompatibility complex)", "MHC (주조직적합복합체)"],
		"what": ["A holder on the cell surface that shows protein pieces to passing T-cells.",
			"세포 표면에서 단백질 조각을 지나가는 T세포에게 보여 주는 받침대."]},
	# --- the training camp (lymph node) ---
	"lymph_node": {
		"nick": ["Training Camp", "훈련소"],
		"sci": ["lymph node", "림프절"],
		"what": ["Bean-sized stations where scouts meet T-cells. The 'swollen glands' in your neck when you are sick are these.",
			"정찰병과 T세포가 만나는 콩알만 한 기지. 아플 때 목에서 붓는 ‘멍울’이 바로 이것이다."]},
	"chemokine": {
		"nick": ["Scent Trail", "냄새 길"],
		"sci": ["chemokine (CCL19)", "케모카인 (CCL19)"],
		"what": ["A chemical 'smell' that a place gives off to call immune cells toward it.",
			"면역세포를 불러들이려고 어떤 곳이 내뿜는 화학 ‘냄새’."]},
	"ccr7": {
		"nick": ["Sniffer Antenna", "냄새 더듬이"],
		"sci": ["CCR7 receptor", "CCR7 수용체"],
		"what": ["A sensor on the scout cell that picks up the scent trail to the lymph node.",
			"림프절로 가는 냄새 길을 맡는 정찰병 세포의 감지기."]},
	"tcell": {
		"nick": ["Knight", "기사"],
		"sci": ["T-cell", "T세포"],
		"what": ["White blood cells that each recognise one specific enemy face and attack it.",
			"저마다 딱 한 가지 적의 얼굴을 알아보고 공격하는 백혈구."]},
	"tcr": {
		"nick": ["Knight's Lock", "기사의 자물쇠"],
		"sci": ["T-cell receptor (TCR)", "T세포 수용체 (TCR)"],
		"what": ["Every T-cell has its own uniquely shaped lock. Only the matching enemy face fits it like a key.",
			"T세포마다 모양이 다른 자물쇠. 꼭 맞는 적의 얼굴만 열쇠처럼 들어맞는다."]},
	"three_signals": {
		"nick": ["Three Handshakes", "세 번의 악수"],
		"sci": ["T-cell activation signals 1, 2 and 3", "T세포 활성화 신호 1·2·3"],
		"what": ["To wake up, a T-cell needs (1) the lock to fit, (2) a second 'yes, this is real' touch, and (3) a chemical 'go!' message.",
			"T세포가 깨어나려면 (1) 자물쇠가 맞고, (2) ‘진짜다’라는 두 번째 접촉, (3) ‘출동!’이라는 화학 신호가 필요하다."]},
	"clonal": {
		"nick": ["Copy Army", "복제 군대"],
		"sci": ["clonal expansion", "클론 증식"],
		"what": ["The matching T-cell copies itself thousands of times. Every copy knows the same enemy face.",
			"꼭 맞는 T세포가 자신을 수천 번 복제한다. 복제된 세포 모두가 같은 적의 얼굴을 안다."]},
	# --- the tumor fortress ---
	"treg": {
		"nick": ["Peacekeepers", "평화유지군"],
		"sci": ["regulatory T-cells (Tregs)", "조절 T세포 (Treg)"],
		"what": ["T-cells that calm the immune system down. Tumors recruit them to switch attackers off.",
			"면역계를 진정시키는 T세포. 종양은 이들을 불러 공격하는 세포를 꺼 버린다."]},
	"caf": {
		"nick": ["Wall Builders", "성벽 일꾼"],
		"sci": ["cancer-associated fibroblasts (CAFs)", "암 관련 섬유아세포 (CAF)"],
		"what": ["Cells that build thick fibre walls (stroma) around a tumor to keep attackers out.",
			"종양 둘레에 두꺼운 섬유 벽(기질)을 쌓아 공격자를 막는 세포."]},
	"hypoxia": {
		"nick": ["Thin Air", "숨 막히는 곳"],
		"sci": ["hypoxia", "저산소증"],
		"what": ["Parts of a tumor with too little oxygen. Immune cells there grow weak.",
			"종양 속 산소가 모자란 곳. 그곳의 면역세포는 힘이 빠진다."]},
	"pdl1": {
		"nick": ["Fake Pass", "가짜 통행증"],
		"sci": ["PD-L1 (immune checkpoint)", "PD-L1 (면역관문)"],
		"what": ["A 'don't attack me' badge. Healthy cells use it honestly; tumors copy it to trick T-cells.",
			"‘나를 공격하지 마’ 배지. 건강한 세포는 정직하게 쓰지만, 종양은 흉내 내어 T세포를 속인다."]},
	"antibody": {
		"nick": ["Pass Blocker", "통행증 차단제"],
		"sci": ["checkpoint-inhibitor antibody (anti-PD-1)", "면역관문억제 항체 (항-PD-1)"],
		"what": ["Covers the T-cell's badge reader (PD-1) so the fake pass stops working. It is a real cancer medicine.",
			"T세포의 배지 판독기(PD-1)를 덮어 가짜 통행증이 통하지 않게 한다. 실제로 쓰이는 항암제다."]},
	"perforin": {
		"nick": ["Hole Punch and Poison", "구멍 뚫기와 독"],
		"sci": ["perforin and granzymes", "퍼포린과 그랜자임"],
		"what": ["Perforin punches holes in the target cell; granzymes slip in and switch on its self-destruct.",
			"퍼포린이 표적 세포에 구멍을 뚫고, 그랜자임이 들어가 자폭 스위치를 켠다."]},
	"apoptosis": {
		"nick": ["Self-Destruct", "자폭"],
		"sci": ["apoptosis", "세포자멸사"],
		"what": ["A tidy, programmed cell death. The cell packs itself up without harming its neighbours.",
			"깔끔하게 계획된 세포의 죽음. 이웃 세포를 해치지 않고 스스로 정리한다."]},
	"memory": {
		"nick": ["Veteran Knights", "노련한 기사"],
		"sci": ["memory T-cells", "기억 T세포"],
		"what": ["Long-lived T-cells that remember the enemy for years and strike fast if it returns.",
			"적을 수년 동안 기억하고, 다시 나타나면 재빨리 공격하는 오래 사는 T세포."]},
}

## Real-world connections shown at the bottom of the codex.
const REAL_WORLD := [
	["In 2020, mRNA vaccines against COVID-19 were built exactly like the letter in this game: seal, greeting, instructions, P.S., fuse, wrapped in a bubble shield.",
		"2020년 코로나19 mRNA 백신도 이 게임의 편지와 똑같이 만들어졌다. 봉인, 인사말, 설명서, 추신, 도화선을 거품 방패로 감쌌다."],
	["Katalin Karikó and Drew Weissman won the 2023 Nobel Prize in Physiology or Medicine for discovering how to tweak mRNA letters so the body does not reject the message.",
		"카탈린 커리코와 드루 와이스먼은 몸이 편지를 거부하지 않도록 mRNA 글자를 살짝 바꾸는 방법을 발견해 2023년 노벨 생리의학상을 받았다."],
	["Personalised mRNA cancer vaccines, like Mira's, are being tested in clinical trials, often together with Pass Blocker (anti-PD-1) medicines.",
		"미라가 받은 것 같은 맞춤형 mRNA 암 백신은 지금 임상시험 중이며, 흔히 통행증 차단제(항-PD-1) 약과 함께 쓰인다."],
]

static func _i(lang: String) -> int:
	return 1 if lang == "ko" else 0

static func has(id: String) -> bool:
	return WORDS.has(id)

static func nick(id: String, lang: String = "") -> String:
	var l := lang if lang != "" else GameState.lang
	return WORDS.get(id, {}).get("nick", [id, id])[_i(l)]

static func sci(id: String, lang: String = "") -> String:
	var l := lang if lang != "" else GameState.lang
	return WORDS.get(id, {}).get("sci", [id, id])[_i(l)]

static func what(id: String, lang: String = "") -> String:
	var l := lang if lang != "" else GameState.lang
	return WORDS.get(id, {}).get("what", ["", ""])[_i(l)]

## The Word Card text (English is the canonical dialogue text; see register_ko).
static func card_text(id: String, lang: String = "en") -> String:
	if lang == "ko":
		return "%s  =  %s\n%s" % [nick(id, "ko"), sci(id, "ko"), what(id, "ko")]
	return "%s  =  %s\n%s" % [nick(id, "en"), sci(id, "en"), what(id, "en")]

## A dialogue line that teaches one word: [speaker, text, word_id].
static func card(id: String) -> Array:
	return [SPEAKER, card_text(id, "en"), id]

static func learn(id: String) -> void:
	if WORDS.has(id) and not GameState.has_flag("word_" + id):
		GameState.set_flag("word_" + id)

static func knows(id: String) -> bool:
	return GameState.has_flag("word_" + id)

static func learned_count() -> int:
	var n := 0
	for id in WORDS.keys():
		if knows(id):
			n += 1
	return n

static func total() -> int:
	return WORDS.size()

## Korean card texts and speaker name, keyed exactly like the other dialogue
## lines (md5(speaker|english)[:12]), so the dialogue box and voice fallback
## translate cards with no extra code.
static func register_ko(ko_lines: Dictionary, ko_speakers: Dictionary) -> void:
	ko_speakers[SPEAKER] = SPEAKER_KO
	for id in WORDS.keys():
		ko_lines[GameState.line_id(SPEAKER, card_text(id, "en"))] = card_text(id, "ko")
