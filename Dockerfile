# syntax=docker/dockerfile:1.7

ARG UBUNTU_VERSION=24.04

FROM ubuntu:${UBUNTU_VERSION} AS builder

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
ENV GNUSTEP_PREFIX=/opt/openswift/gnustep
ENV OPEN_SWIFT_TOOLCHAIN=/opt/openswift/swift-6.3-gnustep/usr
ENV BUILD_JOBS=${BUILD_JOBS}

COPY scripts/ /opt/openswift-build/scripts/

RUN /opt/openswift-build/scripts/install-build-deps.sh
RUN /opt/openswift-build/scripts/clone-sources.sh
RUN /opt/openswift-build/scripts/build-gnustep-baseline.sh
RUN /opt/openswift-build/scripts/build-swift-toolchain.sh
RUN /opt/openswift-build/scripts/smoke-test-toolchain.sh

FROM ubuntu:${UBUNTU_VERSION} AS runtime

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
    libcurl4 \
    libedit2 \
    libffi8 \
    libicu74 \
    libsqlite3-0 \
    libxml2 \
    libz3-4 \
    zlib1g \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/openswift /opt/openswift

ENV OPEN_SWIFT_TOOLCHAIN=/opt/openswift/swift-6.3-gnustep/usr
ENV GNUSTEP_PREFIX=/opt/openswift/gnustep
ENV PATH=/opt/openswift/swift-6.3-gnustep/usr/bin:/opt/openswift/gnustep/bin:${PATH}
ENV LD_LIBRARY_PATH=/opt/openswift/swift-6.3-gnustep/usr/lib/swift/linux:/opt/openswift/swift-6.3-gnustep/usr/lib:/opt/openswift/gnustep/lib
ENV CPATH=/opt/openswift/gnustep/include:/opt/openswift/gnustep/include/GNUstep
ENV LIBRARY_PATH=/opt/openswift/gnustep/lib
ENV PKG_CONFIG_PATH=/opt/openswift/gnustep/lib/pkgconfig:/opt/openswift/gnustep/share/pkgconfig

CMD ["/bin/bash"]

