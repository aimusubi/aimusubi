# AIMusubi – Open WebUI Setup Guide

This guide walks through wiring **Open WebUI** to AIMusubi so an LLM can call  
the AIMusubi API as a tool and interact with real network devices.

After completing this guide you will be able to:

- Chat with an LLM in Open WebUI
- Have the LLM call AIMusubi intents (e.g. `iface.list`)
- See live device data in the conversation
- Watch tool calls show up in AIMusubi logs and Grafana

---

# 1. Prerequisites

Before configuring Open WebUI, make sure:

- AIMusubi API is running at `http://127.0.0.1:5055`
- Open WebUI service is running at `http://127.0.0.1:8081`
- You can successfully call:

```bash
curl http://127.0.0.1:5055/health
```

If that returns `{"ok": true, "status": "up"}`, continue.

If not, complete:

- `installation_baremetal.md` or  
- `installation_docker.md` and  
- `post_bootstrap_activation.md`

first.

---

# 2. Log In to Open WebUI

Open a browser and go to:

- http://127.0.0.1:8081

Create an admin account if prompted, or sign in with the credentials  
you configured during bootstrap.

Once logged in, you should see the main Open WebUI interface with:

- Sidebar (Chats, Workspace, Admin if you’re an admin)
- Main chat window

---

# 3. Configure an LLM Backend

Open WebUI needs at least one model configured. You can use:

- A **local model** via Ollama (`llama3` or similar), or
- An **external model** (OpenAI-compatible / Gemini-like provider)

You only need one to start.

---

## 3.1 Option A – Local LLM via Ollama

If Ollama is running on the same host (default in the bootstrap):

1. In Open WebUI, go to **Admin → Connections**.
2. Add a new connection:
   - **Type:** Ollama (or HTTP/OpenAI-compatible if your UI labels differ)
   - **URL:** `http://127.0.0.1:11434`
3. Save the connection.
4. Verify the model list shows something like `llama3`.

---

## 3.2 Option B – External LLM Provider

If you’re using an external provider:

1. In **Admin → Connections**, create a new connection.
2. Configure:
   - Base URL according to your provider
   - API key in the appropriate header or field
   - Default model name
3. Save.

The exact fields depend on the provider, but the goal is:

- Open WebUI can send prompts to the LLM
- The LLM supports tool-calling / function-calling for best results

---

# 4. Add AIMusubi as a Tool (OpenAPI)

Now we register AIMusubi with Open WebUI so the LLM can call it.

1. In Open WebUI, go to **Admin → Tools**.
2. Click **Add Tool** (or equivalent).
3. Configure:

   - **Name:** `AIMusubi API`
   - **Type:** OpenAPI / HTTP (pick the option that imports an OpenAPI schema)
   - **OpenAPI URL:**  
     `http://127.0.0.1:5055/openapi.json`

4. Save.

Open WebUI should:

- Fetch `openapi.json` from AIMusubi
- Display a list of available operations / intents

If it fails:

- Confirm AIMusubi API is reachable from Open WebUI
- Confirm URL and port are correct
- Check API logs (journalctl or `docker compose logs`)

---

# 5. Create a Workspace for AIMusubi

A workspace ties together:

- The LLM model
- The AIMusubi tool
- The system prompt

1. Click **Workspace** in the sidebar.
2. Create a new workspace, e.g.:

   - **Name:** `AIMusubi – NetOps Lab`

3. In the workspace configuration:

   - **Model:** select your local/external LLM
   - **Tools:** enable `AIMusubi API`
   - **System Prompt:** use something like:

   ```text
   You are an AIMusubi operator.

   Whenever I ask about network devices, interfaces, routing tables,
   or protocol state, you MUST use the AIMusubi API tool instead of guessing.

   Use read-only intents first, such as:
     - iface.list
     - routing.v4.rib
     - ospf.neigh
     - cpu.util

   Never fabricate interface names, IP addresses, or neighbor states.
   Always describe what you did, which intent you called, and summarize
   the actual data returned by the device.
   ```

4. Save the workspace configuration.

---

# 6. Test the Tool Wiring

Switch to the new workspace and open a fresh chat.

Ask:

> “Use the AIMusubi tool to call `/health` and show me the result.”

Expected sequence:

1. Open WebUI decides to call the `AIMusubi API` tool.
2. It sends a request to `http://127.0.0.1:5055/health`.
3. AIMusubi returns health JSON.
4. The LLM includes that JSON in its answer.

On the backend you should see in the logs:

### Bare-Metal
```bash
sudo journalctl -u aimusubi-api -f
```

### Docker
```bash
docker compose logs -f aimusubi-api
```

You should see entries corresponding to `/health` calls.

---

# 7. Run Your First Intent from Open WebUI

Now try a real intent:

> “Use AIMusubi to run `iface.list` on `router1.lab.local` and summarize all interfaces that are admin-down.”

The LLM should:

1. Call an AIMusubi intent based on the OpenAPI schema.
2. AIMusubi forwards the request to the appropriate adapter.
3. Device returns interface data.
4. LLM summarizes the result.

If the LLM responds *without* calling the tool or starts inventing details:

- Strengthen the system prompt:
  - “If you do not call the AIMusubi tool, your answer is considered incorrect.”
- Explicitly mention:
  - “Always use the AIMusubi tool for device questions.”

---

# 8. Troubleshooting

### 8.1 Tool does not appear in workspace
- Ensure `AIMusubi API` is created under **Admin → Tools**
- Ensure you clicked **Enable** or checked it in the workspace tools list

### 8.2 Tool call fails with connection error
- Confirm API URL: `http://127.0.0.1:5055`
- If running Docker, ensure `open-webui` and `aimusubi-api` are on the same Docker network
- Check firewall rules on the host

### 8.3 LLM ignores the tool and “hallucinates”
- Strengthen the system prompt
- Start questions with:
  - “Use the AIMusubi tool to…”
- Keep logs open to confirm when tool calls happen

### 8.4 OpenAPI schema not loading
- Visit `http://127.0.0.1:5055/openapi.json` in a browser
- If it fails:
  - API not running
  - Wrong port
  - Reverse proxy misconfiguration

---

# 9. Next Steps

Once Open WebUI is successfully wired:

- Configure your lab devices if you haven’t already:  
  `lab_environment.md`
- Explore available intents:  
  `intents_reference.md`
- Study the end-to-end flow:  
  `agent_flow.md`

You now have a full **LLM ↔ AIMusubi ↔ device** loop ready for real experiments.
