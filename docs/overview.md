# AIMusubi Overview

AIMusubi is a **local-first, full-stack agentic NetOps framework** that connects an LLM to *real* network devices through a unified intent API.

It is designed as a **learning and experimentation platform** for network engineers who want to explore Level-5 style “observe → plan → execute → verify” automation – without depending on a cloud SaaS controller.

---

## What AIMusubi Gives You

AIMusubi installs an entire stack:

- **AIMusubi API (FastAPI)**  
  - Unified intent engine (`iface.list`, `routing.v4.rib`, `ospf.neigh`, etc.)
  - Vendor adapters for Cisco IOS-XE, Arista EOS, and VyOS

- **Device Adapters**  
  - Cisco IOS-XE via RESTCONF (YANG)
  - Arista EOS via eAPI (JSON-RPC)
  - VyOS via REST/RESTCONF (depending on platform support)

- **Local Memory / State**  
  - SQLite database (`state.db`) for:
    - Observations
    - Credentials
    - Adapter metadata
    - Polling configuration
    - Experiment logs

- **Observability**  
  - Prometheus scraping AIMusubi metrics
  - Grafana with pre-built “AIMusubi Overview” dashboard

- **LLM Front-End**  
  - Open WebUI running locally
  - Optional local model via Ollama (e.g., `llama3`)
  - Optional connection to external LLMs (Gemini, etc.)

- **Policy and Events (Foundation)**  
  - OPA ready for future intent/policy checks
  - SNMP trap receiver for lab event capture

> **AIMusubi also includes real NetOps operator tools (nmap, masscan, fping, SNMP utilities, DNS tools, traceroute, iproute2, etc.) to ensure your lab behaves like a realistic operational network environment.**
---

## Typical Lab Flow

A simple lab flow looks like this:

1. You deploy Cisco / Arista / VyOS devices in a lab (GNS3, EVE-NG, KVM, etc.).
2. You enable RESTCONF / eAPI / REST on each device.
3. You run the AIMusubi bootstrap (bare-metal or Docker).
4. You wire Open WebUI to AIMusubi as a tool.
5. You ask the LLM things like:

   > "Use AIMusubi to list all interfaces on `router1.lab.local` and show which ones are admin-down."

6. AIMusubi:
   - Calls the correct adapter
   - Talks to the device API
   - Returns structured JSON
   - Exposes metrics to Prometheus
   - Shows activity on the Grafana dashboard

All device responses are **live**. AIMusubi does not fabricate interface states or routing tables.

---

## Who This Is For

AIMusubi is built for:

- Network engineers who want to experiment with LLMs in a **real lab**
- Homelab builders who want a **local-first agentic stack**
- SRE / DevOps / NetDevOps engineers exploring **intent-based operations**
- Anyone curious how to move from “LLM in a browser” to “LLM controlling infrastructure (safely)”

It is **not**:

- A finished NOC product
- A one-click “fix my network” appliance
- A replacement for existing controllers

It *is*:

- A transparent framework
- A reproducible full-stack lab
- A foundation to build your own NetOps agent

---

## Key Documents

Start here:

- [Bare-metal Installation](installation_baremetal.md)
- [Docker Installation](installation_docker.md)
- [Post-Bootstrap Activation](post_bootstrap_activation.md)
- [Open WebUI Setup](openwebui_setup.md)
- [Lab Environment](lab_environment.md)
- [Adapters](adapters.md)
- [Intents Reference](intents_reference.md)
- [Agent Flow](agent_flow.md)
- [FAQ](faq.md)
- [Roadmap](roadmap.md)
