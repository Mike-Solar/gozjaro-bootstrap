#!/bin/bash

export LFS=/mnt/lfs
export LFS_TGT=$(uname -m)-gozjaro-linux-gnu

# Set the locale to POSIX
cd $LFS/sources || exit 1

# Extract and prepare the source packages
tar xf ../gcc-*.tar.xz
mv -v gcc-* gcc
cd gcc || exit 1

# Prepare the GCC source directory
tar xf ../mpfr-*.tar.xz
mv -v mpfr-* mpfr
tar xf ../gmp-*.tar.xz
mv -v gmp-* gmp
tar xf ../mpc-*.tar.gz
mv -v mpc-* mpc

# Create a symbolic link for the GMP directory
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac


# Create a build directory
mkdir -v build
cd build || exit 1
# Configure the GCC build

../configure \
  --target=$LFS_TGT \
  --prefix=$LFS/tools \
  --with-glibc-version=2.40 \
  --with-sysroot=$LFS \
  --with-newlib \
  --without-headers \
  --enable-default-pie \
  --enable-default-ssp \
  --disable-nls \
  --disable-shared \
  --disable-multilib \
  --disable-threads \
  --disable-libatomic \
  --disable-libgomp \
  --disable-libquadmath \
  --disable-libssp \
  --disable-libvtv \
  --disable-libstdcxx \
  --enable-languages=c,c++

# Compile GCC
make || exit 1
# Install GCC
make install || exit 1


cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include/limits.h