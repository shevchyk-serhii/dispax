.PHONY: fmt fmt-watch dev run-test prod test test-unit test-unit-all flutter-test-unit test-fast test-integration test-bdd test-all clean rebuild \
        flutter-dev flutter-dev-device flutter-prod flutter-dev-android flutter-dev-ios flutter-prod-android flutter-prod-ios \
        flutter-test-integration \
        patrol-test-android patrol-test-ios \
        emulator-up e2e-backend-up e2e-backend-down e2e-android e2e-ios e2e-test e2e-fast e2e-red e2e-notif-http e2e-ride-rules \
        flutter-dev-iphone-sergii flutter-dev-android-sergii flutter-dev-sergii \
        dev-all dev-sim dev-roles free-port stop-dev \
        deploy logs setup-hooks \
        load-test

PROD_URL := https://dispax-o2trzxjbva-ew.a.run.app
# Wi-Fi (en0) IP for physical devices on the same network; falls back to en1,
# then to 127.0.0.1 when no LAN interface is up (e.g. en0 down → empty would
# otherwise produce http://:8080 and silently send the app to the prod default).
MAC_IP := $(shell ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 127.0.0.1)
GCP_PROJECT := project-6efcac64-991b-49f4-946
GCP_REGION := europe-west1
GCP_SERVICE := dispax
GCP_IMAGE := europe-west1-docker.pkg.dev/$(GCP_PROJECT)/dispax-docker/dispax-server:latest
FLUTTER_DIR    := web
# Mapbox public token (geocoding/address autocomplete + maps SDK). Read from
# .env.dev and passed to every `flutter run`/`build` via --dart-define so the
# in-app MapboxService.suggestAddresses/geocodeAddress actually work. Override
# from the environment or the make CLI (`make flutter-dev MAPBOX_ACCESS_TOKEN=…`);
# empty when .env.dev is absent (e.g. CI) — the app degrades gracefully.
MAPBOX_ACCESS_TOKEN ?= $(shell grep -E '^MAPBOX_ACCESS_TOKEN=' .env.dev 2>/dev/null | cut -d= -f2-)
# Run Flutter/Dart through FVM when it is installed and the project pins a
# version (web/.fvmrc → Flutter 3.44.2, matching .github/workflows/ci.yml), so
# `make fmt`/test targets use the same formatter/SDK as CI. Falls back to the
# bare `flutter`/`dart` on PATH otherwise (e.g. CI, which installs the SDK
# itself). Override: `make FLUTTER=flutter ...`.
FVM_BIN := $(shell command -v fvm 2>/dev/null)
ifeq ($(and $(FVM_BIN),$(wildcard $(FLUTTER_DIR)/.fvmrc)),)
  FLUTTER ?= flutter
  DART    ?= dart
else
  FLUTTER ?= fvm flutter
  DART    ?= fvm dart
endif
# Extra buffer (seconds) before launching Flutter in `make dev-all`, on top of
# waiting for the backend's /health. Gives Flyway migrations + ZIO layers time
# to finish so the first API calls (e.g. /users/clients) don't fail. Override:
# `make dev-all FLUTTER_STARTUP_DELAY=15`
FLUTTER_STARTUP_DELAY := 8
# Booted iOS simulator UDID used by `make dev-sim`. Override if you boot a
# different simulator: `make dev-sim IOS_SIM=<udid>` (find it via `flutter devices`).
IOS_SIM        := 09021E1A-BC6A-4D86-A2EA-06A5894E4AEC
# `make dev-roles` runs the app on three dedicated, NAMED iPhone 17 Pro Max
# simulators so each role is instantly recognisable by the simulator window
# title (otherwise three identical 17 Pro Max devices are impossible to tell
# apart). The simulators are created on first use and reused afterwards — see the
# `_ensure_sim` shell helper inside the dev-roles recipe. Override the device
# model or iOS runtime if needed.
SIM_DEVICE_TYPE := com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max
SIM_RUNTIME     := com.apple.CoreSimulator.SimRuntime.iOS-26-1
SIM_NAME_CLIENT     := Dispax Client
SIM_NAME_DRIVER     := Dispax Driver
SIM_NAME_DISPATCHER := Dispax Dispatcher
PATROL         := $(HOME)/.pub-cache/bin/patrol
ADB            := $(HOME)/Library/Android/sdk/platform-tools/adb
# AVD launched by `emulator-up` if no device is connected. Override: ANDROID_AVD=Pixel_7 make e2e-fast
ANDROID_AVD    ?= Pixel_5
# Port for the in-memory TestApplication used by integration / Patrol tests.
# Defaults to 8090 so tests run alongside a dev server on 8080. Override: TEST_PORT=9000 make ...
TEST_PORT      ?= 8090
# Full-backend E2E tests use an isolated Postgres (docker-compose `postgres-test`,
# 5433/dispax_test) so they never touch the dev DB on 5432.
TEST_DB_URL    := jdbc:postgresql://localhost:5433/dispax_test
-include .env.dev

# ─── Setup ──────────────────────────────────────────────────────────────────

# Point git at the versioned hooks in .githooks (run once after cloning)
setup-hooks:
	git config core.hooksPath .githooks
	@echo "✅ git hooks configured (.githooks)"

# ─── Backend ────────────────────────────────────────────────────────────────

# Start backend locally with the development profile.
# Reads .env.dev (APP_ENV=development); the app selects application-development.conf
# from APP_ENV itself, so plain `sbt run` is enough — no -Dconfig.resource needed.
dev:
	@export $$(cat .env.dev | grep -v '^#' | xargs) && sbt run

# Start backend locally with the test profile against the isolated postgres-test
# DB (5433/dispax_test). Reads .env.test (APP_ENV=test → application-test.conf).
# Bring the DB up first: docker compose up -d postgres-test
run-test:
	@export $$(cat .env.test | grep -v '^#' | xargs) && sbt run

# Run BDD Cucumber scenarios
test-bdd:
	sbt cucumber

# Run all unit + integration tests (excludes Cucumber)
test:
	sbt "core/test; auth/test; ride/test; driver/test; notification/test; schedule/test; billing/test"

# ── DEFAULT INNER-LOOP ────────────────────────────────────────────────────
# Run ONLY fast unit tests (in-memory repos, no Testcontainers / no Postgres).
# Integration specs carry `@@ TestAspect.tag("integration")`; -ignore-tags drops
# them. This is the command to run while developing — no Docker, seconds not
# minutes, no advisory-lock serialisation. Run `make test` (unit + integration)
# before merging. `test-fast` is an alias.
# `make test-unit` runs Scala unit tests only; `make test-unit-all` also runs
# the Flutter (web) unit/widget suite. The api module lives in the `root`
# project (api/src/test); the `*Spec` glob picks up its ZIO specs (in-memory,
# no Postgres) while skipping the JUnit-based CucumberRunner (a `class`, run
# only via the `cucumber` alias).
test-fast: test-unit
test-unit:
	sbt "core/testOnly * -- -ignore-tags integration; \
	     auth/testOnly * -- -ignore-tags integration; \
	     ride/testOnly * -- -ignore-tags integration; \
	     driver/testOnly * -- -ignore-tags integration; \
	     notification/testOnly * -- -ignore-tags integration; \
	     schedule/testOnly * -- -ignore-tags integration; \
	     billing/testOnly * -- -ignore-tags integration; \
	     root/testOnly *Spec -- -ignore-tags integration"

# Scala unit tests + Flutter (web) unit/widget tests. The Flutter suite lives in
# web/test (no IntegrationTestWidgetsFlutterBinding, no network) — distinct from
# the live-backend e2e in web/integration_test, which `flutter test test/` skips.
test-unit-all: test-unit flutter-test-unit
flutter-test-unit:
	cd $(FLUTTER_DIR) && $(FLUTTER) test test/

# Run ONLY the integration tests (Testcontainers + real Postgres). Requires Docker.
# Selects specs tagged `integration` via -tags.
test-integration:
	sbt "core/testOnly * -- -tags integration; \
	     auth/testOnly * -- -tags integration; \
	     ride/testOnly * -- -tags integration; \
	     driver/testOnly * -- -tags integration; \
	     notification/testOnly * -- -tags integration; \
	     schedule/testOnly * -- -tags integration; \
	     billing/testOnly * -- -tags integration"

# Run Flutter integration tests against local TestApplication.
# Backend runs on TEST_PORT (default 8090) so it doesn't collide with a dev
# server on 8080. The test PID is tracked so only this server is stopped.
# HTTP contract/integration tests (flutter_test) against the in-memory
# TestApplication. They talk to localhost:$(TEST_PORT), so they run on the macOS
# host (`-d macos`), not on a device/emulator where localhost is the guest.
INTEGRATION_HTTP_TESTS := integration_test/auth_integration_test.dart \
                          integration_test/contract_test.dart \
                          integration_test/ride_integration_test.dart \
                          integration_test/user_integration_test.dart
flutter-test-integration:
	@echo "🚀 Starting test backend on port $(TEST_PORT)..."
	@PORT=$(TEST_PORT) sbt testServer & echo $$! > /tmp/dispax-testserver.pid
	@echo "⏳ Waiting for backend to be ready..."
	@until curl -sf http://localhost:$(TEST_PORT)/health > /dev/null; do sleep 1; done
	@echo "✅ Backend ready, running Flutter integration tests..."
	@cd $(FLUTTER_DIR) && STATUS=0 ; \
	  for t in $(INTEGRATION_HTTP_TESTS); do \
	    echo "▶ $$t"; \
	    $(FLUTTER) test -d macos $$t --dart-define=TEST_SERVER_PORT=$(TEST_PORT) || STATUS=1 ; \
	  done ; \
	  kill $$(cat /tmp/dispax-testserver.pid) 2>/dev/null || true ; \
	  pkill -f "PORT=$(TEST_PORT).*testServer" 2>/dev/null || true ; \
	  exit $$STATUS

# Run Patrol E2E tests on an Android emulator against local TestApplication.
# Backend runs on TEST_PORT (default 8090); the emulator reaches the host via
# 10.0.2.2. Requires a running emulator and patrol_cli.
patrol-test-android:
	@echo "🚀 Starting test backend on port $(TEST_PORT)..."
	@PORT=$(TEST_PORT) sbt testServer & echo $$! > /tmp/dispax-testserver.pid
	@echo "⏳ Waiting for backend to be ready..."
	@until curl -sf http://localhost:$(TEST_PORT)/health > /dev/null; do sleep 1; done
	@echo "✅ Backend ready, running Patrol Android E2E tests..."
	@cd $(FLUTTER_DIR) && $(PATROL) test \
	  --target integration_test/login_smoke_test.dart \
	  --dart-define=API_BASE_URL=http://10.0.2.2:$(TEST_PORT)/api ; \
	  STATUS=$$? ; \
	  kill $$(cat /tmp/dispax-testserver.pid) 2>/dev/null || true ; \
	  pkill -f "PORT=$(TEST_PORT).*testServer" 2>/dev/null || true ; \
	  exit $$STATUS

# Run Patrol E2E tests on an iOS simulator against local TestApplication.
# Backend runs on TEST_PORT (default 8090); the simulator reaches the host via
# localhost. Requires a booted simulator, patrol_cli, and the RunnerUITests
# target (see web/ios/add_patrol_uitests_target.rb).
patrol-test-ios:
	@echo "🚀 Starting test backend on port $(TEST_PORT)..."
	@PORT=$(TEST_PORT) sbt testServer & echo $$! > /tmp/dispax-testserver.pid
	@echo "⏳ Waiting for backend to be ready..."
	@until curl -sf http://localhost:$(TEST_PORT)/health > /dev/null; do sleep 1; done
	@echo "✅ Backend ready, running Patrol iOS E2E tests..."
	@cd $(FLUTTER_DIR) && $(PATROL) test \
	  --target integration_test/login_smoke_test.dart \
	  --dart-define=API_BASE_URL=http://localhost:$(TEST_PORT)/api ; \
	  STATUS=$$? ; \
	  kill $$(cat /tmp/dispax-testserver.pid) 2>/dev/null || true ; \
	  pkill -f "PORT=$(TEST_PORT).*testServer" 2>/dev/null || true ; \
	  exit $$STATUS

# ─── Full-backend E2E (Patrol) ────────────────────────────────────────────────
# These run the COMPLETE Application (ride/schedule/driver routes) against the
# isolated test DB (postgres-test on 5433), with Flyway dev-data + seeded driver
# schedules. They cover the per-role happy-paths and the full ride lifecycle.

# Ensure an Android emulator is running: reuse a connected device, otherwise
# boot ANDROID_AVD and wait for it. Lets `make e2e-fast` work from cold.
emulator-up:
	@if $(ADB) devices | grep -qw device; then \
	  echo "📱 Android device already connected"; \
	else \
	  echo "📱 Launching emulator $(ANDROID_AVD)..."; \
	  $(FLUTTER) emulators --launch $(ANDROID_AVD); \
	  echo "⏳ Waiting for emulator to boot..."; \
	  $(ADB) wait-for-device; \
	  until [ "$$($(ADB) shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done; \
	  echo "✅ Emulator booted"; \
	fi

# Ordered list of E2E suites. full_flow runs before the data-mutating feature
# tests (blacklist/admin) so their writes can't interfere with assignment.
E2E_SUITES := e2e_client e2e_driver e2e_secretary e2e_dispatcher e2e_admin \
              e2e_settings e2e_cancel_ride e2e_more_menu e2e_airport_ride \
              e2e_chat e2e_reassign e2e_full_flow \
              e2e_admin_users e2e_expense e2e_blacklist e2e_geofence \
              e2e_neg_login e2e_neg_create_ride e2e_neg_role_access \
              e2e_book_discard_guard e2e_address_focus \
              e2e_notif_driver_assigned e2e_notif_status_updates e2e_notif_mark_read

# Notification HTTP checks (flutter_test, no Patrol/UI) — assert the in-app inbox
# over REST. Run with `flutter test` via `make e2e-notif-http`. These are green.
E2E_NOTIF_HTTP_TESTS := integration_test/e2e_notif_isolation_test.dart \
                        integration_test/e2e_notif_client_on_create_test.dart \
                        integration_test/e2e_notif_client_on_status_test.dart \
                        integration_test/e2e_notif_cancel_test.dart \
                        integration_test/e2e_notif_driver_approaching_test.dart

# Ride-rule HTTP checks (flutter_test, no Patrol/UI): negative / edge-case ride
# flows that assert the backend REJECTS bad operations AND leaves the ride's
# state unchanged (the class of bug happy-path tests miss). Green. Run via
# `make e2e-ride-rules`.
E2E_RIDE_RULES_HTTP_TESTS := integration_test/e2e_ride_validation_test.dart \
                             integration_test/e2e_ride_illegal_transitions_test.dart \
                             integration_test/e2e_ride_authorization_test.dart \
                             integration_test/e2e_ride_assign_rules_test.dart

# "Red" suites assert DESIRED behaviour the backend does not implement yet. They
# are EXPECTED TO FAIL and serve as an executable backlog, kept out of the green
# bundle and run via `make e2e-red`. Currently: the dispatcher Pending list has
# no live WebSocket updates (loads via REST), so a ride created mid-session does
# not appear without a manual refresh.
E2E_RED_PATROL_SUITES := e2e_ws_dispatcher_live_red
# Transactional tables wiped before each suite to keep runs isolated/repeatable.
E2E_CLEAN_SQL := TRUNCATE rides, ride_ratings, blacklist_entries, expenses, geofences, chat_messages CASCADE;

# Bring up the isolated test DB and the full backend on TEST_PORT, wait for health.
e2e-backend-up:
	@echo "🐘 Starting isolated test DB (postgres-test :5433)..."
	@docker compose up -d postgres-test
	@until docker exec dispax-postgres-test-1 pg_isready -U dispax -d dispax_test >/dev/null 2>&1; do sleep 1; done
	@echo "🚀 Starting full backend on port $(TEST_PORT) (test DB)..."
	@export $$(grep -v '^#' .env.dev | grep -vE '^(PORT|DATABASE_URL)=' | xargs) && \
	  DATABASE_URL=$(TEST_DB_URL) PORT=$(TEST_PORT) APP_ENV=development sbt run & \
	  echo $$! > /tmp/dispax-e2e-backend.pid
	@echo "⏳ Waiting for backend to be ready..."
	@until curl -sf http://localhost:$(TEST_PORT)/health > /dev/null; do sleep 1; done
	@echo "✅ Backend ready on :$(TEST_PORT)"

# Stop the E2E backend (does NOT stop postgres-test or the dev server on 8080).
e2e-backend-down:
	@lsof -nP -iTCP:$(TEST_PORT) -sTCP:LISTEN -t 2>/dev/null | xargs -r kill 2>/dev/null || true
	@echo "🛑 E2E backend stopped"

# Run all E2E suites on an Android emulator (host reached via 10.0.2.2).
# Each suite starts from a clean transactional state for isolation.
e2e-android: emulator-up e2e-backend-up
	@echo "🧪 Running Patrol E2E suites on Android..."
	@cd $(FLUTTER_DIR) && for t in $(E2E_SUITES); do \
	  echo "▶ $$t"; \
	  PGPASSWORD=dispax psql -h localhost -p 5433 -U dispax -d dispax_test -c "$(E2E_CLEAN_SQL)" >/dev/null 2>&1 || true ; \
	  $(PATROL) test --target integration_test/$$t\_test.dart \
	    --dart-define=API_BASE_URL=http://10.0.2.2:$(TEST_PORT)/api || true ; \
	done ; \
	$(MAKE) e2e-backend-down

# Run all E2E suites on an iOS simulator (host reached via localhost).
e2e-ios: e2e-backend-up
	@echo "🧪 Running Patrol E2E suites on iOS..."
	@cd $(FLUTTER_DIR) && for t in $(E2E_SUITES); do \
	  echo "▶ $$t"; \
	  PGPASSWORD=dispax psql -h localhost -p 5433 -U dispax -d dispax_test -c "$(E2E_CLEAN_SQL)" >/dev/null 2>&1 || true ; \
	  $(PATROL) test --target integration_test/$$t\_test.dart \
	    --dart-define=API_BASE_URL=http://localhost:$(TEST_PORT)/api || true ; \
	done ; \
	$(MAKE) e2e-backend-down

# Default E2E target: Android.
e2e-test: e2e-android

# Fast Android E2E: build ALL Patrol tests into ONE bundle APK and run them in a
# single instrumentation pass (no test orchestrator → no per-test process
# restarts). Each suite resets its data via POST /api/dev/reset (resetTestData),
# so a shared DB stays isolated. Excludes the flutter_test HTTP suites (not
# Patrol) and the native-permission test (needs a real OS dialog).
# Roughly 3x faster than e2e-android (one build, no orchestrator overhead).
PATROL_EXCLUDES := --exclude integration_test/auth_integration_test.dart \
                   --exclude integration_test/contract_test.dart \
                   --exclude integration_test/user_integration_test.dart \
                   --exclude integration_test/ride_integration_test.dart \
                   --exclude integration_test/permissions_test.dart \
                   --exclude integration_test/e2e_notif_isolation_test.dart \
                   --exclude integration_test/e2e_notif_client_on_create_test.dart \
                   --exclude integration_test/e2e_notif_client_on_status_test.dart \
                   --exclude integration_test/e2e_notif_cancel_test.dart \
                   --exclude integration_test/e2e_notif_driver_approaching_test.dart \
                   --exclude integration_test/e2e_ws_dispatcher_live_red_test.dart
e2e-fast: emulator-up e2e-backend-up
	@echo "🧪 Running ALL Patrol E2E in one bundle (Android, no orchestrator)..."
	@cd $(FLUTTER_DIR) && $(PATROL) test $(PATROL_EXCLUDES) \
	  --dart-define=API_BASE_URL=http://10.0.2.2:$(TEST_PORT)/api ; \
	  STATUS=$$? ; \
	  $(MAKE) -C .. e2e-backend-down ; \
	  exit $$STATUS

# Run the notification HTTP checks (flutter test, no emulator UI). Green: they
# assert the in-app inbox over REST. Note flutter_test still builds an APK and
# runs on a device, so an emulator must be booted (host reached via 10.0.2.2).
e2e-notif-http: emulator-up e2e-backend-up
	@echo "🔔 Running notification HTTP checks (flutter test)..."
	@cd $(FLUTTER_DIR) && for t in $(E2E_NOTIF_HTTP_TESTS); do \
	  echo "▶ $$t"; \
	  curl -sf -X POST http://localhost:$(TEST_PORT)/api/dev/reset >/dev/null 2>&1 || true ; \
	  $(FLUTTER) test $$t \
	    --dart-define=API_BASE_URL=http://10.0.2.2:$(TEST_PORT)/api ; \
	done ; \
	STATUS=$$? ; \
	$(MAKE) e2e-backend-down ; \
	exit $$STATUS

# Negative / edge-case ride-rule HTTP checks. Green: each asserts the backend
# rejects a bad operation AND leaves the ride state unchanged. Runs on the macOS
# host's emulator (10.0.2.2), per-file (batching times out on isolate load).
e2e-ride-rules: emulator-up e2e-backend-up
	@echo "🚦 Running ride-rule HTTP checks (flutter test)..."
	@cd $(FLUTTER_DIR) && STATUS=0 ; \
	  for t in $(E2E_RIDE_RULES_HTTP_TESTS); do \
	    echo "▶ $$t"; \
	    curl -sf -X POST http://localhost:$(TEST_PORT)/api/dev/reset >/dev/null 2>&1 || true ; \
	    $(FLUTTER) test $$t --dart-define=API_BASE_URL=http://10.0.2.2:$(TEST_PORT)/api || STATUS=1 ; \
	  done ; \
	  $(MAKE) e2e-backend-down ; \
	  exit $$STATUS

# Run the "red" suites that document expected backend gaps. These are EXPECTED
# TO FAIL — a failure here is the confirmed backlog. Currently: dispatcher
# Pending list has no live WebSocket updates (Patrol); and the 5-min clock-skew
# tolerance on pickup time is unreachable (HTTP). Does not gate CI.
e2e-red: emulator-up e2e-backend-up
	@echo "🟥 Running RED suites (expected failures = backlog)..."
	@cd $(FLUTTER_DIR) && for t in $(E2E_RED_PATROL_SUITES); do \
	  echo "▶ $$t"; \
	  PGPASSWORD=dispax psql -h localhost -p 5433 -U dispax -d dispax_test -c "$(E2E_CLEAN_SQL)" >/dev/null 2>&1 || true ; \
	  $(PATROL) test --target integration_test/$$t\_test.dart \
	    --dart-define=API_BASE_URL=http://10.0.2.2:$(TEST_PORT)/api || true ; \
	done ; \
	$(MAKE) e2e-backend-down

# Run all tests: unit + integration + Cucumber BDD
test-all:
	@echo "▶ Running unit + integration tests..."
	sbt "core/test; auth/test; ride/test; driver/test; notification/test; schedule/test; billing/test"
	@echo "▶ Running Cucumber BDD tests..."
	sbt cucumber

# Format all Scala + Dart code. Dart is rewritten first via $(DART) (FVM-pinned
# to web/.fvmrc 3.44.2 when FVM is installed, matching CI), then `sbt fmtAll`
# runs scalafmt and re-checks Dart with the same binary (DART_BIN) so a CI/local
# formatter mismatch can't slip through.
fmt:
	cd $(FLUTTER_DIR) && $(DART) format lib
	DART_BIN="$(DART)" sbt fmtAll

fmt-watch:
	DART_BIN="$(DART)" sbt fmtWatch

# Clean build
clean:
	sbt clean

rebuild: clean
	sbt compile

# ─── Load tests ─────────────────────────────────────────────────────────────

# Smoke load test: login → list rides → create ride (baseline latency).
# Requires k6 (brew install k6) and a running backend (make dev).
# Override target: BASE_URL=http://staging.example.com make load-test
load-test:
	@command -v k6 >/dev/null 2>&1 || { echo "❌ k6 is not installed. Run: brew install k6"; exit 1; }
	@echo "🚀 Running k6 smoke test against $${BASE_URL:-http://localhost:8080} ..."
	@k6 run -e BASE_URL=$${BASE_URL:-http://localhost:8080} load-tests/smoke-ride-lifecycle.js
	@echo "✅ k6 smoke test finished"

# ─── Deploy ─────────────────────────────────────────────────────────────────

# Build and push Docker image, then deploy to Cloud Run
deploy:
	sbt assembly
	docker buildx build --platform linux/amd64 --provenance=false --sbom=false -t $(GCP_IMAGE) --push .
	gcloud run services update $(GCP_SERVICE) \
		--project $(GCP_PROJECT) \
		--region $(GCP_REGION) \
		--image $(GCP_IMAGE)
	@echo "✅ Deployed to $(PROD_URL)"

# Tail Cloud Run logs
logs:
	gcloud beta run services logs tail $(GCP_SERVICE) \
		--project $(GCP_PROJECT) \
		--region $(GCP_REGION)

# ─── Flutter ────────────────────────────────────────────────────────────────

# Run Flutter against the LOCAL backend (localhost:8080). Uses 127.0.0.1, which
# works for desktop/web (browser) and avoids the WiFi-IP/CORS fragility that
# would otherwise fall back to the prod default. For a physical phone (which
# can't reach localhost) use `flutter-dev-device`, which targets the Mac's LAN IP.
flutter-dev:
	cd $(FLUTTER_DIR) && $(FLUTTER) run \
		--dart-define=API_BASE_URL=http://127.0.0.1:8080/api \
		--dart-define=MAPBOX_ACCESS_TOKEN=$(MAPBOX_ACCESS_TOKEN)

# Run Flutter on a physical device against the local backend over the LAN.
# Requires the phone and Mac to share a WiFi network and en0/en1 to be up.
flutter-dev-device:
	cd $(FLUTTER_DIR) && $(FLUTTER) run \
		--dart-define=API_BASE_URL=http://$(MAC_IP):8080/api \
		--dart-define=MAPBOX_ACCESS_TOKEN=$(MAPBOX_ACCESS_TOKEN)

# Run Flutter on Android emulator against local backend
flutter-dev-android:
	cd $(FLUTTER_DIR) && $(FLUTTER) run -d emulator-5554 \
		--dart-define=API_BASE_URL=http://10.0.2.2:8080/api \
		--dart-define=MAPBOX_ACCESS_TOKEN=$(MAPBOX_ACCESS_TOKEN)

# Run Flutter on iOS simulator against local backend
flutter-dev-ios:
	cd $(FLUTTER_DIR) && $(FLUTTER) run -d 09021E1A-BC6A-4D86-A2EA-06A5894E4AEC \
		--dart-define=API_BASE_URL=http://$(MAC_IP):8080/api \
		--dart-define=MAPBOX_ACCESS_TOKEN=$(MAPBOX_ACCESS_TOKEN)

# Run Flutter against production backend
flutter-prod:
	cd $(FLUTTER_DIR) && $(FLUTTER) run \
		--dart-define=API_BASE_URL=$(PROD_URL)/api \
		--dart-define=MAPBOX_ACCESS_TOKEN=$(MAPBOX_ACCESS_TOKEN)

# Build Android APK for production
flutter-prod-android:
	cd $(FLUTTER_DIR) && $(FLUTTER) build apk --release \
		--dart-define=API_BASE_URL=$(PROD_URL)/api \
		--dart-define=MAPBOX_ACCESS_TOKEN=$(MAPBOX_ACCESS_TOKEN)
	@echo "✅ APK: $(FLUTTER_DIR)/build/app/outputs/flutter-apk/app-release.apk"

# Build iOS IPA for production (App Store / TestFlight). Requires a configured
# signing identity / provisioning profile in Xcode.
flutter-prod-ios:
	cd $(FLUTTER_DIR) && $(FLUTTER) build ipa --release \
		--dart-define=API_BASE_URL=$(PROD_URL)/api \
		--dart-define=MAPBOX_ACCESS_TOKEN=$(MAPBOX_ACCESS_TOKEN)
	@echo "✅ IPA: $(FLUTTER_DIR)/build/ios/ipa/"

# Run Flutter on Sergii's iPhone (wireless) against local backend
flutter-dev-iphone-sergii:
	cd $(FLUTTER_DIR) && $(FLUTTER) run --release -d $(FLUTTER_DEVICE_IPHONE_SERGII) \
		--dart-define=API_BASE_URL=http://$(MAC_IP):8080/api \
		--dart-define=MAPBOX_ACCESS_TOKEN=$(MAPBOX_ACCESS_TOKEN)

# Run Flutter on Sergii's Android (wireless) against local backend
flutter-dev-android-sergii:
	cd $(FLUTTER_DIR) && $(FLUTTER) run -d $(FLUTTER_DEVICE_ANDROID_SERGII) \
		--dart-define=API_BASE_URL=http://$(MAC_IP):8080/api \
		--dart-define=MAPBOX_ACCESS_TOKEN=$(MAPBOX_ACCESS_TOKEN)

# Run Flutter on both Sergii's devices simultaneously (wireless)
flutter-dev-sergii:
	cd $(FLUTTER_DIR) && $(FLUTTER) run --release -d $(FLUTTER_DEVICE_IPHONE_SERGII) \
		--dart-define=API_BASE_URL=http://$(MAC_IP):8080/api \
		--dart-define=MAPBOX_ACCESS_TOKEN=$(MAPBOX_ACCESS_TOKEN) & \
	cd $(FLUTTER_DIR) && $(FLUTTER) run --release -d $(FLUTTER_DEVICE_ANDROID_SERGII) \
		--dart-define=API_BASE_URL=http://$(MAC_IP):8080/api \
		--dart-define=MAPBOX_ACCESS_TOKEN=$(MAPBOX_ACCESS_TOKEN) & \
	wait

# Kill whatever is listening on :8080 so a stale backend never causes
# "bind(..) failed: Address already in use". Used as a prerequisite by dev-all/dev-sim.
free-port:
	@pids=$$(lsof -ti tcp:8080 2>/dev/null); \
	if [ -n "$$pids" ]; then \
		echo "🧹 Freeing port 8080 (killing $$pids)"; \
		echo "$$pids" | xargs kill -9 2>/dev/null || true; \
		sleep 1; \
	fi

# Start local backend + Flutter on both devices in one command
# Hot reload Flutter: press 'r' in each flutter process terminal
# To restart backend after Scala changes: make stop-dev && make dev-all
dev-all: free-port
	@export $$(cat .env.dev | grep -v '^#' | xargs) && sbt run &
	@echo "⏳ Waiting for backend on :8080..."
	@until curl -sf http://localhost:8080/health > /dev/null; do sleep 1; done
	@echo "✅ Backend health OK — buffering $(FLUTTER_STARTUP_DELAY)s for migrations/layers..."
	@sleep $(FLUTTER_STARTUP_DELAY)
	@echo "🚀 Starting Flutter on both devices"
	@cd $(FLUTTER_DIR) && $(FLUTTER) run -d $(FLUTTER_DEVICE_IPHONE_SERGII) \
		--dart-define=API_BASE_URL=http://$(MAC_IP):8080/api \
		--dart-define=MAPBOX_ACCESS_TOKEN=$(MAPBOX_ACCESS_TOKEN) & \
	cd $(FLUTTER_DIR) && $(FLUTTER) run -d $(FLUTTER_DEVICE_ANDROID_SERGII) \
		--dart-define=API_BASE_URL=http://$(MAC_IP):8080/api \
		--dart-define=MAPBOX_ACCESS_TOKEN=$(MAPBOX_ACCESS_TOKEN) & \
	wait

# Start local backend + Flutter on the booted iOS simulator in one command.
# The simulator shares the Mac's network, so it talks to the backend over
# 127.0.0.1 (most reliable — no LAN/WiFi dependency). Override the simulator
# with `make dev-sim IOS_SIM=<udid>`. Stop everything with `make stop-dev`.
dev-sim: free-port
	@export $$(cat .env.dev | grep -v '^#' | xargs) && sbt run &
	@echo "⏳ Waiting for backend on :8080..."
	@until curl -sf http://localhost:8080/health > /dev/null; do sleep 1; done
	@echo "✅ Backend health OK — buffering $(FLUTTER_STARTUP_DELAY)s for migrations/layers..."
	@sleep $(FLUTTER_STARTUP_DELAY)
	@echo "🚀 Starting Flutter on iOS simulator $(IOS_SIM)"
	@cd $(FLUTTER_DIR) && $(FLUTTER) run -d $(IOS_SIM) \
		--dart-define=API_BASE_URL=http://127.0.0.1:8080/api \
		--dart-define=MAPBOX_ACCESS_TOKEN=$(MAPBOX_ACCESS_TOKEN)

# Start local backend + the app on THREE dedicated iPhone 17 Pro Max simulators
# at once (client / driver / dispatcher) so all roles can be tested side by side
# from one command. Each simulator is NAMED ("Dispax Client/Driver/Dispatcher")
# so the role is obvious from the simulator window title — three identical
# 17 Pro Max devices are otherwise indistinguishable. The simulators are created
# on first run and reused after.
#
# The MAPBOX_ACCESS_TOKEN + API_BASE_URL are baked into the build via
# --dart-define, which is why the map/geocoding work here but fail when the app
# is launched from the IDE without those defines (Mapbox returns 401).
#
# The app is BUILT ONCE, then installed+launched on each booted simulator (much
# faster and more stable than three concurrent `flutter run` processes fighting
# over stdin/hot-reload). Roles are NOT auto-selected — the app has no autologin;
# log in via the "Quick Access for Testing" panel on the login screen, or with
# the dev seed accounts (password: password123):
#   • dispatcher@dispax.de   • driver1@dispax.de   • client1@bmw.de
# Stop everything with `make stop-dev`.
dev-roles: free-port
	@export $$(cat .env.dev | grep -v '^#' | xargs) && sbt run &
	@echo "⏳ Waiting for backend on :8080..."
	@until curl -sf http://localhost:8080/health > /dev/null; do sleep 1; done
	@echo "✅ Backend health OK — buffering $(FLUTTER_STARTUP_DELAY)s for migrations/layers..."
	@sleep $(FLUTTER_STARTUP_DELAY)
	@echo "🔨 Building the app once for the simulator..."
	@cd $(FLUTTER_DIR) && $(FLUTTER) build ios --debug --simulator \
		--dart-define=API_BASE_URL=http://127.0.0.1:8080/api \
		--dart-define=MAPBOX_ACCESS_TOKEN=$(MAPBOX_ACCESS_TOKEN)
	@APP="$(FLUTTER_DIR)/build/ios/iphonesimulator/Runner.app"; \
	ensure_sim() { \
		local name="$$1"; \
		local udid; \
		udid=$$(xcrun simctl list devices 2>/dev/null | grep -F "$$name (" | grep -oE '[0-9A-F-]{36}' | head -1); \
		if [ -z "$$udid" ]; then \
			echo "📲 Creating simulator \"$$name\" (17 Pro Max)..." 1>&2; \
			udid=$$(xcrun simctl create "$$name" "$(SIM_DEVICE_TYPE)" "$(SIM_RUNTIME)"); \
		fi; \
		echo "$$udid"; \
	}; \
	for role in "$(SIM_NAME_CLIENT)" "$(SIM_NAME_DRIVER)" "$(SIM_NAME_DISPATCHER)"; do \
		udid=$$(ensure_sim "$$role"); \
		echo "🚀 $$role → $$udid"; \
		xcrun simctl boot "$$udid" 2>/dev/null || true; \
		xcrun simctl install "$$udid" "$$APP"; \
		xcrun simctl launch "$$udid" de.dispax.app; \
	done; \
	open -a Simulator
	@echo "✅ App running on 3 named simulators (Dispax Client / Driver / Dispatcher)."
	@echo "   Log in via 'Quick Access for Testing' or: dispatcher@dispax.de / driver1@dispax.de / client1@bmw.de (password123)."
	@echo "   Backend (sbt run) stays in the foreground — Ctrl-C here stops it; or run 'make stop-dev'."
	@wait

# Kill all dev processes (backend + flutter)
stop-dev:
	@pkill -f "sbt run" 2>/dev/null || true
	@pkill -f "flutter run" 2>/dev/null || true
	@echo "✅ Stopped"
