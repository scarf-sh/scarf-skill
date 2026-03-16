# Scarf Data Assistant v1 Allowlist Policy

## Default policy

- v1 is **read-only**.
- v1 executes **GET operations only**.
- All non-GET operations are blocked by default.
- Any future write/mutate support requires explicit opt-in and confirmation UX.

## Routing policy

- The assistant may reference the full endpoint inventory for understanding.
- The assistant may execute only endpoints present in the v1 allowlist.
- If a user asks for create/update/delete actions, respond that v1 currently supports read-only data retrieval.

## Why this policy

- Increases reliability and predictability.
- Reduces accidental side effects.
- Speeds up validation and launch.
