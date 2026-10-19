# IST to EST — developer tasks.  Run `make` (or `make help`) to list them.
#
# Works with the GNU Make 3.81 that ships with macOS. Xcode targets need macOS
# with Xcode 16+ and the tools from the Brewfile (`make bootstrap`).

SHELL := /bin/bash

PROJECT      := ISTtoEST.xcodeproj
SCHEME       := ISTtoEST
APP_NAME     := IST to EST
APP_BUNDLE   := $(APP_NAME).app
BUNDLE_ID    := io.github.surendrallam.ISTtoEST
CORE_PACKAGE := Packages/TimeConversionKit
DERIVED_DATA := build/DerivedData
SNAPSHOT_DIR := $(CURDIR)/build/snapshots
INSTALL_DIR  ?= /Applications
SITE_PORT    ?= 8000
SITE_URL     := https://surendrallam.github.io/ist-to-est-macos-widget/

DEBUG_APP   := $(DERIVED_DATA)/Build/Products/Debug/$(APP_BUNDLE)
RELEASE_APP := $(DERIVED_DATA)/Build/Products/Release/$(APP_BUNDLE)
LSREGISTER  := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS' -derivedDataPath $(DERIVED_DATA)

# Pipe xcodebuild through xcbeautify when it is installed. Recipes that pipe
# start with `set -o pipefail` so a failed build still fails the target.
ifneq ($(shell command -v xcbeautify 2>/dev/null),)
  FORMAT := | xcbeautify
else
  FORMAT :=
endif

.DEFAULT_GOAL := help

.PHONY: help bootstrap project xcode build test test-core test-app snapshots lint lint-fix \
        run install uninstall release icons site site-test check clean distclean

help: ## Show this list
	@echo "IST to EST — make targets"
	@echo
	@awk 'BEGIN { FS = ":.*## " } /^[a-zA-Z0-9_-]+:.*## / { printf "  \033[36m%-11s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo
	@echo "Variables: INSTALL_DIR=$(INSTALL_DIR)  SITE_PORT=$(SITE_PORT)  VERSION=<x.y.z> (release)"

bootstrap: ## Install XcodeGen, SwiftLint and xcbeautify with Homebrew (brew bundle)
	@command -v brew >/dev/null || { echo "Homebrew is required: https://brew.sh" >&2; exit 1; }
	brew bundle --file=Brewfile

project: ## Generate ISTtoEST.xcodeproj (plus Info.plist/entitlements) from project.yml
	@command -v xcodegen >/dev/null || { echo "XcodeGen is not installed. Run 'make bootstrap' (or 'brew install xcodegen')." >&2; exit 1; }
	xcodegen generate --spec project.yml

xcode: project ## Generate the project and open it in Xcode
	open $(PROJECT)

build: project ## Build the app and widget (Debug, ad-hoc signed)
	set -o pipefail; $(XCODEBUILD) -configuration Debug build $(FORMAT)

test: test-core test-app ## Run every test: core package, then app/widget tests

test-core: ## Run the TimeConversionKit package tests (swift test)
	swift test --package-path $(CORE_PACKAGE)

test-app: project ## Run the Xcode test target (widget rendering + strings)
	set -o pipefail; $(XCODEBUILD) -configuration Debug test $(FORMAT)

snapshots: project ## Render widget screenshots (every size, summer/winter, light/dark) into build/snapshots
	rm -rf "$(SNAPSHOT_DIR)"
	set -o pipefail; TEST_RUNNER_SNAPSHOT_OUTPUT_DIR="$(SNAPSHOT_DIR)" $(XCODEBUILD) test -only-testing:ISTtoESTTests/WidgetSnapshotTests $(FORMAT)
	@echo
	@echo "Widget snapshots: $(SNAPSHOT_DIR)"
	@ls -1 "$(SNAPSHOT_DIR)"

lint: ## Lint Swift sources with SwiftLint (--strict: warnings fail)
	@command -v swiftlint >/dev/null || { echo "SwiftLint is not installed. Run 'make bootstrap' (or 'brew install swiftlint')." >&2; exit 1; }
	swiftlint lint --strict

lint-fix: ## Auto-correct SwiftLint violations where possible
	@command -v swiftlint >/dev/null || { echo "SwiftLint is not installed. Run 'make bootstrap'." >&2; exit 1; }
	swiftlint --fix
	swiftlint lint --strict

run: build ## Build (Debug) and launch the app
	open "$(DEBUG_APP)"

install: project ## Build Release, install into /Applications and launch once so the widget registers
	set -o pipefail; $(XCODEBUILD) -configuration Release build $(FORMAT)
	@test -d "$(RELEASE_APP)/Contents/PlugIns/ISTtoESTWidget.appex" || { echo "error: the widget extension is missing from $(RELEASE_APP)" >&2; exit 1; }
	@if pgrep -x "$(APP_NAME)" >/dev/null; then \
		echo "Quitting the running copy of $(APP_NAME)…"; \
		osascript -e 'tell application id "$(BUNDLE_ID)" to quit' >/dev/null 2>&1 || pkill -x "$(APP_NAME)" || true; \
		sleep 1; \
	fi
	rm -rf "$(INSTALL_DIR)/$(APP_BUNDLE)"
	ditto "$(RELEASE_APP)" "$(INSTALL_DIR)/$(APP_BUNDLE)"
	@# Forget the build-folder copies so the widget gallery lists only the installed app.
	@-"$(LSREGISTER)" -u "$(RELEASE_APP)" >/dev/null 2>&1
	@-"$(LSREGISTER)" -u "$(DEBUG_APP)" >/dev/null 2>&1
	@-"$(LSREGISTER)" -f "$(INSTALL_DIR)/$(APP_BUNDLE)" >/dev/null 2>&1
	open "$(INSTALL_DIR)/$(APP_BUNDLE)"
	@echo
	@echo "Installed $(INSTALL_DIR)/$(APP_BUNDLE)"
	@echo
	@echo "Add the widget:"
	@echo "  1. Click the date and time in the menu bar to open Notification Center."
	@echo "  2. Scroll to the bottom and click Edit Widgets."
	@echo "  3. Search for \"IST to EST\"."
	@echo "  4. Drag Small, Medium or Large into Notification Center, or onto the desktop."

uninstall: ## Remove the app from /Applications
	@-osascript -e 'tell application id "$(BUNDLE_ID)" to quit' >/dev/null 2>&1
	rm -rf "$(INSTALL_DIR)/$(APP_BUNDLE)"

release: ## Build the universal release DMG + ZIP into build/release (signs/notarizes when credentials are set)
	./scripts/build-release.sh $(VERSION)

icons: ## Re-render the app icon and website icons from design/ (needs Node + Playwright)
	npm run icons

site: ## Serve the website from docs/ at http://localhost:8000 (SITE_PORT=…)
	@if ls build/snapshots/*.png >/dev/null 2>&1; then \
		mkdir -p docs/screenshots && cp build/snapshots/*.png docs/screenshots/ && \
		echo "Using widget screenshots from build/snapshots (docs/screenshots is git-ignored)."; \
	else \
		echo "Tip: run 'make snapshots' first to preview the widget screenshots locally."; \
	fi
	@echo "Serving docs/ at http://localhost:$(SITE_PORT)/  (published at $(SITE_URL)) — Ctrl-C to stop"
	python3 -m http.server $(SITE_PORT) --bind 127.0.0.1 --directory docs

site-test: ## Run the website tests (node --test docs/tests/)
	@# Guard: node --test passes silently when it finds no tests.
	@ls docs/tests/*.test.*js >/dev/null 2>&1 || { echo "error: no *.test.mjs files found in docs/tests" >&2; exit 1; }
	node --test docs/tests/

check: lint test site-test ## Everything CI checks: lint, all tests, website tests

clean: ## Remove build output (build/, SwiftPM .build)
	rm -rf build $(CORE_PACKAGE)/.build

distclean: clean ## clean + remove the generated Xcode project, Info.plists and entitlements
	rm -rf $(PROJECT) App/Info.plist Widget/Info.plist App/ISTtoEST.entitlements Widget/ISTtoESTWidget.entitlements
