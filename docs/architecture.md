# AIMusubi – Architecture Guide

This document provides a deep technical overview of AIMusubi’s architecture:
how the API, intent engine, adapters, LLM integration, memory, and observability
combine to create an agentic NetOps framework.

It is written for engineers who want to understand or extend AIMusubi’s internals.

---

# 1. High-Level Architecture

AIMusubi consists of five major components:

```
LLM (Open WebUI / External API)
        │
        ▼
AIMusubi API (FastAPI)
        │
        ▼
Intent Engine
        │
        ▼
Adapter Layer (Cisco / Arista / VyOS / future)
        │
        ▼
Device API (RESTCONF / eAPI / REST)

+ Observability:
    - Prometheus metrics
    - Grafana dashboards
+ Memory:
    - SQLite state db (observations, credentials, metadata)
```

AIMusubi enforces a strict separation between:

- **LLM reasoning**
- **Network device interaction**

This ensures the LLM has *zero direct access* to devices; all operations must
go through the intent engine.

---

# 2. Components Overview

## 2.1 AIMusubi API (FastAPI)

Located in:

```
core/AIMusubi/api/
```

Responsibilities:

- Expose `/intent/exec`, `/health`, `/metrics`
- Validate incoming requests
- Load intent definitions
- Select the correct adapter
- Send normalized results back to callers
- Export Prometheus metrics
- Manage local memory (credentials + observations)
- Serve OpenAPI schema to Open WebUI

The API is intentionally minimal and transparent.

---

# 3. Intent Engine

Located in:

```
core/AIMusubi/intents/
```

Intents represent **vendor-independent network operations**, such as:

- `iface.list`
- `routing.v4.rib`
- `ospf.neigh`
- `cpu.util`

Each intent defines:

- Required parameters
- Expected output schema
- Supported vendors
- Handler logic

### Intent Execution Pipeline

```
Client request
    ↓
Validate intent name
    ↓
Validate parameters
    ↓
Identify vendor for target host
    ↓
Invoke adapter with vendor-specific logic
    ↓
Receive device response
    ↓
Normalize data into standard AIMusubi model
    ↓
Return JSON to caller (LLM or API client)
```

---

# 4. Adapter Layer

Adapters translate intents into vendor-specific API calls.

Located in:

```
core/AIMusubi/adapters/
```

Adapters exist for:

- Cisco IOS-XE (RESTCONF)
- Arista EOS (eAPI JSON-RPC)
- VyOS (REST/RESTCONF)

Each adapter:

1. Authenticates with device  
2. Builds the correct HTTPS URL or JSON payload  
3. Sends the request  
4. Handles errors / retries  
5. Normalizes vendor-specific output  
6. Returns a unified structure back to the intent engine  

### Normalized Interface Structure

```json
{
  "name": "GigabitEthernet1",
  "admin_status": "up",
  "oper_status": "up",
  "ipv4": "10.1.1.1/24"
}
```

Normalization is key to AIMusubi’s vendor-agnostic operation.

---

# 5. Memory Subsystem (SQLite)

AIMusubi uses a simple, reliable SQLite database for:

- Device credential storage  
- First-seen baselines  
- Per-device observations  
- Persistent metadata  

Located in:

```
core/AIMusubi/memory/
```

Schema evolves as features expand.

This memory is used for:

- Avoiding repeated credential prompts  
- Tracking drift in future versions  
- Feeding longitudinal metrics  

---

# 6. Observability

### 6.1 Prometheus

AIMusubi exposes Prometheus metrics at:

```
http://127.0.0.1:5055/metrics
```

Metrics include:

- `aimusubi_api_requests_total`
- `aimusubi_intent_success_total`
- `aimusubi_intent_failure_total`
- `aimusubi_adapter_latency_seconds`
- Per-vendor counters and timing

Prometheus is deployed as part of the bootstrap under:

```
/etc/prometheus/
```

### 6.2 Grafana

Grafana uses preloaded dashboards to visualize:

- API behavior  
- Intent success ratio  
- Per-adapter latency  
- LLM tool call volume  
- Device metrics (in future versions)  

Dashboards are provisioned under:

```
grafana/dashboards/
```

---

# 7. Open WebUI Integration (LLM)

Open WebUI is the LLM orchestrator and frontend.

It integrates with AIMusubi via:

```
http://127.0.0.1:5055/openapi.json
```

### Flow:

1. LLM interprets user prompt  
2. Chooses appropriate AIMusubi intent  
3. Generates a tool call  
4. Open WebUI sends the tool call to AIMusubi  
5. AIMusubi returns JSON  
6. LLM summarizes the JSON into natural language  

AIMusubi never allows the LLM to:

- Guess interface names  
- Invent IP addresses  
- Issue raw device commands  

All device interaction must pass through the intent engine.

---

# 8. Adapter Registry

The adapter registry maps hosts to vendors.

Example:

```
router1.lab.local → cisco
leaf1.lab.local   → arista
edge1.lab.local   → vyos
```

This mapping is done via:

- Device profile data  
- Host naming conventions  
- (Future) automatic vendor detection  

Adapters are selected dynamically per intent execution.

---

# 9. Error Handling Architecture

AIMusubi uses a consistent error model:

### Categories:

- Device unreachable  
- Authentication failure  
- Endpoint unsupported  
- Vendor API failure  
- Intent schema violation  
- Normalization failure  

Errors are returned in structured JSON:

```json
{
  "error": "Device unreachable at router1.lab.local"
}
```

Prometheus counters also record errors for dashboards.

---

# 10. Security Model (Lab Mode)

AIMusubi v1.0 operates in **lab mode**, with:

- Self-signed certificate acceptance  
- No HTTP→HTTPS proxying  
- Localhost-only access by default  
- Credential storage in SQLite  
- No RBAC (future enterprise feature)

This is by design for:

- Homelabs  
- Research  
- Offline demos  
- Lightweight experimentation  

Enterprise security features will come in future tiers.

---

# 11. Bootstrap Architecture

Two bootstraps exist:

### Bare-Metal (Ubuntu-focused)
Installs:

- Python venv  
- AIMusubi API  
- Open WebUI service  
- Prometheus  
- Grafana  
- Ollama  
- SNMP trap receiver  
- Systemd services  

### Docker Version
Builds:

```
~/aimusubi-stack/
├── docker-compose.yml
├── aimusubi/
├── grafana/
├── prometheus/
└── logs/
```

Both paths create a complete, reproducible environment.

---

# 12. Internal Directory Layout

```
core/AIMusubi/
├── api/            # FastAPI entrypoint
├── adapters/       # Vendor-specific drivers
├── intents/        # Intent definitions + handlers
├── memory/         # SQLite memory and abstractions
├── metrics/        # Prometheus metric wrappers
└── utils/          # Common helpers

bootstrap/          # Installers
grafana/            # Dashboards
docs/               # Documentation
```

This structure keeps responsibilities clean and maintainable.

---

# 13. Future Architectural Directions

Planned improvements:

- Adapter plug-in architecture  
- YAML-based intent definitions  
- Event-driven flow engine (SNMP/telemetry triggers)  
- Topology engine (graph-based)  
- Multi-node API clustering  
- RBAC + credential vault (enterprise tier)  

---

# 14. Summary

AIMusubi’s architecture is:

- Clean  
- Transparent  
- Vendor-agnostic  
- Local-first  
- Built for labs and experimentation  

The design provides a strong foundation for future growth while remaining
simple enough for anyone to understand, modify, or extend.

For deeper dives:

👉 `agent_flow.md`  
👉 `adapters.md`  
👉 `intents_reference.md`  
