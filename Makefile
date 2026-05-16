.PHONY: fmt fmt-watch dev prod test test-bdd test-all clean rebuild \
        flutter-dev flutter-prod flutter-dev-android flutter-dev-ios flutter-prod-android \
        flutter-test-integration \
        flutter-dev-iphone-sergii flutter-dev-android-sergii flutter-dev-sergii \
        deploy logs

PROD_URL := https://oktopus-456043977402.europe-west1.run.app
MAC_IP := $(shell ipconfig getifaddr en0)
GCP_PROJECT := project-6efcac64-991b-49f4-946
GCP_REGION := europe-west1
GCP_SERVICE := oktopus
GCP_IMAGE := europe-west1-docker.pkg.dev/$(GCP_PROJECT)/oktopus-docker/oktopus-server:latest
FLUTTER_DIR    := web
IPHONE_SERGII  := 00008150-000978860ED8401C
ANDROID_SERGII := 192.168.0.60:5555

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

# Run Flutter integration tests against local TestApplication (port 8080)
flutter-test-integration:
	@echo "🚀 Starting test backend..."
	@sbt testServer &
	@echo "⏳ Waiting for backend to be ready..."
	@until curl -sf http://localhost:8080/health > /dev/null; do sleep 1; done
	@echo "✅ Backend ready, running Flutter integration tests..."
	@cd $(FLUTTER_DIR) && flutter test test/integration/ ; \
	  STATUS=$$? ; \
	  pkill -f "testServer" 2>/dev/null || true ; \
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
	cd $(FLUTTER_DIR) && flutter run -d $(IPHONE_SERGII) \
		--dart-define=API_BASE_URL=http://$(MAC_IP):8080/api

# Run Flutter on Sergii's Android (wireless) against local backend
flutter-dev-android-sergii:
	cd $(FLUTTER_DIR) && flutter run -d $(ANDROID_SERGII) \
		--dart-define=API_BASE_URL=http://$(MAC_IP):8080/api

# Run Flutter on both Sergii's devices simultaneously (wireless)
flutter-dev-sergii:
	cd $(FLUTTER_DIR) && flutter run -d $(IPHONE_SERGII) \
		--dart-define=API_BASE_URL=http://$(MAC_IP):8080/api & \
	cd $(FLUTTER_DIR) && flutter run -d $(ANDROID_SERGII) \
		--dart-define=API_BASE_URL=http://$(MAC_IP):8080/api & \
	wait
