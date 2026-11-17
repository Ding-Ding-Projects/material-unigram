'use strict';

// Material Unigram proxy dashboard: shows MTProxy's state and the share link to signed-in browsers.
// Plain Node, no dependencies. Started by entrypoint.sh after MTProxy.

const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const { createAuth } = require('./auth');
const { fetchStats, summarize, shareLinks, lanAddresses } = require('./proxy');
const full = require('./fullserver');
const { ensureServerKey } = require('./rsakey');

// proxy: MTProxy in this container. full: the Teamgram stack, checked over the Docker network.
const MODE = process.env.DASHBOARD_MODE === 'full' ? 'full' : 'proxy';
const KEYS_DIR = process.env.KEYS_DIR || '/keys';
if (MODE === 'full') {
  fs.mkdirSync(KEYS_DIR, { recursive: true });
  ensureServerKey(KEYS_DIR);
}

const VERSION = '0.1.0';
const STARTED_AT = new Date().toISOString();
const DATA_DIR = process.env.DATA_DIR || '/data';
const PORT = Number(process.env.DASHBOARD_PORT || 8080);
const PROXY_PORT = Number(process.env.PROXY_PORT || 443);
const TLS_DOMAIN = process.env.TLS_DOMAIN || '';
const publicDir = path.join(__dirname, 'public');

function log(message) {
  process.stdout.write(`${new Date().toTimeString().slice(0, 8)} dashboard ${message}\n`);
}

const auth = createAuth(process.env.DASHBOARD_PASSWORD);

const TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.svg': 'image/svg+xml' };
const SECURITY = {
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
  'X-Frame-Options': 'DENY',
  'Content-Security-Policy': "default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; connect-src 'self'; frame-ancestors 'none'"
};

function send(res, status, body, headers = {}) {
  res.writeHead(status, { ...SECURITY, 'Cache-Control': 'no-store', ...headers });
  res.end(body);
}

function json(res, status, value, headers = {}) {
  send(res, status, JSON.stringify(value), { 'Content-Type': 'application/json; charset=utf-8', ...headers });
}

function serve(res, file) {
  const resolved = path.normalize(path.join(publicDir, file));
  if (!resolved.startsWith(publicDir)) return send(res, 404, 'Not found');
  fs.readFile(resolved, (error, data) => {
    if (error) return send(res, 404, 'Not found');
    send(res, 200, data, { 'Content-Type': TYPES[path.extname(resolved)] || 'application/octet-stream' });
  });
}

function readBody(req, limit = 2048) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.setEncoding('utf8');
    req.on('data', (chunk) => {
      body += chunk;
      if (body.length > limit) { reject(new Error('too large')); req.destroy(); }
    });
    req.on('end', () => resolve(body));
    req.on('error', reject);
  });
}

function secret() {
  return fs.readFileSync(path.join(DATA_DIR, 'secret'), 'utf8').trim();
}

function publicHost() {
  return process.env.PUBLIC_HOST || lanAddresses()[0] || '';
}

function tailLog(lines = 200) {
  try {
    const text = fs.readFileSync(path.join(DATA_DIR, 'proxy.log'), 'utf8');
    return text.split('\n').filter(Boolean).slice(-lines);
  } catch {
    return [];
  }
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://local');
  const address = req.socket.remoteAddress || 'unknown';

  if (url.pathname === '/healthz') {
    const ok = MODE === 'full' ? (await full.serviceHealth()).allUp : (await fetchStats()).ok;
    return json(res, ok ? 200 : 503, { ok, version: VERSION, startedAt: STARTED_AT, proxyPort: PROXY_PORT });
  }

  if (['/theme.css', '/app.css', '/app.js', '/full.js', '/icon.svg', '/login.js'].includes(url.pathname)) {
    return serve(res, url.pathname.slice(1));
  }

  if (url.pathname === '/api/sign-in' && req.method === 'POST') {
    try {
      const { password } = JSON.parse(await readBody(req));
      const result = auth.signIn(address, password);
      if (!result.ok) {
        log(`sign-in refused from ${address}`);
        return json(res, 401, { error: result.reason });
      }
      log(`signed in from ${address}`);
      return json(res, 200, { ok: true }, { 'Set-Cookie': auth.cookie(result.token) });
    } catch {
      return json(res, 400, { error: 'Bad request.' });
    }
  }

  if (!auth.isSignedIn(req.headers.cookie)) {
    if (url.pathname.startsWith('/api/')) return json(res, 401, { error: 'Sign in first.' });
    return serve(res, 'login.html');
  }

  if (url.pathname === '/api/sign-out' && req.method === 'POST') {
    auth.signOut(req.headers.cookie);
    return json(res, 200, {}, { 'Set-Cookie': 'mup_session=; Path=/; Max-Age=0' });
  }

  if (url.pathname === '/api/status' && MODE === 'full') {
    const health = await full.serviceHealth();
    const key = full.serverKey(KEYS_DIR);
    return json(res, 200, {
      mode: 'full',
      version: VERSION,
      teamgramCommit: process.env.TEAMGRAM_COMMIT || 'unknown',
      startedAt: STARTED_AT,
      running: health.allUp,
      services: health.services,
      host: publicHost(),
      hostIsGuess: !process.env.PUBLIC_HOST,
      gatewayPort: Number(process.env.GATEWAY_PORT || 10443),
      publicKey: key && key.publicKey,
      fingerprint: key && key.fingerprint
    });
  }

  if (url.pathname === '/api/status') {
    const { ok, stats } = await fetchStats();
    const host = publicHost();
    let links = null;
    try {
      links = host ? shareLinks(host, PROXY_PORT, secret(), TLS_DOMAIN) : null;
    } catch (error) {
      log(`share link unavailable: ${error.message}`);
    }
    return json(res, 200, {
      mode: 'proxy',
      version: VERSION,
      mtproxyCommit: process.env.MTPROXY_COMMIT || 'unknown',
      startedAt: STARTED_AT,
      running: ok,
      summary: summarize(stats),
      host,
      hostIsGuess: !process.env.PUBLIC_HOST,
      proxyPort: PROXY_PORT,
      tlsDomain: TLS_DOMAIN || null,
      links
    });
  }

  if (url.pathname === '/api/log') {
    return json(res, 200, { lines: tailLog() });
  }

  if (url.pathname === '/' || url.pathname === '/index.html') {
    return serve(res, MODE === 'full' ? 'full.html' : 'index.html');
  }

  return send(res, 404, 'Not found');
});

server.listen(PORT, '0.0.0.0', () => {
  log(`listening on 0.0.0.0:${PORT}`);
  for (const lan of lanAddresses()) log(`open: http://${lan}:${PORT}/`);
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => { log('shutting down'); server.close(() => process.exit(0)); });
}
