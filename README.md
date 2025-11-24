# AIMusubi – Local-First Agentic NetOps Framework

**AIMusubi** is a local-first, full-stack agentic automation framework for real network labs.  
It connects an LLM to **actual devices** – Cisco IOS-XE, Arista EOS, and VyOS – through a unified intent API, backed by observability, memory, and a reproducible bootstrap.

> If you want to see an LLM *observe, decide, and act* on real routers in your own lab – this is for you.

---

## Why AIMusubi?

- **Local-first** – Runs entirely in your lab. Your devices, your data, your API.
- **Real devices, not simulations** – Talks to Cisco, Arista, and VyOS using real network APIs.
- **Unified intent engine** – One set of intents across vendors (`iface.list`, `routing.v4.rib`, `ospf.neigh`, etc.).
- **Agentic by design** – Built to let LLMs reason, call tools, and verify changes – not just print configs.
- **Reproducible bootstraps** – One script for bare-metal, one for Docker. No hand-assembling stacks.
- **Open-core** – Clean separation between lab-friendly open core and future enterprise features.

---

## What You Get

AIMusubi installs an **entire L5 agentic stack** on your hardware:

- **AIMusubi API (FastAPI)**
  - `/intent/exec` unified intent endpoint
  - `/metrics` Prometheus metrics
  - `/openapi.json` for LLM tool-calling

- **Adapters for Real Devices**
  - Cisco IOS-XE via RESTCONF (YANG)
  - Arista EOS via eAPI (JSON-RPC)
  - VyOS via REST/RESTCONF (version-dependent)

- **Memory + State (SQLite)**
  - Device credentials
  - Observations / metadata
  - Room to grow into drift tracking

- **Observability**
  - Prometheus scraping AIMusubi metrics
  - Grafana dashboards for API + adapter behavior

- **LLM Frontend**
  - Open WebUI wired directly to AIMusubi’s OpenAPI schema
  - Ready for local Llama via Ollama or external models via API

All of this is built and wired by the **bootstrap scripts**.

---

## Quickstart

> Full details live in `docs/`, but this is the 10,000-ft view.

### 1. Clone the repo

```bash
git clone https://github.com/aimusubi/aimusubi.git
cd aimusubi
```

### 2. Choose your path

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

Each script installs:

- AIMusubi API service  
- Open WebUI  
- Prometheus & Grafana  
- Ollama (optional local LLM)  
- Systemd services / Docker compose stack  

Then follow:

- `docs/post_bootstrap_activation.md`
- `docs/openwebui_setup.md`

to connect your LLM and start issuing intents.

---

## Who Is This For?

AIMusubi is designed for:

- **Network engineers** who want to experiment with intent-based/LLM-driven NetOps.
- **Homelab builders** who enjoy real multi-vendor labs with observability and automation.
- **SRE / DevOps / platform engineers** curious about agentic workflows touching real infrastructure.
- **Educators / mentors** who want a concrete, local environment to teach AI-Ops concepts.

This is a **lab-first framework**, not a shrink-wrapped product.

---

## Project Status

- **Version:** 1.0.0 (open-core lab release)  
- **Focus:** Realistic, reproducible labs – *not* production change control  
- **Vendors:** Cisco IOS-XE, Arista EOS, VyOS  
- **OS target:** Ubuntu 22.04 / 24.04 (bare-metal bootstrap), plus Docker variant

See:

- `docs/roadmap.md` – where this is going  
- `docs/ARCHITECTURE.md` – how it’s built  

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

- **YouTube (The Agentic Engineer):** walkthroughs and demos of AIMusubi in action  
- **Discord:** MusubiAG Community server for questions, labs, and build-with-me sessions  
- **Issues:** Bug reports and feature requests via GitHub Issues  
- **Roadmap:** `docs/roadmap.md`

---

## Contributing

Contributions are welcome – docs, adapters, intents, dashboards, examples.

- See `docs/CONTRIBUTING.md` for guidelines.
- See `docs/CHANGELOG.md` for release history.

If AIMusubi helps you learn, build, or think differently about NetOps, that’s the mission.
