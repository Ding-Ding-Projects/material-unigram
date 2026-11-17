// Sends MTProto req_pq_multi over the abridged transport and prints the key fingerprints offered.
const net = require('net'), crypto = require('crypto');
const [host, port] = [process.argv[2], Number(process.argv[3])];
const nonce = crypto.randomBytes(16);
const body = Buffer.concat([Buffer.from([0xf1, 0x8e, 0x7e, 0xbe]), nonce]); // req_pq_multi#be7e8ef1
const msgId = BigInt(Math.floor(Date.now() / 1000)) << 32n;
const msg = Buffer.alloc(20 + body.length);
msg.writeBigUInt64LE(0n, 0); msg.writeBigUInt64LE(msgId, 8); msg.writeUInt32LE(body.length, 16); body.copy(msg, 20);
const sock = net.connect({ host, port }, () => { const len = Buffer.alloc(4); len.writeUInt32LE(msg.length); sock.write(Buffer.concat([Buffer.from([0xee,0xee,0xee,0xee]), len, msg])); });
let buf = Buffer.alloc(0);
sock.setTimeout(8000, () => { console.log('NO REPLY (timeout)'); process.exit(1); });
sock.on('data', (d) => {
  buf = Buffer.concat([buf, d]);
  if (buf.length < 4) return; const len = buf.readUInt32LE(0), off = 4;
  if (buf.length < off + len) return;
  const p = buf.subarray(off + 20, off + len);
  const ctor = p.readUInt32LE(0);
  if (ctor !== 0x05162463) { console.log('unexpected constructor 0x' + ctor.toString(16)); process.exit(1); }
  console.log('resPQ received, nonce echoed:', p.subarray(4, 20).equals(nonce));
  let o = 36; const l = p[o]; o += 1 + l; o += (4 - ((1 + l) % 4)) % 4; // skip pq bytes
  o += 4; const n = p.readUInt32LE(o); o += 4; // vector constructor, count
  for (let i = 0; i < n; i++) console.log('offered fingerprint', p.readBigUInt64LE(o + 8 * i).toString());
  sock.destroy();
});
sock.on('error', (e) => { console.log('ERROR', e.message); process.exit(1); });
