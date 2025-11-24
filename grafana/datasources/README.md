# AIMusubi – Grafana Data Sources

This directory contains **Grafana provisioning rules** for data sources.  
AIMusubi includes a single default source:

### ✔ Prometheus (local)

The provisioning file automatically registers:

http://localhost:9090/

as the Prometheus endpoint, matching the configuration set by the bootstrap
installer.

### Why this matters
Because data sources are pre-provisioned:

- Grafana works immediately after installation  
- No manual setup is required  
- Dashboards load instantly  
- Prometheus metrics appear in panels automatically  

See:
- `docs/installation_baremetal.md`
- `docs/installation_docker.md`
