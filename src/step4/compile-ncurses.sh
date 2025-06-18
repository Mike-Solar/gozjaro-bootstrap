#!/bin/sh

# Set environment variables
export LFS=/mnt/lfs
export LC_ALL=POSIX
export LFS_TGT=$(uname -m)-gozjaro-linux-gnu

cd "$LFS/sources" || exit 1

# Extract source package
NCURSES_ARCHIVE=$(ls ncurses-*.tar.gz)
if [ ! -f "$NCURSES_ARCHIVE" ]; then
    echo "Error: Ncurses source package not found"
    exit 1
fi

tar xf "$NCURSES_ARCHIVE"
NCURSES_DIR=$(ls -d ncurses-*/ | head -n1)
cd "$NCURSES_DIR" || exit 1

# Modify configure script to prefer gawk
sed -i s/mawk// configure

# Build tic program
mkdir build
pushd build
../configure
make -C include
make -C progs tic
popd

# Configure Ncurses
./configure \
    --prefix=/usr \
    --host="$LFS_TGT" \
    --build="$(./config.guess)" \
    --mandir=/usr/share/man \
    --with-manpage-format=normal \
    --with-shared \
    --without-normal \
    --with-cxx-shared \
    --without-debug \
    --without-ada \
    --disable-stripping || exit 1

# Compile
make || exit 1

# Install
make DESTDIR="$LFS" TIC_PATH="$(pwd)/build/progs/tic" install || exit 1

# Create symbolic link
ln -sv libncursesw.so "$LFS/usr/lib/libncurses.so"

# Modify header file
sed -e 's/^#if.*XOPEN.*$/#if 1/' \
    -i "$LFS/usr/include/curses.h"

echo "Ncurses compilation and installation completed"