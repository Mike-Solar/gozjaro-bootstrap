#!/bin/bash

# Set environment variables
export LFS=/mnt/lfs
export LC_ALL=POSIX
export LFS_TGT=$(uname -m)-gozjaro-linux-gnu

cd "$LFS/sources" || exit 1

# Unarchieve Glibc
GLIBC_ARCHIVE=$(ls glibc-*.tar.xz)
if [ ! -f "$GLIBC_ARCHIVE" ]; then
    echo "错误：未找到 Glibc 源码包"
    exit 1
fi

tar xf "$GLIBC_ARCHIVE"
GLIBC_DIR=$(ls -d glibc-*/ | head -n1)
cd "$GLIBC_DIR" || exit 1

# Create LSB compatibility symlinks
case $(uname -m) in
    i?86)
        ln -sfv ld-linux.so.2 "$LFS/lib/ld-lsb.so.3"
        ;;
    x86_64)
        ln -sfv ../lib/ld-linux-x86-64.so.2 "$LFS/lib64"
        ln -sfv ../lib/ld-linux-x86-64.so.2 "$LFS/lib64/ld-lsb-x86-64.so.3"
        ;;
esac

# Apply patch for FHS compliance
patch -Np1 -i ../glibc-2.41-fhs-1.patch || exit 1

# Create and enter build directory
mkdir -v build
cd build || exit 1

# Create configparms file
echo "rootsbindir=/usr/sbin" > configparms

# Configure
../configure \
    --prefix=/usr \
    --host="$LFS_TGT" \
    --build="$(../scripts/config.guess)" \
    --enable-kernel=4.19 \
    --with-headers="$LFS/usr/include" \
    --disable-nscd \
    libc_cv_slibdir=/usr/lib || exit 1

# Compile
make || exit 1

# Install
make DESTDIR="$LFS" install || exit 1

# Fix ldd script
sed '/RTLDLIST=/s@/usr@@g' -i "$LFS/usr/bin/ldd"

# Integrity check
echo 'int main(){}' | "$LFS_TGT-gcc" -xc -o a.out
readelf -l a.out | grep ld-linux
rm -v a.out

echo "Glibc 编译和安装完成"
