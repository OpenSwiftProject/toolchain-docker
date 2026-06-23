#!/usr/bin/env bash
set -euo pipefail

apt-get update
apt-get install -y --no-install-recommends \
  autoconf \
  automake \
  bash \
  bison \
  build-essential \
  ca-certificates \
  clang \
  cmake \
  curl \
  flex \
  git \
  icu-devtools \
  libavahi-client-dev \
  libcurl4-openssl-dev \
  libedit-dev \
  libffi-dev \
  libgnutls28-dev \
  libicu-dev \
  libjpeg-dev \
  libncurses-dev \
  libpng-dev \
  libsqlite3-dev \
  libssl-dev \
  libtiff-dev \
  libtool \
  libxml2-dev \
  libxslt1-dev \
  lld \
  ninja-build \
  pkg-config \
  python3 \
  python3-packaging \
  python3-six \
  rsync \
  tzdata \
  uuid-dev \
  zlib1g-dev

rm -rf /var/lib/apt/lists/*

