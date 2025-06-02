#!/bin/bash

# Set LFS environment variable
export LFS=/mnt/lfs
export LC_ALL=POSIX

cd "$LFS/sources" || exit 1

# Find and extract Linux kernel source code
LINUX_ARCHIVE=$(ls linux-*.tar.xz)
if [ ! -f "$LINUX_ARCHIVE" ]; then
    echo "Error: Linux kernel source package not found"
    exit 1
fi

tar xf "$LINUX_ARCHIVE"
LINUX_DIR=$(ls -d linux-*/ | head -n1)
if [ ! -d "$LINUX_DIR" ]; then
    echo "Error: Linux source directory not found after extraction"
    exit 1
fi

cd "$LINUX_DIR" || exit 1

# Clean the source tree
make mrproper

# Extract API headers
make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include "$LFS/usr"

echo "Linux API headers installation complete"
