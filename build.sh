#!/bin/sh -ex

NPROC=8
PATCHDIR="$PWD/patches"
CACHEDIR="$PWD/prefix/cache"
PREFIX="$PWD/prefix"
export PATH="$PREFIX/bin:$PATH"

make_prefix() {
    mkdir -p "$PREFIX"
    [ -f "$PREFIX/make-prefix" ] || mount -t tmpfs ps3-prefix "$PREFIX"
    touch "$PREFIX/make-prefix"
    mkdir -p "$PATCHDIR"
    mkdir -p "$CACHEDIR"
}

download_cached() {
    [ -f "$CACHEDIR/$1" ] || wget -O - "$2" >"$CACHEDIR/$1"
}

git_initialize() {
    git_initialize_inner() {
        git -C "$1" init
        git -C "$1" add .
        git -C "$1" commit -m "intitial"
    }
    [ -d "$1/.git" ] || git_initialize_inner "$1"
}

build_binutils() {
    VERSION=2.46.1
    download_cached "binutils-$VERSION.tar.xz" "https://ftp.gnu.org/gnu/binutils/binutils-$VERSION.tar.xz"
    [ -d "$CACHEDIR/binutils-$VERSION" ] || tar -xvzf "$CACHEDIR/binutils-$VERSION.tar.xz" -C "$CACHEDIR"
    git_initialize "$CACHEDIR/binutils-$VERSION"
    git -C "$CACHEDIR/binutils-$VERSION" diff --cached >"$PATCHDIR/binutils-$VERSION.patch"

    TARGET=powerpc64-ps3-elf
    mkdir -p "$CACHEDIR/build-binutils-$TARGET"
    cd "$CACHEDIR/build-binutils-$TARGET"
    [ -f "$CACHEDIR/build-binutils-$TARGET/Makefile" ] \
        || "$CACHEDIR/binutils-$VERSION/configure" \
        --prefix="$PREFIX" \
        --target="$TARGET" \
        --disable-nls \
        --disable-shared \
        --disable-debug \
        --disable-dependency-tracking \
        --disable-werror \
        --enable-64-bit-bfd \
        --with-gcc \
        --with-gnu-as \
        --with-gnu-ld
    cd "$CACHEDIR/build-binutils-$TARGET" \
        && gmake -j$NPROC \
        && gmake install

    TARGET=spu-unknown-elf
    mkdir -p "$CACHEDIR/build-binutils-$TARGET"
    cd "$CACHEDIR/build-binutils-$TARGET"
    [ -f "$CACHEDIR/build-binutils-$TARGET/Makefile" ] \
        || "$CACHEDIR/binutils-$VERSION/configure" \
        --prefix="$PREFIX" \
        --target="$TARGET" \
        --disable-nls \
        --disable-shared \
        --disable-debug \
        --disable-dependency-tracking \
        --disable-werror \
        --with-gcc \
        --with-gnu-as \
        --with-gnu-ld
    cd "$CACHEDIR/build-binutils-$TARGET" \
        && gmake -j$NPROC \
        && gmake install

    touch "$PREFIX/build-binutils"
}

build_gcc() {
    VERSION=16.1.0
    download_cached "gcc-$VERSION.tar.xz" "https://ftp.gnu.org/gnu/gcc/gcc-$VERSION/gcc-$VERSION.tar.xz"
    [ -d "$CACHEDIR/gcc-$VERSION" ] || tar -xvzf "$CACHEDIR/gcc-$VERSION.tar.xz" -C "$CACHEDIR"
    git_initialize "$CACHEDIR/gcc-$VERSION"
    git -C "$CACHEDIR/gcc-$VERSION" diff --cached >"$PATCHDIR/gcc-$VERSION.patch"

    # TARGET=powerpc64-ps3-elf
    # mkdir -p "$CACHEDIR/build-gcc-$TARGET"
    # cd "$CACHEDIR/build-gcc-$TARGET"
    # [ -f "$CACHEDIR/build-gcc-$TARGET/Makefile" ] \
    #     || "$CACHEDIR/gcc-$VERSION/configure" \
    #     --prefix="$PREFIX" \
    #     --target="$TARGET" \
    #     --disable-dependency-tracking \
    #     --disable-libcc1 \
    #     --disable-libstdcxx-pch \
    #     --disable-multilib \
    #     --disable-nls \
    #     --disable-shared \
    #     --disable-win32-registry \
    #     --disable-bootstrap \
    #     --enable-languages="c" \
    #     --enable-long-double-128 \
    #     --enable-lto \
    #     --enable-threads \
    #     --with-cpu="cell" \
    #     --with-newlib \
    #     --enable-newlib-multithread \
    #     --enable-newlib-hw-fp \
    #     --with-system-zlib
    # cd "$CACHEDIR/build-gcc-$TARGET" \
    #     && gmake -j$NPROC all-gcc \
    #     && gmake -j$NPROC all-target-libgcc \
    #     && gmake -j$NPROC all-target-libstdc++-v3 \
    #     && gmake install-gcc \
    #     && gmake install-target-libgcc \
    #     && gmake install-target-libstdc++-v3

    TARGET=spu-unknown-elf
    mkdir -p "$CACHEDIR/build-gcc-$TARGET"
    cd "$CACHEDIR/build-gcc-$TARGET"
    [ -f "$CACHEDIR/build-gcc-$TARGET/Makefile" ] \
        || "$CACHEDIR/gcc-$VERSION/configure" \
        --prefix="$PREFIX" \
        --target="$TARGET" \
        --disable-dependency-tracking \
        --disable-libcc1 \
        --disable-libssp \
        --disable-multilib \
        --disable-nls \
        --disable-shared \
        --disable-win32-registry \
        --disable-bootstrap \
        --enable-languages="c" \
        --enable-lto \
        --enable-threads \
        --with-newlib \
        --enable-newlib-multithread \
        --enable-newlib-hw-fp \
        --with-pic
    cd "$CACHEDIR/build-gcc-$TARGET" \
        && gmake -j$NPROC all-gcc \
        && gmake -j$NPROC all-target-libgcc \
        && gmake -j$NPROC all-target-libstdc++-v3 \
        && gmake install-gcc \
        && gmake install-target-libgcc \
        && gmake install-target-libstdc++-v3
}

make_prefix
[ -f "$PREFIX/build-binutils" ] || build_binutils
[ -f "$PREFIX/build-gcc" ] || build_gcc
