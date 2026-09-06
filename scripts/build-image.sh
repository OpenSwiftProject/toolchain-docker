#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${OPEN_SWIFT_TOOLCHAIN_IMAGE_NAME:-ghcr.io/openswiftproject/swift-gnustep-toolchain}"
VERSION_TAG="${OPEN_SWIFT_VERSION_TAG:-6.3-alpha}"
PLATFORM_SUFFIX="${OPEN_SWIFT_PLATFORM_SUFFIX:-ubuntu24-aarch64}"
IMAGE="${OPEN_SWIFT_TOOLCHAIN_IMAGE:-$IMAGE_NAME:$VERSION_TAG-$PLATFORM_SUFFIX}"
PLATFORM="${OPEN_SWIFT_DOCKER_PLATFORM:-linux/arm64}"
BUILD_JOBS="${BUILD_JOBS:-3}"
LOAD_FLAG="${OPEN_SWIFT_DOCKER_OUTPUT:---load}"
SWIFT_BRANCH="${SWIFT_BRANCH:-feature/gnu_objc_6.3}"
OPEN_SWIFT_GIT_BASE="${OPEN_SWIFT_GIT_BASE:-https://github.com/OpenSwiftProject}"
SWIFT_REVISION="${SWIFT_REVISION:-$(git ls-remote "$OPEN_SWIFT_GIT_BASE/swift.git" "refs/heads/$SWIFT_BRANCH" | awk '{print $1}')}"
if [[ ! "$SWIFT_REVISION" =~ ^[0-9a-f]{40}$ ]]; then
  echo "error: could not resolve a full Swift revision" >&2
  exit 1
fi

docker buildx build \
  --platform "$PLATFORM" \
  "$LOAD_FLAG" \
  --build-arg BUILD_JOBS="$BUILD_JOBS" \
  --build-arg OPEN_SWIFT_GIT_BASE="$OPEN_SWIFT_GIT_BASE" \
  --build-arg SWIFT_BRANCH="$SWIFT_BRANCH" \
  --build-arg SWIFT_REVISION="$SWIFT_REVISION" \
  -t "$IMAGE" \
  "$ROOT_DIR"
