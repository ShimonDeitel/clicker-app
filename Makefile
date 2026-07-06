XCODEGEN ?= $(shell command -v xcodegen 2>/dev/null || echo /opt/homebrew/bin/xcodegen)

.PHONY: gen build

gen:
	$(XCODEGEN) generate

build: gen
	xcodebuild -project Clicker.xcodeproj -scheme Clicker -destination 'generic/platform=iOS Simulator' build
