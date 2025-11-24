# Roadmap

This roadmap outlines the planned evolution of AIMusubi.

---

## v1.x – Open-Core Lab Framework (Current Phase)

**Focus:**

- Solidify the core
- Support 2–3 vendors well
- Improve documentation and examples

**Planned:**

- More robust error reporting in API
- More detailed interface and routing models
- Additional intents:
  - BGP summaries
  - Interface counters (unicast, errors, drops)
- More Grafana panels (intent latency, vendor breakdowns, error rates)
- Better adapter configuration UX

---

## v2.x – Advanced Lab + Team Use

**Focus:**

- Small teams and serious homelabs
- More guardrails and governance

**Ideas:**

- Role-based “profiles” for different workspaces
- Stronger policy integration with OPA
- Snapshot / restore of AIMusubi state
- Enhanced event handling via SNMP and webhooks
- Pluggable “playbooks” for common workflows

---

## Enterprise Direction (Conceptual)

Longer term, the “enterprise tier” could introduce:

- RBAC and multi-tenant controls
- Clustered AIMusubi API instances
- Central topology and service graph
- Integration with ITSM / ticketing systems
- FinOps and cloud cost correlation
- SLA tracking and service-health scoring

The open-core project will remain focused on:

- Labs
- Local-first operation
- Transparency
- Extensibility

---

## Community Input

If you use AIMusubi and have ideas for:

- New intents
- New vendors
- Better observability
- Safer agent behaviors

…please open an issue or discussion and share your thoughts.
