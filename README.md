# OpenSwiftProject Toolchain Docker

This repository builds the alpha Docker image used by `OpenSwiftProject/toolchain-example`.

The image is built from OpenSwiftProject forks, not from local machine artifacts:

- `OpenSwiftProject/swift@feature/gnu_objc_6.3`
- `OpenSwiftProject/llvm-project@swift/release/6.3`
- `OpenSwiftProject/swift-corelibs-libdispatch@release/6.3`
- `OpenSwiftProject/libobjc2@v2.3`
- `OpenSwiftProject/tools-make@make-2_9_3`
- `OpenSwiftProject/libs-base@base-1_31_1`
- `OpenSwiftProject/libs-corebase@openswift/corebase-0_1_1`

## Image Names

Initial alpha tags:

```text
openswiftproject/swift-gnustep-toolchain:6.3-alpha-ubuntu24-aarch64
openswiftproject/swift-gnustep-toolchain:6.3-alpha
```

## Build Locally

This build is intentionally heavy. Use an arm64 Ubuntu 24.04 environment with enough disk space.

```sh
docker buildx build \
  --platform linux/arm64 \
  --load \
  -t openswiftproject/swift-gnustep-toolchain:6.3-alpha-ubuntu24-aarch64 \
  .
```

Or use the wrapper script:

```sh
OPEN_SWIFT_TOOLCHAIN_IMAGE=openswiftproject/swift-gnustep-toolchain:6.3-alpha-ubuntu24-aarch64 \
  ./scripts/build-image.sh
```

Smoke test:

```sh
./scripts/smoke-test-image.sh openswiftproject/swift-gnustep-toolchain:6.3-alpha-ubuntu24-aarch64
```

## Publish From GitHub Actions

Configure repository secrets:

```text
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN
```

Then run the `Build and publish toolchain image` workflow manually.

The workflow defaults to:

```text
runner: ubuntu-24.04-arm
image: openswiftproject/swift-gnustep-toolchain
tag: 6.3-alpha-ubuntu24-aarch64
```

It builds from forks, smoke-tests the loaded image, then pushes when `push_image` is true.

## Relationship To toolchain-example

`OpenSwiftProject/toolchain-example` defaults to this image:

```text
openswiftproject/swift-gnustep-toolchain:6.3-alpha-ubuntu24-aarch64
```

The example can also build this image first:

```sh
./scripts/run-demokit.sh \
  --build-image \
  --toolchain-docker-repo https://github.com/OpenSwiftProject/toolchain-docker.git
```

## Alpha Caveats

This image currently carries a bootstrap smoke-test toolchain, not complete Swift GNUstep Objective-C interop support. The demo-side shims in `toolchain-example` still mark work that belongs in Swift IRGen/runtime.
