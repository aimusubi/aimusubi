# Intents Reference

This document provides a high-level overview of the standard intents exposed by AIMusubi.

> **Note:** The exact list may evolve. Always refer to the OpenAPI spec at  
> `http://127.0.0.1:5055/openapi.json` for the current set.

---

## Interface Intents

### `iface.list`

List interfaces and their key attributes.

**Parameters (typical):**

- `target`: device logical name (e.g., `router1`)
- Optional filters (interface name, admin/oper status)

**Example LLM prompt:**

> "Use AIMusubi to run `iface.list` on `router1` and tell me which interfaces are admin-down."

---

### `iface.admin-up` / `iface.admin-down` *(if enabled)*

Change interface admin state.

> **Important:** Configuration-changing intents should be used carefully and may be disabled or restricted by default.

**Parameters:**

- `target`: device logical name
- `interface`: interface identifier (e.g., `GigabitEthernet1`)

---

## Routing Intents

### `routing.v4.rib`

Get IPv4 routing table.

**Parameters:**

- `target`: device

**Example prompt:**

> "Use AIMusubi to query `routing.v4.rib` on `router1` and summarize all routes to 10.0.0.0/8."

---

## OSPF Intents

### `ospf.neigh`

List OSPF neighbors and state.

**Parameters:**

- `target`: device

---

## System / Health Intents

### `system.health` or `/health` endpoint

Basic API health check.

**Example prompt:**

> "Use the AIMusubi tool to call `/health` and show me the result."

---

## Telemetry / Utilization

### `cpu.util` (example)

Retrieve CPU utilization.

### `mem.stats` (example)

Retrieve memory statistics.

---

## Adding New Intents

New intents follow this pattern:

1. Define an intent name and schema.
2. Implement logic in the AIMusubi core.
3. Map it in each adapter (where applicable).
4. Document it here and in the OpenAPI spec.

For more details on the end-to-end flow, see [Agent Flow](agent_flow.md).
