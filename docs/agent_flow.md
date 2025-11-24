# Agent Flow

This document explains how AIMusubi ties together:

- User / LLM prompts
- Tool calls
- AIMusubi API
- Adapters
- Devices
- Observability

---

## High-Level Flow

1. **User Prompt**  
   You type into Open WebUI:

   > "Use AIMusubi to list all interfaces on `router1`."

2. **LLM Reasoning**  
   The LLM decides to call the AIMusubi tool with intent `iface.list` for `router1`.

3. **Tool Call (Open WebUI → AIMusubi)**  
   Open WebUI sends a tool request to the AIMusubi API (via `/openapi.json` schema).

4. **API Routing**  
   AIMusubi:
   - Validates the request
   - Locates the adapter for the target device’s vendor
   - Calls the appropriate adapter function

5. **Adapter → Device**  
   The adapter:
   - Builds RESTCONF/eAPI/REST calls
   - Sends them to the device (e.g., `router1.lab.local`)
   - Parses the device response
   - Normalizes data into AIMusubi’s models

6. **API Response**  
   AIMusubi returns structured JSON back to Open WebUI.

7. **LLM Interpretation**  
   The LLM reads the JSON and responds in natural language, e.g.:

   > "On router1, GigabitEthernet2 is admin-down; all other interfaces are up."

8. **Metrics + Logs**  
   Simultaneously:
   - AIMusubi exposes metrics (latency, success/failure, counts) to Prometheus.
   - Logs activity (including errors) to its log output.

Grafana visualizes the metrics in near real time.

---

## Read-Only vs. Configuration Actions

There are two conceptual paths:

1. **Read-only path** (safe):
   - `iface.list`
   - `routing.v4.rib`
   - `ospf.neigh`
   - `cpu.util`
   - etc.

2. **Configuration path** (risky):
   - `iface.admin-up`
   - `iface.admin-down`
   - Future “set” / “update” intents

In most lab setups, you should start with **read-only only**, keep logs open, and only later experiment with config intents under strict control.

---

## Error Handling

If something fails, you might see:

- Device unreachable
- Auth failure
- Schema/intent mismatch
- Adapter errors

These surface as:

- API responses with error fields
- Logs in `journalctl` or Docker logs
- Metrics increments in Prometheus

This is by design – AIMusubi is meant to make failure **visible**, not invisible.

---

## Why This Matters

The goal of AIMusubi is not to hide complexity; it is to:

- Make every step of the pipeline visible
- Give you control over each layer
- Let you experiment with agentic behavior **on your own infrastructure**

For a quick refresher on what AIMusubi provides, see [Overview](overview.md).
