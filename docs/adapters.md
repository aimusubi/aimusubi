# AIMusubi – Adapters Guide

AIMusubi uses **vendor adapters** to translate intent-based API calls into
vendor‑specific device operations.  
This is where AIMusubi bridges the gap between LLM-driven requests and
actual network hardware.

This guide explains how the built‑in adapters work and how to extend them.

---

# 1. What Is an Adapter?

An adapter is a Python module inside:

```
core/AIMusubi/adapters/
```

It provides:

- Protocol handling (RESTCONF, eAPI, REST)
- Authentication
- API request mapping
- Response parsing & normalization
- Error translation
- Logging hooks for Prometheus/Grafana

**Intents** do not talk directly to devices — they call the adapter layer.

---

# 2. Supported Vendors (v1.0)

AIMusubi v1.0 ships with three validated adapters:

| Vendor       | API Protocol | Notes |
|--------------|--------------|-------|
| **Cisco IOS‑XE** | RESTCONF     | YANG data models for interfaces, routing, OSPF |
| **Arista EOS**   | eAPI (HTTPS JSON‑RPC) | Commands exposed via `show` and `interface` |
| **VyOS**         | REST / RESTCONF (varies) | Limited support depending on build |

Each driver exposes a uniform set of operations:

- Interface queries
- Interface admin state (if enabled)
- Routing (IPv4 RIB)
- OSPF adjacency (if configured)
- Basic system health

---

# 3. Cisco IOS‑XE Adapter (RESTCONF)

**Protocol:** RESTCONF over HTTPS  
**Default Port:** `443`  
**Auth:** Basic (username/password)

### Example RESTCONF paths used:

| Purpose                | YANG Path |
|------------------------|-----------|
| Interfaces             | `/restconf/data/ietf-interfaces:interfaces/interface` |
| Interface state        | `/restconf/data/ietf-interfaces:interfaces-state/interface` |
| IPv4 routes            | `/restconf/data/ietf-routing:routing-state` |
| OSPF neighbors         | `/restconf/data/Cisco-IOS-XE-ospf-oper:ospf-oper-data` |

### Capabilities

- Lists interface name, admin state, oper state, IPv4
- Can toggle admin state (if allowed)
- Retrieves full IPv4 routing table
- Reads OSPF neighborship (platform dependent)

### Typical Flow: iface.list

1. Request sent to:

   ```
   GET /restconf/data/ietf-interfaces:interfaces/interface
   ```

2. Cisco returns structured JSON.
3. Adapter converts it into AIMusubi’s normalized model.

---

# 4. Arista EOS Adapter (eAPI – JSON‑RPC)

**Protocol:** HTTPS-based JSON-RPC  
**Default Port:** `443`  
**Auth:** Username/password or token

### Example JSON-RPC Payload

```json
{
  "jsonrpc": "2.0",
  "method": "runCmds",
  "params": {
    "version": 1,
    "cmds": ["show ip interface brief"]
  },
  "id": 1
}
```

### Capabilities

- Collects interface admin/oper state
- Supports interface admin-up/down
- Parses routing table output
- Supports OSPF adjacency
- Normalizes EOS data models to AIMusubi models

### Typical Flow: iface.list

- Sends `"show ip interface brief"`  
- Parses the table from EOS  
- Normalizes result into AIMusubi’s model

---

# 5. VyOS Adapter (REST / RESTCONF)

**Protocol:** Depends on VyOS build (REST or RESTCONF)  
**Default Port:** `443` or `8443`  
**Auth:** API key or username/password

VyOS’ API support differs across versions. AIMusubi’s adapter handles:

- Interface enumeration
- Route table extraction
- Basic state inspection

Example query:

```bash
GET https://edge1.lab.local/interfaces
```

If the API is RESTCONF‑enabled, the adapter automatically switches to  
RESTCONF schema paths.

---

# 6. Adapter Responsibilities

Every adapter module must implement:

### **6.1 Authentication**
- Manage credentials for that vendor  
- Handle tokens/sessions if required  
- Handle Basic auth over HTTPS in lab mode with `verify=False`

### **6.2 API Request Construction**
- Build correct URL paths  
- Build correct JSON-RPC payloads (Arista)  
- Encode parameters as vendor expects

### **6.3 Response Normalization**
Convert device-specific responses into AIMusubi’s normalized structures:

```json
{
  "name": "GigabitEthernet1",
  "admin_status": "up",
  "oper_status": "up",
  "ipv4": "10.1.1.1/24"
}
```

### **6.4 Error Handling**
Map device errors into AIMusubi API errors:

- Connection errors
- Auth failures
- Endpoint unsupported
- Invalid interface names
- Operational state missing from responses

### **6.5 Logging**
Send metrics into Prometheus through AIMusubi’s logging interface:

- Request count
- Request latency
- Success/failure counters
- Vendor error counters

---

# 7. Adding a New Adapter

You can extend AIMusubi with additional vendors.

A new adapter must:

1. Create a new module under:
   ```
   core/AIMusubi/adapters/<vendor_name>.py
   ```

2. Implement the vendor class with:
   - `connect()`
   - `run_intent(intent_name, params)`
   - `normalize_*` helpers
   - Error mapping

3. Update the adapter registry:
   ```
   core/AIMusubi/adapters/__init__.py
   ```

4. Update intent-to-adapter mapping.

5. Update `docs/intents_reference.md` as necessary.

---

# 8. Adapter Debugging Tips

### **Enable Log Tail**

Bare-metal:
```bash
sudo journalctl -u aimusubi-api -f
```

Docker:
```bash
docker compose logs -f aimusubi-api
```

### **Enable Curl Testing**

Verify device APIs independently of AIMusubi.

### **Use Explicit Intent Tests**

```bash
curl -X POST http://127.0.0.1:5055/intent/exec   -H "Content-Type: application/json"   -d '{"intent": "iface.list", "params": {"host":"router1.lab.local"}}'
```

### **Simulate Misconfigurations**

- Wrong credentials  
- Wrong port  
- Wrong protocol  

AIMusubi will show adapter‑level traceback logs.

---

# 9. Summary

Adapters are the core of AIMusubi’s ability to operate across vendors:

- Vendor-specific logic is contained in one place  
- AIMusubi provides a consistent intent interface  
- New vendors can be added by extending the adapter layer  

For deeper understanding of end‑to‑end flow, see:

👉 `agent_flow.md`  
