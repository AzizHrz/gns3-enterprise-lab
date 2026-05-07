#!/usr/bin/env bash
# ==============================================================
# build-vpcs.sh
# Build VPCS from source for Debian 13
#
# Why: apt vpcs version (0.5b2) causes GNS3 3.0.6 error:
#      "VPCS executable version must be >= 0.6.1 but not a 0.8"
# Fix: Build from source → gets version 0.8.3 with correct
#      version string that GNS3 can parse properly.
#
# Usage: chmod +x build-vpcs.sh && ./build-vpcs.sh
# ==============================================================

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Remove apt version if present
if dpkg -l vpcs &>/dev/null 2>&1; then
    log_warn "Removing apt-installed vpcs (old version)"
    sudo apt remove vpcs -y
fi

# Install build dependencies
sudo apt install -y build-essential libpcap-dev git

# Clone and build
log_info "Cloning VPCS repository..."
cd /tmp
rm -rf vpcs
git clone https://github.com/GNS3/vpcs.git
cd vpcs/src

log_info "Building VPCS with Makefile.linux..."
make -f Makefile.linux

# Install
log_info "Installing to /usr/local/bin/vpcs..."
sudo cp vpcs /usr/local/bin/vpcs
sudo chmod +x /usr/local/bin/vpcs

# Verify
VERSION=$(vpcs --version 2>&1 | grep -i version | head -1)
log_info "VPCS installed: $VERSION"

# Remind user to update GNS3 preferences
echo ""
echo "Next: In GNS3 GUI → Edit → Preferences → VPCS"
echo "      Set path to: /usr/local/bin/vpcs"
