#!/usr/bin/env node
// Continuously sends move events in a circular pattern to keep the dot visible.
// Usage: node test/ws_stress.mjs [host] [port]
const net = require('net');
const crypto = require('crypto');

const HOST = process.argv[2] || '127.0.0.1';
const PORT = parseInt(process.argv[3] || '8080', 10);

const socket = new net.Socket();
socket.connect(PORT, HOST, () => {
  console.log(`Connecting to ws://${HOST}:${PORT}/laser`);
  const key = crypto.randomBytes(16).toString('base64');
  socket.write(`GET /laser HTTP/1.1\r\nHost: ${HOST}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: ${key}\r\nSec-WebSocket-Version: 13\r\n\r\n`);
});

let upgraded = false, buf = Buffer.alloc(0);

socket.on('data', (chunk) => {
  buf = Buffer.concat([buf, chunk]);
  if (!upgraded) {
    const idx = buf.indexOf('\r\n\r\n');
    if (idx === -1) return;
    const headers = buf.slice(0, idx).toString();
    if (!headers.includes('101')) { console.error('Handshake failed'); process.exit(1); }
    console.log('WebSocket connected');
    buf = buf.slice(idx + 4);
    upgraded = true;
    startCircle();
  }
});

function sendText(obj) {
  const payload = Buffer.from(JSON.stringify(obj));
  const mask = crypto.randomBytes(4);
  const header = payload.length < 126
    ? Buffer.from([0x81, 0x80 | payload.length])
    : payload.length < 65536
    ? Buffer.concat([Buffer.from([0x81, 0x80 | 126]), Buffer.from([payload.length >> 8, payload.length & 0xff])])
    : null;
  // For our small payloads, length < 126 always
  const masked = Buffer.concat([header || Buffer.alloc(0), mask, payload.map((b,i) => b ^ mask[i%4])]);
  socket.write(masked);
}

function startCircle() {
  let t = 0;
  const cx = 0.5, cy = 0.5, r = 0.3;
  console.log('Streaming circular pattern. Ctrl+C to stop.');
  setInterval(() => {
    t += 0.05;
    const x = cx + r * Math.cos(t);
    const y = cy + r * Math.sin(t);
    sendText({ type: 'move', x, y });
  }, 50);
}

socket.on('close', () => { console.log('Disconnected'); process.exit(0); });
socket.on('error', (e) => { console.error('Error:', e.message); process.exit(1); });