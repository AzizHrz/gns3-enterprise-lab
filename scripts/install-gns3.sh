#!/usr/bin/env bash
# ==============================================================
# install-gns3.sh
# Automated GNS3 3.x installation for Debian 13.4 (Trixie)
# 
# Usage: chmod +x install-gns3.sh && ./install-gns3.sh
# ==============================================================

set -e  # Exit on any error

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "\n${BLUE}=== $1 ===${NC}"; }

# --------------------------------------------------------------
log_step "Step 1: Verify KVM support"
# --------------------------------------------------------------

KVM_COUNT=$(egrep -c '(vmx|svm)' /proc/cpuinfo || true)
if [ "$KVM_COUNT" -eq 0 ]; then
    log_error "KVM not supported. Enable VT-x in BIOS (HP ZBook: F10 at POST)"
    exit 1
fi
log_info "KVM supported: $KVM_COUNT logical CPUs with virtualisation"

if ! command -v kvm-ok &>/dev/null; then
    sudo apt install -y cpu-checker
fi
sudo kvm-ok || { log_error "KVM acceleration not available"; exit 1; }

# --------------------------------------------------------------
log_step "Step 2: Update system"
# --------------------------------------------------------------

sudo apt update && sudo apt full-upgrade -y

# --------------------------------------------------------------
log_step "Step 3: Install system dependencies"
# --------------------------------------------------------------

sudo apt install -y \
    python3 python3-pip pipx \
    python3-pyqt6 python3-pyqt6.qtwebsockets python3-pyqt6.qtsvg \
    qemu-kvm qemu-utils qemu-system-x86 \
    libvirt-daemon-system libvirt-clients virtinst \
    bridge-utils \
    ca-certificates curl gnupg2 \
    git build-essential libpcap-dev \
    net-tools iproute2 iptables \
    wireshark telnet

log_info "System dependencies installed"

# --------------------------------------------------------------
log_step "Step 4: Add user to required groups"
# --------------------------------------------------------------

sudo usermod -aG libvirt,kvm,wireshark "$USER"
log_info "User $USER added to libvirt, kvm, wireshark groups"
log_warn "You must log out and back in for group changes to take full effect"
log_warn "Or run: newgrp libvirt"

# --------------------------------------------------------------
log_step "Step 5: Install dynamips"
# --------------------------------------------------------------

if ! command -v dynamips &>/dev/null; then
    sudo apt install -y dynamips 2>/dev/null || {
        log_warn "dynamips not in apt — building from source"
        sudo apt install -y cmake libelf-dev
        cd /tmp
        git clone https://github.com/GNS3/dynamips.git
        cd dynamips && mkdir build && cd build
        cmake ..
        sudo make install
        cd ~
    }
fi
log_info "Dynamips: $(dynamips --version 2>&1 | head -1)"

# --------------------------------------------------------------
log_step "Step 6: Install GNS3 via pipx"
# --------------------------------------------------------------

# Remove any pip-installed versions first
pip3 uninstall gns3-server gns3-gui -y 2>/dev/null || true

pipx install gns3-server
pipx install gns3-gui
pipx inject gns3-gui gns3-server PyQt6

log_info "GNS3 installed via pipx"
pipx list | grep gns3

# --------------------------------------------------------------
log_step "Step 7: Configure GNS3 server"
# --------------------------------------------------------------

bash "$(dirname "$0")/setup-gns3-config.sh"

# --------------------------------------------------------------
log_step "Step 8: Build ubridge from source"
# --------------------------------------------------------------

cd /tmp
git clone https://github.com/GNS3/ubridge.git
cd ubridge
make
sudo make install
log_info "ubridge: $(ubridge -v)"

# --------------------------------------------------------------
log_step "Step 9: Build VPCS from source"
# --------------------------------------------------------------

bash "$(dirname "$0")/build-vpcs.sh"

# --------------------------------------------------------------
log_step "Installation Complete!"
# --------------------------------------------------------------

echo ""
log_info "Verification:"
echo "  ubridge:   $(ubridge -v)"
echo "  vpcs:      $(vpcs --version 2>&1 | grep version | head -1)"
echo "  dynamips:  $(dynamips --version 2>&1 | head -1)"
echo "  gns3:      $(pipx list | grep gns3-gui)"
echo ""
log_info "Launch GNS3 with: gns3"
log_warn "Remember to run 'newgrp libvirt' or re-login before first launch"
