# AIMusubi – Roadmap (v1.0 → v2.x and Beyond)

This roadmap outlines the evolution of AIMusubi from the current **v1.0 open-core**
release into future lab, team, and enterprise editions.  
It provides transparent expectations for features, stability, vendor expansion,
and architecture improvements.

AIMusubi starts as a **lab-first, local-first, agentic framework** —
simple by design, powerful in potential.

---

# 1. Current Stage (v1.0) – Open-Core Lab Framework

### Goals Achieved
- Full-stack bootstrap (bare-metal + Docker)
- AIMusubi API with standardized intent engine
- Adapters for Cisco IOS-XE, Arista EOS, VyOS
- Unified intent model (`iface.list`, `routing.v4.rib`, `ospf.neigh`, etc.)
- Open WebUI integration (tool-calling)
- Prometheus + Grafana integration
- SQLite memory/state (observations, credentials, metadata)
- SNMP trap receiver + OPA (foundational)
- Documentation suite

### Focus Areas
- Reliability in lab environments  
- Simplicity for new users  
- Clean architecture and transparency  
- Reproducible deployment through bootstraps  

---

# 2. v1.1 – v1.4 (Short-Term Enhancements)

These improvements refine the open-core experience without expanding scope too quickly.

### Planned Enhancements
- More robust adapter error handling
- More detailed interface parsing (e.g., counters, duplex, speed)
- Additional intents:
  - IPv6 routing (`routing.v6.rib`)
  - BGP summary (`bgp.summary`)
  - Interface statistics (`iface.counters`)
- Stronger adapter autodetection
- Prometheus metrics expansion:
  - Intent latency histograms per vendor
  - Adapter error counters
- More Grafana dashboards:
  - Device reachability
  - LLM → API tool-call metrics
  - Per-vendor success ratio

### Developer Improvements
- Better logging hooks
- Cleaner adapter registry
- Simplified device configuration templates

---

# 3. v2.x – Advanced Lab + Team Edition

This stage introduces multi-device workflows and collaboration features.

### Key Features
- Policy execution via OPA (intent validation)
- Event-driven triggers using SNMP traps
- AIMusubi "Playbooks":
  - Multi-step workflows
  - Example: interface flap → diagnose → run OSPF/RIB summary
- Role-based workspaces in Open WebUI
- Snapshot/restore of AIMusubi state
- Smoother adapter configuration via YAML manifests
- More robust error semantics for LLMs

### Collaborator Support
- Shared device profiles
- Shared credentials vault (encrypted)
- Multi-user access in a homelab or small team

---

# 4. Enterprise Direction (Long-Term Vision)

These features are **not** targeted for open-core, but for a future enterprise tier.

### Enterprise-Level Capabilities
- RBAC (role-based access control)
- Topology engine:
  - L2/L3 discovery
  - Service graph
  - Path mapping
- Clustered AIMusubi API nodes
- High availability (HA)
- Audit logging + event correlation
- FinOps + cost telemetry (cloud + L2 overlays)
- Production-grade credential vaulting
- Multi-tenant isolation
- Ticketing/ITSM system integration
- Automated configuration remediation loops

### Why Enterprise?
To maintain:
- A clean open-core project for experimentation  
- A sustainable business model for long-term development  
- A clear separation of concerns (education vs production automation)

---

# 5. Vendor Expansion

Future releases may expand adapters to support:

- Juniper (NETCONF/REST)
- Fortinet (REST API)
- Palo Alto PAN-OS
- Cumulus Linux
- Linux hosts via `ip`/FRR APIs
- Cloud VNFs (AWS, GCP, Azure virtual routers)

Adapters will adopt a plug-in architecture to make this process easier.

---

# 6. Documentation + Community

### Documentation Enhancements
- Architecture deep dive
- Adapter development guide
- Intent development guide
- Troubleshooting playbook
- Contributor onboarding

### Community Features
- Examples directory (playbooks, scenarios)
- Reference labs
- Video walkthroughs
- Discussion boards

---

# 7. Philosophy and Guiding Principles

AIMusubi follows a few key principles:

### **Transparency over abstraction**
Every step should be inspectable and human-understandable.

### **Local-first**
Your lab, your hardware, your API — no cloud required.

### **Vendor-agnostic behavior**
Adapters normalize vendor-specific quirks.

### **Agentic but controlled**
LLMs do not guess — AIMusubi enforces reality via tools.

### **Open-core, community-driven**
Encourages experimentation and contribution.

---

# 8. Summary

AIMusubi’s roadmap balances:

- A stable, transparent open-core foundation  
- Real vendor support  
- A growing intent catalog  
- A path toward automation and agentic behavior  
- A long-term enterprise vision  

The project moves deliberately — focusing first on clarity, reliability, and
educational value before scaling into heavy enterprise features.

For active development details:

👉 Follow updates in the GitHub repo  
👉 Contribute via issues and PRs  
