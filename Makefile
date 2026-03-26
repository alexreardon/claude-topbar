.PHONY: build run clean install uninstall

BUILD_APP = build/ClaudeTopbar.app
BUILD_CONTENTS = $(BUILD_APP)/Contents
BUILD_MACOS = $(BUILD_CONTENTS)/MacOS

build:
	swift build -c release
	@mkdir -p "$(BUILD_MACOS)"
	@cp .build/release/ClaudeTopbar "$(BUILD_MACOS)/ClaudeTopbar"
	@cp Resources/Info.plist "$(BUILD_CONTENTS)/Info.plist"
	@codesign --force --sign - "$(BUILD_APP)" 2>/dev/null || true

run: build
	@pkill -x ClaudeTopbar 2>/dev/null || true
	@sleep 0.5
	@open "$(BUILD_APP)"

clean:
	swift package clean
	rm -rf build

APP_DIR = $(HOME)/Applications/ClaudeTopbar.app

install: build
	@mkdir -p "$(HOME)/Applications"
	@rm -rf "$(APP_DIR)"
	@cp -R "$(BUILD_APP)" "$(APP_DIR)"
	@echo "Installed to $(APP_DIR)"

uninstall:
	@pkill -x ClaudeTopbar 2>/dev/null || true
	@rm -rf "$(APP_DIR)"
	@echo "Removed $(APP_DIR)"
