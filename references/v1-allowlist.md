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
  - `setUserDefinedVariables`
- `getUserDefinedVariables` is in-scope as a `GET` operation.
- If a user asks for create/update/delete actions outside the approved insights workflow operations, respond that v1 supports analytics plus limited insights-filter and persisted-variable management only.

## Why this policy

- Increases reliability and predictability.
- Reduces accidental side effects.
- Preserves the new public insights workflow (filters + persisted variables) without reopening the broader write surface.
- Speeds up validation and launch.
