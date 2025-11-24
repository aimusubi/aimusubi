# AIMusubi Core – Utilities

The `utils/` directory contains **shared helper functions** used across the
AIMusubi core:

- Common HTTP helpers
- Serialization / parsing helpers
- Logging utilities
- Small cross-cutting abstractions that don't belong in a single subsystem

Utilities should remain small, focused, and free of heavy dependencies.

See overall design context in:

- `docs/ARCHITECTURE.md`
