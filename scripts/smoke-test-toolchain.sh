#!/usr/bin/env bash
set -euo pipefail

OPEN_SWIFT_TOOLCHAIN="${OPEN_SWIFT_TOOLCHAIN:-/opt/openswift/swift-6.3-gnustep/usr}"
GNUSTEP_PREFIX="${GNUSTEP_PREFIX:-/opt/openswift/gnustep}"
SWIFT_PACKAGE_FIXTURE="${SWIFT_PACKAGE_FIXTURE:-/opt/openswift-build/tests/swiftpm-objc-smoke}"

export PATH="$OPEN_SWIFT_TOOLCHAIN/bin:$GNUSTEP_PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$OPEN_SWIFT_TOOLCHAIN/lib/swift/linux:$OPEN_SWIFT_TOOLCHAIN/lib:$GNUSTEP_PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

"$OPEN_SWIFT_TOOLCHAIN/bin/swiftc" --version
"$OPEN_SWIFT_TOOLCHAIN/bin/swift" package --version
"$GNUSTEP_PREFIX/bin/gnustep-config" --objc-flags >/dev/null
test -f "$GNUSTEP_PREFIX/lib/libobjc.so" || test -f "$GNUSTEP_PREFIX/lib/libobjc.so.4.6"
test -f "$GNUSTEP_PREFIX/lib/libgnustep-base.so" || test -f "$GNUSTEP_PREFIX/lib/libgnustep-base.so.1.31.1"
test -x "$OPEN_SWIFT_TOOLCHAIN/bin/swift-package"
test -e "$OPEN_SWIFT_TOOLCHAIN/bin/swift-build"
test -e "$OPEN_SWIFT_TOOLCHAIN/bin/swift-run"
test -e "$OPEN_SWIFT_TOOLCHAIN/bin/swift-test"
test -x "$OPEN_SWIFT_TOOLCHAIN/bin/swift-build-tool"
test -f "$OPEN_SWIFT_TOOLCHAIN/lib/libIndexStore.so"
test -f "$OPEN_SWIFT_TOOLCHAIN/lib/swift/pm/ManifestAPI/libPackageDescription.so"
test -f "$OPEN_SWIFT_TOOLCHAIN/lib/swift/pm/PluginAPI/libPackagePlugin.so"
test -f "$OPEN_SWIFT_TOOLCHAIN/lib/swift/linux/libFoundation.so"
test -f "$OPEN_SWIFT_TOOLCHAIN/lib/swift/linux/libdispatch.so"
test -f "$OPEN_SWIFT_TOOLCHAIN/lib/swift/linux/libXCTest.so"
test -d "$OPEN_SWIFT_TOOLCHAIN/lib/swift/linux/XCTest.swiftmodule"
test -f "$OPEN_SWIFT_TOOLCHAIN/lib/swift/linux/libTesting.so"
test -d "$OPEN_SWIFT_TOOLCHAIN/lib/swift/linux/Testing.swiftmodule"
test -f "$OPEN_SWIFT_TOOLCHAIN/lib/swift/host/plugins/libTestingMacros.so"

testing_macro_smoke_dir="$(mktemp -d)"
trap 'rm -rf "$testing_macro_smoke_dir"' EXIT
cat > "$testing_macro_smoke_dir/TestingMacroSmoke.swift" <<'EOF'
import Testing

@Test
func installedTestingMacroExpands() {
  #expect(1 + 1 == 2)
}
EOF
"$OPEN_SWIFT_TOOLCHAIN/bin/swiftc" -typecheck \
  "$testing_macro_smoke_dir/TestingMacroSmoke.swift"
rm -rf "$testing_macro_smoke_dir"
trap - EXIT

broken_symlinks="$(find "$OPEN_SWIFT_TOOLCHAIN" -xtype l -print)"
if [[ -n "$broken_symlinks" ]]; then
  printf 'error: installed toolchain contains dangling symlinks:\n%s\n' \
    "$broken_symlinks" >&2
  exit 1
fi

check_dynamic_dependencies() {
  local artifact="$1"
  local output

  if ! output="$(ldd "$artifact" 2>&1)"; then
    printf 'error: ldd failed for %s:\n%s\n' "$artifact" "$output" >&2
    return 1
  fi
  if grep -q "not found" <<<"$output"; then
    printf 'error: %s has an unresolved runtime dependency:\n%s\n' \
      "$artifact" "$output" >&2
    return 1
  fi
}

check_dynamic_dependencies "$OPEN_SWIFT_TOOLCHAIN/bin/swift-package"
check_dynamic_dependencies "$OPEN_SWIFT_TOOLCHAIN/lib/libIndexStore.so"
check_dynamic_dependencies "$OPEN_SWIFT_TOOLCHAIN/lib/swift/pm/ManifestAPI/libPackageDescription.so"

OPEN_SWIFT_TOOLCHAIN="$OPEN_SWIFT_TOOLCHAIN" \
  /opt/openswift-build/scripts/smoke-test-swift-package.sh "$SWIFT_PACKAGE_FIXTURE"
