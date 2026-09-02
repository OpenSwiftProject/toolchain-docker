#!/usr/bin/env bash
set -euo pipefail

OPEN_SWIFT_SOURCE_ROOT="${OPEN_SWIFT_SOURCE_ROOT:-/work/OpenSwiftProject/swift-projects}"
OPEN_SWIFT_TOOLCHAIN_DESTDIR="${OPEN_SWIFT_TOOLCHAIN_DESTDIR:-/opt/openswift/swift-6.3-gnustep}"
OPEN_SWIFT_BOOTSTRAP_TOOLCHAIN="${OPEN_SWIFT_BOOTSTRAP_TOOLCHAIN:-/opt/openswift-bootstrap/usr}"
BUILD_JOBS="${BUILD_JOBS:-3}"

SWIFT_ROOT="$OPEN_SWIFT_SOURCE_ROOT/swift"
SWIFT_BUILD_SUBDIR="${SWIFT_BUILD_SUBDIR:-openswift-gnustep-linux-aarch64}"
SWIFT_CMAKE_OPTIONS=(
  -USWIFT_DARWIN_SUPPORTED_ARCHS
  -DSWIFT_STDLIB_ENABLE_OBJC_INTEROP:BOOL=TRUE
  "-DSWIFT_EXPERIMENTAL_EXTRA_FLAGS:STRING=-Xllvm;-sil-disable-pass=code-sinking"
)
COMMON_CMAKE_OPTIONS=(
  "-DFETCHCONTENT_SOURCE_DIR_SWIFTSYNTAX:PATH=$OPEN_SWIFT_SOURCE_ROOT/swift-syntax"
)

export SWIFT_BUILD_ROOT="${SWIFT_BUILD_ROOT:-$OPEN_SWIFT_SOURCE_ROOT/build}"
export PATH="$OPEN_SWIFT_BOOTSTRAP_TOOLCHAIN/bin:$PATH"
export LD_LIBRARY_PATH="$OPEN_SWIFT_BOOTSTRAP_TOOLCHAIN/lib/swift/linux:$OPEN_SWIFT_BOOTSTRAP_TOOLCHAIN/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export SWIFTC="$OPEN_SWIFT_BOOTSTRAP_TOOLCHAIN/bin/swiftc"

if [[ ! -x "$SWIFTC" ]]; then
  echo "error: matching Swift bootstrap compiler not found at $SWIFTC" >&2
  exit 1
fi

mkdir -p "$SWIFT_BUILD_ROOT/$SWIFT_BUILD_SUBDIR" "$OPEN_SWIFT_TOOLCHAIN_DESTDIR"

echo "== Bootstrap host compiler =="
"$SWIFTC" --version

echo "== Build OpenSwift stage-1 host toolchain =="
"$SWIFT_ROOT/utils/build-script" \
  --workspace "$OPEN_SWIFT_SOURCE_ROOT" \
  --build-subdir "$SWIFT_BUILD_SUBDIR" \
  --install-prefix /usr \
  --install-destdir "$OPEN_SWIFT_TOOLCHAIN_DESTDIR" \
  --host-target linux-aarch64 \
  --stdlib-deployment-targets=linux-aarch64 \
  --native-clang-tools-path "$OPEN_SWIFT_BOOTSTRAP_TOOLCHAIN/bin" \
  --bootstrapping=hosttools \
  --host-cc /usr/bin/clang \
  --host-cxx /usr/bin/clang++ \
  --cmake /usr/bin/cmake \
  --ninja-bin /usr/bin/ninja \
  --release \
  --llvm-build-type Release \
  --swift-build-type Release \
  --swift-stdlib-build-type Release \
  --libdispatch-build-type Release \
  --swift-enable-assertions true \
  --swift-stdlib-enable-assertions false \
  --swift-stdlib-enable-strict-availability false \
  --jobs "$BUILD_JOBS" \
  --lit-jobs "$BUILD_JOBS" \
  --build-swift-libexec true \
  --build-swift-examples false \
  --swift-enable-backtracing true \
  --swift-include-tests false \
  --llvm-include-tests false \
  --build-swift-clang-overlays true \
  --build-swift-remote-mirror true \
  --swift-source-dirname swift \
  --skip-build-benchmarks \
  --foundation \
  --libdispatch \
  --llbuild \
  --swift-testing \
  --swift-testing-macros \
  --xctest \
  --skip-build-lldb \
  --skip-build-libcxx \
  --skip-build-static-foundation \
  --skip-build-static-libdispatch \
  --skip-build-libxml2 \
  --skip-build-zlib \
  --skip-build-curl \
  --build-swift-dynamic-stdlib \
  --build-swift-dynamic-sdk-overlay \
  --skip-build-android \
  --skip-build-clang-tools-extra \
  --skip-test-swift \
  --skip-test-lldb \
  --skip-test-llbuild \
  --skip-test-xctest \
  --skip-test-foundation \
  --skip-test-libdispatch \
  --skip-test-benchmarks \
  --skip-early-swift-driver \
  --extra-swift-cmake-options="${SWIFT_CMAKE_OPTIONS[*]}" \
  --extra-cmake-options="${COMMON_CMAKE_OPTIONS[*]}" \
  --swift-objc-interop=1 \
  --install-llvm \
  --install-swift \
  --install-foundation \
  --install-libdispatch \
  --install-llbuild \
  --install-swift-testing \
  --install-swift-testing-macros \
  --install-xctest \
  --reconfigure \
  --llvm-lit-args=-sv \
  --llvm-install-components="IndexStore" \
  --skip-build-lld
