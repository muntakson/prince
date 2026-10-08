/* Prince of mRNA: shared helpers for the classroom pages.
 * - App.esc: HTML escaping (student names are user content)
 * - App.t / language toggle (EN / KO, remembered in localStorage)
 * - App.connectBoard: SSE with auto-reconnect + fallback polling every 3 s
 * - ?demo=1: a fake, self-advancing Board (and a fake teacher API) for testing without the server
 */
(function () {
  "use strict";

  var App = {};
  window.App = App;

  // ---------------------------------------------------------------- basics

  App.esc = function (s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
  };

  var params = new URLSearchParams(location.search);
  App.param = function (k) { return params.get(k); };
  App.demo = params.get("demo") === "1";
  App.code = (params.get("c") || "").trim().toUpperCase().replace(/[^A-Z0-9-]/g, "").slice(0, 16);

  /** Build a link to one of the pages, keeping demo mode. */
  App.link = function (page, code) {
    var q = [];
    if (code) q.push("c=" + encodeURIComponent(code));
    if (App.demo) q.push("demo=1");
    return page + (q.length ? "?" + q.join("&") : "");
  };

  App.store = {
    get: function (k, d) { try { var v = localStorage.getItem(k); return v == null ? d : v; } catch (e) { return d; } },
    set: function (k, v) { try { localStorage.setItem(k, v); } catch (e) { /* ignore */ } }
  };
  App.session = {
    get: function (k) { try { return sessionStorage.getItem(k); } catch (e) { return null; } },
    set: function (k, v) { try { sessionStorage.setItem(k, v); } catch (e) { /* ignore */ } },
    del: function (k) { try { sessionStorage.removeItem(k); } catch (e) { /* ignore */ } }
  };

  App.reducedMotion = function () {
    return window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  };

  // ---------------------------------------------------------------- i18n

  App.MILESTONES = ["met_mira", "quest_started", "mrna_assembled", "lnp_made", "lnp_uptake_done",
    "endosome_escape_done", "translation_done", "antigen_presented", "dc_migrated",
    "tcell_activated", "tcells_herded", "tumor_cleared", "story_complete"];

  var T = {
    en: {
      lang_switch: "한국어",
      game: "Prince of mRNA",
      class_competition: "Class Competition",
      // stages
      stage_not_started: "Not started",
      stage_met_mira: "Met Mira",
      stage_quest_started: "Quest begun",
      stage_mrna_assembled: "Royal Letter written",
      stage_lnp_made: "Vaccine ready",
      stage_lnp_uptake_done: "Vaccine delivered",
      stage_endosome_escape_done: "Escaped the bubble",
      stage_translation_done: "Enemy's Face built",
      stage_antigen_presented: "Face on display",
      stage_dc_migrated: "Scout at Training Camp",
      stage_tcell_activated: "Knights trained",
      stage_tcells_herded: "Knights reach the tumor",
      stage_tumor_cleared: "Tumor destroyed",
      stage_story_complete: "Mira is well",
      // live
      live_live: "Live",
      live_polling: "Live (slow link)",
      live_reconnecting: "Reconnecting…",
      live_notfound: "Class not found",
      live_connecting: "Connecting…",
      playing_now: "playing now",
      // scoreboard
      scoreboard: "Scoreboard",
      col_rank: "Rank",
      col_name: "Student",
      col_progress: "Quest progress",
      col_stars: "Stars",
      col_words: "Words",
      col_time: "Time",
      col_score: "Score",
      step_of: "{n}/13",
      online: "Playing now",
      offline: "Not playing",
      empty_title: "No students yet",
      empty_body: "The teacher can add students on the teacher page.",
      notfound_title: "Class not found",
      notfound_body: "Check the class code: {code}",
      nocode_title: "No class code",
      nocode_body: "Open this page from the start page and enter a class code.",
      mins: "{m} min",
      hours: "{h} h {m} min",
      to_mira: "Mira's Status Board",
      to_board: "Scoreboard",
      to_start: "Start page",
      // mira board
      mira_board: "Mira's Status Board",
      miras_of: "{name}'s Mira",
      tumor_size: "Tumor size",
      strength: "Mira's strength",
      immune: "Immune readiness",
      phase_waiting: "Waiting",
      phase_growing: "Tumor growing",
      phase_vaccine: "Vaccine on its way",
      phase_training: "Knights training",
      phase_attacking: "Knights attacking",
      phase_remission: "Remission",
      sort_by: "Sort",
      sort_no: "Student no.",
      sort_health: "Mira's health",
      trend_up: "Tumor grew",
      trend_down: "Tumor shrank",
      not_playing: "Not playing now",
      tumor_cells: "{n} tumor cells defeated",
      // landing
      landing_title: "Class Competition",
      landing_lede: "Enter your class code to open the live boards.",
      class_code: "Class code",
      code_ph: "e.g. 2A",
      open_board: "Scoreboard",
      open_board_sub: "Ranks, quest progress and scores",
      open_mira: "Mira's Status Board",
      open_mira_sub: "Every student's Mira, live",
      teacher_page: "Teacher page",
      // teacher
      teacher: "Teacher",
      teacher_title: "Teacher Tools",
      password: "Teacher password",
      sign_in: "Sign in",
      sign_out: "Sign out",
      bad_password: "That password did not work.",
      server_error: "The server did not answer. Is it running?",
      classes: "Classes",
      new_class: "New class",
      code: "Code",
      class_name: "Class name",
      class_name_ph: "e.g. Grade 10 Biology A",
      code_ph2: "e.g. 10A",
      create: "Create class",
      code_rule: "Letters, numbers and - only, 2 to 16 characters.",
      students_n: "{n} students",
      open: "Open",
      del: "Delete",
      sure_delete_class: "Delete this class and all its students?",
      yes_delete: "Yes, delete",
      cancel: "Cancel",
      no_classes: "No classes yet. Create one above.",
      add_students: "Add students",
      add_students_hint: "Paste names, one per line. Numbers continue from the last student.",
      add: "Add students",
      added_n: "Added {n} students.",
      roster: "Students",
      col_no: "No.",
      col_pin: "PIN",
      col_actions: "",
      new_pin: "New PIN",
      remove: "Remove",
      sure_new_pin: "Make a new PIN? The old one stops working.",
      yes_new_pin: "Yes, new PIN",
      sure_remove: "Remove this student?",
      yes_remove: "Yes, remove",
      no_students: "No students yet. Paste names above.",
      reset_round: "Reset all progress (new round)",
      sure_reset: "Clear every student's progress and score? Logins stay the same.",
      yes_reset: "Yes, reset everything",
      reset_done: "All progress was cleared. A new round can start.",
      print_cards: "Print login cards",
      print: "Print",
      back: "Back",
      print_hint: "8 cards fit on one A4 page. Cut along the dashed lines.",
      card_help: "Open the game, choose Class Login, enter these.",
      card_class: "Class",
      card_no: "No.",
      card_pin: "PIN",
      boards: "Live boards",
      demo_note: "Demo mode: fake data, nothing is saved. Password: demo"
    },
    ko: {
      lang_switch: "English",
      game: "Prince of mRNA",
      class_competition: "우리 반 대회",
      stage_not_started: "시작 전",
      stage_met_mira: "미라를 만남",
      stage_quest_started: "모험 시작",
      stage_mrna_assembled: "왕의 편지 완성",
      stage_lnp_made: "백신 준비",
      stage_lnp_uptake_done: "백신 전달",
      stage_endosome_escape_done: "주머니 탈출",
      stage_translation_done: "적의 얼굴 완성",
      stage_antigen_presented: "얼굴 진열",
      stage_dc_migrated: "정찰병 훈련소 도착",
      stage_tcell_activated: "기사 훈련 완료",
      stage_tcells_herded: "기사 종양 도착",
      stage_tumor_cleared: "종양 파괴",
      stage_story_complete: "미라 회복",
      live_live: "실시간",
      live_polling: "실시간 (느린 연결)",
      live_reconnecting: "다시 연결하는 중…",
      live_notfound: "반을 찾을 수 없어요",
      live_connecting: "연결하는 중…",
      playing_now: "명 지금 플레이 중",
      scoreboard: "점수판",
      col_rank: "순위",
      col_name: "학생",
      col_progress: "모험 진행",
      col_stars: "별",
      col_words: "단어",
      col_time: "시간",
      col_score: "점수",
      step_of: "{n}/13",
      online: "지금 플레이 중",
      offline: "쉬는 중",
      empty_title: "아직 학생이 없어요",
      empty_body: "선생님 페이지에서 학생을 추가할 수 있어요.",
      notfound_title: "반을 찾을 수 없어요",
      notfound_body: "반 코드를 확인해 주세요: {code}",
      nocode_title: "반 코드가 없어요",
      nocode_body: "시작 페이지에서 반 코드를 입력해 주세요.",
      mins: "{m}분",
      hours: "{h}시간 {m}분",
      to_mira: "미라 상태판",
      to_board: "점수판",
      to_start: "시작 페이지",
      mira_board: "미라 상태판",
      miras_of: "{name}의 미라",
      tumor_size: "종양 크기",
      strength: "미라의 체력",
      immune: "면역 준비도",
      phase_waiting: "기다리는 중",
      phase_growing: "종양이 자라는 중",
      phase_vaccine: "백신이 가는 중",
      phase_training: "기사 훈련 중",
      phase_attacking: "기사 공격 중",
      phase_remission: "회복!",
      sort_by: "정렬",
      sort_no: "번호순",
      sort_health: "미라 건강순",
      trend_up: "종양이 커졌어요",
      trend_down: "종양이 작아졌어요",
      not_playing: "지금은 쉬는 중",
      tumor_cells: "종양 세포 {n}개 물리침",
      landing_title: "우리 반 대회",
      landing_lede: "반 코드를 넣으면 실시간 화면이 열려요.",
      class_code: "반 코드",
      code_ph: "예: 2A",
      open_board: "점수판",
      open_board_sub: "순위, 모험 진행, 점수",
      open_mira: "미라 상태판",
      open_mira_sub: "모든 학생의 미라를 실시간으로",
      teacher_page: "선생님 페이지",
      teacher: "선생님",
      teacher_title: "선생님 도구",
      password: "선생님 비밀번호",
      sign_in: "들어가기",
      sign_out: "나가기",
      bad_password: "비밀번호가 맞지 않아요.",
      server_error: "서버가 대답하지 않아요. 서버가 켜져 있나요?",
      classes: "반 목록",
      new_class: "새 반 만들기",
      code: "코드",
      class_name: "반 이름",
      class_name_ph: "예: 1학년 2반 생명과학",
      code_ph2: "예: 1-2",
      create: "반 만들기",
      code_rule: "영문, 숫자, - 만 쓸 수 있어요 (2~16자).",
      students_n: "학생 {n}명",
      open: "열기",
      del: "삭제",
      sure_delete_class: "이 반과 학생을 모두 지울까요?",
      yes_delete: "네, 지울게요",
      cancel: "취소",
      no_classes: "아직 반이 없어요. 위에서 만들어 주세요.",
      add_students: "학생 추가",
      add_students_hint: "이름을 한 줄에 하나씩 붙여 넣으세요. 번호는 마지막 학생 다음부터 이어져요.",
      add: "학생 추가",
      added_n: "학생 {n}명을 추가했어요.",
      roster: "학생 명단",
      col_no: "번호",
      col_pin: "PIN",
      col_actions: "",
      new_pin: "새 PIN",
      remove: "빼기",
      sure_new_pin: "새 PIN을 만들까요? 예전 PIN은 더 이상 안 돼요.",
      yes_new_pin: "네, 새로 만들게요",
      sure_remove: "이 학생을 명단에서 뺄까요?",
      yes_remove: "네, 뺄게요",
      no_students: "아직 학생이 없어요. 위에 이름을 붙여 넣으세요.",
      reset_round: "모든 기록 초기화 (새 라운드)",
      sure_reset: "모든 학생의 진행과 점수를 지울까요? 로그인 정보는 그대로예요.",
      yes_reset: "네, 모두 초기화",
      reset_done: "모든 기록을 지웠어요. 새 라운드를 시작할 수 있어요.",
      print_cards: "로그인 카드 인쇄",
      print: "인쇄",
      back: "돌아가기",
      print_hint: "A4 한 장에 카드 8장이 들어가요. 점선을 따라 자르세요.",
      card_help: "게임을 열고 '반 로그인'을 고른 다음 아래 정보를 넣으세요.",
      card_class: "반",
      card_no: "번호",
      card_pin: "PIN",
      boards: "실시간 화면",
      demo_note: "데모 모드: 가짜 데이터예요. 저장되지 않아요. 비밀번호: demo"
    }
  };

  function detectLang() {
    var saved = App.store.get("pom.lang", "");
    if (saved === "en" || saved === "ko") return saved;
    var nav = (navigator.language || "en").toLowerCase();
    return nav.indexOf("ko") === 0 ? "ko" : "en";
  }

  App.lang = detectLang();
  var langListeners = [];

  App.t = function (key, vars) {
    var s = (T[App.lang] && T[App.lang][key]);
    if (s == null) s = T.en[key];
    if (s == null) s = key;
    if (vars) s = s.replace(/\{(\w+)\}/g, function (m, k) { return vars[k] != null ? vars[k] : m; });
    return s;
  };

  App.stageLabel = function (key) { return App.t("stage_" + (key || "not_started")); };

  /** Fill [data-i18n], [data-i18n-ph], [data-i18n-title], [data-i18n-aria] in the document. */
  App.applyI18n = function (root) {
    root = root || document;
    document.documentElement.lang = App.lang;
    root.querySelectorAll("[data-i18n]").forEach(function (el) { el.textContent = App.t(el.getAttribute("data-i18n")); });
    root.querySelectorAll("[data-i18n-ph]").forEach(function (el) { el.placeholder = App.t(el.getAttribute("data-i18n-ph")); });
    root.querySelectorAll("[data-i18n-title]").forEach(function (el) { el.title = App.t(el.getAttribute("data-i18n-title")); });
    root.querySelectorAll("[data-i18n-aria]").forEach(function (el) { el.setAttribute("aria-label", App.t(el.getAttribute("data-i18n-aria"))); });
    root.querySelectorAll("[data-lang-toggle]").forEach(function (el) {
      el.textContent = App.t("lang_switch");
      el.setAttribute("lang", App.lang === "en" ? "ko" : "en");
    });
  };

  App.setLang = function (lang) {
    App.lang = lang === "ko" ? "ko" : "en";
    App.store.set("pom.lang", App.lang);
    App.applyI18n();
    langListeners.forEach(function (fn) { try { fn(App.lang); } catch (e) { console.error(e); } });
  };
  App.onLang = function (fn) { langListeners.push(fn); };

  document.addEventListener("click", function (ev) {
    var b = ev.target.closest && ev.target.closest("[data-lang-toggle]");
    if (b) { ev.preventDefault(); App.setLang(App.lang === "en" ? "ko" : "en"); }
  });

  // ---------------------------------------------------------------- formatting

  App.minutesPlayed = function (s, now) {
    // `minutes` = active play time from the server (only counted while the game is open)
    if (typeof s.minutes === "number") return s.startedAt || s.minutes > 0 ? Math.floor(s.minutes) : null;
    if (!s.startedAt) return null;
    var end = s.finishedAt || now || Date.now();
    return Math.max(0, Math.floor((end - s.startedAt) / 60000));
  };
  App.fmtMinutes = function (m) {
    if (m == null) return "–";
    if (m < 60) return App.t("mins", { m: m });
    var h = Math.floor(m / 60), mm = m % 60;
    return App.t("hours", { h: h, m: (mm < 10 ? "0" : "") + mm });
  };
  App.fmtNum = function (n) {
    return Math.round(n || 0).toLocaleString(App.lang === "ko" ? "ko-KR" : "en-US");
  };

  App.svg = {
    crest: '<svg class="crest" viewBox="0 0 48 48" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linejoin="round" stroke-linecap="round">' +
      '<path d="M8 34 L6 14 L16 22 L24 8 L32 22 L42 14 L40 34 Z" fill="currentColor" fill-opacity="0.18"/>' +
      '<path d="M8 40 H40"/><circle cx="24" cy="8" r="2.2" fill="currentColor"/><circle cx="6" cy="14" r="1.8" fill="currentColor"/><circle cx="42" cy="14" r="1.8" fill="currentColor"/>' +
      '<path d="M18 30 C20 26 22 34 24 30 C26 26 28 34 30 30" stroke-width="2"/></svg>',
    star: '<svg class="star-ico" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 2l2.9 6.6 7.1.6-5.4 4.7 1.6 7-6.2-3.7-6.2 3.7 1.6-7L2 9.2l7.1-.6z"/></svg>',
    up: '<svg class="trend up" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 4 L21 18 H3 Z"/></svg>',
    down: '<svg class="trend down" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 20 L3 6 H21 Z"/></svg>'
  };

  // ---------------------------------------------------------------- live status chip

  /** Keep a .live element in sync: state = live | polling | reconnecting | notfound | connecting */
  App.liveChip = function (el) {
    var state = "connecting";
    function draw() {
      el.setAttribute("data-state", state);
      el.innerHTML = '<span class="dot" aria-hidden="true"></span><span>' + App.esc(App.t("live_" + state)) + "</span>";
    }
    App.onLang(draw);
    draw();
    return function (s) { if (s !== state) { state = s; draw(); } };
  };

  // ---------------------------------------------------------------- board connection

  /**
   * Connect to a class board. onBoard(board) on every update; onStatus(state).
   * SSE first; if it errors, poll /board every 3 s until SSE is back.
   */
  App.connectBoard = function (code, onBoard, onStatus) {
    onStatus = onStatus || function () {};
    if (App.demo) { Demo.start(onBoard, onStatus); return; }

    var base = "/api/classes/" + encodeURIComponent(code);
    var es = null, pollTimer = null, reopenTimer = null, sseAlive = false, lastBoardAt = 0, missing = false;

    function deliver(board) {
      lastBoardAt = Date.now();
      try { onBoard(board); } catch (e) { console.error(e); }
    }

    function pollOnce() {
      return fetch(base + "/board", { cache: "no-store" }).then(function (r) {
        if (r.status === 404) {
          // unknown class: stop the stream, keep a slow poll in case the teacher creates it
          missing = true; onStatus("notfound");
          if (es) { try { es.close(); } catch (e) { /* ignore */ } es = null; }
          clearTimeout(reopenTimer); startPolling();
          return null;
        }
        if (missing) { missing = false; openSSE(); }
        if (!r.ok) throw new Error("HTTP " + r.status);
        return r.json();
      }).then(function (b) {
        if (b) { deliver(b); if (!sseAlive) onStatus("polling"); }
      }).catch(function () { if (!sseAlive) onStatus("reconnecting"); });
    }

    function startPolling() {
      if (pollTimer) return;
      pollTimer = setInterval(pollOnce, 3000);
    }
    function stopPolling() { if (pollTimer) { clearInterval(pollTimer); pollTimer = null; } }

    function openSSE() {
      if (!window.EventSource) { startPolling(); return; }
      if (es) { try { es.close(); } catch (e) { /* ignore */ } }
      es = new EventSource(base + "/stream");
      es.addEventListener("open", function () { sseAlive = true; onStatus("live"); stopPolling(); });
      es.addEventListener("board", function (ev) {
        sseAlive = true;
        var b;
        try { b = JSON.parse(ev.data); } catch (e) { return; }
        onStatus("live");
        stopPolling();
        deliver(b);
      });
      es.addEventListener("error", function () {
        sseAlive = false;
        if (missing) return;
        onStatus(pollTimer ? "polling" : "reconnecting");
        startPolling();
        pollOnce();
        if (es.readyState === 2 /* CLOSED */) {  // browser gave up; retry ourselves
          clearTimeout(reopenTimer);
          reopenTimer = setTimeout(openSSE, 10000);
        }
      });
    }

    // first paint quickly, then live updates
    pollOnce();
    openSSE();

    // watchdog: if nothing arrived for 60 s (proxy swallowed the stream), poll and reopen
    setInterval(function () {
      if (Date.now() - lastBoardAt > 60000) { pollOnce(); if (sseAlive) { sseAlive = false; openSSE(); } }
    }, 20000);
  };

  // ---------------------------------------------------------------- teacher API

  App.api = function (method, path, body, key) {
    if (App.demo) return DemoApi.call(method, path, body, key);
    var opts = { method: method, headers: {}, cache: "no-store" };
    if (key) opts.headers["X-Teacher-Key"] = key;
    if (body !== undefined) { opts.headers["Content-Type"] = "application/json"; opts.body = JSON.stringify(body); }
    return fetch(path, opts).then(function (r) {
      return r.text().then(function (txt) {
        var data = null;
        try { data = txt ? JSON.parse(txt) : null; } catch (e) { data = null; }
        if (!r.ok) {
          var err = new Error((data && data.error) || ("HTTP " + r.status));
          err.status = r.status; err.data = data;
          throw err;
        }
        return data;
      });
    });
  };

  // ---------------------------------------------------------------- demo mode

  var DEMO_NAMES = ["김민지", "Alex Carter", "이서준", "박지우", "Emma Wilson", "최하은", "정도윤", "Liam O'Brien",
    "강서연", "조예준", "Sofia García", "윤지호", "장수아", "Noah Kim", "임하린", "한시우", "Mia <b>Lee</b>",
    "오은우", "서지안", "Daniel Park", "신유나", "권태윤", "Chloe Nguyen", "황보다인"];

  function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }

  var Demo = {
    students: null,
    tick: 0,
    init: function () {
      var now = Date.now();
      this.students = DEMO_NAMES.map(function (name, i) {
        var started = i < 22;
        return {
          no: i + 1, name: name,
          pace: 0.03 + Math.random() * 0.09,       // milestones per tick
          prog: started ? Math.random() * 3 : 0,
          words: 0, stars: 0, kills: 0, defeats: 0, fails: 0,
          tumor: 100 + Math.random() * 8, peak: 0,
          online: started && Math.random() > 0.15,
          startedAt: started ? now - (5 + Math.random() * 20) * 60000 : null,
          finishedAt: null,
          active: started
        };
      });
      // a couple already far along, so the remission look is visible quickly
      this.students[3].prog = 10.6; this.students[3].pace = 0.12;
      this.students[7].prog = 11.2; this.students[7].kills = 20; this.students[7].tumor = 60;
      this.students[12].prog = 9.5;
    },
    step: function () {
      var now = Date.now();
      this.tick++;
      this.students.forEach(function (s) {
        if (!s.active) {
          if (Math.random() < 0.01) { s.active = true; s.online = true; s.startedAt = now; }
          return;
        }
        if (Math.random() < 0.03) s.online = !s.online;
        if (!s.online) return;
        var reached = Math.floor(s.prog);
        // tumor: grows (demo time is fast) until the Knights arrive (11 = tcells_herded reached)
        if (reached < 11) {
          s.tumor = Math.min(160, s.tumor + 0.5);
          s.prog = Math.min(11, s.prog + s.pace * (0.5 + Math.random()));
        } else if (reached === 11) {
          if (!s.peak) s.peak = s.tumor;
          if (Math.random() < 0.7) s.kills += 1 + Math.floor(Math.random() * 2);
          s.tumor = Math.max(0, s.peak * (1 - s.kills / 30));
          if (s.kills >= 30) { s.tumor = 0; s.prog = 12; }
        } else if (reached === 12) {
          s.prog += 0.25;
          if (s.prog >= 13) { s.prog = 13; s.finishedAt = now; }
        }
        if (Math.random() < 0.25) s.words = Math.min(39, s.words + 1);
        if (Math.random() < 0.04 && s.stars < Math.min(12, Math.floor(s.prog))) s.stars++;
        if (Math.random() < 0.015) s.defeats++;
        if (Math.random() < 0.01) s.fails++;
      });
    },
    board: function () {
      var now = Date.now();
      var list = this.students.map(function (s) {
        var progress = Math.floor(s.prog);
        var stage = progress > 0 ? App.MILESTONES[progress - 1] : "not_started";
        var minutes = s.startedAt ? ((s.finishedAt || now) - s.startedAt) / 60000 : 0;
        var speed = progress >= 13 ? Math.max(0, Math.round(1000 - 10 * minutes)) : 0;
        var b = {
          milestones: progress * 100, words: s.words * 10, stars: s.stars * 100,
          kills: s.kills * 25, setbacks: -(s.defeats * 25 + s.fails * 15), speed: speed
        };
        var score = b.milestones + b.words + b.stars + b.kills + b.setbacks + b.speed;
        var immuneCount = clamp(progress - 2, 0, 9);
        var phase = progress === 0 ? "waiting" : progress <= 3 ? "growing" : progress <= 8 ? "vaccine"
          : progress <= 10 ? "training" : progress === 11 ? "attacking" : "remission";
        var tumor = progress >= 12 ? 0 : Math.round(s.tumor * 10) / 10;
        return {
          no: s.no, name: s.name, rank: 0, score: score, breakdown: b,
          progress: progress, stage: stage,
          chapter: ["", "cave", "palace", "laboratory", "bioworld", "lymph", "tumor"][clamp(Math.ceil(progress / 2.2), 0, 6)],
          words: s.words, stars: s.stars, defeats: s.defeats, fails: s.fails, kills: s.kills,
          online: s.online, startedAt: s.startedAt, finishedAt: s.finishedAt,
          minutes: s.startedAt ? Math.floor(minutes) : 0,
          mira: {
            tumor: tumor,
            strength: Math.round(clamp(100 - tumor * 0.55, 5, 100)),
            immune: Math.round(immuneCount / 9 * 100),
            phase: phase
          }
        };
      });
      list.sort(function (a, b) { return b.score - a.score || a.no - b.no; });
      list.forEach(function (s, i) { s.rank = i + 1; });
      return { code: App.code || "DEMO", name: "Demo · 1학년 2반 생명과학", now: now, milestones: App.MILESTONES.slice(), students: list };
    },
    start: function (onBoard, onStatus) {
      var self = this;
      if (!this.students) this.init();
      onStatus("live");
      onBoard(this.board());
      setInterval(function () {
        self.step();
        if (self.tick % 25 === 12) { onStatus("reconnecting"); return; }   // show the reconnecting state briefly
        onStatus("live");
        onBoard(self.board());
      }, 1000);
    }
  };

  // fake teacher API for ?demo=1 (in-memory only)
  var DemoApi = {
    classes: {
      DEMO: { code: "DEMO", name: "Demo · 1학년 2반 생명과학", students: DEMO_NAMES.slice(0, 10).map(function (n, i) { return { no: i + 1, name: n, pin: String(1000 + Math.floor(Math.random() * 9000)) }; }) }
    },
    call: function (method, path, body, key) {
      var self = this;
      return new Promise(function (resolve, reject) {
        setTimeout(function () {
          function fail(st, msg) { var e = new Error(msg); e.status = st; reject(e); }
          if (key !== "demo") return fail(401, "unauthorized");
          var m;
          var pin = function () { return String(Math.floor(Math.random() * 10000)).padStart(4, "0"); };
          if (path === "/api/teacher/check") return resolve({ ok: true });
          if (path === "/api/classes" && method === "GET") {
            return resolve({ classes: Object.keys(self.classes).map(function (k) { var c = self.classes[k]; return { code: c.code, name: c.name, students: c.students.length }; }) });
          }
          if (path === "/api/classes" && method === "POST") {
            var code = String(body.code || "").toUpperCase();
            if (!/^[A-Z0-9-]{2,16}$/.test(code)) return fail(400, "bad code");
            if (self.classes[code]) return fail(409, "class exists");
            self.classes[code] = { code: code, name: body.name || code, students: [] };
            return resolve({ code: code, name: self.classes[code].name });
          }
          if ((m = path.match(/^\/api\/classes\/([^/]+)(\/.*)?$/))) {
            var c = self.classes[decodeURIComponent(m[1])];
            if (!c) return fail(404, "no such class");
            var rest = m[2] || "";
            if (!rest && method === "DELETE") { delete self.classes[c.code]; return resolve({ ok: true }); }
            if (rest === "/roster") return resolve({ code: c.code, name: c.name, students: c.students.slice() });
            if (rest === "/reset") return resolve({ ok: true });
            if (rest === "/students" && method === "POST") {
              var next = c.students.reduce(function (a, s) { return Math.max(a, s.no); }, 0);
              var added = (body.names || []).map(function (n) { var s = { no: ++next, name: n, pin: pin() }; c.students.push(s); return s; });
              return resolve({ added: added });
            }
            var sm = rest.match(/^\/students\/(\d+)(\/pin)?$/);
            if (sm) {
              var no = +sm[1];
              var st = c.students.filter(function (s) { return s.no === no; })[0];
              if (!st) return fail(404, "no such student");
              if (sm[2]) { st.pin = pin(); return resolve({ no: no, pin: st.pin }); }
              c.students = c.students.filter(function (s) { return s.no !== no; });
              return resolve({ ok: true });
            }
          }
          fail(404, "not found");
        }, 150);
      });
    }
  };

  // ---------------------------------------------------------------- page boot

  document.addEventListener("DOMContentLoaded", function () { App.applyI18n(); });
})();
