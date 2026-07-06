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

docker buildx build \
  --platform "$PLATFORM" \
  "$LOAD_FLAG" \
  --build-arg BUILD_JOBS="$BUILD_JOBS" \
  -t "$IMAGE" \
  "$ROOT_DIR"
