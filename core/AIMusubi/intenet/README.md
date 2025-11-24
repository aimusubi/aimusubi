# AIMusubi Core – Intent Engine

The `intents/` directory contains the **intent definitions and handlers** that
drive AIMusubi's vendor-agnostic behavior.

An intent represents a high-level network operation such as:

- `iface.list`
- `iface.admin-up`
- `iface.admin-down`
- `routing.v4.rib`
- `ospf.neigh`
- `cpu.util`
- `mem.stats`

Each intent:

- Defines required parameters
- Calls the appropriate adapter(s)
- Normalizes results into AIMusubi's standard schemas

For full reference, see:

- `docs/intents_reference.md`
- `docs/agent_flow.md`
