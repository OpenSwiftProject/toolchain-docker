#!/usr/bin/env bash
set -euo pipefail

OPEN_SWIFT_GNUSTEP_SRC="${OPEN_SWIFT_GNUSTEP_SRC:-/work/OpenSwiftProject/gnustep-src}"
OPEN_SWIFT_BUILD_ROOT="${OPEN_SWIFT_BUILD_ROOT:-/work/OpenSwiftProject/build}"
GNUSTEP_PREFIX="${GNUSTEP_PREFIX:-/opt/openswift/gnustep}"
BUILD_JOBS="${BUILD_JOBS:-3}"

export PATH="$GNUSTEP_PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$GNUSTEP_PREFIX/lib:${LD_LIBRARY_PATH:-}"
export CPATH="$GNUSTEP_PREFIX/include:$GNUSTEP_PREFIX/include/GNUstep:${CPATH:-}"
export LIBRARY_PATH="$GNUSTEP_PREFIX/lib:${LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="$GNUSTEP_PREFIX/lib/pkgconfig:$GNUSTEP_PREFIX/share/pkgconfig:${PKG_CONFIG_PATH:-}"

mkdir -p "$OPEN_SWIFT_BUILD_ROOT" "$GNUSTEP_PREFIX"

echo "== Build libobjc2 =="
cmake -S "$OPEN_SWIFT_GNUSTEP_SRC/libobjc2" \
  -B "$OPEN_SWIFT_BUILD_ROOT/libobjc2" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_INSTALL_PREFIX="$GNUSTEP_PREFIX" \
  -DCMAKE_C_COMPILER=/usr/bin/clang \
  -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
  -DGNUSTEP_INSTALL_TYPE=NONE
cmake --build "$OPEN_SWIFT_BUILD_ROOT/libobjc2" -- -j"$BUILD_JOBS"
cmake --install "$OPEN_SWIFT_BUILD_ROOT/libobjc2"

echo "== Build swift-corelibs-libdispatch =="
cmake -S "$OPEN_SWIFT_GNUSTEP_SRC/../swift-projects/swift-corelibs-libdispatch" \
  -B "$OPEN_SWIFT_BUILD_ROOT/swift-corelibs-libdispatch" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_INSTALL_PREFIX="$GNUSTEP_PREFIX" \
  -DCMAKE_C_COMPILER=/usr/bin/clang \
  -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
  -DINSTALL_PRIVATE_HEADERS=YES \
  -DINSTALL_BLOCK_HEADERS_DIR=include \
  -DINSTALL_DISPATCH_HEADERS_DIR=include/dispatch \
  -DINSTALL_OS_HEADERS_DIR=include/os
cmake --build "$OPEN_SWIFT_BUILD_ROOT/swift-corelibs-libdispatch" -- -j"$BUILD_JOBS"
cmake --install "$OPEN_SWIFT_BUILD_ROOT/swift-corelibs-libdispatch"

echo "== Build gnustep-make =="
(
  cd "$OPEN_SWIFT_GNUSTEP_SRC/tools-make"
  ./configure \
    --prefix="$GNUSTEP_PREFIX" \
    --with-layout=fhs \
    --enable-native-objc-exceptions \
    --enable-objc-arc \
    --enable-debug-by-default \
    CC=/usr/bin/clang \
    CXX=/usr/bin/clang++ \
    CFLAGS="-I$GNUSTEP_PREFIX/include" \
    CXXFLAGS="-I$GNUSTEP_PREFIX/include" \
    CPPFLAGS="-I$GNUSTEP_PREFIX/include" \
    LDFLAGS="-fuse-ld=/usr/bin/ld.lld -L$GNUSTEP_PREFIX/lib"
  make -j"$BUILD_JOBS"
  make install
)

if [[ -f "$GNUSTEP_PREFIX/share/GNUstep/Makefiles/GNUstep.sh" ]]; then
  set +u
  # shellcheck disable=SC1091
  . "$GNUSTEP_PREFIX/share/GNUstep/Makefiles/GNUstep.sh"
  set -u
fi

echo "== Build gnustep-base =="
(
  cd "$OPEN_SWIFT_GNUSTEP_SRC/libs-base"
  ./configure \
    --prefix="$GNUSTEP_PREFIX" \
    CC=/usr/bin/clang \
    CFLAGS="-I$GNUSTEP_PREFIX/include" \
    CPPFLAGS="-I$GNUSTEP_PREFIX/include" \
    PKG_CONFIG_PATH="$PKG_CONFIG_PATH" \
    LDFLAGS="-fuse-ld=/usr/bin/ld.lld -L$GNUSTEP_PREFIX/lib"
  make -j"$BUILD_JOBS"
  make install
)

ICU_CONFIG_DIR="$OPEN_SWIFT_BUILD_ROOT/icu-config-shim"
mkdir -p "$ICU_CONFIG_DIR"
cat > "$ICU_CONFIG_DIR/icu-config" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  --cflags) pkg-config --cflags icu-uc icu-i18n ;;
  --ldflags|--ldflags-libsonly) pkg-config --libs icu-uc icu-i18n ;;
  --version) pkg-config --modversion icu-uc ;;
  *) pkg-config --cflags --libs icu-uc icu-i18n ;;
esac
EOF
chmod +x "$ICU_CONFIG_DIR/icu-config"
export PATH="$ICU_CONFIG_DIR:$PATH"

echo "== Build gnustep-corebase =="
(
  cd "$OPEN_SWIFT_GNUSTEP_SRC/libs-corebase"
  ./configure \
    --prefix="$GNUSTEP_PREFIX" \
    CC=/usr/bin/clang \
    CFLAGS="-I$GNUSTEP_PREFIX/include -fcommon" \
    CPPFLAGS="-I$GNUSTEP_PREFIX/include"
  make -j"$BUILD_JOBS"
  make install
)

