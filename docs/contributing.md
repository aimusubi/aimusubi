# Contributing to AIMusubi

Thank you for your interest in contributing to **AIMusubi**, a local-first,
open-core agentic NetOps framework.  
This project exists to empower engineers, homelab builders, and researchers to
experiment with intent-based automation and real-network LLM workflows.

This guide outlines how to contribute code, documentation, adapters, or testing.

---

# 1. Code of Conduct

By participating in this project, you agree to:

- Be respectful and constructive  
- Avoid hostile or dismissive behavior  
- Help maintain a welcoming environment  

We aim to build a collaborative, positive community.

---

# 2. Ways You Can Contribute

You do **not** need to write code to contribute.

### **Documentation**
- Fix typos or formatting
- Expand explanations
- Improve examples
- Add troubleshooting guides
- Suggest reorganizations

### **Issues / Bug Reports**
- Unexpected behavior
- Adapter inconsistencies
- Intent edge cases
- Bootstrap issues (bare-metal or Docker)
- Anything confusing or unclear

### **Feature Requests**
- New intents
- Metrics enhancements
- Adapter improvements
- UI integrations
- Device support ideas

### **Code Contributions**
- New adapters (Juniper, Fortinet, Palo Alto, etc.)
- Intent implementations
- Log enhancements
- Robust error handling
- Prometheus/Grafana improvements

---

# 3. Project Structure

Below is a simplified overview of key directories:

```
core/AIMusubi/
├── api/            # FastAPI service
├── adapters/       # Vendor-specific drivers
├── intents/        # Intent schemas + handlers
├── memory/         # SQLite state
└── utils/          # Shared helpers

bootstrap/          # Installer scripts (bare-metal + Docker)
docs/               # Documentation
grafana/            # Dashboards + datasources
```

Documentation for these sections is located inside the `docs/` folder.

---

# 4. Filing an Issue

Before opening an issue:

1. Search existing issues  
2. If nothing matches, create a new issue

### Include:
- Description of the problem
- Steps to reproduce
- Logs if relevant (`journalctl -u aimusubi-api -f`)
- Environment details:
  - Bare-metal or Docker?
  - Ubuntu version?
  - Device vendor?  
  - API endpoint behavior?

Clear issues help maintainers respond quickly.

---

# 5. Pull Requests (PRs)

We welcome well-scoped PRs.

To submit a PR:

1. **Fork the repository**
2. **Create a feature branch**
3. Make changes with clear commit messages
4. Run basic tests (see below)
5. Submit PR with description and rationale

Example workflow:

```bash
git checkout -b feature/new-adapter
# make changes
git commit -am "Add preliminary Juniper NETCONF adapter"
git push origin feature/new-adapter
```

---

# 6. Development Environment Setup

### Clone and install:

```bash
git clone https://github.com/aimusubi/aimusubi.git
cd aimusubi
pip install -r requirements.txt
```

### Run API locally:

```bash
uvicorn core.AIMusubi.api.main:app --reload --port 5055
```

### View API docs:

```
http://127.0.0.1:5055/docs
```

---

# 7. Writing or Extending Intents

To create a new intent:

1. Add a schema in `core/AIMusubi/intents/`
2. Implement the handler logic
3. Add adapter support for each vendor (or vendor subsets)
4. Update OpenAPI generation
5. Document in `docs/intents_reference.md`

---

# 8. Building Adapters

Adapter templates live in:

```
core/AIMusubi/adapters/
```

To build a new adapter:

- Follow structure of `cisco.py`, `arista.py`, or `vyos.py`
- Implement:
  - Authentication
  - Device API calls
  - Error handling
  - Normalization functions
- Update the adapter registry
- Add unit tests where possible

---

# 9. Testing and Validation

### Local tests:
- Run intents against mock devices or emulated API responses
- Use GNS3 or containerized router images for integration tests

### Observability testing:
- Check Prometheus metrics exposed at `/metrics`
- Validate Grafana dashboards

### LLM testing:
- Verify that tool calls fire properly in Open WebUI
- Check that LLMs summarize results without fabricating data

---

# 10. Code Style

- Follow PEP8 formatting for Python
- Keep functions small and modular
- Document complex logic
- Avoid silent failures — raise explicit errors

---

# 11. Submitting Dashboards or Examples

You may contribute:

- Grafana dashboards
- Example playbooks
- Adapter testing guides
- Sample labs (GNS3, EVE-NG, container labs)

Place them under the appropriate folder (`grafana/`, `examples/`, etc.)

---

# 12. Versioning and Releases

AIMusubi uses semantic versioning:

```
MAJOR.MINOR.PATCH
```

Examples:
- `1.0.0` - Initial open-core release
- `1.1.0` - New intents, vendor updates
- `2.0.0` - Major architectural enhancements

---

# 13. Getting Help

You can:

- Open issues  
- DM maintainers on GitHub  
- Participate in discussions (future)  

Documentation lives under `docs/`.

---

# 14. Thank You

Your contributions, small or large, help make AIMusubi a stronger, more useful project.

Thank you for helping grow this open-core community!
