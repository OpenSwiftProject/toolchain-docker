#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-openswiftproject/swift-gnustep-toolchain:6.3-alpha-ubuntu24-aarch64}"

docker run --rm --platform linux/arm64 "$IMAGE" bash -lc '
  set -euo pipefail
  "$OPEN_SWIFT_TOOLCHAIN/bin/swiftc" --version
  "$GNUSTEP_PREFIX/bin/gnustep-config" --objc-flags >/dev/null
  test -f "$GNUSTEP_PREFIX/lib/libobjc.so" || test -f "$GNUSTEP_PREFIX/lib/libobjc.so.4.6"
  test -f "$GNUSTEP_PREFIX/lib/libgnustep-base.so" || test -f "$GNUSTEP_PREFIX/lib/libgnustep-base.so.1.31.1"
'

