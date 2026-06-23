#!/usr/bin/env bash
set -euo pipefail

OPEN_SWIFT_GIT_BASE="${OPEN_SWIFT_GIT_BASE:-https://github.com/OpenSwiftProject}"
OPEN_SWIFT_SOURCE_ROOT="${OPEN_SWIFT_SOURCE_ROOT:-/work/OpenSwiftProject/swift-projects}"
OPEN_SWIFT_GNUSTEP_SRC="${OPEN_SWIFT_GNUSTEP_SRC:-/work/OpenSwiftProject/gnustep-src}"

SWIFT_BRANCH="${SWIFT_BRANCH:-feature/gnu_objc_6.3}"
LLVM_BRANCH="${LLVM_BRANCH:-swift/release/6.3}"
LIBDISPATCH_BRANCH="${LIBDISPATCH_BRANCH:-release/6.3}"
LIBOBJC2_REF="${LIBOBJC2_REF:-v2.3}"
TOOLS_MAKE_REF="${TOOLS_MAKE_REF:-make-2_9_3}"
LIBS_BASE_REF="${LIBS_BASE_REF:-base-1_31_1}"
LIBS_COREBASE_REF="${LIBS_COREBASE_REF:-openswift/corebase-0_1_1}"

clone_or_update() {
  local repo="$1"
  local dest="$2"
  local ref="$3"

  if [[ -d "$dest/.git" ]]; then
    git -C "$dest" fetch --all --tags
  else
    git clone "$OPEN_SWIFT_GIT_BASE/$repo.git" "$dest"
  fi

  git -C "$dest" checkout "$ref"
}

mkdir -p "$OPEN_SWIFT_SOURCE_ROOT" "$OPEN_SWIFT_GNUSTEP_SRC"

clone_or_update swift "$OPEN_SWIFT_SOURCE_ROOT/swift" "$SWIFT_BRANCH"

# Let Swift's release scheme clone the full workspace, then restore the Swift
# fork branch because update-checkout may align it back to release/6.3.
"$OPEN_SWIFT_SOURCE_ROOT/swift/utils/update-checkout" \
  --scheme release/6.3 \
  --source-root "$OPEN_SWIFT_SOURCE_ROOT" \
  --clone
git -C "$OPEN_SWIFT_SOURCE_ROOT/swift" fetch "$OPEN_SWIFT_GIT_BASE/swift.git" "$SWIFT_BRANCH"
git -C "$OPEN_SWIFT_SOURCE_ROOT/swift" checkout "$SWIFT_BRANCH"

if [[ -d "$OPEN_SWIFT_SOURCE_ROOT/llvm-project/.git" ]]; then
  git -C "$OPEN_SWIFT_SOURCE_ROOT/llvm-project" remote add osp "$OPEN_SWIFT_GIT_BASE/llvm-project.git" 2>/dev/null || true
  git -C "$OPEN_SWIFT_SOURCE_ROOT/llvm-project" fetch osp "$LLVM_BRANCH"
  git -C "$OPEN_SWIFT_SOURCE_ROOT/llvm-project" checkout FETCH_HEAD
fi

if [[ -d "$OPEN_SWIFT_SOURCE_ROOT/swift-corelibs-libdispatch/.git" ]]; then
  git -C "$OPEN_SWIFT_SOURCE_ROOT/swift-corelibs-libdispatch" remote add osp "$OPEN_SWIFT_GIT_BASE/swift-corelibs-libdispatch.git" 2>/dev/null || true
  git -C "$OPEN_SWIFT_SOURCE_ROOT/swift-corelibs-libdispatch" fetch osp "$LIBDISPATCH_BRANCH"
  git -C "$OPEN_SWIFT_SOURCE_ROOT/swift-corelibs-libdispatch" checkout FETCH_HEAD
fi

clone_or_update libobjc2 "$OPEN_SWIFT_GNUSTEP_SRC/libobjc2" "$LIBOBJC2_REF"
clone_or_update tools-make "$OPEN_SWIFT_GNUSTEP_SRC/tools-make" "$TOOLS_MAKE_REF"
clone_or_update libs-base "$OPEN_SWIFT_GNUSTEP_SRC/libs-base" "$LIBS_BASE_REF"
clone_or_update libs-corebase "$OPEN_SWIFT_GNUSTEP_SRC/libs-corebase" "$LIBS_COREBASE_REF"

