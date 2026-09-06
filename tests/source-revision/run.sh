#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
revision_test_dir="$(mktemp -d)"
trap 'rm -rf "$revision_test_dir"' EXIT
export OPEN_SWIFT_GIT_BASE="$revision_test_dir/remotes"
export OPEN_SWIFT_SOURCE_ROOT="$revision_test_dir/sources"
export OPEN_SWIFT_GNUSTEP_SRC="$revision_test_dir/gnustep"
mkdir -p "$OPEN_SWIFT_GIT_BASE"

commit() {
  git -C "$1" -c user.name=Test -c user.email=test@example.invalid \
    -c commit.gpgsign=false commit -qm "$2" --allow-empty
}

swift_repo="$OPEN_SWIFT_GIT_BASE/swift.git"
git init -q -b main "$swift_repo"
mkdir -p "$swift_repo/utils"
cp "$ROOT_DIR/tests/source-revision/update-checkout" "$swift_repo/utils/update-checkout"
chmod +x "$swift_repo/utils/update-checkout"
git -C "$swift_repo" add utils/update-checkout
commit "$swift_repo" baseline
git -C "$swift_repo" branch release/6.3
git -C "$swift_repo" branch feature/gnu_objc_6.3
commit "$swift_repo" pinned
pinned="$(git -C "$swift_repo" rev-parse HEAD)"

for entry in libobjc2:v2.3 tools-make:make-2_9_3 libs-base:base-1_31_1 libs-corebase:openswift/corebase-0_1_1; do
  repo="$OPEN_SWIFT_GIT_BASE/${entry%%:*}.git"
  git init -q -b main "$repo"
  commit "$repo" baseline
  git -C "$repo" tag "${entry#*:}"
done

SWIFT_REVISION="$pinned" bash "$ROOT_DIR/scripts/clone-sources.sh"
test "$(git -C "$OPEN_SWIFT_SOURCE_ROOT/swift" rev-parse HEAD)" = "$pinned"
if git -C "$OPEN_SWIFT_SOURCE_ROOT/swift" symbolic-ref -q HEAD; then
  echo "error: pinned source must have detached HEAD" >&2
  exit 1
fi

# Advance the remote branch, while the clone's local branch is still stale.
commit "$swift_repo" advanced
advanced="$(git -C "$swift_repo" rev-parse HEAD)"
git -C "$swift_repo" update-ref refs/heads/feature/gnu_objc_6.3 "$advanced"
SWIFT_REVISION="" bash "$ROOT_DIR/scripts/clone-sources.sh"
test "$(git -C "$OPEN_SWIFT_SOURCE_ROOT/swift" rev-parse HEAD)" = "$advanced"

if SWIFT_REVISION=invalid bash "$ROOT_DIR/scripts/clone-sources.sh"; then
  echo "error: invalid revision was accepted" >&2
  exit 1
fi
echo "Swift revision pin, moving-branch refresh, and invalid-revision rejection passed"
