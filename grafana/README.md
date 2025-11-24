# AIMusubi – Grafana Integration

This directory contains the **pre-provisioned Grafana dashboards and data source
definitions** used to visualize AIMusubi’s behavior.

Grafana is automatically installed and configured by both bootstraps
(bare-metal and Docker). When the system comes online, Grafana loads these
dashboards without any manual steps.

## What Grafana Provides

AIMusubi exposes Prometheus metrics from the API layer, adapter layer, and
intent engine. Grafana visualizes:

- API request rate  
- Intent success vs. failure  
- Adapter latency (Cisco / Arista / VyOS)  
- Error conditions  
- System resource usage (via Prometheus node exporter)

These dashboards help you understand how the LLM is interacting with the
network and how AIMusubi is performing internally.

## Structure

- `dashboard/` – JSON dashboard definitions loaded at startup
- `datasources/` – Data source provisioning for Prometheus

See the installation guides for:
- `docs/installation_baremetal.md`
- `docs/installation_docker.md`
