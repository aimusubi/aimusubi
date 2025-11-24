# AIMusubi – Bare-Metal Installation Guide

This guide covers installing AIMusubi directly on a clean **Ubuntu** system.

> **Validated OS:**  
> - Ubuntu 22.04 LTS  
> - Ubuntu 24.04 LTS  
>
> Other Debian-based systems may work but are not officially tested.

---

# 1. System Requirements

Reference hardware from the development environment:

- **CPU:** 2 vCPUs (8th-gen Intel i7 virtual cores or similar)
- **RAM:** 10 GB
- **Storage:** 80 GB SSD
- **GPU (optional):** NVIDIA GTX 1050 Ti (4 GB VRAM) for local LLM via Ollama
- **Network:** Devices reachable over HTTPS (RESTCONF / eAPI / REST)

AIMusubi is resource-efficient, but depending on your LLM choice, RAM/GPU needs may vary.

---

# 2. Clone the Repository

```bash
git clone https://github.com/aimusubi/aimusubi.git
cd aimusubi
```

---

# 3. Make the Bootstrap Executable

```bash
chmod +x bootstrap/aimusubi_l5_fullstack_baremetal.sh
```

This script installs the **entire AIMusubi stack**:

- AIMusubi API (FastAPI)
- Adapters (Cisco IOS-XE, Arista EOS, VyOS)
- Prometheus
- Grafana
- Open WebUI
- Ollama + `llama3` model
- SNMP trap receiver
- Netops operator toolchain
- OPA (policy engine foundation)
- Systemd services for all components
- Required Python environment + dependencies

---

# 4. Run the Bootstrap

```bash
sudo ./bootstrap/aimusubi_l5_fullstack_baremetal.sh
```

> **Important:**  
> This script is designed for a dedicated lab host or VM.  
> It installs system-level services and packages.

During installation you will see:

- Grafana APT repo setup  
- Python venv creation  
- pip dependency installation  
- AIMusubi directory creation under `$AIMUSUBI_HOME`  
- Systemd service registration  
- Prometheus + Grafana provisioning  

At completion you should see:

```
[ OK ] Started aimusubi-api.service
[ OK ] Started grafana-server.service
[ OK ] Started prometheus.service
[ OK ] Started open-webui.service
```

---

# 5. Validate Installation

Check the API:

```bash
curl http://127.0.0.1:5055/health
```

Expected JSON:

```json
{
  "ok": true,
  "status": "up"
}
```

Check systemd services:

```bash
sudo systemctl status aimusubi-api
sudo systemctl status open-webui
sudo systemctl status grafana-server
sudo systemctl status prometheus
sudo systemctl status ollama
```

All should show: **active (running)**.

---

# 6. Access the Platform

After installation:

| Component        | URL                            |
|-----------------|--------------------------------|
| AIMusubi API    | http://127.0.0.1:5055          |
| Open WebUI      | http://127.0.0.1:8081          |
| Grafana         | http://127.0.0.1:3000          |
| Prometheus      | http://127.0.0.1:9090          |

Grafana credentials are provided during bootstrap.

---

# 7. Log Monitoring

AIMusubi API logs (critical for debugging):

```bash
sudo journalctl -u aimusubi-api -f
```

Open WebUI logs:

```bash
sudo journalctl -u open-webui -f
```

Prometheus and Grafana:

```bash
sudo journalctl -u prometheus -f
sudo journalctl -u grafana-server -f
```

SNMP Trap receiver:

```bash
sudo journalctl -u snmptrapd -f
```

---

# 8. Next Steps

After a successful bare-metal installation:

### ✔ Configure your devices  
Enable RESTCONF/eAPI/REST depending on vendor.  
See: `lab_environment.md`

### ✔ Wire Open WebUI to AIMusubi  
Set up connections and tools.  
See: `openwebui_setup.md`

### ✔ Activate the platform  
Run your first `/health` and `iface.list` intents.  
See: `post_bootstrap_activation.md`

---

# 9. Updating or Reinstalling

To wipe and rebuild:

```bash
sudo systemctl stop aimusubi-api
sudo rm -rf $AIMUSUBI_HOME
```

Then rerun the bootstrap:

```bash
sudo ./bootstrap/aimusubi_l5_fullstack_baremetal.sh
```

---

# 10. Troubleshooting

### **API not responding**
```bash
sudo systemctl status aimusubi-api
sudo journalctl -u aimusubi-api -f
```

### **Open WebUI not loading**
```bash
sudo systemctl status open-webui
```

### **Cannot reach devices**
- Verify HTTPS reachability  
- Check credentials  
- Confirm RESTCONF/eAPI enabled  

### **LLM not issuing tool calls**
- Strengthen the system prompt  
- Ensure AIMusubi tool is enabled in the workspace  

---

# 11. Summary

Bare-metal installation provides a full, local, self-contained agentic NetOps lab including:

- API  
- Adapters  
- Local memory  
- Prometheus + Grafana  
- Open WebUI  
- LLM backend  
- SNMP + OPA foundations  

Once installed, your next step is to connect devices and run your first live intents.

👉 Proceed to: `post_bootstrap_activation.md`
