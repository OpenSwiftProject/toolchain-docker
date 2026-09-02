#!/usr/bin/env bash
set -euo pipefail

PACKAGE_DIR="${1:?usage: smoke-test-swift-package.sh PACKAGE_DIR}"
OPEN_SWIFT_TOOLCHAIN="${OPEN_SWIFT_TOOLCHAIN:-/opt/openswift/swift-6.3-gnustep/usr}"
GNUSTEP_PREFIX="${GNUSTEP_PREFIX:-/opt/openswift/gnustep}"
SWIFT="$OPEN_SWIFT_TOOLCHAIN/bin/swift"

export PATH="$OPEN_SWIFT_TOOLCHAIN/bin:$GNUSTEP_PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$OPEN_SWIFT_TOOLCHAIN/lib/swift/linux:$OPEN_SWIFT_TOOLCHAIN/lib:$GNUSTEP_PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export CPATH="$GNUSTEP_PREFIX/include:$GNUSTEP_PREFIX/include/GNUstep${CPATH:+:$CPATH}"
export LIBRARY_PATH="$GNUSTEP_PREFIX/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
export PKG_CONFIG_PATH="$GNUSTEP_PREFIX/lib/pkgconfig:$GNUSTEP_PREFIX/share/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

if [[ ! -f "$PACKAGE_DIR/Package.swift" ]]; then
  echo "error: no Package.swift found in $PACKAGE_DIR" >&2
  exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
package_copy="$work_dir/package"
mkdir -p "$package_copy"

# The input can be a developer checkout with a large .build directory. Copy
# only source inputs so every smoke starts from a clean package state.
tar \
  --exclude='./.build' \
  --exclude='./.cache' \
  --exclude='./.git' \
  --exclude='./.swiftpm' \
  -C "$PACKAGE_DIR" -cf - . | tar -C "$package_copy" -xf -

"$SWIFT" package --version
"$SWIFT" package --package-path "$package_copy" dump-package >/dev/null

run_configuration() {
  local configuration="$1"
  local -a build_args=(--package-path "$package_copy")
  local -a run_args=(--package-path "$package_copy")
  local -a test_args=(
    --package-path "$package_copy"
    --scratch-path "$work_dir/test-$configuration"
  )

  if [[ "$configuration" == "release" ]]; then
    build_args+=(--configuration release)
    run_args+=(--configuration release)
    test_args+=(--configuration release)
  fi

  # Run tests first, with a dedicated scratch path, so the smoke proves that a
  # standalone `swift test` builds the sibling executable used by the tests.
  echo "== SwiftPM $configuration test =="
  local test_output
  if ! test_output="$("$SWIFT" test "${test_args[@]}" 2>&1)"; then
    printf '%s\n' "$test_output" >&2
    return 1
  fi
  printf '%s\n' "$test_output"

  grep -Fq "Swift Testing verified swift test" <<<"$test_output"
  grep -Fq "XCTest verified swift test" <<<"$test_output"

  echo "== SwiftPM $configuration build =="
  "$SWIFT" build "${build_args[@]}"

  echo "== SwiftPM $configuration run =="
  local output
  if ! output="$("$SWIFT" run "${run_args[@]}" GNUstepObjCDemo 2>&1)"; then
    printf '%s\n' "$output" >&2
    return 1
  fi
  printf '%s\n' "$output"

  grep -Fq "ObjCGreeter: Hello from GNUstep Objective-C (4 items)" <<<"$output"
  grep -Fq "Swift saw: Hello from GNUstep Objective-C" <<<"$output"
  grep -Fq "Swift saw item count: 4" <<<"$output"
}

run_configuration debug
run_configuration release
