#!/bin/bash

# Set environment variables
export LFS=/mnt/lfs
export LC_ALL=POSIX
export LFS_TGT=$(uname -m)-gozjaro-linux-gnu

cp -v bash-5.2_p15-random-ub.patch "$LFS/sources"
cp -v bash-5.2_p21-wpointer-to-int.patch "$LFS/sources"
cp -v bash-5.2_p32-memory-leaks.patch "$LFS/sources"
cp -v bash-5.2_p32-invalid-continuation-byte-ignored-as-delimiter-1.patch "$LFS/sources"
cp -v bash-5.2_p32-invalid-continuation-byte-ignored-as-delimiter-2.patch "$LFS/sources"
cp -v bash-5.2_p32-erroneous-delimiter-pushback-condition.patch "$LFS/sources"
cp -v bash-5.2-mkbuiltins-ansi-prototypes.patch "$LFS/sources"

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
patch -Np0 -i ../bash-5.2-mkbuiltins-ansi-prototypes.patch

_bashconfig=(-DDEFAULT_PATH_VALUE=\'\"/usr/local/sbin:/usr/local/bin:/usr/bin\"\'
               -DSTANDARD_UTILS_PATH=\'\"/usr/bin\"\'
               -DSYS_BASHRC=\'\"/etc/bash.bashrc\"\'
               -DSYS_BASH_LOGOUT=\'\"/etc/bash.bash_logout\"\'
               -DNON_INTERACTIVE_LOGIN_SHELLS
               -std=gnu17)

 export CFLAGS="${CFLAGS} ${_bashconfig[@]}"

# Configure Bash
./configure \
    --prefix=/usr \
    --build=$(sh support/config.guess) \
    --with-curses \
    --enable-readline \
    --with-installed-readline \
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