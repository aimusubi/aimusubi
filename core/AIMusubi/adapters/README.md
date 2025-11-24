# AIMusubi Core – Adapter Layer

The `adapters/` directory contains **vendor-specific drivers** that translate
AIMusubi intents into concrete device API calls.

Each adapter is responsible for:

- Authentication (RESTCONF, eAPI, REST, etc.)
- Constructing API requests
- Parsing and normalizing responses
- Mapping device errors into AIMusubi error types

Initial adapters include:

- Cisco IOS-XE (RESTCONF)
- Arista EOS (eAPI JSON-RPC)
- VyOS (REST/RESTCONF, version-dependent)

For a conceptual overview, see:

- `docs/adapters.md`
- `docs/intents_reference.md`
- `docs/ARCHITECTURE.md`
