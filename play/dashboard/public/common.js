// Shared: WebSocket connection with auto-reconnect, audio player, small helpers.
const API = {
  async post(url, body) {
    const r = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) });
    const j = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(j.error || r.statusText);
    return j;
  },
  async put(url, body) {
    const r = await fetch(url, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) });
    const j = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(j.error || r.statusText);
    return j;
  },
};
function connect(onMessage, onStatus) {
  let ws, timer;
  function open() {
    ws = new WebSocket((location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/ws');
    ws.onopen = () => onStatus && onStatus(true);
    ws.onclose = () => { onStatus && onStatus(false); timer = setTimeout(open, 1500); };
    ws.onerror = () => ws.close();
    ws.onmessage = e => { try { onMessage(JSON.parse(e.data)); } catch (err) { console.error(err); } };
  }
  open();
  return () => { clearTimeout(timer); ws && ws.close(); };
}
// Audio player: one <audio> per clip id; fade-out on stop when asked.
const Player = {
  clips: {}, enabled: false, unlocked: false,
  play(id, loop, kind) {
    if (!this.enabled) return;
    this.stop(id, false);
    const api = kind === 'voice' ? '/api/voice' : '/api/sound';
    const a = new Audio((kind === 'voice' ? '/voice/' : '/sfx/') + id + '.mp3');
    a.loop = !!loop; a.volume = 1;
    a.onended = () => { if (!a.loop) { delete this.clips[id]; API.post(api, { action: 'ended', id }).catch(() => {}); } };
    this.clips[id] = a;
    a.play().then(() => { this.unlocked = true; }).catch(err => { console.warn('autoplay blocked', err); window.onAudioBlocked && window.onAudioBlocked(); });
  },
  stop(id, fade) {
    const a = this.clips[id]; if (!a) return; delete this.clips[id];
    if (fade) { const step = () => { a.volume = Math.max(0, a.volume - 0.1); if (a.volume > 0) setTimeout(step, 60); else a.pause(); }; step(); }
    else a.pause();
  },
  stopAll() { for (const id of Object.keys(this.clips)) this.stop(id, true); },
  unlock() { // called from a user gesture so later programmatic plays are allowed
    const a = new Audio(); a.muted = true; a.play().catch(() => {}); this.unlocked = true;
  },
};
function fmtClock(ms) {
  const neg = ms < 0; ms = Math.abs(ms);
  const s = Math.floor(ms / 1000), m = Math.floor(s / 60);
  return (neg ? '-' : '') + String(m).padStart(2, '0') + ':' + String(s % 60).padStart(2, '0');
}
function parseCueTime(t) { // "-5:00" / "12:40" -> ms
  const m = /^(-)?(\d+):(\d\d)$/.exec(t.trim()); if (!m) return null;
  return (m[1] ? -1 : 1) * (Number(m[2]) * 60 + Number(m[3])) * 1000;
}
function toast(msg, err) {
  let el = document.querySelector('.toast');
  if (!el) { el = document.createElement('div'); el.className = 'toast'; document.body.appendChild(el); }
  el.textContent = msg; el.classList.toggle('err', !!err); el.classList.add('show');
  clearTimeout(el._t); el._t = setTimeout(() => el.classList.remove('show'), 2500);
}
function esc(s) { return String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])); }
