#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Check if running with root privileges
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}This script needs to be run with root privileges${NC}"
    exit 1
fi

# Display available disks
echo -e "${GREEN}Available disks:${NC}"
lsblk
echo

# Get user input
read -p "Enter the disk device for LFS (e.g., /dev/sda): " DISK
read -p "Enter partition size (e.g., 20G): " SIZE
read -p "Enter partition number (e.g., 1): " PARTITION_NUMBER

# Create partition
echo -e "${GREEN}Creating new partition...${NC}"
parted $DISK --script mklabel gpt
parted $DISK --script mkpart primary ext4 0% $SIZE

# Get new partition device name
PARTITION="${DISK}${PARTITION_NUMBER}"

# Format partition
echo -e "${GREEN}Formatting partition...${NC}"
mkfs.ext4 $PARTITION

# Create mount point
echo -e "${GREEN}Creating mount point...${NC}"
export LFS=/mnt/lfs
mkdir -pv $LFS

# Mount partition
echo -e "${GREEN}Mounting partition...${NC}"
mount $PARTITION $LFS

# Set LFS environment variable
echo -e "${GREEN}Setting LFS environment variable...${NC}"

# Add LFS environment variable for current user
USER_HOME=$(eval echo ~$SUDO_USER)
echo "export LFS=/mnt/lfs" >> $USER_HOME/.bashrc
echo "export LFS=/mnt/lfs" >> $USER_HOME/.bash_profile

# Set environment variable immediately
export LFS=/mnt/lfs

echo -e "${GREEN}Done!${NC}"
echo -e "${GREEN}LFS partition has been created and mounted at $LFS${NC}"
echo -e "${GREEN}Environment variables have been set, please run 'source ~/.bashrc' to apply${NC}"

# Display partition information
df -h $LFS
