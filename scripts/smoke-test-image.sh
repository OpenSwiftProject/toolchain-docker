#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-ghcr.io/openswiftproject/swift-gnustep-toolchain:6.3-alpha-ubuntu24-aarch64}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="${2:-$ROOT_DIR/tests/swiftpm-objc-smoke}"

if [[ ! -d "$PACKAGE_DIR" ]]; then
  echo "error: package directory not found: $PACKAGE_DIR" >&2
  exit 1
fi
PACKAGE_DIR="$(cd "$PACKAGE_DIR" && pwd -P)"

if [[ ! -f "$PACKAGE_DIR/Package.swift" ]]; then
  echo "error: no Package.swift found in $PACKAGE_DIR" >&2
  exit 1
fi

docker run --rm --platform linux/arm64 \
  --mount "type=bind,src=$ROOT_DIR/scripts/smoke-test-swift-package.sh,dst=/opt/openswift-smoke/smoke-test-swift-package.sh,readonly" \
  --mount "type=bind,src=$PACKAGE_DIR,dst=/opt/openswift-smoke/package,readonly" \
  "$IMAGE" bash -lc '
  set -euo pipefail
  "$OPEN_SWIFT_TOOLCHAIN/bin/swiftc" --version
  "$OPEN_SWIFT_TOOLCHAIN/bin/swift" package --version
  test -e "$OPEN_SWIFT_TOOLCHAIN/bin/swift-test"
  "$OPEN_SWIFT_TOOLCHAIN/bin/clang" --version
  command -v git
  command -v ssh
  command -v pkg-config
  command -v tar
  command -v unzip
  command -v zip
  test -f "$GNUSTEP_PREFIX/lib/libobjc.so" || test -f "$GNUSTEP_PREFIX/lib/libobjc.so.4.6"
  test -f "$GNUSTEP_PREFIX/lib/libgnustep-base.so" || test -f "$GNUSTEP_PREFIX/lib/libgnustep-base.so.1.31.1"
  test -f "$OPEN_SWIFT_TOOLCHAIN/lib/libIndexStore.so"
  test -f "$OPEN_SWIFT_TOOLCHAIN/lib/swift/host/plugins/libTestingMacros.so"

  testing_macro_smoke_dir="$(mktemp -d)"
  cat > "$testing_macro_smoke_dir/TestingMacroSmoke.swift" <<EOF
import Testing

@Test
func installedTestingMacroExpands() {
  #expect(1 + 1 == 2)
}
EOF
  "$OPEN_SWIFT_TOOLCHAIN/bin/swiftc" -typecheck \
    "$testing_macro_smoke_dir/TestingMacroSmoke.swift"
  rm -rf "$testing_macro_smoke_dir"

  broken_symlinks="$(find "$OPEN_SWIFT_TOOLCHAIN" -xtype l -print)"
  if [[ -n "$broken_symlinks" ]]; then
    printf "error: installed toolchain contains dangling symlinks:\n%s\n" \
      "$broken_symlinks" >&2
    exit 1
  fi

  check_dynamic_dependencies() {
    local artifact="$1"
    local output

    if ! output="$(ldd "$artifact" 2>&1)"; then
      printf "error: ldd failed for %s:\n%s\n" "$artifact" "$output" >&2
      return 1
    fi
    if grep -q "not found" <<<"$output"; then
      printf "error: %s has an unresolved runtime dependency:\n%s\n" \
        "$artifact" "$output" >&2
      return 1
    fi
  }

  check_dynamic_dependencies "$GNUSTEP_PREFIX/lib/libgnustep-base.so"
  check_dynamic_dependencies "$OPEN_SWIFT_TOOLCHAIN/lib/libIndexStore.so"
  check_dynamic_dependencies "$OPEN_SWIFT_TOOLCHAIN/bin/swift-package"
  check_dynamic_dependencies "$OPEN_SWIFT_TOOLCHAIN/lib/swift/pm/ManifestAPI/libPackageDescription.so"

  OBJCFLAGS="$("$GNUSTEP_PREFIX/bin/gnustep-config" --objc-flags)"
  BASELIBS="$("$GNUSTEP_PREFIX/bin/gnustep-config" --base-libs)"
  if [[ -z "$OBJCFLAGS" || "$BASELIBS" != *-lgnustep-base* ]]; then
    echo "error: gnustep-config did not return usable Objective-C/Foundation flags" >&2
    echo "objc flags: $OBJCFLAGS" >&2
    echo "base libs: $BASELIBS" >&2
    exit 1
  fi

  tmpdir="$(mktemp -d)"
  cat > "$tmpdir/FoundationSmoke.m" <<'"'"'EOF'"'"'
#import <Foundation/Foundation.h>

int main(void) {
  @autoreleasepool {
    NSString *message = @"GNUstep Foundation smoke";
    NSArray *items = @[ message, @"from", @"OpenSwiftProject" ];
    NSLog(@"%@ (%lu items)", message, (unsigned long)[items count]);
  }
  return 0;
}
EOF

  "$OPEN_SWIFT_TOOLCHAIN/bin/clang" $OBJCFLAGS \
    -fobjc-runtime=gnustep-2.0 \
    -fobjc-arc \
    -fblocks \
    "$tmpdir/FoundationSmoke.m" \
    -o "$tmpdir/FoundationSmoke" \
    $BASELIBS \
    -L"$GNUSTEP_PREFIX/lib" \
    -lobjc \
    -lBlocksRuntime \
    -ldispatch \
    -Wl,-rpath,"$GNUSTEP_PREFIX/lib"
  "$tmpdir/FoundationSmoke"

  bash /opt/openswift-smoke/smoke-test-swift-package.sh /opt/openswift-smoke/package
'
