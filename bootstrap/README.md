# AIMusubi – Local-First Agentic NetOps Framework  
**Version: 1.0**  
**Release Date: 2025-11-23**

AIMusubi is a **local-first** agentic NetOps **framework** that becomes a full **platform** when bootstrapped with its open-core stack.. It connects an LLM to *actual* network devices — Cisco IOS-XE, Arista EOS, and VyOS — through a unified intent API, backed by observability, memory, and a reproducible bootstrap system.

AIMusubi is open-core, transparent, and built for engineers who want to **experiment, learn, and build** agentic operations from the ground up.

<p align="center">
  <img src="(optional-your-image)" width="640"/>
</p>

---

# 🚀 What AIMusubi Provides

AIMusubi installs an entire L5 agentic stack on your hardware:

### ✔ **AIMusubi API (FastAPI)**
Unified intent engine across Cisco, Arista, and VyOS:
- `iface.list`, `iface.admin-up`, `iface.admin-down`
- `routing.v4.rib`
- `ospf.neigh`
- `cpu.util`, `mem.stats`
- vendor-specific adapters (RESTCONF, eAPI, REST)

### ✔ **Adapters for Real Devices**
- **Cisco IOS-XE** via RESTCONF (YANG models)
- **Arista EOS** via eAPI (JSON-RPC)
- **VyOS** via REST/RESTCONF (depending on version)

### ✔ **Memory + State**
SQLite `state.db` stores:
- Observations  
- Credentials  
- Adapter metadata  
- Poll specs  
- Reinforcement feedback for agent behavior  

### ✔ **Observability Stack**
Installed and pre-wired:
- **Prometheus** scraping AIMusubi metrics  
- **Grafana** with the `AIMusubi Overview` dashboard  
- Intent latency, API hit rate, error metrics, agent level states  

### ✔ **LLM Integration (Local or External)**
AIMusubi integrates natively with **Open WebUI**, giving you:
- Local LLM (Ollama + llama3)  
- External LLM (Gemini, OpenAI, Anthropic, etc.)  
- Full tool-calling via `/openapi.json`  

### ✔ **SNMP + Policy Foundation**
- SNMP trap handler → logs into `logs/snmptraps.log`  
- OPA running for future policy enforcement

### ✔ **NetOps Toolchain**
- nmap, masscan, fping, SNMP utilities, DNS tools, traceroute, iproute2, etc  
- Accessible workflow on request via the LLM  

### ✔ **Bare-Metal or Docker Deployment**
Both are fully supported through one-command bootstraps.

---

# 📦 Project Structure

```
aimusubi/
├── bootstrap/                   # Baremetal and Docker installers
├── core/
│   └── AIMusubi/                # API, adapters, intents, loop, memory
├── docs/                        # Full documentation set
├── grafana/
│   ├── dashboard/               # Prebuilt dashboards
│   └── datasources/             # Prometheus datasource config
├── LICENSE                      # Apache 2.0
└── README.md                    # You are here
```

---

# 🛠️ Installation (Bare-Metal)

**Supported OS:** Ubuntu 22.04 / 24.04 (recommended)

```bash
chmod +x bootstrap/aimusubi_l5_fullstack_baremetal.sh
sudo ./bootstrap/aimusubi_l5_fullstack_baremetal.sh
```

What this script installs:

- Python3, venv, dependencies  
- Prometheus + Grafana  
- Open WebUI  
- Ollama + llama3  
- AIMusubi API (FastAPI)  
- Adapters (Cisco / Arista / VyOS)  
- SNMP trap agent
- NetOps Toolschain 
- OPA  
- Systemd services  

After install:

- AIMusubi API → http://127.0.0.1:5055  
- Open WebUI → http://127.0.0.1:8081  
- Grafana → http://127.0.0.1:3000  
- Prometheus → http://127.0.0.1:9090  

---

# 🐳 Installation (Docker)

```bash
chmod +x bootstrap/aimusubi_l5_fullstack_docker.sh
./bootstrap/aimusubi_l5_fullstack_docker.sh
```

This creates:

```
~/aimusubi-stack/
├── docker-compose.yml
├── .env
├── prometheus/
├── grafana/
└── aimusubi/ (api.py + adapters + intents)
```

Then start:

```bash
cd ~/aimusubi-stack
docker compose up -d
```

---

# 🔧 Post-Bootstrap Activation

After installation, you’ll connect Open WebUI to AIMusubi:

1. Open WebUI → http://127.0.0.1:8081  
2. Admin → **Connections**  
   - Add local LLM (Ollama)  
   - OR external provider (Gemini / OpenAI)  
3. Admin → **Tools**  
   - Add tool: `http://127.0.0.1:5055/openapi.json`  
4. Workspace  
   - Choose model  
   - Add AIMusubi tool  
   - Add system prompt  
5. Validate with:  
   - “Use the AIMusubi tool to call `/health`.”  

Full details:  
👉 `docs/post_bootstrap_activation.md`

---

# 🧪 Example: Running a Real Intent

Ask the model:

> “Use the AIMusubi tool to run `iface.list` on router1.”

AIMusubi will:
- Execute adapter-level RESTCONF/eAPI calls  
- Log everything in journalctl or docker logs  
- Return structured JSON to the LLM  
- Feed observability metrics into Prometheus  

This is *not simulated output*.  
All responses come directly from your devices.

---

# 🧬 Supported Vendors (v1.0)

| Vendor       | Protocol  | Notes                                 |
|--------------|-----------|----------------------------------------|
| Cisco IOS-XE | RESTCONF  | YANG-based operational + config        |
| Arista EOS   | eAPI      | JSON-RPC, secure or insecure modes     |
| VyOS         | REST      | RESTCONF depending on version          |

You can extend vendors easily via `core/AIMusubi/adapters`.

---

# 📡 Lab Requirements

AIMusubi expects:
- Cisco/Arista/VyOS reachable over HTTPS  
- RESTCONF/eAPI enabled (docs include starter configs)  
- Basic credentials (saved securely in SQLite)

Hardware reference build:
- 2 vCPUs (8th-gen i7 virtual cores)  
- 10 GB RAM  
- 80 GB SSD  
- GTX 1050 Ti (for local LLM)  

Full details:  
👉 `docs/lab_environment.md`

---

# 🧩 Extending AIMusubi

You can extend the framework by:

- Adding **new adapters**  
- Adding **new intents**  
- Expanding **loop logic**  
- Adding **policy checks** via OPA  
- Adding **dashboards** in Grafana  
- Creating **automation tasks** in `/tools`  

This is an open-core project — the platform is yours to grow.

---

# 🗺️ Roadmap

Short-term:
- More YANG models  
- More adapter coverage  
- Additional intents  
- Deeper Grafana dashboards  
- Improved WebUI tooling  

Long-term (Enterprise tier):
- RBAC  
- Topology engine  
- FinOps & cost telemetry  
- Clustered multi-agent operation  
- Advanced remediation scoring  

See:  
👉 `docs/roadmap.md`

---

# 📄 License

AIMusubi is released under the **Apache License 2.0**.  
This allows free use, modification, and commercial extensions.

---

# 🎥 Learn More

A full walkthrough and live demo is available on YouTube:

👉 *(Add your Episode 1 Link here)*

---

# 🙌 Contributing

Contributions are welcome.  
See:  
👉 `CONTRIBUTING.md`

---

# 🤝 Acknowledgments

This project represents hundreds of hours of hands-on work with real network devices and LLM experimentation. If AIMusubi helps you learn, build, or think differently — that’s the mission.

