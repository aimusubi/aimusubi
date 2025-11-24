# AIMusubi – Post-Bootstrap Activation Guide

This guide walks you through **activating AIMusubi immediately after installation**  
(bare‑metal or Docker). It ensures all core services are running, devices are reachable,  
and the AIMusubi API is ready for live intents.

---

# 1. Validate System Services

## Bare-Metal
```bash
sudo systemctl status aimusubi-api
sudo systemctl status open-webui
sudo systemctl status prometheus
sudo systemctl status grafana-server
sudo systemctl status ollama
```

## Docker
```bash
cd ~/aimusubi-stack
docker compose ps
```

You should see **running** for:

- aimusubi-api  
- open-webui  
- prometheus  
- grafana  
- ollama (optional)

---

# 2. Verify the AIMusubi API Is Alive

```bash
curl http://127.0.0.1:5055/health
```

Expected output:

```json
{
  "ok": true,
  "status": "up"
}
```

If you see `"ok": false`, check logs:

### Bare-Metal
```bash
sudo journalctl -u aimusubi-api -f
```

### Docker
```bash
docker compose logs -f aimusubi-api
```

---

# 3. Confirm Prometheus + Grafana Startup

## Prometheus
```bash
curl http://127.0.0.1:9090/-/ready
```

Expect:
```
Prometheus is Ready.
```

## Grafana
Open: http://127.0.0.1:3000

Login:  
- **admin / admin** (unless changed by bootstrap)

Check dashboards:

- `AIMusubi – API Metrics`
- `AIMusubi – LLM Interaction`

If dashboards appear, observability is active.

---

# 4. Load AIMusubi Intent Catalog

List available intents:

```bash
curl http://127.0.0.1:5055/intent/list
```

You should see entries like:

```json
{
  "iface.list": {},
  "iface.admin-up": {},
  "iface.admin-down": {},
  "routing.v4.rib": {},
  "ospf.neigh": {},
  "cpu.util": {},
  "mem.stats": {}
}
```

If empty → API did not load manifests.

Check:

```bash
ls $AIMUSUBI_HOME/manifests
```

---

# 5. Configure Device Credentials

AIMusubi stores runtime device credentials in **SQLite memory state**.

To add credentials:

```bash
curl -X POST http://127.0.0.1:5055/device/credentials   -H "Content-Type: application/json"   -d '{
        "host": "router1.lab.local",
        "username": "lab",
        "password": "lab123"
      }'
```

Verify saved credentials:

```bash
curl http://127.0.0.1:5055/device/list
```

Expected:

```json
[
  {
    "host": "router1.lab.local",
    "username": "lab"
  }
]
```

AIMusubi will automatically use these values for any live intent.

---

# 6. Test Device Reachability

Before running any intent, ensure your AIMusubi host can reach the router.

### Cisco IOS-XE (RESTCONF)
```bash
curl -k https://router1.lab.local/restconf/data
```

### Arista EOS (eAPI JSON-RPC)
```bash
curl -k https://router2.lab.local/command-api
```

### VyOS (REST)
```bash
curl -k https://router3.lab.local/configuration
```

If these return *any* JSON → the router is reachable.

If they fail:

- Check routing/table on AIMusubi host
- Confirm HTTPS is enabled on device
- Verify ACLs/firewalls

---

# 7. First Live Intent: Interface List

Now run your first real device pull:

```bash
curl -X POST http://127.0.0.1:5055/intent/exec   -H "Content-Type: application/json"   -d '{
        "intent": "iface.list",
        "params": {
          "host": "router1.lab.local"
        }
      }'
```

Expected output (sanitized example):

```json
{
  "result": [
    {
      "name": "GigabitEthernet1",
      "admin_status": "up",
      "oper_status": "up",
      "ipv4": "10.1.1.1/24"
    }
  ]
}
```

If you see `"500 Internal Server Error"`:

- Device credentials incorrect  
- Device does not support required API  
- RESTCONF/eAPI endpoint unreachable  

Check logs for exact traceback.

---

# 8. Observe Live API Activity

Use the log tail to confirm tool execution:

### Bare-Metal
```bash
sudo journalctl -u aimusubi-api -f
```

### Docker
```bash
docker compose logs -f aimusubi-api
```

You should see lines like:

```
INFO Executing intent iface.list for host router1.lab.local
INFO HTTP Request → https://router1.lab.local/restconf/...
INFO Success 200 OK
```

This is your real-time ground truth.

---

# 9. Grafana Verification (Optional but Recommended)

Open the dashboard:
http://127.0.0.1:3000/d/AIMUSUBI/aimusubi-api-metrics

You should now see:

- Request rate increasing  
- Success / failure counts  
- Latency graphs  
- LLM-to-API tool call metrics  

If empty → Prometheus scrape configs may be wrong.

---

# 10. AIMusubi Is Now Activated

At this point, all components are validated:

✔ API running  
✔ Prometheus/Grafana wired  
✔ Adapters active  
✔ Device credentials loaded  
✔ First live intent successful  
✔ Logs flowing  

You are ready for LLM-driven workflows.

Proceed to:

👉 `openwebui_setup.md`

