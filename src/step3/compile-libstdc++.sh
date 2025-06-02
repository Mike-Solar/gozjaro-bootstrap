#!/bin/bash

# Set environment variables
export LFS=/mnt/lfs
export LC_ALL=POSIX
export LFS_TGT=$(uname -m)-gozjaro-linux-gnu

cd "$LFS/sources" || exit 1

# Use previously extracted GCC source code
GCC_DIR=$(ls -d gcc-*/ | head -n1)
if [ ! -d "$GCC_DIR" ]; then
    echo "Error: GCC source directory not found"
    exit 1
fi

cd "$GCC_DIR" || exit 1

# Create and enter build directory
mkdir -v build
cd build || exit 1

# Configure Libstdc++
../libstdc++-v3/configure \
    --host="$LFS_TGT" \
    --build="$(../config.guess)" \
    --prefix=/usr \
    --disable-multilib \
    --disable-nls \
    --disable-libstdcxx-pch \
    --with-gxx-include-dir=/tools/"$LFS_TGT"/include/c++/14.2.0 || exit 1

# Compile
make || exit 1

# Install
make DESTDIR="$LFS" install || exit 1

# Remove libtool archive files
rm -v "$LFS"/usr/lib/lib{stdc++{,exp,fs},supc++}.la

echo "Libstdc++ compilation and installation completed"
