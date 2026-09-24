# Agent-friendly build commands for Five67.
# Generated from project.yml via XcodeGen; uses xcbeautify when available.

SCHEME ?= Five67
BUNDLE_ID ?= com.nopal.five67.dev
BUILD_DESTINATION ?= generic/platform=iOS Simulator
TEST_DESTINATION ?= platform=iOS Simulator,name=iPhone 17 Pro
DERIVED_DATA ?= build/DerivedData
LOG_DIR ?= build/logs
XCB := $(shell command -v xcbeautify 2>/dev/null)

.PHONY: default build-and-run doctor generate build run run-fresh run-xcode test ui-test clean open logs-dir

default: build-and-run

build-and-run: build run

logs-dir:
	@mkdir -p $(LOG_DIR)

doctor:
	@command -v xcodegen >/dev/null || { echo "Missing xcodegen. Install with: brew install xcodegen"; exit 1; }
	@xcodebuild -version >/dev/null || { echo "xcodebuild is unavailable. Select a full Xcode with: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"; exit 1; }
	@if [ -z "$(XCB)" ]; then echo "Note: xcbeautify not found; install with: brew install xcbeautify for cleaner agent-readable build logs."; fi

generate: doctor
	xcodegen generate

build: generate logs-dir
	@set -o pipefail; \
	if [ -n "$(XCB)" ]; then \
		xcodebuild build -scheme $(SCHEME) -destination '$(BUILD_DESTINATION)' -derivedDataPath $(DERIVED_DATA) 2>&1 | tee $(LOG_DIR)/build.raw.log | xcbeautify | tee $(LOG_DIR)/build.pretty.log; \
	else \
		xcodebuild build -scheme $(SCHEME) -destination '$(BUILD_DESTINATION)' -derivedDataPath $(DERIVED_DATA) 2>&1 | tee $(LOG_DIR)/build.raw.log; \
	fi

run: generate
	@xcodebuild -scheme $(SCHEME) -destination '$(TEST_DESTINATION)' -derivedDataPath $(DERIVED_DATA) -quiet build
	@APP_PATH="$$(find '$(DERIVED_DATA)' -path "*.app" -name "$(SCHEME).app" | head -n 1)"; \
	if [ -z "$$APP_PATH" ]; then echo "Could not find built app under $(DERIVED_DATA). Run make build first."; exit 1; fi; \
	DEVICE_ID="$$(xcrun simctl list devices available | awk -F '[()]' '/$(shell printf "%s" "$(TEST_DESTINATION)" | sed -n "s/.*name=\([^,]*\).*/\1/p")/ {print $$2; exit}')"; \
	if [ -z "$$DEVICE_ID" ]; then echo "Could not find simulator for TEST_DESTINATION=$(TEST_DESTINATION)."; exit 1; fi; \
	xcrun simctl boot "$$DEVICE_ID" >/dev/null 2>&1 || true; \
	xcrun simctl install "$$DEVICE_ID" "$$APP_PATH"; \
	xcrun simctl launch "$$DEVICE_ID" $(BUNDLE_ID)

# Fresh install: uninstall first so UserDefaults (onboarding flag) and the
# SwiftData store (imported videos) are wiped, guaranteeing the onboarding
# flow shows again. Use this while iterating on onboarding.
# NOTE: StoreKit's local config is NOT injected via simctl, so the paywall
# button stays disabled here. Use `make run-xcode` to exercise the purchase.
run-fresh: generate
	@xcodebuild -scheme $(SCHEME) -destination '$(TEST_DESTINATION)' -derivedDataPath $(DERIVED_DATA) -quiet build
	@APP_PATH="$$(find '$(DERIVED_DATA)' -path "*.app" -name "$(SCHEME).app" | head -n 1)"; \
	if [ -z "$$APP_PATH" ]; then echo "Could not find built app under $(DERIVED_DATA). Run make build first."; exit 1; fi; \
	DEVICE_ID="$$(xcrun simctl list devices available | awk -F '[()]' '/$(shell printf "%s" "$(TEST_DESTINATION)" | sed -n "s/.*name=\([^,]*\).*/\1/p")/ {print $$2; exit}')"; \
	if [ -z "$$DEVICE_ID" ]; then echo "Could not find simulator for TEST_DESTINATION=$(TEST_DESTINATION)."; exit 1; fi; \
	xcrun simctl boot "$$DEVICE_ID" >/dev/null 2>&1 || true; \
	echo "Uninstalling $(BUNDLE_ID) to reset onboarding + local data..."; \
	xcrun simctl uninstall "$$DEVICE_ID" $(BUNDLE_ID) >/dev/null 2>&1 || true; \
	xcrun simctl install "$$DEVICE_ID" "$$APP_PATH"; \
	xcrun simctl launch "$$DEVICE_ID" $(BUNDLE_ID)

# Launch through Xcode's scheme so the local StoreKit configuration is
# injected and the paywall's product loads (button enables, purchase works).
# This is the only CLI path that activates Five67.storekit. Requires Xcode.
run-xcode: generate
	@scripts/run_in_xcode.sh "$(CURDIR)/Five67.xcodeproj" "$(SCHEME)"

test: generate logs-dir
	@set -o pipefail; \
	if [ -n "$(XCB)" ]; then \
		xcodebuild test -scheme $(SCHEME) -destination '$(TEST_DESTINATION)' -derivedDataPath $(DERIVED_DATA) 2>&1 | tee $(LOG_DIR)/test.raw.log | xcbeautify | tee $(LOG_DIR)/test.pretty.log; \
	else \
		xcodebuild test -scheme $(SCHEME) -destination '$(TEST_DESTINATION)' -derivedDataPath $(DERIVED_DATA) 2>&1 | tee $(LOG_DIR)/test.raw.log; \
	fi

ui-test:
	@echo "No UI test target is configured yet. Add one in project.yml, then wire this target to that scheme/test plan."
	@exit 2

open: generate
	open Five67.xcodeproj

clean:
	@mkdir -p build
	@scripts/move_to_trash.sh $(DERIVED_DATA) $(LOG_DIR)
