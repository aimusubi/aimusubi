# AIMusubi Core – API Layer

The `api/` directory contains the **FastAPI-based HTTP service** that exposes
AIMusubi to the outside world.

Responsibilities:

- Serve `/health`, `/metrics`, and `/openapi.json`
- Provide the `/intent/exec` endpoint used by Open WebUI and other clients
- Validate incoming requests and parameters
- Route intents into the intent engine
- Translate internal errors into clear HTTP responses

For more context on how requests flow through this layer, see:

- `docs/ARCHITECTURE.md`
- `docs/agent_flow.md`
