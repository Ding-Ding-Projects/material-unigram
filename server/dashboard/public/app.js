'use strict';

// Dashboard client: polls /api/status and /api/log, renders the share link, live numbers, a small
// connections chart, and a log view filtered by plain text or by the regex builder.

const $ = (id) => document.getElementById(id);
const history = [];
let regexMode = false;
let lastLines = [];

function formatUptime(seconds) {
  if (seconds == null) return '-';
  const d = Math.floor(seconds / 86400);
  const h = Math.floor((seconds % 86400) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return d ? `${d} d ${h} h` : h ? `${h} h ${m} min` : `${m} min`;
}

function drawChart() {
  const values = history.slice(-60);
  if (values.length < 2) return;
  const max = Math.max(1, ...values);
  const step = 500 / (values.length - 1);
  const points = values.map((v, i) => `${(i * step).toFixed(1)} ${(130 - (v / max) * 120).toFixed(1)}`);
  $('chartLine').setAttribute('d', 'M' + points.join(' L'));
}

async function refreshStatus() {
  let status;
  try {
    const res = await fetch('/api/status', { cache: 'no-store' });
    if (res.status === 401) { location.reload(); return; }
    status = await res.json();
  } catch {
    $('status-title').textContent = 'The dashboard cannot reach the server';
    $('statusTag').className = 'tag hot';
    $('statusTag').textContent = 'Offline';
    return;
  }

  $('provenance').textContent = `v${status.version} · MTProxy ${String(status.mtproxyCommit).slice(0, 7)} · started ${new Date(status.startedAt).toLocaleString()}`;
  $('status-title').textContent = status.running ? 'Your proxy is running' : 'The proxy is not answering';
  $('statusTag').className = status.running ? 'tag ok' : 'tag hot';
  $('statusTag').textContent = status.running ? 'Healthy' : 'Not answering yet';
  $('liveTag').hidden = !status.running;

  const s = status.summary || {};
  $('connections').textContent = s.connections ?? '-';
  $('uptime').textContent = formatUptime(s.uptimeSeconds);
  $('targets').textContent = s.activeTargets != null ? `${s.activeTargets} active` : '-';
  $('host').textContent = status.host || 'unknown';
  $('port').textContent = status.proxyPort;
  $('disguise').textContent = status.tlsDomain ? `Looks like HTTPS to ${status.tlsDomain}` : 'Random padding';
  $('hostNote').textContent = status.hostIsGuess
    ? 'The address is this computer\'s local address. For use outside home, set PUBLIC_HOST and forward the port on your router.'
    : '';

  if (!status.host) {
    $('tgLink').textContent = 'Set the address first';
    $('hostNote').textContent = 'The proxy does not know which address to put in the link. Start it with host.bat or the host assistant, or set PUBLIC_HOST.';
  }

  if (status.links && status.links.tg) {
    $('tgLink').textContent = status.links.tg;
    $('copyLink').disabled = false;
    $('openLink').href = status.links.tg;
    $('openLink').removeAttribute('aria-disabled');
  }

  if (s.connections != null) {
    history.push(s.connections);
    drawChart();
  }
}

function filterLines(lines) {
  const query = $('search').value;
  if (!query) return { lines, valid: true };
  if (!regexMode) return { lines: lines.filter((l) => l.toLowerCase().includes(query.toLowerCase())), valid: true };
  try {
    const flags = ($('flagI').checked ? 'i' : '') + ($('flagU').checked ? 'u' : '');
    const re = new RegExp(query, flags);
    return { lines: lines.filter((l) => re.test(l)), valid: true };
  } catch (error) {
    return { lines, valid: false, message: error.message };
  }
}

function renderLog() {
  const { lines, valid, message } = filterLines(lastLines);
  $('log').textContent = lines.join('\n');
  $('logCount').textContent = `${lines.length} of ${lastLines.length} lines`;
  if (regexMode) {
    $('regexState').className = valid ? 'tag ok' : 'tag hot';
    $('regexState').textContent = valid ? 'Valid' : 'Not valid';
    $('regexExplain').textContent = valid
      ? (lines.length ? `${lines.length} matching lines. The pattern runs in this browser only.` : 'No lines match.')
      : `The pattern does not work: ${message}`;
  }
}

async function refreshLog() {
  try {
    const res = await fetch('/api/log', { cache: 'no-store' });
    if (!res.ok) return;
    lastLines = (await res.json()).lines || [];
    renderLog();
  } catch { /* the status poll reports the outage */ }
}

$('copyLink').addEventListener('click', async () => {
  await navigator.clipboard.writeText($('tgLink').textContent);
  $('copyLink').textContent = 'Copied';
  setTimeout(() => { $('copyLink').textContent = 'Copy'; }, 1500);
});

$('regexToggle').addEventListener('click', () => {
  regexMode = !regexMode;
  $('regexToggle').setAttribute('aria-pressed', String(regexMode));
  $('regexToggle').classList.toggle('on', regexMode);
  $('regexPanel').hidden = !regexMode;
  renderLog();
});

for (const id of ['search', 'flagI', 'flagU']) $(id).addEventListener('input', renderLog);

$('signOut').addEventListener('click', async () => {
  await fetch('/api/sign-out', { method: 'POST' });
  location.reload();
});

refreshStatus();
refreshLog();
setInterval(refreshStatus, 5000);
setInterval(refreshLog, 5000);
