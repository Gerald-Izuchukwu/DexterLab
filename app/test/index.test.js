const test = require('node:test');
const assert = require('node:assert');
const request = require('supertest');
const app = require('../index.js');

test('GET /healthz returns 200 and status ok', async () => {
  const res = await request(app).get('/healthz');
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.status, 'ok');
});

test('GET / returns service metadata', async () => {
  const res = await request(app).get('/');
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.service, 'wallet-app');
});
