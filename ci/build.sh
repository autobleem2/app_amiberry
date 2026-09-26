#!/usr/bin/env bash
# Builds Amiberry-Lite (the SDL2 line of Amiberry, for low-end machines) in the autobleem-build image
# (ghcr.io/autobleem2/autobleem-build) and packages it as an AutoBleem App:
#
#   ci/build.sh native                 a host build (build_native/)
#   ci/build.sh psc|rpi|rpi64|pcusb    a target -> dist/amiberry-<key>-<version>.zip
#   ci/build.sh all                    every one of them
#
# There is no Windows package: Amiberry-Lite is Linux-only, and the current Amiberry needs SDL3, which the
# console cannot run (the owner's decision, 2026-09-25 - Windows has WinUAE).
#
# upstream/* are pinned submodules, never edited: each build copies them and applies patches/<name>/*.patch
# (CLAUDE.md). The libraries Amiberry needs besides SDL2 - zlib, libpng, FLAC and zstd - are built from their
# submodules as static libraries and linked in; SDL2, SDL2_image and SDL2_ttf are the launcher's (the console)
# or the system's (the Pis, the PC stick).
#
# The console: Amiberry is C++17 and uses std::filesystem, which the console's gcc-6 cannot build. It is built
# with the image's gcc-12 (Debian's armhf cross compiler) against the console's own glibc 2.24 - the Stretch
# sysroot, forced ahead of gcc-12's own headers and libraries - with libstdc++ and libgcc linked in statically
# (so the console's older libstdc++ is not needed) and resources/psc/glibc_compat.c for the handful of newer
# glibc symbols that libstdc++ uses. tools/check_psc_binary.sh then holds the program to GLIBC 2.24.
#
# On the build server: docker run --rm -u $(id -u):$(id -g) -v $PWD:/src -w /src \
#                          ghcr.io/autobleem2/autobleem-build:develop ci/build.sh all
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD

VERSION="${AB_VERSION:-$(tr -d '\r' < VERSION)}"
JOBS="${JOBS:-$(nproc)}"
PSC=${AB_PSC_TOOLCHAIN:-/opt/psc}
APP=amiberry
PROGRAM=amiberry-lite

banner() { printf '\n==== %s ====\n' "$*"; }

# ---------------------------------------------------------------------------------------------------------
# One target. Each target_* sets CROSS, CC, CXX, STRIP, CFLAGS_T/CXXFLAGS_T (compile flags), LDFLAGS_T (link
# flags for programs and shared libraries), LIBS_T (libraries at the end of Amiberry's link line), CMAKE_T (a
# cross build's CMake arguments) and SDL_PREFIX
# ---------------------------------------------------------------------------------------------------------
cross_cmake() { # cross_cmake <processor> <multiarch triplet or "">
    CMAKE_T=(-DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR="$1" -DCMAKE_C_COMPILER="$CC"
             -DCMAKE_CXX_COMPILER="$CXX" -DCMAKE_AR="$(command -v "${CROSS}ar")"
             -DCMAKE_RANLIB="$(command -v "${CROSS}ranlib")" -DCMAKE_STRIP="$(command -v "$STRIP")")
    [ -z "$2" ] || CMAKE_T+=(-DCMAKE_LIBRARY_ARCHITECTURE="$2")
}
target_native() {
    CROSS=""; CC=gcc; CXX=g++; STRIP=strip; CFLAGS_T=""; CXXFLAGS_T=""; LDFLAGS_T=""; LIBS_T=""; CMAKE_T=()
    SDL_PREFIX=/usr
}
target_psc() {
    local sr="$PSC/sysroot" gcc=/usr/lib/gcc-cross/arm-linux-gnueabihf/12 cxx=/usr/arm-linux-gnueabihf/include/c++/12
    CROSS=arm-linux-gnueabihf-; CC="${CROSS}gcc"; CXX="${CROSS}g++"; STRIP="${CROSS}strip"
    # neon-fp-armv8 (what Amiberry's ARM assembly is built for); gcc-12 fails on neon-vfpv4 with armv8-a (an ICE in FLAC)
    local cpu="-march=armv8-a -mtune=cortex-a35 -mfpu=neon-fp-armv8 -mfloat-abi=hard"
    # the console's headers only: gcc-12's own C++ headers, then the sysroot's C library - never the Bookworm
    # armhf libc under /usr/arm-linux-gnueabihf that the compiler would otherwise search first
    local cinc="-nostdinc -isystem $gcc/include -isystem $sr/usr/include/arm-linux-gnueabihf -isystem $sr/usr/include"
    CFLAGS_T="$cpu $cinc"
    CXXFLAGS_T="$cpu -nostdinc -isystem $cxx -isystem $cxx/arm-linux-gnueabihf -isystem $cxx/backward $cinc -include $ROOT/resources/psc/glibc_compat.h"
    LDFLAGS_T="--sysroot=$sr -B$sr/usr/lib/arm-linux-gnueabihf/ -L$sr/lib/arm-linux-gnueabihf -L$sr/usr/lib/arm-linux-gnueabihf -static-libstdc++ -static-libgcc -Wl,--exclude-libs,ALL $ROOT/build_psc/glibc_compat.o -pthread"
    # glibc 2.24 keeps forkpty in libutil (2.34 moved it into libc); at the end of the link line, after
    # upstream's -Wl,--as-needed
    LIBS_T="-lutil"
    cross_cmake arm ""
    SDL_PREFIX="$PSC/sdl2"
}
target_rpi() {
    CROSS=arm-linux-gnueabihf-; CC="${CROSS}gcc"; CXX="${CROSS}g++"; STRIP="${CROSS}strip"
    CFLAGS_T="-mfloat-abi=hard -mfpu=neon-vfpv4 -march=armv7-a"; CXXFLAGS_T="$CFLAGS_T"; LDFLAGS_T=""
    cross_cmake arm arm-linux-gnueabihf
    LIBS_T=""
    SDL_PREFIX=/usr
}
target_rpi64() {
    CROSS=aarch64-linux-gnu-; CC="${CROSS}gcc"; CXX="${CROSS}g++"; STRIP="${CROSS}strip"
    CFLAGS_T="-march=armv8-a"; CXXFLAGS_T="$CFLAGS_T"; LDFLAGS_T=""
    cross_cmake aarch64 aarch64-linux-gnu
    LIBS_T=""
    SDL_PREFIX=/usr
}
target_pcusb() {
    CROSS=i686-linux-gnu-; CC="${CROSS}gcc"; CXX="${CROSS}g++"; STRIP="${CROSS}strip"
    CFLAGS_T="-march=i686 -mtune=generic -D_FILE_OFFSET_BITS=64"; CXXFLAGS_T="$CFLAGS_T"; LDFLAGS_T=""
    cross_cmake i686 i386-linux-gnu
    LIBS_T=""
    SDL_PREFIX=/usr
}

# ---------------------------------------------------------------------------------------------------------
# The static libraries, into build_<key>/deps (include/, lib/). Kept between runs: a target whose deps/.stamp
# names the same submodule commits, compiler and flags is not rebuilt.
# ---------------------------------------------------------------------------------------------------------
deps_stamp() {
    git submodule status upstream/zlib upstream/libpng upstream/flac upstream/zstd 2>/dev/null \
        | awk '{print $1 $2}' | tr -d '+-'
    echo "$CC $CFLAGS_T $LDFLAGS_T"
}

cmake_dep() { # cmake_dep <key> <name> <source subdir> <cmake args...>
    local key="$1" name="$2" sub="$3"; shift 3
    local src="build_$key/deps-src/$name" deps="$ROOT/build_$key/deps"
    rm -rf "$src"
    mkdir -p "$src"
    cp -r "upstream/$name/." "$src/src"
    rm -rf "$src/src/.git"
    # the libraries' own warnings are not ours to fix: their output goes to a log, shown when a step fails
    local log="build_$key/deps-$name.log"
    if ! { PKG_CONFIG_LIBDIR="$deps/lib/pkgconfig" cmake -S "$src/src/$sub" -B "$src/build" -G "Unix Makefiles" \
               --no-warn-unused-cli -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$deps" \
               -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_PREFIX_PATH="$deps" -DCMAKE_C_FLAGS="$CFLAGS_T" \
               -DCMAKE_CXX_FLAGS="$CXXFLAGS_T" -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS_T" \
               -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DBUILD_SHARED_LIBS=OFF "${CMAKE_T[@]}" "$@" \
           && cmake --build "$src/build" -j "$JOBS" && cmake --install "$src/build"; } > "$log" 2>&1; then
        tail -40 "$log" >&2
        echo "    ERROR: $name failed (the whole log: $log)" >&2
        exit 1
    fi
    rm -f "$log"
}

build_deps() { # build_deps <key>
    local key="$1" deps="$ROOT/build_$1/deps"
    local stamp; stamp=$(deps_stamp)
    if [ -f "$deps/.stamp" ] && [ "$(cat "$deps/.stamp")" = "$stamp" ]; then
        echo "    libraries: up to date (build_$key/deps)"
        return
    fi
    rm -rf "$deps" "build_$key/deps-src"
    mkdir -p "$deps"

    echo "    zlib"
    cmake_dep "$key" zlib . -DZLIB_BUILD_EXAMPLES=OFF
    rm -f "$deps"/lib/libz.so*
    echo "    libpng"
    cmake_dep "$key" libpng . -DPNG_SHARED=OFF -DPNG_STATIC=ON -DPNG_TESTS=OFF -DPNG_TOOLS=OFF \
        -DPNG_FRAMEWORK=OFF -DPNG_HARDWARE_OPTIMIZATIONS=OFF \
        -DZLIB_INCLUDE_DIR="$deps/include" -DZLIB_LIBRARY="$deps/lib/libz.a" -DZLIB_ROOT="$deps"
    echo "    FLAC"
    cmake_dep "$key" flac . -DBUILD_CXXLIBS=OFF -DBUILD_PROGRAMS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_TESTING=OFF \
        -DBUILD_DOCS=OFF -DINSTALL_MANPAGES=OFF -DWITH_OGG=OFF -DWITH_FORTIFY_SOURCE=OFF \
        -DWITH_STACK_PROTECTOR=OFF -DENABLE_MULTITHREADING=OFF \
        -DCMAKE_C_FLAGS="$CFLAGS_T -fno-tree-vectorize"   # gcc-12 has an ICE vectorising its window functions for 32-bit NEON
    echo "    zstd"
    cmake_dep "$key" zstd build/cmake -DZSTD_BUILD_SHARED=OFF -DZSTD_BUILD_STATIC=ON -DZSTD_BUILD_PROGRAMS=OFF \
        -DZSTD_BUILD_TESTS=OFF -DZSTD_BUILD_CONTRIB=OFF -DZSTD_MULTITHREAD_SUPPORT=OFF

    rm -rf "build_$key/deps-src"
    echo "$stamp" > "$deps/.stamp"
}

# ---------------------------------------------------------------------------------------------------------
# Amiberry-Lite
# ---------------------------------------------------------------------------------------------------------
build_amiberry() { # build_amiberry <key>
    local key="$1" dir="build_$1/amiberry"
    rm -rf "$dir"
    mkdir -p "$dir"
    cp -r upstream/amiberry-lite/. "$dir/src"
    rm -rf "$dir/src/.git"
    for p in patches/amiberry-lite/*.patch; do
        [ -f "$p" ] || continue
        patch -d "$dir/src" -p1 --no-backup-if-mismatch < "$p" >/dev/null
    done

    # what it does not need on these machines is left out: serial ports, MIDI, CD32 video (libmpeg2), network
    # emulation, MP3 CD audio; OpenGL, D-Bus and GPIO are off upstream already
    PKG_CONFIG_LIBDIR="$ROOT/build_$key/deps/lib/pkgconfig" cmake -S "$dir/src" -B "$dir/build" \
        -G "Unix Makefiles" --no-warn-unused-cli -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH="$ROOT/build_$key/deps;$SDL_PREFIX" -DCMAKE_SKIP_RPATH=ON \
        -DCMAKE_C_FLAGS="$CFLAGS_T" -DCMAKE_CXX_FLAGS="$CXXFLAGS_T" \
        -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS_T" -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS_T" \
        -DCMAKE_MODULE_LINKER_FLAGS="$LDFLAGS_T" -DCMAKE_CXX_STANDARD_LIBRARIES="$LIBS_T" "${CMAKE_T[@]}" \
        -DUSE_LIBSERIALPORT=OFF -DUSE_PORTMIDI=OFF -DUSE_LIBMPEG2=OFF -DUSE_LIBENET=OFF -DUSE_MPG123=OFF \
        -DUSE_UAENET_PCAP=OFF -DUSE_ZSTD=ON -DUSE_PCEM=OFF -DUSE_OPENGL=OFF -DUSE_DBUS=OFF -DUSE_GPIOD=OFF \
        -DWITH_LTO=OFF >/dev/null
    cmake --build "$dir/build" -j "$JOBS" 2>&1 | { grep -E "error:|Error [0-9]|undefined reference" || true; }
    local built; built=$(find "$dir/build" -maxdepth 2 -type f -name "$PROGRAM" | head -1)
    [ -n "$built" ] || { echo "    ERROR: $PROGRAM was not built" >&2; exit 1; }

    # the App folder in Amiberry's portable layout (amiberry.portable: every path under the working directory,
    # which the launcher makes the App's folder)
    local stage="build_$key/Apps/$APP"
    rm -rf "$stage"
    mkdir -p "$stage/bin/$key" "$stage/plugins" "$stage/licences"
    cp "$built" "$stage/bin/$key/$PROGRAM"
    "$STRIP" "$stage/bin/$key/$PROGRAM"
    local so
    for so in capsimage floppybridge; do
        find "$dir/build" -type f -name "lib$so.so*" -exec cp {} "$stage/plugins/" \;
    done
    for so in "$stage"/plugins/*.so*; do [ -f "$so" ] && "$STRIP" --strip-unneeded "$so"; done
    cp -r "$dir/src/data" "$stage/data"
    cp resources/branding/amiberry-logo.png "$stage/data/amiberry-logo.png"
    # the portable folder names are Linux's, lower case (upstream's capitalised ones are the macOS build's)
    cp -r "$dir/src/roms" "$stage/roms"
    cp -r "$dir/src/whdboot" "$stage/whdboot"
    cp -r "$dir/src/controllers" "$stage/controllers"
    mkdir -p "$stage/conf" "$stage/floppies" "$stage/lha" "$stage/harddrives" "$stage/savestates" \
        "$stage/screenshots"
    : > "$stage/amiberry.portable"
    cp resources/app/app.ini resources/app/readme.txt resources/app/icon.png resources/app/pad.ini "$stage/"
    sed -i "s/^Version=.*/Version=$VERSION/" "$stage/app.ini"
    cp "$dir/src/LICENSE" "$stage/LICENSE-amiberry.txt"
    cp "$dir/src/external/capsimage/LICENCE.txt" "$stage/licences/capsimage.txt"
    cat "$dir/src/external/mt32emu/COPYING.LESSER.txt" > "$stage/licences/mt32emu.txt"
    cp upstream/zlib/LICENSE "$stage/licences/zlib.txt"
    cp upstream/libpng/LICENSE "$stage/licences/libpng.txt"
    cp upstream/flac/COPYING.Xiph "$stage/licences/flac.txt"
    cp upstream/zstd/LICENSE "$stage/licences/zstd.txt"
}

build_target() { # build_target <key>
    banner "$1 (build_$1)"
    "target_$1"
    mkdir -p "build_$1"
    if [ "$1" = psc ]; then
        # the glibc compat object every console program and plugin links (see the top of this file)
        "$CC" $CFLAGS_T -O2 -c resources/psc/glibc_compat.c -o build_psc/glibc_compat.o
    fi
    build_deps "$1"
    build_amiberry "$1"
}

package() { # package <key>
    local key="$1" dir="build_$1"
    local zip="dist/$APP-$key-$VERSION.zip"
    mkdir -p dist
    rm -f "$zip"
    (cd "$dir" && python3 "$ROOT/tools/zip_app.py" "$ROOT/$zip" "Apps/$APP")
    ls -l "$zip"
}

check() { # check <key>: the program and its plugins are the platform's and need nothing we do not ship
    local key="$1" stage="build_$1/Apps/$APP" f
    case "$key" in
        psc)
            file "$stage/bin/psc/$PROGRAM" | grep -q 'ELF 32-bit LSB.*ARM'
            for f in "$stage/bin/psc/$PROGRAM" "$stage"/plugins/*.so*; do
                [ -f "$f" ] && bash tools/check_psc_binary.sh "$f" "$PSC"
            done ;;
        rpi) file "$stage/bin/rpi/$PROGRAM" | grep -q 'ELF 32-bit LSB.*ARM' ;;
        rpi64) file "$stage/bin/rpi64/$PROGRAM" | grep -q 'ELF 64-bit LSB.*aarch64' ;;
        pcusb) file "$stage/bin/pcusb/$PROGRAM" | grep -q 'ELF 32-bit LSB.*Intel 80386' ;;
    esac
    bash tools/check_needed.sh "$key" "$stage"
}

build_one() { # build_one <key>
    build_target "$1"
    check "$1"
    package "$1"
}

[ $# -gt 0 ] || { echo "usage: $0 native|psc|rpi|rpi64|pcusb|all" >&2; exit 2; }
for target in "$@"; do
    case "$target" in
        native) build_target native; ls -l "build_native/Apps/$APP/bin/native/" ;;
        psc | rpi | rpi64 | pcusb) build_one "$target" ;;
        all) build_target native; for k in psc rpi rpi64 pcusb; do build_one "$k"; done ;;
        *) echo "unknown target: $target" >&2; exit 2 ;;
    esac
done
