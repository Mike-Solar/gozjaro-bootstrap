#!/bin/bash

export LFS=/mnt/lfs
export LFS_TGT=$(uname -m)-gozjaro-linux-gnu
export LC_ALL=POSIX

cd "$LFS/sources" || exit 1

# Extract and prepare the source packages
GCC_ARCHIVE=$(ls gcc-*.tar.xz)
if [ ! -f "$GCC_ARCHIVE" ]; then
    echo "Error: GCC archive not found"
    exit 1
fi

tar xf "$GCC_ARCHIVE"
GCC_DIR=$(ls -d gcc-*/ | head -n1)
mv -v "$GCC_DIR" gcc
cd gcc || exit 1

# Prepare the GCC source directory
for pkg in mpfr gmp mpc; do
    archive=$(ls ../"$pkg"-*.tar.*)
    if [ ! -f "$archive" ]; then
        echo "Error: $pkg archive not found"
        exit 1
    fi
    tar xf "$archive"
    dir=$(ls -d "$pkg"-*/ | head -n1)
    if [ -z "$dir" ]; then
        echo "Error: $pkg directory not found after extraction"
        exit 1
    fi
    mv -v "$dir" "$pkg"
done

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