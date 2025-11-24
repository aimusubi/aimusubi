# AIMusubi – Lab Environment Guide

This guide describes the recommended lab environment for running AIMusubi and
preparing network devices (Cisco IOS-XE, Arista EOS, VyOS) for API-driven LLM
automation.

---

# 1. Reference Hardware

AIMusubi was validated on the following hardware profile:

- **CPU:** 2 vCPUs (8th-gen i7 virtual cores)
- **RAM:** 10 GB
- **Storage:** 80 GB SSD
- **Optional GPU:** NVIDIA GTX 1050 Ti (4 GB VRAM) for local LLM workloads
- **Network:** Layer‑3 reachable management network to all devices

This configuration easily supports:

- 1–3 lab routers
- The full AIMusubi stack (API, WebUI, Prometheus, Grafana)
- Local LLMs if desired

---

# 2. Recommended Network Topology

Below is a simple testbed topology suitable for AIMusubi:

```
                   ┌──────────────────────┐
                   │   AIMusubi Host      │
                   │  (Ubuntu or Docker)  │
                   │ 10.10.0.10/24        │
                   └─────────┬────────────┘
                             │
     ┌────────────────────────┼────────────────────────┐
     │                        │                        │
┌─────────────┐        ┌─────────────┐        ┌─────────────┐
│ Cisco IOS-XE│        │ Arista EOS  │        │    VyOS      │
│ router1     │        │ leaf1       │        │ edge1        │
│10.10.0.11/24│        │10.10.0.12/24│        │10.10.0.13/24 │
└─────────────┘        └─────────────┘        └─────────────┘
```

Device names are examples; use any naming convention you prefer.

---

# 3. Device Preparation

Each vendor requires enabling its HTTPS-based API and configuring credentials.

---

## 3.1 Cisco IOS-XE – RESTCONF

### Minimum Configuration Example

```text
ip http secure-server
restconf

username aimusubi privilege 15 secret LabPassword123
```

### Connectivity Test

From AIMusubi host:

```bash
curl -k https://router1.lab.local/restconf/data
```

If you get any JSON output, RESTCONF is working.

---

## 3.2 Arista EOS – eAPI (JSON-RPC)

### Enable eAPI

```text
management api http-commands
   no shutdown
   protocol https
!
username aimusubi privilege 15 secret LabPassword123
```

### Connectivity Test

```bash
curl -k https://leaf1.lab.local/command-api
```

Expected JSON response from EOS.

---

## 3.3 VyOS – REST / RESTCONF (depending on build)

VyOS versions vary in API support.  
Typical pattern:

```text
set service https listen-address 0.0.0.0
set service https api keys id aimusubi key LabKey123
commit
save
```

### Connectivity Test

```bash
curl -k https://edge1.lab.local/configuration
```

If you see a JSON structure, the API is reachable.

---

# 4. Certificate Handling

For simplicity, AIMusubi’s default setting allows:

- Self-signed certificates  
- No strict certificate validation  

**This is acceptable for a homelab**, but should not be used in production.

---

# 5. Management User Accounts

Each device must have credentials for AIMusubi:

- Username: `aimusubi`
- Password: `LabPassword123`
- Privilege level: Must allow reading operational state  
  (and configuration changes *if you intend to experiment with them*)

Credentials are stored inside AIMusubi’s SQLite memory.

---

# 6. Device Reachability

Ensure AIMusubi host can reach each device:

```bash
ping router1.lab.local
ping leaf1.lab.local
ping edge1.lab.local
```

Check HTTPS port reachability (443 by default):

```bash
nc -zv router1.lab.local 443
```

---

# 7. SNMP Trap Configuration (Optional)

AIMusubi includes an SNMP trap receiver for future event-driven workflows.

To send traps to AIMusubi host:

### Cisco IOS-XE
```text
snmp-server host 10.10.0.10 traps version 2c public
```

### Arista EOS
```text
snmp-server host 10.10.0.10 version 2c public
```

### VyOS
```text
set service snmp community public
set service snmp trap-target 10.10.0.10
commit; save
```

SNMP traps appear in:

- Bare-metal: `journalctl -u snmptrapd -f`
- Docker: logs under `~/aimusubi-stack/logs/snmptrap.log`

---

# 8. Recommended Best Practices

- Use a **dedicated management VRF** or VLAN for devices and AIMusubi.
- Keep device clocks synchronized via NTP.
- Start with read-only intents before experimenting with config changes.
- Keep API logs open while testing:
  - Bare-metal: `journalctl -u aimusubi-api -f`
  - Docker: `docker compose logs -f aimusubi-api`

---

# 9. Next Steps

Your lab is now ready for AIMusubi device automation.

Proceed to:

👉 `post_bootstrap_activation.md`  
👉 `openwebui_setup.md`  
