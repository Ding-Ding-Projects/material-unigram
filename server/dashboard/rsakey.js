'use strict';

// Server key for the full (Teamgram) server. Teamgram's source ships one fixed private key, which
// would let anyone with the source impersonate every server that keeps it, so each install makes
// its own. Clients pin the public key and its MTProto fingerprint.
//
// Fingerprint, as Telegram defines it: the low 64 bits of SHA1 over the TL serialisation of the
// key's modulus and exponent (each as TL "bytes"), read little-endian, printed as unsigned decimal.

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

function tlBytes(buffer) {
  const header = buffer.length < 254
    ? Buffer.from([buffer.length])
    : Buffer.from([254, buffer.length & 0xff, (buffer.length >> 8) & 0xff, (buffer.length >> 16) & 0xff]);
  const body = Buffer.concat([header, buffer]);
  const padding = (4 - (body.length % 4)) % 4;
  return Buffer.concat([body, Buffer.alloc(padding)]);
}

function stripLeadingZero(buffer) {
  let i = 0;
  while (i < buffer.length - 1 && buffer[i] === 0) i++;
  return buffer.subarray(i);
}

function fingerprint(publicKeyPem) {
  const jwk = crypto.createPublicKey(publicKeyPem).export({ format: 'jwk' });
  const n = stripLeadingZero(Buffer.from(jwk.n, 'base64url'));
  const e = stripLeadingZero(Buffer.from(jwk.e, 'base64url'));
  const sha1 = crypto.createHash('sha1').update(Buffer.concat([tlBytes(n), tlBytes(e)])).digest();
  return sha1.readBigUInt64LE(12).toString();
}

/** Creates the key pair in dir once; returns the public key and fingerprint either way. */
function ensureServerKey(dir) {
  const privatePath = path.join(dir, 'server_pkcs1.key');
  const publicPath = path.join(dir, 'server_public.pem');
  if (!fs.existsSync(privatePath)) {
    const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', {
      modulusLength: 2048,
      publicExponent: 65537,
      privateKeyEncoding: { type: 'pkcs1', format: 'pem' },
      publicKeyEncoding: { type: 'pkcs1', format: 'pem' }
    });
    fs.writeFileSync(privatePath, privateKey, { mode: 0o600 });
    fs.writeFileSync(publicPath, publicKey, { mode: 0o644 });
  }
  const publicKey = fs.readFileSync(publicPath, 'utf8');
  const value = fingerprint(publicKey);
  fs.writeFileSync(path.join(dir, 'server_fingerprint.txt'), value + '\n');
  return { publicKey, fingerprint: value };
}

if (require.main === module) {
  const dir = process.argv[2] || '/keys';
  fs.mkdirSync(dir, { recursive: true });
  const { fingerprint: value } = ensureServerKey(dir);
  process.stdout.write(`server key ready, fingerprint ${value}\n`);
}

module.exports = { fingerprint, ensureServerKey, tlBytes };
