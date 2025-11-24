# AIMusubi – Changelog

All notable changes to this project will be documented in this file.  
This adheres to **Semantic Versioning (SemVer)**:

```
MAJOR.MINOR.PATCH
```

---

# [1.0.0] – 2025-02-XX  
### Initial Open-Core Release

This is the first fully defined open-core release of AIMusubi, providing a complete lab framework for agentic NetOps experimentation.

### **Core Features**
- AIMusubi API (FastAPI)
- Unified intent engine
- Adapter layer:
  - Cisco IOS-XE (RESTCONF)
  - Arista EOS (eAPI JSON-RPC)
  - VyOS (REST/RESTCONF)
- Normalized output schemas for all vendors
- SQLite memory/state subsystem
- Prometheus metrics endpoint (`/metrics`)
- Full OpenAPI schema (`/openapi.json`)

### **Bootstrap**
- Bare-metal installer (Ubuntu 22.04+ / 24.04)
- Docker installer with unified `docker-compose.yml`
- Automatic setup of:
  - Python venv
  - Prometheus
  - Grafana (with AIMusubi dashboards)
  - Open WebUI
  - Ollama (optional)
  - SNMP trap receiver

### **Documentation**
- Complete docs/ tree:
  - Installation (bare-metal + Docker)
  - Post-bootstrap activation
  - Open WebUI setup
  - Lab environment prep
  - Intent reference
  - Adapter guide
  - Agent flow
  - Architecture guide
  - FAQ
  - Roadmap
  - Contributing instructions

### **Grafana Dashboards**
- API metrics overview
- Adapter latency insights
- Intent success/failure visualizations

### **LLM Integration**
- Full Open WebUI tooling support via `openapi.json`
- Clean separation between:
  - LLM reasoning
  - Device operations
- Enforced tool-calling for network interactions

### **Security Model**
- Lab-mode (self-signed cert support)
- Local-first operation
- Credentials stored in SQLite memory

---

# Future Releases

Future versions will follow the roadmap outlined in:

👉 `docs/roadmap.md`

Planned additions include:

- Additional intents (IPv6 RIB, BGP, counters)
- Improved adapter error handling
- More vendor support
- Playbooks and event-driven workflows
- Advanced observability
- Enterprise-grade extensions (in separate tier)

---

# Versioning Policy

AIMusubi follows these principles:

- **MAJOR**: Breaking changes to architecture or interfaces  
- **MINOR**: New intents, adapters, dashboards, or improvements  
- **PATCH**: Bug fixes, documentation updates, minor enhancements  

---

# Summary

This `CHANGELOG.md` represents the foundation of AIMusubi as an open-core,
local-first agentic framework for NetOps experimentation.  
Each future update will be documented here to maintain transparency and trust.

