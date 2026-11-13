# One entry point for setup and verification. CI runs `make lint` on Linux and `make native` on macOS.
# Cargo runs from the repository root so rust-toolchain.toml selects the pinned Rust and .cargo/config.toml applies.
.DEFAULT_GOAL := check
ENGINE := --manifest-path vendor/paneru/Cargo.toml --target-dir vendor/paneru/target --locked --no-default-features
SHELL_SCRIPTS := $(shell git ls-files '*.sh' .githooks)

.PHONY: setup pre-push check lint lint-doctor docs harness-tests shell actions compat native doctor swift-lint strings strings-update engine-format engine-lint build test swift-test engine-test e2e package release-candidate format verify-engine-lifecycle

setup:
	git submodule update --init
	git config core.hooksPath .githooks
	rustup toolchain install
	scripts/setup-signing.sh
	scripts/doctor.sh all

check: lint native

# The checks that finish in seconds. The pre-push hook in .githooks runs them.
pre-push: lint swift-lint engine-format

lint: lint-doctor docs harness-tests shell actions compat

lint-doctor:
	scripts/doctor.sh lint

docs:
	python3 scripts/check-docs.py

harness-tests:
	python3 -m unittest discover -s scripts/tests

shell:
	shellcheck $(SHELL_SCRIPTS)

actions:
	actionlint

compat:
	python3 scripts/check-compat.py

native: doctor swift-lint strings engine-lint build test e2e package

doctor:
	scripts/doctor.sh native

swift-lint:
	swift format lint --strict --recursive Sources Tests Package.swift

# Fails on interface text in Sources that is not localized where it stands, or when Localization/Localizable.xcstrings
# differs from the strings the compiler extracts. `make strings-update` fixes the catalog. It needs macOS.
strings:
	scripts/sync-strings.sh --check

strings-update:
	scripts/sync-strings.sh

engine-format:
	env -u CARGO_BUILD_TARGET cargo fmt --manifest-path vendor/paneru/Cargo.toml --check

engine-lint: engine-format
	env -u CARGO_BUILD_TARGET cargo clippy $(ENGINE) --all-targets -- -D warnings

build:
	scripts/build-app.sh

test: swift-test engine-test

swift-test:
	swift test

engine-test:
	env -u CARGO_BUILD_TARGET cargo test $(ENGINE)

# The selftests launch the app at APP from this checkout, so they hold the live-test lock while they run.
# An agent that already holds the lock passes its own owner: `make e2e LIVE_LOCK_OWNER="<owner>"`.
APP ?= .build/app/Miri Developer.app
LIVE_LOCK_OWNER ?= make e2e in $(CURDIR)
e2e:
	python3 scripts/live-lock.py run --owner "$(LIVE_LOCK_OWNER)" --minutes 15 \
		--task "make e2e launches $(APP) selftests from this checkout" \
		-- sh -c 'scripts/test-permission-prototype.sh "$$1" && scripts/test-window-recovery.sh "$$1"' sh "$(APP)"

package:
	scripts/package-dmg.sh "$(APP)"

# Builds the stable Miri app with the release-profile engine, then selftests and packages that exact bundle.
release-candidate:
	scripts/build-app.sh --release
	$(MAKE) e2e APP=.build/app/Miri.app
	scripts/package-dmg.sh .build/app/Miri.app

format:
	swift format format --in-place --recursive Sources Tests Package.swift

# Model-checks the engine lifecycle. .claude/skills/verify-engine-lifecycle/SKILL.md says when and how to read it.
verify-engine-lifecycle:
	python3 scripts/verify-engine-lifecycle.py --mutants
