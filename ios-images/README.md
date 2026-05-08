# 🖥️ IOS Images Guide

> GNS3 requires router/switch OS images to emulate real network devices.  
> These images are **not included in this repo** for legal reasons.  
> This guide explains where to get them and how to use them.

---

## What You Need for This Lab

| Device | Image Type | Required For |
|---|---|---|
| R1, R2 (Cisco routers) | Cisco IOS / IOSv | OSPF, NAT, DHCP, ACL, QoS |
| SW1 (if using Cisco) | Cisco IOSvL2 | VLAN, trunking (optional — built-in switch works too) |
| FortiGate (future) | FortiGate QEMU | Firewall, IPS, VPN |

---

## Option 1 — Cisco IOSv (Recommended for this lab)

**IOSv** is a full virtual Cisco IOS image that runs under QEMU. It supports all features needed for this lab.

### Where to get it legally

1. **Cisco DevNet Sandbox** (free):
   - Go to: https://developer.cisco.com/site/sandbox/
   - Reserve a "Multi-IOS" or "VIRL" sandbox
   - Download `vios-adventerprisek9-m.vmdk.SPA.xxx.qcow2`

2. **Cisco VIRL / CML Personal** (paid license ~$200/yr):
   - https://learningnetworkstore.cisco.com/cisco-modeling-labs-personal

3. **Cisco Learning Network** (if you have a valid CCO account with support contract):
   - https://software.cisco.com

### Import into GNS3

```
File name:    vios-adventerprisek9-m.vmdk.SPA.159-3.M6.qcow2
Place in:     ~/GNS3/images/QEMU/

In GNS3 GUI:
  Edit → Preferences → QEMU VMs → New
  Name:    IOSv-R1
  RAM:     512 MB
  CPUs:    1
  hda:     vios-adventerprisek9-m...qcow2
  Adapters: 4
  Type:    virtio-net-pci
```

---

## Option 2 — Cisco c7200 (Dynamips — older but works)

Dynamips emulates older Cisco platforms (c7200, c3725, c3640). IOS images for these are widely available but technically still Cisco intellectual property.

### File format
```
c7200-adventerprisek9-mz.124-24.T5.bin
```

### Place in
```
~/GNS3/images/IOS/
```

### Import in GNS3
```
Edit → Preferences → IOS Routers → New
Platform: c7200
RAM: 256 MB
IOS image: c7200-adventerprisek9-mz.xxx.bin
```

> **Note**: c7200 is heavy — each instance uses 256+ MB RAM. For this lab with 32 GB RAM, you can run 4–6 instances comfortably.

---

## Option 3 — FRRouting (Free & Open Source)

If you cannot get Cisco images, FRRouting (FRR) is a free Linux-based routing suite that supports OSPF, BGP, and more.

```bash
# Install on a Linux VM in GNS3
sudo apt install frr

# Enable OSPF daemon
sudo nano /etc/frr/daemons
# Set: ospfd=yes

sudo systemctl restart frr
sudo vtysh   # Cisco-like CLI
```

FRR is 100% legal, free, and available as a GNS3 appliance:
https://www.gns3.com/marketplace/appliances/frrouting

---

## Option 4 — FortiGate VM (for firewall lab)

1. Create free account at: https://support.fortinet.com
2. Go to: Download → VM Images → FortiGate → KVM
3. Download: `FGT_VM64_KVM-v7.x.x.qcow2`
4. Place in: `~/GNS3/images/QEMU/`

### GNS3 appliance config
```
Name:     FortiGate-7x
RAM:      2048 MB
CPUs:     2
hda:      FGT_VM64_KVM-v7.x.x.qcow2
Options:  -cpu host -smp 2,sockets=1,cores=2
Adapters: 4
Type:     virtio-net-pci
```

---

## Directory Structure

```
~/GNS3/images/
├── IOS/          ← Dynamips .bin images (c7200, c3725)
├── QEMU/         ← QEMU .qcow2 images (IOSv, FortiGate, Linux)
└── IOU/          ← IOS on Unix .bin images (if available)
```

---

## Image Checksums

Document your images here after downloading:

| Image | Version | MD5/SHA256 | Source |
|---|---|---|---|
| (your image here) | | | |

---

*Note: This repository does not and will not host any Cisco IOS images.*  
*All Cisco software is subject to Cisco's End User License Agreement.*
