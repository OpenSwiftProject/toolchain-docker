#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-ghcr.io/openswiftproject/swift-gnustep-toolchain:6.3-alpha-ubuntu24-aarch64}"

docker run --rm --platform linux/arm64 "$IMAGE" bash -lc '
  set -euo pipefail
  "$OPEN_SWIFT_TOOLCHAIN/bin/swiftc" --version
  "$OPEN_SWIFT_TOOLCHAIN/bin/clang" --version
  test -f "$GNUSTEP_PREFIX/lib/libobjc.so" || test -f "$GNUSTEP_PREFIX/lib/libobjc.so.4.6"
  test -f "$GNUSTEP_PREFIX/lib/libgnustep-base.so" || test -f "$GNUSTEP_PREFIX/lib/libgnustep-base.so.1.31.1"
  ! ldd "$GNUSTEP_PREFIX/lib/libgnustep-base.so" | grep "not found"

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
'
