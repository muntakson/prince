# Prince of mRNA — 연출 대시보드

연출자가 노트북(듀얼 모니터)에서 큐시트를 보며 배경 투사, 음향효과, IoT 조명을 조작하는 로컬 웹앱.
Node.js + Express + WebSocket, 빌드 과정 없음. 포트 **8100**.

**공개 주소:** https://mrnaplay.aiedus.org (Cloudflare Full SSL → 이 서버 nginx → 8100). 이 서버에서는 `systemd`의 `mrnaplay.service`로 항상 떠 있다 (`sudo systemctl restart mrnaplay`).
nginx 설정: `/etc/nginx/sites-available/mrnaplay.aiedus.org`. DNS: Cloudflare aiedus.org 존의 A 레코드 `mrnaplay` → 121.180.148.105 (proxied).

```bash
cd /home/jit/mRNA/play/dashboard
npm install            # 처음 한 번 (express, ws)
npm start              # http://localhost:8100
PORT=8200 npm start    # 다른 포트
```

## 창 구성 (듀얼 모니터)

| 창 | 주소 | 모니터 | 용도 |
| --- | --- | --- | --- |
| 연출 대시보드 | `http://localhost:8100/` | 노트북 화면 | 큐시트, GO 버튼, 배경 Show, 음향 Play, 조명 ON/OFF, 스톱워치 |
| 무대 화면 | `http://localhost:8100/stage` | 빔 프로젝터 (HDMI) | 검은 바탕에 배경화면만 표시. 대시보드의 "무대 화면 열기"로 띄운 뒤 프로젝터 모니터로 옮기고 F11 |
| 설정 | `http://localhost:8100/settings` | 아무 곳 | 조명 4대의 IP·포트·HTTP 경로, 소리 재생 창, 배경 맞춤 |

여러 창은 WebSocket으로 같은 상태를 공유하므로 스마트폰이나 두 번째 노트북에서 `http://<노트북IP>:8100/`을 열어도 같은 큐 상태가 보인다 (조연출용).

## 큐시트와 GO

- 큐 표는 서버가 시작할 때 `play/큐시트.md`의 표를 읽어 만든다. 표를 고치면 서버를 다시 시작하거나 `curl -X POST localhost:8100/api/reload`.
- **GO** (또는 Space/Enter)는 다음 큐를 실행한다: 음향 칸의 `NN 정지`/`NN 페이드아웃`에 해당하는 소리를 멈추고, 배경 칸의 번호를 무대 화면에 띄우고(`1 → 2`처럼 전환 표시면 암전), 첫 번째 음향을 재생한다(`반복`이 있으면 루프).
- 표 안의 파란 배경 번호, 음향 버튼은 그것만 따로 실행한다. 7회 반복 같은 큐는 버튼을 그때그때 누른다.
- ↑/↓로 큐 포인터만 옮길 수 있고(실행 안 함), 행을 더블클릭하면 그 행이 "다음 큐"가 된다.
- 스톱워치는 현재 큐의 누적 시간보다 1분 이상 늦으면 빨강, 빠르면 초록으로 표시된다.

## AI 배우 (대본 낭독)

큐시트 아래의 "AI 배우 · 대본 낭독" 패널은 `play/희곡.md`의 대사 91줄을 장면별로 보여 준다. 음성은 `play/voice/<id>.mp3`
(id = md5("역할|대사")의 앞 12자리, `tools/play/gen_voice.py`로 생성). 대사를 고치면 그 줄의 id가 바뀌므로 생성 스크립트를 다시 돌린 뒤
`curl -X POST localhost:8100/api/reload` (또는 서비스 재시작).

- 줄의 ▶: 그 대사 하나만 재생. 장면 제목의 ▶ 또는 줄 더블클릭: 거기서부터 **자동 재생**.
- 자동 재생은 서버가 순서를 맡는다. 대사가 끝나면(재생 창이 보고) 0.6초 뒤 다음 줄로 가고, 지문(`>` 줄)을 만나면 그 안의
  `배경 N`/`암전`과 음향 `NN_이름`을 실행한 뒤 1~1.8초 쉬고 넘어간다. 그래서 대본만 자동 재생해도 배경·효과음이 같이 맞춰 돈다.
- ■ 정지, ⏮ 이전 줄, ⏭ 다음 줄, 단축키 N(다음 줄) / P(자동 재생·정지). "소리 전부 정지"(Esc)도 낭독을 멈춘다.
- 역할별 목소리: 해설 Jung, 아린 LEEHO, 미라 Anna Kim, 수지상세포 Seojin, 리보솜·혼합기 JI HOON, T세포 KKC RADIO (이상 한국어 보이스),
  암세포 Callum, TRIM25 Adam, 엑소뉴클레아제 Charlie (영어 보이스가 한국어를 읽어 약간 이국적인 악당 억양).

## 소리

브라우저는 사용자가 한 번 클릭하기 전에는 소리를 내지 않는다. 대시보드 창에서 아무 곳이나 한 번 클릭하면 "소리 켜짐" 배지가 초록이 된다.
설정에서 재생 창을 **무대 화면**으로 바꾸면 프로젝터 HDMI 오디오로 나간다 (그 창도 한 번 클릭해야 한다).

## IoT 조명

서버가 `http://IP:포트/경로`로 HTTP 요청을 보낸다 (3초 타임아웃). 노트북과 조명이 같은 Wi-Fi에 있어야 한다.
예시 경로: Shelly `/relay/0?turn=on`, Tasmota `/cm?cmnd=Power%20On`, 직접 만든 ESP8266 `/on`. POST/PUT이면 JSON 본문도 넣을 수 있다.
설정 페이지의 ON/OFF 테스트 버튼이 응답 코드와 본문 앞부분을 보여 준다. 설정은 `config.json`에 저장된다.

## API (다른 장치에서 쓰고 싶을 때)

`POST /api/cue {index}` · `POST /api/show {backdrop: "02"|"black"}` · `POST /api/sound {action: play|stop|stopAll, id, loop}` ·
`POST /api/lights/:id {on}` · `POST /api/lights {on}` · `POST /api/stopwatch {action: start|pause|reset}` · `GET /api/catalog`
