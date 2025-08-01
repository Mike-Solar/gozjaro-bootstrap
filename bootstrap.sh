#/bin/bash
# Prepare the environment
umask 022
sudo mkdir /mnt/lfs
export LFS=/mnt/lfs
sudo chown root:root $LFS
chmod 755 $LFS
sudo mkdir -v $LFS/sources
sudo chmod -v a+wt $LFS/sources
sudo chown root:root $LFS/sources/*
sudo mkdir -pv $LFS/{etc,var} $LFS/usr/{bin,lib,sbin}
for i in bin lib sbin; do
 sudo ln -sv usr/$i $LFS/$i
done
case $(uname -m) in
 x86_64) sudo mkdir -pv $LFS/lib64 ;;
esac
sudo mkdir -pv $LFS/tools
sudo set +h
sudo umask 022
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE

# Download the sources

wget https://mirrors.ustc.edu.cn/lfs/lfs-packages/12.3/binutils-2.44.tar.xz
wget https://mirrors.ustc.edu.cn/lfs/lfs-packages/12.3/gcc-14.2.0.tar.xz
wget https://mirrors.ustc.edu.cn/lfs/lfs-packages/12.3/mpfr-4.2.1.tar.xz
wget https://mirrors.ustc.edu.cn/lfs/lfs-packages/12.3/gmp-6.3.0.tar.xz
wget https://mirrors.ustc.edu.cn/lfs/lfs-packages/12.3/mpc-1.3.1.tar.gz
wget https://mirrors.ustc.edu.cn/lfs/lfs-packages/12.3/linux-6.13.4.tar.xz
wget https://mirrors.ustc.edu.cn/lfs/lfs-packages/12.3/glibc-2.41.tar.xz
wget https://mirrors.ustc.edu.cn/lfs/lfs-packages/12.3/glibc-2.41-fhs-1.patch
wget https://mirrors.ustc.edu.cn/lfs/lfs-packages/12.3/m4-1.4.19.tar.xz
wget https://mirrors.ustc.edu.cn/lfs/lfs-packages/12.3/ncurses-6.5.tar.gz
wget https://mirrors.ustc.edu.cn/lfs/lfs-packages/12.3/bash-5.2.37.tar.gz

# Build cross compiling toolchain

# Binutils
tar xvf binutils-2.44.tar.xz
cd binutils-2.44
mkdir build
cd build
../configure --prefix=$LFS/tools \
 --with-sysroot=$LFS \
 --target=$LFS_TGT \
 --disable-nls \
 --enable-gprofng=no \
 --disable-werror \
 --enable-new-dtags \
 --enable-default-hash-style=gnu
make -j8
make install
cd ../..
# GCC
tar xvf gcc-14.2.0.tar.xz
tar xvf mpfr-4.2.1.tar.xz
tar xvf gmp-6.3.0.tar.xz
tar xvf mpc-1.3.1.tar.gz

cp -r mpfr-4.2.1 gcc-14.2.0/mpfr
cp -r gmp-6.3.0 gcc-14.2.0/gmp
cp -r mpc-1.3.1 gcc-14.2.0/mpc

cd gcc-14.2.0

case $(uname -m) in
 x86_64)
 sed -e '/m64=/s/lib64/lib/' \
 -i.orig gcc/config/i386/t-linux64
 ;;
esac

mkdir -v build
cd build
../configure \
 --target=$LFS_TGT \
 --prefix=$LFS/tools \
 --with-glibc-version=2.41 \
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
make -j8
make install
