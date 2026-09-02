# OpenSwiftProject Toolchain Docker

This repository builds the alpha Docker image used by `OpenSwiftProject/toolchain-example`.
The image includes the Swift compiler, GNUstep Objective-C/Foundation runtime,
and the matching SwiftPM/LLBuild toolchain needed for `swift build`,
`swift run`, and `swift test`.

The shipped OpenSwift compiler, runtime, and package-manager components are
built from OpenSwiftProject forks, not from local machine artifacts:

- `OpenSwiftProject/swift@feature/gnu_objc_6.3`
- `OpenSwiftProject/llvm-project@swift/release/6.3`
- `OpenSwiftProject/swift-corelibs-libdispatch@release/6.3`
- `OpenSwiftProject/libobjc2@v2.3`
- `OpenSwiftProject/tools-make@make-2_9_3`
- `OpenSwiftProject/libs-base@base-1_31_1`
- `OpenSwiftProject/libs-corebase@openswift/corebase-0_1_1`

Digest-pinned Ubuntu 24.04 and Swift 6.3.3 images keep the base-image inputs
stable. The source branches listed above remain moving inputs until their
commits are pinned. The official Swift image is used only as the host compiler
for the stage-1 self-host build. The final Swift compiler, runtime libraries,
XCTest, Swift Testing, LLBuild, and SwiftPM are all built from the source
checkouts above (and the matching `release/6.3` workspace populated by Swift's
`update-checkout`). The runtime image currently links `clang` and `clang++` to
Ubuntu 24.04's Clang 18 for C and Objective-C compilation.

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

The smoke test runs a real mixed-language Swift package in both Debug and
Release. Its production graph has one Swift executable target and one
Objective-C target, plus a Swift test target that exercises both XCTest and
Swift Testing by launching the built demo and asserting its Objective-C/
Foundation output:

```sh
swift build
swift run GNUstepObjCDemo
swift test
swift build --configuration release
swift run --configuration release GNUstepObjCDemo
swift test --configuration release
```

The integration-test target intentionally has no direct dependency on the
Objective-C target. SwiftPM's generated test-discovery targets do not yet
inherit the target-scoped GNUstep Objective-C importer flags, so direct import
from a test target remains part of the general interop work tracked separately.

By default it uses the self-contained fixture under
`tests/swiftpm-objc-smoke`. To validate a local `toolchain-example` checkout
instead, pass it as the second argument:

```sh
./scripts/smoke-test-image.sh \
  ghcr.io/openswiftproject/swift-gnustep-toolchain:6.3-alpha-ubuntu24-aarch64 \
  /path/to/toolchain-example
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

The compiler and package manager are built in two stages:

1. A pinned Swift 6.3.3 Linux toolchain supplies host-only Swift and Clang
   executables while the OpenSwift compiler is rebuilt with Swift-in-Swift,
   SwiftSyntax, macro, and regex parser support. The resulting build-tree
   compiler then builds and installs libdispatch, swift-corelibs-foundation,
   XCTest, Swift Testing (including its macro plugin), and LLBuild.
2. SwiftPM is built and installed through its supported
   `Utilities/bootstrap` entry point, using that LLBuild build directory and
   the installed swift-corelibs-foundation/libdispatch.

SwiftPM is intentionally not selected through Swift's top-level
`build-script`: on Linux that path forcibly rebuilds Foundation and libdispatch,
which makes Clang see both the installed and source Dispatch module maps during
this second stage.

This staging is required because the previous C/C++-only bootstrap compiler
cannot parse the bare-slash regex literals used by SwiftPM and `swift-build`
6.3 production sources. The bootstrap image is digest-pinned and can be
overridden with the `SWIFT_BOOTSTRAP_IMAGE` Docker build argument when moving
to another Swift patch release.

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

The current milestone covers `swift build`, `swift run`, and `swift test`.
The Debug and Release smoke tests execute both an XCTest case and a Swift
Testing `@Test`; each launches the built GNUstep Objective-C demo and verifies
its output. This milestone does not claim that a SwiftPM test target can yet
directly import the Objective-C target.

This is also not complete, Darwin-equivalent GNUstep Objective-C interop. The
SwiftPM smoke deliberately keeps the same three underlying toolchain
workarounds as
`toolchain-example`:

- `ObjCInteropShim.c` for missing Swift runtime Objective-C metadata entry points.
- `DarwinSelectorRefs.c` for selector registration expected by current IRGen.
- A per-class ELF `--defsym` alias for GNUstep class-symbol lowering.

The demo also keeps `MakeObjCGreeter()` behind an explicit factory-isolation
gate. That gate crosses the runtime (`swift#2`) and IRGen (`swift#3`) work; it is
not a fourth independent upstream issue. Final interop acceptance requires the
direct Swift `ObjCGreeter()` allocation path to succeed.

Those remain tracked runtime/IRGen issues and do not block the package-manager
workflow itself.
