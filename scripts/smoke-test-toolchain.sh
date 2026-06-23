#!/usr/bin/env bash
set -euo pipefail

OPEN_SWIFT_TOOLCHAIN="${OPEN_SWIFT_TOOLCHAIN:-/opt/openswift/swift-6.3-gnustep/usr}"
GNUSTEP_PREFIX="${GNUSTEP_PREFIX:-/opt/openswift/gnustep}"

"$OPEN_SWIFT_TOOLCHAIN/bin/swiftc" --version
"$GNUSTEP_PREFIX/bin/gnustep-config" --objc-flags >/dev/null
test -f "$GNUSTEP_PREFIX/lib/libobjc.so" || test -f "$GNUSTEP_PREFIX/lib/libobjc.so.4.6"
test -f "$GNUSTEP_PREFIX/lib/libgnustep-base.so" || test -f "$GNUSTEP_PREFIX/lib/libgnustep-base.so.1.31.1"

