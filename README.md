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
stable. CI/release workflows resolve the Swift ref to a full commit SHA and pass
`SWIFT_REVISION` to the build; it invalidates the clone cache and is recorded in
the `org.openswiftproject.swift.revision` image label. Other source branches
listed above remain moving inputs. The official Swift image is used only as the host compiler
for the stage-1 self-host build. The final Swift compiler, runtime libraries,
XCTest, Swift Testing, LLBuild, and SwiftPM are all built from the source
checkouts above (and the matching `release/6.3` workspace populated by Swift's
`update-checkout`). The runtime image currently links `clang` and `clang++` to
Ubuntu 24.04's Clang 18 for C and Objective-C compilation.

## Verified Release

`6.3-alpha.3` was published on 2026-09-07 (Asia/Shanghai) for Linux ARM64 /
Ubuntu 24.04. The [release workflow](https://github.com/OpenSwiftProject/toolchain-docker/actions/runs/34049285226)
and [post-merge CI](https://github.com/OpenSwiftProject/toolchain-docker/actions/runs/34049148102)
passed full source builds, clean Debug/Release build/run/test for both packages,
selector DSO probes, and the manual shared-library example. After publication,
the workflow anonymously pulled the immutable image and repeated the gate.

```sh
docker pull ghcr.io/openswiftproject/swift-gnustep-toolchain:6.3-alpha.3
```

Both `6.3-alpha.3` and `6.3-alpha.3-ubuntu24-aarch64` identify the verified image:

```text
sha256:1fe994e838781b510de667e805435e0a68f62c65fd6d9f13f3dae6791ac3a9da
```

It contains Swift `38cb233d6848882a1764134360cd22ae350cf0e3`, was built from
toolchain commit `a4951ec83f1d604c4f17ffd1124d86d2d115c4ea`, and was validated
against example commit `1b449e25988e2b330ba21f287c4f83dc01ea13d7`.
The [package-workflow tracker](https://github.com/OpenSwiftProject/toolchain-docker/issues/2)
records the delivery and remaining interop boundaries.

For this release, `org.opencontainers.image.version` still inherits the base
image's `24.04`; identify the toolchain using its immutable tag/digest and the
`org.opencontainers.image.revision` / `org.openswiftproject.swift.revision`
labels instead.

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
SWIFT_REVISION=$(git ls-remote https://github.com/OpenSwiftProject/swift.git \
  refs/heads/feature/gnu_objc_6.3 | awk '{print $1}')
docker buildx build \
  --platform linux/arm64 \
  --load \
  --build-arg BUILD_JOBS=3 \
  --build-arg SWIFT_REVISION="$SWIFT_REVISION" \
  -t ghcr.io/openswiftproject/swift-gnustep-toolchain:6.3-alpha-ubuntu24-aarch64 \
  .
```

Or use the wrapper script, which resolves the current Swift commit by default
(set `SWIFT_REVISION` explicitly to rebuild a specific commit):

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

The `Toolchain package regression` workflow builds and tests pull requests and
`main` without publishing. CI and release both run
`scripts/smoke-test-release.sh IMAGE EXAMPLE_CHECKOUT`, covering:

- selector-only Swift DSOs with late loading, cross-object coalescing, Clang
  selector equality, concurrent lookup, and `--gc-sections`, at `-Onone`/`-O`;
- clean Debug/Release build, run, XCTest, and Swift Testing for both the in-repo
  fixture and a checkout of the real `OpenSwiftProject/toolchain-example`;
- the real example's manual shared-library runner and direct Swift allocation.

Neither package may contain the selector shim or per-class linker aliases.
The compiler and example selector changes are merged, and the gate has passed
against their default branches for `6.3-alpha.3`. Manual runs can select
candidate `swift_ref`/`example_ref` branches. For future dependent changes,
land the compiler and example prerequisites before publishing the toolchain.

The `Build and publish toolchain image` workflow can publish manually or from a git tag push. It uses GitHub's built-in `GITHUB_TOKEN` to push to GitHub Container Registry, so no Docker Hub secrets are required.

Manual workflow inputs:

```text
runner: ubuntu-24.04-arm
image_name: ghcr.io/openswiftproject/swift-gnustep-toolchain
version_tag: required; choose a new, unused 6.3-alpha.N tag
build_jobs: 3
swift_ref: feature/gnu_objc_6.3
example_ref: main
```

Manual workflow runs build from forks, pass the shared release gate, and publish
GHCR tags. A final step pulls the immutable tag with an empty Docker auth config
and reruns the release gate, checking anonymous access and the published image.

For normal releases, create and push a new, unused version tag at the reviewed
release commit. `6.3-alpha.3` is already published and must not be reused.
The version below is an example for a future release, not a published version:

```sh
release_remote=origin # Use your publication remote (osp in the local workspace).
release_version=6.3-alpha.4 # Confirm this version is unused before tagging.
git tag "$release_version"
git push "$release_remote" "refs/tags/$release_version"
```

Pushing `6.3-alpha.N` tags automatically publishes:

```text
6.3-alpha.N
6.3-alpha.N-ubuntu24-aarch64
6.3-alpha
6.3-alpha-ubuntu24-aarch64
```

Anonymous pull was verified for `6.3-alpha.3`. Keep the post-publication check
enabled for later releases so public access continues to be tested.

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
SwiftPM smoke keeps the same remaining runtime workaround as `toolchain-example`:

- `ObjCInteropShim.c` for missing Swift runtime Objective-C metadata entry points.

Selector registration now uses native GNUstep records and the compiler-emitted
image initializer. Imported class references use Clang's GNUstep reference
slots. Neither path requires a demo-side selector shim or per-class alias.

The Linux image still lacks the Swift `ObjectiveC` module/overlay needed by
source-level `#selector`. The selector-only runtime regression intentionally
uses SIL literals to test the ABI independently of that platform/overlay gap.

The demo also keeps `MakeObjCGreeter()` behind an explicit factory-isolation
gate. That gate crosses the runtime (`swift#2`) and IRGen (`swift#3`) work; it is
not a separate upstream issue. Direct Swift allocation passes the manual smoke
with the runtime shim, but semantic runtime metadata correctness, Swift-defined
Objective-C classes/subclasses, and general bridging remain separate work.

Those remain tracked runtime/IRGen issues and do not block the package-manager
workflow itself.

Offline source-selection regression: `bash tests/source-revision/run.sh`.
