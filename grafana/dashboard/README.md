# AIMusubi – Grafana Dashboards

This folder contains the **JSON dashboard definitions** that Grafana imports
automatically on startup.

Dashboards included:

### 1. AIMusubi API Overview
Shows:
- Request throughput  
- Intent counts  
- Error ratios  
- Latency distributions  

### 2. Adapters Performance
Per-vendor visualization of:
- Cisco RESTCONF latency  
- Arista eAPI round-trip time  
- VyOS REST/RESTCONF performance  

### 3. System Health (optional)
If node exporter is active:
- CPU load  
- Memory usage  
- Disk I/O  
- Network interface traffic  

All dashboards are fully editable by users; changes do not affect the source
files unless exported manually.

To learn more, see:
- `docs/ARCHITECTURE.md`
- `docs/agent_flow.md`
