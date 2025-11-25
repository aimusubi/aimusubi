# AIMusubi – Frequently Asked Questions (FAQ)

This FAQ covers the most common questions about installing, running, and using AIMusubi,
as well as questions about LLM behavior, device interaction, and roadmap direction.

---

# 1. General Questions

## **What is AIMusubi?**
AIMusubi is a **local-first agentic NetOps framework** that connects an LLM
(Open WebUI + your chosen model) to real network devices using a unified intent API.

It is designed for:
- Labs
- Homelabs
- Learning
- Experimentation
- Agentic research
- Early-stage NetOps automation

Not for production use (yet).

---

## **Is this production-ready?**
No.  
AIMusubi v1.0 is a **lab-grade project**, meant for:

- Experiments  
- Demos  
- Training  
- Prototyping  

It is not hardened for production NOC environments.

---

## **Does AIMusubi require the cloud?**
No.

AIMusubi is **local-first**:

- Runs entirely on your machine
- Works offline
- Optional external LLM integration
- Core stack is self-contained

You can air‑gap the environment after bootstrapping.

---

## **Does AIMusubi fabricate device data?**
AIMusubi itself **never** fabricates data.

However, an LLM *can* hallucinate if:

- It ignores the AIMusubi tool  
- It misinterprets JSON  
- The system prompt is weak  
- The workspace isn't configured correctly  

To minimize this:
- Enforce tool usage via system prompt  
- Begin queries with “Use the AIMusubi tool to…”  
- Keep API logs open when testing  
- Confirm tool calls appear in the chat UI  

---

## **Why doesn't AIMusubi know what to do immediately?**
Think of AiMusubi as a teenager; a very jr network engineer.

- It requires technical and behavior training 
- AiMusubi responds to reinforcement (positive and negative)
- Scenario based training is beneficial for its learning
- Do not get frustrated with AiMusubi.  Be patient with it. It learns over time.
---

## **What devices are supported?**

### Out-of-the-box:
- **Cisco IOS-XE** (RESTCONF)
- **Arista EOS** (eAPI JSON-RPC)
- **VyOS** (REST/RESTCONF; varies by version)

### Coming later:
- More vendors can be added through adapters.

---

# 2. Installation & Setup

## **Do I need Ubuntu?**
For **bare-metal installation**, yes:  
AIMusubi is validated on Ubuntu 22.04+ / 24.04.

Docker installation works on nearly any Linux distribution.

---

## **How do I configure device credentials?**
Use the API:

```bash
curl -X POST http://127.0.0.1:5055/device/credentials   -H "Content-Type: application/json"   -d '{ "host": "router1.lab.local", "username":"lab", "password":"lab123" }'
```

List devices:

```bash
curl http://127.0.0.1:5055/device/list
```

---

## **Why does the LLM sometimes freeze or fail to call tools?**
Common causes:

- Incorrect Open WebUI workspace bindings  
- Cached profile state  
- Weak system prompt  
- Model does not support function calling  
- Open WebUI advanced settings interfering with behavior  

Reset by:
- Creating a fresh workspace  
- Re-attaching AIMusubi API as the tool  
- Forcing tool usage in the system prompt  

---

# 3. Device Interaction

## **Does AIMusubi log everything?**
Yes.

Use:

### Bare-metal:
```bash
sudo journalctl -u aimusubi-api -f
```

### Docker:
```bash
docker compose logs -f aimusubi-api
```

---

## **Can AIMusubi change device configs?**
Yes — but cautiously.

**Config-changing intents** like `iface.admin-up` and `iface.admin-down` exist,
but for safety:

- Start with read-only intents
- Enable config intents only when you fully understand adapter behavior
- Always keep device snapshots

---

## **Why do some intents return empty results?**
Possible reasons:

- Device API doesn't support that operation  
- OSPF not configured  
- Routing table empty  
- Vendor limitations  
- Missing privileges  

Check adapter logs for details.

---

## **Why does device output differ between runs?**
Because AIMusubi always returns **live data**.

If interface state or route tables change, AIMusubi reflects the most recent truth.

---

# 4. LLM Behavior

## **Why does the LLM hallucinate sometimes?**
Because LLMs interpret JSON and respond with natural language.

Typical triggers:
- Weak system prompt  
- Lack of explicit instructions  
- Tool not enforced  
- Past Open WebUI settings cached  

Fix using:
- Stronger system prompts  
- Clear instructions: “Use the AIMusubi tool to…”  
- Restart workspace if needed  

---

## **Why do tool calls sometimes not fire even with good prompts?**
Common causes:

- Model not in function-calling mode  
- Session corrupted by previous tool call failures  
- Open WebUI using cached data  
- Switching LLM models mid-session  

Fix:
- Create a new Workspace  
- Re-select model + tool  
- Paste a fresh system prompt  

---

# 5. Troubleshooting

## **I get 500 Internal Server Error**
Check:

- Device credentials  
- Device reachability  
- RESTCONF/eAPI/REST API enabled  
- Adapter logs  
- AIMusubi API traceback  

---

## **API health is up, but intents fail**
- Wrong credentials  
- Wrong host name  
- Unsupported YANG model  
- Vendor adapter limitations  

---

## **Open WebUI tool import fails**
Check:
- `http://127.0.0.1:5055/openapi.json` directly in browser  
- API logs  
- Port conflicts  

---

## **Prometheus/Grafana dashboard is empty**
Likely causes:

- Prometheus scrape failing  
- AIMusubi API not emitting metrics  
- Grafana datasource not detected  

---

# 6. Roadmap & Contributors

## **Will more vendors be supported?**
Yes — Cisco, Arista, VyOS are the first set.

Future candidates:
- Juniper  
- Fortinet  
- Palo Alto  
- Linux hosts / FRR  
- Cloud VNFs  

---

## **How can I contribute?**
1. Submit issues  
2. Improve documentation  
3. Build new adapters  
4. Enhance intents  
5. Improve Grafana dashboards  

A `CONTRIBUTING.md` file will be available soon.

---

# 7. Summary

AIMusubi is an early-stage, local-first, open-core framework designed for:

- Network engineers  
- DevOps practitioners  
- Homelab builders  
- LLM researchers  
- Anyone exploring agentic automation  

This FAQ covers the most common questions.  
For deeper technical insights:

👉 `agent_flow.md`  
👉 `installation_baremetal.md`  
👉 `installation_docker.md`  
