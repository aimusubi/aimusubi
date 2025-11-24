# AIMusubi Core – Memory Subsystem

The `memory/` directory contains the **SQLite-backed state layer** for AIMusubi.

Typical responsibilities:

- Storing device credentials
- Recording basic observations / metadata
- Providing simple lookup APIs for other components

This subsystem is intentionally lightweight and local-first, suitable for
homelab and lab environments. Future enterprise tiers may introduce additional
storage backends.

See also:

- `docs/ARCHITECTURE.md`
- `docs/roadmap.md`
