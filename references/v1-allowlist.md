# Scarf Data Assistant v1 Allowlist Policy

## Default policy

- v1 is analytics-first with bounded insights-filter CRUD.
- v1 executes `GET` operations by default.
- Only the approved insights-filter mutations are allowed outside `GET`.
- All other non-`GET` operations are blocked by default.

## Routing policy

- The assistant may reference the full endpoint inventory for understanding.
- The assistant may execute only endpoints present in the v1 allowlist.
- Approved non-`GET` operations:
  - `createInsightsFilter`
  - `updateInsightsFilter`
  - `deleteInsightsFilter`
- `getUserDefinedVariables` and `setUserDefinedVariables` are documented public endpoints, but user-defined variable writes remain outside the v1 allowlist.
- If a user asks for create/update/delete actions outside the approved filter CRUD endpoints, respond that v1 supports analytics plus limited insights-filter management only.

## Why this policy

- Increases reliability and predictability.
- Reduces accidental side effects.
- Preserves the new public filter CRUD workflow without reopening the broader write surface.
- Speeds up validation and launch.
