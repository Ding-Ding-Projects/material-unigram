'use strict';

// Main process: copies the bundled server files to a folder the assistant owns, checks this
// computer, writes settings, runs the same host scripts the repository ships, and reads the
// result back from the dashboard.

const { app, BrowserWindow, ipcMain, shell, clipboard } = require('electron');
const { spawn, execFile } = require('node:child_process');
const crypto = require('node:crypto');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');

const VERSION = app.getVersion();
const workDir = path.join(process.env.LOCALAPPDATA || os.homedir(), 'MaterialUnigramHost');
let win = null;

function bundleDir() {
  return app.isPackaged ? path.join(process.resourcesPath, 'bundle') : path.join(__dirname, '..', '..');
}

/** Copies server, scripts and appliance into workDir, keeping any settings already there. */
function prepareWorkDir() {
  const source = bundleDir();
  const copy = (from, to) => {
    if (!fs.existsSync(from)) return;
    fs.cpSync(from, to, {
      recursive: true,
      force: true,
      filter: (src) => !/[\\/]\.env$/.test(src) && !/[\\/](\.build|out)([\\/]|$)/.test(src)
    });
  };
  fs.mkdirSync(workDir, { recursive: true });
  copy(path.join(source, 'server'), path.join(workDir, 'server'));
  copy(path.join(source, 'appliance'), path.join(workDir, 'appliance'));
  fs.mkdirSync(path.join(workDir, 'scripts'), { recursive: true });
  for (const script of ['host.ps1', 'go-host.ps1']) {
    const from = path.join(source, 'scripts', script);
    if (fs.existsSync(from)) fs.copyFileSync(from, path.join(workDir, 'scripts', script));
  }
}

function run(command, args, options = {}) {
  return new Promise((resolve) => {
    execFile(command, args, { windowsHide: true, timeout: 20000, ...options }, (error, stdout, stderr) => {
      resolve({ ok: !error, stdout: String(stdout || ''), stderr: String(stderr || '') });
    });
  });
}

async function checkComputer() {
  const docker = await run('docker', ['info', '--format', '{{.ServerVersion}}']);
  const wsl = await run('wsl.exe', ['--status']);
  return {
    docker: docker.ok ? { ok: true, detail: `Docker ${docker.stdout.trim()} is running` } : { ok: false, detail: 'Docker Desktop is not running or not installed.' },
    wsl: wsl.ok ? { ok: true, detail: 'WSL is available' } : { ok: false, detail: 'WSL is not available. Turn on "Windows Subsystem for Linux".' },
    freeGb: Math.round(os.freemem() / 1e9)
  };
}

function envPath(server) {
  return server === 'full' ? path.join(workDir, 'server', 'full', '.env') : path.join(workDir, 'server', '.env');
}

function writeSettings(server, settings) {
  const file = envPath(server);
  const lines = fs.existsSync(file) ? fs.readFileSync(file, 'utf8').split(/\r?\n/) : [];
  const set = (name, value) => {
    if (value === undefined || value === null) return;
    const index = lines.findIndex((line) => line.startsWith(`${name}=`));
    const entry = `${name}=${value}`;
    if (index >= 0) lines[index] = entry; else lines.push(entry);
  };
  if (/[\r\n]/.test(settings.password || '') || (settings.password || '').length < 8) {
    throw new Error('The dashboard password must be at least 8 characters, on one line.');
  }
  set('DASHBOARD_PASSWORD', settings.password);
  if (server === 'full') {
    set('GATEWAY_PORT', settings.port || '10443');
  } else {
    set('PROXY_PORT', settings.port || '443');
    set('TLS_DOMAIN', settings.tlsDomain || '');
  }
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, lines.filter((line, i) => line || i < lines.length - 1).join('\n') + '\n', { mode: 0o600 });
}

function startHosting(event, { form, server, settings }) {
  prepareWorkDir();
  writeSettings(server, settings);

  let command;
  let args;
  if (form === 'wsl') {
    if (server === 'full') throw new Error('The full server runs in Docker or as an appliance; the WSL form hosts the proxy.');
    args = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(workDir, 'scripts', 'go-host.ps1'), '-Mode', 'start'];
  } else if (form === 'appliance') {
    args = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(workDir, 'appliance', 'build.ps1'), '-Variant', server];
  } else {
    args = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(workDir, 'scripts', 'host.ps1'), '-Mode', 'detached', '-Server', server];
  }
  command = 'powershell.exe';

  const child = spawn(command, args, { cwd: workDir, windowsHide: true });
  const send = (text) => { if (!event.sender.isDestroyed()) event.sender.send('host:output', text); };
  child.stdout.on('data', (chunk) => send(chunk.toString('utf8')));
  child.stderr.on('data', (chunk) => send(chunk.toString('utf8')));
  child.on('close', (code) => { if (!event.sender.isDestroyed()) event.sender.send('host:done', { code, outDir: path.join(workDir, 'appliance', 'out') }); });
  return { started: true };
}

function dashboardRequest(port, pathName, { method = 'GET', body = null, cookie = null } = {}) {
  return new Promise((resolve, reject) => {
    const req = http.request({ host: '127.0.0.1', port, path: pathName, method, timeout: 5000, headers: { 'Content-Type': 'application/json', ...(cookie ? { Cookie: cookie } : {}) } }, (res) => {
      let data = '';
      res.on('data', (c) => { data += c; });
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: data }));
    });
    req.on('error', reject);
    req.on('timeout', () => req.destroy(new Error('timeout')));
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function readResult(_event, { server, password }) {
  const file = envPath(server);
  const values = Object.fromEntries((fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '').split(/\r?\n/).filter((l) => l.includes('=')).map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1)]));
  const port = Number(values.DASHBOARD_HOST_PORT || (server === 'full' ? 8081 : 8080));
  const signIn = await dashboardRequest(port, '/api/sign-in', { method: 'POST', body: { password } });
  if (signIn.status !== 200) throw new Error('The dashboard did not accept the password.');
  const cookie = String(signIn.headers['set-cookie'] || '').split(';')[0];
  const status = JSON.parse((await dashboardRequest(port, '/api/status', { cookie })).body);
  return { status, dashboard: `http://${status.host || '127.0.0.1'}:${port}/` };
}

function createWindow() {
  win = new BrowserWindow({
    width: 1100,
    height: 760,
    minWidth: 760,
    minHeight: 560,
    title: `Material Unigram Host Assistant ${VERSION}`,
    backgroundColor: '#e7ecf2',
    autoHideMenuBar: true,
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, nodeIntegration: false, sandbox: true }
  });
  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:\/\//.test(url)) shell.openExternal(url);
    return { action: 'deny' };
  });
}

ipcMain.handle('host:check', () => checkComputer());
ipcMain.handle('host:start', (event, request) => startHosting(event, request));
ipcMain.handle('host:result', (event, request) => readResult(event, request));
ipcMain.handle('host:copy', (_e, text) => { clipboard.writeText(String(text)); return true; });
ipcMain.handle('host:open', (_e, url) => { if (/^(https?|tg):\/\//.test(url)) shell.openExternal(url); return true; });
ipcMain.handle('host:version', () => VERSION);
ipcMain.handle('host:randomPassword', () => crypto.randomBytes(12).toString('base64url'));

app.whenReady().then(createWindow);
app.on('window-all-closed', () => app.quit());
