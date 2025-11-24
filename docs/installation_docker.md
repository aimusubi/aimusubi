# AIMusubi – Docker Installation Guide

This guide covers installing AIMusubi on any Linux host using **Docker** and **Docker Compose**.

Docker installation provides:
- Faster setup
- Easier teardown/rebuild
- Portability across environments
- No dependency pollution on the host OS

This is the recommended method for most users who are not running a dedicated Ubuntu lab VM.

---

# 1. System Requirements

- **OS:** Any modern Linux distribution (Ubuntu, Debian, CentOS, Rocky, etc.)
- **CPU:** 2 vCPUs or more
- **RAM:** 8–10 GB recommended
- **Storage:** 40–80 GB free
- **Docker:** Required
- **Docker Compose:** Required

Optional:
- **GPU:** NVIDIA GPU with drivers + Docker GPU toolkit for accelerated local LLMs

---

# 2. Install Docker & Docker Compose

On Ubuntu:

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin git
sudo usermod -aG docker $USER
# Log out and back in
```

Verify:

```bash
docker --version
docker compose version
```

---

# 3. Clone AIMusubi

```bash
git clone https://github.com/aimusubi/aimusubi.git
cd aimusubi
```

---

# 4. Make the Docker Bootstrap Executable

```bash
chmod +x bootstrap/aimusubi_l5_fullstack_docker.sh
```

---

# 5. Run the Bootstrap Script

This script creates the **full AIMusubi Docker stack** in `~/aimusubi-stack`.

```bash
./bootstrap/aimusubi_l5_fullstack_docker.sh
```

It will generate:

```
~/aimusubi-stack/
├── docker-compose.yml
├── .env
├── aimusubi/           # API, adapters, intents
├── grafana/            # dashboards + datasources
├── prometheus/         # scrape configs
└── logs/
```

---

# 6. Start the Stack

```bash
cd ~/aimusubi-stack
docker compose up -d
```

Check container status:

```bash
docker compose ps
```

You should see containers such as:

- `aimusubi-api`
- `prometheus`
- `grafana`
- `open-webui`
- `ollama` (optional)

---

# 7. Access the AIMusubi Stack

| Component        | URL                            |
|-----------------|--------------------------------|
| AIMusubi API    | http://127.0.0.1:5055          |
| Open WebUI      | http://127.0.0.1:8081          |
| Grafana         | http://127.0.0.1:3000          |
| Prometheus      | http://127.0.0.1:9090          |

These ports can be changed in `.env` before starting the stack.

---

# 8. Verify the API

```bash
curl http://127.0.0.1:5055/health
```

Expected:

```json
{
  "ok": true,
  "status": "up"
}
```

Logs for deeper debugging:

```bash
docker compose logs -f aimusubi-api
```

---

# 9. Stopping / Restarting / Rebuilding

Stop:

```bash
docker compose down
```

Restart:

```bash
docker compose up -d
```

Full rebuild:

```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

---

# 10. Logs

Tail all logs:

```bash
docker compose logs -f
```

Tail a specific component:

```bash
docker compose logs -f open-webui
docker compose logs -f grafana
docker compose logs -f prometheus
docker compose logs -f aimusubi-api
```

---

# 11. Next Steps

After a successful Docker deployment:

### ✔ Configure your network devices  
See `lab_environment.md`

### ✔ Connect Open WebUI to AIMusubi  
See `openwebui_setup.md`

### ✔ Run your first live intent  
See `post_bootstrap_activation.md`

---

# 12. Troubleshooting

### **API container crashes**
- Run: `docker compose logs aimusubi-api`
- Check Python dependency issues
- Ensure ports 5055/8081/3000/9090 are not in use

### **Open WebUI failing to connect to AIMusubi**
- Confirm tool added using: `http://127.0.0.1:5055/openapi.json`
- Ensure the API container is reachable from Docker network

### **Devices unreachable**
- Ensure device management IPs are reachable from the Docker host
- Confirm HTTPS API services enabled on each router

---

# 13. Summary

Docker installation gives you a fully containerized agentic NetOps environment, including:

- AIMusubi API  
- All adapters  
- Local memory  
- Prometheus + Grafana  
- Open WebUI  
- Optional Ollama LLM backend  

This installation is ideal for rapid testing and for isolating AIMusubi from host dependencies.

Proceed next to:

👉 `post_bootstrap_activation.md`
