# Prince of mRNA (mRNA 왕자)

*[English README](README.md)*

mRNA 백신 과학을 가르치는 스토리 기반 교육용 게임입니다 (Godot 4.3).
아린 왕자가 미라 공주를 구한 뒤, 분자 왕국을 여행하며 mRNA 항암 백신을
만들고, 보호하고, 전달하고, 번역합니다.

**플레이:** https://prince.aiedus.org (웹 빌드, https://prince.iotok.org 에서도 가능)

지원 플랫폼: **데스크톱, 웹(HTML5), 안드로이드** (세로 화면, 터치 + 키보드).
언어: **English / 한국어** (`F3` 또는 타이틀 화면 버튼으로 전환).

제작 : 손문탁 박사, 사단법인 나눔과기술, 2026년 9월 19일

---

## 여정 (6개 챕터)

각 챕터는 `scripts/world/` 의 `LevelBase` 를 상속한 장면입니다. 과학 단계는
미니게임(`scripts/minigames/`) 또는 애니메이션 컷신 스테이션으로 진행됩니다.

1. **동굴** — 튜토리얼: 걷기, 달리기, 틈새 뛰어넘기, 미라의 방에 도달.
2. **궁전** — 미라를 찾고 mRNA 두루마리를 읽음 (퀘스트 시작).
3. **실험실** — mRNA 구성 요소 7가지(5' 캡, 5' UTR, 신호 펩타이드, 항원,
   3' UTR, 폴리(A) 꼬리, 변형 뉴클레오사이드)를 모아 합성기에서 조립
   (`AssembleMRNA` 드래그 퍼즐)한 뒤, `MicrofluidicMixer` 미니게임으로
   mRNA 를 캡슐화합니다: 지질 / mRNA 를 에탄올과 pH 4 완충액 입구에 넣고,
   유량비 3:1 과 빠른 총 유량을 맞추면 헤링본 채널에서 LNP 가 만들어집니다
   (크기 / PDI / 봉입률 표시). 마지막으로 완충액을 pH 7.4 로 교환합니다.
   LNP 가 완성되기 전까지는 RNase 가 맨 mRNA 를 쫓아옵니다.
4. **바이오월드 (세포 안)** — 수지상세포의 LNP 흡수, 엔도솜 탈출
   (`EndosomeTiming`: 이온화 지질이 전하를 띠는 동안, 리소좀이 융합하기 전에
   탈출), 엑소뉴클레이스를 피해 리보솜까지 달리는 폴리(A) 질주, 번역과
   MHC 항원 제시 (애니메이션 `CutsceneStation`).
5. **림프절** — `ChemokineNav` (CCR7 안테나로 CCL19 농도 기울기를 따라
   수지상세포를 림프관까지 안내) 와 `TCellChamber` (순진 T세포의 TCR 을
   항원과 대조, 신호 1/2/3 과 LFA-1 / ICAM-1 고리로 이루어진 면역 시냅스,
   활성화, 클론 증식).
6. **종양** — `TCellHerd` (조절 T세포, CAF 콜라겐 기질, 저산소 지역을 지나
   T세포 군단을 이끌기) 와 `TumorHunt` (킬러 T세포를 조종해 각 세포의 MHC-I
   펩타이드를 읽고, 퍼포린 / 그랜자임 B 로 종양 세포를 제거하고, 정상 세포는
   살려두며, 계속 분열하는 종양 속에서 항 PD-1 항체로 PD-L1 을 무력화).
   그리고 미라의 결말.

## 조작법

- **이동:** WASD / 방향키, 또는 화면 조이스틱(터치). 한 방향을 계속 누르면
  달리기로 바뀌고, 달리다 손을 떼면 미끄러지며 멈춥니다.
- **상호작용 / 대화 넘기기:** `E` 또는 ✋ 버튼 (`Space` 로도 대화를 넘길 수 있음).
- **점프 / 도약:** `Space` (`Shift` / `J` 도 가능) 또는 JUMP 버튼. 달리는 중에
  점프하면 멀리 도약합니다. 구덩이 가장자리로 걸어가면 난간을 붙잡습니다:
  반대 방향을 밀거나 점프하면 올라오고, 안쪽으로 밀면 놓습니다. 공중에 있는
  동안에는 바닥의 위험 요소가 왕자를 건드리지 못합니다.
- **일시정지:** `Esc` 또는 `II` 버튼 (계속 / 저장 / 도움말 / 음성 / 메인 메뉴).
- **도움말:** 전체 여정을 단계별로 설명하는 안내서 (English / 한국어, 복사 버튼
  포함). 내용: `assets/help/help.json`.
- **힌트:** 미니게임 안에서 `F1` / `H` 를 누르면 과학 힌트 패널이 열립니다
  (`assets/help/*_clues.json`).
- **음성:** `V` 로 음성 모드를 켜고 끕니다. 모든 대사에 녹음된 음성 클립이
  있으며 (`assets/voice/`, ElevenLabs TTS, 캐릭터마다 다른 목소리), 클립이
  없으면 브라우저 / OS 음성 합성이 읽어 줍니다. 효과음은 `assets/audio/` 에
  있습니다. 설정은 `user://settings.cfg` 에 저장됩니다.
- **언어:** `F3` 으로 영어 / 한국어를 전환합니다. UI 문자열은
  `assets/help/ui_ko.json` (TranslationServer 에 로드), 대사는
  `assets/help/dialogue_ko.json` 에서 옵니다.

## 위험 요소

궁전 이후의 모든 챕터에는 메시지를 노리는 무언가가 있습니다. 위험한 동안에는
HUD 에 게이지(mRNA 온전성 / 폴리(A) 꼬리)가 표시되고, 게이지가 바닥나면 왕자는
새 사본을 들고 마지막 안전 지점으로 돌아갑니다.

| 챕터 | 위험 | 과학 | 살아남는 법 |
|---|---|---|---|
| 1 동굴 | 틈새 | (튜토리얼) | 달리다가 Space / JUMP 로 뛰어넘기 |
| 3 실험실 | 조립 후 맨 mRNA 를 쫓는 RNase | RNase 는 보호되지 않은 RNA 를 분해하고, LNP 가 이를 막아 줌 | 뛰어넘어 믹서까지 가기. LNP 를 만든 뒤에는 튕겨 나감 |
| 4 세포 | 조직 속 RNase | 지질 껍질이 RNase 를 밀어냄 | 할 일 없음. 튕겨 나가는 모습을 지켜보기 |
| 4 세포 | 엔도솜 pH 타이밍 (미니게임) | 이온화 지질(pKa ~6.4)은 pH 6.6 아래에서 전하를 띠고, pH 5 아래에서는 리소좀이 융합 | pH 창 안에서 탈출 |
| 4 세포 | 폴리(A) 질주 + 엑소뉴클레이스 | 탈아데닐화로 꼬리가 짧아지고, 꼬리가 사라지면 캡이 제거되어 mRNA 가 파괴됨 | 꼬리 게이지가 비기 전에 리보솜에 도달, 엑소뉴클레이스는 뛰어넘기 |
| 6 종양 | T세포 군단 이끌기 (미니게임) | 조절 T세포(IL-10 / TGF-β), CAF 콜라겐 기질, 저산소 | 군단을 가까이 유지, 보라색 안개 피하기, 틈 찾기, 억제된 세포 다시 일으키기 |

## 프로젝트 구조

- `autoload/` — 싱글톤: `GameState` (플래그, 챕터, 언어), `Inventory`,
  `SaveManager` (`user://savegame.json`, 웹 / 안드로이드에서도 동작),
  `DialogueManager`, `AudioManager` (음악, 효과음, 음성, 설정),
  `SceneManager` (페이드 전환 + 스폰), `DebugConsole`.
- `scripts/player/Player.gd` — 명시적 상태 기계
  (IDLE / WALK / RUN / JUMP / LEAP / FALL / LEDGE_GRAB / HURT). 키보드와
  터치가 같은 입력 액션을 사용합니다.
- `scripts/ui/` — HUD (인벤토리 바, 타자기 효과 대화 상자, 챕터 타이틀 카드,
  가상 조이스틱, 버튼, 일시정지 메뉴), 타이틀 화면, 도움말 화면, 힌트 패널.
- `scripts/world/`, `scripts/minigames/` — 챕터, 스테이션, 미니게임.
- `assets/` — 분자 스프라이트, 배경 아트, 컷신 프레임, 효과음, 음성,
  도움말 / 힌트 / 번역 JSON, 번들 폰트 `assets/fonts/help_ko.otf`
  (Noto Sans CJK KR 서브셋, OFL. 시스템 폰트 대체가 없는 웹에서도 한글이
  보이도록 기본 테마 폰트로 사용).
- `tools/` — `subset_font.py` (게임 안의 모든 문자열로 폰트 서브셋을 다시
  생성. 한국어 텍스트를 바꾼 뒤 실행), `ShotRunner.tscn` (헤드리스 스크린샷과
  미니게임 자동 실행), `audio/` (음성 / 효과음 생성기).

## 실행 / 빌드

```bash
GODOT=/home/jit/bin/godot                       # Godot 4.3 (헤드리스 지원)

# 받은 뒤 에셋 임포트
$GODOT --headless --path . --import

# 실행 (데스크톱)
$GODOT --path .

# 웹 빌드 내보내기 -> build/web/index.html
$GODOT --headless --path . --export-release "Web" build/web/index.html

# 내보내기 + 콘텐츠 해시 파일명으로 /var/www/prince 에 배포 (DEPLOY.md 참고)
./deploy.sh            # 에셋을 추가했다면 --import 를 붙임

# 한국어 텍스트를 수정한 뒤 폰트 서브셋 재생성
python3 tools/subset_font.py

# 임의 장면의 헤드리스 스크린샷 (xvfb 사용)
xvfb-run -a env LIBGL_ALWAYS_SOFTWARE=1 $GODOT --path . tools/ShotRunner.tscn \
  --resolution 720x1280 --rendering-driver opengl3 \
  -- scene=res://scenes/world/Cave.tscn out=/tmp/shot.png wait=100
# FORCE_TOUCH=1 을 붙이면 화면 터치 컨트롤이 함께 찍힘
```

안드로이드 내보내기에는 Godot 안드로이드 빌드 템플릿과 SDK 설정이 필요합니다.
프리셋("Android", `org.aiedus.princeofmrna`, 세로)은 `export_presets.cfg` 에
이미 들어 있습니다.

## 디버깅과 테스트

- 타이틀 화면의 **Chapter Select** 는 필요한 스토리 플래그를 미리 부여한 채
  어느 챕터로든 바로 이동합니다.
- 웹 URL 매개변수: `?chapter=<id>` 는 해당 챕터를 바로 시작, `?flags=a,b` 는
  추가 스토리 플래그 부여, `?debug` 는 디버그 콘솔 활성화 (`DBG` 버튼 / `F4`
  로 오버레이 표시. 데스크톱에서는 `--debug-console` 인자).
- 웹 빌드는 몇 프레임마다 실시간 상태(프레임, 일시정지, 대화, 플레이어 위치,
  진행 중인 미니게임, 플래그, 오디오)를 `window.__ss` 에 복사하므로
  (`autoload/DebugConsole.gd`), Playwright 테스트가 타이머 대신 이 값을
  폴링할 수 있습니다.

nginx / Cloudflare 설정, 해시 파일 배포, 로딩 스플래시에 대한 내용은
`DEPLOY.md` 를 참고하세요.
