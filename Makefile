.PHONY: fmt fmt-watch dev prod test test-bdd test-all clean rebuild \
        flutter-dev flutter-prod flutter-dev-android flutter-dev-ios flutter-prod-android \
        flutter-test-integration \
        patrol-test-android patrol-test-ios \
        emulator-up e2e-backend-up e2e-backend-down e2e-android e2e-ios e2e-test e2e-fast \
        flutter-dev-iphone-sergii flutter-dev-android-sergii flutter-dev-sergii \
        dev-all stop-dev \
        deploy logs setup-hooks

PROD_URL := https://dispax-o2trzxjbva-ew.a.run.app
MAC_IP := $(shell ipconfig getifaddr en0)
GCP_PROJECT := project-6efcac64-991b-49f4-946
GCP_REGION := europe-west1
GCP_SERVICE := dispax
GCP_IMAGE := europe-west1-docker.pkg.dev/$(GCP_PROJECT)/dispax-docker/dispax-server:latest
FLUTTER_DIR    := web
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

# Start backend locally with dev profile (reads .env.dev)
dev:
	@export $$(cat .env.dev | grep -v '^#' | xargs) && sbt run

# Run BDD Cucumber scenarios
test-bdd:
	sbt cucumber

# Run all unit + integration tests (excludes Cucumber)
test:
	sbt "core/test; auth/test; ride/test; driver/test; notification/test; schedule/test"

# Run Flutter integration tests against local TestApplication.
# Backend runs on TEST_PORT (default 8090) so it doesn't collide with a dev
# server on 8080. The test PID is tracked so only this server is stopped.
flutter-test-integration:
	@echo "🚀 Starting test backend on port $(TEST_PORT)..."
	@PORT=$(TEST_PORT) sbt testServer & echo $$! > /tmp/dispax-testserver.pid
	@echo "⏳ Waiting for backend to be ready..."
	@until curl -sf http://localhost:$(TEST_PORT)/health > /dev/null; do sleep 1; done
	@echo "✅ Backend ready, running Flutter integration tests..."
	@cd $(FLUTTER_DIR) && flutter test test/integration/ \
	  --dart-define=TEST_SERVER_PORT=$(TEST_PORT) ; \
	  STATUS=$$? ; \
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
	  flutter emulators --launch $(ANDROID_AVD); \
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
              e2e_neg_login e2e_neg_create_ride e2e_neg_role_access
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
                   --exclude integration_test/permissions_test.dart
e2e-fast: emulator-up e2e-backend-up
	@echo "🧪 Running ALL Patrol E2E in one bundle (Android, no orchestrator)..."
	@cd $(FLUTTER_DIR) && $(PATROL) test $(PATROL_EXCLUDES) \
	  --dart-define=API_BASE_URL=http://10.0.2.2:$(TEST_PORT)/api ; \
	  STATUS=$$? ; \
	  $(MAKE) -C .. e2e-backend-down ; \
	  exit $$STATUS

# Run all tests: unit + integration + Cucumber BDD
test-all:
	@echo "▶ Running unit + integration tests..."
	sbt "core/test; auth/test; ride/test; driver/test; notification/test; schedule/test"
	@echo "▶ Running Cucumber BDD tests..."
	sbt cucumber

# Format all Scala code
fmt:
	sbt fmtAll

fmt-watch:
	sbt fmtWatch

# Clean build
clean:
	sbt clean

rebuild: clean
	sbt compile

# ─── Deploy ─────────────────────────────────────────────────────────────────

# Build and push Docker image, then deploy to Cloud Run
deploy:
	sbt assembly
	docker buildx build --platform linux/amd64 -t $(GCP_IMAGE) --push .
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

# Run Flutter on any connected device against local backend
flutter-dev:
	cd $(FLUTTER_DIR) && flutter run \
		--dart-define=API_BASE_URL=http://$(MAC_IP):8080/api

# Run Flutter on Android emulator against local backend
flutter-dev-android:
	cd $(FLUTTER_DIR) && flutter run -d emulator-5554 \
		--dart-define=API_BASE_URL=http://10.0.2.2:8080/api

# Run Flutter on iOS simulator against local backend
flutter-dev-ios:
	cd $(FLUTTER_DIR) && flutter run -d 09021E1A-BC6A-4D86-A2EA-06A5894E4AEC \
		--dart-define=API_BASE_URL=http://$(MAC_IP):8080/api

# Run Flutter against production backend
flutter-prod:
	cd $(FLUTTER_DIR) && flutter run \
		--dart-define=API_BASE_URL=$(PROD_URL)/api

# Build Android APK for production
flutter-prod-android:
	cd $(FLUTTER_DIR) && flutter build apk --release \
		--dart-define=API_BASE_URL=$(PROD_URL)/api
	@echo "✅ APK: $(FLUTTER_DIR)/build/app/outputs/flutter-apk/app-release.apk"

# Run Flutter on Sergii's iPhone (wireless) against local backend
flutter-dev-iphone-sergii:
	cd $(FLUTTER_DIR) && flutter run -d $(FLUTTER_DEVICE_IPHONE_SERGII) \
		--dart-define=API_BASE_URL=http://$(MAC_IP):8080/api

# Run Flutter on Sergii's Android (wireless) against local backend
flutter-dev-android-sergii:
	cd $(FLUTTER_DIR) && flutter run -d $(FLUTTER_DEVICE_ANDROID_SERGII) \
		--dart-define=API_BASE_URL=http://$(MAC_IP):8080/api

# Run Flutter on both Sergii's devices simultaneously (wireless)
flutter-dev-sergii:
	cd $(FLUTTER_DIR) && flutter run -d $(FLUTTER_DEVICE_IPHONE_SERGII) \
		--dart-define=API_BASE_URL=http://$(MAC_IP):8080/api & \
	cd $(FLUTTER_DIR) && flutter run -d $(FLUTTER_DEVICE_ANDROID_SERGII) \
		--dart-define=API_BASE_URL=http://$(MAC_IP):8080/api & \
	wait

# Start local backend + Flutter on both devices in one command
# Hot reload Flutter: press 'r' in each flutter process terminal
# To restart backend after Scala changes: make stop-dev && make dev-all
dev-all:
	@export $$(cat .env.dev | grep -v '^#' | xargs) && sbt run &
	@echo "⏳ Waiting for backend on :8080..."
	@until curl -sf http://localhost:8080/health > /dev/null; do sleep 1; done
	@echo "✅ Backend ready — starting Flutter on both devices"
	@cd $(FLUTTER_DIR) && flutter run -d $(FLUTTER_DEVICE_IPHONE_SERGII) \
		--dart-define=API_BASE_URL=http://$(MAC_IP):8080/api & \
	cd $(FLUTTER_DIR) && flutter run -d $(FLUTTER_DEVICE_ANDROID_SERGII) \
		--dart-define=API_BASE_URL=http://$(MAC_IP):8080/api & \
	wait

# Kill all dev processes (backend + flutter)
stop-dev:
	@pkill -f "sbt run" 2>/dev/null || true
	@pkill -f "flutter run" 2>/dev/null || true
	@echo "✅ Stopped"
