import Foundation

/// Embedded HTML client served at GET /
/// When the page is loaded from http://<mac-ip>:<port>/, the WebSocket
/// connects back to the same host:port — no manual IP entry needed.
enum ClientHTML {
    static let content: String = """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover"/>
<meta name="apple-mobile-web-app-capable" content="yes"/>
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent"/>
<meta name="mobile-web-app-capable" content="yes"/>
<title>RemoteLaser</title>
<style>
  :root { color-scheme: dark; --bg:#0e0e10; --panel:#1a1a1e; --line:#2c2c30; --fg:#eee; --dim:#888;
    --accent:#ff453a; --accent2:#ff6b5e; --ok:#4ade80; --warn:#f87171; --tap:#2a2a2e;
    --safe-t: env(safe-area-inset-top, 0px); --safe-b: env(safe-area-inset-bottom, 0px);
    --safe-l: env(safe-area-inset-left, 0px); --safe-r: env(safe-area-inset-right, 0px);
  }
  * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
  html, body {
    margin: 0; padding: 0; height: 100%; width: 100%;
    font: 15px -apple-system, system-ui, "SF Pro Text", sans-serif;
    background: var(--bg); color: var(--fg);
    touch-action: none; overscroll-behavior: none;
    user-select: none; -webkit-user-select: none;
    overflow: hidden; position: fixed; inset: 0;
  }
  body { display: flex; flex-direction: column;
    padding: var(--safe-t) var(--safe-r) var(--safe-b) var(--safe-l); }

  /* === Top bar === */
  #bar {
    flex: 0 0 auto; display: flex; align-items: center; gap: 8px;
    padding: 10px 14px; background: var(--panel);
    border-bottom: 1px solid var(--line);
  }
  #title { font-size: 15px; font-weight: 700; letter-spacing: -0.01em; white-space: nowrap; }
  #status { flex: 1; font-size: 11px; color: var(--dim); text-align: right;
    white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .icon-btn {
    flex: 0 0 auto; width: 38px; height: 38px; border-radius: 10px; border: 1px solid var(--line);
    background: var(--tap); color: var(--fg); font-size: 18px; padding: 0;
    display: flex; align-items: center; justify-content: center; font-weight: 700;
  }
  .icon-btn:active { background: #3a3a3e; }
  #connect {
    flex: 0 0 auto; min-width: 72px; height: 38px; border-radius: 10px;
    border: 1px solid var(--accent); background: var(--accent); color: #fff;
    font-weight: 700; font-size: 14px; padding: 0 14px;
  }
  #connect.connected { background: transparent; color: var(--accent); border-color: var(--accent); }

  /* === Settings sheet === */
  #sheet {
    flex: 0 0 auto; background: var(--panel); border-bottom: 1px solid var(--line);
    max-height: 0; overflow: hidden; transition: max-height .22s ease;
  }
  #sheet.open { max-height: 360px; }
  #sheetInner { padding: 12px 14px 14px; display: flex; flex-direction: column; gap: 12px; }
  .field { display: flex; align-items: center; gap: 10px; }
  .field label { flex: 0 0 76px; font-size: 12px; color: var(--dim); }
  .field input[type=range] { flex: 1; height: 28px; }
  .field .val { flex: 0 0 52px; font-size: 12px; text-align: right; color: var(--fg);
    font-variant-numeric: tabular-nums; }
  .field input[type=text], .field input[type=number] {
    flex: 1; height: 36px; border-radius: 8px; border: 1px solid var(--line);
    background: var(--tap); color: var(--fg); font: inherit; padding: 0 10px;
  }
  .toggle { display: flex; align-items: center; gap: 10px; cursor: pointer; }
  .toggle input { width: 18px; height: 18px; accent-color: var(--accent); }
  .toggle span { font-size: 13px; }

  /* === Stage === */
  #stage { flex: 1 1 auto; display: flex; flex-direction: column; min-height: 0; position: relative; }

  /* === Action row === */
  #actions {
    flex: 0 0 auto; display: flex; gap: 8px; padding: 12px 14px;
    background: var(--panel); border-top: 1px solid var(--line);
  }
  .act {
    flex: 1; height: 44px; border-radius: 12px; border: 1px solid var(--line);
    background: var(--tap); color: var(--fg); font: inherit; font-size: 13px;
    font-weight: 600; padding: 0; display: flex; align-items: center; justify-content: center;
  }
  .act:active { background: #3a3a3e; transform: scale(.97); }
  .act.danger { color: var(--warn); border-color: #5a2a30; }

  /* === Joystick === */
  #joyWrap {
    flex: 1 1 auto; display: flex; align-items: center; justify-content: center;
    position: relative; padding: 18px; min-height: 0;
  }
  #joyBase {
    width: min(72vw, 320px); aspect-ratio: 1; max-height: 60vh;
    border-radius: 50%; border: 2px solid #3a3a3e;
    background: radial-gradient(circle, #202024 0%, #16161a 70%);
    position: relative; touch-action: none;
    box-shadow: inset 0 2px 24px rgba(0,0,0,0.5), 0 0 0 1px rgba(255,255,255,0.03);
  }
  #joyBase::after {
    content: ""; position: absolute; inset: 30%; border-radius: 50%;
    border: 1px dashed #404044; pointer-events: none;
  }
  #joyKnob {
    position: absolute; width: 28%; height: 28%; left: 36%; top: 36%;
    border-radius: 50%;
    background: radial-gradient(circle at 35% 28%, var(--accent2), var(--accent));
    box-shadow: 0 6px 18px rgba(255,69,58,0.35), inset 0 1px 2px rgba(255,255,255,0.3);
    pointer-events: none; transition: left .08s, top .08s;
  }
  #joyHint {
    position: absolute; inset: 0; display: flex; align-items: center; justify-content: center;
    color: #4a4a4e; font-size: 13px; pointer-events: none; text-align: center;
    padding: 0 20%;
  }

  /* === Preview === */
  #preview {
    display: none; flex: 0 0 96px; margin: 0 14px 12px; border-radius: 12px;
    border: 1px solid var(--line); background: #141418; position: relative; overflow: hidden;
  }
  @media (min-width: 600px) { #preview { display: block; } }
  #previewDot {
    position: absolute; width: 14px; height: 14px; border-radius: 50%;
    background: radial-gradient(circle at 40% 30%, var(--accent2), var(--accent));
    transform: translate(-50%, -50%); pointer-events: none; box-shadow: 0 0 8px rgba(255,69,58,0.4);
  }
  #previewNote { position: absolute; inset: 0; display: flex; align-items: center;
    justify-content: center; font-size: 11px; color: var(--dim); pointer-events: none; }

  /* === Tap mode overlay === */
  #tapPad {
    display: none; flex: 1 1 auto; position: relative; margin: 14px;
    border-radius: 16px; border: 2px dashed var(--line); background: #141418;
    touch-action: none; overflow: hidden;
  }
  #tapPad.active { display: block; }
  #tapPadDot {
    position: absolute; width: 22px; height: 22px; border-radius: 50%;
    background: radial-gradient(circle at 40% 30%, var(--accent2), var(--accent));
    transform: translate(-50%, -50%); pointer-events: none;
    box-shadow: 0 0 14px rgba(255,69,58,0.5);
  }
  #tapPadHint { position: absolute; inset: 0; display: flex; align-items: center;
    justify-content: center; font-size: 13px; color: var(--dim); pointer-events: none;
    text-align: center; padding: 0 20%; }

  body.tap #joyWrap, body.tap #preview { display: none !important; }

  .live { color: var(--ok) !important; }
  .stopped { color: var(--warn) !important; }

  /* === Toast === */
  #toast {
    position: fixed; left: 50%; top: calc(var(--safe-t) + 14px);
    transform: translate(-50%, -20px); z-index: 999;
    max-width: 92vw; padding: 10px 14px; border-radius: 12px;
    background: rgba(38,16,18,0.96); border: 1px solid #6a2a30;
    color: #ff8a82; font-size: 12px; line-height: 1.35;
    pointer-events: none; opacity: 0;
    transition: opacity .25s ease, transform .25s ease;
    box-shadow: 0 8px 28px rgba(0,0,0,0.55);
    white-space: pre-wrap; word-break: break-word;
  }
  #toast.show { opacity: 1; transform: translate(-50%, 0); }
</style>
</head>
<body>

<div id="toast"></div>

<div id="bar">
  <span id="title">RemoteLaser</span>
  <span id="status">disconnected</span>
  <button id="gear" class="icon-btn" aria-label="settings">⋯</button>
  <button id="connect">Connect</button>
</div>

<div id="sheet">
  <div id="sheetInner">
    <div class="field">
      <label>Host</label>
      <input id="host" type="text" placeholder="mac LAN IP" autocapitalize="off" autocorrect="off" spellcheck="false">
    </div>
    <div class="field">
      <label>Port</label>
      <input id="port" type="number" inputmode="numeric">
    </div>
    <div class="field">
      <label>Speed</label>
      <input id="speed" type="range" min="0.05" max="2" step="0.05" value="0.8">
      <span class="val" id="speedV">0.80/s</span>
    </div>
    <div class="field">
      <label>Deadzone</label>
      <input id="dead" type="range" min="0" max="0.5" step="0.01" value="0.08">
      <span class="val" id="deadV">0.08</span>
    </div>
    <div class="field">
      <label>Send rate</label>
      <input id="rate" type="range" min="10" max="120" step="5" value="60">
      <span class="val" id="rateV">60Hz</span>
    </div>
    <label class="toggle">
      <input type="checkbox" id="tapMode">
      <span>Tap-to-position mode (tap the screen to move the dot directly)</span>
    </label>
  </div>
</div>

<div id="stage">
  <div id="joyWrap">
    <div id="joyBase">
      <div id="joyKnob"></div>
      <div id="joyHint">drag the knob to fly the laser</div>
    </div>
  </div>

  <div id="preview">
    <div id="previewNote">screen preview</div>
    <div id="previewDot"></div>
  </div>

  <div id="tapPad">
    <div id="tapPadHint">tap or drag anywhere to position the laser</div>
    <div id="tapPadDot"></div>
  </div>
</div>

<div id="actions">
  <button class="act" id="sweep">Sweep</button>
  <button class="act" id="center">Center</button>
  <button class="act danger" id="hide">Hide</button>
</div>

<script>
const $ = (id) => document.getElementById(id);
const bar = $('bar'), status = $('status'), gear = $('gear'), connect = $('connect');
const sheet = $('sheet');
const hostEl = $('host'), portEl = $('port');
const speedEl = $('speed'), speedV = $('speedV');
const deadEl = $('dead'), deadV = $('deadV');
const rateEl = $('rate'), rateV = $('rateV');
const tapModeEl = $('tapMode');
const joyBase = $('joyBase'), joyKnob = $('joyKnob'), joyHint = $('joyHint');
const preview = $('preview'), previewDot = $('previewDot');
const tapPad = $('tapPad'), tapPadDot = $('tapPadDot'), tapPadHint = $('tapPadHint');
const sweepBtn = $('sweep'), centerBtn = $('center'), hideBtn = $('hide');

// Auto-detect host and port from the page URL when served by RemoteLaser
// This is the key fix: when the browser loads this page from http://<mac-ip>:8080/,
// location.hostname and location.port give us the right values automatically.
const servedByServer = location.protocol.startsWith('http') && location.hostname !== '';
if (servedByServer) {
  hostEl.value = location.hostname;
  portEl.value = location.port || '8080';
  // Auto-connect after a short delay when served by the server
  setTimeout(() => connect.click(), 300);
} else {
  hostEl.value = '127.0.0.1';
  portEl.value = '8080';
}

let ws = null;
let dotX = 0.5, dotY = 0.5;
let stickX = 0, stickY = 0;
let joyActive = false;
let sweepTimer = null;
let pumpTimer = null, lastPump = 0;

// === Toast ===
const toast = $('toast');
let toastTimer = null;
function showToast(msg, ms = 4500) {
  toast.textContent = msg;
  toast.classList.add('show');
  if (toastTimer) clearTimeout(toastTimer);
  if (ms > 0) toastTimer = setTimeout(() => toast.classList.remove('show'), ms);
}
window.addEventListener('error', (e) => {
  const m = e.error && e.error.stack ? e.error.stack : (e.message || 'Unknown error');
  showToast('JS error: ' + m);
});
window.addEventListener('unhandledrejection', (e) => {
  showToast('Promise reject: ' + (e.reason && e.reason.message ? e.reason.message : (e.reason || '?')));
});

const clamp = (v, lo, hi) => Math.min(Math.max(v, lo), hi);
const speed = () => parseFloat(speedEl.value);
const deadzone = () => parseFloat(deadEl.value);
const rate = () => parseInt(rateEl.value, 10);

speedEl.addEventListener('input', () => speedV.textContent = parseFloat(speedEl.value).toFixed(2) + '/s');
deadEl.addEventListener('input', () => deadV.textContent = deadEl.value);
rateEl.addEventListener('input', () => rateV.textContent = rateEl.value + 'Hz');

// === Settings toggle ===
gear.addEventListener('click', () => sheet.classList.toggle('open'));
// Only auto-open settings if NOT served by server (user needs to enter IP manually)
if (!servedByServer) sheet.classList.add('open');

// === Connect ===
connect.addEventListener('click', () => {
  if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) {
    ws.close();
    return;
  }
  const host = hostEl.value.trim() || '127.0.0.1';
  const port = parseInt(portEl.value, 10) || 8080;
  let url = `ws://${host}:${port}/laser`;
  if (location.origin.startsWith('https') && !url.startsWith('wss')) {
    showToast('Page is HTTPS but WebSocket is ws://. Mixed content will be blocked.\\nOpen http://' + host + ':' + port + '/ instead.');
  }
  setStatus('connecting…');
  try {
    ws = new WebSocket(url);
  } catch (err) {
    showToast('WebSocket() threw: ' + (err && err.message ? err.message : err));
    setStatus('error');
    return;
  }
  ws.onopen = () => {
    setStatus('connected');
    toast.classList.remove('show');
    connect.textContent = 'Stop';
    connect.classList.add('connected');
    sendMove(dotX, dotY);
  };
  ws.onmessage = (e) => {
    try {
      const m = JSON.parse(e.data);
      if (m.type === 'ready') setStatus(`screen ${m.screen.w}×${m.screen.h}`);
    } catch (err) {
      showToast('Bad server msg: ' + (err && err.message ? err.message : err));
    }
  };
  ws.onclose = (e) => {
    setStatus('disconnected');
    connect.textContent = 'Connect';
    connect.classList.remove('connected');
    ws = null; stopPump();
    let reason = '';
    switch (e.code) {
      case 1000: reason = 'normal close'; break;
      case 1006: reason = 'abnormal close (server unreachable / refused / mixed content)'; break;
      case 1015: reason = 'TLS handshake failed'; break;
      case 1005: reason = 'no status received'; break;
      default: reason = 'code ' + e.code + (e.reason ? ' — ' + e.reason : '');
    }
    if (e.code !== 1000) showToast('WebSocket closed: ' + reason, 6000);
  };
  ws.onerror = (e) => {
    let hint = '';
    if (location.protocol === 'https:') hint = 'Page is https → ws:// blocked (mixed content). Use http://.';
    else if (location.protocol === 'file:') hint = 'file:// + ws:// may be blocked on mobile. Open http://' + hostEl.value.trim() + ':' + portEl.value + '/ in your browser instead.';
    else hint = 'Could be firewall, wrong IP/port, or server not running.';
    showToast('WebSocket error: ' + hint, 6000);
    setStatus('error');
  };
});
function setStatus(t) { status.textContent = t; }

function sendMove(x, y) {
  if (!ws || ws.readyState !== WebSocket.OPEN) return;
  ws.send(JSON.stringify({ type: 'move', x, y }));
}
function sendHide() {
  if (!ws || ws.readyState !== WebSocket.OPEN) return;
  ws.send(JSON.stringify({ type: 'hide' }));
}

// === Preview update ===
function updatePreview() {
  const r = preview.getBoundingClientRect();
  previewDot.style.left = (dotX * r.width) + 'px';
  previewDot.style.top = (dotY * r.height) + 'px';
}
function updateTapDot() {
  const r = tapPad.getBoundingClientRect();
  tapPadDot.style.left = (dotX * r.width) + 'px';
  tapPadDot.style.top = (dotY * r.height) + 'px';
}
function refreshDotVisuals() {
  if (tapModeEl.checked) updateTapDot(); else updatePreview();
}

// === Joystick ===
let joyPointerId = null, joyRect = null;
joyBase.addEventListener('pointerdown', (e) => {
  if (tapModeEl.checked) return;
  if (joyPointerId !== null) return;
  joyPointerId = e.pointerId;
  joyBase.setPointerCapture(e.pointerId);
  joyRect = joyBase.getBoundingClientRect();
  joyActive = true;
  joyHint.style.display = 'none';
  if (navigator.vibrate) navigator.vibrate(10);
  moveKnob(e);
});
joyBase.addEventListener('pointermove', (e) => {
  if (e.pointerId !== joyPointerId) return;
  moveKnob(e);
});
function endJoy(e) {
  if (e.pointerId !== joyPointerId) return;
  joyPointerId = null;
  joyActive = false;
  stickX = 0; stickY = 0;
  joyKnob.style.left = '36%'; joyKnob.style.top = '36%';
  sendMove(dotX, dotY);
  stopPump();
}
joyBase.addEventListener('pointerup', endJoy);
joyBase.addEventListener('pointercancel', endJoy);
joyBase.addEventListener('lostpointercapture', endJoy);

function moveKnob(e) {
  const cx = joyRect.left + joyRect.width / 2;
  const cy = joyRect.top + joyRect.height / 2;
  const r = Math.min(joyRect.width, joyRect.height) / 2;
  let dx = (e.clientX - cx) / r;
  let dy = (e.clientY - cy) / r;
  const mag = Math.hypot(dx, dy);
  if (mag > 1) { dx /= mag; dy /= mag; }
  const dz = deadzone();
  let sx = dx, sy = dy;
  if (Math.hypot(sx, sy) < dz) { sx = 0; sy = 0; }
  stickX = sx; stickY = sy;
  joyKnob.style.left = (50 + sx * 40 - 14) + '%';
  joyKnob.style.top = (50 + sy * 40 - 14) + '%';
  startPump();
}

// === Tap-to-position mode ===
tapPad.addEventListener('pointerdown', (e) => {
  if (!tapModeEl.checked) return;
  tapPad.setPointerCapture(e.pointerId);
  tapTapMove(e);
});
tapPad.addEventListener('pointermove', (e) => {
  if (!tapModeEl.checked || e.buttons === 0) return;
  tapTapMove(e);
});
function tapTapMove(e) {
  const r = tapPad.getBoundingClientRect();
  dotX = clamp((e.clientX - r.left) / r.width, 0, 1);
  dotY = clamp((e.clientY - r.top) / r.height, 0, 1);
  updateTapDot();
  tapPadHint.style.display = 'none';
  sendMove(dotX, dotY);
}
tapModeEl.addEventListener('change', () => {
  if (tapModeEl.checked) {
    document.body.classList.add('tap');
    tapPad.classList.add('active');
    updateTapDot();
  } else {
    document.body.classList.remove('tap');
    tapPad.classList.remove('active');
    updatePreview();
  }
});

// === Velocity pump ===
function startPump() {
  if (pumpTimer !== null) return;
  const dt = 1000 / rate();
  lastPump = performance.now();
  pumpTimer = setInterval(tickPump, dt);
}
function stopPump() {
  if (pumpTimer !== null) { clearInterval(pumpTimer); pumpTimer = null; }
}
function tickPump() {
  if (sweepTimer) return;
  const now = performance.now();
  const dt = Math.min(0.05, (now - lastPump) / 1000);
  lastPump = now;
  dotX = clamp(dotX + stickX * speed() * dt, 0, 1);
  dotY = clamp(dotY + stickY * speed() * dt, 0, 1);
  sendMove(dotX, dotY);
  updatePreview();
}

// === Sweep demo ===
sweepBtn.addEventListener('click', () => {
  if (!ws || ws.readyState !== WebSocket.OPEN) { setStatus('connect first'); return; }
  if (sweepTimer) { clearInterval(sweepTimer); sweepTimer = null; sweepBtn.textContent = 'Sweep'; stopPump(); return; }
  let t = 0;
  startPump();
  sweepTimer = setInterval(() => {
    t += 0.1;
    dotX = 0.5 + 0.45 * Math.sin(t);
    dotY = 0.5 + 0.30 * Math.cos(t * 1.3);
    updatePreview();
    sendMove(dotX, dotY);
    if (t > 4 * Math.PI) { clearInterval(sweepTimer); sweepTimer = null; sweepBtn.textContent = 'Sweep'; stopPump(); }
  }, 50);
  sweepBtn.textContent = 'Stop';
});

centerBtn.addEventListener('click', () => {
  dotX = 0.5; dotY = 0.5;
  refreshDotVisuals();
  sendMove(dotX, dotY);
});

hideBtn.addEventListener('click', () => {
  sendHide();
});

document.addEventListener('contextmenu', (e) => e.preventDefault());
document.addEventListener('gesturestart', (e) => e.preventDefault());

window.addEventListener('resize', refreshDotVisuals);
refreshDotVisuals();
</script>
</body>
</html>
"""
}
