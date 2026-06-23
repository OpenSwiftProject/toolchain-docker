#!/usr/bin/env bash
set -euo pipefail

OPEN_SWIFT_SOURCE_ROOT="${OPEN_SWIFT_SOURCE_ROOT:-/work/OpenSwiftProject/swift-projects}"
OPEN_SWIFT_BUILD_ROOT="${OPEN_SWIFT_BUILD_ROOT:-/work/OpenSwiftProject/build}"
OPEN_SWIFT_TOOLCHAIN_DESTDIR="${OPEN_SWIFT_TOOLCHAIN_DESTDIR:-/opt/openswift/swift-6.3-gnustep}"
BUILD_JOBS="${BUILD_JOBS:-3}"

SWIFT_ROOT="$OPEN_SWIFT_SOURCE_ROOT/swift"
SWIFT_BUILD_DIR="$OPEN_SWIFT_BUILD_ROOT/swift-gnustep-linux-aarch64"
SWIFT_DEFAULT_BUILD_ROOT="$OPEN_SWIFT_SOURCE_ROOT/build/Ninja-RelWithDebInfoAssert"
LLVM_CMAKE_DIR="$SWIFT_DEFAULT_BUILD_ROOT/llvm-linux-aarch64/lib/cmake/llvm"
CLANG_CMAKE_DIR="$SWIFT_DEFAULT_BUILD_ROOT/llvm-linux-aarch64/lib/cmake/clang"
SWIFT_CMAKE_OPTIONS="-DCMAKE_EXPORT_COMPILE_COMMANDS=TRUE -DLLVM_DIR:PATH=$LLVM_CMAKE_DIR -DClang_DIR:PATH=$CLANG_CMAKE_DIR -DSWIFT_STDLIB_ENABLE_OBJC_INTEROP:BOOL=TRUE -DSWIFT_EXPERIMENTAL_EXTRA_FLAGS:STRING=-Xllvm;-sil-disable-pass=code-sinking -DSWIFT_BUILD_SWIFT_SYNTAX:BOOL=FALSE -DSWIFT_ENABLE_SWIFT_IN_SWIFT:BOOL=FALSE -DSWIFT_BUILD_REGEX_PARSER_IN_COMPILER:BOOL=FALSE"

mkdir -p "$SWIFT_BUILD_DIR" "$OPEN_SWIFT_TOOLCHAIN_DESTDIR"

echo "== Build Swift toolchain =="
"$SWIFT_ROOT/utils/build-script" \
  --workspace "$OPEN_SWIFT_SOURCE_ROOT" \
  --build-dir "$SWIFT_BUILD_DIR" \
  --install-prefix /usr \
  --install-destdir "$OPEN_SWIFT_TOOLCHAIN_DESTDIR" \
  --host-target linux-aarch64 \
  --stdlib-deployment-targets=linux-aarch64 \
  --host-cc /usr/bin/clang \
  --host-cxx /usr/bin/clang++ \
  --cmake /usr/bin/cmake \
  --ninja-bin /usr/bin/ninja \
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
  --swift-enable-backtracing true \
  --build-swift-clang-overlays true \
  --build-swift-remote-mirror true \
  --swift-source-dirname swift \
  --swift-cmake-options="$SWIFT_CMAKE_OPTIONS" \
  --skip-build-benchmarks \
  --skip-build-foundation \
  --skip-build-xctest \
  --skip-build-lldb \
  --skip-build-llbuild \
  --skip-build-libcxx \
  --skip-build-libdispatch \
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
  --extra-cmake-options=-USWIFT_DARWIN_SUPPORTED_ARCHS \
  --swift-objc-interop=1 \
  --install-swift \
  --reconfigure \
  --llvm-lit-args=-sv \
  --llvm-install-components="llvm-ar;llvm-nm;llvm-ranlib;llvm-cov;llvm-profdata;llvm-objdump;llvm-objcopy;llvm-symbolizer;IndexStore;clang;clang-resource-headers;libclang;LTO;clang-features-file" \
  --skip-build-lld
