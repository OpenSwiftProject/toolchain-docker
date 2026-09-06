#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:?usage: smoke-test-release.sh IMAGE EXAMPLE_CHECKOUT}"
EXAMPLE_DIR="${2:?usage: smoke-test-release.sh IMAGE EXAMPLE_CHECKOUT}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLE_DIR="$(cd "$EXAMPLE_DIR" && pwd -P)"

# Do not accidentally validate a historical demo that still hides ABI gaps.
for package in "$ROOT_DIR/tests/swiftpm-objc-smoke" "$EXAMPLE_DIR"; do
  test -f "$package/Package.swift"
  if [[ -f "$package/DemoKit/DarwinSelectorRefs.c" ]] ||
    grep -q -- '--defsym' "$package/Package.swift"; then
    echo "error: release smoke requires an alias-free, selector-shim-free package: $package" >&2
    exit 1
  fi
done

docker run --rm --platform linux/arm64 \
  --mount "type=bind,src=$ROOT_DIR/tests/selector-runtime,dst=/opt/selector-runtime,readonly" \
  "$IMAGE" bash /opt/selector-runtime/run.sh

bash "$ROOT_DIR/scripts/smoke-test-image.sh" "$IMAGE"
bash "$ROOT_DIR/scripts/smoke-test-image.sh" "$IMAGE" "$EXAMPLE_DIR"

# Also exercise shared-library linkage and direct Swift allocation. All build
# products stay in the disposable container, not in the caller's checkout.
docker run --rm --platform linux/arm64 \
  --mount "type=bind,src=$EXAMPLE_DIR,dst=/opt/openswift-example,readonly" \
  -e OPEN_SWIFT_DEMOKIT_BUILD_DIR=/tmp/openswift-demokit \
  "$IMAGE" bash /opt/openswift-example/scripts/build-demokit-in-container.sh
