'use strict';

// Status for the full (Teamgram) server: each internal service is checked by opening a TCP
// connection on the private Docker network, and the gateway ports are what clients use.

const fs = require('node:fs');
const net = require('node:net');
const path = require('node:path');

const SERVICES = [
  { id: 'gateway', name: 'Client gateway (MTProto over TCP)', host: 'teamgram', port: 10443, clientFacing: true },
  { id: 'websocket', name: 'Client gateway (WebSocket)', host: 'teamgram', port: 11443, clientFacing: true },
  { id: 'mysql', name: 'Database', host: 'mysql', port: 3306 },
  { id: 'redis', name: 'Cache', host: 'redis', port: 6379 },
  { id: 'etcd', name: 'Service discovery', host: 'etcd', port: 2379 },
  { id: 'kafka', name: 'Message queue', host: 'kafka', port: 9092 },
  { id: 'minio', name: 'File storage', host: 'minio', port: 9000 }
];

function probe(host, port, timeoutMs = 1500) {
  return new Promise((resolve) => {
    const started = Date.now();
    const socket = net.connect({ host, port });
    const done = (up) => { socket.destroy(); resolve({ up, ms: up ? Date.now() - started : null }); };
    socket.setTimeout(timeoutMs, () => done(false));
    socket.once('connect', () => done(true));
    socket.once('error', () => done(false));
  });
}

async function serviceHealth() {
  const results = await Promise.all(SERVICES.map(async (service) => ({ ...service, ...(await probe(service.host, service.port)) })));
  return { services: results, allUp: results.every((s) => s.up) };
}

function serverKey(keysDir) {
  try {
    return {
      publicKey: fs.readFileSync(path.join(keysDir, 'server_public.pem'), 'utf8'),
      fingerprint: fs.readFileSync(path.join(keysDir, 'server_fingerprint.txt'), 'utf8').trim()
    };
  } catch {
    return null;
  }
}

module.exports = { SERVICES, probe, serviceHealth, serverKey };
