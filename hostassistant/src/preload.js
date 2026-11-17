'use strict';

const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('host', {
  check: () => ipcRenderer.invoke('host:check'),
  start: (request) => ipcRenderer.invoke('host:start', request),
  result: (request) => ipcRenderer.invoke('host:result', request),
  copy: (text) => ipcRenderer.invoke('host:copy', text),
  open: (url) => ipcRenderer.invoke('host:open', url),
  version: () => ipcRenderer.invoke('host:version'),
  randomPassword: () => ipcRenderer.invoke('host:randomPassword'),
  onOutput: (callback) => ipcRenderer.on('host:output', (_e, text) => callback(text)),
  onDone: (callback) => ipcRenderer.on('host:done', (_e, info) => callback(info))
});
