# Classroom server API

A tiny Node server (`classroom/server.js`, no dependencies) that powers the class
competition: student logins, live scores, and every student's Mira status.
It serves the web pages in `classroom/public/` under `/class/` and the JSON API under `/api/`.
All bodies are JSON. Times are milliseconds since the epoch.

## Teacher endpoints

Send the teacher password in the header `X-Teacher-Key`.

| Method | Path | Body | Returns |
|---|---|---|---|
| GET | `/api/teacher/check` | | `{ok: true}` or 401 |
| GET | `/api/classes` | | `{classes: [{code, name, students: n}]}` |
| POST | `/api/classes` | `{code, name}` | `{code, name}`. The code is uppercased; letters, digits and `-` only, 2–16 chars. |
| DELETE | `/api/classes/:code` | | `{ok: true}` |
| GET | `/api/classes/:code/roster` | | `{code, name, students: [{no, name, pin}]}`. PINs are shown so the teacher can print login cards. |
| POST | `/api/classes/:code/students` | `{names: ["Kim Minji", ...]}` | `{added: [{no, name, pin}]}`. Numbers continue from the last one (`1`, `2`, ...). PIN = 4 random digits. |
| POST | `/api/classes/:code/students/:no/pin` | | `{no, pin}`: a new PIN; old logins on that student stop working. |
| DELETE | `/api/classes/:code/students/:no` | | `{ok: true}` |
| POST | `/api/classes/:code/reset` | | `{ok: true}`: clears every student's progress (new round); logins stay. |

## Student endpoints (used by the game)

| Method | Path | Body | Returns |
|---|---|---|---|
| POST | `/api/login` | `{class, no, pin}` | `{token, name, no, class, className}` or 401 `{error}` |
| POST | `/api/events` | `{token, events: [Event]}` | `{ok: true, score}` or 401 |

`Event` objects (`t` = client time, optional):
- `{type: "flag", name, value}`: a story flag was set (milestones, `word_<id>`, `quizstars_<chapter>` with an integer value).
- `{type: "chapter", id}`: entered a chapter.
- `{type: "defeat"}`: lost the letter (RNase / exonuclease) and respawned.
- `{type: "mg_fail", station}`: closed a mini-game without success.
- `{type: "tumor", left, kills}`: live tumor-hunt state (sent whenever it changes).
- `{type: "ping"}`: heartbeat every ~15 s while the game is open.

The server keeps the best-ever state (union of milestones and words, max quiz stars),
so starting a New Game never loses points and repeating content never adds points.

## Public board endpoints (no key; the class code is enough)

| Method | Path | Returns |
|---|---|---|
| GET | `/api/classes/:code/board` | `Board` |
| GET | `/api/classes/:code/stream` | Server-Sent Events: an `event: board` with a `Board` JSON whenever anything changes (at most twice a second), and a comment ping every 20 s. |

```
Board = {
  code, name, now,
  milestones: ["met_mira", "quest_started", "mrna_assembled", "lnp_made", "lnp_uptake_done",
               "endosome_escape_done", "translation_done", "antigen_presented", "dc_migrated",
               "tcell_activated", "tcells_herded", "tumor_cleared", "story_complete"],
  students: [Student]          // sorted by score, highest first
}
Student = {
  no, name, rank,
  score, breakdown: {milestones, words, stars, kills, setbacks, speed},
  progress,                    // 0..13 milestones reached
  stage,                       // key of the latest milestone reached, or "not_started"
  chapter,                     // current chapter id ("cave", "palace", "laboratory", "bioworld", "lymph", "tumor") or ""
  words, stars,                // counts (max 39 words, 12 stars)
  defeats, fails, kills,
  online,                      // true if a ping/event arrived in the last 40 s
  startedAt, finishedAt,       // null until set
  minutes,                     // active play time in minutes (only while the game is open;
                               // gaps over 60 s, e.g. between lessons, do not count)
  mira: {
    tumor,                     // tumor size, % of diagnosis size: starts 100, grows +0.5 per minute
                               // of active play (cap 160) until the Knights arrive (tcells_herded), then shrinks
                               // with tumor cells killed, 0 when tumor_cleared
    strength,                  // Mira's strength 0..100 = clamp(100 - tumor * 0.55, 5, 100)
    immune,                    // immune readiness 0..100 from milestones 3..11
    phase                      // "waiting" | "growing" | "vaccine" | "training" | "attacking" | "remission"
  }
}
```

## Scoring

| Item | Points |
|---|---|
| Each story milestone reached (13) | +100 |
| Each Science Word earned (39) | +10 |
| Each Gate Quiz star (12) | +100 |
| Each tumor cell killed | +25 |
| Each lost letter (defeat) | −25 |
| Each failed mini-game | −15 |
| Speed bonus when the story is complete | max(0, 1000 − 10 × minutes of active play) |

## Running

```bash
TEACHER_PASSWORD=choose-one PORT=8110 node classroom/server.js
```
Data is stored in `classroom/data/classroom.json` (created on first run, not in git).
