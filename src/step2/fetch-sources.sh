#!/bin/bash
# LFS Source Fetch Script
# You need to install the `parallel` package to run this script.
# This script downloads the source packages for Linux From Scratch (LFS) using wget and parallel.
# # Debian/Ubuntu:
# sudo apt-get install parallel wget
# # Fedora:
# sudo dnf install parallel wget
# # Arch Linux:
# sudo pacman -S parallel wget

# Check if the script is run as root
if [ "$(id -u)" != "0" ]; then
    echo -e "\033[0;31m This script requires root privileges. Please run as root or use sudo. \033[0m"
    exit 1
fi
# Set color variables for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if wget and parallel are installed
if ! command -v wget &> /dev/null || ! command -v parallel &> /dev/null; then
    echo -e "${RED}Please install wget and parallel.${NC}"
    echo -e "On Debian/Ubuntu you can use: sudo apt-get install parallel wget"
    echo -e "On Fedora you can use: sudo dnf install parallel wget"
    echo -e "On Arch Linux you can use: sudo pacman -S parallel wget"
    exit 1
fi
# Set LFS mount point
export LFS="/mnt/lfs"
# Create necessary directories
SOURCES_DIR="$LFS/sources"

if [ ! -d "$SOURCES_DIR" ]; then
    echo -e "${GREEN}Creating LFS source directory: $SOURCES_DIR${NC}"
else
    echo -e "${GREEN}LFS source directory already exists: $SOURCES_DIR${NC}"
fi

mkdir -p "$SOURCES_DIR"
cd "$SOURCES_DIR" || exit 1

# Set permissions for the sources directory
chmod -v a+wt "$SOURCES_DIR"

echo -e "${GREEN}Downloading LFS package list...${NC}"

# Download the file containing all source package links
wget -q https://www.linuxfromscratch.org/lfs/view/stable/wget-list-sysv

if [ ! -f wget-list-sysv ]; then
    echo -e "${RED}Failed to download package list${NC}"
    exit 1
fi

# Count the total number of files to download
TOTAL_FILES=$(wc -l < wget-list-sysv)
CURRENT_FILE=0

echo -e "${GREEN}Starting to download $TOTAL_FILES source packages...${NC}"

# Set maximum retry count and parallel download count
MAX_RETRIES=3
PARALLEL_DOWNLOADS=4

# Create temporary directory for failed downloads
FAILED_DIR="$SOURCES_DIR/failed"
mkdir -p "$FAILED_DIR"

# Download all source packages
download_package() {
    local package=$1
    local filename=${package##*/}
    local start_time=$(date +%s)

    echo -e "${GREEN}Starting download: $filename${NC}"
    
    for ((try=1; try<=MAX_RETRIES; try++)); do
        if wget --continue --progress=bar:force:noscroll \
                --tries=3 --timeout=15 \
                -q --show-progress "$package" 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            echo -e "${GREEN}✓ Successfully downloaded: $filename (Time taken: ${duration}s)${NC}"
            return 0
        else
            echo -e "${RED}Failed to download (Attempt $try): $filename${NC}"
            sleep 2
        fi
    done
    
    echo "$package" >> "$FAILED_DIR/failed_downloads.txt"
    return 1
}

# Export the download function and variables for parallel execution
export -f download_package
export GREEN RED NC FAILED_DIR MAX_RETRIES

echo -e "${GREEN}Using $PARALLEL_DOWNLOADS parallel download processes${NC}"

# 使用 parallel 进行并行下载
cat wget-list-sysv | parallel -j $PARALLEL_DOWNLOADS download_package

# 检查是否有失败的下载
if [ -f "$FAILED_DIR/failed_downloads.txt" ]; then
    echo -e "${RED}Failed downloads:${NC}"
    cat "$FAILED_DIR/failed_downloads.txt"
    echo -e "${GREEN}Please manually retry downloading these files${NC}"
fi

echo -e "${GREEN}Download complete!${NC}"
echo -e "${GREEN}All files have been saved to: $SOURCES_DIR${NC}"

# Download md5sums file for verification
wget -q https://www.linuxfromscratch.org/lfs/view/stable/md5sums

if [ -f md5sums ]; then
    echo -e "${GREEN}Verifying downloaded files...${NC}"
    md5sum -c md5sums
else
    echo -e "${RED}Warning: Failed to download md5sums file, skipping integrity check${NC}"
fi
