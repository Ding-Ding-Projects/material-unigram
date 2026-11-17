'use strict';

// Reading MTProxy's state and building share links. Kept free of I/O where possible so the
// self-test can check it without a running proxy.

const http = require('node:http');
const os = require('node:os');

/** MTProxy's /stats page is "key<TAB>value" lines; returns them as an object. */
function parseStats(text) {
  const stats = {};
  for (const line of String(text).split('\n')) {
    const tab = line.indexOf('\t');
    if (tab <= 0) continue;
    stats[line.slice(0, tab).trim()] = line.slice(tab + 1).trim();
  }
  return stats;
}

/** Picks the numbers the dashboard shows, tolerating keys a given MTProxy build does not have. */
function summarize(stats) {
  const number = (key) => (stats[key] !== undefined && !Number.isNaN(Number(stats[key])) ? Number(stats[key]) : null);
  return {
    connections: number('total_special_connections') ?? number('active_connections') ?? number('total_connections'),
    // This MTProxy build reports the live routes to Telegram as active_targets; ready_targets
    // stays at 0 until clients use them, so active is the honest "routes up" number.
    activeTargets: number('active_targets'),
    readyTargets: number('ready_targets'),
    totalTargets: number('total_targets'),
    uptimeSeconds: number('uptime'),
    bytesIn: number('tot_bytes_received') ?? number('total_bytes_received'),
    bytesOut: number('tot_bytes_sent') ?? number('total_bytes_sent'),
    version: stats.version || null
  };
}

function fetchStats(port = 8888, timeoutMs = 2000) {
  return new Promise((resolve) => {
    const req = http.get({ host: '127.0.0.1', port, path: '/stats', timeout: timeoutMs }, (res) => {
      let body = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => { body += chunk; if (body.length > 262144) req.destroy(); });
      res.on('end', () => resolve({ ok: res.statusCode === 200, stats: parseStats(body) }));
    });
    req.on('timeout', () => { req.destroy(); resolve({ ok: false, stats: {} }); });
    req.on('error', () => resolve({ ok: false, stats: {} }));
  });
}

/**
 * The secret clients put in their link. With a TLS domain the proxy disguises itself as HTTPS:
 * "ee" + secret + hex(domain). Otherwise "dd" + secret turns on random padding.
 */
function clientSecret(secret, tlsDomain) {
  if (!/^[0-9a-f]{32}$/.test(secret)) throw new Error('The stored secret is not 32 hex characters.');
  if (tlsDomain) return 'ee' + secret + Buffer.from(tlsDomain, 'utf8').toString('hex');
  return 'dd' + secret;
}

function shareLinks(host, port, secret, tlsDomain) {
  const client = clientSecret(secret, tlsDomain);
  const query = `server=${encodeURIComponent(host)}&port=${encodeURIComponent(port)}&secret=${client}`;
  return { tg: `tg://proxy?${query}`, https: `https://t.me/proxy?${query}` };
}

function lanAddresses() {
  const result = [];
  for (const list of Object.values(os.networkInterfaces())) {
    for (const item of list || []) {
      if (item.family === 'IPv4' && !item.internal && !item.address.startsWith('172.17.')) result.push(item.address);
    }
  }
  return result;
}

module.exports = { parseStats, summarize, fetchStats, clientSecret, shareLinks, lanAddresses };
