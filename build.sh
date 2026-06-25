#!/bin/sh -ex

NPROC=8
PATCHDIR="$PWD/patches"
CACHEDIR="$PWD/prefix/cache"
PREFIX="$PWD/prefix"

export PS3DEV="$PREFIX"
export PSL1GHT="$PS3DEV"
export PATH="$PREFIX/bin:$PATH"

make_prefix() {
    mkdir -p "$PREFIX"
    [ -f "$PREFIX/make-prefix" ] || mount -t tmpfs ps3-prefix "$PREFIX"
    touch "$PREFIX/make-prefix"
    mkdir -p "$PATCHDIR"
    mkdir -p "$CACHEDIR"

    cp -v files/* prefix/
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

    PATCHFILE="$PATCHDIR/binutils-$VERSION.patch"
    if [ "$DEVELOP" ]; then
        [ -f "$CACHEDIR/patched-binutils" ] || git -C "$CACHEDIR/binutils-$VERSION" diff --cached >"$PATCHFILE"
        touch "$CACHEDIR/patched-binutils"
    else
        git -C "$CACHEDIR/binutils-$VERSION" apply "$PATCHFILE"
    fi

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

    PATCHFILE="$PATCHDIR/gcc-$VERSION.patch"
    if [ "$DEVELOP" ]; then
        [ -f "$CACHEDIR/patched-gcc" ] || git -C "$CACHEDIR/gcc-$VERSION" diff --cached >"$PATCHFILE"
        touch "$CACHEDIR/patched-gcc"
    else
        git -C "$CACHEDIR/gcc-$VERSION" apply "$PATCHFILE"
    fi

    TARGET=powerpc64-ps3-elf
    mkdir -p "$CACHEDIR/build-gcc-$TARGET"
    cd "$CACHEDIR/build-gcc-$TARGET"
    [ -f "$CACHEDIR/build-gcc-$TARGET/Makefile" ] \
        || "$CACHEDIR/gcc-$VERSION/configure" \
        --prefix="$PREFIX" \
        --target="$TARGET" \
        --disable-dependency-tracking \
        --disable-libcc1 \
        --disable-libstdcxx-pch \
        --disable-multilib \
        --disable-nls \
        --disable-shared \
        --disable-win32-registry \
        --disable-bootstrap \
        --enable-languages="c" \
        --enable-long-double-128 \
        --enable-lto \
        --enable-threads \
        --with-cpu="cell" \
        --with-newlib \
        --enable-newlib-multithread \
        --enable-newlib-hw-fp \
        --with-system-zlib
    cd "$CACHEDIR/build-gcc-$TARGET" \
        && gmake -j$NPROC all-gcc \
        && gmake -j$NPROC all-target-libgcc \
        && gmake -j$NPROC all-target-libstdc++-v3 \
        && gmake install-gcc \
        && gmake install-target-libgcc \
        && gmake install-target-libstdc++-v3

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
    # cd "$CACHEDIR/build-gcc-$TARGET" \
    #     && gmake -j$NPROC all-gcc \
    #     && gmake -j$NPROC all-target-libgcc \
    #     && gmake -j$NPROC all-target-libstdc++-v3 \
    #     && gmake install-gcc \
    #     && gmake install-target-libgcc \
    #     && gmake install-target-libstdc++-v3
    
    # TODO: ICE when scheduling with libgcc
    cd "$CACHEDIR/build-gcc-$TARGET" \
        && gmake -j$NPROC all-gcc \
        && gmake install-gcc

    touch "$PREFIX/build-gcc"
}

build_newlib() {
    VERSION=1.20.0
    download_cached "newlib-$VERSION.tar.gz" "https://sourceware.org/pub/newlib/newlib-$VERSION.tar.gz"
    [ -d "$CACHEDIR/newlib-$VERSION" ] || tar -xvzf "$CACHEDIR/newlib-$VERSION.tar.gz" -C "$CACHEDIR"
    git_initialize "$CACHEDIR/newlib-$VERSION"

    PATCHFILE="$PATCHDIR/newlib-$VERSION.patch"
    if [ "$DEVELOP" ]; then
        [ -f "$CACHEDIR/patched-newlib" ] || git -C "$CACHEDIR/newlib-$VERSION" diff --cached >"$PATCHFILE"
        touch "$CACHEDIR/patched-newlib"
    else
        git -C "$CACHEDIR/newlib-$VERSION" apply "$PATCHFILE"
    fi

    TARGET=powerpc64-ps3-elf
    mkdir -p "$CACHEDIR/build-newlib-$TARGET"
    cd "$CACHEDIR/build-newlib-$TARGET"
    [ -f "$CACHEDIR/build-newlib-$TARGET/Makefile" ] \
        || "$CACHEDIR/newlib-$VERSION/configure" \
        --prefix="$PREFIX" \
        --target="$TARGET" \
        --disable-newlib-supplied-syscalls \
        --disable-newlib-wide-orient
    cd "$CACHEDIR/build-newlib-$TARGET" \
        && gmake -j$NPROC \
        && gmake install
    touch "$PREFIX/build-newlib"
}

build_psl1ght() {
    COMMIT=f987683
    download_cached "psl1ght.tar.xz" "https://github.com/ps3dev/psl1ght/tarball/master"
    [ -d "$CACHEDIR/ps3dev-PSL1GHT-$COMMIT" ] || tar -xvzf "$CACHEDIR/psl1ght.tar.xz" -C "$CACHEDIR"
    git_initialize "$CACHEDIR/ps3dev-PSL1GHT-$COMMIT"

    PATCHFILE="$PATCHDIR/ps3dev-PSL1GHT-$COMMIT.patch"
    if [ "$DEVELOP" ]; then
        [ -f "$CACHEDIR/patched-newlib" ] || git -C "$CACHEDIR/ps3dev-PSL1GHT-$COMMIT" diff --cached >"$PATCHFILE"
        touch "$CACHEDIR/ps3dev-PSL1GHT"
    else
        git -C "$CACHEDIR/ps3dev-PSL1GHT-$COMMIT" apply "$PATCHFILE"
    fi

    cd "$CACHEDIR/ps3dev-PSL1GHT-$COMMIT" \
        && gmake -j$NPROC \
        && gmake install
    #touch "$PREFIX/build-psl1ght"
}

make_prefix
[ -f "$PREFIX/build-binutils" ] || build_binutils
[ -f "$PREFIX/build-gcc" ] || build_gcc
[ -f "$PREFIX/build-newlib" ] || build_newlib

# PPU symlinks
which ppu-as      || ln -s "$PREFIX/bin/powerpc64-ps3-elf-as"      "$PREFIX/bin/ppu-as"
which ppu-gcc     || ln -s "$PREFIX/bin/powerpc64-ps3-elf-gcc"     "$PREFIX/bin/ppu-gcc"
which ppu-g++     || ln -s "$PREFIX/bin/powerpc64-ps3-elf-g++"     "$PREFIX/bin/ppu-g++"
which ppu-ar      || ln -s "$PREFIX/bin/powerpc64-ps3-elf-ar"      "$PREFIX/bin/ppu-ar"
which ppu-ld      || ln -s "$PREFIX/bin/powerpc64-ps3-elf-ld"      "$PREFIX/bin/ppu-ld"
which ppu-strip   || ln -s "$PREFIX/bin/powerpc64-ps3-elf-strip"   "$PREFIX/bin/ppu-strip"
which ppu-objcopy || ln -s "$PREFIX/bin/powerpc64-ps3-elf-objcopy" "$PREFIX/bin/ppu-objcopy"

# SPU symlinks
which spu-as      || ln -s "$PREFIX/bin/spu-unknown-elf-as"        "$PREFIX/bin/spu-as"
which spu-gcc     || ln -s "$PREFIX/bin/spu-unknown-elf-gcc"       "$PREFIX/bin/spu-gcc"
which spu-g++     || ln -s "$PREFIX/bin/spu-unknown-elf-g++"       "$PREFIX/bin/spu-g++"
which spu-ar      || ln -s "$PREFIX/bin/spu-unknown-elf-ar"        "$PREFIX/bin/spu-ar"
which spu-ld      || ln -s "$PREFIX/bin/spu-unknown-elf-ld"        "$PREFIX/bin/spu-ld"
which spu-strip   || ln -s "$PREFIX/bin/spu-unknown-elf-strip"     "$PREFIX/bin/spu-strip"
which spu-objcopy || ln -s "$PREFIX/bin/spu-unknown-elf-objcopy"   "$PREFIX/bin/spu-objcopy"

[ -f "$PREFIX/build-psl1ght" ] || build_psl1ght
