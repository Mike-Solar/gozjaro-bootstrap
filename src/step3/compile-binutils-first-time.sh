#!/bin/bash

export LFS=/mnt/lfs
export LC_ALL=POSIX
export LFS_TGT=$(uname -m)-gozjaro-linux-gnu

cd "$LFS/sources" || exit 1

# Find and extract the binutils source archive
BINUTILS_ARCHIVE=$(ls binutils-*.tar.xz)
if [ ! -f "$BINUTILS_ARCHIVE" ]; then
    echo "Error: binutils archive not found"
    exit 1
fi

# Extract the source package
tar xf "$BINUTILS_ARCHIVE" || exit 1

# Enter the extracted directory
BINUTILS_DIR=$(ls -d binutils-*/ | head -n1)
if [ ! -d "$BINUTILS_DIR" ]; then
    echo "Error: binutils source directory not found"
    exit 1
fi

cd "$BINUTILS_DIR" || exit 1
mkdir -v build || exit 1
cd build || exit 1

../configure --prefix=$LFS/tools \
	--with-sysroot=$LFS \
	--target=$LFS_TGT \
	--disable-nls \
	--enable-gprofng=no \
	--disable-werror \
	--enable-new-dtags \
	--enable-default-hash-style=gnu || exit 1


make || exit 1
make install || exit 1
