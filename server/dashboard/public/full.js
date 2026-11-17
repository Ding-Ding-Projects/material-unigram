'use strict';

// Full-server dashboard: service health, the address clients use, and the server key.

const $ = (id) => document.getElementById(id);
let regexMode = false;
let lastServices = [];
let publicKey = '';

function matches(service) {
  const query = $('search').value;
  if (!query) return true;
  const text = `${service.name} ${service.id}`;
  if (!regexMode) return text.toLowerCase().includes(query.toLowerCase());
  try {
    const re = new RegExp(query, $('flagI').checked ? 'i' : '');
    $('regexState').className = 'tag ok';
    $('regexState').textContent = 'Valid';
    $('regexExplain').textContent = 'The pattern runs in this browser only.';
    return re.test(text);
  } catch (error) {
    $('regexState').className = 'tag hot';
    $('regexState').textContent = 'Not valid';
    $('regexExplain').textContent = `The pattern does not work: ${error.message}`;
    return true;
  }
}

function renderServices() {
  const list = $('services');
  list.replaceChildren();
  for (const service of lastServices.filter(matches)) {
    const item = document.createElement('li');
    item.className = 'row';
    const name = document.createElement('span');
    name.className = 'grow';
    name.textContent = service.name + (service.clientFacing ? ' · used by clients' : '');
    const tag = document.createElement('span');
    tag.className = service.up ? 'tag ok' : 'tag hot';
    tag.textContent = service.up ? `Up · ${service.ms} ms` : 'Not answering';
    item.append(name, tag);
    list.append(item);
  }
}

async function refresh() {
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

  $('provenance').textContent = `v${status.version} · Teamgram ${String(status.teamgramCommit).slice(0, 7)} · started ${new Date(status.startedAt).toLocaleString()}`;
  const up = status.services.filter((s) => s.up).length;
  $('status-title').textContent = status.running ? 'Your server is running' : 'Some services are not answering yet';
  $('statusTag').className = status.running ? 'tag ok' : 'tag warn';
  $('statusTag').textContent = status.running ? 'Healthy' : 'Starting or degraded';
  $('upCount').textContent = `${up} of ${status.services.length} up`;
  $('host').textContent = status.host || 'unknown';
  $('port').textContent = status.gatewayPort;
  $('fingerprint').textContent = status.fingerprint || 'not made yet';
  publicKey = status.publicKey || '';
  $('copyKey').disabled = !publicKey;
  $('hostNote').textContent = status.hostIsGuess
    ? 'The address is this computer\'s local address. For use outside home, set PUBLIC_HOST and forward the port on your router.'
    : '';

  lastServices = status.services;
  renderServices();
}

$('copyKey').addEventListener('click', async () => {
  await navigator.clipboard.writeText(publicKey);
  $('copyKey').textContent = 'Copied';
  setTimeout(() => { $('copyKey').textContent = 'Copy public key'; }, 1500);
});

$('regexToggle').addEventListener('click', () => {
  regexMode = !regexMode;
  $('regexToggle').setAttribute('aria-pressed', String(regexMode));
  $('regexToggle').classList.toggle('on', regexMode);
  $('regexPanel').hidden = !regexMode;
  renderServices();
});
for (const id of ['search', 'flagI']) $(id).addEventListener('input', renderServices);

$('signOut').addEventListener('click', async () => {
  await fetch('/api/sign-out', { method: 'POST' });
  location.reload();
});

refresh();
setInterval(refresh, 5000);
