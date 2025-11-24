# AIMusubi – Intents Reference Guide

This document provides a complete, human-readable reference for the **intents**
supported by AIMusubi v1.0.  
Intents represent vendor-agnostic operations such as listing interfaces, pulling
routing tables, or inspecting OSPF neighbors.

Every intent is executed through the AIMusubi API and translated by vendor
adapters into device-specific calls (RESTCONF, eAPI, REST).

---

# 1. What Are Intents?

An *intent* is a high-level instruction that abstracts away vendor-specific
details.

Instead of writing:

- Cisco RESTCONF URLs  
- Arista JSON-RPC payloads  
- VyOS REST paths  

…you call:

```
iface.list
routing.v4.rib
ospf.neigh
cpu.util
```

AIMusubi handles the rest.

---

# 2. How to List Available Intents

From AIMusubi API:

```bash
curl http://127.0.0.1:5055/intent/list
```

Expected output:

```json
{
  "iface.list": {},
  "iface.admin-up": {},
  "iface.admin-down": {},
  "routing.v4.rib": {},
  "ospf.neigh": {},
  "cpu.util": {},
  "mem.stats": {}
}
```

---

# 3. Standard Intents (v1.0)

Below is the reference for all built-in intents in AIMusubi v1.0.

---

## 3.1 Interface Intents

### **iface.list**  
Retrieve interface state (admin/oper), IPv4, and attributes.

**Parameters:**
- `host` – logical device name or FQDN

**Example Request:**

```bash
curl -X POST http://127.0.0.1:5055/intent/exec   -H "Content-Type: application/json"   -d '{
        "intent": "iface.list",
        "params": { "host": "router1.lab.local" }
      }'
```

**Example Output (sanitized):**

```json
{
  "result": [
    {
      "name": "GigabitEthernet1",
      "admin_status": "up",
      "oper_status": "up",
      "ipv4": "10.1.1.1/24"
    }
  ]
}
```

---

### **iface.admin-up**  
Bring an interface into admin-up state.

**Parameters:**
- `host`
- `interface`

**Notes:**
- Configuration-changing intents may require elevated privilege.
- Not all environments enable config intents by default.

---

### **iface.admin-down**  
Bring an interface into admin-down state.

**Parameters:**
- `host`
- `interface`

**Notes:**
- Same constraints as `iface.admin-up`.

---

## 3.2 Routing Intents

### **routing.v4.rib**  
Retrieve the IPv4 route table.

**Parameters:**
- `host`

**Example Output:**

```json
{
  "result": [
    {
      "prefix": "0.0.0.0/0",
      "nexthop": "10.1.1.254",
      "interface": "GigabitEthernet1",
      "protocol": "static"
    }
  ]
}
```

---

## 3.3 OSPF Intents

### **ospf.neigh**  
Retrieve OSPF neighbors.

**Parameters:**
- `host`

**Example Output (sanitized):**

```json
{
  "result": [
    {
      "neighbor_id": "10.10.10.2",
      "state": "FULL",
      "interface": "GigabitEthernet2"
    }
  ]
}
```

OSPF visibility depends on:

- Device support  
- OSPF being configured  
- The adapter (Cisco and Arista support OSPF in v1.0)

---

## 3.4 System / Health Intents

### **cpu.util**  
Report CPU usage.

**Parameters:**
- `host`

### **mem.stats**  
Report memory usage.

**Parameters:**
- `host`

### **system.health**  
Check device/system-level status (implementation varies per vendor).

---

## 4. How the LLM Uses Intents

When Open WebUI is configured correctly, prompts like:

> “Use AIMusubi to show interface state on router1.”

…lead the LLM to generate a tool call:

```json
{
  "tool": "AIMusubi API",
  "operation": "iface.list",
  "params": { "host": "router1.lab.local" }
}
```

AIMusubi:

1. Routes the intent  
2. Selects the correct adapter  
3. Queries the device  
4. Normalizes the response  
5. Returns structured data  
6. LLM summarizes the result  

---

# 5. Writing New Intents

New intents involve:

1. Defining the name (`routing.v6.rib`, `bgp.summary`, etc.)
2. Adding manifest schemas in `core/AIMusubi/intents`
3. Implementing logic inside the AIMusubi API
4. Adding adapter logic for each vendor
5. Updating the OpenAPI schema  
6. Updating this documentation

Intent creation is modular — vendors can support subsets of capabilities.

---

# 6. Example Troubleshooting

### **Issue:** LLM ignores the tool and guesses  
**Fix:** Strengthen system prompt, e.g.:

```
Always call an AIMusubi intent for any network device question.
Do not fabricate interface names or data.
```

---

### **Issue:** Intent returns 500 error  
**Common Causes:**

- Wrong credentials  
- Device API unreachable  
- Unsupported vendor endpoint  
- Adapter error parsing JSON  

Check logs:

Bare-metal:
```bash
sudo journalctl -u aimusubi-api -f
```

Docker:
```bash
docker compose logs -f aimusubi-api
```

---

### **Issue:** OSPF intent returns empty result  
**Causes:**

- OSPF not configured on device  
- Device does not expose required data model  
- Not supported by vendor in v1.0  

---

# 7. Summary

This guide provides a reference for:

- Interface operations  
- Routing operations  
- OSPF neighbors  
- System resource queries  
- Administrative interface controls  

Intents are the core of AIMusubi’s automation model.  
For deeper details on execution flow:

👉 See `agent_flow.md`
