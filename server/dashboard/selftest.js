'use strict';

// Checks the dashboard logic that does not need a running proxy: password and sessions, the
// sign-in rate limit, stats parsing and share-link secrets.

const assert = require('node:assert/strict');
const { createAuth } = require('./auth');
const { parseStats, summarize, clientSecret, shareLinks } = require('./proxy');

assert.throws(() => createAuth('short'), /at least 8/);
const auth = createAuth('correct horse battery');
assert.equal(auth.signIn('198.51.100.5', 'wrong').ok, false);
const good = auth.signIn('198.51.100.6', 'correct horse battery');
assert.equal(good.ok, true);
assert.equal(auth.isSignedIn(`a=1; mup_session=${good.token}`), true);
assert.equal(auth.isSignedIn('mup_session=forged'), false);
auth.signOut(`mup_session=${good.token}`);
assert.equal(auth.isSignedIn(`mup_session=${good.token}`), false);
for (let i = 0; i < 10; i++) auth.signIn('198.51.100.7', 'wrong');
assert.equal(auth.signIn('198.51.100.7', 'correct horse battery').ok, false, 'rate limit holds');

const stats = parseStats('version\tmtproxy-1\nuptime\t120\ntotal_special_connections\t12\nready_targets\t8\nactive_targets\t19\ntotal_targets\t8\nbroken line\n');
assert.equal(stats.uptime, '120');
const summary = summarize(stats);
assert.equal(summary.connections, 12);
assert.equal(summary.uptimeSeconds, 120);
assert.equal(summary.readyTargets, 8);
assert.equal(summary.activeTargets, 19);
assert.equal(summarize({}).connections, null);

const secret = '0123456789abcdef0123456789abcdef';
assert.equal(clientSecret(secret, ''), 'dd' + secret);
assert.equal(clientSecret(secret, 'example.org'), 'ee' + secret + Buffer.from('example.org').toString('hex'));
assert.throws(() => clientSecret('not-hex', ''), /32 hex/);
const links = shareLinks('192.0.2.10', 443, secret, '');
assert.equal(links.tg, `tg://proxy?server=192.0.2.10&port=443&secret=dd${secret}`);
assert.ok(links.https.startsWith('https://t.me/proxy?'));

process.stdout.write('dashboard selftest passed\n');
