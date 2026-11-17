'use strict';

document.getElementById('form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const error = document.getElementById('error');
  error.textContent = '';
  try {
    const res = await fetch('/api/sign-in', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ password: document.getElementById('password').value })
    });
    if (res.ok) {
      location.href = '/';
      return;
    }
    const body = await res.json().catch(() => ({}));
    error.textContent = body.error || 'Sign-in did not work. Try again.';
  } catch {
    error.textContent = 'The dashboard cannot be reached. Check that the proxy is running.';
  }
});
