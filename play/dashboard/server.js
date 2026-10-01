// Director's dashboard for the Prince of mRNA play.
// Serves the dashboard (/), the projector window (/stage) and settings (/settings);
// keeps one shared state and pushes it to every open window over WebSocket.
const express = require('express');
const http = require('http');
const fs = require('fs');
const path = require('path');
const { WebSocketServer } = require('ws');

const PLAY = path.resolve(__dirname, '..');            // play/
const BACKDROPS = path.join(PLAY, 'backdrops');
const SFX = path.join(PLAY, 'sfx');
const CUESHEET = path.join(PLAY, '큐시트.md');
const SCRIPT = path.join(PLAY, '희곡.md');
const VOICE = path.join(PLAY, 'voice');
const CONFIG = path.join(__dirname, 'config.json');
const DEFAULTS = JSON.parse(fs.readFileSync(path.join(__dirname, 'config.default.json'), 'utf8'));

function loadConfig() {
  try { return { ...DEFAULTS, ...JSON.parse(fs.readFileSync(CONFIG, 'utf8')) }; }
  catch { return JSON.parse(JSON.stringify(DEFAULTS)); }
}
function saveConfig(cfg) { fs.writeFileSync(CONFIG, JSON.stringify(cfg, null, 2)); }
let config = loadConfig();

// ---------- catalogue: backdrops, sound effects, cues ----------
const BACKDROP_NAMES = {
  '01': '공주가 누워 있는 방', '02': '두루마리의 방', '03': '분자 왕국 혼합기의 방',
  '04': '수지상세포 내부', '05': '림프절 T세포의 방', '06': '종양',
};
function listBackdrops() {
  return fs.readdirSync(BACKDROPS)
    .filter(f => /^\d\d_[a-z0-9_]+\.png$/.test(f) && !/_raw|_v\d/.test(f))
    .sort()
    .map(f => ({ id: f.replace(/\.png$/, ''), num: f.slice(0, 2), name: BACKDROP_NAMES[f.slice(0, 2)] || f, url: '/backdrops/' + f, thumb: fs.existsSync(path.join(BACKDROPS, 'thumbs', f.replace(/\.png$/, '.jpg'))) ? '/backdrops/thumbs/' + f.replace(/\.png$/, '.jpg') : '/backdrops/' + f }));
}
function listSfx() {
  return fs.readdirSync(SFX).filter(f => f.endsWith('.mp3')).sort()
    .map(f => ({ id: f.replace(/\.mp3$/, ''), num: f.slice(0, 2), url: '/sfx/' + f }));
}
const SFX_TOKEN = /(\d\d)_([a-z0-9_]+)/g;
function parseCues() {
  const md = fs.readFileSync(CUESHEET, 'utf8');
  const cues = [];
  for (const line of md.split('\n')) {
    if (!/^\|\s*\d+\s*\|/.test(line)) continue;
    const c = line.split('|').slice(1, -1).map(s => s.trim());
    if (c.length < 8) continue;
    const [no, time, scene, trigger, backdrop, light, soundRaw, notes] = c;
    const sound = soundRaw.replace(/`/g, '');
    const nums = backdrop.match(/\d/g) || [];
    const transition = backdrop.includes('→');
    const sounds = [...sound.matchAll(SFX_TOKEN)].map(m => m[0]);
    const loop = /반복/.test(sound);
    const stops = [...sound.matchAll(/(\d\d)\s*(페이드아웃|정지)/g)].map(m => m[1]);
    cues.push({
      no: Number(no), time, scene, trigger, backdrop, light, sound, notes,
      action: {
        backdrop: nums.length ? (transition ? 'black' : nums[nums.length - 1].padStart(2, '0')) : null,
        nextBackdrop: transition ? nums[nums.length - 1].padStart(2, '0') : null,
        play: sounds, loop, stops,
      },
    });
  }
  return cues;
}
let cues = parseCues();

// ---------- script (희곡) lines for the AI actors ----------
const ROLE_ALIASES = { '해설(두루마리)': '해설', '해설(혼합기)': '혼합기', '수지상세포(리보솜 목소리)': '리보솜', 'T세포(활성화)': 'T세포', 'TRIM25·엑소뉴클레아제': 'TRIM25' };
const ROLES = new Set(['해설', '아린', '미라', '수지상세포', '리보솜', '혼합기', 'T세포', '암세포', 'TRIM25', '엑소뉴클레아제']);
function md5(s) { return require('crypto').createHash('md5').update(s, 'utf8').digest('hex').slice(0, 12); }
function loadManifest() { try { return JSON.parse(fs.readFileSync(path.join(VOICE, 'manifest.json'), 'utf8')); } catch { return {}; } }
function parseScript() {
  const manifest = loadManifest();
  const md = fs.readFileSync(SCRIPT, 'utf8');
  const lines = []; let scene = '', sceneNo = 0;
  for (const raw of md.split('\n')) {
    if (raw.startsWith('## ')) { scene = raw.slice(3).trim(); if (/^(등장인물|주요 소품)/.test(scene)) { scene = ''; continue; } sceneNo++; lines.push({ type: 'scene', scene, sceneNo, i: lines.length }); continue; }
    if (!scene) continue;
    if (raw.startsWith('> ')) {
      const t = raw.slice(2).trim().replace(/\*\*/g, '').replace(/`/g, '');
      const nums = [...t.matchAll(/배경 (\d)/g)].map(m => m[1].padStart(2, '0'));
      lines.push({ type: 'direction', i: lines.length, scene, sceneNo, text: t,
        action: { backdrop: nums[0] || (/암전/.test(t) ? 'black' : null), play: [...t.matchAll(SFX_TOKEN)].map(m => m[0]), loop: /반복/.test(t) } });
      continue;
    }
    const m = /^\*\*(.+?)\*\*\s*(.*)$/.exec(raw);
    if (!m) continue;
    const speaker = m[1].trim(), text = m[2].trim(), role = ROLE_ALIASES[speaker] || speaker;
    if (!ROLES.has(role) || !text) continue;
    const id = md5(role + '|' + text);
    const has = fs.existsSync(path.join(VOICE, id + '.mp3'));
    lines.push({ type: 'line', i: lines.length, scene, sceneNo, speaker, role, text, id, voice: has, duration: manifest[id]?.duration || null });
  }
  return lines;
}
let script = parseScript();

// ---------- shared state ----------
const state = {
  backdrop: 'black',          // backdrop id ('01_princess_room') or 'black'
  cue: -1,                    // index into cues of the last executed cue
  playing: [],                // [{id, loop, startedAt}]
  lights: {},                 // id -> {on: true|false|null, ok, message, at}
  stopwatch: { running: false, startedAt: null, elapsed: 0 },
  narration: { running: false, index: -1, lineId: null },
};
let narrTimer = null;
const GAP_MS = 600;
function execAction(a) {
  if (!a) return;
  for (const num of a.stops || []) { const p = state.playing.find(p => p.id.startsWith(num + '_')); if (p) { state.playing = state.playing.filter(x => x !== p); broadcast({ type: 'sound', action: 'stop', id: p.id, fade: true }); } }
  if (a.backdrop) state.backdrop = a.backdrop === 'black' ? 'black' : ((listBackdrops().find(b => b.num === a.backdrop) || {}).id || state.backdrop);
  for (const id of a.play || []) { state.playing = state.playing.filter(p => p.id !== id); state.playing.push({ id, loop: !!a.loop, startedAt: Date.now() }); broadcast({ type: 'sound', action: 'play', id, loop: !!a.loop, volume: 1 }); }
}
function narrStop(silent) {
  clearTimeout(narrTimer); narrTimer = null;
  const n = state.narration;
  if (n.lineId) broadcast({ type: 'voice', action: 'stop', id: n.lineId, fade: true });
  n.running = false; n.lineId = null;
  if (!silent) pushState();
}
function narrStep(i) {
  clearTimeout(narrTimer); narrTimer = null;
  const n = state.narration;
  const line = script[i];
  if (!line) { n.running = false; n.index = -1; n.lineId = null; pushState(); return; }
  n.index = i; n.lineId = null;
  if (line.type === 'scene') { pushState(); narrTimer = setTimeout(() => narrStep(i + 1), 300); return; }
  if (line.type === 'direction') {
    execAction({ backdrop: line.action.backdrop, play: line.action.play, loop: line.action.loop });
    pushState();
    narrTimer = setTimeout(() => narrStep(i + 1), line.action.play.length ? 1800 : 1000);
    return;
  }
  if (line.voice) {
    n.lineId = line.id;
    broadcast({ type: 'voice', action: 'play', id: line.id });
    pushState();
    narrTimer = setTimeout(() => narrStep(i + 1), ((line.duration || 4) * 1000) + 2500);   // fallback if no client reports 'ended'
  } else { pushState(); narrTimer = setTimeout(() => narrStep(i + 1), Math.min(6000, 1500 + line.text.length * 60)); }
}
function narrStart(i) { narrStop(true); state.narration.running = true; narrStep(i); }
for (const l of config.lights) state.lights[l.id] = { on: null, ok: null, message: '아직 명령 없음', at: null };

const app = express();
app.use(express.json());
app.use('/backdrops', express.static(BACKDROPS, { maxAge: '1h' }));
app.use('/sfx', express.static(SFX, { maxAge: '1h' }));
const ASSET_VER = String(Math.floor(fs.statSync(path.join(__dirname, 'public', 'app.js')).mtimeMs));
function sendPage(name) {   // HTML is never cached; js/css links get a version query so browsers and Cloudflare fetch new builds
  const html = fs.readFileSync(path.join(__dirname, 'public', name), 'utf8').replace(/(href|src)="\/([a-z]+\.(?:js|css))"/g, `$1="/$2?v=${ASSET_VER}"`);
  return (_, res) => { res.set('Cache-Control', 'no-store'); res.type('html').send(html); };
}
app.get('/', sendPage('index.html'));
app.get('/index.html', sendPage('index.html'));
app.use(express.static(path.join(__dirname, 'public'), { setHeaders: res => res.set('Cache-Control', 'no-cache') }));
app.get('/stage', sendPage('stage.html'));
app.get('/settings', sendPage('settings.html'));

const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: '/ws' });
function broadcast(msg) {
  const data = JSON.stringify(msg);
  for (const ws of wss.clients) if (ws.readyState === 1) ws.send(data);
}
function pushState() { broadcast({ type: 'state', state }); }
wss.on('connection', ws => {
  ws.send(JSON.stringify({ type: 'hello', state, config: publicConfig(), cues, backdrops: listBackdrops(), sfx: listSfx(), script }));
});
function publicConfig() { return config; }

// ---------- API ----------
app.get('/api/catalog', (_, res) => res.json({ cues, backdrops: listBackdrops(), sfx: listSfx(), config: publicConfig(), state, script }));
app.get('/api/script', (_, res) => res.json(script));
app.use('/voice', express.static(VOICE, { maxAge: '1h' }));

// AI actors: single line, or the sequencer (start / stop / next / prev)
app.post('/api/voice', (req, res) => {
  const { action, id } = req.body || {};
  if (action === 'play') {
    if (!script.some(l => l.id === id && l.voice)) return res.status(400).json({ error: 'no clip' });
    if (state.narration.running) narrStop(true);
    state.narration.index = script.findIndex(l => l.id === id); state.narration.lineId = id;
    broadcast({ type: 'voice', action: 'play', id }); pushState();
  } else if (action === 'stop') { broadcast({ type: 'voice', action: 'stop', id, fade: true }); if (state.narration.lineId === id) { state.narration.lineId = null; pushState(); } }
  else if (action === 'ended') {
    if (state.narration.running && state.narration.lineId === id) { state.narration.lineId = null; clearTimeout(narrTimer); narrTimer = setTimeout(() => narrStep(state.narration.index + 1), GAP_MS); }
    else if (state.narration.lineId === id) { state.narration.lineId = null; pushState(); }
  } else return res.status(400).json({ error: 'bad action' });
  res.json({ ok: true });
});
app.post('/api/narration', (req, res) => {
  const { action, index } = req.body || {};
  const n = state.narration;
  if (action === 'start') narrStart(Number.isFinite(Number(index)) ? Number(index) : Math.max(0, n.index));
  else if (action === 'stop') narrStop();
  else if (action === 'next') { const was = n.running; narrStop(true); if (was) narrStart(n.index + 1); else { n.index = Math.min(script.length - 1, n.index + 1); pushState(); } }
  else if (action === 'prev') { const was = n.running; narrStop(true); const i = Math.max(0, n.index - 1); if (was) narrStart(i); else { n.index = i; pushState(); } }
  else return res.status(400).json({ error: 'bad action' });
  res.json({ ok: true, narration: n });
});
app.get('/api/state', (_, res) => res.json(state));

app.post('/api/show', (req, res) => {
  const { backdrop } = req.body || {};
  const ok = backdrop === 'black' || listBackdrops().some(b => b.id === backdrop || b.num === backdrop);
  if (!ok) return res.status(400).json({ error: 'unknown backdrop' });
  state.backdrop = backdrop === 'black' ? 'black' : listBackdrops().find(b => b.id === backdrop || b.num === backdrop).id;
  pushState();
  res.json({ ok: true, backdrop: state.backdrop });
});

app.post('/api/sound', (req, res) => {
  const { action, id, loop } = req.body || {};
  if (action === 'play') {
    if (!listSfx().some(s => s.id === id)) return res.status(400).json({ error: 'unknown sfx' });
    state.playing = state.playing.filter(p => p.id !== id);
    state.playing.push({ id, loop: !!loop, startedAt: Date.now() });
    broadcast({ type: 'sound', action: 'play', id, loop: !!loop, volume: 1 });
  } else if (action === 'stop') {
    state.playing = state.playing.filter(p => p.id !== id);
    broadcast({ type: 'sound', action: 'stop', id });
  } else if (action === 'stopAll') {
    state.playing = [];
    broadcast({ type: 'sound', action: 'stopAll' });
    if (state.narration.running || state.narration.lineId) narrStop(true);
  } else if (action === 'ended') {          // a client reports a non-looping clip finished
    state.playing = state.playing.filter(p => p.id !== id);
  } else return res.status(400).json({ error: 'bad action' });
  pushState();
  res.json({ ok: true });
});

// Execute a cue: stop referenced sounds, show its backdrop, play its first sound.
app.post('/api/cue', (req, res) => {
  const idx = Number(req.body?.index);
  const cue = cues[idx];
  if (!cue) return res.status(400).json({ error: 'no such cue' });
  const a = cue.action;
  for (const num of a.stops) {
    const p = state.playing.find(p => p.id.startsWith(num + '_'));
    if (p) { state.playing = state.playing.filter(x => x !== p); broadcast({ type: 'sound', action: 'stop', id: p.id, fade: true }); }
  }
  if (a.backdrop) {
    state.backdrop = a.backdrop === 'black' ? 'black' : (listBackdrops().find(b => b.num === a.backdrop) || {}).id || state.backdrop;
    if (a.nextBackdrop) broadcast({ type: 'preload', backdrop: (listBackdrops().find(b => b.num === a.nextBackdrop) || {}).id });
  }
  if (a.play.length) {
    const id = a.play[0];
    state.playing = state.playing.filter(p => p.id !== id);
    state.playing.push({ id, loop: a.loop, startedAt: Date.now() });
    broadcast({ type: 'sound', action: 'play', id, loop: a.loop, volume: 1 });
  }
  state.cue = idx;
  pushState();
  res.json({ ok: true, cue });
});
app.post('/api/cue/select', (req, res) => {   // move the pointer without executing
  const idx = Number(req.body?.index);
  if (idx < -1 || idx >= cues.length) return res.status(400).json({ error: 'range' });
  state.cue = idx; pushState(); res.json({ ok: true });
});

app.post('/api/stopwatch', (req, res) => {
  const sw = state.stopwatch, now = Date.now();
  switch (req.body?.action) {
    case 'start': if (!sw.running) { sw.running = true; sw.startedAt = now - sw.elapsed; } break;
    case 'pause': if (sw.running) { sw.elapsed = now - sw.startedAt; sw.running = false; } break;
    case 'reset': sw.running = false; sw.elapsed = 0; sw.startedAt = null; break;
    default: return res.status(400).json({ error: 'bad action' });
  }
  pushState(); res.json({ ok: true, stopwatch: sw });
});

// ---------- settings ----------
app.get('/api/settings', (_, res) => res.json(config));
app.put('/api/settings', (req, res) => {
  const b = req.body || {};
  const next = { ...config };
  if (['dashboard', 'stage', 'both'].includes(b.audioOutput)) next.audioOutput = b.audioOutput;
  if (['contain', 'cover'].includes(b.stageFit)) next.stageFit = b.stageFit;
  if (Number.isFinite(Number(b.stageFadeMs))) next.stageFadeMs = Math.max(0, Math.min(5000, Number(b.stageFadeMs)));
  if (Array.isArray(b.lights)) {
    next.lights = b.lights.slice(0, 4).map((l, i) => ({
      id: i + 1,
      name: String(l.name || `조명 ${i + 1}`).slice(0, 40),
      color: /^#[0-9a-fA-F]{6}$/.test(l.color || '') ? l.color : '#f59e0b',
      host: String(l.host || '').trim().slice(0, 100),
      port: Math.max(1, Math.min(65535, Number(l.port) || 80)),
      method: ['GET', 'POST', 'PUT'].includes(l.method) ? l.method : 'GET',
      onPath: String(l.onPath || '/').slice(0, 200),
      offPath: String(l.offPath || '/').slice(0, 200),
      body: String(l.body || '').slice(0, 2000),
    }));
    for (const l of next.lights) if (!state.lights[l.id]) state.lights[l.id] = { on: null, ok: null, message: '아직 명령 없음', at: null };
  }
  config = next; saveConfig(config);
  broadcast({ type: 'config', config });
  res.json({ ok: true, config });
});

// ---------- IoT lights ----------
async function callLight(light, on) {
  const p = on ? light.onPath : light.offPath;
  const url = `http://${light.host}:${light.port}${p.startsWith('/') ? '' : '/'}${p}`;
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), 3000);
  try {
    const opts = { method: light.method, signal: ctrl.signal };
    if (light.method !== 'GET' && light.body) { opts.body = light.body; opts.headers = { 'Content-Type': 'application/json' }; }
    const r = await fetch(url, opts);
    const text = (await r.text()).slice(0, 120);
    return { ok: r.ok, message: `HTTP ${r.status} ${text}`.trim(), url };
  } catch (e) {
    return { ok: false, message: e.name === 'AbortError' ? '응답 없음 (3초 초과)' : String(e.message || e), url };
  } finally { clearTimeout(t); }
}
app.post('/api/lights/:id', async (req, res) => {
  const light = config.lights.find(l => l.id === Number(req.params.id));
  if (!light) return res.status(404).json({ error: 'no such light' });
  const on = !!req.body?.on;
  const r = await callLight(light, on);
  state.lights[light.id] = { on: r.ok ? on : state.lights[light.id]?.on ?? null, ok: r.ok, message: r.message, at: Date.now(), wanted: on };
  pushState();
  res.json({ ok: r.ok, light: state.lights[light.id], url: r.url });
});
app.post('/api/lights', async (req, res) => {       // all four at once
  const on = !!req.body?.on;
  const results = await Promise.all(config.lights.map(async l => {
    const r = await callLight(l, on);
    state.lights[l.id] = { on: r.ok ? on : state.lights[l.id]?.on ?? null, ok: r.ok, message: r.message, at: Date.now(), wanted: on };
    return { id: l.id, ok: r.ok };
  }));
  pushState(); res.json({ results });
});

app.post('/api/reload', (_, res) => { cues = parseCues(); script = parseScript(); broadcast({ type: 'cues', cues, script }); res.json({ ok: true, cues: cues.length, lines: script.length }); });

const PORT = Number(process.env.PORT) || config.port || 8100;
server.listen(PORT, () => console.log(`Director dashboard: http://localhost:${PORT}/  stage: /stage  settings: /settings  (${cues.length} cues, ${script.filter(l => l.type === 'line').length} lines, ${script.filter(l => l.voice).length} voiced)`));
