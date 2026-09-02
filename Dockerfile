# syntax=docker/dockerfile:1.7

ARG UBUNTU_IMAGE=ubuntu:24.04@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517
ARG SWIFT_BOOTSTRAP_IMAGE=swift:6.3.3-noble@sha256:56ef1be2c1ca36f4c52440357dc1fcdfdb5e113587134fcadeef57c225c71b54

FROM ${SWIFT_BOOTSTRAP_IMAGE} AS swift-bootstrap

FROM ${UBUNTU_IMAGE} AS builder

ARG BUILD_JOBS=3
ARG OPEN_SWIFT_GIT_BASE=https://github.com/OpenSwiftProject
ARG SWIFT_BRANCH=feature/gnu_objc_6.3
ARG LLVM_BRANCH=swift/release/6.3
ARG LIBDISPATCH_BRANCH=release/6.3
ARG LIBOBJC2_REF=v2.3
ARG TOOLS_MAKE_REF=make-2_9_3
ARG LIBS_BASE_REF=base-1_31_1
ARG LIBS_COREBASE_REF=openswift/corebase-0_1_1

ENV DEBIAN_FRONTEND=noninteractive
ENV OPEN_SWIFT_WORKSPACE=/work/OpenSwiftProject
ENV OPEN_SWIFT_SOURCE_ROOT=/work/OpenSwiftProject/swift-projects
ENV OPEN_SWIFT_GNUSTEP_SRC=/work/OpenSwiftProject/gnustep-src
ENV OPEN_SWIFT_BUILD_ROOT=/work/OpenSwiftProject/build
ENV OPEN_SWIFT_TOOLCHAIN_DESTDIR=/opt/openswift/swift-6.3-gnustep
ENV OPEN_SWIFT_BOOTSTRAP_TOOLCHAIN=/opt/openswift-bootstrap/usr
ENV GNUSTEP_PREFIX=/opt/openswift/gnustep
ENV OPEN_SWIFT_TOOLCHAIN=/opt/openswift/swift-6.3-gnustep/usr
ENV BUILD_JOBS=${BUILD_JOBS}

COPY scripts/install-build-deps.sh /opt/openswift-build/scripts/install-build-deps.sh
RUN /opt/openswift-build/scripts/install-build-deps.sh

COPY scripts/clone-sources.sh /opt/openswift-build/scripts/clone-sources.sh
RUN /opt/openswift-build/scripts/clone-sources.sh

COPY scripts/build-gnustep-baseline.sh /opt/openswift-build/scripts/build-gnustep-baseline.sh
RUN /opt/openswift-build/scripts/build-gnustep-baseline.sh

COPY scripts/build-swift-toolchain.sh /opt/openswift-build/scripts/build-swift-toolchain.sh
COPY scripts/build-swiftpm-toolchain.sh /opt/openswift-build/scripts/build-swiftpm-toolchain.sh
ARG TARGETARCH
ARG SWIFT_BUILD_CACHE_EPOCH=swift63-gnustep-v1
RUN --mount=from=swift-bootstrap,source=/usr,target=/opt/openswift-bootstrap/usr,ro \
  --mount=type=cache,id=openswift-${SWIFT_BUILD_CACHE_EPOCH}-${TARGETARCH},target=/work/OpenSwiftProject/swift-projects/build,sharing=locked \
  /opt/openswift-build/scripts/build-swift-toolchain.sh \
  && /opt/openswift-build/scripts/build-swiftpm-toolchain.sh

COPY scripts/smoke-test-swift-package.sh /opt/openswift-build/scripts/smoke-test-swift-package.sh
COPY scripts/smoke-test-toolchain.sh /opt/openswift-build/scripts/smoke-test-toolchain.sh
COPY tests/ /opt/openswift-build/tests/
RUN /opt/openswift-build/scripts/smoke-test-toolchain.sh

FROM ${UBUNTU_IMAGE} AS runtime

ARG IMAGE_REVISION=unknown
ARG IMAGE_CREATED=unknown

LABEL org.opencontainers.image.title="OpenSwiftProject Swift GNUstep Toolchain"
LABEL org.opencontainers.image.description="Alpha Swift 6.3 + GNUstep Objective-C interop toolchain image"
LABEL org.opencontainers.image.source="https://github.com/OpenSwiftProject/toolchain-docker"
LABEL org.opencontainers.image.revision="${IMAGE_REVISION}"
LABEL org.opencontainers.image.created="${IMAGE_CREATED}"
LABEL org.opencontainers.image.licenses="Apache-2.0"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    clang \
    git \
    libavahi-client3 \
    libavahi-common3 \
    libcurl4 \
    libedit2 \
    libffi8 \
    libgnutls30t64 \
    libicu74 \
    libncurses6 \
    libsqlite3-0 \
    libtinfo6 \
    libxml2 \
    libxslt1.1 \
    libz3-4 \
    lld \
    make \
    openssh-client \
    pkg-config \
    tar \
    tzdata \
    unzip \
    zip \
    zlib1g \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/openswift /opt/openswift

RUN ln -sf /usr/bin/clang /opt/openswift/swift-6.3-gnustep/usr/bin/clang \
  && ln -sf /usr/bin/clang++ /opt/openswift/swift-6.3-gnustep/usr/bin/clang++ \
  && ln -sf /usr/bin/make /usr/bin/gmake

ENV OPEN_SWIFT_TOOLCHAIN=/opt/openswift/swift-6.3-gnustep/usr
ENV GNUSTEP_PREFIX=/opt/openswift/gnustep
ENV PATH=/opt/openswift/swift-6.3-gnustep/usr/bin:/opt/openswift/gnustep/bin:${PATH}
ENV LD_LIBRARY_PATH=/opt/openswift/swift-6.3-gnustep/usr/lib/swift/linux:/opt/openswift/swift-6.3-gnustep/usr/lib:/opt/openswift/gnustep/lib
ENV CPATH=/opt/openswift/gnustep/include:/opt/openswift/gnustep/include/GNUstep
ENV LIBRARY_PATH=/opt/openswift/gnustep/lib
ENV PKG_CONFIG_PATH=/opt/openswift/gnustep/lib/pkgconfig:/opt/openswift/gnustep/share/pkgconfig

CMD ["/bin/bash"]
