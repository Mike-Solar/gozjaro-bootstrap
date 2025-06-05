#!/bin/bash

# Set environment variables
export LFS=/mnt/lfs
export LC_ALL=POSIX
export LFS_TGT=$(uname -m)-gozjaro-linux-gnu

cd "$LFS/sources" || exit 1

# Extract Bash source package
BASH_ARCHIVE=$(ls bash-*.tar.gz)
if [ ! -f "$BASH_ARCHIVE" ]; then
    echo "Error: Bash source package not found"
    exit 1
fi

tar xf "$BASH_ARCHIVE"
BASH_DIR=$(ls -d bash-*/ | head -n1)
cd "$BASH_DIR" || exit 1


# Apply patches
patch -Np0 -i ../bash-5.2_p15-random-ub.patch
patch -Np0 -i ../bash-5.2_p21-wpointer-to-int.patch
patch -Np0 -i ../bash-5.2_p32-memory-leaks.patch
patch -Np0 -i ../bash-5.2_p32-invalid-continuation-byte-ignored-as-delimiter-1.patch
patch -Np0 -i ../bash-5.2_p32-invalid-continuation-byte-ignored-as-delimiter-2.patch
patch -Np0 -i ../bash-5.2_p32-erroneous-delimiter-pushback-condition.patch


# Configure Bash
./configure \
    --prefix=/usr \
    --build=$(sh support/config.guess) \
    --host="$LFS_TGT" \
    --without-bash-malloc \
    bash_cv_strtold_broken=no || exit 1

# Build
make || exit 1

# Install
make DESTDIR="$LFS" install || exit 1

# Create sh symlink
mkdir -pv "$LFS/bin"
ln -sv bash "$LFS/bin/sh"

echo "Bash compilation and installation completed"