let cues = [], backdrops = [], sfx = [], script = [], config = {}, state = { backdrop: 'black', cue: -1, playing: [], lights: {}, stopwatch: { running: false, elapsed: 0 }, narration: { running: false, index: -1, lineId: null } };
const $ = s => document.querySelector(s);
const ROLE = 'dashboard';

function audioEnabled() { return config.audioOutput === ROLE || config.audioOutput === 'both'; }
function updateAudioBadge() {
  const b = $('#audioState');
  if (!audioEnabled()) { b.textContent = '🔈 소리는 무대 창에서 재생'; b.className = 'badge ok'; return; }
  b.textContent = Player.unlocked ? '🔊 소리 켜짐 (이 창)' : '🔇 클릭해서 소리 허용';
  b.className = 'badge ' + (Player.unlocked ? 'ok' : 'bad');
}
window.onAudioBlocked = () => { Player.unlocked = false; updateAudioBadge(); toast('브라우저가 자동 재생을 막았습니다. 상단의 소리 배지를 클릭하세요.', true); };
$('#audioState').onclick = () => { Player.unlock(); updateAudioBadge(); };
document.body.addEventListener('pointerdown', () => { if (!Player.unlocked && audioEnabled()) { Player.unlock(); updateAudioBadge(); } }, { once: true });

connect(msg => {
  if (msg.type === 'hello') { ({ cues, backdrops, sfx, config, state, script } = msg); Player.enabled = audioEnabled(); renderAll(); updateAudioBadge(); }
  else if (msg.type === 'state') { state = msg.state; renderState(); }
  else if (msg.type === 'config') { config = msg.config; Player.enabled = audioEnabled(); renderLights(); updateAudioBadge(); }
  else if (msg.type === 'cues') { cues = msg.cues; if (msg.script) { script = msg.script; renderScript(); } renderCues(); renderState(); }
  else if (msg.type === 'sound' || msg.type === 'voice') {
    if (!audioEnabled()) return;
    if (msg.action === 'play') Player.play(msg.id, msg.loop, msg.type);
    else if (msg.action === 'stop') Player.stop(msg.id, msg.fade);
    else if (msg.action === 'stopAll') Player.stopAll();
  }
}, ok => { const c = $('#conn'); c.textContent = ok ? '서버 연결됨' : '연결 끊김'; c.className = 'badge ' + (ok ? 'ok' : 'bad'); });

function renderAll() { renderBackdrops(); renderCues(); renderLights(); renderSfx(); renderScript(); renderState(); }

function renderScript() {
  const g = $('#scriptList'); g.innerHTML = '';
  for (const l of script) {
    if (l.type === 'scene') {
      const h = document.createElement('div'); h.className = 'scene-h'; h.dataset.i = l.i;
      h.innerHTML = `<button class="small go" data-narr="${l.i}" title="이 장면부터 자동 재생">▶</button><span>${esc(l.scene)}</span>`;
      g.appendChild(h); continue;
    }
    const d = document.createElement('div'); d.dataset.i = l.i;
    if (l.type === 'direction') {
      d.className = 'sline direction';
      const acts = [l.action.backdrop ? `배경 ${l.action.backdrop === 'black' ? '암전' : l.action.backdrop}` : '', ...l.action.play].filter(Boolean).join(', ');
      d.innerHTML = `<span class="help" style="margin:0">${acts ? '⚙' : ''}</span><span class="dtext">${esc(l.text)}</span>`;
    } else {
      d.className = 'sline role-' + l.role;
      d.innerHTML = `<button class="pbtn ${l.voice ? '' : 'novoice'}" data-voice="${l.id}" ${l.voice ? '' : 'disabled title="음성 없음"'}>▶</button><span class="who ${l.voice ? '' : 'novoice'}">${esc(l.speaker)}</span><span class="text">${esc(l.text)}</span>`;
    }
    g.appendChild(d);
  }
  g.onclick = e => {
    const t = e.target.closest('[data-voice],[data-narr]'); if (!t) return;
    if (t.dataset.voice) { const playing = state.narration.lineId === t.dataset.voice && !state.narration.running; API.post('/api/voice', playing ? { action: 'stop', id: t.dataset.voice } : { action: 'play', id: t.dataset.voice }).catch(err => toast(err.message, true)); }
    else API.post('/api/narration', { action: 'start', index: Number(t.dataset.narr) }).catch(err => toast(err.message, true));
  };
  g.ondblclick = e => { const row = e.target.closest('.sline'); if (row) API.post('/api/narration', { action: 'start', index: Number(row.dataset.i) }); };
}
function renderNarration() {
  const n = state.narration || {};
  document.querySelectorAll('#scriptList .sline, #scriptList .scene-h').forEach(el => {
    const i = Number(el.dataset.i);
    el.classList.toggle('current', i === n.index);
    el.classList.toggle('played', n.running && i < n.index);
    el.classList.toggle('now', !!n.lineId && script[i] && script[i].id === n.lineId);
    const b = el.querySelector('.pbtn'); if (b) b.classList.toggle('playing', !!n.lineId && b.dataset.voice === n.lineId);
  });
  const cur = script[n.index];
  $('#narrStatus').textContent = n.running ? `자동 재생 중 · ${cur ? (cur.type === 'line' ? cur.speaker + ': ' + cur.text.slice(0, 40) : cur.type === 'scene' ? cur.scene : '지문') : ''}` : (n.index >= 0 ? `정지됨 · 다음은 ${n.index + 1}번째 줄부터` : '대기');
  $('#narrPlay').textContent = n.running ? '▶ 재생 중' : '▶ 자동 재생'; $('#narrPlay').disabled = !!n.running;
  if ($('#narrFollow').checked && n.index >= 0) { const el = document.querySelector(`#scriptList [data-i="${n.index}"]`); if (el) el.scrollIntoView({ block: 'center', behavior: 'smooth' }); }
}

function renderBackdrops() {
  const g = $('#backdrops'); g.innerHTML = '';
  for (const b of backdrops) {
    const d = document.createElement('button'); d.className = 'bdcard'; d.dataset.id = b.id;
    d.innerHTML = `<img src="${b.thumb || b.url}" loading="lazy" alt="${esc(b.name)}"><div class="cap">${b.num} ${esc(b.name)}</div>`;
    d.onclick = () => show(b.id); g.appendChild(d);
  }
  const k = document.createElement('button'); k.className = 'bdcard blackout'; k.dataset.id = 'black'; k.textContent = '⬛ 암전'; k.onclick = () => show('black'); g.appendChild(k);
}
function renderCues() {
  const tb = $('#cueTable tbody'); tb.innerHTML = '';
  cues.forEach((c, i) => {
    const tr = document.createElement('tr'); tr.dataset.i = i;
    const bdHtml = c.backdrop.replace(/\d/g, n => `<span class="chip bd" data-bd="${n.padStart(2, '0')}">${n}</span>`);
    const soundHtml = c.sound
      .replace(/(\d\d)_([a-z0-9_]+)/g, (m, num, name) => `<button class="small sfxbtn" data-sfx="${m}" data-loop="${/반복/.test(c.sound) ? 1 : 0}">▶ ${num} ${name}</button>`)
      .replace(/(\d\d)\s*(페이드아웃|정지)/g, (m, num, w) => `<button class="small sfxbtn" data-stop="${num}">■ ${num} ${w}</button>`);
    tr.innerHTML = `<td class="no">${c.no}</td><td class="time">${esc(c.time)}</td><td>${esc(c.scene)}</td><td>${esc(c.trigger)}</td>
      <td>${bdHtml}</td><td><span class="chip light">${esc(c.light)}</span></td><td>${soundHtml}</td><td>${esc(c.notes)}</td>
      <td><button class="small go" data-go="${i}">GO</button></td>`;
    tb.appendChild(tr);
  });
  tb.onclick = async e => {
    const t = e.target.closest('[data-bd],[data-sfx],[data-stop],[data-go]'); if (!t) return;
    e.stopPropagation();
    if (t.dataset.bd) return show(t.dataset.bd);
    if (t.dataset.sfx) return API.post('/api/sound', { action: 'play', id: t.dataset.sfx, loop: t.dataset.loop === '1' }).catch(err => toast(err.message, true));
    if (t.dataset.stop) { const p = state.playing.find(p => p.id.startsWith(t.dataset.stop + '_')); return p ? API.post('/api/sound', { action: 'stop', id: p.id }) : toast('그 번호의 소리는 재생 중이 아닙니다'); }
    if (t.dataset.go) return runCue(Number(t.dataset.go));
  };
  tb.ondblclick = e => { const tr = e.target.closest('tr'); if (tr) API.post('/api/cue/select', { index: Number(tr.dataset.i) - 1 }); };
}
function renderLights() {
  const g = $('#lights'); g.innerHTML = '';
  for (const l of config.lights || []) {
    const s = state.lights[l.id] || {};
    const d = document.createElement('div'); d.className = 'light' + (s.on ? ' on' : ''); d.style.color = l.color;
    d.innerHTML = `<div class="name"><span class="dot" style="${s.on ? 'background:' + l.color : ''}"></span><span style="color:var(--text)">${esc(l.name)}</span></div>
      <div class="msg">${s.ok === false ? '⚠ ' : ''}${esc(s.message || '')}</div>
      <div class="btns"><button class="small ${s.on ? 'primary' : ''}" data-on="1">ON</button><button class="small ${s.on === false ? 'active' : ''}" data-on="0">OFF</button></div>`;
    d.querySelectorAll('button').forEach(b => b.onclick = () => setLight(l.id, b.dataset.on === '1'));
    g.appendChild(d);
  }
}
function renderSfx() {
  const g = $('#sfxList'); g.innerHTML = '';
  for (const s of sfx) {
    const b = document.createElement('button'); b.className = 'small sfxbtn'; b.dataset.id = s.id; b.textContent = '▶ ' + s.id;
    b.onclick = () => { const playing = state.playing.some(p => p.id === s.id); API.post('/api/sound', playing ? { action: 'stop', id: s.id } : { action: 'play', id: s.id, loop: false }).catch(err => toast(err.message, true)); };
    g.appendChild(b);
  }
}
function renderState() {
  // backdrop
  document.querySelectorAll('.bdcard').forEach(c => c.classList.toggle('active', c.dataset.id === state.backdrop));
  const bd = backdrops.find(b => b.id === state.backdrop);
  $('#curBackdrop').textContent = bd ? `${bd.num} ${bd.name}` : '암전';
  // cues
  const rows = document.querySelectorAll('#cueTable tbody tr');
  rows.forEach((tr, i) => { tr.className = i < state.cue ? 'done' : i === state.cue ? 'current' : i === state.cue + 1 ? 'next' : ''; });
  const cur = cues[state.cue], nxt = cues[state.cue + 1];
  $('#curCue').textContent = cur ? `큐 ${cur.no} · ${cur.scene} · ${cur.trigger}` : '아직 시작 전';
  $('#nextCue').textContent = nxt ? `큐 ${nxt.no} · ${nxt.scene} · ${nxt.trigger}` : '마지막 큐까지 끝났습니다';
  $('#goBtn').disabled = !nxt; $('#goBtn').textContent = nxt ? `GO ▶ 큐 ${nxt.no}` : '끝';
  const cr = rows[state.cue + 1]; if (cr) cr.scrollIntoView({ block: 'center', behavior: 'smooth' });
  // sounds
  const np = $('#nowPlaying');
  np.innerHTML = state.playing.length ? '<span style="color:var(--dim)">재생 중:</span>' + state.playing.map(p => `<button class="small sfxbtn playing" data-id="${p.id}">■ ${p.id}${p.loop ? ' (반복)' : ''}</button>`).join('') : '<span style="color:var(--dim)">재생 중: 없음</span>';
  np.querySelectorAll('button').forEach(b => b.onclick = () => API.post('/api/sound', { action: 'stop', id: b.dataset.id }));
  document.querySelectorAll('.sfxlist .sfxbtn, #cueTable .sfxbtn[data-sfx]').forEach(b => b.classList.toggle('playing', state.playing.some(p => p.id === (b.dataset.id || b.dataset.sfx))));
  renderLights();
  renderNarration();
}

async function show(id) { try { await API.post('/api/show', { backdrop: id }); } catch (e) { toast(e.message, true); } }
async function runCue(i) { try { const r = await API.post('/api/cue', { index: i }); toast(`큐 ${r.cue.no} 실행`); } catch (e) { toast(e.message, true); } }
async function setLight(id, on) {
  try { const r = await API.post('/api/lights/' + id, { on }); if (!r.ok) toast(`조명 ${id} 응답 실패: ${r.light.message}`, true); }
  catch (e) { toast(e.message, true); }
}
$('#goBtn').onclick = () => runCue(state.cue + 1);
$('#narrPlay').onclick = () => API.post('/api/narration', { action: 'start', index: state.narration.index < 0 ? 0 : state.narration.index }).catch(err => toast(err.message, true));
$('#narrStop').onclick = () => API.post('/api/narration', { action: 'stop' });
$('#narrNext').onclick = () => API.post('/api/narration', { action: 'next' });
$('#narrPrev').onclick = () => API.post('/api/narration', { action: 'prev' });
$('#blackBtn').onclick = () => show('black');
$('#stopAllBtn').onclick = () => API.post('/api/sound', { action: 'stopAll' });
$('#allOn').onclick = () => API.post('/api/lights', { on: true });
$('#allOff').onclick = () => API.post('/api/lights', { on: false });
$('#swStart').onclick = () => API.post('/api/stopwatch', { action: 'start' });
$('#swPause').onclick = () => API.post('/api/stopwatch', { action: 'pause' });
$('#swReset').onclick = () => { if (confirm('스톱워치를 0으로 되돌릴까요?')) API.post('/api/stopwatch', { action: 'reset' }); };
$('#openStage').onclick = () => window.open('/stage', 'prince-stage', 'popup=yes,width=1280,height=720');

document.addEventListener('keydown', e => {
  if (['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName)) return;
  if (e.code === 'Space' || e.code === 'Enter') { e.preventDefault(); if (cues[state.cue + 1]) runCue(state.cue + 1); }
  else if (e.code === 'Escape') API.post('/api/sound', { action: 'stopAll' });
  else if (e.key === 'b' || e.key === 'B') show('black');
  else if (e.key === 'n' || e.key === 'N') API.post('/api/narration', { action: 'next' });
  else if (e.key === 'p' || e.key === 'P') API.post('/api/narration', { action: state.narration.running ? 'stop' : 'start', index: state.narration.index < 0 ? 0 : state.narration.index });
  else if (e.code === 'ArrowDown') API.post('/api/cue/select', { index: Math.min(cues.length - 1, state.cue + 1) });
  else if (e.code === 'ArrowUp') API.post('/api/cue/select', { index: Math.max(-1, state.cue - 1) });
});

// stopwatch display, compared with the current cue's scheduled time
setInterval(() => {
  const sw = state.stopwatch; const ms = sw.running ? Date.now() - sw.startedAt : sw.elapsed;
  const el = $('#clock'); el.textContent = fmtClock(ms);
  const cur = cues[state.cue]; el.className = 'clock';
  if (cur && sw.running) { const sched = parseCueTime(cur.time); if (sched != null) { const d = ms - sched; if (d > 60000) el.className += ' behind'; else if (d < -60000) el.className += ' ahead'; } }
  $('#swStart').disabled = sw.running; $('#swPause').disabled = !sw.running;
}, 250);
