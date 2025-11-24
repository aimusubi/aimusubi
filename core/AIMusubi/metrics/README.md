# AIMusubi Core – Metrics Helpers

The `metrics/` directory contains helper code used to expose **Prometheus
metrics** from AIMusubi.

Example metric categories:

- API request counts
- Intent success / failure counts
- Adapter latency histograms
- Error counters

Metrics are scraped by Prometheus and visualized in Grafana dashboards.

More information:

- `docs/ARCHITECTURE.md`
- `docs/agent_flow.md`
