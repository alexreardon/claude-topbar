.PHONY: build run clean install uninstall

build:
	swift build -c release

run:
	swift run

clean:
	swift package clean

APP_DIR = $(HOME)/Applications/ClaudeTopbar.app
CONTENTS_DIR = $(APP_DIR)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS

install: build
	@mkdir -p "$(MACOS_DIR)"
	@cp .build/release/ClaudeTopbar "$(MACOS_DIR)/ClaudeTopbar"
	@/usr/libexec/PlistBuddy -c "Delete :CFBundleName" "$(CONTENTS_DIR)/Info.plist" 2>/dev/null || true
	@/usr/libexec/PlistBuddy \
		-c "Add :CFBundleName string 'Claude Topbar'" \
		-c "Add :CFBundleIdentifier string 'com.claudetopbar.app'" \
		-c "Add :CFBundleExecutable string 'ClaudeTopbar'" \
		-c "Add :CFBundleVersion string '1.0'" \
		-c "Add :CFBundleShortVersionString string '1.0'" \
		-c "Add :LSUIElement bool true" \
		-c "Add :CFBundlePackageType string 'APPL'" \
		"$(CONTENTS_DIR)/Info.plist" 2>/dev/null || true
	@codesign --force --sign - "$(APP_DIR)" 2>/dev/null || true
	@echo "Installed to $(APP_DIR)"

uninstall:
	@rm -rf "$(APP_DIR)"
	@echo "Removed $(APP_DIR)"
