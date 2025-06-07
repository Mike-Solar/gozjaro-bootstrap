#!/bin/bash


export LFS=/mnt/lfs

# Add a user for LFS
groupadd lfs
useradd -s /bin/bash -g lfs -m -k /dev/null lfs

# Set password for the LFS user
echo "Please set a password for the LFS user:"
passwd lfs

# Set permissions for the LFS directories
chown -R -v lfs $LFS/{usr{,/*},lib,var{,/*},etc,bin,sbin,tools}
case $(uname -m) in
  x86_64) chown -v lfs $LFS/lib64 ;;
esac

# Switch to the LFS user
su - lfs
