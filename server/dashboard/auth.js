'use strict';

// Dashboard password and session cookies. The password is compared in constant time and never
// logged; sessions are random tokens held in memory, so a restart signs browsers out.

const crypto = require('node:crypto');

const SESSION_COOKIE = 'mup_session';
const SESSION_TTL_MS = 1000 * 60 * 60 * 24 * 30;
const MAX_ATTEMPTS = 10;
const ATTEMPT_WINDOW_MS = 1000 * 60 * 10;

function createAuth(password) {
  if (!password || password.length < 8) {
    throw new Error('DASHBOARD_PASSWORD must be at least 8 characters.');
  }

  const passwordHash = crypto.createHash('sha256').update(password, 'utf8').digest();
  const sessions = new Map();
  const attempts = new Map();

  function verify(candidate) {
    const candidateHash = crypto.createHash('sha256').update(String(candidate || ''), 'utf8').digest();
    return crypto.timingSafeEqual(candidateHash, passwordHash);
  }

  function recent(address) {
    const now = Date.now();
    const list = (attempts.get(address) || []).filter((time) => now - time < ATTEMPT_WINDOW_MS);
    attempts.set(address, list);
    return list;
  }

  function signIn(address, candidate) {
    if (recent(address).length >= MAX_ATTEMPTS) {
      return { ok: false, reason: 'Too many attempts. Wait ten minutes and try again.' };
    }
    if (!verify(candidate)) {
      recent(address).push(Date.now());
      return { ok: false, reason: 'That password is not right.' };
    }
    const token = crypto.randomBytes(32).toString('base64url');
    sessions.set(token, Date.now() + SESSION_TTL_MS);
    return { ok: true, token };
  }

  function tokenFrom(cookieHeader) {
    if (!cookieHeader) return null;
    for (const part of cookieHeader.split(';')) {
      const [name, ...rest] = part.trim().split('=');
      if (name === SESSION_COOKIE) return rest.join('=');
    }
    return null;
  }

  function isSignedIn(cookieHeader) {
    const token = tokenFrom(cookieHeader);
    const expires = token && sessions.get(token);
    if (!expires) return false;
    if (expires < Date.now()) {
      sessions.delete(token);
      return false;
    }
    return true;
  }

  function signOut(cookieHeader) {
    const token = tokenFrom(cookieHeader);
    if (token) sessions.delete(token);
  }

  function cookie(token) {
    return `${SESSION_COOKIE}=${token}; HttpOnly; SameSite=Strict; Path=/; Max-Age=${SESSION_TTL_MS / 1000}`;
  }

  return { signIn, isSignedIn, signOut, cookie, verify };
}

module.exports = { createAuth, SESSION_COOKIE };
