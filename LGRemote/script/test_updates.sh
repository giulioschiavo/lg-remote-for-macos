#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build-cache
TEST_BIN="$(mktemp -t lg-remote-updates)"
trap 'rm -f "$TEST_BIN"' EXIT
swiftc -swift-version 5 -parse-as-library -module-cache-path .build-cache Sources/UpdateChecker.swift Sources/Localization.swift Tests/UpdateCheckerTests.swift -o "$TEST_BIN" -framework Cocoa -framework UserNotifications
"$TEST_BIN" "$@"
