#!/bin/bash

# To configure a good working environment, we will create two new startup scripts for bash.
# As user lfs, execute the following commands to create a new .bash_profile:

# Create a new .bash_profile
cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

# Create a new .bashrc
cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-gozjaro-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
EOF

# Append to the .bashrc
cat >> ~/.bashrc << "EOF"
export MAKEFLAGS=-j$(nproc)
EOF

# Source the new .bash_profile to apply changes
source ~/.bash_profile



