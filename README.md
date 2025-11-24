   
# AIMusubi – Local-First Agentic NetOps Framework

AIMusubi is a **local-first agentic automation framework** that brings LLM-driven
intent-based operations to **real network devices** — Cisco IOS-XE, Arista EOS,
and VyOS — through a unified API, reproducible bootstraps, and full-stack
observability.

This is a framework that becomes a **platform** when bootstrapped.

> If you want to see an LLM observe, decide, execute, and verify changes on
> actual routers in your own lab — AIMusubi is built for you.

---

## Why AIMusubi?

- **Local-first** – Runs entirely in your lab. Your devices, your data, your API.
- **Real devices** – Talks to Cisco, Arista, and VyOS using real APIs.
- **Unified intent engine** – Same operations across all vendors.
- **Agentic by design** – Built specifically for LLM tool-calling workflows.
- **Reproducible bootstraps** – One script builds the full environment.
- **Open-core** – Clean separation between lab framework and future enterprise tier.

---

## What You Get

AIMusubi installs an entire **Level-5 agentic NetOps stack**:

- **AIMusubi API (FastAPI)**
  - `/intent/exec`, `/openapi.json`, `/metrics`, `/health`
- **Vendor Adapters**
  - Cisco RESTCONF (YANG)
  - Arista eAPI (JSON-RPC)
  - VyOS REST/RESTCONF
- **Intent Engine**
  - Vendor-agnostic operations (`iface.list`, `routing.v4.rib`, `ospf.neigh`, etc.)
- **SQLite Memory**
  - Credentials, observations, evolving state
- **Observability**
  - Prometheus metrics + Grafana dashboards
- **LLM Frontend**
  - Open WebUI wired directly to AIMusubi’s OpenAPI schema

> **AIMusubi includes a full operator-grade toolchain (nmap, masscan, fping, SNMP utilities, DNS tools, traceroute, iproute2, etc.) so your environment has the same diagnostic visibility as a real NetOps workflow. Please use carefully and in a lab environment only**

All installed and wired together via **bare-metal** or **Docker** bootstrap.

---

## 🚀 Five-Minute Quickstart

> Full installation details live in `docs/`, but here’s the shortest path.

### 1. Clone the repo

```bash
git clone https://github.com/aimusubi/aimusubi.git
cd aimusubi
```

### 2. Choose a bootstrap

**Bare-metal (Ubuntu 22.04 / 24.04)**

```bash
chmod +x bootstrap/aimusubi_l5_fullstack_baremetal.sh
sudo ./bootstrap/aimusubi_l5_fullstack_baremetal.sh
```

**Docker stack**

```bash
chmod +x bootstrap/aimusubi_l5_fullstack_docker.sh
./bootstrap/aimusubi_l5_fullstack_docker.sh
```

### 3. Activate the system

Follow:

- `docs/post_bootstrap_activation.md`
- `docs/openwebui_setup.md`

Then open Open WebUI, select your LLM, and AIMusubi is ready for tool-calling.

---

## Who Is This For?

- **Network engineers** who want to experiment with LLM-driven NetOps  
- **Homelab builders** running multi-vendor topologies  
- **SRE / DevOps engineers** curious about agentic workflows  
- **Educators & students** learning real infrastructure automation  

AIMusubi is a **lab-first framework**, not a production change control system.

---

## Project Status

- **Version:** 1.0.0 (Open-Core Lab Release)  
- **Vendors:** Cisco IOS-XE, Arista EOS, VyOS  
- **OS Target:** Ubuntu (bare-metal) + Docker stack  
- **Security Model:** Local lab mode, self-signed certs accepted  

See:

- `docs/roadmap.md`
- `docs/ARCHITECTURE.md`

---

## Documentation

Start here:

- `docs/overview.md`
- `docs/installation_baremetal.md`
- `docs/installation_docker.md`
- `docs/post_bootstrap_activation.md`
- `docs/openwebui_setup.md`
- `docs/adapters.md`
- `docs/intents_reference.md`

---

## Community & Links

👉 **Join the MusubiAG Discord Community**  
https://discord.gg/xAeXxM5f

- **YouTube – The Agentic Engineer**  
- **GitHub Issues** – bugs, ideas, suggestions  
- **Roadmap** – `docs/roadmap.md`

---

## Contributing

Contributions are welcome — adapters, intents, dashboards, docs, improvements.

See:

- `CONTRIBUTING.md`
- `docs/CHANGELOG.md`

If AIMusubi helps you build, learn, or think differently about NetOps, that’s the mission.
