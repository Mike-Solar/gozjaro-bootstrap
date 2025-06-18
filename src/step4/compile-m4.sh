#!/bin/sh

# Set environment variables
export LFS=/mnt/lfs
export LC_ALL=POSIX
export LFS_TGT=$(uname -m)-gozjaro-linux-gnu

cd "$LFS/sources" || exit 1

# Extract source package
M4_ARCHIVE=$(ls m4-*.tar.xz)
if [ ! -f "$M4_ARCHIVE" ]; then
    echo "Error: M4 source package not found"
    exit 1
fi

tar xf "$M4_ARCHIVE"
M4_DIR=$(ls -d m4-*/ | head -n1)
cd "$M4_DIR" || exit 1

# Configure
./configure \
    --prefix=/usr \
    --host="$LFS_TGT" \
    --build="$(build-aux/config.guess)" || exit 1

# Compile
make || exit 1

# Install
make DESTDIR="$LFS" install || exit 1


# Clean the build directory
cd "$LFS/sources" || exit 1
rm -rf "$M4_DIR" || exit 1

echo "M4 compilation and installation completed"