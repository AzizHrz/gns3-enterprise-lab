# 🔧 Troubleshooting Log

> This document records every error encountered during GNS3 installation and setup on Debian 13.4,  
> with exact error messages, root cause analysis, and confirmed fixes.

---

## Error Index

| # | Error | Cause | Status |
|---|---|---|---|
| [T1](#t1) | `VPCS executable version must be >= 0.6.1 but not a 0.8` | GNS3 version parser bug + wrong VPCS binary | ✅ Fixed |
| [T2](#t2) | `"local":false` in API response | Missing config file, server started without `--local` flag | ✅ Fixed |
| [T3](#t3) | `HTTP 405 Method Not Allowed` on node start | JWT secret not configured + local:false | ✅ Fixed |
| [T4](#t4) | `A JWT secret key must be configured` (repeated ERROR) | No `gns3_server.conf` existed | ✅ Fixed |
| [T5](#t5) | `make: No targets specified and no makefile found` | Wrong `make` command (no platform flag) | ✅ Fixed |
| [T6](#t6) | `pip3 install` vs `pipx install` conflict | Two different install methods used simultaneously | ✅ Fixed |
| [T7](#t7) | `Another GNS3 GUI is already running. Continue?` | Old GNS3 process not killed before relaunch | ✅ Fixed |

---

## T1 — VPCS Version Mismatch {#t1}

### Error message

```
error while starting PC1: VPCS executable version must be >= 0.6.1 but not a 0.8
VPCS executable version must be >= 0.6.1 but not a 0.8
```

Visible in:
- GNS3 GUI top-right red banner
- GNS3 console panel (bottom)
- Terminal log output

📸 *Screenshot: `docs/screenshots/troubleshooting/T1-vpcs-version-error-gui.png`*  
📸 *Screenshot: `docs/screenshots/troubleshooting/T1-vpcs-version-error-terminal.png`*

### What was happening

The apt-installed `vpcs` was version `0.5b2`:
```bash
$ which vpcs
/usr/bin/vpcs
$ vpcs -v
Welcome to Virtual PC Simulator, version 0.5b2
Build time: Sep 6 2020 19:00:57
```

GNS3 3.0.6 has a version comparison bug: it parses `0.8` (from the source-built `0.8.3`) correctly — but the apt version `0.5b2` was also a problem because it is genuinely older than `0.6.1`. The error message is confusing because it says "not a 0.8" — this means it found version `0.8` somewhere but rejected it, which is actually the **correct newer version** that GNS3's parser handles incorrectly.

### Root cause

GNS3 3.0.6 uses a version comparison that fails to properly parse `0.8` (interprets it as `0.8.0` which sorts less than `0.6.1` in some parsing implementations). The fix is to build VPCS from source which produces version `0.8.3` — the full three-part version string parses correctly.

### Fix — Build VPCS from source

```bash
# 1. Remove apt version
sudo apt remove vpcs -y

# 2. Verify removed
which vpcs   # must return nothing

# 3. Clone and build
git clone https://github.com/GNS3/vpcs.git
cd vpcs/src
make -f Makefile.linux   # IMPORTANT: must use -f Makefile.linux

# 4. Install
sudo cp vpcs /usr/local/bin/vpcs
sudo chmod +x /usr/local/bin/vpcs

# 5. Verify
vpcs --version
```

**Expected after fix:**
```
Welcome to Virtual PC Simulator, version 0.8.3
Dedicated to Daling.
Build time: Apr 24 2026 12:42:24
```

📸 *Screenshot: `docs/screenshots/troubleshooting/T1-vpcs-083-fixed.png`*

### Update GNS3 to use new binary

In GNS3 GUI: **Edit → Preferences → VPCS** → set path to `/usr/local/bin/vpcs`

### Confirmation

After fix, PC1 and PC2 start successfully — green indicators in topology, telnet console accessible:

```
PC1   telnet localhost:5000
PC2   telnet localhost:5002
```

📸 *Screenshot: `docs/screenshots/troubleshooting/T1-nodes-green-after-fix.png`*

---

## T2 — `"local":false` in API Response {#t2}

### Error symptom

```bash
$ curl http://localhost:3080/v3/version
{"controller_host":"127.0.0.1","version":"3.0.6","local":false}
```

📸 *Screenshot: `docs/screenshots/troubleshooting/T2-local-false.png`*

### What this means

In GNS3 3.0, `local:true` means the controller and compute backend run in the **same process on the same machine** — the correct mode for a standalone workstation. When `local:false`, the controller thinks the compute is remote, and certain API routes (especially `/nodes/{id}/start`) behave differently, causing 405 errors.

### Root cause

The server was started **manually** via `gns3server` in a terminal, without the `--local` flag. Additionally, no `gns3_server.conf` existed, so the server couldn't read `local = true` from config.

The log confirmed this:
```
2026-04-24 01:21:28 WARNING gns3server.config:250 No configuration file could be found or read
```

### Fix

```bash
# Step 1: Kill all GNS3 processes
pkill -f gns3server
pkill -f gns3
sleep 3
ps aux | grep gns3   # confirm clean

# Step 2: Create config file
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
EOF

# Step 3: Launch ONLY via GUI (do not run gns3server manually)
gns3
```

### Confirmation

```bash
$ curl http://localhost:3080/v3/version
{"controller_host":"127.0.0.1","version":"3.0.6","local":true}
```

📸 *Screenshot: `docs/screenshots/troubleshooting/T2-local-true-fixed.png`*

Also confirmed via `ps aux`:
```
gns3server --local --logfile=...gns3_server.log --pid=...gns3_server.pid
```
The `--local` flag is now passed automatically by the GUI.

---

## T3 — HTTP 405 Method Not Allowed on Node Start {#t3}

### Error message

```
Error transferring http://localhost:3080/v3/projects/.../nodes/.../start
- server replied: Method Not Allowed (HTTP code 405)
```

### Root cause

Two combined causes:
1. **`local:false`** — controller routing start requests to wrong endpoint (see T2)
2. **No JWT secret** — authentication failing intermittently, causing certain API methods to be rejected

### Fix

Fixing T2 (config file with `local=true` and JWT key) also resolves T3. After creating the config and relaunching via GUI only, the 405 error disappears.

---

## T4 — JWT Secret Key Error (Repeated) {#t4}

### Error message

```
ERROR gns3server.services.authentication:58 A JWT secret key must be configured 
to secure the server, using an unsecured default key!
```

This appeared **repeatedly** in the server log — every API call triggered it.

📸 *Screenshot: `docs/screenshots/troubleshooting/T4-jwt-error-log.png`*

### Root cause

No `gns3_server.conf` file existed. GNS3 3.0 requires a `jwt_secret_key` in the config for secure token signing. Without it, it falls back to a hardcoded insecure default key and logs this error on every authenticated request.

### Fix

The `setup-gns3-config.sh` script in this repo (or manual step in INSTALLATION.md Step 8) creates the config with a proper randomly generated 64-character hex key.

```bash
SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
# Results in something like:
# a3f8e2c1d4b7f9e0a1c3d5e7f2b4d6e8a0c2e4f6b8d0f2a4c6e8b0d2f4a6c8e0
```

---

## T5 — `make: No targets specified and no makefile found` {#t5}

### Error message

```bash
$ cd vpcs/src
$ make
make: *** No targets specified and no makefile found.  Stop.
```

📸 *Screenshot: `docs/screenshots/troubleshooting/T5-make-error.png`*

### Root cause

The VPCS source directory contains **platform-specific Makefiles** only — there is no generic `Makefile`:

```
Makefile.cygwin   (Windows/Cygwin)
Makefile.fbsd     (FreeBSD)
Makefile.linux    (Linux) ← this is what we need
Makefile.obsd     (OpenBSD)
Makefile.osx      (macOS)
mk.sh             (shell script wrapper)
```

Running bare `make` looks for a file literally named `Makefile` or `makefile` — finds none — fails.

### Fix

```bash
make -f Makefile.linux
```

The `-f` flag explicitly specifies which makefile to use.

📸 *Screenshot: `docs/screenshots/troubleshooting/T5-make-linux-success.png`*

---

## T6 — pip3 vs pipx Install Conflict {#t6}

### What happened

During initial setup, GNS3 was installed **twice** using different methods:

```bash
# Method 1 (wrong — done first)
pip3 install gns3-server gns3-gui --break-system-packages
# Installs into: ~/.local/lib/python3.13/site-packages/

# Method 2 (correct — done later)
pipx install gns3-server
pipx install gns3-gui
# Installs into: ~/.local/share/pipx/venvs/gns3-server/
#                ~/.local/share/pipx/venvs/gns3-gui/
```

📸 *Screenshot: `docs/screenshots/troubleshooting/T6-pip-wrong-install.png`*

### Why this causes problems

- pip installs GNS3 into the user site-packages alongside system PyQt5
- pipx installs into isolated venvs with their own PyQt6
- The GUI might load from one location and the server from another
- Version mismatches become possible if pip and pipx installed different versions

### Fix

```bash
# Remove pip-installed versions
pip3 uninstall gns3-server gns3-gui -y --break-system-packages

# Verify gone
pip3 list | grep gns3   # must return nothing

# Keep only the pipx versions
pipx list   # should show gns3-server 3.0.6 and gns3-gui 3.0.6
```

**Rule going forward**: GNS3 on Debian 13 is managed **exclusively via pipx**. Never use pip3 for GNS3.

---

## T7 — "Another GNS3 GUI is Already Running" {#t7}

### Warning message

```
WARNING main window.py:1258 Another GNS3 GUI is already running. Continue?
```

📸 *Screenshot: `docs/screenshots/troubleshooting/T7-duplicate-gui-warning.png`*

### Cause

Attempting to launch `gns3` while a previous instance is still running (or its PID file was not cleaned up after a crash/kill).

### Fix

```bash
pkill -f gns3server
pkill -f gns3
sleep 2
ps aux | grep gns3   # confirm clean — only grep line should appear
gns3                 # fresh launch
```

---

## General Debugging Commands

```bash
# Check what's running
ps aux | grep gns3

# Check server status
curl http://localhost:3080/v3/version

# Check server log
tail -f ~/.config/GNS3/3.0/gns3_server.log

# Check VPCS binary
which vpcs
vpcs --version
/usr/local/bin/vpcs --version

# Check ubridge capabilities
getcap /usr/local/bin/ubridge
# Expected: /usr/local/bin/ubridge cap_net_admin,cap_net_raw=ep

# Check groups (libvirt, kvm, wireshark required)
groups $USER

# Run GNS3 Doctor (inside GNS3 GUI)
# Help → GNS3 Doctor
```

---

*→ Back to: [Installation Guide](INSTALLATION.md)*  
*→ Next: [TP Multi-site Lab](TP_MULTISITE.md)*
