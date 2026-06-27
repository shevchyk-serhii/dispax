# Load Tests

k6 smoke test for the Dispax ride lifecycle: **login → list rides → create ride**.

---

## Prerequisites

1. **Start the database:**
   ```bash
   docker-compose up -d
   ```

2. **Start the backend** with the development profile (applies V1001 dev seed data):
   ```bash
   make dev
   ```
   The backend must start with `APP_ENV=development` so that Flyway applies the
   `V1001__Insert_dev_data.sql` migration. Without it the test account
   `dispatcher@dispax.de` does not exist and login will fail.

3. **Verify the backend is ready:**
   ```bash
   curl http://localhost:8080/health
   ```

---

## Install k6

```bash
# macOS (Homebrew — recommended)
brew install k6

# Other platforms: https://k6.io/docs/getting-started/installation/
```

---

## Run

```bash
# Default: hits http://localhost:8080
make load-test

# Override target URL (staging, prod-like, etc.)
BASE_URL=http://staging.example.com make load-test

# Or call k6 directly
k6 run -e BASE_URL=http://localhost:8080 load-tests/smoke-ride-lifecycle.js
```

---

## Thresholds explained

| Metric                    | Threshold  | Meaning                                                                                                                            |
|---------------------------|------------|------------------------------------------------------------------------------------------------------------------------------------|
| `http_req_duration p(95)` | < 500 ms   | 95% of all ride-lifecycle requests complete in under 500 ms — the latency baseline expected from a local Postgres + ZIO-HTTP stack |
| `http_req_duration p(99)` | < 1 000 ms | No more than 1 in 100 requests exceeds 1 second, accounting for occasional GC pauses or HikariCP pool contention                   |
| `http_req_failed`         | < 1%       | Fewer than 1 in 100 requests return a non-2xx/3xx status or a network error                                                        |

k6 exits non-zero and prints `FAILED` next to any breached threshold.

---

## What is tested

| Step                | Endpoint                           | Expected status |
|---------------------|------------------------------------|-----------------|
| Login (setup, once) | `POST /api/auth/login`             | 200             |
| List rides          | `GET /api/rides?limit=20&offset=0` | 200             |
| Create ride         | `POST /api/rides`                  | 201             |

The script uses a **single login** in `setup()` (runs once before VUs start) to avoid
triggering the per-IP auth rate limiter when all 10 VUs ramp up from one machine.

---

## What is NOT tested

- **Assign driver** (`PUT /api/rides/{id}/assign-driver`) — requires a `ScheduleDay`
  reference that is not seeded for the Dispax Munchen company in V1001.
- **External routing APIs** (HERE / Google Maps) — omitted by design. The ride payload
  supplies explicit `latitude`/`longitude` coordinates so the backend does not need to
  geocode addresses.

---

## Cleanup

Each k6 run creates rides in the dev database. They accumulate across runs but do not
affect test correctness (the list endpoint returns them all, pagination is capped at 20).

To wipe transactional data between runs (dev environment only):

```bash
curl -sf -X POST http://localhost:8080/api/dev/reset
```

This endpoint is available only when `APP_ENV=development`.
