import http from 'k6/http';
import { check, sleep, fail } from 'k6';

// Smoke load test: login → list rides → create ride.
// Measures baseline latency for the core ride lifecycle without triggering
// external routing APIs (coordinates are supplied explicitly).
//
// Prerequisites:
//   docker-compose up -d
//   make dev          (APP_ENV=development — applies V1001 dev seed)
//
// Run:
//   make load-test
//   BASE_URL=http://staging.example.com make load-test
export const options = {
  stages: [
    { duration: '5s',  target: 10 },  // ramp up  0 → 10 VUs
    { duration: '20s', target: 10 },  // hold      10 VUs
    { duration: '5s',  target: 0  },  // ramp down 10 → 0
  ],
  thresholds: {
    'http_req_duration{scenario:default}': ['p(95)<500', 'p(99)<1000'],
    'http_req_failed':                     ['rate<0.01'],
  },
};

// setup() runs ONCE before any VU starts.
// A single login avoids hammering the per-IP rate limiter when 10 VUs ramp up
// simultaneously — all from the same machine/IP.
export function setup() {
  const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
  const res = http.post(
    `${BASE_URL}/api/auth/login`,
    JSON.stringify({ email: 'dispatcher@dispax.de', password: 'password123' }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  check(res, { 'login 200': (r) => r.status === 200 });
  // Abort the whole run with a clear message if login fails — otherwise every VU
  // would send `Bearer undefined`, producing a wall of 401s that hides the real cause
  // (backend down, wrong BASE_URL, or dev seed missing).
  if (res.status !== 200) {
    fail(`login failed: status ${res.status} against ${BASE_URL} — is the backend up with the V1001 dev seed?`);
  }
  const body = JSON.parse(res.body);
  return {
    baseUrl:   BASE_URL,
    token:     body.token,
    personId:  body.person.id,           // '11111111-1111-1111-1111-111111111111'
    companyId: body.person.companyId,    // '10101010-1010-1010-1010-101010101010'
    clientId:  '66666666-6666-6666-6666-666666666666', // client1@bmw.de (same company)
  };
}

export default function (data) {
  const headers = {
    Authorization: `Bearer ${data.token}`,
    'Content-Type': 'application/json',
  };

  // Step 1 — list rides (read path)
  const listRes = http.get(`${data.baseUrl}/api/rides?limit=20&offset=0`, { headers });
  check(listRes, { 'list rides 200': (r) => r.status === 200 });

  // Step 2 — create ride (write path, no routing API call: coords supplied explicitly)
  const pickupDt = new Date(Date.now() + 2 * 3600 * 1000).toISOString(); // now + 2 h
  const payload = JSON.stringify({
    clientId:       data.clientId,
    creatorId:      data.personId,
    clientName:     'BMW AG',
    pickupDateTime: pickupDt,
    from: {
      address:   'Marienplatz 1, 80331 München',
      latitude:  48.1374,
      longitude: 11.5755,
    },
    to: {
      address:   'Munich Airport Terminal 1',
      latitude:  48.3537,
      longitude: 11.7750,
    },
  });
  const createRes = http.post(`${data.baseUrl}/api/rides`, payload, { headers });
  check(createRes, { 'create ride 201': (r) => r.status === 201 });

  sleep(1);
}
