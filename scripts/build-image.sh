#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${OPEN_SWIFT_TOOLCHAIN_IMAGE:-openswiftproject/swift-gnustep-toolchain:6.3-alpha-ubuntu24-aarch64}"
PLATFORM="${OPEN_SWIFT_DOCKER_PLATFORM:-linux/arm64}"
BUILD_JOBS="${BUILD_JOBS:-3}"
LOAD_FLAG="${OPEN_SWIFT_DOCKER_OUTPUT:---load}"

docker buildx build \
  --platform "$PLATFORM" \
  "$LOAD_FLAG" \
  --build-arg BUILD_JOBS="$BUILD_JOBS" \
  -t "$IMAGE" \
  "$ROOT_DIR"

