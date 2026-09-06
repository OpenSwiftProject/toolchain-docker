#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLCHAIN="${OPEN_SWIFT_TOOLCHAIN:-/opt/openswift/swift-6.3-gnustep/usr}"
PREFIX="${GNUSTEP_PREFIX:-/opt/openswift/gnustep}"
probe_dir="$(mktemp -d)"
trap 'rm -rf "$probe_dir"' EXIT
export LD_LIBRARY_PATH="$TOOLCHAIN/lib/swift/linux:$PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

for optimization in Onone O; do
  output="$probe_dir/$optimization"
  mkdir -p "$output"
  for source in First Second; do
    "$TOOLCHAIN/bin/swiftc" -frontend -enable-objc-interop \
      -objc-runtime-vendor=gnustep -"$optimization" -emit-object \
      "$ROOT_DIR/$source.sil" -o "$output/$source.o"
    sections="$(readelf -SW "$output/$source.o")"
    grep -Fq '__objc_selectors' <<<"$sections"
    if grep -Eq '[[:space:]]objc_selrefs[[:space:]]' <<<"$sections"; then
      echo "error: compiler still emits Darwin selector references" >&2
      exit 1
    fi
  done
  "$TOOLCHAIN/bin/swiftc" -emit-library "$output/First.o" "$output/Second.o" \
    -L "$PREFIX/lib" -lobjc -Xlinker --gc-sections \
    -Xlinker -z -Xlinker defs -o "$output/libSelectors.so"
  "$TOOLCHAIN/bin/swiftc" -emit-library "$output/Second.o" \
    -L "$PREFIX/lib" -lobjc -Xlinker --gc-sections \
    -Xlinker -z -Xlinker defs -o "$output/libOtherSelectors.so"
  "$TOOLCHAIN/bin/clang" -fobjc-runtime=gnustep-2.0 -Wno-selector \
    -I "$PREFIX/include" "$ROOT_DIR/Host.m" \
    -L "$PREFIX/lib" -lobjc -ldl -pthread -o "$output/Host"
  "$output/Host" "$output/libSelectors.so" "$output/libOtherSelectors.so"
done
