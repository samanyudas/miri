# One entry point for setup and verification. CI runs `make lint` on Linux and `make native` on macOS.
# Cargo runs from the repository root so rust-toolchain.toml selects the pinned Rust.
.DEFAULT_GOAL := check
ENGINE := --manifest-path vendor/paneru/Cargo.toml --target-dir vendor/paneru/target --locked --no-default-features
SHELL_SCRIPTS := $(shell git ls-files '*.sh')

.PHONY: setup check lint lint-doctor docs harness-tests shell actions compat native doctor swift-lint engine-lint build test e2e package format

setup:
	git submodule update --init
	rustup toolchain install
	scripts/doctor.sh all

check: lint native

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

native: doctor swift-lint engine-lint build test e2e package

doctor:
	scripts/doctor.sh native

swift-lint:
	swift format lint --strict --recursive Sources Package.swift

engine-lint:
	env -u CARGO_BUILD_TARGET cargo fmt --manifest-path vendor/paneru/Cargo.toml --check
	env -u CARGO_BUILD_TARGET cargo clippy $(ENGINE) --all-targets -- -D warnings

build:
	scripts/build-prototype.sh

test:
	env -u CARGO_BUILD_TARGET cargo test $(ENGINE)

e2e:
	scripts/test-permission-prototype.sh

package:
	scripts/package-dmg.sh

format:
	swift format format --in-place --recursive Sources Package.swift
