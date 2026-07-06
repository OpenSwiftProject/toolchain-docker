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

Immutable alpha tags:

```text
ghcr.io/openswiftproject/swift-gnustep-toolchain:6.3-alpha.N
ghcr.io/openswiftproject/swift-gnustep-toolchain:6.3-alpha.N-ubuntu24-aarch64
```

Moving alpha aliases:

```text
ghcr.io/openswiftproject/swift-gnustep-toolchain:6.3-alpha
ghcr.io/openswiftproject/swift-gnustep-toolchain:6.3-alpha-ubuntu24-aarch64
```

Use immutable tags for reproducible testing and moving aliases for the latest published alpha in the same Swift release channel.

## Build Locally

This build is intentionally heavy. Use an arm64 Ubuntu 24.04 environment with enough disk space.

```sh
docker buildx build \
  --platform linux/arm64 \
  --load \
  --build-arg BUILD_JOBS=3 \
  -t ghcr.io/openswiftproject/swift-gnustep-toolchain:6.3-alpha-ubuntu24-aarch64 \
  .
```

Or use the wrapper script:

```sh
./scripts/build-image.sh
```

Smoke test:

```sh
./scripts/smoke-test-image.sh ghcr.io/openswiftproject/swift-gnustep-toolchain:6.3-alpha-ubuntu24-aarch64
```

## Publish To GHCR From GitHub Actions

The `Build and publish toolchain image` workflow can publish manually or from a git tag push. It uses GitHub's built-in `GITHUB_TOKEN` to push to GitHub Container Registry, so no Docker Hub secrets are required.

Manual workflow inputs:

```text
runner: ubuntu-24.04-arm
image: ghcr.io/openswiftproject/swift-gnustep-toolchain
version_tag: required, for example 6.3-alpha.2
build_jobs: 3
```

Manual workflow runs build from forks, smoke-tests the loaded image, then publishes GHCR tags.

For normal releases, create and push a version tag:

```sh
git tag 6.3-alpha.2
git push <remote> 6.3-alpha.2
```

Pushing `6.3-alpha.N` tags automatically publishes:

```text
6.3-alpha.N
6.3-alpha.N-ubuntu24-aarch64
6.3-alpha
6.3-alpha-ubuntu24-aarch64
```

After the first GHCR push, confirm the package visibility is public under the OpenSwiftProject organization so users can pull the image without logging in.

## Build Layout Notes

The Swift toolchain build intentionally uses Swift's wrapper-managed build root:

```text
SWIFT_BUILD_ROOT=/work/OpenSwiftProject/swift-projects/build
SWIFT_BUILD_SUBDIR=openswift-gnustep-linux-aarch64
```

Keep Swift's LLVM, Clang, and stdlib build products under the same wrapper build root. Passing a separate impl-level `--build-dir` can split the LLVM and Swift stdlib build directories and make stdlib configuration fail to find `LLVMConfig.cmake`.

## Relationship To toolchain-example

`OpenSwiftProject/toolchain-example` defaults to this image:

```text
ghcr.io/openswiftproject/swift-gnustep-toolchain:6.3-alpha-ubuntu24-aarch64
```

The example can also build this image first:

```sh
./scripts/run-demokit.sh \
  --build-image \
  --toolchain-docker-repo https://github.com/OpenSwiftProject/toolchain-docker.git
```

## Alpha Caveats

This image currently carries a bootstrap smoke-test toolchain, not complete Swift GNUstep Objective-C interop support. The demo-side shims in `toolchain-example` still mark work that belongs in Swift IRGen/runtime.
