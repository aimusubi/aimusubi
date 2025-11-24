# AIMusubi Core

This directory contains the **core engine** of AIMusubi – the code that powers
the API, intent engine, adapter layer, memory subsystem, metrics, and utilities.

Most users will interact with AIMusubi through the bootstraps and the documented
HTTP API. This folder is primarily for contributors and advanced users who want
to understand or extend how AIMusubi works internally.

For a high-level explanation of the design, see:

- `docs/ARCHITECTURE.md`
- `docs/agent_flow.md`
- `docs/adapters.md`
- `docs/intents_reference.md`

## Layout

- `api/` – FastAPI service and HTTP endpoints
- `adapters/` – Vendor-specific drivers (Cisco, Arista, VyOS, etc.)
- `intents/` – Intent definitions and handlers
- `memory/` – SQLite-backed state and credential storage
- `metrics/` – Prometheus metric helpers
- `utils/` – Shared helper functions and common utilities

Each subdirectory includes its own `README.md` with more detail.
