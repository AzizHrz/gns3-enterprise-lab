# 🌐 GNS3 Enterprise Network Lab
### Advanced Multi-Site Network Simulation on Debian 13.4

> **Hardware**: HP ZBook G9 · Intel Core i7-13th Gen · 32 GB RAM · 1 TB SSD (dual-disk) · NVIDIA RTX Ada 2000  
> **OS**: Debian 13.4 (Trixie) — dual boot with Windows 11  
> **GNS3**: v3.0.6 · Python 3.13.5 · Qt 6.11.0 · PyQt 6.11.0

---

## 📋 Table of Contents

1. [What is GNS3?](#what-is-gns3)
2. [Project Goals](#project-goals)
3. [Repository Structure](#repository-structure)
4. [Installation Guide](docs/INSTALLATION.md)
5. [Troubleshooting Log](docs/TROUBLESHOOTING.md)
6. [TP — Advanced Multi-Site Lab](docs/TP_MULTISITE.md)
7. [Configurations](configs/)
8. [Scripts](scripts/)
9. [IOS Images Guide](ios-images/README.md)
10. [Next Steps](#next-steps)

---

## What is GNS3?

**GNS3** (Graphical Network Simulator-3) is a free, open-source network simulation platform used by network engineers, students, and security professionals to design, test, and troubleshoot complex networks — without needing physical hardware.

### Key concepts

| Component | Role |
|---|---|
| **GNS3 GUI** | The graphical interface you interact with — drag nodes, draw links, open consoles |
| **GNS3 Server** | The backend engine that manages all node processes, handles API calls |
| **ubridge** | A bridge utility that connects virtual network interfaces — required for linking GNS3 nodes to each other and to the host |
| **Dynamips** | Cisco router emulator — runs real IOS images for routers like c7200, c3725 |
| **VPCS** | Virtual PC Simulator — lightweight fake "PC" nodes for quick ping/connectivity tests |
| **QEMU** | Full machine emulator used for FortiGate, Linux VMs, and any appliance needing a real OS |

### How GNS3 3.0 works (architecture)

```
┌─────────────────────────────────────────┐
│            GNS3 GUI (gns3)              │  ← You interact here
│         PyQt6 · Port 3080 API           │
└───────────────┬─────────────────────────┘
                │ HTTP/WebSocket
┌───────────────▼─────────────────────────┐
│         GNS3 Server (gns3server)        │  ← Controller + Compute (local mode)
│    Controller  ←→  Compute (local)      │
│         JWT Auth · SQLite DB            │
└──┬──────────┬──────────┬────────────────┘
   │          │          │
[VPCS]   [Dynamips]   [QEMU]           ← Node backends
[vpcs]   [dynamips]   [qemu-system-x86]
   │          │          │
[ubridge] ──────────────────────────── ← Network glue
```

> **Important for Debian 13**: GNS3 is NOT available via `apt`. It must be installed via `pipx`. This is because Debian 13 removed several GNS3 dependencies from its repositories.

---

## Project Goals

This lab implements a **real enterprise network scenario** covering:

- ✅ Multi-site topology (Headquarters + Branch office)
- ✅ VLAN segmentation (Admin VLAN 10, Tech VLAN 20)
- ✅ Inter-VLAN routing (Router-on-a-Stick)
- ✅ OSPF dynamic routing between sites
- ✅ NAT/PAT for internet access
- ✅ DHCP server with per-VLAN pools
- ✅ ACL security policies
- ✅ QoS traffic prioritization (VoIP)
- ✅ WAN failure simulation and analysis
- ✅ Wireshark packet capture and analysis
- 🔜 FortiGate firewall integration
- 🔜 Load balancer (HAProxy)
- 🔜 Cloud connectivity via IPsec VPN

---

## Repository Structure

```
gns3-enterprise-lab/
│
├── README.md                    ← You are here — main project overview
│
├── docs/
│   ├── INSTALLATION.md          ← Step-by-step GNS3 install on Debian 13.4
│   ├── TROUBLESHOOTING.md       ← All errors encountered + solutions (with screenshots)
│   ├── TP_MULTISITE.md          ← Full lab guide: VLAN, OSPF, NAT, QoS, ACL
│   └── screenshots/
│       ├── setup/               ← Installation process screenshots
│       ├── troubleshooting/     ← Error screenshots + fix evidence
│       └── topology/            ← GNS3 topology screenshots
│
├── configs/
│   ├── routers/
│   │   ├── R1-siege.cfg         ← HQ router full config
│   │   └── R2-agence.cfg        ← Branch router full config
│   ├── switches/
│   │   └── SW1-vlan.cfg         ← Switch VLAN config
│   └── firewall/
│       └── fortigate-basic.cfg  ← FortiGate bootstrap config
│
├── scripts/
│   ├── install-gns3.sh          ← Automated GNS3 install script for Debian 13
│   ├── build-vpcs.sh            ← Build VPCS from source
│   ├── build-dynamips.sh        ← Build Dynamips from source
│   └── setup-gns3-config.sh     ← Generate gns3_server.conf with JWT key
│
├── ios-images/
│   └── README.md                ← Where to get IOS images legally + QEMU image guide
│
└── topologies/
    └── tp-multisite.gns3        ← Exported GNS3 project topology file
```

---

## Current Status

| Phase | Status | Details |
|---|---|---|
| KVM verification | ✅ Done | 40 vCPU threads, KVM acceleration confirmed |
| ubridge build | ✅ Done | v0.9.19 from source, caps set |
| GNS3 install (pipx) | ✅ Done | v3.0.6 GUI + Server |
| Dynamips | ✅ Done | v0.2.14 from apt |
| VPCS build from source | ✅ Done | v0.8.3 — fixed version mismatch bug |
| GNS3 config (JWT + local) | ✅ Done | `local=true`, secret key set |
| First topology (PC1+PC2+Switch) | ✅ Done | Nodes start and run |
| TP Multi-site topology | 🔄 In Progress | VLAN, OSPF, NAT next |
| FortiGate integration | 🔜 Next | Requires QEMU image |
| Load balancer + cloud | 🔜 Planned | HAProxy + IPsec |

---

## Next Steps

1. **Get Cisco IOS image** for R1 and R2 — see [ios-images/README.md](ios-images/README.md)
2. **Build the TP topology** — follow [docs/TP_MULTISITE.md](docs/TP_MULTISITE.md)
3. **Configure VLAN + OSPF + NAT** — all configs in [configs/routers/](configs/routers/)
4. **Import FortiGate QEMU appliance** — requires free Fortinet eval account
5. **Run Wireshark captures** — OSPF hellos, DHCP DORA, NAT translation

---

## Quick Start (if starting fresh)

```bash
# 1. Clone this repo
git clone https://github.com/YOUR_USERNAME/gns3-enterprise-lab.git
cd gns3-enterprise-lab

# 2. Run install script
chmod +x scripts/install-gns3.sh
./scripts/install-gns3.sh

# 3. Build VPCS from source (required on Debian 13)
chmod +x scripts/build-vpcs.sh
./scripts/build-vpcs.sh

# 4. Setup GNS3 config
chmod +x scripts/setup-gns3-config.sh
./scripts/setup-gns3-config.sh

# 5. Launch GNS3
gns3
```

---

*Last updated: May 2026 | Platform: Debian 13.4 Trixie | GNS3: 3.0.6*
