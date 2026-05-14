.PHONY: fmt fmt-watch dev prod test clean rebuild \
        flutter-dev flutter-prod flutter-dev-android flutter-dev-ios flutter-prod-android \
        deploy logs

PROD_URL := https://oktopus-456043977402.europe-west1.run.app
MAC_IP := 192.168.0.188
GCP_PROJECT := project-6efcac64-991b-49f4-946
GCP_REGION := europe-west1
GCP_SERVICE := oktopus
GCP_IMAGE := europe-west1-docker.pkg.dev/$(GCP_PROJECT)/oktopus-docker/oktopus-server:latest
FLUTTER_DIR := web

# ─── Backend ────────────────────────────────────────────────────────────────

# Start backend locally with dev profile (reads .env.dev)
dev:
	@export $$(cat .env.dev | grep -v '^#' | xargs) && sbt run

# Run tests
test:
	sbt test

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
