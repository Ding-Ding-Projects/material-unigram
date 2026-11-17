'use strict';

const $ = (id) => document.getElementById(id);
const STEPS = ['How to host', 'Check this computer', 'Settings', 'Start', 'Ready'];
const state = { step: 0, server: 'proxy', form: 'docker', checks: null, running: false, done: false, output: '', regex: false };

function renderSteps() {
  const list = $('stepList');
  list.replaceChildren();
  STEPS.forEach((label, i) => {
    const item = document.createElement('li');
    item.className = i === state.step ? 'on' : i < state.step ? 'done' : '';
    const mark = document.createElement('span');
    mark.className = 'mark';
    mark.textContent = i < state.step ? '✓' : String(i + 1);
    const text = document.createElement('span');
    text.textContent = label;
    item.append(mark, text);
    list.append(item);
  });
  for (const section of document.querySelectorAll('section[data-step]')) section.hidden = Number(section.dataset.step) !== state.step;
  $('back').disabled = state.step === 0 || state.running || state.step === 4;
  $('next').textContent = state.step === 2 ? 'Start' : state.step === 4 ? 'Finish' : 'Continue';
  $('next').disabled = state.running || (state.step === 1 && !checksPass()) || (state.step === 3 && !state.done);
}

function checksPass() {
  if (!state.checks) return false;
  if (state.form === 'wsl') return state.checks.wsl.ok;
  return state.checks.docker.ok;
}

async function runChecks() {
  const list = $('checks');
  list.replaceChildren();
  state.checks = await window.host.check();
  const rows = [];
  if (state.form !== 'wsl') rows.push(['Docker', state.checks.docker]);
  if (state.form === 'wsl') rows.push(['WSL', state.checks.wsl]);
  for (const [name, check] of rows) {
    const item = document.createElement('li');
    item.className = 'row';
    const label = document.createElement('span');
    label.className = 'grow';
    label.textContent = `${name}: ${check.detail}`;
    const tag = document.createElement('span');
    tag.className = check.ok ? 'tag ok' : 'tag hot';
    tag.textContent = check.ok ? 'Ready' : 'Needs attention';
    item.append(label, tag);
    list.append(item);
  }
  renderSteps();
}

function prepareSettings() {
  const full = state.server === 'full';
  if (!$('port').value) $('port').value = full ? '10443' : '443';
  $('portHelp').textContent = full
    ? 'Port Material Unigram connects to. Forward it on your router to use the server outside home.'
    : '443 looks like ordinary web traffic. Forward it on your router to use the proxy outside home.';
  $('tlsField').hidden = full;
}

function validSettings() {
  const port = Number($('port').value);
  if (!Number.isInteger(port) || port < 1 || port > 65535) return 'The port must be a number from 1 to 65535.';
  if ($('password').value.length < 8) return 'The dashboard password must be at least 8 characters.';
  if (state.form === 'wsl' && state.server === 'full') return 'The full server runs in Docker or as an appliance. Go back and choose one of those.';
  return '';
}

function renderOutput() {
  const query = $('outSearch').value;
  let lines = state.output.split('\n');
  $('outRegexState').hidden = !state.regex;
  if (query) {
    if (state.regex) {
      try {
        const re = new RegExp(query, 'i');
        lines = lines.filter((l) => re.test(l));
        $('outRegexState').textContent = `Valid pattern · ${lines.length} matching lines`;
      } catch (error) {
        $('outRegexState').textContent = `The pattern does not work: ${error.message}`;
      }
    } else {
      lines = lines.filter((l) => l.toLowerCase().includes(query.toLowerCase()));
    }
  }
  $('output').textContent = lines.join('\n');
  $('output').scrollTop = $('output').scrollHeight;
}

async function start() {
  state.running = true;
  state.done = false;
  state.output = '';
  renderSteps();
  $('startNote').textContent = state.form === 'appliance'
    ? 'Building the appliance image. This takes a while; the files appear in a folder when it is done.'
    : 'This can take a few minutes the first time. Windows may ask for approval.';
  await window.host.start({
    form: state.form,
    server: state.server,
    settings: { port: $('port').value, tlsDomain: $('tlsDomain').value.trim(), password: $('password').value }
  });
}

window.host.onOutput((text) => {
  state.output += text.replace(/\r/g, '');
  renderOutput();
});

window.host.onDone(async ({ code, outDir }) => {
  state.running = false;
  if (code !== 0) {
    state.output += `\nStopped with exit code ${code}. Nothing was reported as working; read the last lines above.`;
    renderOutput();
    renderSteps();
    return;
  }
  state.done = true;
  state.step = 4;
  if (state.form === 'appliance') {
    $('doneTitle').textContent = 'Your appliance image is ready';
    $('linkLabel').textContent = 'Image folder';
    $('link').textContent = outDir;
    $('openLink').hidden = true;
    $('dashboard').textContent = 'shown on the appliance screen after it boots';
    $('doneNote').textContent = 'Write the .img file to a USB stick or disk, or attach the .vhdx to a Hyper-V virtual machine (Generation 2, Secure Boot off).';
  } else {
    try {
      const { status, dashboard } = await window.host.result({ server: state.server, password: $('password').value });
      $('dashboard').textContent = dashboard;
      $('dashboard').onclick = (e) => { e.preventDefault(); window.host.open(dashboard); };
      if (state.server === 'full') {
        $('doneTitle').textContent = 'Your private server is ready';
        $('linkLabel').textContent = 'Server address and key fingerprint (enter these in Material Unigram)';
        $('link').textContent = `${status.host}:${status.gatewayPort} · fingerprint ${status.fingerprint}`;
        $('openLink').hidden = true;
      } else {
        $('doneTitle').textContent = 'Your Telegram proxy is ready';
        $('link').textContent = (status.links && status.links.tg) || 'not available';
        $('openLink').hidden = !(status.links && status.links.tg);
        $('openLink').onclick = () => window.host.open(status.links.tg);
      }
      $('doneNote').textContent = 'Checked just now: the dashboard answered on the network address.';
    } catch (error) {
      $('doneTag').className = 'tag warn';
      $('doneTag').textContent = 'Running, but the details could not be read';
      $('doneNote').textContent = error.message;
    }
  }
  renderSteps();
});

for (const button of document.querySelectorAll('.choice')) {
  button.addEventListener('click', () => {
    const key = button.dataset.server ? 'server' : 'form';
    state[key] = button.dataset[key];
    for (const other of document.querySelectorAll(`.choice[data-${key}]`)) other.setAttribute('aria-checked', String(other === button));
  });
}

$('copyLink').addEventListener('click', () => window.host.copy($('link').textContent));
$('suggest').addEventListener('click', async () => {
  $('password').type = 'text';
  $('password').value = await window.host.randomPassword();
});
$('recheck').addEventListener('click', runChecks);
$('outRegex').addEventListener('click', () => {
  state.regex = !state.regex;
  $('outRegex').setAttribute('aria-pressed', String(state.regex));
  $('outRegex').classList.toggle('on', state.regex);
  renderOutput();
});
$('outSearch').addEventListener('input', renderOutput);

$('back').addEventListener('click', () => { state.step = Math.max(0, state.step - 1); renderSteps(); });
$('next').addEventListener('click', async () => {
  if (state.step === 4) { window.close(); return; }
  if (state.step === 2) {
    const error = validSettings();
    $('settingsError').textContent = error;
    if (error) return;
    state.step = 3;
    renderSteps();
    await start();
    return;
  }
  state.step += 1;
  if (state.step === 1) await runChecks();
  if (state.step === 2) prepareSettings();
  renderSteps();
});

window.host.version().then((v) => { $('version').textContent = `Assistant v${v}`; });
renderSteps();
