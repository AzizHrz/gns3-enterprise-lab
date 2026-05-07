# 📦 GNS3 Installation Guide — Debian 13.4 (Trixie)

> This guide documents the **exact installation process** performed on the HP ZBook G9.  
> Every command is verified against real output. Screenshots are referenced at each step.

---

## Prerequisites

| Requirement | Value | Status |
|---|---|---|
| OS | Debian 13.4 (Trixie) | ✅ |
| CPU | Intel Core i7-13th Gen | ✅ |
| RAM | 32 GB | ✅ |
| Disk | 512 GB SSD (Debian disk) | ✅ |
| VT-x / VT-d | Enabled in BIOS | ✅ |

---

## Step 1 — Verify KVM / Hardware Virtualisation

Before installing anything, confirm KVM acceleration is available.

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
sudo kvm-ok
```

**Expected output:**
```
40
INFO: /dev/kvm exists
KVM acceleration can be used
```

> The value `40` means 40 logical CPU threads support virtualisation — this is your i7-13th gen with hyperthreading across all cores.

📸 *Screenshot: `docs/screenshots/setup/01-kvm-check.png`*

> **If VT-x is not found**: Reboot → press **F10** (HP ZBook BIOS) → Advanced → CPU Configuration → Intel Virtualization Technology → **Enable** → Save & Exit.

---

## Step 2 — Install System Dependencies

### 2a — Core build tools and libraries

```bash
sudo apt install -y git build-essential libpcap-dev
```

📸 *Screenshot: `docs/screenshots/setup/02-build-deps.png`*

### 2b — Full dependency set (KVM, libvirt, Wireshark, PyQt5, networking tools)

```bash
sudo apt install -y \
  qemu-kvm qemu-utils \
  libvirt-daemon-system libvirt-clients \
  bridge-utils virt-manager \
  cpu-checker \
  dynamips vpcs \
  wireshark \
  python3 python3-pip \
  python3-pyqt5 python3-pyqt5.qtsvg python3-pyqt5.qtwebsockets \
  net-tools iproute2 iptables telnet curl git
```

📸 *Screenshot: `docs/screenshots/setup/03-apt-install.png`*

> **Note on Debian 13**: `dynamips` and `vpcs` are available via apt on Debian 13, but the apt `vpcs` version (0.5b2) will later cause a version mismatch error. We build VPCS from source in Step 5 to fix this.

### 2c — PyQt6 + pipx (required for official install method)

```bash
sudo apt install -y \
  python3 python3-pip pipx \
  python3-pyqt6 python3-pyqt6.qtwebsockets python3-pyqt6.qtsvg \
  qemu-kvm qemu-utils \
  libvirt-clients libvirt-daemon-system virtinst \
  ca-certificates curl gnupg2
```

📸 *Screenshot: `docs/screenshots/setup/04-pyqt6-install.png`*

---

## Step 3 — Add User to Required Groups

```bash
sudo usermod -aG libvirt,kvm,wireshark $USER
newgrp libvirt
```

📸 *Screenshot: `docs/screenshots/setup/05-usermod-groups.png`*

> You must log out and back in (or use `newgrp`) for group membership to take effect. Without `libvirt` group membership, GNS3 cannot manage QEMU VMs.

---

## Step 4 — Build and Install ubridge

ubridge is the network bridge utility that connects GNS3 virtual nodes. It must be built from source and given network capabilities.

```bash
git clone https://github.com/GNS3/ubridge.git
cd ubridge
make
sudo make install
```

**Expected install output:**
```
chmod +x ubridge
cp -p ubridge /usr/local/bin
setcap cap_net_admin,cap_net_raw=ep /usr/local/bin/ubridge
```

Verify:
```bash
ubridge -v
```
```
ubridge version 0.9.19
```

📸 *Screenshots: `docs/screenshots/setup/06-ubridge-build.png`, `07-ubridge-install.png`*

> **Important**: The `setcap` line is critical — it grants ubridge the ability to create network interfaces and capture raw packets without running as root.

---

## Step 5 — Build VPCS from Source

> **Why from source?** The apt package provides VPCS 0.5b2. GNS3 3.0.6 checks the version string and rejects anything that doesn't parse as `>= 0.6.1`. VPCS 0.8.3 (from source) has a properly formatted version string that passes the check.

```bash
cd ~
git clone https://github.com/GNS3/vpcs.git
cd vpcs/src
make -f Makefile.linux
```

**Expected output** — GCC compiles all source files:
```
gcc  -DLinux -Dx86_64 -DHV -Wall -DTAP -c vpcs.c
gcc  -DLinux -Dx86_64 -DHV -Wall -DTAP -c daemon.c
...
gcc  vpcs.o daemon.o readline.o packets.o utils.o queue.o command.o \
     dev.o dhcp.o ip.o tcp.o inet6.o dns.o remote.o help.o dump.o \
     relay.o hv.o frag.o frag6.o -o vpcs -lpthread -lutil
```

Install:
```bash
sudo cp vpcs /usr/local/bin/vpcs
sudo chmod +x /usr/local/bin/vpcs
vpcs --version
```

**Expected:**
```
Welcome to Virtual PC Simulator, version 0.8.3
Dedicated to Daling.
Build time: Apr 24 2026 12:42:24
```

📸 *Screenshots: `docs/screenshots/setup/08-vpcs-build.png`, `09-vpcs-version.png`*

---

## Step 6 — Install Dynamips

### Option A: From apt (worked on this system)

```bash
sudo apt install -y dynamips
dynamips --version
```

**Expected:**
```
Cisco Router Simulation Platform (version 0.2.14-amd64/Linux stable)
Copyright (c) 2005-2011 Christophe Fillot.
Build date: Apr 26 2024 21:50:16
```

📸 *Screenshot: `docs/screenshots/setup/10-dynamips-version.png`*

### Option B: From source (if apt version fails)

```bash
sudo apt install -y cmake libelf-dev libpcap0.8-dev
git clone https://github.com/GNS3/dynamips.git
cd dynamips && mkdir build && cd build
cmake ..
sudo make install
```

---

## Step 7 — Install GNS3 via pipx (Official Method)

> **Do NOT use `pip3 install`** — the pipx method creates isolated virtual environments for each app, preventing PyQt5/PyQt6 conflicts.

```bash
pipx install gns3-server
pipx install gns3-gui
pipx inject gns3-gui gns3-server PyQt6
```

**Expected output:**
```
installed package gns3-server 3.0.6, installed using Python 3.13.5
  - gns3server
  - gns3vmnet
done! ✨ ⭐ ✨

installed package gns3-gui 3.0.6, installed using Python 3.13.5
  - gns3
done! ✨ ⭐ ✨

injected package pyqt6 into venv gns3-gui
injected package gns3-server into venv gns3-gui
done! ✨ ⭐ ✨
```

📸 *Screenshot: `docs/screenshots/setup/11-pipx-gns3-install.png`*

> **Version match is critical**: both `gns3-server` and `gns3-gui` must be the same version (3.0.6). Mismatched versions cause API 405 errors.

---

## Step 8 — Configure GNS3 Server

Create a proper config file with a secure JWT key. This prevents authentication errors and ensures `local=true` mode.

```bash
mkdir -p ~/.config/GNS3/3.0

SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")

cat > ~/.config/GNS3/3.0/gns3_server.conf << EOF
[Server]
host = 127.0.0.1
port = 3080
jwt_secret_key = ${SECRET}
local = true

[VPCS]
vpcs_path = /usr/local/bin/vpcs

[Dynamips]
dynamips_path = /usr/bin/dynamips

[QEMU]
enable_hardware_acceleration = true
require_hardware_acceleration = false
EOF

echo "Config written:"
cat ~/.config/GNS3/3.0/gns3_server.conf
```

---

## Step 9 — Set VPCS Path in GNS3 GUI

After launching GNS3 for the first time, the Setup Wizard appears:

1. **Server path**: `/home/primaryos/.local/bin/gns3server` (auto-detected)
2. **Host binding**: `localhost`
3. **Port**: `3080 TCP`
4. Click **Next**

📸 *Screenshot: `docs/screenshots/setup/12-setup-wizard.png`*

Then go to **Edit → Preferences → VPCS** and set:
```
/usr/local/bin/vpcs
```

---

## Step 10 — Launch and Verify

```bash
gns3
```

Verify in a second terminal:
```bash
curl http://localhost:3080/v3/version
```

**Expected:**
```json
{"controller_host":"127.0.0.1","version":"3.0.6","local":true}
```

📸 *Screenshot: `docs/screenshots/setup/13-local-true-confirmed.png`*

> `"local":true` confirms the controller and compute are running in the same process — this is the correct mode for a standalone workstation setup.

---

## Verification Checklist

```bash
# All of these must return valid output
ubridge -v          # ubridge version 0.9.19
vpcs --version      # version 0.8.3
dynamips --version  # version 0.2.14
pipx list           # gns3-server 3.0.6, gns3-gui 3.0.6
curl http://localhost:3080/v3/version  # local:true
```

---

*→ Next: [Troubleshooting Log](TROUBLESHOOTING.md)*  
*→ Then: [TP Multi-site Lab](TP_MULTISITE.md)*
