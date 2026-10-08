// Classroom server for Prince of mRNA: student logins, live scores and every
// student's Mira status. No dependencies (Node 18+). See classroom/API.md.
//
//   TEACHER_PASSWORD=choose-one PORT=8110 node classroom/server.js
//
// Serves classroom/public/ at /class/ and the JSON API at /api/.
// State lives in classroom/data/classroom.json (written atomically).
'use strict';
const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PORT = parseInt(process.env.PORT || '8110', 10);
const HOST = process.env.HOST || '127.0.0.1';
const PUBLIC_DIR = path.join(__dirname, 'public');
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');
const DATA_FILE = path.join(DATA_DIR, 'classroom.json');

// Story milestones in order (GameState flags set by the game).
const MILESTONES = ['met_mira', 'quest_started', 'mrna_assembled', 'lnp_made', 'lnp_uptake_done',
  'endosome_escape_done', 'translation_done', 'antigen_presented', 'dc_migrated',
  'tcell_activated', 'tcells_herded', 'tumor_cleared', 'story_complete'];
const QUIZ_CHAPTERS = ['laboratory', 'bioworld', 'lymph', 'tumor'];
const CHAPTERS = ['cave', 'palace', 'laboratory', 'bioworld', 'lymph', 'tumor'];
const MAX_WORDS = 39;
const ONLINE_MS = 40 * 1000;
const ACTIVE_GAP_MS = 60 * 1000;   // gaps longer than this (game closed, next lesson) are not play time

// ---------------------------------------------------------------- storage
let db = { classes: {} };
let tokens = {};   // token -> {code, no, ver}   (kept in the data file so logins survive restarts)

function load() {
  try {
    const d = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
    db = d.db || { classes: {} };
    tokens = d.tokens || {};
  } catch (e) {
    if (e.code !== 'ENOENT') console.error('Could not read data file:', e.message);
  }
}

let saveTimer = null;
function save() {
  if (saveTimer) return;
  saveTimer = setTimeout(() => {
    saveTimer = null;
    fs.mkdirSync(DATA_DIR, { recursive: true });
    const tmp = DATA_FILE + '.tmp';
    fs.writeFileSync(tmp, JSON.stringify({ db, tokens }));
    fs.renameSync(tmp, DATA_FILE);
  }, 1000);
}

let TEACHER_PASSWORD = process.env.TEACHER_PASSWORD || '';

// ---------------------------------------------------------------- model
function newProgress() {
  return { milestones: {}, words: {}, quiz: {}, defeats: 0, fails: 0, kills: 0,
    tumorLeft: null, tumorInit: null, chapter: '', startedAt: null, finishedAt: null, lastSeen: 0,
    activeMs: 0, activeAtHerd: null, activeAtFinish: null };
}

function applyEvent(p, ev, now) {
  if (!ev || typeof ev !== 'object') return false;
  if (p.startedAt === null) p.startedAt = now;
  addActive(p, now);
  switch (ev.type) {
    case 'flag': {
      const name = String(ev.name || '');
      if (MILESTONES.includes(name)) {
        if (!p.milestones[name]) {
          p.milestones[name] = now;
          if (name === 'story_complete' && !p.finishedAt) { p.finishedAt = now; p.activeAtFinish = p.activeMs; }
          if (name === 'tcells_herded') p.activeAtHerd = p.activeMs;
          return true;
        }
      } else if (/^word_[a-z0-9_]{1,30}$/.test(name)) {
        if (!p.words[name] && Object.keys(p.words).length < MAX_WORDS) { p.words[name] = 1; return true; }
      } else if (/^quizstars_[a-z]+$/.test(name)) {
        const ch = name.slice(10);
        const v = Math.max(0, Math.min(3, parseInt(ev.value, 10) || 0));
        if (QUIZ_CHAPTERS.includes(ch) && v > (p.quiz[ch] || 0)) { p.quiz[ch] = v; return true; }
      }
      return false;
    }
    case 'chapter': {
      const id = String(ev.id || '');
      if (CHAPTERS.includes(id) && p.chapter !== id) { p.chapter = id; return true; }
      return false;
    }
    case 'defeat': p.defeats = Math.min(p.defeats + 1, 999); return true;
    case 'mg_fail': p.fails = Math.min(p.fails + 1, 999); return true;
    case 'tumor': {
      const left = Math.max(0, Math.min(99, parseInt(ev.left, 10) || 0));
      const kills = Math.max(0, Math.min(99, parseInt(ev.kills, 10) || 0));
      if (kills === 0 && (p.tumorInit === null || p.tumorLeft === null)) p.tumorInit = Math.max(1, left);
      p.tumorLeft = left;
      if (kills > p.kills) p.kills = kills;   // best hunt
      return true;
    }
    case 'ping': return false;   // only play time / online status change
    default: return false;
  }
}

// Play time only counts while the game is open: events and 15 s pings close
// small gaps; a long silence (game closed, next lesson) adds nothing.
function addActive(p, now) {
  if (p.activeMs === undefined) p.activeMs = 0;
  const gap = now - (p.lastSeen || 0);
  if (p.lastSeen && gap > 0 && gap < ACTIVE_GAP_MS) p.activeMs += gap;
  p.lastSeen = now;
}

function minutesPlayed(p) {
  return (p.activeAtFinish ?? p.activeMs ?? 0) / 60000;
}

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

function mira(p, now) {
  const has = (m) => !!p.milestones[m];
  let phase = 'waiting';
  if (p.startedAt) phase = 'growing';
  if (has('lnp_made')) phase = 'vaccine';
  if (has('dc_migrated')) phase = 'training';
  if (has('tcells_herded')) phase = 'attacking';
  if (has('tumor_cleared')) phase = 'remission';

  let tumor = 100;
  if (p.startedAt) {
    // the tumor grows with active play time until the Knights arrive
    const minutes = (p.activeAtHerd ?? p.activeMs ?? 0) / 60000;
    tumor = Math.min(160, 100 + 0.5 * minutes);
    if (has('tumor_cleared')) tumor = 0;
    else if (has('tcells_herded') && p.tumorInit && p.tumorLeft !== null) {
      tumor = Math.min(160, tumor * p.tumorLeft / p.tumorInit);
    }
  }
  let ready = 0;
  for (let i = 2; i <= 10; i++) if (has(MILESTONES[i])) ready++;
  return {
    tumor: Math.round(tumor * 10) / 10,
    strength: Math.round(clamp(100 - tumor * 0.55, 5, 100)),
    immune: Math.round(ready / 9 * 100),
    phase,
  };
}

function score(p, now) {
  const milestones = Object.keys(p.milestones).length * 100;
  const words = Object.keys(p.words).length * 10;
  const stars = Object.values(p.quiz).reduce((a, b) => a + b, 0) * 100;
  const kills = p.kills * 25;
  const setbacks = -(p.defeats * 25 + p.fails * 15);
  let speed = 0;
  if (p.finishedAt) speed = Math.max(0, Math.round(1000 - 10 * minutesPlayed(p)));
  return { total: milestones + words + stars + kills + setbacks + speed,
    breakdown: { milestones, words, stars, kills, setbacks, speed } };
}

function board(code, now = Date.now()) {
  const c = db.classes[code];
  if (!c) return null;
  const students = Object.entries(c.students).map(([no, s]) => {
    const p = s.progress || newProgress();
    const sc = score(p, now);
    let stage = 'not_started';
    for (const m of MILESTONES) if (p.milestones[m]) stage = m;
    return {
      no: parseInt(no, 10), name: s.name, rank: 0,
      score: sc.total, breakdown: sc.breakdown,
      progress: Object.keys(p.milestones).length, stage, chapter: p.chapter,
      words: Object.keys(p.words).length,
      stars: Object.values(p.quiz).reduce((a, b) => a + b, 0),
      defeats: p.defeats, fails: p.fails, kills: p.kills,
      online: now - (p.lastSeen || 0) < ONLINE_MS,
      startedAt: p.startedAt, finishedAt: p.finishedAt,
      minutes: Math.round(minutesPlayed(p) * 10) / 10,
      mira: mira(p, now),
    };
  });
  students.sort((a, b) => b.score - a.score || b.progress - a.progress || a.no - b.no);
  let rank = 0, prev = null;
  students.forEach((s, i) => { if (s.score !== prev) { rank = i + 1; prev = s.score; } s.rank = rank; });
  return { code, name: c.name, now, milestones: MILESTONES, students };
}

// ---------------------------------------------------------------- live updates (SSE)
const streams = {};   // code -> Set(res)
const dirty = new Set();
function touch(code) { dirty.add(code); }
function startTimers() {
  setInterval(() => {
    for (const code of dirty) push(code);
    dirty.clear();
  }, 500);
  // tumors grow with time and "online" dots expire, so refresh every board regularly
  setInterval(() => { for (const code of Object.keys(streams)) push(code); }, 5000);
  setInterval(() => {
    for (const set of Object.values(streams)) for (const res of set) res.write(': ping\n\n');
  }, 20000);
}
function push(code) {
  const set = streams[code];
  if (!set || set.size === 0) return;
  const b = board(code);
  if (!b) return;
  const msg = 'event: board\ndata: ' + JSON.stringify(b) + '\n\n';
  for (const res of set) res.write(msg);
}

// ---------------------------------------------------------------- http helpers
function send(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store',
    'Access-Control-Allow-Origin': '*' });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let size = 0; const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > 64 * 1024) { reject(new Error('too large')); req.destroy(); return; }
      chunks.push(c);
    });
    req.on('end', () => {
      if (!chunks.length) return resolve({});
      try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8'))); } catch (e) { reject(e); }
    });
    req.on('error', reject);
  });
}

function isTeacher(req) {
  const k = String(req.headers['x-teacher-key'] || '');
  if (!k || !TEACHER_PASSWORD) return false;
  const a = Buffer.from(k), b = Buffer.from(TEACHER_PASSWORD);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

const loginAttempts = {};   // ip -> [timestamps]
function rateLimited(ip) {
  const now = Date.now();
  const list = (loginAttempts[ip] || []).filter((t) => now - t < 60000);
  list.push(now);
  loginAttempts[ip] = list;
  return list.length > 30;
}

function cleanCode(s) { return String(s || '').trim().toUpperCase(); }
function newPin() { return String(crypto.randomInt(0, 10000)).padStart(4, '0'); }

const TYPES = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8', '.png': 'image/png', '.svg': 'image/svg+xml',
  '.json': 'application/json', '.ico': 'image/x-icon', '.woff2': 'font/woff2' };

function serveStatic(req, res, rel) {
  if (rel === '' || rel.endsWith('/')) rel += 'index.html';
  const file = path.normalize(path.join(PUBLIC_DIR, rel));
  if (!file.startsWith(PUBLIC_DIR + path.sep)) { res.writeHead(403); return res.end(); }
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404, { 'Content-Type': 'text/plain' }); return res.end('Not found'); }
    res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream',
      'Cache-Control': 'no-cache' });
    res.end(data);
  });
}

// ---------------------------------------------------------------- routes
async function handleApi(req, res, parts) {
  const method = req.method;
  // parts: path after /api/, split by "/"
  if (method === 'OPTIONS') {
    res.writeHead(204, { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET,POST,DELETE',
      'Access-Control-Allow-Headers': 'Content-Type, X-Teacher-Key' });
    return res.end();
  }

  // ---- students
  if (method === 'POST' && parts[0] === 'login' && parts.length === 1) {
    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress || '';
    if (rateLimited(ip)) return send(res, 429, { error: 'Too many tries. Wait a minute.' });
    const b = await readBody(req);
    const code = cleanCode(b.class);
    const c = db.classes[code];
    const s = c && c.students[String(parseInt(b.no, 10))];
    if (!s || String(b.pin || '').trim() !== s.pin) {
      return send(res, 401, { error: 'Class code, number or PIN is wrong.' });
    }
    const token = crypto.randomBytes(18).toString('base64url');
    tokens[token] = { code, no: String(parseInt(b.no, 10)), ver: s.pinVer || 0 };
    save();
    return send(res, 200, { token, name: s.name, no: parseInt(b.no, 10), class: code, className: c.name });
  }

  if (method === 'POST' && parts[0] === 'events' && parts.length === 1) {
    const b = await readBody(req);
    const t = tokens[String(b.token || '')];
    const c = t && db.classes[t.code];
    const s = c && c.students[t.no];
    if (!s || (s.pinVer || 0) !== t.ver) return send(res, 401, { error: 'Please log in again.' });
    s.progress = s.progress || newProgress();
    const now = Date.now();
    let changed = false;
    for (const ev of (Array.isArray(b.events) ? b.events.slice(0, 200) : [])) {
      if (applyEvent(s.progress, ev, now)) changed = true;
    }
    if (!Array.isArray(b.events) || b.events.length === 0) addActive(s.progress, now);
    touch(t.code);
    save();
    return send(res, 200, { ok: true, score: score(s.progress, now).total, changed });
  }

  // ---- public boards
  if (parts[0] === 'classes' && parts.length === 3 && method === 'GET' && parts[2] === 'board') {
    const b = board(cleanCode(parts[1]));
    return b ? send(res, 200, b) : send(res, 404, { error: 'No class with that code.' });
  }
  if (parts[0] === 'classes' && parts.length === 3 && method === 'GET' && parts[2] === 'stream') {
    const code = cleanCode(parts[1]);
    const b = board(code);
    if (!b) return send(res, 404, { error: 'No class with that code.' });
    res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-store',
      'Connection': 'keep-alive', 'X-Accel-Buffering': 'no', 'Access-Control-Allow-Origin': '*' });
    res.write('retry: 3000\n');
    res.write('event: board\ndata: ' + JSON.stringify(b) + '\n\n');
    (streams[code] = streams[code] || new Set()).add(res);
    req.on('close', () => streams[code].delete(res));
    return;
  }

  // ---- teacher
  if (!isTeacher(req)) return send(res, 401, { error: 'Teacher password needed.' });

  if (parts[0] === 'teacher' && parts[1] === 'check') return send(res, 200, { ok: true });

  if (parts[0] === 'classes' && parts.length === 1) {
    if (method === 'GET') {
      return send(res, 200, { classes: Object.entries(db.classes).map(([code, c]) =>
        ({ code, name: c.name, students: Object.keys(c.students).length })) });
    }
    if (method === 'POST') {
      const b = await readBody(req);
      const code = cleanCode(b.code);
      if (!/^[A-Z0-9-]{2,16}$/.test(code)) return send(res, 400, { error: 'Use 2-16 letters, digits or -.' });
      if (db.classes[code]) return send(res, 409, { error: 'That class code is already used.' });
      db.classes[code] = { name: String(b.name || code).slice(0, 60), nextNo: 1, students: {} };
      save();
      return send(res, 200, { code, name: db.classes[code].name });
    }
  }

  const code = cleanCode(parts[1]);
  const c = parts[0] === 'classes' ? db.classes[code] : null;
  if (!c) return send(res, 404, { error: 'No class with that code.' });

  if (parts.length === 2 && method === 'DELETE') {
    delete db.classes[code];
    for (const [k, t] of Object.entries(tokens)) if (t.code === code) delete tokens[k];
    save();
    return send(res, 200, { ok: true });
  }
  if (parts.length === 3 && parts[2] === 'roster' && method === 'GET') {
    return send(res, 200, { code, name: c.name, students: Object.entries(c.students)
      .map(([no, s]) => ({ no: parseInt(no, 10), name: s.name, pin: s.pin })).sort((a, b) => a.no - b.no) });
  }
  if (parts.length === 3 && parts[2] === 'students' && method === 'POST') {
    const b = await readBody(req);
    const names = (Array.isArray(b.names) ? b.names : []).map((n) => String(n).trim().slice(0, 40)).filter(Boolean);
    if (Object.keys(c.students).length + names.length > 200) return send(res, 400, { error: 'At most 200 students per class.' });
    const added = names.map((name) => {
      const no = c.nextNo++;
      c.students[String(no)] = { name, pin: newPin(), pinVer: 0, progress: newProgress() };
      return { no, name, pin: c.students[String(no)].pin };
    });
    touch(code); save();
    return send(res, 200, { added });
  }
  if (parts.length === 5 && parts[2] === 'students' && parts[4] === 'pin' && method === 'POST') {
    const s = c.students[String(parseInt(parts[3], 10))];
    if (!s) return send(res, 404, { error: 'No such student.' });
    s.pin = newPin(); s.pinVer = (s.pinVer || 0) + 1;
    save();
    return send(res, 200, { no: parseInt(parts[3], 10), pin: s.pin });
  }
  if (parts.length === 4 && parts[2] === 'students' && method === 'DELETE') {
    delete c.students[String(parseInt(parts[3], 10))];
    touch(code); save();
    return send(res, 200, { ok: true });
  }
  if (parts.length === 3 && parts[2] === 'reset' && method === 'POST') {
    for (const s of Object.values(c.students)) s.progress = newProgress();
    touch(code); save();
    return send(res, 200, { ok: true });
  }
  return send(res, 404, { error: 'Not found.' });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://x');
  const p = decodeURIComponent(url.pathname);
  try {
    if (p.startsWith('/api/')) {
      return await handleApi(req, res, p.slice(5).split('/').filter(Boolean));
    }
    if (p === '/class') { res.writeHead(301, { Location: '/class/' }); return res.end(); }
    if (p.startsWith('/class/')) return serveStatic(req, res, p.slice(7));
    if (p === '/') { res.writeHead(302, { Location: '/class/' }); return res.end(); }
    res.writeHead(404); res.end();
  } catch (e) {
    if (!res.headersSent) send(res, 400, { error: 'Bad request.' });
  }
});

// exported for tests
module.exports = { applyEvent, mira, score, board, newProgress, MILESTONES, _db: () => db };

if (require.main === module) {
  load();
  startTimers();
  if (!TEACHER_PASSWORD) {
    TEACHER_PASSWORD = crypto.randomBytes(6).toString('base64url');
    console.log('No TEACHER_PASSWORD set. Teacher password for this run: ' + TEACHER_PASSWORD);
  }
  server.listen(PORT, HOST, () => console.log(`Classroom server on http://${HOST}:${PORT}/class/`));
}
