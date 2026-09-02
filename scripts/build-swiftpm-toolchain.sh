#!/usr/bin/env bash
set -euo pipefail

OPEN_SWIFT_SOURCE_ROOT="${OPEN_SWIFT_SOURCE_ROOT:-/work/OpenSwiftProject/swift-projects}"
OPEN_SWIFT_TOOLCHAIN_DESTDIR="${OPEN_SWIFT_TOOLCHAIN_DESTDIR:-/opt/openswift/swift-6.3-gnustep}"
OPEN_SWIFT_TOOLCHAIN="${OPEN_SWIFT_TOOLCHAIN:-$OPEN_SWIFT_TOOLCHAIN_DESTDIR/usr}"
BUILD_JOBS="${BUILD_JOBS:-3}"
CLANG_PATH="${CLANG_PATH:-/usr/bin/clang}"
CLANGXX_PATH="${CLANGXX_PATH:-/usr/bin/clang++}"

SWIFTPM_ROOT="$OPEN_SWIFT_SOURCE_ROOT/swiftpm"
# Reuse stage 1's LLBuild tree for SwiftPM bootstrap artifacts.
SWIFT_BUILD_SUBDIR="${SWIFT_BUILD_SUBDIR:-openswift-gnustep-linux-aarch64}"

export SWIFT_BUILD_ROOT="${SWIFT_BUILD_ROOT:-$OPEN_SWIFT_SOURCE_ROOT/build}"
export PATH="$OPEN_SWIFT_TOOLCHAIN/bin:$PATH"
export LD_LIBRARY_PATH="$OPEN_SWIFT_TOOLCHAIN/lib/swift/linux:$OPEN_SWIFT_TOOLCHAIN/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export SWIFTC="$OPEN_SWIFT_TOOLCHAIN/bin/swiftc"
# SwiftPM's bootstrap forwards --clang-path as CMAKE_C_COMPILER, but does not
# set CMAKE_CXX_COMPILER. swift-build requires Clang-only options such as
# -fblocks, so make CMake select clang++ instead of the system c++ (GCC).
export CC="$CLANG_PATH"
export CXX="$CLANGXX_PATH"
export CMAKE_BUILD_PARALLEL_LEVEL="$BUILD_JOBS"
CMAKE_PATH="${CMAKE_PATH:-$SWIFT_BUILD_ROOT/cmake-linux-aarch64/bin/cmake}"

if [[ ! -x "$SWIFTC" ]]; then
  echo "error: stage-1 Swift compiler not found at $SWIFTC" >&2
  exit 1
fi

if [[ ! -x "$CLANG_PATH" || ! -x "$CLANGXX_PATH" ]]; then
  echo "error: Clang toolchain not found at $CLANG_PATH and $CLANGXX_PATH" >&2
  exit 1
fi

# Ubuntu 24.04 ships CMake 3.28, while SwiftPM 6.3's Runtimes project requires
# 3.29. Swift's stage-1 build has already bootstrapped a matching newer CMake.
if [[ ! -x "$CMAKE_PATH" ]]; then
  echo "error: stage-1 CMake not found at $CMAKE_PATH" >&2
  exit 1
fi

echo "== Verify stage-1 regex parser and XCTest module =="
regex_smoke_dir="$(mktemp -d)"
trap 'rm -rf "$regex_smoke_dir"' EXIT
cat > "$regex_smoke_dir/RegexSmoke.swift" <<'EOF'
import XCTest
import Testing

let expression = #/open(swift)?/#
guard "openswift".wholeMatch(of: expression) != nil else {
  fatalError("regex parser smoke failed")
}
EOF
"$SWIFTC" "$regex_smoke_dir/RegexSmoke.swift" -o "$regex_smoke_dir/RegexSmoke"
"$regex_smoke_dir/RegexSmoke"
rm -rf "$regex_smoke_dir"
trap - EXIT

# On Linux, Swift's top-level build-script unconditionally enables Foundation
# and libdispatch whenever --swiftpm is selected. Stage 1 already built
# libdispatch, Foundation, and LLBuild with the OpenSwift build-tree compiler.
# Rebuilding any of them with the installed compiler exposes both the installed
# and source Dispatch module maps and fails with a module redefinition. Invoke
# SwiftPM's supported bootstrap entry point directly and consume the installed
# runtime plus the stage-1 LLBuild build directory instead.
LLBUILD_BUILD_DIR="$SWIFT_BUILD_ROOT/$SWIFT_BUILD_SUBDIR/llbuild-linux-aarch64"
# Keep this separate from earlier GCC-configured bootstrap trees. CMake caches
# compiler selection, and SwiftPM's --reconfigure does not reset that entry.
SWIFTPM_BUILD_DIR="$SWIFT_BUILD_ROOT/$SWIFT_BUILD_SUBDIR/swiftpm-clang-linux-aarch64"

if [[ ! -d "$LLBUILD_BUILD_DIR" ]]; then
  echo "error: LLBuild build directory not found at $LLBUILD_BUILD_DIR" >&2
  exit 1
fi

echo "== Build and install SwiftPM =="
"$SWIFTPM_ROOT/Utilities/bootstrap" install \
  --release \
  --reconfigure \
  --swiftc-path "$SWIFTC" \
  --clang-path "$CLANG_PATH" \
  --cmake-path "$CMAKE_PATH" \
  --ninja-path /usr/bin/ninja \
  --ar-path /usr/bin/ar \
  --ranlib-path /usr/bin/ranlib \
  --build-dir "$SWIFTPM_BUILD_DIR" \
  --llbuild-build-dir "$LLBUILD_BUILD_DIR" \
  --prefix "$OPEN_SWIFT_TOOLCHAIN"
