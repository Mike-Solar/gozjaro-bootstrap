#!/bin/bash

export LFS=/mnt/lfs
export LC_ALL=POSIX
export LFS_TGT=$(uname -m)-gozjaro-linux-gnu

cd $LFS/sources || exit 1
tar xf binutils-*.tar.xz || exit 1
cd binutils-* || exit 1
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
