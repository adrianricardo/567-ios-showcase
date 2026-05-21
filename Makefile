# Agent-friendly build commands for Five67.
# Generated from project.yml via XcodeGen; uses xcbeautify when available.

SCHEME ?= Five67
BUILD_DESTINATION ?= generic/platform=iOS Simulator
TEST_DESTINATION ?= platform=iOS Simulator,name=iPhone 17 Pro
DERIVED_DATA ?= build/DerivedData
XCB := $(shell command -v xcbeautify 2>/dev/null)

.PHONY: doctor generate build test clean open

doctor:
	@command -v xcodegen >/dev/null || { echo "Missing xcodegen. Install with: brew install xcodegen"; exit 1; }
	@xcodebuild -version >/dev/null || { echo "xcodebuild is unavailable. Select a full Xcode with: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"; exit 1; }

generate: doctor
	xcodegen generate

build: generate
	@if [ -n "$(XCB)" ]; then \
		xcodebuild build -scheme $(SCHEME) -destination '$(BUILD_DESTINATION)' -derivedDataPath $(DERIVED_DATA) | xcbeautify; \
	else \
		xcodebuild build -scheme $(SCHEME) -destination '$(BUILD_DESTINATION)' -derivedDataPath $(DERIVED_DATA); \
	fi

test: generate
	@if [ -n "$(XCB)" ]; then \
		xcodebuild test -scheme $(SCHEME) -destination '$(TEST_DESTINATION)' -derivedDataPath $(DERIVED_DATA) | xcbeautify; \
	else \
		xcodebuild test -scheme $(SCHEME) -destination '$(TEST_DESTINATION)' -derivedDataPath $(DERIVED_DATA); \
	fi

open: generate
	open CumbiaMoves.xcodeproj

clean:
	rm -rf $(DERIVED_DATA)
