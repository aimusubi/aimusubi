# AIMusubi – Agent Flow Guide

This document explains the **end-to-end flow** of how AIMusubi processes  
an LLM request, executes an intent, interacts with a real network device,  
and returns structured data back to the LLM.

This helps users understand how AIMusubi operates internally and how  
each component fits into the automation pipeline.

---

# 1. High-Level Architecture

The overall path of a request:

```
User Prompt → LLM Reasoning → Open WebUI Tool Call → AIMusubi API
            → Adapter Logic → Device API (RESTCONF/eAPI/REST)
            → AIMusubi API → LLM → User Response
```

AIMusubi also feeds logs and metrics into:

- **Prometheus**
- **Grafana**
- Local SQLite memory state

---

# 2. Step-by-Step Agent Flow

Below is the detailed flow from the moment a user types a prompt.

---

## Step 1 – User Prompts the LLM

Example:

> “Use AIMusubi to run `iface.list` on router1.”

The prompt is processed inside **Open WebUI** using the configured model  
(local Ollama or external provider).

---

## Step 2 – LLM Decides to Call a Tool

If your system prompt is configured correctly, the LLM will:

- Recognize the request involves a network device
- Decide to use the AIMusubi tool
- Identify the correct intent (`iface.list`)
- Build a tool call based on the OpenAPI schema

Example internal tool call (conceptual):

```json
{
  "tool": "AIMusubi API",
  "operation": "iface.list",
  "params": { "host": "router1.lab.local" }
}
```

---

## Step 3 – Open WebUI Sends Tool Call to AIMusubi API

Open WebUI uses the `/openapi.json` spec to generate  
a valid HTTP POST request to the AIMusubi API.

Example:

```
POST http://127.0.0.1:5055/intent/exec
```

Payload:

```json
{
  "intent": "iface.list",
  "params": { "host": "router1.lab.local" }
}
```

Open WebUI shows the tool call in the chat UI.

---

## Step 4 – AIMusubi API Routes Intent

The AIMusubi API:

1. Validates the intent exists
2. Validates parameters
3. Identifies the vendor associated with the host
4. Selects the correct adapter:
   - Cisco RESTCONF
   - Arista eAPI
   - VyOS REST
5. Calls the adapter’s internal handler

---

## Step 5 – Adapter Executes Device API Calls

Each adapter:

- Builds the correct HTTPS request(s)
- Adds credentials
- Sends the request to the device
- Receives JSON/XML/YANG output
- Normalizes the data into AIMusubi’s standard structures

Example Cisco RESTCONF call (conceptual):

```
GET https://router1.lab.local/restconf/data/ietf-interfaces:interfaces/interface
```

Example Arista eAPI call (conceptual):

```
JSON-RPC → runCmds(["show ip interface brief"])
```

Example VyOS REST call:

```
GET https://edge1.lab.local/interfaces
```

If device errors occur:

- AIMusubi logs them
- The adapter returns a structured error back to API
- LLM receives meaningful error context

---

## Step 6 – AIMusubi API Returns Normalized JSON

AIMusubi returns a clean, vendor-agnostic JSON response:

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

This is one of the major benefits of AIMusubi:

✔ Unified data model  
✔ Identical schema across all vendors  
✔ LLM-friendly structures  
✔ Rich telemetry and logs  

---

## Step 7 – LLM Interprets Device Data

The LLM receives the JSON and produces a human-readable explanation.

Example:

> “On router1, all interfaces are up except GigabitEthernet2,  
> which is admin-down. The IPv4 address of Gi1 is 10.1.1.1/24.”

Properly instructed (via system prompt), the LLM will:

- Never invent interface names
- Never guess statuses
- Only summarize returned JSON
- Offer recommendations based on actual device state

---

## Step 8 – Metrics and Logs Update

While the request flows:

### Logs  
AIMusubi records:

- Intent execution  
- Device API calls  
- Errors  
- Latency  
- Adapter selection  

Bare-metal:
```bash
sudo journalctl -u aimusubi-api -f
```

Docker:
```bash
docker compose logs -f aimusubi-api
```

### Prometheus Metrics  
Prometheus scrapes metrics such as:

- `aimusubi_intent_success_total`
- `aimusubi_intent_failure_total`
- `aimusubi_adapter_latency_seconds`
- `aimusubi_api_requests_total`

Grafana dashboards then visualize:

- Intent success/failure trends  
- Per-vendor latency  
- Success ratio  
- API behavior over time  

---

# 3. How AIMusubi Avoids Hallucinations

Hallucination prevention is built on three layers:

### **Layer 1 – Tool Enforcement**  
Strong system prompts instruct LLM to always call AIMusubi for device data.

### **Layer 2 – Ground Truth JSON**  
Adapters return **real device state** — no synthetic values.

### **Layer 3 – Observability**  
Logs and metrics allow verification that every intent was actually executed.

---

# 4. Errors and Recovery

### Example: Device unreachable

API returns:

```json
{
  "error": "Device unreachable at router1.lab.local"
}
```

LLM explains:

> “AIMusubi could not reach router1.lab.local over HTTPS.  
> Check IP, routing, or device API configuration.”

### Example: Unsupported endpoint

API returns:

```json
{
  "error": "RESTCONF endpoint not supported on this device"
}
```

Adapter automatically flags vendor limitations.

### Example: Credential problems

Use `/device/list` and `/device/credentials` to confirm proper configuration.

---

# 5. Summary

The AIMusubi agent flow provides:

- A clean division between LLM reasoning and device interaction  
- A consistent, predictable structure for automation  
- Real network state instead of hallucinated output  
- Strong observability and debug tools  
- An extensible architecture for new intents and vendors  

For deeper understanding of specific intents:

👉 `intents_reference.md`  
