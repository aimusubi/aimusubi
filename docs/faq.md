# FAQ

A collection of frequently asked questions about AIMusubi.

---

## Is this production-ready?

No. AIMusubi v1.0 is a **lab-grade framework** for experimentation and learning.

It is:

- Great for homelabs and testbeds.
- Not hardened for multi-tenant or production NOCs.

---

## Does AIMusubi fabricate device data?

AIMusubi itself never fabricates device state.  

However, an LLM **can** hallucinate if:

- It ignores the AIMusubi tool
- It misinterprets the JSON
- The prompt doesn’t strongly require tool usage

To reduce this:

- Use strong system prompts that force tool usage.
- Train yourself to ask: “Use the AIMusubi tool to…”
- Cross-check with CLI or logs, especially early on.

---

## What vendors are supported?

Out of the box (v1.0):

- Cisco IOS-XE (RESTCONF)
- Arista EOS (eAPI)
- VyOS (REST/RESTCONF, depending on platform support)

You can extend to more vendors by writing new adapters.

---

## Does this require cloud connectivity?

No. AIMusubi is **local-first**.

You can:

- Use local LLMs (via Ollama).
- Block outbound traffic after initial bootstrap.
- Or use external LLMs if you choose.

---

## Why use Open WebUI?

Open WebUI provides:

- A local LLM front-end
- Easy tool (OpenAPI) integration
- Workspace isolation
- A clean way to see tool calls and responses

You can integrate AIMusubi with other front-ends if desired.

---

## Can I break my lab devices?

Yes – if you use configuration-changing intents (`admin-up`, `admin-down`, etc.).

To stay safe:

- Start with **read-only** intents.
- Snapshot device configs.
- Only experiment with config changes once you understand the flows.

---

## Will there be an “enterprise” version?

The long-term plan is:

- **Open-core AIMusubi** for labs and experimentation
- **Enterprise tier** for:
  - RBAC
  - Multi-tenant operation
  - Topology & service modeling
  - FinOps / cost telemetry
  - Clustering and HA

See [Roadmap](roadmap.md) for more details.

---

## How do I contribute?

- Open issues with bug reports or questions
- Submit PRs for:
  - Docs improvements
  - New intents
  - New adapters
- Share your lab setups and feedback

See `CONTRIBUTING.md` (when available) for guidelines.
