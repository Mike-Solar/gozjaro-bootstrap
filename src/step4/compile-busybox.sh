#!/bin/bash
set -euo pipefail

# Set environment variables
export LFS=${LFS:-/mnt/lfs}
export LC_ALL=POSIX
export LFS_TGT=$(uname -m)-gozjaro-linux-gnu

BUSYBOX_VERSION=1.36.1
TARBALL=busybox-${BUSYBOX_VERSION}.tar.bz2
URL=https://busybox.net/downloads/${TARBALL}

cd "$LFS/sources"

# Download
if [ ! -f "$TARBALL" ]; then
    wget "$URL"
fi

# Extract
rm -rf "busybox-${BUSYBOX_VERSION}"
tar -xf "$TARBALL"
cd "busybox-${BUSYBOX_VERSION}"

# Configure
make distclean
make defconfig

# Enable static build
sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config

# Compile
make -j"$(nproc)"

# Install
make CONFIG_PREFIX="$LFS/tools" install

# Create symlinks (so /tools/bin/sh works)
cd "$LFS/tools/bin"
ln -svf busybox sh
