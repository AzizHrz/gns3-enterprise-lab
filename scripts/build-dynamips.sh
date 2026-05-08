#!/usr/bin/env bash
# ==============================================================
# build-dynamips.sh
# Build Dynamips from source for Debian 13.4 (Trixie)
#
# Why: On Debian 13, dynamips is still available via apt
#      (version 0.2.14) and works fine. This script is a
#      fallback in case the apt version breaks or is removed
#      in a future Debian release.
#
# What is Dynamips:
#   Dynamips is a Cisco router emulator. It allows GNS3 to run
#   real Cisco IOS images for platforms like c7200, c3725, c3640.
#   It also powers GNS3's built-in Ethernet switch node.
#
# Usage:
#   chmod +x build-dynamips.sh
#   ./build-dynamips.sh
#
# Verified on: Debian 13.4 | GNS3 3.0.6 | Dynamips 0.2.21
# ==============================================================

set -e  # exit on any error

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "\n${BLUE}=== $1 ===${NC}"; }

# --------------------------------------------------------------
log_step "Step 1: Check if apt dynamips already works"
# --------------------------------------------------------------

if command -v dynamips &>/dev/null; then
    VERSION=$(dynamips --version 2>&1 | head -1)
    log_info "dynamips already installed: $VERSION"
    read -p "Build from source anyway to get latest version? [y/N] " REPLY
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        log_info "Keeping existing dynamips. Exiting."
        exit 0
    fi
fi

# --------------------------------------------------------------
log_step "Step 2: Install build dependencies"
# --------------------------------------------------------------

log_info "Installing cmake, libelf-dev, libpcap-dev, build-essential..."

sudo apt update
sudo apt install -y \
    build-essential \
    cmake \
    libelf-dev \
    libpcap-dev \
    git \
    uuid-dev

log_info "Build dependencies installed"

# --------------------------------------------------------------
log_step "Step 3: Clone Dynamips repository"
# --------------------------------------------------------------

BUILD_DIR="/tmp/dynamips-build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

log_info "Cloning GNS3/dynamips from GitHub..."
git clone https://github.com/GNS3/dynamips.git
cd dynamips

log_info "Repository cloned. Latest commit:"
git log --oneline -1

# --------------------------------------------------------------
log_step "Step 4: Build with CMake"
# --------------------------------------------------------------

mkdir -p build
cd build

log_info "Running cmake..."
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DDYNAMIPS_CODE=stable

log_info "Running make..."
make -j$(nproc)   # use all CPU cores for faster build

log_info "Build complete"

# --------------------------------------------------------------
log_step "Step 5: Install"
# --------------------------------------------------------------

# Remove apt version first if present to avoid conflicts
if dpkg -l dynamips &>/dev/null 2>&1; then
    log_warn "Removing apt-installed dynamips to avoid conflict..."
    sudo apt remove dynamips -y
fi

sudo make install

# --------------------------------------------------------------
log_step "Step 6: Verify"
# --------------------------------------------------------------

INSTALLED=$(which dynamips)
VERSION=$(dynamips --version 2>&1 | head -1)

log_info "Installed at: $INSTALLED"
log_info "Version: $VERSION"

# Verify GNS3 can find it
echo ""
echo "Checking GNS3 preferences path..."
if grep -q "dynamips_path" ~/.config/GNS3/3.0/gns3_server.conf 2>/dev/null; then
    CONF_PATH=$(grep "dynamips_path" ~/.config/GNS3/3.0/gns3_server.conf | cut -d= -f2 | xargs)
    log_info "GNS3 config points to: $CONF_PATH"
    if [ "$CONF_PATH" != "$INSTALLED" ]; then
        log_warn "Path mismatch! Updating gns3_server.conf..."
        sed -i "s|dynamips_path.*|dynamips_path = $INSTALLED|" \
            ~/.config/GNS3/3.0/gns3_server.conf
        log_info "Updated to: $INSTALLED"
    fi
else
    log_warn "No dynamips_path in gns3_server.conf"
    log_warn "In GNS3 GUI: Edit → Preferences → Dynamips → set path to: $INSTALLED"
fi

# --------------------------------------------------------------
log_step "Done!"
# --------------------------------------------------------------

echo ""
log_info "Dynamips successfully built and installed from source."
log_info "Version: $VERSION"
log_info "Path:    $INSTALLED"
echo ""
log_warn "Restart GNS3 for changes to take effect:"
echo "  pkill -f gns3; gns3"
