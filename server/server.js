const { WebSocketServer, WebSocket } = require('ws');

const PORT = process.env.PORT || 8080;
const wss = new WebSocketServer({ port: PORT });
const history = [];          // letzte 50 Nachrichten
const MAX_HISTORY = 50;

function broadcast(obj) {
  const data = JSON.stringify(obj);
  for (const client of wss.clients) {
    if (client.readyState === WebSocket.OPEN) client.send(data);
  }
}

wss.on('connection', (ws) => {
  ws.send(JSON.stringify({ type: 'history', messages: history }));
  broadcast({ type: 'online', count: wss.clients.size });

  ws.on('message', (raw) => {
    let m;
    try { m = JSON.parse(raw.toString()); } catch { return; }
    if (m.type !== 'msg') return;
    const user = String(m.user || '').trim().slice(0, 24);
    const text = String(m.text || '').trim().slice(0, 2000);
    if (!user || !text) return;
    const msg = { type: 'msg', user, text, time: Date.now() };
    history.push(msg);
    if (history.length > MAX_HISTORY) history.shift();
    broadcast(msg);
  });

  ws.on('close', () => broadcast({ type: 'online', count: wss.clients.size }));
});

console.log(`Messenger-Server läuft auf Port ${PORT}`);
