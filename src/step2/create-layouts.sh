#!/bin/bash

# Define the LFS mount point
export LFS=/mnt/lfs

# Create basic system directories
mkdir -pv $LFS/{etc,var} $LFS/usr/{bin,lib,sbin}

# Create additional essential directories
mkdir -pv $LFS/usr/{include,libexec,share,src}
mkdir -pv $LFS/usr/share/{doc,info,locale,man}
mkdir -pv $LFS/usr/share/{misc,terminfo,zoneinfo}
mkdir -pv $LFS/var/{cache,lib,local,log,mail,opt,spool}
mkdir -pv $LFS/var/lib/{color,misc,locate,tmp}

# Create symlinks for root-level directories
for i in bin lib sbin; do
    ln -sv usr/$i $LFS/$i
done

# Create lib64 directory for x86_64 systems
case $(uname -m) in
    x86_64) mkdir -pv $LFS/lib64 ;;
esac

# Create tools directory for temporary toolchain
mkdir -pv $LFS/tools

# Set proper permissions for var directory
chmod -v 1777 $LFS/var/tmp

# Add optional but commonly used directories
mkdir -pv $LFS/{boot,home,mnt,opt,srv}
mkdir -pv $LFS/etc/{opt,sysconfig}
mkdir -pv $LFS/media/{floppy,cdrom}
mkdir -pv $LFS/usr/local/{bin,include,lib,sbin,share,src}
