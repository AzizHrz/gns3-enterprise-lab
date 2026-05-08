# 🏢 TP GNS3 Avancé — Réseau Multi-sites

> **Objectif**: Concevoir un réseau multi-sites avec VLAN, OSPF, NAT, QoS, DHCP, ACL  
> et analyser les performances avec Wireshark.

---

## Scenario

```
📍 Site 1 — Siège (HQ)          📍 Site 2 — Agence (Branch)
  VLAN 10: Service Admin           1 réseau local: 192.168.30.0/24
  VLAN 20: Service Technique       PC-Agence
  Serveur interne
```

---

## Topology Diagram

```
                    [Cloud / Internet]
                           │
                    ┌──────▼──────┐
                    │  R1 - Siège │  e0/0 WAN → Cloud
                    │             │  e0/1 → SW1 (trunk)
                    │  OSPF: 1.1.1.1 │  e0/2 → R2 (WAN link)
                    └──────┬──────┘
                           │ trunk (VLAN 10+20)
                    ┌──────▼──────┐
                    │    SW1      │
                    └──┬───────┬──┘
                  VLAN10     VLAN20
              192.168.10.x  192.168.20.x
              [PC-Admin]    [PC-Tech]
                            [Serveur: 192.168.20.100]
                           │
                    10.0.0.0/30 (WAN link)
                           │
                    ┌──────▼──────┐
                    │ R2 - Agence │  e0/0 → R1 (WAN)
                    │             │  e0/1 → LAN 192.168.30.0/24
                    │  OSPF: 2.2.2.2 │
                    └──────┬──────┘
                           │
                    [PC-Agence: 192.168.30.x]
```

---

## Addressing Plan

| Device | Interface | IP Address | Description |
|---|---|---|---|
| R1 | e0/0 | 203.0.113.1/30 | WAN → Internet |
| R1 | e0/1.10 | 192.168.10.1/24 | Gateway VLAN 10 Admin |
| R1 | e0/1.20 | 192.168.20.1/24 | Gateway VLAN 20 Tech |
| R1 | e0/2 | 10.0.0.1/30 | WAN → R2 |
| R2 | e0/0 | 10.0.0.2/30 | WAN → R1 |
| R2 | e0/1 | 192.168.30.1/24 | Gateway Agence LAN |
| PC-Admin | eth0 | DHCP → 192.168.10.x | VLAN 10 |
| PC-Tech | eth0 | DHCP → 192.168.20.x | VLAN 20 |
| Serveur | eth0 | 192.168.20.100/24 | Static — VLAN 20 |
| PC-Agence | eth0 | DHCP → 192.168.30.x | Agence LAN |

---

## Step 1 — Build Topology in GNS3

### Nodes needed

| Node | GNS3 Type | Notes |
|---|---|---|
| R1 | Cisco IOS (QEMU or Dynamips) | c7200 or IOSv |
| R2 | Cisco IOS (QEMU or Dynamips) | same image as R1 |
| SW1 | Ethernet switch (built-in) | Simple L2, no IOS needed |
| PC-Admin | VPCS | Lightweight — no image needed |
| PC-Tech | VPCS | Lightweight |
| PC-Agence | VPCS | Lightweight |
| Serveur | VPCS or Linux VM | VPCS for simple tests |
| Cloud | Cloud node | For internet via host NAT |

### Connections

```
Cloud   →  R1 e0/0
R1 e0/1 →  SW1 port0      (trunk)
R1 e0/2 →  R2 e0/0        (WAN inter-site)
SW1 port1 → PC-Admin       (access VLAN 10)
SW1 port2 → PC-Tech        (access VLAN 20)
SW1 port3 → Serveur        (access VLAN 20)
R2  e0/1 →  PC-Agence
```

### SW1 VLAN port configuration (built-in switch)

Right-click SW1 → **Configure** → set each port:

| Port | Type | VLAN |
|---|---|---|
| 0 (→ R1) | dot1q trunk | 10, 20 |
| 1 (→ PC-Admin) | access | 10 |
| 2 (→ PC-Tech) | access | 20 |
| 3 (→ Serveur) | access | 20 |

---

## Step 2 — R1 Configuration (Siège)

Open R1 console (right-click → Console after starting):

### 2.1 — Basic setup

```
R1# conf t
hostname R1-SIEGE
no ip domain-lookup
service timestamps log datetime msec
```

### 2.2 — WAN interface (internet)

```
interface e0/0
 description "WAN-INTERNET"
 ip address 203.0.113.1 255.255.255.252
 ip nat outside
 no shutdown
```

### 2.3 — Sub-interfaces for VLANs (Router-on-a-Stick)

```
interface e0/1
 no shutdown

interface e0/1.10
 encapsulation dot1Q 10
 description "VLAN10-ADMIN"
 ip address 192.168.10.1 255.255.255.0
 ip nat inside

interface e0/1.20
 encapsulation dot1Q 20
 description "VLAN20-TECH"
 ip address 192.168.20.1 255.255.255.0
 ip nat inside
```

### 2.4 — Inter-site WAN link

```
interface e0/2
 description "WAN-VERS-R2"
 ip address 10.0.0.1 255.255.255.252
 ip ospf network point-to-point
 no shutdown
```

### 2.5 — Default route toward internet

```
ip route 0.0.0.0 0.0.0.0 203.0.113.2
```

---

## Step 3 — R2 Configuration (Agence)

```
R2# conf t
hostname R2-AGENCE
no ip domain-lookup

interface e0/0
 description "WAN-VERS-R1"
 ip address 10.0.0.2 255.255.255.252
 ip ospf network point-to-point
 no shutdown

interface e0/1
 description "LAN-AGENCE"
 ip address 192.168.30.1 255.255.255.0
 ip nat inside
 no shutdown

end
write memory
```

---

## Step 4 — DHCP Configuration on R1

```
R1# conf t

ip dhcp excluded-address 192.168.10.1 192.168.10.10
ip dhcp excluded-address 192.168.20.1 192.168.20.10
ip dhcp excluded-address 192.168.30.1 192.168.30.10

ip dhcp pool VLAN10-ADMIN
 network 192.168.10.0 255.255.255.0
 default-router 192.168.10.1
 dns-server 8.8.8.8 1.1.1.1
 domain-name siege.lab
 lease 1

ip dhcp pool VLAN20-TECH
 network 192.168.20.0 255.255.255.0
 default-router 192.168.20.1
 dns-server 8.8.8.8 1.1.1.1
 domain-name siege.lab
 lease 1

ip dhcp pool LAN-AGENCE
 network 192.168.30.0 255.255.255.0
 default-router 192.168.30.1
 dns-server 8.8.8.8
 domain-name agence.lab
 lease 1

end
write memory
```

**DHCP relay on R2** (forward requests to R1):
```
R2# conf t
interface e0/1
 ip helper-address 10.0.0.1
end
```

---

## Step 5 — OSPF Configuration

```
! === R1 ===
R1# conf t
router ospf 1
 router-id 1.1.1.1
 network 192.168.10.0 0.0.0.255 area 0
 network 192.168.20.0 0.0.0.255 area 0
 network 10.0.0.0 0.0.0.3 area 0
 default-information originate always
 passive-interface e0/0
 passive-interface e0/1.10
 passive-interface e0/1.20
 auto-cost reference-bandwidth 1000
end

! === R2 ===
R2# conf t
router ospf 1
 router-id 2.2.2.2
 network 192.168.30.0 0.0.0.255 area 0
 network 10.0.0.0 0.0.0.3 area 0
 passive-interface e0/1
 auto-cost reference-bandwidth 1000
end

write memory
```

**Verify OSPF:**
```
R1# show ip ospf neighbor
R1# show ip route ospf
```

---

## Step 6 — NAT Configuration

```
R1# conf t

ip access-list standard NAT-INSIDE
 permit 192.168.10.0 0.0.0.255
 permit 192.168.20.0 0.0.0.255
 permit 192.168.30.0 0.0.0.255

ip nat inside source list NAT-INSIDE interface e0/0 overload

end
write memory
```

**Verify:**
```
R1# show ip nat translations
R1# show ip nat statistics
```

---

## Step 7 — ACL Security

Block VLAN 20 (Tech) from accessing VLAN 10 (Admin):

```
R1# conf t

ip access-list extended ACL-VLAN20-IN
 remark Block Tech from reaching Admin VLAN
 deny   ip 192.168.20.0 0.0.0.255 192.168.10.0 0.0.0.255
 remark Allow Tech to internet and agence
 permit ip 192.168.20.0 0.0.0.255 any
 deny   ip any any log

interface e0/1.20
 ip access-group ACL-VLAN20-IN in

end
write memory
```

---

## Step 8 — QoS (Prioritize VoIP)

```
R1# conf t

class-map match-any CM-VOIP
 match dscp ef
 match protocol rtp

class-map match-any CM-CRITICAL
 match dscp af31 af32

class-map match-any CM-BULK
 match protocol ftp

policy-map PM-WAN-OUT
 class CM-VOIP
  priority percent 30
 class CM-CRITICAL
  bandwidth percent 20
 class CM-BULK
  bandwidth percent 10
  fair-queue
 class class-default
  fair-queue

interface e0/0
 service-policy output PM-WAN-OUT

interface e0/2
 service-policy output PM-WAN-OUT

end
write memory
```

---

## Step 9 — PC Configuration

In each VPCS console:

```
! PC-Admin
PC-Admin> dhcp
PC-Admin> show ip

! PC-Tech
PC-Tech> dhcp
PC-Tech> show ip

! Serveur (static)
Serveur> ip 192.168.20.100 255.255.255.0 192.168.20.1
Serveur> show ip

! PC-Agence
PC-Agence> dhcp
PC-Agence> show ip
```

---

## Step 10 — WAN Failure Simulation

```
R1# conf t
interface e0/0
 shutdown
end

! Test — inter-site routing still works via OSPF
R2# ping 192.168.10.1    ! should work (OSPF intact)
R2# ping 8.8.8.8         ! should FAIL (NAT/internet down)

! Restore
R1# conf t
interface e0/0
 no shutdown
end
```

---

## Step 11 — Wireshark Analysis

Right-click any link in GNS3 → **Start Capture** → Wireshark opens.

| Capture | Link | Filter | What to observe |
|---|---|---|---|
| OSPF hellos | R1↔R2 | `ospf` | Hello interval 10s, Router-ID exchange |
| DHCP DORA | SW1→PC-Admin | `bootp` | Discover, Offer, Request, ACK |
| NAT in action | R1↔Cloud | `icmp` | Source IP = 203.0.113.1 (not internal) |
| ACL block | R1 e0/1.20 | `icmp` | Packets arrive, no reply |
| QoS DSCP | Any | `ip.dscp == 46` | EF-marked VoIP packets |

---

## Verification Summary

```
! Connectivity matrix
PC-Admin  → 192.168.10.1   ✅ (own gateway)
PC-Admin  → 192.168.20.100 ✅ (cross-VLAN via R1)
PC-Admin  → 192.168.30.x   ✅ (agence via OSPF)
PC-Admin  → 8.8.8.8        ✅ (internet via NAT)
PC-Tech   → 192.168.10.x   ❌ (ACL blocks)
PC-Tech   → 8.8.8.8        ✅ (internet permitted)
PC-Agence → 192.168.10.x   ✅ (via OSPF + inter-VLAN)
PC-Agence → 8.8.8.8        ✅ (via R1 NAT)
```

---

*→ Configs: [configs/routers/](../configs/routers/)*  
*→ Scripts: [scripts/](../scripts/)*
