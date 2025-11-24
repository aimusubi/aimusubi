
---

## `docs/adapters.md`

```markdown
# Adapters

AIMusubi uses **adapters** to translate vendor-agnostic intents into vendor-specific API calls.

This document describes the high-level behavior of the built-in adapters.

---

## Cisco IOS-XE Adapter

- **Protocol:** RESTCONF over HTTPS
- **Typical Port:** 443
- **Auth:** Basic auth or token (lab: username/password)

### Key Capabilities

- Interface state via YANG models
- Admin up/down via interface configuration
- IPv4 routing table via YANG
- OSPF neighbor information (where supported)

**Example intent flow:**

1. User/LLM calls `iface.list` for `router1`.
2. AIMusubi resolves `router1` to `router1.lab.local`.
3. Cisco adapter builds RESTCONF GETs to `/restconf/data/ietf-interfaces:interfaces/interface`.
4. Adapter normalizes output into AIMusubi’s interface model.
5. API returns standard JSON to the caller.

---

## Arista EOS Adapter

- **Protocol:** eAPI (JSON-RPC) over HTTPS
- **Typical Port:** 443
- **Auth:** Username/password

### Key Capabilities

- Interface state via `show interfaces` / `show ip interface brief`
- Admin up/down via `interface ...` commands
- Routing table via `show ip route`
- OSPF neighbors via `show ip ospf neighbor` (if configured)

**Example flow:**

1. `iface.list` for `leaf1`.
2. Adapter sends JSON-RPC calls:
   - `"command": "show ip interface brief"`
3. Output parsed and normalized.

---

## VyOS Adapter

- **Protocol:** REST / RESTCONF (depending on platform)
- **Typical Port:** 443 or 8443
- **Auth:** API key or username/password

Capabilities depend on the specific REST/RESTCONF implementation:

- Interface listing
- Route table retrieval
- Operational state where available

---

## Adding New Adapters

A new adapter typically involves:

1. Defining a **vendor module** in `core/AIMusubi/adapters`.
2. Implementing:
   - Connection handling
   - Authentication
   - API request/response mapping
3. Mapping each **intent** to one or more device API calls.
4. Normalizing output into AIMusubi’s internal models.

Future documentation will provide detailed adapter development guides.
