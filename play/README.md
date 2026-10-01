# Prince of mRNA — 연극 자료 (30분, 고등학생용)

- `희곡.md` — 7장 대본 (등장인물, 소품, 지문, 대사)
- `큐시트.md` — 42개 큐 (시간, 배경, 조명, 음향, 동선)
- `backdrops/` — 1.2 m × 2.4 m 세로 배경화면 6장, 672×1344 px (`tools/play/gen_backdrops.py`, Gemini 2.5 Flash Image; 사실적 생의학 애니메이션 풍, `play/images/`의 참고 그림을 스타일 레퍼런스로 전달; 첫 번째 페르시아풍 시안은 `backdrops/old_persian/`)
- `dashboard/` — 연출 대시보드 웹앱 (Node, 포트 8100: 큐시트·배경 투사·음향·IoT 조명). 사용법은 `dashboard/README.md`
- `voice/` — AI 배우 음성 91개 (`tools/play/gen_voice.py`, ElevenLabs multilingual v2, 한국어; 역할별 목소리 매핑은 스크립트 안의 VOICES)
- `sfx/` — 음향효과 36개 (`tools/play/gen_sfx.py`, ElevenLabs sound generation + 게임 효과음 7개 재사용)

```bash
cd /home/jit/mRNA
GEMINI_API_KEY=<key> python3 tools/play/gen_backdrops.py        # -> play/backdrops/*.png
EL=<key>             python3 tools/play/gen_sfx.py              # -> play/sfx/*.mp3
EL=<key>             python3 tools/play/gen_voice.py            # -> play/voice/*.mp3 + manifest.json (대본의 모든 대사)
# 고해상도 인쇄용:
GEMINI_API_KEY=<key> GEMINI_MODEL=gemini-3-pro-image-preview GEMINI_IMAGE_SIZE=4K python3 tools/play/gen_backdrops.py
```

편집 가능한 문서: https://claude.ai/code/artifact/19303375-89b6-478c-94b3-1da8e8a12652
